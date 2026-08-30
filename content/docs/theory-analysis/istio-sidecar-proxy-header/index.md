---
title: Istio Sidecar Proxy Header
draft: true
---

## 1. Istio Sidecar Proxy Header

Istio 환경에서 Sidecar Proxy가 설정하고 활용하는 Header를 살펴본다.

### 1.1. Test 환경 구성

Test 환경은 Istio `1.24` Version을 기준으로 구성한다. 2개의 Worker Node로 구성되어 있고 각각의 Node에 Client 역할을 수행하는 `shell` Pod와 Server 역할을 수행하는 `mock-server` Pod가 위치한다. HTTP Protocol을 통해서 접근하는 경우에는 `shell` Pod 내부에서 `curl` 명령어를 이용하여 접근하고, gRPC Protocol을 통해서 접근하는 경우에는 `shell` Pod 내부에서 `grpcurl` 명령어를 이용하여 접근한다. Ingress Gateway Case (1.6)에서는 Mesh 외부에서 Ingress Gateway를 경유하여 `mock-server`에 접근한다.

#### 1.1.1. Kubernetes, Istio 환경 구성

```shell {caption="[Shell 1] Kubernetes, Istio 환경 구성"}
# Create kubernetes cluster with kind
$ kind create cluster --config=- <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
EOF

# Install istio
$ istioctl install --set profile=demo -y

# Enable sidecar injection to default namespace
$ kubectl label namespace default istio-injection=enabled
```

[Shell 1]은 Kubernetes, Istio 환경을 구성하는 Script를 나타내고 있다. `kind`를 활용하여 Kubernetes Cluster를 구성하고 Istio를 설치한다. 그리고 default Namespace에 Sidecar Injection을 활성화한다.

#### 1.1.2. Workload 구성

```yaml {caption="[File 1] mock-server Pod Manifest", linenos=table}
apiVersion: v1
kind: Pod
metadata:
  name: mock-server
  labels:
    app: mock-server
spec:
  containers:
  - name: mock-server
    image: ghcr.io/ssup2/mock-go-server:3.1.0
    ports:
    - containerPort: 8080
    - containerPort: 9090
---
apiVersion: v1
kind: Service
metadata:
  name: mock-server
spec:
  selector:
    app: mock-server
  ports:
  - name: http
    port: 8080
    targetPort: 8080
  - name: grpc
    port: 9090
    targetPort: 9090
```

[File 1]은 `mock-server` Workload의 Manifest를 나타내고 있다. `mock-server` Image를 이용하여 `mock-server` Pod을 생성하며, `8080` Port를 열어서 HTTP 서비스를 제공하고, `9090` Port를 열어서 gRPC 서비스를 제공한다.

```yaml {caption="[File 2] shell Pod Manifest", linenos=table}
apiVersion: v1
kind: Pod
metadata:
  name: shell
  labels:
    app: shell
spec:
  containers:
  - name: shell
    image: nicolaka/netshoot
    command: ["sleep", "infinity"]
```

[File 2]는 Client 역할을 수행하는 `shell` Pod의 Manifest를 나타내고 있다.

```yaml {caption="[File 3] mock-server Gateway, Virtual Service Manifest", linenos=table}
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: mock-server
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "mock-server.example.com"
---
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: mock-server-gateway
spec:
  hosts:
  - "mock-server.example.com"
  gateways:
  - mock-server
  http:
  - route:
    - destination:
        host: mock-server
        port:
          number: 8080
```

[File 3]은 Mesh 외부에서 Ingress Gateway를 통해서 `mock-server`에 접근하기 위한 Gateway, Virtual Service Manifest를 나타내고 있다. Ingress Gateway 관련 Case (1.6)에서 이용한다.

#### 1.1.3. Header 확인 방법

모든 Header는 **istio-proxy (Envoy)의 Debug Log**를 통해서 확인한다. Envoy의 `http`, `router` Logger의 Log Level을 `debug`로 변경하면 Envoy가 처리하는 요청과 응답의 모든 Header를 Log로 확인할 수 있으며, 각 Logger는 다음의 내용을 출력한다.

* `http` Logger : Downstream으로부터 수신한 요청 Header (`request headers complete`)와, Downstream에게 전달하는 응답 Header (`encoding headers via codec`), Trailer (`encoding trailers via codec`)를 출력한다.
* `router` Logger : Upstream으로 전송하는 요청 Header (`router decoding headers`)를 출력한다.

따라서 Client 측 (`shell`)과 Server 측 (`mock-server`)의 istio-proxy Log를 통해서 다음과 같이 모든 구간의 Header를 확인할 수 있다.

* Client가 전송한 요청 Header : `shell` istio-proxy의 `request headers complete`
* Sidecar Proxy 사이의 요청 Header : `shell` istio-proxy의 `router decoding headers` 또는 `mock-server` istio-proxy의 `request headers complete`
* Server (App Container)가 수신하는 요청 Header : `mock-server` istio-proxy의 `router decoding headers`
* Client가 수신하는 응답 Header : `shell` istio-proxy의 `encoding headers via codec`

```shell {caption="[Shell 2] Header 확인 방법"}
# Enable debug log for http, router loggers
$ istioctl proxy-config log shell --level http:debug,router:debug
$ istioctl proxy-config log mock-server --level http:debug,router:debug

# Send requests
$ kubectl exec -it shell -- curl -s mock-server:8080/status/200
$ kubectl exec -it shell -- grpcurl -plaintext -d '{"code": 0}' mock-server:9090 mock.MockService/Status

# Check headers in istio-proxy logs
$ kubectl logs shell -c istio-proxy -f
$ kubectl logs mock-server -c istio-proxy -f
```

[Shell 2]는 Header 확인 방법을 나타내고 있다. `curl`, `grpcurl` 명령어는 요청 전송 용도로만 이용하며, Header 확인은 모두 istio-proxy의 Log를 이용한다.

### 1.2. Header 처리의 주요 특징

각 Case를 살펴보기 전에, Istio 환경에서 Sidecar Proxy의 Header 처리와 관련된 일반적인 특징은 다음과 같다.

* Tracing Header 미생성 : Istio `1.22` Version부터 Tracing이 기본적으로 비활성화되어 있기 때문에, `x-b3-traceid`, `x-b3-spanid`와 같은 Tracing Header는 생성되지 않는다. Mesh Config를 통해서 Tracing을 활성화한 경우에만 설정된다.
* Sidecar Proxy 간 전용 Header 제거 : `x-envoy-peer-metadata`, `x-envoy-peer-metadata-id`, `x-envoy-decorator-operation` Header는 Sidecar Proxy 사이에서만 교환되며, App Container에게 전달되기 전에 제거된다.
* 제어 Header 미동작 : App이 요청에 설정하는 `x-envoy-upstream-rq-timeout-ms`, `x-envoy-retry-on`과 같은 제어 Header는 동작하지 않는다. Sidecar Proxy의 `use_remote_address` 설정이 `false`이고 App이 전송하는 요청에는 XFF Header가 존재하지 않기 때문에, Sidecar Proxy는 요청을 External 요청으로 판단하여 `x-envoy-` Prefix의 제어 Header를 제거한다. 따라서 Timeout과 재시도는 제어 Header가 아니라 Virtual Service를 통해서 설정해야 한다.

### 1.3. HTTP Cases

#### 1.3.1. Server 수신 요청 Header Case

```shell {caption="[Shell 3] HTTP 요청 전송 및 Server 수신 요청 Header 확인"}
$ kubectl exec -it shell -- curl -s mock-server:8080/status/200
$ kubectl logs mock-server -c istio-proxy | grep -A 12 "router decoding headers"
```

```text {caption="[Text 1] mock-server istio-proxy의 App Container 전송 요청 Header"}
router decoding headers:
':authority', 'mock-server:8080'
':path', '/status/200'
':method', 'GET'
':scheme', 'http'
'user-agent', 'curl/8.21.0'
'accept', '*/*'
'x-forwarded-proto', 'http'
'x-request-id', '748f9efe-751f-9675-8126-c508c226f873'
'x-envoy-attempt-count', '1'
'x-forwarded-client-cert', 'By=spiffe://cluster.local/ns/default/sa/default;Hash=a6410c85...;Subject="";URI=spiffe://cluster.local/ns/default/sa/default'
```

[Shell 3]과 같이 `shell` Pod에서 `mock-server`로 HTTP 요청을 전송하고, `mock-server` istio-proxy가 App Container에게 전송하는 요청 Header를 확인한다. 이 Header가 App Container가 실제로 수신하는 요청 Header이다. [Text 1]과 같이 `curl`은 `Host`, `User-Agent`, `Accept` Header만 전송했지만, Sidecar Proxy를 거치면서 다음의 Header들이 추가된 것을 확인할 수 있다.

* `x-request-id` : Client 측 Sidecar Proxy가 생성한 UUID 값이 Server까지 전파된다.
* `x-forwarded-proto` : Client와 Sidecar Proxy 사이의 Protocol (`http`)을 나타낸다.
* `x-envoy-attempt-count` : 요청의 시도 횟수를 나타낸다. 재시도가 없는 경우 `1`이다.
* `x-forwarded-client-cert` (XFCC) : mTLS를 통해서 전달된 Client의 인증서 정보를 나타낸다. 각 Key의 의미는 다음과 같다.
  * `By` : 현재 Proxy (`mock-server`의 Sidecar Proxy) 인증서의 URI SAN (SPIFFE ID)을 나타낸다. `mock-server` Pod가 `default` Namespace의 `default` Service Account로 동작하기 때문에 `spiffe://cluster.local/ns/default/sa/default` 값이 설정된다.
  * `Hash` : Client 인증서의 SHA256 Hash 값을 나타낸다.
  * `Subject` : Client 인증서의 Subject를 나타낸다. Istio가 발급하는 인증서에는 Subject가 존재하지 않기 때문에 빈 값이다.
  * `URI` : Client 인증서의 URI SAN (SPIFFE ID)을 나타낸다. `shell` Pod도 `default` Namespace의 `default` Service Account로 동작하기 때문에 `By` Key와 동일한 값이 설정되어 있으며, App은 이 값을 통해서 요청을 전송한 Client의 Identity를 확인할 수 있다.

#### 1.3.2. Client 수신 응답 Header Case

```shell {caption="[Shell 4] HTTP 요청 전송 및 Client 수신 응답 Header 확인"}
$ kubectl exec -it shell -- curl -s mock-server:8080/status/200
$ kubectl logs shell -c istio-proxy | grep -A 7 "encoding headers via codec"
```

```text {caption="[Text 2] shell istio-proxy의 Client 전송 응답 Header"}
encoding headers via codec (end_stream=false):
':status', '200'
'content-type', 'application/json'
'date', 'Sun, 30 Aug 2026 09:04:14 GMT'
'content-length', '59'
'x-envoy-upstream-service-time', '11'
'server', 'envoy'
```

[Shell 4]와 같이 `shell` istio-proxy가 Client (`curl`)에게 전달하는 응답 Header를 확인한다. 이 Header가 Client가 실제로 수신하는 응답 Header이다. [Text 2]와 같이 다음의 Header들이 설정되어 있는 것을 확인할 수 있다.

* `x-envoy-upstream-service-time` : Client 측 Sidecar Proxy가 `mock-server` Pod로 요청을 전송한 이후 응답을 받을 때까지의 시간 (Millisecond)을 나타내며, 두 Pod 사이의 Network Latency와 Server 측 Sidecar Proxy, App Container의 처리 시간이 모두 포함된다.
* `server` : Server 측 Sidecar Proxy는 응답에 `server: istio-envoy` Header를 설정하지만, Client 측 Sidecar Proxy를 거치면서 `envoy` 값으로 변경되어 Client에게 전달된다.

#### 1.3.3. Sidecar Proxy 간 Metadata Exchange Header Case

```shell {caption="[Shell 5] HTTP 요청 전송 및 Sidecar Proxy 간 Header 확인"}
$ kubectl exec -it shell -- curl -s mock-server:8080/status/200
$ kubectl logs shell -c istio-proxy
$ kubectl logs mock-server -c istio-proxy
```

```text {caption="[Text 3] shell istio-proxy 요청, 응답 Header (Debug Log)"}
# Request headers received from curl
request headers complete (end_stream=true):
':authority', 'mock-server:8080'
':path', '/status/200'
':method', 'GET'
'user-agent', 'curl/8.21.0'
'accept', '*/*'

# Request headers sent to mock-server istio-proxy
router decoding headers:
':authority', 'mock-server:8080'
':path', '/status/200'
':method', 'GET'
':scheme', 'http'
'user-agent', 'curl/8.21.0'
'accept', '*/*'
'x-forwarded-proto', 'http'
'x-request-id', '748f9efe-751f-9675-8126-c508c226f873'
'x-envoy-decorator-operation', 'mock-server.default.svc.cluster.local:8080/*'
'x-envoy-peer-metadata-id', 'sidecar~10.244.2.3~shell.default~default.svc.cluster.local'
'x-envoy-peer-metadata', 'ChoKCkNMVVNURVJfSUQSDBoKS3ViZXJuZXRlcwp5CgZMQUJFTFMSbypt...'
'x-envoy-attempt-count', '1'

# Response headers received from mock-server istio-proxy and sent to curl
encoding headers via codec (end_stream=false):
':status', '200'
'content-type', 'application/json'
'x-envoy-upstream-service-time', '11'
'server', 'envoy'
```

```text {caption="[Text 4] mock-server istio-proxy 요청, 응답 Header (Debug Log)"}
# Request headers received from shell istio-proxy
request headers complete (end_stream=true):
':authority', 'mock-server:8080'
':path', '/status/200'
':method', 'GET'
'user-agent', 'curl/8.21.0'
'accept', '*/*'
'x-forwarded-proto', 'http'
'x-request-id', '748f9efe-751f-9675-8126-c508c226f873'
'x-envoy-decorator-operation', 'mock-server.default.svc.cluster.local:8080/*'
'x-envoy-peer-metadata-id', 'sidecar~10.244.2.3~shell.default~default.svc.cluster.local'
'x-envoy-peer-metadata', 'ChoKCkNMVVNURVJfSUQSDBoKS3ViZXJuZXRlcwp5CgZMQUJFTFMSbypt...'
'x-envoy-attempt-count', '1'

# Request headers sent to mock-server app container
router decoding headers:
':authority', 'mock-server:8080'
':path', '/status/200'
':method', 'GET'
':scheme', 'http'
'user-agent', 'curl/8.21.0'
'accept', '*/*'
'x-forwarded-proto', 'http'
'x-request-id', '748f9efe-751f-9675-8126-c508c226f873'
'x-envoy-attempt-count', '1'
'x-forwarded-client-cert', 'By=spiffe://cluster.local/ns/default/sa/default;Hash=a6410c85...;Subject="";URI=spiffe://cluster.local/ns/default/sa/default'

# Response headers sent to shell istio-proxy
encoding headers via codec (end_stream=false):
':status', '200'
'content-type', 'application/json'
'x-envoy-upstream-service-time', '7'
'x-envoy-peer-metadata-id', 'sidecar~10.244.1.8~mock-server.default~default.svc.cluster.local'
'x-envoy-peer-metadata', 'ChoKCkNMVVNURVJfSUQSDBoKS3ViZXJuZXRlcwqFAQoGTEFCRUxTEnsqeQ...'
'server', 'istio-envoy'
```

```text {caption="[Text 5] x-envoy-peer-metadata Decoding 결과"}
$ echo "ChoKCkNMVVNURVJfSUQSDBoKS3ViZXJuZXRlcwp5..." | base64 -d | strings
CLUSTER_ID / Kubernetes
LABELS / app: shell / service.istio.io/canonical-name: shell / ...
NAME / shell
NAMESPACE / default
OWNER / kubernetes://apis/apps/v1/namespaces/default/pods/shell
WORKLOAD_NAME / shell
```

[Shell 5]와 같이 하나의 요청에 대해서 양쪽 istio-proxy의 Log를 확인하면 Sidecar Proxy 사이에서만 교환되는 Header를 확인할 수 있다. [Text 3]은 Client 측 (`shell`) Sidecar Proxy의 관점을 나타내고 있다. `curl`로부터 수신한 요청에는 기본 Header만 존재하지만, `mock-server`로 전송하는 요청에는 Sidecar Proxy가 추가한 `x-request-id`, `x-envoy-decorator-operation`, `x-envoy-peer-metadata` Header가 존재하며, 반대로 `curl`에게 전달하는 응답에서는 Server 측 Sidecar Proxy가 응답에 설정한 Metadata Header가 제거되어 있는 것을 확인할 수 있다. [Text 4]는 Server 측 (`mock-server`) Sidecar Proxy의 관점을 나타내고 있다. 수신한 요청에는 Client 측 Sidecar Proxy가 추가한 Header들이 그대로 존재하지만, App Container로 전송하는 요청에서는 Metadata Exchange Header와 `x-envoy-decorator-operation` Header가 제거되고 XFCC Header가 추가된 것을 확인할 수 있다. 그리고 App Container의 응답을 Client에게 전달하면서 자신의 Metadata Header를 응답에 추가한다. Sidecar Proxy 구간에만 존재하는 Header의 의미는 다음과 같다.

* `x-envoy-peer-metadata`, `x-envoy-peer-metadata-id` : Client Workload의 Metadata를 나타낸다. [Text 5]는 `x-envoy-peer-metadata` 값을 Decoding한 결과를 나타내고 있으며, Workload의 이름, Namespace, Label, Owner 정보가 포함되어 있다. 응답에는 반대로 `mock-server` Workload의 Metadata가 설정되며, 양쪽 Sidecar Proxy는 이러한 Metadata 교환을 통해서 `source_workload`, `destination_workload`와 같은 Istio Metric의 Label을 설정한다.
* `x-envoy-decorator-operation` : Client 측 Sidecar Proxy가 Route 설정을 기반으로 설정한 Tracing Span의 Operation 이름을 나타낸다.

### 1.4. GRPC Cases

#### 1.4.1. 요청, 응답 Header와 Trailer Case

```shell {caption="[Shell 6] gRPC 요청 전송 및 응답 Header, Trailer 확인"}
$ kubectl exec -it shell -- grpcurl -plaintext -d '{"code": 0}' mock-server:9090 mock.MockService/Status
$ kubectl exec -it shell -- grpcurl -plaintext -d '{"code": 13}' mock-server:9090 mock.MockService/Status
$ kubectl logs shell -c istio-proxy
```

```text {caption="[Text 6] gRPC 정상 응답의 Header, Trailer (shell istio-proxy Debug Log)"}
# Request headers received from grpcurl
request headers complete (end_stream=false):
':method', 'POST'
':scheme', 'http'
':path', '/mock.MockService/Status'
':authority', 'mock-server:9090'
'content-type', 'application/grpc'
'user-agent', 'grpcurl/v1.9.3 grpc-go/1.61.0'
'te', 'trailers'
'grpc-accept-encoding', 'gzip'

# Response headers sent to grpcurl
encoding headers via codec (end_stream=false):
':status', '200'
'content-type', 'application/grpc'
'x-envoy-upstream-service-time', '7'
'server', 'envoy'

# Response trailers sent to grpcurl
encoding trailers via codec:
'grpc-status', '0'
'grpc-message', ''
```

```text {caption="[Text 7] gRPC Error 응답의 Header (shell istio-proxy Debug Log, Trailers-Only)"}
encoding headers via codec (end_stream=true):
':status', '200'
'content-type', 'application/grpc'
'grpc-status', '13'
'grpc-message', 'Simulated error with gRPC code 13 (Internal)'
'x-envoy-upstream-service-time', '3'
'server', 'envoy'
```

[Shell 6]과 같이 gRPC 요청을 전송하고 `shell` istio-proxy의 Log를 통해서 응답의 Header와 Trailer를 확인한다. [Text 6]은 정상 응답 (gRPC Status Code `OK (0)`)을 나타내고 있다. 요청 Header에는 gRPC의 특징인 `content-type: application/grpc`, `te: trailers` Header가 설정되어 있으며, 응답은 Header (`end_stream=false`)와 Body 전송 이후 **Trailer**에 최종 처리 결과인 `grpc-status` Header가 설정되어 전송된다.

[Text 7]는 Error 응답 (gRPC Status Code `INTERNAL (13)`)을 나타내고 있다. 전송할 Message가 없는 Error 응답이기 때문에 **Trailers-Only** 형태로 응답되며, 별도의 Trailer 없이 하나의 HEADERS Frame (`end_stream=true`)에 `grpc-status`, `grpc-message` Header가 함께 설정된 것을 확인할 수 있다.

#### 1.4.2. grpc-timeout Header Case

```shell {caption="[Shell 7] gRPC Deadline 설정 요청"}
$ kubectl exec -it shell -- grpcurl -plaintext -max-time 1 -d '{"milliseconds": 3000}' mock-server:9090 mock.MockService/Delay
$ kubectl logs mock-server -c istio-proxy | grep -B 10 -A 2 "grpc-timeout"
```

```text {caption="[Text 8] grpc-timeout Header 결과 (mock-server istio-proxy Debug Log)"}
request headers complete (end_stream=false):
':method', 'POST'
':scheme', 'http'
':path', '/mock.MockService/Delay'
':authority', 'mock-server:9090'
'content-type', 'application/grpc'
'te', 'trailers'
'grpc-timeout', '988m'
'x-request-id', '878dda93-fa6d-953d-b338-afeb40dd9e45'
'x-envoy-expected-rq-timeout-ms', '988'
'x-envoy-attempt-count', '1'
```

[Shell 7]와 같이 `grpcurl` 명령어의 `-max-time` 옵션을 이용하여 gRPC Client의 Deadline이 `grpc-timeout` Header로 전파되는지 확인한다. [Text 8]은 `mock-server` istio-proxy가 수신한 요청 Header를 나타내고 있다.

* Client가 설정한 1초의 Deadline은 `grpc-timeout: 988m` Header로 전파된다. (전송 시점까지의 경과 시간을 제외한 988 Millisecond)
* Sidecar Proxy는 `grpc-timeout` Header를 요청의 Timeout으로 활용하며, `x-envoy-expected-rq-timeout-ms: 988` Header를 추가로 설정하여 Upstream에게 Timeout 값을 전파하는 것을 확인할 수 있다.

### 1.5. mTLS Cases

mTLS 적용 유무에 따라서 변화하는 Header를 확인한다. mTLS 관련 Header (`x-forwarded-client-cert`)는 Protocol과 무관한 연결 수준에서 설정되는 Header이기 때문에 HTTP 요청으로만 확인하며, gRPC 요청의 경우에도 동일하게 동작한다.

#### 1.5.1. mTLS 적용 Case

```shell {caption="[Shell 8] mTLS 적용 상태 요청 전송"}
$ kubectl exec -it shell -- curl -s mock-server:8080/status/200
$ kubectl logs mock-server -c istio-proxy | grep -A 12 "router decoding headers"
```

```text {caption="[Text 9] mTLS 적용 상태 App Container 전송 요청 Header"}
router decoding headers:
':authority', 'mock-server:8080'
':path', '/status/200'
'x-request-id', '748f9efe-751f-9675-8126-c508c226f873'
'x-envoy-attempt-count', '1'
'x-forwarded-client-cert', 'By=spiffe://cluster.local/ns/default/sa/default;Hash=a6410c85...;Subject="";URI=spiffe://cluster.local/ns/default/sa/default'
```

Istio는 기본적으로 Sidecar Proxy 사이에 mTLS를 적용한다 (`PERMISSIVE` Mode + Auto mTLS). [Shell 8]과 같이 mTLS가 적용된 상태에서 `mock-server` istio-proxy가 App Container에게 전송하는 요청 Header를 확인하면, [Text 9]와 같이 `x-forwarded-client-cert` (XFCC) Header에 Client (`shell` Pod)의 SPIFFE ID가 설정되어 있는 것을 확인할 수 있다.

#### 1.5.2. mTLS 미적용 Case

```yaml {caption="[File 4] mTLS 비활성화 Manifest", linenos=table}
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: mock-server
spec:
  selector:
    matchLabels:
      app: mock-server
  mtls:
    mode: DISABLE
---
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: mock-server
spec:
  host: mock-server
  trafficPolicy:
    tls:
      mode: DISABLE
```

[File 4]는 `mock-server`에 대한 mTLS를 비활성화하는 Manifest를 나타내고 있다. PeerAuthentication을 통해서 Server 측의 mTLS 수신을 비활성화하고, Destination Rule을 통해서 Client 측의 mTLS 전송을 비활성화한다.

```shell {caption="[Shell 9] mTLS 미적용 상태 요청 전송"}
$ kubectl exec -it shell -- curl -s mock-server:8080/status/200
$ kubectl logs mock-server -c istio-proxy | grep -A 12 "router decoding headers"
```

```text {caption="[Text 10] mTLS 미적용 상태 App Container 전송 요청 Header"}
router decoding headers:
':authority', 'mock-server:8080'
':path', '/status/200'
':method', 'GET'
':scheme', 'http'
'user-agent', 'curl/8.21.0'
'accept', '*/*'
'x-forwarded-proto', 'http'
'x-request-id', 'e0a45506-9f65-920c-867d-e5323d83586c'
'x-envoy-attempt-count', '1'
```

[Shell 9]와 같이 mTLS를 비활성화한 상태에서 동일한 요청을 전송하면, [Text 10]과 같이 App Container에게 전송하는 요청에서 `x-forwarded-client-cert` (XFCC) Header가 사라진 것을 확인할 수 있다. XFCC Header는 mTLS 인증서 정보를 기반으로 설정되기 때문에 mTLS가 비활성화되면 설정되지 않는다.

### 1.6. Ingress Gateway Cases

Mesh 외부에서 Ingress Gateway를 통해서 유입되는 요청의 Header를 확인한다. Ingress Gateway 관련 Header (`x-forwarded-for`, `x-envoy-external-address`)와 Header Sanitization, `use_remote_address`, `xff_num_trusted_hops` 설정은 모두 Protocol과 무관한 HTTP Connection Manager 수준의 동작이기 때문에 HTTP 요청으로만 확인하며, gRPC 요청의 경우에도 동일하게 동작한다.

Mesh 외부에서 Ingress Gateway로의 접근은 `kubectl port-forward`를 이용한다. 이 경우 Ingress Gateway가 인식하는 직접 연결된 Client의 IP 주소가 실제 외부 IP가 아니라 Loopback 또는 Pod IP (Internal 주소)가 된다는 점을 감안하고 결과를 해석해야 한다.

#### 1.6.1. Ingress Gateway 경유 요청 Header Case

```shell {caption="[Shell 10] Ingress Gateway 경유 요청 전송"}
# Port forward ingress gateway
$ kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80

# Send request from outside of the mesh
$ curl -s -H "Host: mock-server.example.com" localhost:8080/status/200

# Check headers sent to app container
$ kubectl logs mock-server -c istio-proxy | grep -A 13 "router decoding headers"
```

```text {caption="[Text 11] Ingress Gateway 경유 App Container 전송 요청 Header"}
router decoding headers:
':authority', 'mock-server.example.com'
':path', '/status/200'
':method', 'GET'
':scheme', 'http'
'user-agent', 'curl/8.7.1'
'accept', '*/*'
'x-forwarded-for', '10.244.2.7'
'x-forwarded-proto', 'http'
'x-request-id', '2b4f3b6e-f411-94ef-9a43-dde1cb79c7ea'
'x-envoy-attempt-count', '1'
'x-envoy-internal', 'true'
'x-forwarded-client-cert', 'By=spiffe://cluster.local/ns/default/sa/default;Hash=31d6f5d6...;Subject="";URI=spiffe://cluster.local/ns/istio-system/sa/istio-ingressgateway-service-account'
```

[Shell 10]과 같이 [File 3]의 Gateway, Virtual Service를 통해서 Mesh 외부에서 Ingress Gateway를 경유하여 `mock-server`에 접근하고, App Container에게 전송되는 요청 Header를 확인한다. [Text 11]는 Mesh 내부 요청과 비교하여 다음의 차이를 나타내고 있다.

* `x-forwarded-for` : Ingress Gateway가 직접 연결된 Client의 IP 주소를 XFF Header에 추가한 것을 확인할 수 있다. Mesh 내부의 Sidecar Proxy는 XFF Header를 추가하지 않지만, Ingress Gateway는 `use_remote_address` 설정이 `true`이기 때문에 XFF Header를 추가한다.
* `x-forwarded-client-cert` (XFCC) : Ingress Gateway와 `mock-server`의 Sidecar Proxy 사이에는 mTLS가 적용되기 때문에, `URI` Key에 Ingress Gateway의 SPIFFE ID (`spiffe://cluster.local/ns/istio-system/sa/istio-ingressgateway-service-account`)가 설정된다. 즉 App 입장에서 XFCC로 확인할 수 있는 Identity는 원본 Client가 아니라 Ingress Gateway이다.
* `x-envoy-internal` : `true`로 설정되어 있는데, 이는 `kubectl port-forward` 특성상 Ingress Gateway에 직접 연결된 Client의 주소가 Internal 주소 (Pod IP)이기 때문이다. 실제 환경에서 외부 Client가 공인 IP로 접근하는 경우에는 External 요청으로 판단된다.

#### 1.6.2. Header Sanitization Case

```shell {caption="[Shell 11] 외부 Client의 제어 Header 설정 요청"}
# Enable debug log for ingress gateway
$ istioctl proxy-config log deploy/istio-ingressgateway -n istio-system --level http:debug,router:debug

# A: Internal client (no XFF, direct address is a private IP via port-forward)
$ curl -s -H "Host: mock-server.example.com" -H "x-envoy-upstream-rq-timeout-ms: 1000" localhost:8080/delay/3000

# B: External client (XFF with a public IP)
$ curl -s -H "Host: mock-server.example.com" -H "X-Forwarded-For: 1.2.3.4" -H "x-envoy-upstream-rq-timeout-ms: 1000" localhost:8080/delay/3000

# Check headers in ingress gateway log
$ kubectl logs -n istio-system deploy/istio-ingressgateway
```

```text {caption="[Text 12] Header Sanitization 결과 (Ingress Gateway Debug Log)"}
# A: request headers received from external client
request headers complete (end_stream=true):
':path', '/delay/3000'
'x-envoy-upstream-rq-timeout-ms', '1000'

# A: request headers sent to mock-server istio-proxy (internal, timeout header honored)
router decoding headers:
':path', '/delay/3000'
'x-forwarded-for', '10.244.2.7'
'x-envoy-expected-rq-timeout-ms', '1000'

# A: 504 local reply after 1s
Sending local reply with details response_timeout
"response_code": "504"

# B: request headers received from external client
request headers complete (end_stream=true):
':path', '/delay/3000'
'x-forwarded-for', '1.2.3.4'
'x-envoy-upstream-rq-timeout-ms', '1000'

# B: request headers sent to mock-server istio-proxy (external, timeout header removed)
router decoding headers:
':path', '/delay/3000'
'x-forwarded-for', '1.2.3.4,10.244.2.7'
'x-envoy-external-address', '127.0.0.1'

# B: 200 after 3s (timeout not applied)
"response_code": "200"
```

[Shell 11]와 같이 Mesh 외부의 Client가 `x-envoy-` Prefix의 제어 Header를 설정하여 전송하는 경우, Ingress Gateway가 해당 Header를 제거하는지 확인한다. `kubectl port-forward` 환경에서는 직접 연결된 Client의 주소가 Internal 주소로 인식되기 때문에, XFF Header에 공인 IP를 설정하여 External 요청 상황을 재현한다. [Text 12]는 Ingress Gateway의 Log를 나타내고 있다.

* A의 경우 Ingress Gateway가 직접 연결된 Client의 주소 (Internal 주소)를 기반으로 Internal 요청으로 판단하기 때문에, Timeout 제어 Header가 `x-envoy-expected-rq-timeout-ms` Header로 변환되어 동작하고 `504` Status Code가 1초 만에 응답된다.
* B의 경우 요청에 XFF Header가 존재하기 때문에 External 요청으로 판단되며, **Timeout 제어 Header가 제거되어 동작하지 않고** 3초 후에 `200` Status Code가 응답된다. External 요청이기 때문에 `x-envoy-external-address` Header가 설정되며, 신뢰할 수 있는 Client의 IP 주소인 직접 연결된 주소 (`127.0.0.1`, port-forward의 Loopback 연결)가 설정된다. Client가 전송한 XFF Header의 `1.2.3.4` 값은 신뢰되지 않는다.

실제 환경에서 외부 Client가 공인 IP로 직접 접근하는 경우에는 XFF Header 유무와 무관하게 External 요청으로 판단되기 때문에, Mesh 외부의 Client는 `x-envoy-` Prefix의 제어 Header를 활용할 수 없다.

#### 1.6.3. use_remote_address 기본값 Case

```shell {caption="[Shell 12] use_remote_address 설정 확인"}
# Ingress gateway
$ kubectl exec -n istio-system deploy/istio-ingressgateway -- pilot-agent request GET config_dump | grep use_remote_address

# Sidecar proxy
$ kubectl exec shell -c istio-proxy -- pilot-agent request GET config_dump | grep use_remote_address
```

```text {caption="[Text 13] use_remote_address 기본값 확인 결과"}
# Ingress Gateway
"use_remote_address": true

# Sidecar Proxy
"use_remote_address": false
```

Envoy의 `use_remote_address` 설정은 신뢰할 수 있는 Client의 IP 주소와 Internal/External 요청 판단의 기준을 결정하며, Istio는 Proxy의 역할에 따라서 이 설정을 다르게 구성한다. Istio는 이 설정을 변경하는 정식 API를 제공하지 않는다. [Shell 12]와 같이 Envoy의 Config Dump를 통해서 확인하면, [Text 13]과 같이 **Ingress Gateway는 `true`, Sidecar Proxy는 `false`**로 설정되어 있다. 이 차이로 인해서 앞의 Case들에서 확인한 동작 차이가 발생한다.

* Sidecar Proxy (`false`) : 직접 연결된 Client (App Container)의 주소를 신뢰하지 않고 XFF Header만을 기반으로 판단한다. App이 전송하는 요청에는 XFF Header가 없기 때문에 External 요청으로 판단되어 제어 Header가 제거된다. XFF Header에 주소를 추가하지도 않는다.
* Ingress Gateway (`true`) : Mesh의 Edge에 위치하기 때문에 직접 연결된 Client의 주소를 신뢰한다. 직접 연결된 주소를 XFF Header에 추가하며, 요청에 XFF Header가 존재하지 않으면 직접 연결된 주소를 기반으로 Internal/External을 판단하고, XFF Header가 존재하면 External 요청으로 판단한다.

#### 1.6.4. xff_num_trusted_hops 설정 Case

```yaml {caption="[File 5] Ingress Gateway numTrustedProxies Manifest", linenos=table}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: istio-ingressgateway
  namespace: istio-system
spec:
  template:
    metadata:
      annotations:
        proxy.istio.io/config: |
          gatewayTopology:
            numTrustedProxies: 1
```

[File 5]는 Ingress Gateway의 `numTrustedProxies` 설정을 `1`로 변경하는 Manifest를 나타내고 있다. Istio는 `gatewayTopology.numTrustedProxies` 설정을 통해서 Envoy의 `xff_num_trusted_hops` 설정을 변경한다. Ingress Gateway 앞에 신뢰할 수 있는 Proxy (AWS ALB, Nginx 등)가 존재하는 환경을 의미한다.

```shell {caption="[Shell 13] xff_num_trusted_hops 설정 요청 전송"}
# Send request with pre-populated XFF header (simulating a front proxy)
$ curl -s -H "Host: mock-server.example.com" -H "X-Forwarded-For: 1.2.3.4, 5.6.7.8" localhost:8080/status/200

# Check headers sent to app container
$ kubectl logs mock-server -c istio-proxy | grep -A 13 "router decoding headers"
```

```text {caption="[Text 14] xff_num_trusted_hops 설정 App Container 전송 요청 Header"}
# Before (numTrustedProxies: 0, default)
'x-forwarded-for', '1.2.3.4, 5.6.7.8,10.244.2.7'
'x-envoy-external-address', '127.0.0.1'

# After (numTrustedProxies: 1)
'x-forwarded-for', '1.2.3.4, 5.6.7.8,10.244.1.10'
'x-envoy-external-address', '5.6.7.8'
```

[Shell 13]과 같이 XFF Header에 두 개의 주소 (`1.2.3.4, 5.6.7.8`)를 설정한 요청을 전송하고, App Container에게 전송되는 요청 Header를 설정 전/후로 비교한다. [Text 14]은 설정 전/후의 결과를 나타내고 있다.

* 설정 전 (`numTrustedProxies: 0`) : XFF Header의 주소를 신뢰하지 않고, 직접 연결된 Client의 주소 (`127.0.0.1`)가 신뢰할 수 있는 Client의 IP 주소로 판단되어 `x-envoy-external-address` Header에 설정된다.
* 설정 후 (`numTrustedProxies: 1`) : Ingress Gateway 앞에 신뢰할 수 있는 Proxy가 1개 존재한다고 가정하기 때문에, XFF Header의 가장 오른쪽 주소 (`5.6.7.8`)가 신뢰할 수 있는 Proxy가 설정한 신뢰할 수 있는 Client의 IP 주소로 판단되어 `x-envoy-external-address` Header에 설정된다. Client가 임의로 설정한 `1.2.3.4` 값은 신뢰되지 않는다.

## 2. 참조

* Envoy Header : [https://ssup2.github.io/blog-software/docs/theory-analysis/envoy-header/](https://ssup2.github.io/blog-software/docs/theory-analysis/envoy-header/)
* Envoy Header Manipulation : [https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_conn_man/headers](https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_conn_man/headers)
* Istio Distributed Tracing : [https://istio.io/latest/docs/tasks/observability/distributed-tracing/overview/](https://istio.io/latest/docs/tasks/observability/distributed-tracing/overview/)
* Envoy x-forwarded-client-cert : [https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_conn_man/headers#x-forwarded-client-cert](https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_conn_man/headers#x-forwarded-client-cert)
* Istio Gateway Network Topology : [https://istio.io/latest/docs/ops/configuration/traffic-management/network-topologies/](https://istio.io/latest/docs/ops/configuration/traffic-management/network-topologies/)
* Istio Mutual TLS Migration : [https://istio.io/latest/docs/tasks/security/authentication/mtls-migration/](https://istio.io/latest/docs/tasks/security/authentication/mtls-migration/)

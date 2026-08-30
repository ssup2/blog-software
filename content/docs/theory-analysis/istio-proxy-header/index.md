---
title: Istio Proxy Header
draft: true
---

## 1. Istio Proxy Header

Istio 환경에서 Sidecar Proxy와 Ingress Gateway가 설정하고 활용하는 Header를 살펴본다.

### 1.1. Test 환경 구성

Test 환경은 Istio `1.24` Version을 기준으로 구성한다. 2개의 Worker Node로 구성되어 있고 각각의 Node에 Client 역할을 수행하는 `shell` Pod와 Server 역할을 수행하는 `mock-server` Pod가 위치한다. `shell` Pod 내부에서 `curl` 명령어를 이용하여 `mock-server`에 접근한다. Ingress Gateway Case (1.4)에서는 Mesh 외부에서 Ingress Gateway를 경유하여 `mock-server`에 접근한다.

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
```

[File 1]은 `mock-server` Workload의 Manifest를 나타내고 있다. `mock-server` Image를 이용하여 `mock-server` Pod을 생성하며, `8080` Port를 열어서 HTTP 서비스를 제공한다.

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

[File 3]은 Mesh 외부에서 Ingress Gateway를 통해서 `mock-server`에 접근하기 위한 Gateway, Virtual Service Manifest를 나타내고 있다. Ingress Gateway 관련 Case (1.4)에서 이용한다.

#### 1.1.3. Header 확인 방법

모든 Header는 **istio-proxy (Envoy)의 Log**를 통해서 확인한다. Envoy의 `http`, `router` Logger의 Log Level을 `trace`로 변경하면 Envoy가 처리하는 요청과 응답의 모든 Header를 Log로 확인할 수 있으며, 각 Logger는 다음의 내용을 출력한다.

* `http` Logger : Downstream으로부터 수신한 요청 Header (`request headers complete`)와, Downstream에게 전달하는 응답 Header (`encoding headers via codec`), Trailer (`encoding trailers via codec`)를 출력한다.
* `router` Logger : Upstream으로 전송하는 요청 Header (`router decoding headers`)와, Upstream으로부터 수신한 응답 Header (`upstream response headers`)를 출력한다.

따라서 Client 측 (`shell`)과 Server 측 (`mock-server`)의 istio-proxy Log를 통해서 다음과 같이 모든 구간의 Header를 확인할 수 있다.

* Client가 전송한 요청 Header : `shell` istio-proxy의 `request headers complete`
* Sidecar Proxy 간 요청 Header : `shell` istio-proxy의 `router decoding headers` 또는 `mock-server` istio-proxy의 `request headers complete`
* Server가 수신하는 요청 Header : `mock-server` istio-proxy의 `router decoding headers`
* Server가 전송한 응답 Header : `mock-server` istio-proxy의 `upstream response headers`
* Sidecar Proxy 간 응답 Header : `mock-server` istio-proxy의 `encoding headers via codec`
* Client가 수신하는 응답 Header : `shell` istio-proxy의 `encoding headers via codec`

```shell {caption="[Shell 2] Header 확인 방법"}
# Enable trace log for http, router loggers
$ istioctl proxy-config log shell --level http:trace,router:trace
$ istioctl proxy-config log mock-server --level http:trace,router:trace

# Send request
$ kubectl exec -it shell -- curl -s mock-server:8080/status/200

# Check headers in istio-proxy logs
$ kubectl logs shell -c istio-proxy -f
$ kubectl logs mock-server -c istio-proxy -f
```

[Shell 2]는 Header 확인 방법을 나타내고 있다. `curl` 명령어는 요청 전송 용도로만 이용하며, Header 확인은 모두 istio-proxy의 Log를 이용한다.

### 1.2. Header 처리의 주요 특징

각 Case를 살펴보기 전에, Istio 환경에서 Istio Proxy (Sidecar Proxy, Ingress Gateway)의 Header 처리와 관련된 일반적인 특징은 다음과 같다.

* Tracing Header 미생성 : Istio `1.22` Version부터 Tracing이 기본적으로 비활성화되어 있기 때문에, `x-b3-traceid`, `x-b3-spanid`와 같은 Tracing Header는 생성되지 않는다. Mesh Config를 통해서 Tracing을 활성화한 경우에만 설정된다.
* Istio Proxy 간 전용 Header 제거 : `x-envoy-peer-metadata`, `x-envoy-peer-metadata-id`, `x-envoy-decorator-operation` Header는 Istio Proxy 사이에서만 교환되며, App Container에게 전달되기 전에 제거된다.
* gRPC 요청의 동일 처리 : gRPC는 HTTP/2를 기반으로 동작하기 때문에 gRPC 요청에도 HTTP 요청과 동일한 Header 처리가 적용된다. gRPC Client가 Deadline을 설정한 경우 전파되는 `grpc-timeout` Header는 Istio Proxy가 요청의 Timeout으로 활용하며, `x-envoy-expected-rq-timeout-ms` Header로 변환되어 Upstream에게 전파된다.
* 제어 Header 미동작 : App이 요청에 설정하는 `x-envoy-upstream-rq-timeout-ms`, `x-envoy-retry-on`과 같은 제어 Header는 동작하지 않는다. Sidecar Proxy의 `use_remote_address` 설정이 `false`이고 App이 전송하는 요청에는 XFF Header가 존재하지 않기 때문에, Sidecar Proxy는 요청을 External 요청으로 판단하여 `x-envoy-` Prefix의 제어 Header를 제거한다. Ingress Gateway도 동일하게 Mesh 외부에서 유입되는 External 요청의 `x-envoy-` Prefix 제어 Header를 제거한다. 따라서 Timeout과 재시도는 제어 Header가 아니라 Virtual Service를 통해서 설정해야 한다.

### 1.3. Sidecar Proxy Cases

```shell {caption="[Shell 3] HTTP 요청 전송"}
$ kubectl exec -it shell -- curl -s mock-server:8080/status/200
```

[Shell 3]과 같이 `shell` Pod에서 `mock-server`로 하나의 HTTP 요청을 전송하고, 요청과 응답이 흐르는 순서대로 각 구간의 Header를 istio-proxy의 Log를 통해서 확인한다. 요청은 `shell` Container → `shell` istio-proxy → `mock-server` istio-proxy → `mock-server` Container 순서로 3개의 구간을 거치며, 응답은 반대 순서로 전달된다.

#### 1.3.1. Client 전송 요청 Header Case (shell → shell istio-proxy)

```shell {caption="[Shell 4] Client 전송 요청 Header 확인"}
$ kubectl logs shell -c istio-proxy | sed -n '/request headers complete/,/thread=/p'
```

```text {caption="[Text 1] shell istio-proxy 수신 요청 Header"}
request headers complete (end_stream=true):
':authority', 'mock-server:8080'
':path', '/status/200'
':method', 'GET'
'user-agent', 'curl/8.21.0'
'accept', '*/*'
```

[Shell 4]와 같이 `shell` istio-proxy가 `shell` Container로부터 수신한 요청 Header를 확인한다. [Text 1]과 같이 `curl`이 전송한 `Host`, `User-Agent`, `Accept` Header만 존재하며, 아직 Istio 관련 Header는 존재하지 않는다.

#### 1.3.2. Sidecar Proxy 간 요청 Header Case (shell istio-proxy → mock-server istio-proxy)

```shell {caption="[Shell 5] Sidecar Proxy 간 요청 Header 확인"}
$ kubectl logs shell -c istio-proxy | sed -n '/router decoding headers/,/thread=/p'
```

```text {caption="[Text 2] shell istio-proxy의 mock-server istio-proxy 전송 요청 Header"}
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
```

```text {caption="[Text 3] x-envoy-peer-metadata Decoding 결과"}
$ echo "ChoKCkNMVVNURVJfSUQSDBoKS3ViZXJuZXRlcwp5..." | base64 -d | strings
CLUSTER_ID / Kubernetes
LABELS / app: shell / service.istio.io/canonical-name: shell / ...
NAME / shell
NAMESPACE / default
OWNER / kubernetes://apis/apps/v1/namespaces/default/pods/shell
WORKLOAD_NAME / shell
```

[Shell 5]와 같이 `shell` istio-proxy가 `mock-server` istio-proxy에게 전송하는 요청 Header를 확인한다. [Text 2]와 같이 `shell` istio-proxy를 거치면서 다음의 Header들이 추가된 것을 확인할 수 있다.

* `x-forwarded-proto` : Client와 Sidecar Proxy 사이의 Protocol (`http`)을 나타낸다.
* `x-request-id` : Client 측 Sidecar Proxy가 생성한 요청의 고유한 UUID 값을 나타낸다.
* `x-envoy-attempt-count` : 요청의 시도 횟수를 나타낸다. 재시도가 없는 경우 `1`이다.
* `x-envoy-decorator-operation` : Client 측 Sidecar Proxy가 Route 설정을 기반으로 설정한 Tracing Span의 Operation 이름을 나타낸다.
* `x-envoy-peer-metadata`, `x-envoy-peer-metadata-id` : Client Workload의 Metadata를 나타낸다. [Text 3]은 `x-envoy-peer-metadata` 값을 Decoding한 결과를 나타내고 있으며, Workload의 이름, Namespace, Label, Owner 정보가 포함되어 있다. 양쪽 Sidecar Proxy는 Metadata 교환을 통해서 `source_workload`, `destination_workload`와 같은 Istio Metric의 Label을 설정한다.

#### 1.3.3. Server 수신 요청 Header Case (mock-server istio-proxy → mock-server)

```shell {caption="[Shell 6] Server 수신 요청 Header 확인"}
$ kubectl logs mock-server -c istio-proxy | sed -n '/router decoding headers/,/thread=/p'
```

```text {caption="[Text 4] mock-server istio-proxy의 mock-server 전송 요청 Header"}
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

[Shell 6]과 같이 `mock-server` istio-proxy가 `mock-server` Container에게 전송하는 요청 Header를 확인한다. 이 Header가 `mock-server` Container가 실제로 수신하는 요청 Header이다. [Text 4]와 같이 Sidecar Proxy 사이에서만 교환되는 `x-envoy-decorator-operation`, `x-envoy-peer-metadata`, `x-envoy-peer-metadata-id` Header는 제거되고, `x-forwarded-client-cert` (XFCC) Header가 추가된 것을 확인할 수 있다. XFCC Header는 mTLS를 통해서 전달된 Client의 인증서 정보를 나타내며, 각 Key의 의미는 다음과 같다.

* `By` : 현재 Proxy (`mock-server`의 Sidecar Proxy) 인증서의 URI SAN (SPIFFE ID)을 나타낸다. `mock-server` Pod가 `default` Namespace의 `default` Service Account로 동작하기 때문에 `spiffe://cluster.local/ns/default/sa/default` 값이 설정된다.
* `Hash` : Client 인증서의 SHA256 Hash 값을 나타낸다.
* `Subject` : Client 인증서의 Subject를 나타낸다. Istio가 발급하는 인증서에는 Subject가 존재하지 않기 때문에 빈 값이다.
* `URI` : Client 인증서의 URI SAN (SPIFFE ID)을 나타낸다. `shell` Pod도 `default` Namespace의 `default` Service Account로 동작하기 때문에 `By` Key와 동일한 값이 설정되어 있으며, App은 이 값을 통해서 요청을 전송한 Client의 Identity를 확인할 수 있다.

Istio는 기본적으로 Sidecar Proxy 사이에 mTLS를 적용하기 때문에 (`PERMISSIVE` Mode + Auto mTLS) XFCC Header도 기본적으로 설정된다. 반면 PeerAuthentication과 Destination Rule을 통해서 mTLS를 비활성화하면 인증서 정보가 존재하지 않기 때문에 XFCC Header도 설정되지 않는다. `URI` Key의 SPIFFE ID는 Istio Authorization Policy의 `source.principals` 조건 매칭에도 활용된다.

#### 1.3.4. Server 전송 응답 Header Case (mock-server → mock-server istio-proxy)

```shell {caption="[Shell 7] Server 전송 응답 Header 확인"}
$ kubectl logs mock-server -c istio-proxy | sed -n '/upstream response headers/,/thread=/p'
```

```text {caption="[Text 5] mock-server istio-proxy 수신 응답 Header"}
end_stream: false, upstream response headers:
':status', '200'
'content-type', 'application/json'
'content-length', '59'
```

[Shell 7]과 같이 `mock-server` istio-proxy가 `mock-server` Container로부터 수신한 응답 Header를 확인한다. [Text 5]와 같이 `mock-server` Container가 전송한 응답에는 `content-type`, `content-length`와 같은 기본 Header만 존재하며, 아직 Istio 관련 Header는 존재하지 않는다.

#### 1.3.5. Sidecar Proxy 간 응답 Header Case (mock-server istio-proxy → shell istio-proxy)

```shell {caption="[Shell 8] Sidecar Proxy 간 응답 Header 확인"}
$ kubectl logs mock-server -c istio-proxy | sed -n '/encoding headers via codec/,/thread=/p'
```

```text {caption="[Text 6] mock-server istio-proxy의 shell istio-proxy 전송 응답 Header"}
encoding headers via codec (end_stream=false):
':status', '200'
'content-type', 'application/json'
'x-envoy-upstream-service-time', '7'
'x-envoy-peer-metadata-id', 'sidecar~10.244.1.8~mock-server.default~default.svc.cluster.local'
'x-envoy-peer-metadata', 'ChoKCkNMVVNURVJfSUQSDBoKS3ViZXJuZXRlcwqFAQoGTEFCRUxTEnsqeQ...'
'server', 'istio-envoy'
```

[Shell 8]과 같이 `mock-server` istio-proxy가 `shell` istio-proxy에게 전송하는 응답 Header를 확인한다. App Container가 전송한 응답에는 `content-type`과 같은 기본 Header만 존재하지만, [Text 6]와 같이 `mock-server` istio-proxy를 거치면서 다음의 Header들이 추가된 것을 확인할 수 있다.

* `x-envoy-upstream-service-time` : `mock-server` istio-proxy가 `mock-server` Container로 요청을 전송한 이후 응답을 받을 때까지의 시간 (Millisecond)을 나타낸다. `mock-server` Container의 처리 시간을 의미한다.
* `x-envoy-peer-metadata`, `x-envoy-peer-metadata-id` : 요청과 반대 방향으로 `mock-server` Workload의 Metadata가 설정된다.
* `server` : 응답을 처리한 Proxy 정보 (`istio-envoy`)를 나타낸다.

#### 1.3.6. Client 수신 응답 Header Case (shell istio-proxy → shell)

```shell {caption="[Shell 9] Client 수신 응답 Header 확인"}
$ kubectl logs shell -c istio-proxy | sed -n '/encoding headers via codec/,/thread=/p'
```

```text {caption="[Text 7] shell istio-proxy의 shell 전송 응답 Header"}
encoding headers via codec (end_stream=false):
':status', '200'
'content-type', 'application/json'
'date', 'Sun, 30 Aug 2026 09:04:14 GMT'
'content-length', '59'
'x-envoy-upstream-service-time', '11'
'server', 'envoy'
```

[Shell 9]과 같이 `shell` istio-proxy가 `shell` Container에게 전달하는 응답 Header를 확인한다. 이 Header가 `shell` Container의 `curl`이 실제로 수신하는 응답 Header이다. [Text 7]과 같이 Sidecar Proxy 사이에서만 교환되는 Metadata Exchange Header는 제거되고, 다음의 Header들이 변경된 것을 확인할 수 있다.

* `x-envoy-upstream-service-time` : `shell` istio-proxy가 측정한 값으로 덮어써진다. Client 측 Sidecar Proxy가 `mock-server` Pod로 요청을 전송한 이후 응답을 받을 때까지의 시간 (Millisecond)을 나타내며, 두 Pod 사이의 Network Latency와 Server 측 Sidecar Proxy, App Container의 처리 시간이 모두 포함된다.
* `server` : Server 측 Sidecar Proxy가 설정한 `istio-envoy` 값이 `envoy` 값으로 변경되어 Client에게 전달된다.

### 1.4. Ingress Gateway Cases

Mesh 외부에서 Ingress Gateway를 통해서 유입되는 요청의 Header를 확인한다. Ingress Gateway 관련 Header (`x-forwarded-for`, `x-envoy-external-address`)와 `use_remote_address`, `xff_num_trusted_hops` 설정은 모두 Protocol과 무관한 HTTP Connection Manager 수준의 동작이기 때문에 HTTP 요청으로만 확인하며, gRPC 요청의 경우에도 동일하게 동작한다.

Mesh 외부에서 Ingress Gateway로의 접근은 `kubectl port-forward`를 이용한다. 이 경우 Ingress Gateway가 인식하는 직접 연결된 Client의 IP 주소가 실제 외부 IP가 아니라 Loopback 또는 Pod IP (Internal 주소)가 된다는 점을 감안하고 결과를 해석해야 한다.

#### 1.4.1. Ingress Gateway 경유 요청 Header Case

```shell {caption="[Shell 10] Ingress Gateway 경유 요청 전송"}
# Port forward ingress gateway
$ kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80

# Send request from outside of the mesh
$ curl -s -H "Host: mock-server.example.com" localhost:8080/status/200

# Check headers sent to app container
$ kubectl logs mock-server -c istio-proxy | sed -n '/router decoding headers/,/thread=/p'
```

```text {caption="[Text 8] Ingress Gateway 경유 mock-server 전송 요청 Header"}
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

[Shell 10]과 같이 [File 3]의 Gateway, Virtual Service를 통해서 Mesh 외부에서 Ingress Gateway를 경유하여 `mock-server`에 접근하고, App Container에게 전송되는 요청 Header를 확인한다. [Text 8]는 Mesh 내부 요청과 비교하여 다음의 차이를 나타내고 있다.

* `x-forwarded-for` : Ingress Gateway가 직접 연결된 Client의 IP 주소를 XFF Header에 추가한 것을 확인할 수 있다. Mesh 내부의 Sidecar Proxy는 XFF Header를 추가하지 않지만, Ingress Gateway는 `use_remote_address` 설정이 `true`이기 때문에 XFF Header를 추가한다.
* `x-forwarded-client-cert` (XFCC) : Ingress Gateway와 `mock-server`의 Sidecar Proxy 사이에는 mTLS가 적용되기 때문에, `URI` Key에 Ingress Gateway의 SPIFFE ID (`spiffe://cluster.local/ns/istio-system/sa/istio-ingressgateway-service-account`)가 설정된다. 즉 App 입장에서 XFCC로 확인할 수 있는 Identity는 원본 Client가 아니라 Ingress Gateway이다.
* `x-envoy-internal` : `true`로 설정되어 있는데, 이는 `kubectl port-forward` 특성상 Ingress Gateway에 직접 연결된 Client의 주소가 Internal 주소 (Pod IP)이기 때문이다. 실제 환경에서 외부 Client가 공인 IP로 접근하는 경우에는 External 요청으로 판단된다.

#### 1.4.2. use_remote_address 기본값 Case

```shell {caption="[Shell 11] use_remote_address 설정 확인"}
# Ingress gateway
$ kubectl exec -n istio-system deploy/istio-ingressgateway -- pilot-agent request GET config_dump | grep use_remote_address

# Sidecar proxy
$ kubectl exec shell -c istio-proxy -- pilot-agent request GET config_dump | grep use_remote_address
```

```text {caption="[Text 9] use_remote_address 기본값 확인 결과"}
# Ingress Gateway
"use_remote_address": true

# Sidecar Proxy
"use_remote_address": false
```

Envoy의 `use_remote_address` 설정은 신뢰할 수 있는 Client의 IP 주소와 Internal/External 요청 판단의 기준을 결정하며, Istio는 Proxy의 역할에 따라서 이 설정을 다르게 구성한다. Istio는 이 설정을 변경하는 정식 API를 제공하지 않는다. [Shell 11]와 같이 Envoy의 Config Dump를 통해서 확인하면, [Text 9]과 같이 **Ingress Gateway는 `true`, Sidecar Proxy는 `false`**로 설정되어 있다. 이 차이로 인해서 앞의 Case들에서 확인한 동작 차이가 발생한다.

* Sidecar Proxy (`false`) : 직접 연결된 Client (App Container)의 주소를 신뢰하지 않고 XFF Header만을 기반으로 판단한다. App이 전송하는 요청에는 XFF Header가 없기 때문에 External 요청으로 판단되어 제어 Header가 제거된다. XFF Header에 주소를 추가하지도 않는다.
* Ingress Gateway (`true`) : Mesh의 Edge에 위치하기 때문에 직접 연결된 Client의 주소를 신뢰한다. 직접 연결된 주소를 XFF Header에 추가하며, 요청에 XFF Header가 존재하지 않으면 직접 연결된 주소를 기반으로 Internal/External을 판단하고, XFF Header가 존재하면 External 요청으로 판단한다.

#### 1.4.3. xff_num_trusted_hops 설정 Case

```yaml {caption="[File 4] Ingress Gateway numTrustedProxies Manifest", linenos=table}
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

[File 4]는 Ingress Gateway의 `numTrustedProxies` 설정을 `1`로 변경하는 Manifest를 나타내고 있다. Istio는 `gatewayTopology.numTrustedProxies` 설정을 통해서 Envoy의 `xff_num_trusted_hops` 설정을 변경한다. Ingress Gateway 앞에 신뢰할 수 있는 Proxy (AWS ALB, Nginx 등)가 존재하는 환경을 의미한다.

```shell {caption="[Shell 12] xff_num_trusted_hops 설정 요청 전송"}
# Send request with pre-populated XFF header (simulating a front proxy)
$ curl -s -H "Host: mock-server.example.com" -H "X-Forwarded-For: 1.2.3.4, 5.6.7.8" localhost:8080/status/200

# Check headers sent to app container
$ kubectl logs mock-server -c istio-proxy | sed -n '/router decoding headers/,/thread=/p'
```

```text {caption="[Text 10] xff_num_trusted_hops 설정 mock-server 전송 요청 Header"}
# Before (numTrustedProxies: 0, default)
'x-forwarded-for', '1.2.3.4, 5.6.7.8,10.244.2.7'
'x-envoy-external-address', '127.0.0.1'

# After (numTrustedProxies: 1)
'x-forwarded-for', '1.2.3.4, 5.6.7.8,10.244.1.10'
'x-envoy-external-address', '5.6.7.8'
```

[Shell 12]과 같이 XFF Header에 두 개의 주소 (`1.2.3.4, 5.6.7.8`)를 설정한 요청을 전송하고, App Container에게 전송되는 요청 Header를 설정 전/후로 비교한다. [Text 10]은 설정 전/후의 결과를 나타내고 있다.

* 설정 전 (`numTrustedProxies: 0`) : XFF Header의 주소를 신뢰하지 않고, 직접 연결된 Client의 주소 (`127.0.0.1`)가 신뢰할 수 있는 Client의 IP 주소로 판단되어 `x-envoy-external-address` Header에 설정된다.
* 설정 후 (`numTrustedProxies: 1`) : Ingress Gateway 앞에 신뢰할 수 있는 Proxy가 1개 존재한다고 가정하기 때문에, XFF Header의 가장 오른쪽 주소 (`5.6.7.8`)가 신뢰할 수 있는 Proxy가 설정한 신뢰할 수 있는 Client의 IP 주소로 판단되어 `x-envoy-external-address` Header에 설정된다. Client가 임의로 설정한 `1.2.3.4` 값은 신뢰되지 않는다.

## 2. 참조

* Envoy Header : [https://ssup2.github.io/blog-software/docs/theory-analysis/envoy-header/](https://ssup2.github.io/blog-software/docs/theory-analysis/envoy-header/)
* Envoy Header Manipulation : [https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_conn_man/headers](https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_conn_man/headers)
* Istio Distributed Tracing : [https://istio.io/latest/docs/tasks/observability/distributed-tracing/overview/](https://istio.io/latest/docs/tasks/observability/distributed-tracing/overview/)
* Envoy x-forwarded-client-cert : [https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_conn_man/headers#x-forwarded-client-cert](https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_conn_man/headers#x-forwarded-client-cert)
* Istio Gateway Network Topology : [https://istio.io/latest/docs/ops/configuration/traffic-management/network-topologies/](https://istio.io/latest/docs/ops/configuration/traffic-management/network-topologies/)
* Istio Mutual TLS Migration : [https://istio.io/latest/docs/tasks/security/authentication/mtls-migration/](https://istio.io/latest/docs/tasks/security/authentication/mtls-migration/)

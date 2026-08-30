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
    env:
    - name: LOG_HEADERS
      value: "true"
    ports:
    - containerPort: 8080
    - containerPort: 9090
    securityContext:
      capabilities:
        add: ["NET_ADMIN"]
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

[File 1]은 `mock-server` Workload의 Manifest를 나타내고 있다. `mock-server` Image를 이용하여 `mock-server` Pod을 생성하며, `8080` Port를 열어서 HTTP 서비스를 제공하고, `9090` Port를 열어서 gRPC 서비스를 제공한다. `LOG_HEADERS` 환경 변수를 `true`로 설정하여 `mock-server`가 수신하는 모든 요청의 Header를 Container Log로 출력하도록 설정되어 있다.

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
    securityContext:
      capabilities:
        add: ["NET_ADMIN"]
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

각 구간별로 Header를 확인하는 방법은 다음과 같다.

* Client가 수신하는 응답 Header : `shell` Pod에서 `curl` 명령어의 `-v` 옵션 또는 `grpcurl` 명령어의 `-vv` 옵션을 이용하여 응답의 Header와 Trailer를 확인한다.
* Server가 수신하는 요청 Header : `mock-server`는 `LOG_HEADERS` 환경 변수가 `true`로 설정된 경우 수신하는 모든 요청의 Header를 Log로 출력한다. 따라서 `mock-server` Container의 Log를 통해서 App Container가 실제로 수신하는 요청 Header를 확인할 수 있다. Sidecar Proxy가 제거한 Header는 App Container에게 전달되지 않기 때문에 Log에도 나타나지 않는다.
* Sidecar Proxy 사이의 Header : Sidecar Proxy 사이의 구간은 mTLS로 암호화되어 있기 때문에 `tcpdump`로 Header를 확인할 수 없다. 대신 Envoy의 Log Level을 `debug`로 변경하면 Envoy가 송수신하는 Header 전체를 Log로 확인할 수 있다.

```shell {caption="[Shell 2] Header 확인 명령어"}
# Client response headers
$ kubectl exec -it shell -- curl -v mock-server:8080/status/200
$ kubectl exec -it shell -- grpcurl -vv -plaintext -d '{"code": 0}' mock-server:9090 mock.MockService/Status

# Request headers received by server (mock-server container log)
$ kubectl logs mock-server -c mock-server -f

# Headers between sidecar proxies (envoy debug log)
$ istioctl proxy-config log mock-server --level http:debug
$ kubectl logs mock-server -c istio-proxy -f
```

[Shell 2]는 각 구간별 Header 확인 명령어를 나타내고 있다.

### 1.2. Header 처리의 주요 특징

각 Case를 살펴보기 전에, Istio 환경에서 Sidecar Proxy의 Header 처리와 관련된 일반적인 특징은 다음과 같다.

* Tracing Header 미생성 : Istio `1.22` Version부터 Tracing이 기본적으로 비활성화되어 있기 때문에, `x-b3-traceid`, `x-b3-spanid`와 같은 Tracing Header는 생성되지 않는다. Mesh Config를 통해서 Tracing을 활성화한 경우에만 설정된다.
* Sidecar Proxy 간 전용 Header 제거 : `x-envoy-peer-metadata`, `x-envoy-peer-metadata-id`, `x-envoy-decorator-operation` Header는 Sidecar Proxy 사이에서만 교환되며, App Container에게 전달되기 전에 제거된다. (1.3.3 Case에서 확인)
* 제어 Header 기본 미동작 : App이 요청에 설정하는 `x-envoy-upstream-rq-timeout-ms`, `x-envoy-retry-on`과 같은 제어 Header는 기본적으로 동작하지 않는다. Sidecar Proxy의 `use_remote_address` 설정이 `false`이고 App이 전송하는 요청에는 XFF Header가 존재하지 않기 때문에, Sidecar Proxy는 요청을 External 요청으로 판단하여 `x-envoy-` Prefix의 제어 Header를 제거한다. 따라서 요청에 XFF Header와 하나의 Internal 주소를 함께 설정하여 Internal 요청으로 판단되도록 만들어야 제어 Header가 동작한다. (1.3.4, 1.3.5 Case에서 확인)

### 1.3. HTTP Cases

#### 1.3.1. Server 수신 요청 Header Case

```shell {caption="[Shell 3] HTTP 요청 전송"}
$ kubectl exec -it shell -- curl -s mock-server:8080/status/200
$ kubectl logs mock-server -c mock-server
```

```text {caption="[Text 1] mock-server App Container 수신 요청 Header"}
[mock-server] HTTP GET /status/200 127.0.0.6:49151
[mock-server] HTTP header Accept: */*
[mock-server] HTTP header User-Agent: curl/8.21.0
[mock-server] HTTP header X-Envoy-Attempt-Count: 1
[mock-server] HTTP header X-Forwarded-Client-Cert: By=spiffe://cluster.local/ns/default/sa/default;Hash=a6410c85...;Subject="";URI=spiffe://cluster.local/ns/default/sa/default
[mock-server] HTTP header X-Forwarded-Proto: http
[mock-server] HTTP header X-Request-Id: b21e2d12-3239-95a8-8c54-938ad101ab83
```

[Shell 3]과 같이 `shell` Pod에서 `mock-server`로 HTTP 요청을 전송하고, `mock-server`의 App Container가 실제로 수신하는 요청 Header를 확인한다. [Text 1]은 App Container가 수신한 요청 Header를 나타내고 있다. `curl`은 `Host`, `User-Agent`, `Accept` Header만 전송했지만, Sidecar Proxy를 거치면서 다음의 Header들이 추가된 것을 확인할 수 있다.

* `x-request-id` : Client 측 Sidecar Proxy가 생성한 UUID 값이 Server까지 전파된다.
* `x-forwarded-proto` : Client와 Sidecar Proxy 사이의 Protocol (`http`)을 나타낸다.
* `x-forwarded-client-cert` (XFCC) : mTLS를 통해서 전달된 Client의 SPIFFE ID를 나타낸다.
* `x-envoy-attempt-count` : 요청의 시도 횟수를 나타낸다. 재시도가 없는 경우 `1`이다.

#### 1.3.2. Client 수신 응답 Header Case

```shell {caption="[Shell 4] HTTP 응답 Header 확인"}
$ kubectl exec -it shell -- curl -v mock-server:8080/status/200
```

```text {caption="[Text 2] Client 수신 응답 Header"}
> GET /status/200 HTTP/1.1
> Host: mock-server:8080
> User-Agent: curl/8.21.0
> Accept: */*
>
< HTTP/1.1 200 OK
< content-type: application/json
< date: Sat, 29 Aug 2026 16:16:15 GMT
< content-length: 59
< x-envoy-upstream-service-time: 53
< server: envoy
```

[Shell 4]와 같이 `shell` Pod에서 `curl` 명령어의 `-v` 옵션을 이용하여 Client가 수신하는 응답 Header를 확인한다. [Text 2]는 Client가 수신한 응답 Header를 나타내고 있다.

* `x-envoy-upstream-service-time` : Sidecar Proxy가 Upstream으로 요청을 전송한 이후 응답을 받을 때까지 소요된 시간 (Millisecond)을 나타낸다.
* `server` : Server 측 Sidecar Proxy는 응답에 `server: istio-envoy` Header를 설정하지만 (1.3.3의 [Text 3]에서 확인 가능), Client 측 Sidecar Proxy를 거치면서 `envoy` 값으로 변경되어 Client에게 전달된다.

#### 1.3.3. Sidecar Proxy 간 Metadata Exchange Header Case

```shell {caption="[Shell 5] Envoy Debug Log 설정 및 요청 전송"}
$ istioctl proxy-config log mock-server --level http:debug
$ kubectl exec -it shell -- curl -s mock-server:8080/status/200
$ kubectl logs mock-server -c istio-proxy | grep -A 15 "request headers complete"
```

```text {caption="[Text 3] mock-server istio-proxy 수신 요청 Header (Debug Log)"}
request headers complete (end_stream=true):
':authority', 'mock-server:8080'
':path', '/status/200'
':method', 'GET'
'user-agent', 'curl/8.21.0'
'accept', '*/*'
'x-forwarded-proto', 'http'
'x-request-id', '9461e9ba-ba6b-924f-8cbd-f8a1ec35be61'
'x-envoy-decorator-operation', 'mock-server.default.svc.cluster.local:8080/*'
'x-envoy-peer-metadata-id', 'sidecar~10.244.2.3~shell.default~default.svc.cluster.local'
'x-envoy-peer-metadata', 'ChoKCkNMVVNURVJfSUQSDBoKS3ViZXJuZXRlcwp5CgZMQUJFTFMSbypt...'
'x-envoy-attempt-count', '1'

encoding headers via codec (end_stream=false):
':status', '200'
'content-type', 'application/json'
'x-envoy-upstream-service-time', '1'
'x-envoy-peer-metadata-id', 'sidecar~10.244.1.8~mock-server.default~default.svc.cluster.local'
'x-envoy-peer-metadata', 'ChoKCkNMVVNURVJfSUQSDBoKS3ViZXJuZXRlcwqFAQoGTEFCRUxTEnsqeQ...'
'server', 'istio-envoy'
```

```text {caption="[Text 4] x-envoy-peer-metadata Decoding 결과"}
$ echo "ChoKCkNMVVNURVJfSUQSDBoKS3ViZXJuZXRlcwp5..." | base64 -d | strings
CLUSTER_ID / Kubernetes
LABELS / app: shell / service.istio.io/canonical-name: shell / ...
NAME / shell
NAMESPACE / default
OWNER / kubernetes://apis/apps/v1/namespaces/default/pods/shell
WORKLOAD_NAME / shell
```

[Shell 5]와 같이 Envoy의 Log Level을 `debug`로 변경하고 Sidecar Proxy 사이에서만 교환되는 Header를 확인한다. [Text 3]은 `mock-server`의 Sidecar Proxy가 수신한 요청 Header와 App의 응답에 설정하는 Header를 나타내고 있다. App Container가 수신하는 요청 ([Text 1])과 비교하면 다음의 Header들이 Sidecar Proxy 구간에만 존재하는 것을 확인할 수 있다.

* `x-envoy-peer-metadata`, `x-envoy-peer-metadata-id` : Client Workload의 Metadata를 나타낸다. [Text 4]는 `x-envoy-peer-metadata` 값을 Decoding한 결과를 나타내고 있으며, Workload의 이름, Namespace, Label, Owner 정보가 포함되어 있다. 응답에는 반대로 `mock-server` Workload의 Metadata가 설정되며, 양쪽 Sidecar Proxy는 이러한 Metadata 교환을 통해서 `source_workload`, `destination_workload`와 같은 Istio Metric의 Label을 설정한다. Metadata Exchange Header는 Sidecar Proxy 사이에서만 교환되며, App Container에게 전달되기 전에 제거된다.
* `x-envoy-decorator-operation` : Client 측 Sidecar Proxy가 Route 설정을 기반으로 설정한 Tracing Span의 Operation 이름 (`mock-server.default.svc.cluster.local:8080/*`)을 나타낸다. 이 Header도 App Container에게 전달되기 전에 제거된다.

#### 1.3.4. Timeout 제어 Header Case

```shell {caption="[Shell 6] Timeout 제어 Header 설정 요청"}
# Without XFF header
$ kubectl exec -it shell -- curl -v -H "x-envoy-upstream-rq-timeout-ms: 1000" mock-server:8080/delay/3000

# With single internal XFF address
$ kubectl exec -it shell -- curl -v -H "X-Forwarded-For: 10.244.2.3" -H "x-envoy-upstream-rq-timeout-ms: 1000" mock-server:8080/delay/3000
```

```text {caption="[Text 5] Timeout 제어 Header 응답"}
# Without XFF header -> External 요청으로 판단되어 Timeout Header가 제거됨
< HTTP/1.1 200 OK
< x-envoy-upstream-service-time: 3037

# With single internal XFF address -> Internal 요청으로 판단되어 Timeout Header가 동작함
< HTTP/1.1 504 Gateway Timeout
< server: envoy
```

[Shell 6]과 같이 App이 요청에 `x-envoy-upstream-rq-timeout-ms` Header를 설정하여 Virtual Service 설정 없이 요청 단위로 Timeout을 제어할 수 있는지 확인한다. [Text 5]는 Timeout 제어 Header를 설정한 요청의 응답을 나타내고 있다. **XFF Header 없이 요청을 전송하는 경우 Timeout이 동작하지 않는다.** Envoy는 `use_remote_address` 설정이 `false`인 경우 (Sidecar Proxy의 기본값) XFF Header에 정확히 하나의 Internal 주소가 존재해야 Internal 요청으로 판단하는데, App이 전송하는 요청에는 XFF Header가 존재하지 않기 때문에 External 요청으로 판단되어 `x-envoy-` Prefix의 제어 Header가 제거되기 때문이다. 실제로 `mock-server`의 App Container가 수신한 요청에도 Timeout Header가 존재하지 않는 것을 확인할 수 있다.

반면 XFF Header에 Internal 주소 (Pod IP) 하나를 함께 설정하면 Internal 요청으로 판단되어 Timeout Header가 동작하며, `mock-server`의 `/delay/3000` Endpoint가 3초 후에 응답하기 때문에 1초의 Timeout이 적용되어 `504` Status Code가 응답된다. Client 측 Sidecar Proxy의 Access Log에서도 `UT` (UpstreamRequestTimeout) Response Flag와 `1003ms`의 Duration을 확인할 수 있다.

#### 1.3.5. Retry 제어 Header Case

```shell {caption="[Shell 7] Retry 제어 Header 설정 요청"}
$ kubectl exec -it shell -- curl -v -H "X-Forwarded-For: 10.244.2.3" -H "x-envoy-retry-on: 5xx" -H "x-envoy-max-retries: 3" mock-server:8080/status/503
$ kubectl logs mock-server -c mock-server
```

```text {caption="[Text 6] Retry 제어 Header 결과"}
# With XFF + x-envoy-retry-on: 5xx + x-envoy-max-retries: 3 -> 4 attempts
[mock-server] HTTP GET /status/503 127.0.0.6:58851
[mock-server] HTTP header X-Envoy-Attempt-Count: 1
[mock-server] HTTP header X-Envoy-Internal: true
[mock-server] HTTP header X-Forwarded-For: 10.244.2.3
...
[mock-server] HTTP header X-Envoy-Attempt-Count: 2
...
[mock-server] HTTP header X-Envoy-Attempt-Count: 3
...
[mock-server] HTTP header X-Envoy-Attempt-Count: 4

# Without XFF -> retry headers sanitized -> single attempt
[mock-server] HTTP GET /status/503 127.0.0.6:48411
[mock-server] HTTP header X-Envoy-Attempt-Count: 1
```

[Shell 7]과 같이 App이 요청에 `x-envoy-retry-on`, `x-envoy-max-retries` Header를 설정하여 요청 단위로 재시도를 제어할 수 있는지 확인하며, 1.3.4와 동일한 이유로 XFF Header에 Internal 주소를 함께 설정해야 동작한다. [Text 6]은 Retry 제어 Header를 설정한 요청의 결과를 나타내고 있다. Istio의 기본 재시도 조건 (`connect-failure,refused-stream,unavailable,cancelled`)에는 `5xx`가 포함되어 있지 않기 때문에 `503` Status Code는 기본적으로 재시도되지 않지만, `x-envoy-retry-on: 5xx` Header를 설정하면 재시도가 수행된다. `x-envoy-max-retries: 3` 설정에 의해서 최대 4번의 요청이 전송되며, `mock-server`가 수신하는 요청의 `x-envoy-attempt-count` Header 값이 `1`부터 `4`까지 증가하는 것을 확인할 수 있다.

또한 Internal 요청으로 판단되었기 때문에 `x-envoy-internal: true` Header가 설정되어 App Container까지 전달되는 것도 확인할 수 있다. XFF Header 없이 전송한 경우에는 재시도 Header가 제거되어 한 번의 요청만 전송된다.

### 1.4. GRPC Cases

#### 1.4.1. 요청, 응답 Header와 Trailer Case

```shell {caption="[Shell 8] gRPC 응답 Header, Trailer 확인"}
$ kubectl exec -it shell -- grpcurl -vv -plaintext -d '{"code": 0}' mock-server:9090 mock.MockService/Status
$ kubectl exec -it shell -- grpcurl -vv -plaintext -d '{"code": 13}' mock-server:9090 mock.MockService/Status
$ kubectl logs mock-server -c mock-server
```

```text {caption="[Text 7] gRPC 정상 응답의 Header, Trailer"}
Response headers received:
content-type: application/grpc
date: Sat, 29 Aug 2026 16:21:54 GMT
server: envoy
x-envoy-upstream-service-time: 3

Response contents:
{
  "service": "mock-server",
  "message": "OK"
}

Response trailers received:
(empty)
```

```text {caption="[Text 8] gRPC Error 응답의 Header, Trailer (Trailers-Only)"}
ERROR:
  Code: Internal
  Message: Simulated error with gRPC code 13 (Internal)

Response headers received:
(empty)

Response trailers received:
content-type: application/grpc
date: Sat, 29 Aug 2026 16:23:32 GMT
server: envoy
x-envoy-upstream-service-time: 6
```

```text {caption="[Text 9] mock-server App Container 수신 gRPC Metadata"}
[mock-server] gRPC /mock.MockService/Status
[mock-server] gRPC header :authority: mock-server:9090
[mock-server] gRPC header content-type: application/grpc
[mock-server] gRPC header grpc-accept-encoding: gzip
[mock-server] gRPC header user-agent: grpcurl/v1.9.3 grpc-go/1.61.0
[mock-server] gRPC header x-envoy-attempt-count: 1
[mock-server] gRPC header x-forwarded-client-cert: By=spiffe://cluster.local/ns/default/sa/default;Hash=a6410c85...;URI=spiffe://cluster.local/ns/default/sa/default
[mock-server] gRPC header x-forwarded-proto: http
[mock-server] gRPC header x-request-id: 4be797af-4796-9d45-82d9-31d80236967e
```

[Shell 8]과 같이 `shell` Pod에서 `grpcurl` 명령어의 `-vv` 옵션을 이용하여 gRPC 요청의 응답 Header와 Trailer를 확인한다. [Text 7]은 정상 응답의 Header와 Trailer를 나타내고 있다. 응답 Header에 HTTP Case와 동일하게 `x-envoy-upstream-service-time`, `server` Header가 설정되며, Trailer에는 `grpc-status` 외의 추가 Metadata가 없기 때문에 `grpcurl`은 빈 Trailer로 표시한다.

[Text 8]은 Error 응답 (gRPC Status Code `INTERNAL (13)`)을 나타내고 있다. 전송할 Message가 없는 Error 응답이기 때문에 **Trailers-Only** 형태로 응답되며, 정상 응답에서 Header 위치에 있던 Field들이 모두 Trailer 위치에서 표시되는 것을 확인할 수 있다.

[Text 9]는 App Container가 수신한 gRPC Metadata를 나타내고 있다. gRPC는 HTTP/2 기반으로 동작하기 때문에 HTTP Case ([Text 1])와 동일한 Envoy Header들이 설정되며, gRPC Library는 `:authority` Pseudo-Header와 `content-type`, `grpc-accept-encoding` Header도 Metadata로 노출한다.

#### 1.4.2. grpc-timeout Header Case

```shell {caption="[Shell 9] gRPC Deadline 설정 요청"}
$ istioctl proxy-config log mock-server --level http:debug
$ kubectl exec -it shell -- grpcurl -vv -plaintext -max-time 1 -d '{"milliseconds": 3000}' mock-server:9090 mock.MockService/Delay
$ kubectl logs mock-server -c istio-proxy | grep -A 16 "mock.MockService/Delay"
```

```text {caption="[Text 10] grpc-timeout Header 결과"}
# grpcurl result
ERROR:
  Code: DeadlineExceeded
  Message: context deadline exceeded

# mock-server istio-proxy debug log
request headers complete (end_stream=false):
':method', 'POST'
':scheme', 'http'
':path', '/mock.MockService/Delay'
':authority', 'mock-server:9090'
'content-type', 'application/grpc'
'te', 'trailers'
'grpc-timeout', '970m'
'x-request-id', '78abf552-1bac-9dc7-a591-030ca2784e62'
'x-envoy-expected-rq-timeout-ms', '970'
'x-envoy-attempt-count', '1'
```

[Shell 9]와 같이 `grpcurl` 명령어의 `-max-time` 옵션을 이용하여 gRPC Client의 Deadline이 `grpc-timeout` Header로 전파되는지 확인한다. [Text 10]은 gRPC Client가 1초의 Deadline을 설정한 요청의 결과를 나타내고 있다.

* Client가 설정한 Deadline은 `grpc-timeout: 970m` Header로 전파된다. (전송 시점까지의 경과 시간을 제외한 970 Millisecond)
* Sidecar Proxy는 `grpc-timeout` Header를 요청의 Timeout으로 활용하며, `x-envoy-expected-rq-timeout-ms: 970` Header를 추가로 설정하여 Upstream에게 Timeout 값을 전파하는 것을 확인할 수 있다.
* App Container의 Metadata Log에는 `grpc-timeout` Header가 나타나지 않는데, 이는 gRPC Library (grpc-go)가 예약된 Header인 `grpc-timeout`을 Metadata가 아니라 Context의 Deadline으로 변환하여 App에게 제공하기 때문이다.

#### 1.4.3. gRPC Retry 제어 Header Case

```shell {caption="[Shell 10] gRPC Retry 제어 Header 설정 요청"}
$ kubectl exec -it shell -- grpcurl -plaintext -H 'x-forwarded-for: 10.244.2.3' -H 'x-envoy-retry-grpc-on: internal' -H 'x-envoy-max-retries: 3' -d '{"code": 13}' mock-server:9090 mock.MockService/Status
$ kubectl logs mock-server -c mock-server
```

```text {caption="[Text 11] gRPC Retry 제어 Header 결과"}
# Without retry header -> single attempt
[mock-server] gRPC header x-envoy-attempt-count: 1

# With x-forwarded-for + x-envoy-retry-grpc-on: internal + x-envoy-max-retries: 3 -> 4 attempts
[mock-server] gRPC header x-envoy-attempt-count: 1
[mock-server] gRPC header x-envoy-attempt-count: 2
[mock-server] gRPC header x-envoy-attempt-count: 3
[mock-server] gRPC header x-envoy-attempt-count: 4
```

[Shell 10]과 같이 App이 요청에 `x-envoy-retry-grpc-on` Header를 설정하여 gRPC 요청 단위로 재시도를 제어할 수 있는지 확인한다. HTTP Case와 동일하게 XFF Header에 Internal 주소를 함께 설정해야 동작하며, Istio의 기본 재시도 조건에 포함되어 있지 않은 `internal` 조건 (gRPC Status Code `INTERNAL (13)`)을 이용한다. [Text 11]은 gRPC Retry 제어 Header를 설정한 요청의 결과를 나타내고 있다. `INTERNAL (13)` gRPC Status Code는 기본적으로 재시도되지 않지만, `x-envoy-retry-grpc-on: internal` Header를 설정하면 최대 4번의 요청이 전송되는 것을 확인할 수 있다.

### 1.5. mTLS Cases

mTLS 적용 유무에 따라서 변화하는 Header를 확인한다. mTLS 관련 Header (`x-forwarded-client-cert`, `x-envoy-peer-metadata`)는 Protocol과 무관한 연결 수준에서 설정되는 Header이기 때문에 HTTP 요청으로만 확인하며, gRPC 요청의 경우에도 동일하게 동작한다.

#### 1.5.1. mTLS 적용 Case

```shell {caption="[Shell 11] mTLS 적용 상태 요청 전송"}
$ kubectl exec -it shell -- curl -s mock-server:8080/status/200
$ kubectl logs mock-server -c mock-server
```

```text {caption="[Text 12] mTLS 적용 상태 App 수신 요청 Header"}
[mock-server] HTTP GET /status/200 127.0.0.6:58851
[mock-server] HTTP header X-Forwarded-Client-Cert: By=spiffe://cluster.local/ns/default/sa/default;Hash=a6410c85...;Subject="";URI=spiffe://cluster.local/ns/default/sa/default
[mock-server] HTTP header X-Forwarded-Proto: http
[mock-server] HTTP header X-Request-Id: 0399dd5b-ba8b-9b22-b66d-924a10e6f292
...
```

Istio는 기본적으로 Sidecar Proxy 사이에 mTLS를 적용한다 (`PERMISSIVE` Mode + Auto mTLS). [Shell 11]과 같이 mTLS가 적용된 상태에서 `mock-server`의 App Container가 수신하는 요청 Header를 확인하면, [Text 12]와 같이 `x-forwarded-client-cert` (XFCC) Header가 설정되어 있는 것을 확인할 수 있다. 각 Key의 의미는 다음과 같다.

* `By` : 현재 Proxy (`mock-server`의 Sidecar Proxy) 인증서의 URI SAN (SPIFFE ID)을 나타낸다.
* `Hash` : Client 인증서의 SHA256 Hash 값을 나타낸다.
* `Subject` : Client 인증서의 Subject를 나타낸다. Istio가 발급하는 인증서에는 Subject가 존재하지 않기 때문에 빈 값이다.
* `URI` : Client 인증서의 URI SAN (SPIFFE ID)을 나타낸다. `shell` Pod가 default Namespace의 `default` Service Account로 동작하기 때문에 `spiffe://cluster.local/ns/default/sa/default` 값이 설정되며, App은 이 값을 통해서 요청을 전송한 Client의 Identity를 확인할 수 있다. Istio Authorization Policy의 `source.principals` 조건도 이 값을 기반으로 동작한다.

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

```shell {caption="[Shell 12] mTLS 미적용 상태 요청 전송 및 Packet Capture"}
# Capture plaintext traffic between sidecar proxies from shell pod
$ kubectl exec -it shell -c shell -- tcpdump -i eth0 -A -s 0 'tcp port 8080'

# Send request and check headers received by server
$ kubectl exec -it shell -- curl -s mock-server:8080/status/200
$ kubectl logs mock-server -c mock-server
```

```text {caption="[Text 13] mTLS 미적용 상태 App 수신 요청 Header"}
[mock-server] HTTP GET /status/200 127.0.0.6:60681
[mock-server] HTTP header Accept: */*
[mock-server] HTTP header User-Agent: curl/8.21.0
[mock-server] HTTP header X-Envoy-Attempt-Count: 1
[mock-server] HTTP header X-Forwarded-Proto: http
[mock-server] HTTP header X-Request-Id: 79dbc3bb-9fb0-9086-9396-738c845d3238
```

```text {caption="[Text 14] mTLS 미적용 상태 Sidecar Proxy 간 요청 Header (tcpdump)"}
shell.40420 > 10-244-1-8.mock-server...8080: GET /status/200 HTTP/1.1
x-forwarded-proto: http
x-request-id: a4188fda-81aa-938d-a1e7-f846b86a9bea
x-envoy-peer-metadata-id: sidecar~10.244.2.3~shell.default~default.svc.cluster.local
x-envoy-peer-metadata: ChoKCkNMVVNURVJfSUQSDBoKS3ViZXJuZXRlcwp5CgZMQUJFTFMSbypt...

(response)
x-envoy-peer-metadata-id: sidecar~10.244.1.8~mock-server.default~default.svc.cluster.local
x-envoy-peer-metadata: ChoKCkNMVVNURVJfSUQSDBoKS3ViZXJuZXRlcwqFAQoGTEFCRUxTEnsqeQ...
```

확인 결과는 다음과 같다.

* [Text 13]과 같이 App Container가 수신하는 요청에서 `x-forwarded-client-cert` (XFCC) Header가 사라진 것을 확인할 수 있다. XFCC Header는 mTLS 인증서 정보를 기반으로 설정되기 때문에 mTLS가 비활성화되면 설정되지 않는다.
* Sidecar Proxy 사이의 구간이 Plaintext로 전환되었기 때문에, [Text 14]와 같이 `tcpdump`를 통해서 Sidecar Proxy 사이에서 교환되는 `x-envoy-peer-metadata`, `x-envoy-peer-metadata-id` Header를 직접 확인할 수 있다. mTLS 비활성화 여부와 무관하게 Metadata Exchange는 동일하게 수행된다.

### 1.6. Ingress Gateway Cases

Mesh 외부에서 Ingress Gateway를 통해서 유입되는 요청의 Header를 확인한다. Ingress Gateway 관련 Header (`x-forwarded-for`, `x-envoy-external-address`)와 Header Sanitization, `use_remote_address`, `xff_num_trusted_hops` 설정은 모두 Protocol과 무관한 HTTP Connection Manager 수준의 동작이기 때문에 HTTP 요청으로만 확인하며, gRPC 요청의 경우에도 동일하게 동작한다.

Mesh 외부에서 Ingress Gateway로의 접근은 `kubectl port-forward`를 이용한다. 이 경우 Ingress Gateway가 인식하는 직접 연결된 Client의 IP 주소가 실제 외부 IP가 아니라 Loopback 또는 Pod IP (Internal 주소)가 된다는 점을 감안하고 결과를 해석해야 한다.

#### 1.6.1. Ingress Gateway 경유 요청 Header Case

```shell {caption="[Shell 13] Ingress Gateway 경유 요청 전송"}
# Port forward ingress gateway
$ kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80

# Send request from outside of the mesh
$ curl -v -H "Host: mock-server.example.com" localhost:8080/status/200

# Request headers received by server
$ kubectl logs mock-server -c mock-server
```

```text {caption="[Text 15] Ingress Gateway 경유 App 수신 요청 Header"}
[mock-server] HTTP GET /status/200 127.0.0.6:51661
[mock-server] HTTP header Accept: */*
[mock-server] HTTP header User-Agent: curl/8.7.1
[mock-server] HTTP header X-Envoy-Attempt-Count: 1
[mock-server] HTTP header X-Envoy-Internal: true
[mock-server] HTTP header X-Forwarded-Client-Cert: By=spiffe://cluster.local/ns/default/sa/default;Hash=14f4d966...;Subject="";URI=spiffe://cluster.local/ns/istio-system/sa/istio-ingressgateway-service-account
[mock-server] HTTP header X-Forwarded-For: 10.244.1.5
[mock-server] HTTP header X-Forwarded-Proto: http
[mock-server] HTTP header X-Request-Id: d3ceb4fc-6519-9059-af74-1a76cf06577e
```

[Shell 13]과 같이 [File 3]의 Gateway, Virtual Service를 통해서 Mesh 외부에서 Ingress Gateway를 경유하여 `mock-server`에 접근하고, `mock-server`의 App Container가 수신하는 요청 Header를 확인한다. [Text 15]는 Ingress Gateway를 경유한 요청을 App Container가 수신한 Header를 나타내고 있다.

* `x-forwarded-for` : Ingress Gateway가 직접 연결된 Client의 IP 주소를 XFF Header에 추가한 것을 확인할 수 있다. Mesh 내부의 Sidecar Proxy는 XFF Header를 추가하지 않지만 ([Text 1]에는 XFF가 없음), Ingress Gateway는 `use_remote_address` 설정이 `true`이기 때문에 XFF Header를 추가한다. (1.6.3 참조)
* `x-forwarded-client-cert` (XFCC) : Ingress Gateway와 `mock-server`의 Sidecar Proxy 사이에 mTLS가 적용되기 때문에, `URI` Key에 Ingress Gateway의 SPIFFE ID (`spiffe://cluster.local/ns/istio-system/sa/istio-ingressgateway-service-account`)가 설정된다. 즉 App 입장에서 XFCC로 확인할 수 있는 Identity는 원본 Client가 아니라 Ingress Gateway이다.
* `x-envoy-internal` : `true`로 설정되어 있는데, 이는 `kubectl port-forward` 특성상 Ingress Gateway에 직접 연결된 Client의 주소가 Internal 주소 (Pod IP)이기 때문이다. 실제 환경에서 외부 Client가 공인 IP로 접근하는 경우에는 External 요청으로 판단된다.

Client가 수신하는 응답에는 Mesh 내부와 다르게 `server: istio-envoy` Header가 설정된다. Ingress Gateway는 Client 측 Sidecar Proxy와 다르게 `server` Header를 `envoy` 값으로 변경하지 않기 때문이다.

#### 1.6.2. Header Sanitization Case

```shell {caption="[Shell 14] 외부 Client의 제어 Header 설정 요청"}
# A: Internal client (no XFF, direct address is a private IP via port-forward)
$ curl -o /dev/null -w "%{http_code} %{time_total}s\n" -H "Host: mock-server.example.com" -H "x-envoy-upstream-rq-timeout-ms: 1000" localhost:8080/delay/3000

# B: External client (XFF with a public IP)
$ curl -o /dev/null -w "%{http_code} %{time_total}s\n" -H "Host: mock-server.example.com" -H "X-Forwarded-For: 1.2.3.4" -H "x-envoy-upstream-rq-timeout-ms: 1000" localhost:8080/delay/3000
```

```text {caption="[Text 16] Header Sanitization 결과"}
# A: Internal 판단 -> Timeout Header 동작
504 1.046821s

# B: External 판단 -> Timeout Header 제거
200 3.023438s

# B의 App 수신 요청 Header (Timeout Header가 제거되고 External Address가 설정됨)
[mock-server] HTTP header X-Envoy-External-Address: 127.0.0.1
[mock-server] HTTP header X-Forwarded-For: 1.2.3.4,10.244.1.5
```

[Shell 14]와 같이 Mesh 외부의 Client가 `x-envoy-` Prefix의 제어 Header를 설정하여 전송하는 경우, Ingress Gateway가 해당 Header를 제거하는지 확인한다. `kubectl port-forward` 환경에서는 직접 연결된 Client의 주소가 Internal 주소로 인식되기 때문에, XFF Header에 공인 IP를 설정하여 External 요청 상황을 재현한다. [Text 16]은 Header Sanitization 결과를 나타내고 있다.

* A의 경우 Ingress Gateway가 직접 연결된 Client의 주소 (Internal 주소)를 기반으로 Internal 요청으로 판단하기 때문에, Timeout 제어 Header가 동작하여 `504` Status Code가 1초 만에 응답된다.
* B의 경우 요청에 XFF Header가 존재하기 때문에 External 요청으로 판단되며, **Timeout 제어 Header가 제거되어 동작하지 않고** 3초 후에 `200` Status Code가 응답된다. App Container가 수신한 요청에서도 `x-envoy-upstream-rq-timeout-ms` Header가 제거되어 있는 것을 확인할 수 있다.
* B의 경우 External 요청이기 때문에 `x-envoy-external-address` Header가 설정되며, 신뢰할 수 있는 Client의 IP 주소인 직접 연결된 주소 (`127.0.0.1`, port-forward의 Loopback 연결)가 설정된다. Client가 전송한 XFF Header의 `1.2.3.4` 값은 신뢰되지 않는다.

실제 환경에서 외부 Client가 공인 IP로 직접 접근하는 경우에는 XFF Header 유무와 무관하게 External 요청으로 판단되기 때문에, Mesh 외부의 Client는 `x-envoy-` Prefix의 제어 Header를 활용할 수 없다.

#### 1.6.3. use_remote_address 기본값 Case

```shell {caption="[Shell 15] use_remote_address 설정 확인"}
# Ingress gateway
$ kubectl exec -n istio-system deploy/istio-ingressgateway -- pilot-agent request GET config_dump | grep use_remote_address

# Sidecar proxy
$ kubectl exec shell -c istio-proxy -- pilot-agent request GET config_dump | grep use_remote_address
```

```text {caption="[Text 17] use_remote_address 기본값 확인 결과"}
# Ingress Gateway
"use_remote_address": true

# Sidecar Proxy
"use_remote_address": false
```

Envoy의 `use_remote_address` 설정은 신뢰할 수 있는 Client의 IP 주소와 Internal/External 요청 판단의 기준을 결정하며, Istio는 Proxy의 역할에 따라서 이 설정을 다르게 구성한다. Istio는 이 설정을 변경하는 정식 API를 제공하지 않는다. [Shell 15]와 같이 Envoy의 Config Dump를 통해서 확인하면, [Text 17]과 같이 **Ingress Gateway는 `true`, Sidecar Proxy는 `false`**로 설정되어 있다. 이 차이로 인해서 앞의 Case들에서 확인한 동작 차이가 발생한다.

* Sidecar Proxy (`false`) : 직접 연결된 Client (App Container)의 주소를 신뢰하지 않고 XFF Header만을 기반으로 판단한다. App이 전송하는 요청에는 XFF Header가 없기 때문에 External 요청으로 판단되어 제어 Header가 제거되며 (1.3.4), XFF Header에 Internal 주소를 설정해야 Internal 요청으로 판단된다. XFF Header에 주소를 추가하지도 않는다.
* Ingress Gateway (`true`) : Mesh의 Edge에 위치하기 때문에 직접 연결된 Client의 주소를 신뢰한다. 직접 연결된 주소를 XFF Header에 추가하며 (1.6.1), 요청에 XFF Header가 존재하지 않으면 직접 연결된 주소를 기반으로 Internal/External을 판단하고, XFF Header가 존재하면 External 요청으로 판단한다 (1.6.2).

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

```shell {caption="[Shell 16] xff_num_trusted_hops 설정 요청 전송"}
# Send request with pre-populated XFF header (simulating a front proxy)
$ curl -H "Host: mock-server.example.com" -H "X-Forwarded-For: 1.2.3.4, 5.6.7.8" localhost:8080/status/200

# Request headers received by server
$ kubectl logs mock-server -c mock-server
```

```text {caption="[Text 18] xff_num_trusted_hops 설정 App 수신 요청 Header"}
# Before (numTrustedProxies: 0, default)
[mock-server] HTTP header X-Envoy-External-Address: 127.0.0.1
[mock-server] HTTP header X-Forwarded-For: 1.2.3.4, 5.6.7.8,10.244.1.5

# After (numTrustedProxies: 1)
[mock-server] HTTP header X-Envoy-External-Address: 5.6.7.8
[mock-server] HTTP header X-Forwarded-For: 1.2.3.4, 5.6.7.8,10.244.1.9
```

[Text 18]은 XFF Header에 두 개의 주소 (`1.2.3.4, 5.6.7.8`)를 설정한 요청의 설정 전/후 결과를 나타내고 있다.

* 설정 전 (`numTrustedProxies: 0`) : XFF Header의 주소를 신뢰하지 않고, 직접 연결된 Client의 주소 (`127.0.0.1`)가 신뢰할 수 있는 Client의 IP 주소로 판단되어 `x-envoy-external-address` Header에 설정된다.
* 설정 후 (`numTrustedProxies: 1`) : Ingress Gateway 앞에 신뢰할 수 있는 Proxy가 1개 존재한다고 가정하기 때문에, XFF Header의 가장 오른쪽 주소 (`5.6.7.8`)가 신뢰할 수 있는 Proxy가 설정한 신뢰할 수 있는 Client의 IP 주소로 판단되어 `x-envoy-external-address` Header에 설정된다. Client가 임의로 설정한 `1.2.3.4` 값은 신뢰되지 않는다.

## 2. 참조

* Envoy Header : [https://ssup2.github.io/blog-software/docs/theory-analysis/envoy-header/](https://ssup2.github.io/blog-software/docs/theory-analysis/envoy-header/)
* Envoy Header Manipulation : [https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_conn_man/headers](https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_conn_man/headers)
* Istio Distributed Tracing : [https://istio.io/latest/docs/tasks/observability/distributed-tracing/overview/](https://istio.io/latest/docs/tasks/observability/distributed-tracing/overview/)
* Envoy x-forwarded-client-cert : [https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_conn_man/headers#x-forwarded-client-cert](https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_conn_man/headers#x-forwarded-client-cert)
* Istio Gateway Network Topology : [https://istio.io/latest/docs/ops/configuration/traffic-management/network-topologies/](https://istio.io/latest/docs/ops/configuration/traffic-management/network-topologies/)
* Istio Mutual TLS Migration : [https://istio.io/latest/docs/tasks/security/authentication/mtls-migration/](https://istio.io/latest/docs/tasks/security/authentication/mtls-migration/)

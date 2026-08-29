---
title: Istio Sidecar Proxy Header
draft: true
---

## 1. Istio Sidecar Proxy Header

Istio 환경에서 Sidecar Proxy가 설정하고 활용하는 Header를 살펴본다.

### 1.1. Test 환경 구성

Test 환경은 2개의 Worker Node로 구성되어 있고 각각의 Node에 Client 역할을 수행하는 `shell` Pod와 Server 역할을 수행하는 `mock-server` Pod가 위치한다. HTTP Protocol을 통해서 접근하는 경우에는 `shell` Pod 내부에서 `curl` 명령어를 이용하여 접근하고, gRPC Protocol을 통해서 접근하는 경우에는 `shell` Pod 내부에서 `grpcurl` 명령어를 이용하여 접근한다. Ingress Gateway Case (1.5)에서는 Mesh 외부에서 Ingress Gateway를 경유하여 `mock-server`에 접근한다.

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

[File 3]은 Mesh 외부에서 Ingress Gateway를 통해서 `mock-server`에 접근하기 위한 Gateway, Virtual Service Manifest를 나타내고 있다. Ingress Gateway 관련 Case (1.5)에서 이용한다.

#### 1.1.3. Header 확인 방법

각 구간별로 Header를 확인하는 방법은 다음과 같다.

* Client가 수신하는 응답 Header : `shell` Pod에서 `curl` 명령어의 `-v` 옵션 또는 `grpcurl` 명령어의 `-vv` 옵션을 이용하여 응답의 Header와 Trailer를 확인한다.
* Server App이 수신하는 요청 Header : `mock-server`는 `LOG_HEADERS` 환경 변수가 `true`로 설정된 경우 수신하는 모든 요청의 Header를 Log로 출력한다. 따라서 `mock-server` Container의 Log를 통해서 App Container가 실제로 수신하는 요청 Header를 확인할 수 있다. Sidecar Proxy가 제거한 Header는 App Container에게 전달되지 않기 때문에 Log에도 나타나지 않는다.
* Sidecar Proxy 사이의 Header : Sidecar Proxy 사이의 구간은 mTLS로 암호화되어 있기 때문에 `tcpdump`로 Header를 확인할 수 없다. 대신 Envoy의 Log Level을 `debug`로 변경하면 Envoy가 송수신하는 Header 전체를 Log로 확인할 수 있다.

```shell {caption="[Shell 2] Header 확인 명령어"}
# Client response headers
$ kubectl exec -it shell -- curl -v mock-server:8080/status/200
$ kubectl exec -it shell -- grpcurl -vv -plaintext -d '{"code": 0}' mock-server:9090 mock.MockService/Status

# Request headers received by server app (mock-server container log)
$ kubectl logs mock-server -c mock-server -f

# Headers between sidecar proxies (envoy debug log)
$ istioctl proxy-config log mock-server --level http:debug
$ kubectl logs mock-server -c istio-proxy -f
```

[Shell 2]는 각 구간별 Header 확인 명령어를 나타내고 있다.

### 1.2. HTTP Cases

#### 1.2.1. Server App 수신 요청 Header Case

`shell` Pod에서 `mock-server`로 HTTP 요청을 전송하고, `mock-server`의 App Container가 실제로 수신하는 요청 Header를 확인한다.

```shell {caption="[Shell 3] HTTP 요청 전송"}
$ kubectl exec -it shell -- curl -s mock-server:8080/status/200
$ kubectl logs mock-server -c mock-server
```

```text {caption="[Text 1] mock-server App Container 수신 요청 Header"}
(TODO: mock-server Container Log 추가)
```

확인 대상 Header는 다음과 같다.

* `x-request-id` : Client 측 Sidecar Proxy가 생성한 UUID 값이 Server까지 전파되는지 확인한다.
* `x-forwarded-proto` : Client와 Sidecar Proxy 사이의 Protocol을 확인한다.
* `x-forwarded-client-cert` (XFCC) : mTLS를 통해서 전달된 Client의 SPIFFE ID를 확인한다.
* `x-envoy-attempt-count` : 요청의 시도 횟수를 확인한다.
* `x-envoy-decorator-operation` : Server 측 Sidecar Proxy의 Route 설정에 의해서 결정된 Operation 이름을 확인한다.
* `x-b3-traceid`, `x-b3-spanid`, `x-b3-sampled` : Tracing Header의 존재 여부를 확인한다.

#### 1.2.2. Client 수신 응답 Header Case

`shell` Pod에서 `curl` 명령어의 `-v` 옵션을 이용하여 Client가 수신하는 응답 Header를 확인한다.

```shell {caption="[Shell 4] HTTP 응답 Header 확인"}
$ kubectl exec -it shell -- curl -v mock-server:8080/status/200
```

```text {caption="[Text 2] Client 수신 응답 Header"}
(TODO: curl -v 결과 추가)
```

확인 대상 Header는 다음과 같다.

* `x-envoy-upstream-service-time` : Sidecar Proxy가 Upstream으로 요청을 전송한 이후 응답을 받을 때까지 소요된 시간을 확인한다.
* `x-envoy-decorator-operation` : Server 측 Sidecar Proxy가 응답에 설정한 Operation 이름을 확인한다.
* `server` : 응답을 처리한 Server 정보 (`istio-envoy`)를 확인한다.

#### 1.2.3. Sidecar Proxy 간 Metadata Exchange Header Case

Envoy의 Log Level을 `debug`로 변경하고 Sidecar Proxy 사이에서만 교환되는 Metadata Exchange Header를 확인한다.

```shell {caption="[Shell 5] Envoy Debug Log 설정 및 요청 전송"}
$ istioctl proxy-config log mock-server --level http:debug
$ kubectl exec -it shell -- curl -s mock-server:8080/status/200
$ kubectl logs mock-server -c istio-proxy | grep -A 30 "request headers"
```

```text {caption="[Text 3] mock-server istio-proxy 수신 요청 Header (Debug Log)"}
(TODO: envoy debug log 결과 추가)
```

확인 대상 Header는 다음과 같다.

* `x-envoy-peer-metadata` : Client Workload의 Metadata (이름, Namespace, Label)가 Base64로 Encoding되어 전달되는지 확인한다.
* `x-envoy-peer-metadata-id` : Client Workload의 고유 ID를 확인한다.
* App Container가 수신하는 요청 ([Text 1])에는 Metadata Exchange Header가 제거되어 존재하지 않는 점을 확인한다.

#### 1.2.4. Timeout 제어 Header Case

App이 요청에 `x-envoy-upstream-rq-timeout-ms` Header를 설정하여 Virtual Service 설정 없이 요청 단위로 Timeout을 제어할 수 있는지 확인한다.

```shell {caption="[Shell 6] Timeout 제어 Header 설정 요청"}
$ kubectl exec -it shell -- curl -v -H "x-envoy-upstream-rq-timeout-ms: 1000" mock-server:8080/delay/3000
```

```text {caption="[Text 4] Timeout 제어 Header 응답"}
(TODO: 504 응답 결과 추가)
```

`mock-server`의 `/delay/3000` Endpoint는 3초 후에 응답하기 때문에, 1초의 Timeout이 적용되어 `504` Status Code와 `UT` Response Flag가 확인되어야 한다.

#### 1.2.5. Retry 제어 Header Case

App이 요청에 `x-envoy-retry-on`, `x-envoy-max-retries` Header를 설정하여 요청 단위로 재시도를 제어할 수 있는지 확인한다.

```shell {caption="[Shell 7] Retry 제어 Header 설정 요청"}
$ kubectl exec -it shell -- curl -v -H "x-envoy-retry-on: 5xx" -H "x-envoy-max-retries: 3" mock-server:8080/status/503
$ kubectl logs mock-server -c mock-server
```

```text {caption="[Text 5] Retry 제어 Header 결과"}
(TODO: mock-server Container Log의 x-envoy-attempt-count 결과 추가)
```

`mock-server`가 수신하는 요청의 `x-envoy-attempt-count` Header 값이 재시도마다 증가하여 최대 `4`까지 확인되어야 한다.

### 1.3. GRPC Cases

#### 1.3.1. 요청, 응답 Header와 Trailer Case

`shell` Pod에서 `grpcurl` 명령어의 `-vv` 옵션을 이용하여 gRPC 요청의 응답 Header와 Trailer를 확인한다.

```shell {caption="[Shell 8] gRPC 응답 Header, Trailer 확인"}
$ kubectl exec -it shell -- grpcurl -vv -plaintext -d '{"code": 0}' mock-server:9090 mock.MockService/Status
```

```text {caption="[Text 6] gRPC 응답 Header, Trailer"}
(TODO: grpcurl -vv 결과 추가)
```

응답 Header에서 `x-envoy-upstream-service-time` Header를 확인하고, Trailer에서 `grpc-status`, `grpc-message` Header를 확인한다.

#### 1.3.2. grpc-timeout Header Case

`grpcurl` 명령어의 `-max-time` 옵션을 이용하여 gRPC Client의 Deadline이 `grpc-timeout` Header로 전파되는지 확인한다.

```shell {caption="[Shell 9] gRPC Deadline 설정 요청"}
$ kubectl exec -it shell -- grpcurl -vv -plaintext -max-time 1 -d '{"delay_ms": 3000}' mock-server:9090 mock.MockService/Delay
$ kubectl logs mock-server -c mock-server
```

```text {caption="[Text 7] grpc-timeout Header 결과"}
(TODO: mock-server Container Log의 grpc-timeout Header, DeadlineExceeded 응답 결과 추가)
```

`mock-server`가 수신하는 요청의 `grpc-timeout` Header를 확인하고, Deadline 초과 시 `DEADLINE_EXCEEDED (4)` gRPC Status Code를 확인한다.

#### 1.3.3. gRPC Retry 제어 Header Case

App이 요청에 `x-envoy-retry-grpc-on` Header를 설정하여 gRPC 요청 단위로 재시도를 제어할 수 있는지 확인한다.

```shell {caption="[Shell 10] gRPC Retry 제어 Header 설정 요청"}
$ kubectl exec -it shell -- grpcurl -vv -plaintext -H "x-envoy-retry-grpc-on: unavailable" -H "x-envoy-max-retries: 3" -d '{"code": 14}' mock-server:9090 mock.MockService/Status
$ kubectl logs mock-server -c mock-server
```

```text {caption="[Text 8] gRPC Retry 제어 Header 결과"}
(TODO: mock-server Container Log의 x-envoy-attempt-count 결과 추가)
```

`mock-server`가 수신하는 요청의 `x-envoy-attempt-count` Header 값이 재시도마다 증가하는 것을 확인한다.

### 1.4. mTLS Cases

mTLS 적용 유무에 따라서 변화하는 Header를 확인한다. mTLS 관련 Header (`x-forwarded-client-cert`, `x-envoy-peer-metadata`)는 Protocol과 무관한 연결 수준에서 설정되는 Header이기 때문에 HTTP 요청으로만 확인하며, gRPC 요청의 경우에도 동일하게 동작한다.

#### 1.4.1. mTLS 적용 Case

Istio는 기본적으로 Sidecar Proxy 사이에 mTLS를 적용한다 (`PERMISSIVE` Mode + Auto mTLS). mTLS가 적용된 상태에서 `mock-server`의 App Container가 수신하는 요청 Header를 확인한다.

```shell {caption="[Shell 11] mTLS 적용 상태 요청 전송"}
$ kubectl exec -it shell -- curl -s mock-server:8080/status/200
$ kubectl logs mock-server -c mock-server
```

```text {caption="[Text 9] mTLS 적용 상태 App 수신 요청 Header"}
(TODO: mock-server Container Log 추가)
```

`x-forwarded-client-cert` (XFCC) Header에 Client (`shell` Pod)의 SPIFFE ID (`spiffe://cluster.local/ns/default/sa/default`)가 설정되어 있는 것을 확인한다.

#### 1.4.2. mTLS 미적용 Case

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
# Request headers received by server app
$ kubectl exec -it shell -- curl -s mock-server:8080/status/200
$ kubectl logs mock-server -c mock-server

# Headers between sidecar proxies (plaintext because mTLS is disabled)
$ kubectl exec -it mock-server -c mock-server -- tcpdump -i eth0 -A -s 0 port 8080
```

```text {caption="[Text 10] mTLS 미적용 상태 App 수신 요청 Header"}
(TODO: mock-server Container Log 추가)
```

```text {caption="[Text 11] mTLS 미적용 상태 Sidecar Proxy 간 요청 Header"}
(TODO: tcpdump 결과 추가)
```

확인 대상은 다음과 같다.

* App Container가 수신하는 요청에서 `x-forwarded-client-cert` (XFCC) Header가 존재하지 않는 것을 확인한다. XFCC Header는 mTLS 인증서 정보를 기반으로 설정되기 때문에 mTLS가 비활성화되면 설정되지 않는다.
* Sidecar Proxy 사이의 구간이 Plaintext로 전환되었기 때문에, `tcpdump`를 통해서 Sidecar Proxy 사이에서 교환되는 `x-envoy-peer-metadata`, `x-envoy-peer-metadata-id` Header를 직접 확인할 수 있다.

### 1.5. Ingress Gateway Cases

Mesh 외부에서 Ingress Gateway를 통해서 유입되는 요청의 Header를 확인한다. Ingress Gateway 관련 Header (`x-forwarded-for`, `x-envoy-external-address`)와 Header Sanitization, `use_remote_address`, `xff_num_trusted_hops` 설정은 모두 Protocol과 무관한 HTTP Connection Manager 수준의 동작이기 때문에 HTTP 요청으로만 확인하며, gRPC 요청의 경우에도 동일하게 동작한다.

#### 1.5.1. Ingress Gateway 경유 요청 Header Case

[File 3]의 Gateway, Virtual Service를 통해서 Mesh 외부에서 Ingress Gateway를 경유하여 `mock-server`에 접근하고, `mock-server`의 App Container가 수신하는 요청 Header를 확인한다.

```shell {caption="[Shell 13] Ingress Gateway 경유 요청 전송"}
# Port forward ingress gateway
$ kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80

# Send request from outside of the mesh
$ curl -v -H "Host: mock-server.example.com" localhost:8080/status/200

# Request headers received by server app
$ kubectl logs mock-server -c mock-server
```

```text {caption="[Text 12] Ingress Gateway 경유 App 수신 요청 Header"}
(TODO: mock-server Container Log 추가)
```

확인 대상 Header는 다음과 같다.

* `x-forwarded-for` : Ingress Gateway가 설정한 외부 Client의 IP 주소를 확인한다.
* `x-envoy-external-address` : External 요청으로 판단된 경우 설정되는 신뢰할 수 있는 Client의 IP 주소를 확인한다.
* `x-forwarded-client-cert` (XFCC) : Ingress Gateway와 `mock-server`의 Sidecar Proxy 사이에는 mTLS가 적용되기 때문에, XFCC Header의 `URI` Key에 Ingress Gateway의 SPIFFE ID (`spiffe://cluster.local/ns/istio-system/sa/istio-ingressgateway-service-account`)가 설정되어 있는 것을 확인한다.
* `x-envoy-internal` : Mesh 외부에서 유입된 요청이 Internal 요청으로 판단되는지 확인한다.

#### 1.5.2. Header Sanitization Case

Mesh 외부의 Client가 `x-envoy-` Prefix의 제어 Header를 설정하여 전송하는 경우, Ingress Gateway가 해당 Header를 제거하는지 확인한다.

```shell {caption="[Shell 14] 외부 Client의 제어 Header 설정 요청"}
$ curl -v -H "Host: mock-server.example.com" -H "x-envoy-upstream-rq-timeout-ms: 1000" localhost:8080/delay/3000
```

```text {caption="[Text 13] Header Sanitization 결과"}
(TODO: 응답 결과 및 mock-server 수신 요청 Header 추가)
```

Mesh 내부의 `shell` Pod에서 전송한 경우 (1.2.4)와 다르게 Timeout이 동작하지 않고 3초 후에 `200 OK` 응답이 확인되어야 하며, `mock-server`가 수신하는 요청에서도 `x-envoy-upstream-rq-timeout-ms` Header가 제거되어 있는 것을 확인한다.

#### 1.5.3. use_remote_address 설정 Case

```yaml {caption="[File 5] Ingress Gateway use_remote_address EnvoyFilter Manifest", linenos=table}
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: ingressgateway-use-remote-address
  namespace: istio-system
spec:
  workloadSelector:
    labels:
      istio: ingressgateway
  configPatches:
  - applyTo: NETWORK_FILTER
    match:
      listener:
        filterChain:
          filter:
            name: envoy.filters.network.http_connection_manager
    patch:
      operation: MERGE
      value:
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
          use_remote_address: true
```

[File 5]는 Ingress Gateway의 `use_remote_address` 설정을 `true`로 변경하는 EnvoyFilter Manifest를 나타내고 있다.

```shell {caption="[Shell 15] use_remote_address 설정 요청 전송"}
# Send request with fake XFF header
$ curl -v -H "Host: mock-server.example.com" -H "X-Forwarded-For: 1.2.3.4" localhost:8080/status/200

# Request headers received by server app
$ kubectl logs mock-server -c mock-server
```

```text {caption="[Text 14] use_remote_address 설정 App 수신 요청 Header"}
(TODO: 설정 전/후 mock-server Container Log 추가)
```

확인 대상은 다음과 같다.

* 설정 전 (`use_remote_address: false`) : Ingress Gateway는 직접 연결된 Client의 IP 주소를 신뢰하지 않고 XFF Header를 기반으로 신뢰할 수 있는 Client의 IP 주소를 판단한다. 따라서 Client가 전송한 `1.2.3.4` 값이 그대로 신뢰된다.
* 설정 후 (`use_remote_address: true`) : Ingress Gateway는 직접 연결된 Client의 IP 주소를 XFF Header에 추가하며, 신뢰할 수 있는 Client의 IP 주소도 직접 연결된 Client의 IP 주소로 판단한다. 따라서 Client가 전송한 `1.2.3.4` 값은 신뢰되지 않는다.

#### 1.5.4. xff_num_trusted_hops 설정 Case

```yaml {caption="[File 6] Ingress Gateway numTrustedProxies Manifest", linenos=table}
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

[File 6]은 Ingress Gateway의 `numTrustedProxies` 설정을 `1`로 변경하는 Manifest를 나타내고 있다. Istio는 `gatewayTopology.numTrustedProxies` 설정을 통해서 Envoy의 `xff_num_trusted_hops` 설정을 변경한다. Ingress Gateway 앞에 신뢰할 수 있는 Proxy (AWS ALB, Nginx 등)가 존재하는 환경을 의미한다.

```shell {caption="[Shell 16] xff_num_trusted_hops 설정 요청 전송"}
# Send request with pre-populated XFF header (simulating a front proxy)
$ curl -v -H "Host: mock-server.example.com" -H "X-Forwarded-For: 1.2.3.4, 5.6.7.8" localhost:8080/status/200

# Request headers received by server app
$ kubectl logs mock-server -c mock-server
```

```text {caption="[Text 15] xff_num_trusted_hops 설정 App 수신 요청 Header"}
(TODO: 설정 전/후 mock-server Container Log 추가)
```

확인 대상은 다음과 같다.

* 설정 전 (`numTrustedProxies: 0`) : XFF Header의 가장 오른쪽 주소 (`5.6.7.8`)가 신뢰할 수 있는 Client의 IP 주소로 판단된다.
* 설정 후 (`numTrustedProxies: 1`) : XFF Header의 오른쪽에서 두 번째 주소 (`1.2.3.4`)가 신뢰할 수 있는 Client의 IP 주소로 판단된다. 가장 오른쪽 주소는 신뢰할 수 있는 Proxy가 설정한 주소로 간주된다.

## 2. 참조

* Envoy Header : [https://ssup2.github.io/blog-software/docs/theory-analysis/envoy-header/](https://ssup2.github.io/blog-software/docs/theory-analysis/envoy-header/)
* Envoy Header Manipulation : [https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_conn_man/headers](https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_conn_man/headers)
* Istio Distributed Tracing : [https://istio.io/latest/docs/tasks/observability/distributed-tracing/overview/](https://istio.io/latest/docs/tasks/observability/distributed-tracing/overview/)
* Envoy x-forwarded-client-cert : [https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_conn_man/headers#x-forwarded-client-cert](https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_conn_man/headers#x-forwarded-client-cert)
* Istio Gateway Network Topology : [https://istio.io/latest/docs/ops/configuration/traffic-management/network-topologies/](https://istio.io/latest/docs/ops/configuration/traffic-management/network-topologies/)
* Istio Mutual TLS Migration : [https://istio.io/latest/docs/tasks/security/authentication/mtls-migration/](https://istio.io/latest/docs/tasks/security/authentication/mtls-migration/)

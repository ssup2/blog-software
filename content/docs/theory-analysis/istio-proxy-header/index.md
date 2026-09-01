---
title: Istio Proxy Header
---

## 1. Istio Proxy Header

Istio 환경에서 Sidecar Proxy와 Ingress Gateway가 설정하고 활용하는 Header를 살펴본다.

### 1.1. Test 환경 구성

{{< figure caption="[Figure 1] Test Environment" src="images/test-environment.png" width="1000px" >}}

[Figure 1]은 Istio Proxy Header Test 환경을 나타내고 있다. Test 환경은 Istio `1.24` Version을 기준으로 구성한다. 2개의 Worker Node로 구성되어 있고 각각의 Node에 Client 역할을 수행하는 `shell` Pod와 Server 역할을 수행하는 `mock-server` Pod가 위치한다. `shell` Pod 내부에서 `curl` 명령어를 이용하여 `mock-server`에 접근한다. Ingress Gateway Case (1.4)에서는 Mesh 외부에서 Ingress Gateway를 경유하여 `mock-server`에 접근한다.

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

# Install metallb
$ kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml

# Enable sidecar injection to default namespace
$ kubectl label namespace default istio-injection=enabled
```

[Shell 1]은 Kubernetes, Istio 환경을 구성하는 Script를 나타내고 있다. `kind`를 활용하여 Kubernetes Cluster를 구성하고 Istio를 설치한다. 그리고 default Namespace에 Sidecar Injection을 활성화한다. kind 환경에는 LoadBalancer Type의 Service에게 External IP를 할당하는 Component가 존재하지 않기 때문에, istio-ingressgateway Service의 External IP 할당을 위해서 MetalLB도 함께 설치한다.

```yaml {caption="[File 1] MetalLB IPAddressPool, L2Advertisement Manifest", linenos=table}
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: kind-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.97.200-192.168.97.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: kind-l2
  namespace: metallb-system
spec:
  ipAddressPools:
  - kind-pool
```

[File 1]은 MetalLB의 IP Pool 설정을 나타내고 있다. kind Node가 연결되어 있는 Docker Network의 대역 (`192.168.97.0/24`) 중 일부를 Pool로 설정하여, Docker Network에 연결되어 있는 Host에서 External IP로 직접 접근할 수 있도록 구성한다. 설정 이후 istio-ingressgateway Service는 `192.168.97.200` External IP를 할당받는다.

```shell {caption="[Shell 2] External Client 환경 구성"}
# Preserve client ip by local external traffic policy
$ kubectl patch svc -n istio-system istio-ingressgateway -p '{"spec":{"externalTrafficPolicy":"Local"}}'

# Pretend the host has a public ip address (SNAT on every kind node)
$ for node in kind-control-plane kind-worker kind-worker2; do
    docker exec $node iptables -t nat -I POSTROUTING 1 -s 192.168.97.0 -p tcp --dport 8080 -j SNAT --to-source 203.0.113.9
  done

# Check external ip of istio-ingressgateway service
$ kubectl get svc -n istio-system istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
192.168.97.200
```

[Shell 2]는 Mesh 외부의 External Client 환경을 구성하는 Script를 나타내고 있다. Ingress Gateway로의 접근은 MetalLB가 할당한 External IP를 이용하며, kind Node와 같은 Docker Network에 연결되어 있는 Host에서 요청을 전송한다. Host의 주소는 사설 IP이기 때문에 그대로 접근하면 istio-ingressgateway가 요청을 Internal 요청으로 판단한다. 따라서 공인 IP를 이용하는 실제 External Client 환경을 재현하기 위해서, istio-ingressgateway Service에 `externalTrafficPolicy: Local`을 설정하여 Client의 주소를 보존하고, kind Node에서 SNAT를 통해서 Host의 주소를 공인 대역의 주소 (`203.0.113.9`)로 변환한다.

#### 1.1.2. Workload 구성

```yaml {caption="[File 2] mock-server Pod Manifest", linenos=table}
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

[File 2]은 `mock-server` Workload의 Manifest를 나타내고 있다. `mock-server` Image를 이용하여 `mock-server` Pod을 생성하며, `8080` Port를 열어서 HTTP 서비스를 제공한다.

```yaml {caption="[File 3] shell Pod Manifest", linenos=table}
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

[File 3]는 Client 역할을 수행하는 `shell` Pod의 Manifest를 나타내고 있다.

```yaml {caption="[File 4] mock-server Gateway, Virtual Service Manifest", linenos=table}
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

[File 4]은 Mesh 외부에서 Ingress Gateway를 통해서 `mock-server`에 접근하기 위한 Gateway, Virtual Service Manifest를 나타내고 있다. Ingress Gateway 관련 Case (1.4)에서 이용한다.

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

```shell {caption="[Shell 3] Header 확인 방법"}
# Enable trace log for http, router loggers
$ istioctl proxy-config log shell --level http:trace,router:trace
$ istioctl proxy-config log mock-server --level http:trace,router:trace
$ istioctl proxy-config log deploy/istio-ingressgateway -n istio-system --level http:trace,router:trace

# Send request
$ kubectl exec -it shell -- curl -s mock-server:8080/status/200

# Check headers in istio-proxy logs
$ kubectl logs shell -c istio-proxy -f
$ kubectl logs mock-server -c istio-proxy -f
$ kubectl logs -n istio-system deploy/istio-ingressgateway -f
```

[Shell 3]는 Header 확인 방법을 나타내고 있다. `curl` 명령어는 요청 전송 용도로만 이용하며, Header 확인은 모두 istio-proxy의 Log를 이용한다.

### 1.2. Header 처리의 주요 특징

각 Case를 살펴보기 전에, Istio 환경에서 Istio Proxy (Sidecar Proxy, Ingress Gateway)의 Header 처리와 관련된 일반적인 특징은 다음과 같다.

* Tracing Header 미생성 : Istio `1.22` Version부터 Tracing이 기본적으로 비활성화되어 있기 때문에, `x-b3-traceid`, `x-b3-spanid`와 같은 Tracing Header는 생성되지 않는다. Mesh Config를 통해서 Tracing을 활성화한 경우에만 설정된다.
* Istio Proxy 간 전용 Header 제거 : `x-envoy-peer-metadata`, `x-envoy-peer-metadata-id`, `x-envoy-decorator-operation` Header는 Istio Proxy 사이에서만 교환되며, Client와 Server의 Container에게 전달되기 전에 제거된다.
* gRPC 요청의 동일 처리 : gRPC는 HTTP/2를 기반으로 동작하기 때문에 gRPC 요청에도 HTTP 요청과 동일한 Header 처리가 적용된다. gRPC Client가 Deadline을 설정한 경우 전파되는 `grpc-timeout` Header는 Istio Proxy가 요청의 Timeout으로 활용하며, `x-envoy-expected-rq-timeout-ms` Header로 변환되어 Upstream에게 전파된다.
* External 요청 판단 (`x-envoy-internal: false`) : Istio Proxy는 기본적으로 요청을 External 요청으로 판단하며, `x-envoy-internal` Header가 `false`인 상태로 동작한다. Sidecar Proxy는 Envoy의 `use_remote_address` 설정이 `false`이고 Client가 전송하는 요청에 XFF Header가 존재하지 않기 때문에 요청을 External 요청으로 판단하며, Ingress Gateway는 직접 연결된 Client의 주소가 공인 대역이기 때문에 요청을 External 요청으로 판단한다.
* 제어 Header 미동작 : 요청이 External 요청으로 판단되기 때문에, Client가 요청에 설정하는 `x-envoy-upstream-rq-timeout-ms`, `x-envoy-retry-on`과 같은 `x-envoy-` Prefix의 제어 Header는 Istio Proxy가 제거하여 동작하지 않는다. 따라서 Timeout과 재시도는 제어 Header가 아니라 Virtual Service를 통해서 설정해야 한다.

### 1.3. Sidecar Proxy Cases

{{< figure caption="[Figure 2] Sidecar Proxy Case" src="images/sidecar-proxy-case.png" width="1000px" >}}

```shell {caption="[Shell 4] HTTP 요청 전송"}
$ kubectl exec -it shell -- curl -s mock-server:8080/status/200
```

[Figure 2]는 Sidecar Proxy Case에서 요청과 응답이 각 구간을 거치면서 추가되는 Header를 나타내고 있으며, 각 번호는 이후 살펴보는 Case의 순서를 나타낸다. [Shell 4]과 같이 `shell` Pod에서 `mock-server`로 하나의 HTTP 요청을 전송하고, 요청과 응답이 흐르는 순서대로 각 구간의 Header를 istio-proxy의 Log를 통해서 확인한다. 요청은 `shell` Container → `shell` istio-proxy → `mock-server` istio-proxy → `mock-server` Container 순서로 3개의 구간을 거치며, 응답은 반대 순서로 전달된다. 각 구간의 Header 처리는 Protocol과 무관하게 동작하기 때문에 HTTP 요청으로만 확인하며, gRPC 요청의 경우에도 동일하게 동작한다.

#### 1.3.1. Client 전송 요청 Header Case (shell → shell istio-proxy)

```shell {caption="[Shell 5] Client 전송 요청 Header 확인"}
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

[Shell 5]와 같이 `shell` istio-proxy가 `shell` Container로부터 수신한 요청 Header를 확인한다. [Text 1]과 같이 `curl`이 전송한 `Host`, `User-Agent`, `Accept` Header만 존재하며, 아직 Istio 관련 Header는 존재하지 않는다.

#### 1.3.2. Sidecar Proxy 간 요청 Header Case (shell istio-proxy → mock-server istio-proxy)

```shell {caption="[Shell 6] Sidecar Proxy 간 요청 Header 확인"}
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

[Shell 6]와 같이 `shell` istio-proxy가 `mock-server` istio-proxy에게 전송하는 요청 Header를 확인한다. [Text 2]와 같이 `shell` istio-proxy를 거치면서 다음의 Header들이 추가된 것을 확인할 수 있다.

* `x-forwarded-proto` : Client와 Sidecar Proxy 사이의 Protocol (`http`)을 나타낸다.
* `x-request-id` : Client 측 Sidecar Proxy가 생성한 요청의 고유한 UUID 값을 나타낸다.
* `x-envoy-attempt-count` : 요청의 시도 횟수를 나타낸다. 재시도가 없는 경우 `1`이다.
* `x-envoy-decorator-operation` : Client 측 Sidecar Proxy가 Route 설정을 기반으로 설정한 Tracing Span의 Operation 이름을 나타낸다.
* `x-envoy-peer-metadata`, `x-envoy-peer-metadata-id` : Client Workload의 Metadata를 나타낸다. [Text 3]은 `x-envoy-peer-metadata` 값을 Decoding한 결과를 나타내고 있으며, Workload의 이름, Namespace, Label, Owner 정보가 포함되어 있다. 양쪽 Sidecar Proxy는 Metadata 교환을 통해서 `source_workload`, `destination_workload`와 같은 Istio Metric의 Label을 설정한다.

#### 1.3.3. Server 수신 요청 Header Case (mock-server istio-proxy → mock-server)

```shell {caption="[Shell 7] Server 수신 요청 Header 확인"}
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

[Shell 7]과 같이 `mock-server` istio-proxy가 `mock-server` Container에게 전송하는 요청 Header를 확인한다. 이 Header가 `mock-server` Container가 실제로 수신하는 요청 Header이다. [Text 4]와 같이 Sidecar Proxy 사이에서만 교환되는 `x-envoy-decorator-operation`, `x-envoy-peer-metadata`, `x-envoy-peer-metadata-id` Header는 제거되고, `x-forwarded-client-cert` (XFCC) Header가 추가된 것을 확인할 수 있다. XFCC Header는 mTLS를 통해서 전달된 Client의 인증서 정보를 나타내며, 각 Key의 의미는 다음과 같다.

* `By` : 현재 Proxy (`mock-server`의 Sidecar Proxy) 인증서의 URI SAN (SPIFFE ID)을 나타낸다. `mock-server` Pod가 `default` Namespace의 `default` Service Account로 동작하기 때문에 `spiffe://cluster.local/ns/default/sa/default` 값이 설정된다.
* `Hash` : Client 인증서의 SHA256 Hash 값을 나타낸다.
* `Subject` : Client 인증서의 Subject를 나타낸다. Istio가 발급하는 인증서에는 Subject가 존재하지 않기 때문에 빈 값이다.
* `URI` : Client 인증서의 URI SAN (SPIFFE ID)을 나타낸다. `shell` Pod도 `default` Namespace의 `default` Service Account로 동작하기 때문에 `By` Key와 동일한 값이 설정되어 있으며, `mock-server` Container는 이 값을 통해서 요청을 전송한 Client의 Identity를 확인할 수 있다.

Istio는 기본적으로 Sidecar Proxy 사이에 mTLS를 적용하기 때문에 (`PERMISSIVE` Mode + Auto mTLS) XFCC Header도 기본적으로 설정된다. 반면 PeerAuthentication과 Destination Rule을 통해서 mTLS를 비활성화하면 인증서 정보가 존재하지 않기 때문에 XFCC Header도 설정되지 않는다. `URI` Key의 SPIFFE ID는 Istio Authorization Policy의 `source.principals` 조건 매칭에도 활용된다.

#### 1.3.4. Server 전송 응답 Header Case (mock-server → mock-server istio-proxy)

```shell {caption="[Shell 8] Server 전송 응답 Header 확인"}
$ kubectl logs mock-server -c istio-proxy | sed -n '/upstream response headers/,/thread=/p'
```

```text {caption="[Text 5] mock-server istio-proxy 수신 응답 Header"}
end_stream: false, upstream response headers:
':status', '200'
'content-type', 'application/json'
'content-length', '59'
```

[Shell 8]과 같이 `mock-server` istio-proxy가 `mock-server` Container로부터 수신한 응답 Header를 확인한다. [Text 5]와 같이 `mock-server` Container가 전송한 응답에는 `content-type`, `content-length`와 같은 기본 Header만 존재하며, 아직 Istio 관련 Header는 존재하지 않는다.

#### 1.3.5. Sidecar Proxy 간 응답 Header Case (mock-server istio-proxy → shell istio-proxy)

```shell {caption="[Shell 9] Sidecar Proxy 간 응답 Header 확인"}
$ kubectl logs mock-server -c istio-proxy | sed -n '/encoding headers via codec/,/thread=/p'
```

```text {caption="[Text 6] mock-server istio-proxy의 shell istio-proxy 전송 응답 Header"}
encoding headers via codec (end_stream=false):
':status', '200'
'content-type', 'application/json'
'x-envoy-upstream-service-time', '2'
'x-envoy-peer-metadata-id', 'sidecar~10.244.1.15~mock-server.default~default.svc.cluster.local'
'x-envoy-peer-metadata', 'ChoKCkNMVVNURVJfSUQSDBoKS3ViZXJuZXRlcwqFAQoGTEFCRUxTEnsqeQ...'
'server', 'istio-envoy'
```

[Shell 9]과 같이 `mock-server` istio-proxy가 `shell` istio-proxy에게 전송하는 응답 Header를 확인한다. `mock-server` Container가 전송한 응답에는 `content-type`과 같은 기본 Header만 존재하지만, [Text 6]와 같이 `mock-server` istio-proxy를 거치면서 다음의 Header들이 추가된 것을 확인할 수 있다.

* `x-envoy-upstream-service-time` : `mock-server` istio-proxy가 `mock-server` Container로 요청을 전송한 이후 응답을 받을 때까지의 시간 (Millisecond)을 나타낸다. `mock-server` Container의 처리 시간을 의미한다.
* `x-envoy-peer-metadata`, `x-envoy-peer-metadata-id` : 요청과 반대 방향으로 `mock-server` Workload의 Metadata가 설정된다.
* `server` : 응답을 처리한 Proxy 정보 (`istio-envoy`)를 나타낸다.

#### 1.3.6. Client 수신 응답 Header Case (shell istio-proxy → shell)

```shell {caption="[Shell 10] Client 수신 응답 Header 확인"}
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

[Shell 10]과 같이 `shell` istio-proxy가 `shell` Container에게 전달하는 응답 Header를 확인한다. 이 Header가 `shell` Container의 `curl`이 실제로 수신하는 응답 Header이다. [Text 7]과 같이 Sidecar Proxy 사이에서만 교환되는 Metadata Exchange Header는 제거되고, 다음의 Header들이 변경된 것을 확인할 수 있다.

* `x-envoy-upstream-service-time` : `shell` istio-proxy가 측정한 값으로 덮어써진다. Client 측 Sidecar Proxy가 `mock-server` Pod로 요청을 전송한 이후 응답을 받을 때까지의 시간 (Millisecond)을 나타내며, 두 Pod 사이의 Network Latency와 Server 측 Sidecar Proxy, `mock-server` Container의 처리 시간이 모두 포함된다.
* `server` : Server 측 Sidecar Proxy가 설정한 `istio-envoy` 값이 `envoy` 값으로 변경되어 Client에게 전달된다.

#### 1.3.7. Circuit Breaking 응답 Header Case (shell istio-proxy → shell)

```yaml {caption="[File 5] mock-server Destination Rule Manifest", linenos=table}
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: mock-server
spec:
  host: mock-server
  trafficPolicy:
    connectionPool:
      http:
        http2MaxRequests: 1
```

```shell {caption="[Shell 11] Circuit Breaking 응답 Header 확인"}
# Send two requests concurrently
$ kubectl exec shell -- curl -s mock-server:8080/delay/5000 &
$ kubectl exec shell -- curl -s mock-server:8080/delay/5000 &
upstream connect error or disconnect/reset before headers. reset reason: overflow
{"delayed_ms":5000,"message":"Response delayed by 5000ms","service":"mock-server"}

# Check headers in shell istio-proxy logs
$ kubectl logs shell -c istio-proxy | sed -n '/encoding headers via codec/,/thread=/p'
```

```text {caption="[Text 8] shell istio-proxy의 shell 전송 503 응답 Header"}
encoding headers via codec (end_stream=false):
':status', '503'
'x-envoy-overloaded', 'true'
'content-length', '81'
'content-type', 'text/plain'
'date', 'Tue, 01 Sep 2026 07:05:26 GMT'
'server', 'envoy'
```

[File 5]는 `mock-server`로의 동시 요청 개수를 1개로 제한하는 Destination Rule Manifest를 나타내고 있다. [Shell 11]과 같이 두 개의 요청을 동시에 전송하면 두번째 요청은 동시 요청 제한을 초과하기 때문에, `shell` istio-proxy는 Upstream Overflow로 판단하여 Circuit Breaking을 동작시키고 요청을 `mock-server` Pod에게 전달하지 않고 직접 `503 Service Unavailable` 응답을 생성한다.

[Text 8]과 같이 생성된 응답에는 `x-envoy-overloaded: true` Header가 설정된 것을 확인할 수 있으며, Client는 이 Header를 통해서 응답이 Server가 아니라 Circuit Breaking에 의해서 생성된 것을 구분할 수 있다.

유사하게 Rate Limit에 의해서 제한된 요청의 응답에 설정되는 `x-envoy-ratelimited` Header도 존재하지만, Envoy의 Global Rate Limit Filter만 설정하는 Header이기 때문에 EnvoyFilter를 통해서 별도의 Rate Limit Service를 연동하지 않는 기본 Istio 환경에서는 설정되지 않는다. EnvoyFilter를 통해서 설정하는 Local Rate Limit Filter의 경우에도 Istio `1.24`가 이용하는 Envoy `1.32` Version 기준으로 `x-envoy-ratelimited` Header를 설정하지 않는다.

### 1.4. Ingress Gateway Cases

{{< figure caption="[Figure 3] Ingress Gateway Case" src="images/ingressgateway-case.png" width="1000px" >}}

```shell {caption="[Shell 12] Ingress Gateway 경유 HTTP 요청 전송"}
$ curl -s -H "Host: mock-server.example.com" http://192.168.97.200/status/200
```

[Figure 3]는 Ingress Gateway Case에서 요청과 응답이 각 구간을 거치면서 추가되는 Header를 나타내고 있으며, 각 번호는 이후 살펴보는 Case의 순서를 나타낸다. [Shell 12]과 같이 [File 4]의 Gateway, Virtual Service를 통해서 Mesh 외부에서 Ingress Gateway를 경유하는 하나의 HTTP 요청을 전송하고, 요청과 응답이 흐르는 순서대로 각 구간의 Header를 istio-proxy의 Log를 통해서 확인한다. 요청은 External Client → istio-ingressgateway → `mock-server` istio-proxy → `mock-server` Container 순서로 3개의 구간을 거치며, 응답은 반대 순서로 전달된다. 각 구간의 Header 처리는 Protocol과 무관하게 동작하기 때문에 HTTP 요청으로만 확인하며, gRPC 요청의 경우에도 동일하게 동작한다.

#### 1.4.1. Client 전송 요청 Header Case (External Client → istio-ingressgateway)

```shell {caption="[Shell 13] Client 전송 요청 Header 확인"}
$ kubectl logs -n istio-system deploy/istio-ingressgateway | sed -n '/request headers complete/,/thread=/p'
```

```text {caption="[Text 9] istio-ingressgateway 수신 요청 Header"}
request headers complete (end_stream=true):
':authority', 'mock-server.example.com'
':path', '/status/200'
':method', 'GET'
'user-agent', 'curl/8.7.1'
'accept', '*/*'
```

[Shell 13]과 같이 istio-ingressgateway가 External Client로부터 수신한 요청 Header를 확인한다. [Text 9]과 같이 `curl`이 전송한 `Host`, `User-Agent`, `Accept` Header만 존재하며, 아직 Istio 관련 Header는 존재하지 않는다.

#### 1.4.2. Istio Proxy 간 요청 Header Case (istio-ingressgateway → mock-server istio-proxy)

```shell {caption="[Shell 14] Istio Proxy 간 요청 Header 확인"}
$ kubectl logs -n istio-system deploy/istio-ingressgateway | sed -n '/router decoding headers/,/thread=/p'
```

```text {caption="[Text 10] istio-ingressgateway의 mock-server istio-proxy 전송 요청 Header"}
router decoding headers:
':authority', 'mock-server.example.com'
':path', '/status/200'
':method', 'GET'
':scheme', 'http'
'user-agent', 'curl/8.7.1'
'accept', '*/*'
'x-forwarded-for', '203.0.113.9'
'x-forwarded-proto', 'http'
'x-envoy-external-address', '203.0.113.9'
'x-request-id', 'b06908b8-745a-9b2b-99c1-a6f570ce6627'
'x-envoy-decorator-operation', 'mock-server.default.svc.cluster.local:8080/*'
'x-envoy-peer-metadata-id', 'router~10.244.1.14~istio-ingressgateway-78c97cd8c9-p6qkv.istio-system~istio-system.svc.cluster.local'
'x-envoy-peer-metadata', 'ChoKCkNMVVNURVJfSUQSDBoKS3ViZXJuZXRlcwqZAQoGTEFCRUxTEo4BKosB...'
'x-envoy-attempt-count', '1'
```

[Shell 14]와 같이 istio-ingressgateway가 `mock-server` istio-proxy에게 전송하는 요청 Header를 확인한다. [Text 10]와 같이 Sidecar Proxy Case (1.3.2)와 동일하게 `x-request-id`, `x-envoy-decorator-operation`, `x-envoy-peer-metadata` Header가 추가되며, 다음의 차이가 존재한다.

* `x-forwarded-for` : istio-ingressgateway가 직접 연결된 External Client의 주소 (`203.0.113.9`)를 XFF Header에 추가한다. Sidecar Proxy는 XFF Header를 추가하지 않지만, istio-ingressgateway는 Envoy의 `use_remote_address` 설정이 `true`이기 때문에 XFF Header를 추가한다.
* `x-envoy-external-address` : 직접 연결된 External Client의 주소가 공인 대역이기 때문에 istio-ingressgateway는 요청을 External 요청으로 판단하며, 신뢰할 수 있는 Client의 IP 주소인 직접 연결된 주소 (`203.0.113.9`)를 설정한다. 반대로 Internal 요청으로 판단한 경우에는 `x-envoy-internal: true` Header가 설정된다.
* `x-envoy-peer-metadata-id` : Sidecar Proxy의 `sidecar~` Prefix와 다르게 `router~` Prefix와 함께 istio-ingressgateway Workload의 정보가 설정된다.

#### 1.4.3. Server 수신 요청 Header Case (mock-server istio-proxy → mock-server)

```shell {caption="[Shell 15] Server 수신 요청 Header 확인"}
$ kubectl logs mock-server -c istio-proxy | sed -n '/router decoding headers/,/thread=/p'
```

```text {caption="[Text 11] mock-server istio-proxy의 mock-server 전송 요청 Header"}
router decoding headers:
':authority', 'mock-server.example.com'
':path', '/status/200'
':method', 'GET'
':scheme', 'http'
'user-agent', 'curl/8.7.1'
'accept', '*/*'
'x-forwarded-for', '203.0.113.9'
'x-forwarded-proto', 'http'
'x-envoy-external-address', '203.0.113.9'
'x-request-id', 'b06908b8-745a-9b2b-99c1-a6f570ce6627'
'x-envoy-attempt-count', '1'
'x-forwarded-client-cert', 'By=spiffe://cluster.local/ns/default/sa/default;Hash=de4a0539...;Subject="";URI=spiffe://cluster.local/ns/istio-system/sa/istio-ingressgateway-service-account'
```

[Shell 15]과 같이 `mock-server` istio-proxy가 `mock-server` Container에게 전송하는 요청 Header를 확인한다. [Text 11]과 같이 Istio Proxy 간 전용 Header는 제거되고 XFCC Header가 추가되며, `x-forwarded-for`, `x-envoy-external-address` Header는 그대로 유지되어 전달된다. XFCC Header의 `URI` Key에는 istio-ingressgateway의 SPIFFE ID (`spiffe://cluster.local/ns/istio-system/sa/istio-ingressgateway-service-account`)가 설정된다. 즉 `mock-server` Container 입장에서 XFCC로 확인할 수 있는 Identity는 원본 Client가 아니라 istio-ingressgateway이다.

#### 1.4.4. Server 전송 응답 Header Case (mock-server → mock-server istio-proxy)

```shell {caption="[Shell 16] Server 전송 응답 Header 확인"}
$ kubectl logs mock-server -c istio-proxy | sed -n '/upstream response headers/,/thread=/p'
```

```text {caption="[Text 12] mock-server istio-proxy 수신 응답 Header"}
end_stream: false, upstream response headers:
':status', '200'
'content-type', 'application/json'
'content-length', '59'
```

[Shell 16]와 같이 `mock-server` istio-proxy가 `mock-server` Container로부터 수신한 응답 Header를 확인한다. Sidecar Proxy Case (1.3.4)와 동일하게 `mock-server` Container가 전송한 응답에는 기본 Header만 존재한다.

#### 1.4.5. Istio Proxy 간 응답 Header Case (mock-server istio-proxy → istio-ingressgateway)

```shell {caption="[Shell 17] Istio Proxy 간 응답 Header 확인"}
$ kubectl logs mock-server -c istio-proxy | sed -n '/encoding headers via codec/,/thread=/p'
```

```text {caption="[Text 13] mock-server istio-proxy의 istio-ingressgateway 전송 응답 Header"}
encoding headers via codec (end_stream=false):
':status', '200'
'content-type', 'application/json'
'x-envoy-upstream-service-time', '0'
'x-envoy-peer-metadata-id', 'sidecar~10.244.1.15~mock-server.default~default.svc.cluster.local'
'x-envoy-peer-metadata', 'ChoKCkNMVVNURVJfSUQSDBoKS3ViZXJuZXRlcwqFAQoGTEFCRUxTEnsqeQ...'
'server', 'istio-envoy'
```

[Shell 17]와 같이 `mock-server` istio-proxy가 istio-ingressgateway에게 전송하는 응답 Header를 확인한다. Sidecar Proxy Case (1.3.5)와 동일하게 `mock-server` Workload의 Metadata Header와 `x-envoy-upstream-service-time`, `server` Header가 추가된다.

#### 1.4.6. Client 수신 응답 Header Case (istio-ingressgateway → External Client)

```shell {caption="[Shell 18] Client 수신 응답 Header 확인"}
$ kubectl logs -n istio-system deploy/istio-ingressgateway | sed -n '/encoding headers via codec/,/thread=/p'
```

```text {caption="[Text 14] istio-ingressgateway의 External Client 전송 응답 Header"}
encoding headers via codec (end_stream=false):
':status', '200'
'content-type', 'application/json'
'date', 'Sun, 30 Aug 2026 16:29:30 GMT'
'content-length', '59'
'x-envoy-upstream-service-time', '2'
'server', 'istio-envoy'
```

[Shell 18]과 같이 istio-ingressgateway가 External Client에게 전달하는 응답 Header를 확인한다. [Text 14]과 같이 Istio Proxy 간 전용 Header는 제거되고, `x-envoy-upstream-service-time` Header는 istio-ingressgateway가 측정한 값 (`2`)으로 덮어써진다. Sidecar Proxy와 다르게 `server` Header는 `envoy` 값으로 변경되지 않고 `istio-envoy` 값이 그대로 전달된다.

#### 1.4.7. xff_num_trusted_hops 설정 Case

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

[File 6]는 Ingress Gateway의 `numTrustedProxies` 설정을 `1`로 변경하는 Manifest를 나타내고 있다. Istio는 `gatewayTopology.numTrustedProxies` 설정을 통해서 Envoy의 `xff_num_trusted_hops` 설정을 변경한다. Ingress Gateway 앞에 신뢰할 수 있는 Proxy (AWS ALB, Nginx 등)가 존재하는 환경을 의미한다.

```shell {caption="[Shell 19] xff_num_trusted_hops 설정 요청 전송"}
# Send request with pre-populated XFF header (simulating a front proxy)
$ curl -s -H "Host: mock-server.example.com" -H "X-Forwarded-For: 1.2.3.4, 5.6.7.8" http://192.168.97.200/status/200

# Check headers sent to app container
$ kubectl logs mock-server -c istio-proxy | sed -n '/router decoding headers/,/thread=/p'
```

```text {caption="[Text 15] xff_num_trusted_hops 설정 mock-server 전송 요청 Header"}
# Before (numTrustedProxies: 0, default)
'x-forwarded-for', '1.2.3.4, 5.6.7.8,203.0.113.9'
'x-envoy-external-address', '203.0.113.9'

# After (numTrustedProxies: 1)
'x-forwarded-for', '1.2.3.4, 5.6.7.8,203.0.113.9'
'x-envoy-external-address', '5.6.7.8'
```

[Shell 19]과 같이 XFF Header에 두 개의 주소 (`1.2.3.4, 5.6.7.8`)를 설정한 요청을 전송하고, `mock-server` Container에게 전송되는 요청 Header를 설정 전/후로 비교한다. [Text 15]은 설정 전/후의 결과를 나타내고 있다. 신뢰할 수 있는 Client의 IP 주소 판단은 Ingress Gateway가 수신한 시점의 XFF Header (`1.2.3.4, 5.6.7.8`)를 기준으로 수행되며, 판단 이후에 Ingress Gateway가 직접 연결된 External Client의 주소 (`203.0.113.9`)를 XFF Header에 추가하기 때문에 [Text 15]의 XFF Header 가장 오른쪽에는 두 경우 모두 `203.0.113.9`가 위치한다.

* 설정 전 (`numTrustedProxies: 0`) : XFF Header의 주소를 신뢰하지 않고, 직접 연결된 External Client의 주소 (`203.0.113.9`)가 신뢰할 수 있는 Client의 IP 주소로 판단되어 `x-envoy-external-address` Header에 설정된다.
* 설정 후 (`numTrustedProxies: 1`) : Ingress Gateway 앞에 신뢰할 수 있는 Proxy가 1개 존재한다고 가정하기 때문에, Ingress Gateway가 수신한 XFF Header의 가장 오른쪽 주소 (`5.6.7.8`)가 신뢰할 수 있는 Proxy가 설정한 신뢰할 수 있는 Client의 IP 주소로 판단되어 `x-envoy-external-address` Header에 설정된다. Client가 임의로 설정한 `1.2.3.4` 값은 신뢰되지 않는다.

## 2. 참조

* Envoy Header : [https://ssup2.github.io/blog-software/docs/theory-analysis/envoy-header/](https://ssup2.github.io/blog-software/docs/theory-analysis/envoy-header/)
* Envoy Header Manipulation : [https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_conn_man/headers](https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_conn_man/headers)
* Istio Distributed Tracing : [https://istio.io/latest/docs/tasks/observability/distributed-tracing/overview/](https://istio.io/latest/docs/tasks/observability/distributed-tracing/overview/)
* Envoy x-forwarded-client-cert : [https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_conn_man/headers#x-forwarded-client-cert](https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_conn_man/headers#x-forwarded-client-cert)
* Istio Gateway Network Topology : [https://istio.io/latest/docs/ops/configuration/traffic-management/network-topologies/](https://istio.io/latest/docs/ops/configuration/traffic-management/network-topologies/)
* Istio Mutual TLS Migration : [https://istio.io/latest/docs/tasks/security/authentication/mtls-migration/](https://istio.io/latest/docs/tasks/security/authentication/mtls-migration/)

---
title: Istio Proxy Header
---

## 1. Istio Proxy Header

This document examines the Headers that the Sidecar Proxy and Ingress Gateway set and utilize in an Istio environment.

### 1.1. Test Environment Setup

{{< figure caption="[Figure 1] Test Environment" src="images/test-environment.png" width="1000px" >}}

[Figure 1] shows the Istio Proxy Header test environment. The test environment is based on Istio version `1.24`. It consists of 2 Worker Nodes, each containing a `shell` Pod acting as a Client and a `mock-server` Pod acting as a Server. The `curl` command is used inside the `shell` Pod to access the `mock-server`. In the Ingress Gateway Cases (1.4), the `mock-server` is accessed from outside the Mesh via the Ingress Gateway.

#### 1.1.1. Kubernetes, Istio Environment Setup

```shell {caption="[Shell 1] Kubernetes, Istio Environment Setup"}
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

[Shell 1] shows the script for setting up the Kubernetes and Istio environment. A Kubernetes Cluster is created using `kind`, and Istio is installed. Then Sidecar Injection is enabled for the default Namespace. Since the kind environment does not have a component that assigns External IPs to LoadBalancer type Services, MetalLB is also installed to assign an External IP to the istio-ingressgateway Service.

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

[File 1] shows the IP Pool configuration of MetalLB. A part of the Docker Network range (`192.168.97.0/24`) to which the kind Nodes are connected is configured as the Pool, so that Hosts connected to the Docker Network can directly access the External IP. After configuration, the istio-ingressgateway Service is assigned the External IP `192.168.97.200`.

```shell {caption="[Shell 2] External Client Environment Setup"}
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

[Shell 2] shows the script for setting up the External Client environment outside the Mesh. Access to the Ingress Gateway uses the External IP assigned by MetalLB, and requests are sent from a Host connected to the same Docker Network as the kind Nodes. Since the Host's address is a private IP, istio-ingressgateway would judge the request as an Internal request if accessed as is. Therefore, to reproduce a real External Client environment using a public IP, `externalTrafficPolicy: Local` is set on the istio-ingressgateway Service to preserve the Client's address, and SNAT is performed on the kind Nodes to translate the Host's address to a public range address (`203.0.113.9`).

#### 1.1.2. Workload Setup

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

[File 2] shows the Manifest of the `mock-server` Workload. The `mock-server` Pod is created using the `mock-server` Image, and provides HTTP service by opening Port `8080`.

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

[File 3] shows the Manifest of the `shell` Pod acting as a Client.

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

[File 4] shows the Gateway and Virtual Service Manifest for accessing the `mock-server` through the Ingress Gateway from outside the Mesh. It is used in the Ingress Gateway related Cases (1.4).

#### 1.1.3. Header Verification Method

All Headers are verified through the **Logs of istio-proxy (Envoy)**. By changing the Log Level of Envoy's `http` and `router` Loggers to `trace`, all Headers of requests and responses processed by Envoy can be checked in the Logs, and each Logger outputs the following.

* `http` Logger : Outputs the request Headers received from the Downstream (`request headers complete`), the response Headers delivered to the Downstream (`encoding headers via codec`), and Trailers (`encoding trailers via codec`).
* `router` Logger : Outputs the request Headers sent to the Upstream (`router decoding headers`) and the response Headers received from the Upstream (`upstream response headers`).

Therefore, the Headers of all segments can be checked through the istio-proxy Logs of the Client side (`shell`) and the Server side (`mock-server`) as follows.

* Request Headers sent by the Client : `request headers complete` of `shell` istio-proxy
* Request Headers between Sidecar Proxies : `router decoding headers` of `shell` istio-proxy or `request headers complete` of `mock-server` istio-proxy
* Request Headers received by the Server : `router decoding headers` of `mock-server` istio-proxy
* Response Headers sent by the Server : `upstream response headers` of `mock-server` istio-proxy
* Response Headers between Sidecar Proxies : `encoding headers via codec` of `mock-server` istio-proxy
* Response Headers received by the Client : `encoding headers via codec` of `shell` istio-proxy

```shell {caption="[Shell 3] Header Verification Method"}
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

[Shell 3] shows the Header verification method. The `curl` command is used only for sending requests, and all Header verification uses the istio-proxy Logs.

### 1.2. Key Characteristics of Header Processing

Before examining each Case, the general characteristics related to Header processing of the Istio Proxy (Sidecar Proxy, Ingress Gateway) in an Istio environment are as follows.

* No Tracing Header Generation : Since Tracing is disabled by default from Istio version `1.22`, Tracing Headers such as `x-b3-traceid` and `x-b3-spanid` are not generated. They are set only when Tracing is enabled through the Mesh Config.
* Removal of Istio Proxy Dedicated Headers : The `x-envoy-peer-metadata`, `x-envoy-peer-metadata-id`, and `x-envoy-decorator-operation` Headers are exchanged only between Istio Proxies, and are removed before being delivered to the Client and Server Containers.
* Identical Processing of gRPC Requests : Since gRPC operates based on HTTP/2, the same Header processing as HTTP requests is applied to gRPC requests. The `grpc-timeout` Header, which is propagated when a gRPC Client sets a Deadline, is utilized by the Istio Proxy as the request Timeout, and is converted to the `x-envoy-expected-rq-timeout-ms` Header and propagated to the Upstream.
* External Request Judgment (`x-envoy-internal: false`) : The Istio Proxy judges requests as External requests by default, operating in a state where the `x-envoy-internal` Header is `false`. The Sidecar Proxy judges requests as External requests because Envoy's `use_remote_address` setting is `false` and requests sent by the Client do not contain an XFF Header, and the Ingress Gateway judges requests as External requests because the address of the directly connected Client is in the public range.
* Control Headers Not Working : Since requests are judged as External requests, control Headers with the `x-envoy-` Prefix such as `x-envoy-upstream-rq-timeout-ms` and `x-envoy-retry-on` that the Client sets in requests are removed by the Istio Proxy and do not work. Therefore, Timeout and Retry must be configured through the Virtual Service, not through control Headers.

### 1.3. Sidecar Proxy Cases

{{< figure caption="[Figure 2] Sidecar Proxy Case" src="images/sidecar-proxy-case.png" width="1000px" >}}

```shell {caption="[Shell 4] Sending HTTP Request"}
$ kubectl exec -it shell -- curl -s mock-server:8080/status/200
```

[Figure 2] shows the Headers added at each segment as the request and response pass through in the Sidecar Proxy Case, and each number indicates the order of the Cases examined below. As shown in [Shell 4], a single HTTP request is sent from the `shell` Pod to the `mock-server`, and the Headers of each segment are checked through the istio-proxy Logs in the order that the request and response flow. The request passes through 3 segments in the order of `shell` Container → `shell` istio-proxy → `mock-server` istio-proxy → `mock-server` Container, and the response is delivered in the reverse order. Since the Header processing of each segment operates regardless of the Protocol, it is verified only with an HTTP request, and it operates the same for gRPC requests.

#### 1.3.1. Client Sent Request Header Case (shell → shell istio-proxy)

```shell {caption="[Shell 5] Checking Client Sent Request Headers"}
$ kubectl logs shell -c istio-proxy | sed -n '/request headers complete/,/thread=/p'
```

```text {caption="[Text 1] Request Headers Received by shell istio-proxy"}
request headers complete (end_stream=true):
':authority', 'mock-server:8080'
':path', '/status/200'
':method', 'GET'
'user-agent', 'curl/8.21.0'
'accept', '*/*'
```

As shown in [Shell 5], the request Headers that the `shell` istio-proxy received from the `shell` Container are checked. As shown in [Text 1], only the `Host`, `User-Agent`, and `Accept` Headers sent by `curl` exist, and no Istio related Headers exist yet.

#### 1.3.2. Request Headers between Sidecar Proxies Case (shell istio-proxy → mock-server istio-proxy)

```shell {caption="[Shell 6] Checking Request Headers between Sidecar Proxies"}
$ kubectl logs shell -c istio-proxy | sed -n '/router decoding headers/,/thread=/p'
```

```text {caption="[Text 2] Request Headers Sent by shell istio-proxy to mock-server istio-proxy"}
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

```text {caption="[Text 3] x-envoy-peer-metadata Decoding Result"}
$ echo "ChoKCkNMVVNURVJfSUQSDBoKS3ViZXJuZXRlcwp5..." | base64 -d | strings
CLUSTER_ID / Kubernetes
LABELS / app: shell / service.istio.io/canonical-name: shell / ...
NAME / shell
NAMESPACE / default
OWNER / kubernetes://apis/apps/v1/namespaces/default/pods/shell
WORKLOAD_NAME / shell
```

As shown in [Shell 6], the request Headers that the `shell` istio-proxy sends to the `mock-server` istio-proxy are checked. As shown in [Text 2], the following Headers are added while passing through the `shell` istio-proxy.

* `x-forwarded-proto` : Indicates the Protocol (`http`) between the Client and the Sidecar Proxy.
* `x-request-id` : Indicates the unique UUID value of the request generated by the Client side Sidecar Proxy.
* `x-envoy-attempt-count` : Indicates the number of attempts of the request. It is `1` when there is no retry.
* `x-envoy-decorator-operation` : Indicates the Operation name of the Tracing Span set by the Client side Sidecar Proxy based on the Route configuration.
* `x-envoy-peer-metadata`, `x-envoy-peer-metadata-id` : Indicate the Metadata of the Client Workload. [Text 3] shows the result of decoding the `x-envoy-peer-metadata` value, which includes the Workload's name, Namespace, Labels, and Owner information. Both Sidecar Proxies set the Labels of Istio Metrics such as `source_workload` and `destination_workload` through Metadata exchange.

#### 1.3.3. Server Received Request Header Case (mock-server istio-proxy → mock-server)

```shell {caption="[Shell 7] Checking Server Received Request Headers"}
$ kubectl logs mock-server -c istio-proxy | sed -n '/router decoding headers/,/thread=/p'
```

```text {caption="[Text 4] Request Headers Sent by mock-server istio-proxy to mock-server"}
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

As shown in [Shell 7], the request Headers that the `mock-server` istio-proxy sends to the `mock-server` Container are checked. These Headers are the request Headers that the `mock-server` Container actually receives. As shown in [Text 4], the `x-envoy-decorator-operation`, `x-envoy-peer-metadata`, and `x-envoy-peer-metadata-id` Headers exchanged only between Sidecar Proxies are removed, and the `x-forwarded-client-cert` (XFCC) Header is added. The XFCC Header indicates the Client's certificate information delivered through mTLS, and the meaning of each Key is as follows.

* `By` : Indicates the URI SAN (SPIFFE ID) of the current Proxy's (`mock-server`'s Sidecar Proxy) certificate. Since the `mock-server` Pod runs with the `default` Service Account in the `default` Namespace, the value `spiffe://cluster.local/ns/default/sa/default` is set.
* `Hash` : Indicates the SHA256 Hash value of the Client certificate.
* `Subject` : Indicates the Subject of the Client certificate. It is empty because certificates issued by Istio do not have a Subject.
* `URI` : Indicates the URI SAN (SPIFFE ID) of the Client certificate. Since the `shell` Pod also runs with the `default` Service Account in the `default` Namespace, the same value as the `By` Key is set, and the `mock-server` Container can verify the Identity of the Client that sent the request through this value.

Since Istio applies mTLS between Sidecar Proxies by default (`PERMISSIVE` Mode + Auto mTLS), the XFCC Header is also set by default. On the other hand, if mTLS is disabled through PeerAuthentication and Destination Rule, the XFCC Header is not set because there is no certificate information. The SPIFFE ID of the `URI` Key is also utilized for matching the `source.principals` condition of the Istio Authorization Policy.

#### 1.3.4. Server Sent Response Header Case (mock-server → mock-server istio-proxy)

```shell {caption="[Shell 8] Checking Server Sent Response Headers"}
$ kubectl logs mock-server -c istio-proxy | sed -n '/upstream response headers/,/thread=/p'
```

```text {caption="[Text 5] Response Headers Received by mock-server istio-proxy"}
end_stream: false, upstream response headers:
':status', '200'
'content-type', 'application/json'
'content-length', '59'
```

As shown in [Shell 8], the response Headers that the `mock-server` istio-proxy received from the `mock-server` Container are checked. As shown in [Text 5], the response sent by the `mock-server` Container contains only basic Headers such as `content-type` and `content-length`, and no Istio related Headers exist yet.

#### 1.3.5. Response Headers between Sidecar Proxies Case (mock-server istio-proxy → shell istio-proxy)

```shell {caption="[Shell 9] Checking Response Headers between Sidecar Proxies"}
$ kubectl logs mock-server -c istio-proxy | sed -n '/encoding headers via codec/,/thread=/p'
```

```text {caption="[Text 6] Response Headers Sent by mock-server istio-proxy to shell istio-proxy"}
encoding headers via codec (end_stream=false):
':status', '200'
'content-type', 'application/json'
'x-envoy-upstream-service-time', '2'
'x-envoy-peer-metadata-id', 'sidecar~10.244.1.15~mock-server.default~default.svc.cluster.local'
'x-envoy-peer-metadata', 'ChoKCkNMVVNURVJfSUQSDBoKS3ViZXJuZXRlcwqFAQoGTEFCRUxTEnsqeQ...'
'server', 'istio-envoy'
```

As shown in [Shell 9], the response Headers that the `mock-server` istio-proxy sends to the `shell` istio-proxy are checked. The response sent by the `mock-server` Container contains only basic Headers such as `content-type`, but as shown in [Text 6], the following Headers are added while passing through the `mock-server` istio-proxy.

* `x-envoy-upstream-service-time` : Indicates the time (in Milliseconds) from when the `mock-server` istio-proxy sent the request to the `mock-server` Container until it received the response. It means the processing time of the `mock-server` Container.
* `x-envoy-peer-metadata`, `x-envoy-peer-metadata-id` : The Metadata of the `mock-server` Workload is set in the opposite direction of the request.
* `server` : Indicates the Proxy information (`istio-envoy`) that processed the response.

#### 1.3.6. Client Received Response Header Case (shell istio-proxy → shell)

```shell {caption="[Shell 10] Checking Client Received Response Headers"}
$ kubectl logs shell -c istio-proxy | sed -n '/encoding headers via codec/,/thread=/p'
```

```text {caption="[Text 7] Response Headers Sent by shell istio-proxy to shell"}
encoding headers via codec (end_stream=false):
':status', '200'
'content-type', 'application/json'
'date', 'Sun, 30 Aug 2026 09:04:14 GMT'
'content-length', '59'
'x-envoy-upstream-service-time', '11'
'server', 'envoy'
```

As shown in [Shell 10], the response Headers that the `shell` istio-proxy delivers to the `shell` Container are checked. These Headers are the response Headers that `curl` in the `shell` Container actually receives. As shown in [Text 7], the Metadata Exchange Headers exchanged only between Sidecar Proxies are removed, and the following Headers are changed.

* `x-envoy-upstream-service-time` : Overwritten with the value measured by the `shell` istio-proxy. It indicates the time (in Milliseconds) from when the Client side Sidecar Proxy sent the request to the `mock-server` Pod until it received the response, and includes the Network Latency between the two Pods and the processing time of the Server side Sidecar Proxy and the `mock-server` Container.
* `server` : The `istio-envoy` value set by the Server side Sidecar Proxy is changed to the `envoy` value and delivered to the Client.

#### 1.3.7. Circuit Breaking Response Header Case (shell istio-proxy → shell)

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

```shell {caption="[Shell 11] Checking Circuit Breaking Response Headers"}
# Send two requests concurrently
$ kubectl exec shell -- curl -s mock-server:8080/delay/5000 &
$ kubectl exec shell -- curl -s mock-server:8080/delay/5000 &
upstream connect error or disconnect/reset before headers. reset reason: overflow
{"delayed_ms":5000,"message":"Response delayed by 5000ms","service":"mock-server"}

# Check headers in shell istio-proxy logs
$ kubectl logs shell -c istio-proxy | sed -n '/encoding headers via codec/,/thread=/p'
```

```text {caption="[Text 8] 503 Response Headers Sent by shell istio-proxy to shell"}
encoding headers via codec (end_stream=false):
':status', '503'
'x-envoy-overloaded', 'true'
'content-length', '81'
'content-type', 'text/plain'
'date', 'Tue, 01 Sep 2026 07:05:26 GMT'
'server', 'envoy'
```

[File 5] shows the Destination Rule Manifest that limits the number of concurrent requests to the `mock-server` to 1. As shown in [Shell 11], when two requests are sent concurrently, the second request exceeds the concurrent request limit, so the `shell` istio-proxy judges it as an Upstream Overflow, triggers Circuit Breaking, and directly generates a `503 Service Unavailable` response without forwarding the request to the `mock-server` Pod.

As shown in [Text 8], the `x-envoy-overloaded: true` Header is set in the generated response, and the Client can distinguish through this Header that the response was generated by Circuit Breaking, not by the Server.

Similarly, there is also the `x-envoy-ratelimited` Header, which is set in the response of requests limited by Rate Limit, but since it is a Header set only by Envoy's Global Rate Limit Filter, it is not set in a default Istio environment that does not integrate a separate Rate Limit Service through EnvoyFilter. Even in the case of the Local Rate Limit Filter configured through EnvoyFilter, the `x-envoy-ratelimited` Header is not set as of Envoy version `1.32` used by Istio `1.24`.

### 1.4. Ingress Gateway Cases

{{< figure caption="[Figure 3] Ingress Gateway Case" src="images/ingressgateway-case.png" width="1000px" >}}

```shell {caption="[Shell 12] Sending HTTP Request via Ingress Gateway"}
$ curl -s -H "Host: mock-server.example.com" http://192.168.97.200/status/200
```

[Figure 3] shows the Headers added at each segment as the request and response pass through in the Ingress Gateway Case, and each number indicates the order of the Cases examined below. As shown in [Shell 12], a single HTTP request passing through the Ingress Gateway from outside the Mesh is sent via the Gateway and Virtual Service of [File 4], and the Headers of each segment are checked through the istio-proxy Logs in the order that the request and response flow. The request passes through 3 segments in the order of External Client → istio-ingressgateway → `mock-server` istio-proxy → `mock-server` Container, and the response is delivered in the reverse order. Since the Header processing of each segment operates regardless of the Protocol, it is verified only with an HTTP request, and it operates the same for gRPC requests.

#### 1.4.1. Client Sent Request Header Case (External Client → istio-ingressgateway)

```shell {caption="[Shell 13] Checking Client Sent Request Headers"}
$ kubectl logs -n istio-system deploy/istio-ingressgateway | sed -n '/request headers complete/,/thread=/p'
```

```text {caption="[Text 9] Request Headers Received by istio-ingressgateway"}
request headers complete (end_stream=true):
':authority', 'mock-server.example.com'
':path', '/status/200'
':method', 'GET'
'user-agent', 'curl/8.7.1'
'accept', '*/*'
```

As shown in [Shell 13], the request Headers that istio-ingressgateway received from the External Client are checked. As shown in [Text 9], only the `Host`, `User-Agent`, and `Accept` Headers sent by `curl` exist, and no Istio related Headers exist yet.

#### 1.4.2. Request Headers between Istio Proxies Case (istio-ingressgateway → mock-server istio-proxy)

```shell {caption="[Shell 14] Checking Request Headers between Istio Proxies"}
$ kubectl logs -n istio-system deploy/istio-ingressgateway | sed -n '/router decoding headers/,/thread=/p'
```

```text {caption="[Text 10] Request Headers Sent by istio-ingressgateway to mock-server istio-proxy"}
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

As shown in [Shell 14], the request Headers that istio-ingressgateway sends to the `mock-server` istio-proxy are checked. As shown in [Text 10], the `x-request-id`, `x-envoy-decorator-operation`, and `x-envoy-peer-metadata` Headers are added in the same way as the Sidecar Proxy Case (1.3.2), with the following differences.

* `x-forwarded-for` : istio-ingressgateway adds the address of the directly connected External Client (`203.0.113.9`) to the XFF Header. The Sidecar Proxy does not add the XFF Header, but istio-ingressgateway adds the XFF Header because Envoy's `use_remote_address` setting is `true`.
* `x-envoy-external-address` : Since the address of the directly connected External Client is in the public range, istio-ingressgateway judges the request as an External request, and sets the directly connected address (`203.0.113.9`), which is the trusted Client IP address. Conversely, when the request is judged as an Internal request, the `x-envoy-internal: true` Header is set.
* `x-envoy-peer-metadata-id` : Unlike the Sidecar Proxy's `sidecar~` Prefix, the information of the istio-ingressgateway Workload is set with the `router~` Prefix.

#### 1.4.3. Server Received Request Header Case (mock-server istio-proxy → mock-server)

```shell {caption="[Shell 15] Checking Server Received Request Headers"}
$ kubectl logs mock-server -c istio-proxy | sed -n '/router decoding headers/,/thread=/p'
```

```text {caption="[Text 11] Request Headers Sent by mock-server istio-proxy to mock-server"}
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

As shown in [Shell 15], the request Headers that the `mock-server` istio-proxy sends to the `mock-server` Container are checked. As shown in [Text 11], the Istio Proxy dedicated Headers are removed and the XFCC Header is added, while the `x-forwarded-for` and `x-envoy-external-address` Headers are maintained and delivered as is. The SPIFFE ID of istio-ingressgateway (`spiffe://cluster.local/ns/istio-system/sa/istio-ingressgateway-service-account`) is set in the `URI` Key of the XFCC Header. In other words, from the perspective of the `mock-server` Container, the Identity that can be verified through XFCC is istio-ingressgateway, not the original Client.

#### 1.4.4. Server Sent Response Header Case (mock-server → mock-server istio-proxy)

```shell {caption="[Shell 16] Checking Server Sent Response Headers"}
$ kubectl logs mock-server -c istio-proxy | sed -n '/upstream response headers/,/thread=/p'
```

```text {caption="[Text 12] Response Headers Received by mock-server istio-proxy"}
end_stream: false, upstream response headers:
':status', '200'
'content-type', 'application/json'
'content-length', '59'
```

As shown in [Shell 16], the response Headers that the `mock-server` istio-proxy received from the `mock-server` Container are checked. As in the Sidecar Proxy Case (1.3.4), the response sent by the `mock-server` Container contains only basic Headers.

#### 1.4.5. Response Headers between Istio Proxies Case (mock-server istio-proxy → istio-ingressgateway)

```shell {caption="[Shell 17] Checking Response Headers between Istio Proxies"}
$ kubectl logs mock-server -c istio-proxy | sed -n '/encoding headers via codec/,/thread=/p'
```

```text {caption="[Text 13] Response Headers Sent by mock-server istio-proxy to istio-ingressgateway"}
encoding headers via codec (end_stream=false):
':status', '200'
'content-type', 'application/json'
'x-envoy-upstream-service-time', '0'
'x-envoy-peer-metadata-id', 'sidecar~10.244.1.15~mock-server.default~default.svc.cluster.local'
'x-envoy-peer-metadata', 'ChoKCkNMVVNURVJfSUQSDBoKS3ViZXJuZXRlcwqFAQoGTEFCRUxTEnsqeQ...'
'server', 'istio-envoy'
```

As shown in [Shell 17], the response Headers that the `mock-server` istio-proxy sends to istio-ingressgateway are checked. As in the Sidecar Proxy Case (1.3.5), the Metadata Headers of the `mock-server` Workload and the `x-envoy-upstream-service-time` and `server` Headers are added.

#### 1.4.6. Client Received Response Header Case (istio-ingressgateway → External Client)

```shell {caption="[Shell 18] Checking Client Received Response Headers"}
$ kubectl logs -n istio-system deploy/istio-ingressgateway | sed -n '/encoding headers via codec/,/thread=/p'
```

```text {caption="[Text 14] Response Headers Sent by istio-ingressgateway to External Client"}
encoding headers via codec (end_stream=false):
':status', '200'
'content-type', 'application/json'
'date', 'Sun, 30 Aug 2026 16:29:30 GMT'
'content-length', '59'
'x-envoy-upstream-service-time', '2'
'server', 'istio-envoy'
```

As shown in [Shell 18], the response Headers that istio-ingressgateway delivers to the External Client are checked. As shown in [Text 14], the Istio Proxy dedicated Headers are removed, and the `x-envoy-upstream-service-time` Header is overwritten with the value measured by istio-ingressgateway (`2`). Unlike the Sidecar Proxy, the `server` Header is not changed to the `envoy` value, and the `istio-envoy` value is delivered as is.

#### 1.4.7. xff_num_trusted_hops Configuration Case

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

[File 6] shows the Manifest that changes the `numTrustedProxies` setting of the Ingress Gateway to `1`. Istio changes Envoy's `xff_num_trusted_hops` setting through the `gatewayTopology.numTrustedProxies` setting. It means an environment where a trusted Proxy (AWS ALB, Nginx, etc.) exists in front of the Ingress Gateway.

```shell {caption="[Shell 19] Sending Request with xff_num_trusted_hops Configuration"}
# Send request with pre-populated XFF header (simulating a front proxy)
$ curl -s -H "Host: mock-server.example.com" -H "X-Forwarded-For: 1.2.3.4, 5.6.7.8" http://192.168.97.200/status/200

# Check headers sent to app container
$ kubectl logs mock-server -c istio-proxy | sed -n '/router decoding headers/,/thread=/p'
```

```text {caption="[Text 15] Request Headers Sent to mock-server with xff_num_trusted_hops Configuration"}
# Before (numTrustedProxies: 0, default)
'x-forwarded-for', '1.2.3.4, 5.6.7.8,203.0.113.9'
'x-envoy-external-address', '203.0.113.9'

# After (numTrustedProxies: 1)
'x-forwarded-for', '1.2.3.4, 5.6.7.8,203.0.113.9'
'x-envoy-external-address', '5.6.7.8'
```

As shown in [Shell 19], a request with two addresses (`1.2.3.4, 5.6.7.8`) set in the XFF Header is sent, and the request Headers sent to the `mock-server` Container are compared before and after the configuration. [Text 15] shows the results before and after the configuration.

* Before configuration (`numTrustedProxies: 0`) : The addresses in the XFF Header are not trusted, and the address of the directly connected External Client (`203.0.113.9`) is judged as the trusted Client IP address and set in the `x-envoy-external-address` Header.
* After configuration (`numTrustedProxies: 1`) : Since it is assumed that one trusted Proxy exists in front of the Ingress Gateway, the rightmost address in the XFF Header (`5.6.7.8`) is judged as the trusted Client IP address set by the trusted Proxy and set in the `x-envoy-external-address` Header. The `1.2.3.4` value arbitrarily set by the Client is not trusted.

## 2. References

* Envoy Header : [https://ssup2.github.io/blog-software/docs/theory-analysis/envoy-header/](https://ssup2.github.io/blog-software/docs/theory-analysis/envoy-header/)
* Envoy Header Manipulation : [https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_conn_man/headers](https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_conn_man/headers)
* Istio Distributed Tracing : [https://istio.io/latest/docs/tasks/observability/distributed-tracing/overview/](https://istio.io/latest/docs/tasks/observability/distributed-tracing/overview/)
* Envoy x-forwarded-client-cert : [https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_conn_man/headers#x-forwarded-client-cert](https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_conn_man/headers#x-forwarded-client-cert)
* Istio Gateway Network Topology : [https://istio.io/latest/docs/ops/configuration/traffic-management/network-topologies/](https://istio.io/latest/docs/ops/configuration/traffic-management/network-topologies/)
* Istio Mutual TLS Migration : [https://istio.io/latest/docs/tasks/security/authentication/mtls-migration/](https://istio.io/latest/docs/tasks/security/authentication/mtls-migration/)

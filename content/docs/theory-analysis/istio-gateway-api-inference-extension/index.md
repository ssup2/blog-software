---
title: Istio Gateway API Inference Extension
---

Istio에서 Gateway API Inference Extension이 어떻게 구현되어 동작하는지 분석한다. Istio는 1.27 Version부터 Gateway API Inference Extension을 지원하며, 분석한 Istio의 Version은 1.31이고 Gateway API Inference Extension의 Version은 v1.6이다.

## 1. Istio Gateway API Inference Extension

{{< figure caption="[Figure 1] Istio Inference Gateway 구성" src="images/istio-inference-gateway.png" width="900px" >}}

Envoy에는 Inference를 위한 전용 기능이 존재하지 않는다. 따라서 Istio는 Envoy의 범용 기능인 **External Processing (ext-proc) Filter**와 **Override Host Load Balancing Policy**를 조합하여 **Gateway API Inference Extension**을 구현한다. ext-proc Filter는 요청과 응답의 Header, Body를 외부 gRPC Server에 전달하여 외부 Server가 Traffic을 검사하고 수정할 수 있도록 하는 HTTP Filter이며, Override Host Load Balancing Policy는 Load Balancing 알고리즘으로 Endpoint를 선택하지 않고, 요청의 특정 Header나 요청에 설정된 Envoy Metadata에서 Endpoint 주소를 읽어 해당 Endpoint로 Traffic을 전달하는 Load Balancing 정책이다.

istiod는 InferencePool Resource를 Watch하고 있다가 InferencePool을 참조하는 HTTPRoute가 존재하면, Gateway 역할을 수행하는 Envoy에 ext-proc Filter와 Override Host Load Balancing Policy 설정을 전달한다.

[Figure 1]은 Istio Inference Gateway의 구성을 나타내고 있다. Gateway가 수신한 요청은 ext-proc Filter를 통해서 **EPP** (Endpoint Picker)에게 전달되고, EPP가 선택한 Model Server Pod의 주소는 ext-proc 응답의 Metadata를 통해서 Envoy에게 반환된다. Envoy는 Override Host Load Balancing Policy를 통해서 Metadata에 명시된 Model Server Pod로 요청을 전달한다.

### 1.1. Test 환경 구축

```shell {caption="[Shell 1] Test 환경 구성"}
# Create kind cluster
$ kind create cluster --name istio-gateway-api

# Install gateway api CRDs (v1.6.0 standard channel)
$ kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.0/standard-install.yaml

# Install gateway api inference extension CRDs (v1.6.2)
$ kubectl apply -f https://github.com/kubernetes-sigs/gateway-api-inference-extension/releases/download/v1.6.2/manifests.yaml

# Install istio with gateway api inference extension
$ istioctl install --set profile=minimal \
    --set values.pilot.env.SUPPORT_GATEWAY_API_INFERENCE_EXTENSION=true \
    --set values.pilot.env.ENABLE_GATEWAY_API_INFERENCE_EXTENSION=true -y
```

Gateway API Inference Extension은 아직 Istio의 기본 기능으로 활성화되어 있지 않기 때문에, [Shell 1]과 같이 istiod의 환경 변수를 통해서 활성화해야 한다. 활성화 이후에는 별도의 Istio 전용 설정 없이 Gateway API Inference Extension의 InferencePool과 Gateway API의 Gateway, HTTPRoute Resource만으로 Inference Gateway를 구성할 수 있다. 이후 본문의 동작 확인은 [Shell 1]과 같이 kind Cluster에 Gateway API v1.6.0 CRD, Gateway API Inference Extension v1.6.2 CRD, Istio 1.31.0을 설치하여 수행한다.

```yaml {caption="[File 1] Test Workload 구성", linenos=table}
apiVersion: v1
kind: Namespace
metadata:
  name: llm-namespace
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vllm-llama3-8b
  namespace: llm-namespace
  labels:
    app: vllm-llama3-8b
spec:
  replicas: 3
  selector:
    matchLabels:
      app: vllm-llama3-8b
  template:
    metadata:
      labels:
        app: vllm-llama3-8b
    spec:
      containers:
      - name: vllm-sim
        image: ghcr.io/llm-d/llm-d-inference-sim:v0.7.1
        args:
        - --model
        - meta-llama/Llama-3.1-8B-Instruct
        - --port
        - "8000"
        - --max-loras
        - "2"
        - --lora-modules
        - '{"name": "reviews-1"}'
        ports:
        - containerPort: 8000
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vllm-llama3-8b-epp
  namespace: llm-namespace
  labels:
    app: vllm-llama3-8b-epp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vllm-llama3-8b-epp
  template:
    metadata:
      labels:
        app: vllm-llama3-8b-epp
    spec:
      containers:
      - name: lwepp
        image: registry.k8s.io/gateway-api-inference-extension/lwepp:v1.6.2
        args:
        - --pool-name
        - vllm-llama3-8b
        - --pool-namespace
        - llm-namespace
        ports:
        - containerPort: 9002
---
apiVersion: v1
kind: Service
metadata:
  name: vllm-llama3-8b-epp
  namespace: llm-namespace
spec:
  selector:
    app: vllm-llama3-8b-epp
  ports:
  - protocol: TCP
    port: 9002
    targetPort: 9002
    appProtocol: http2
---
# A DestinationRule is required to enable TLS between the gateway and the EPP
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: vllm-llama3-8b-epp-tls
  namespace: llm-namespace
spec:
  host: vllm-llama3-8b-epp
  trafficPolicy:
    tls:
      mode: SIMPLE
      insecureSkipVerify: true
```

```shell {caption="[Shell 2] Test Workload 확인"}
$ kubectl -n llm-namespace get pods -o wide
NAME                                   READY   STATUS    RESTARTS   AGE    IP
vllm-llama3-8b-56d558cb78-hnfzl        1/1     Running   0          21m    10.244.0.13
vllm-llama3-8b-56d558cb78-nw2p4        1/1     Running   0          21m    10.244.0.14
vllm-llama3-8b-56d558cb78-vw58t        1/1     Running   0          21m    10.244.0.15
vllm-llama3-8b-epp-5dc6dcfddc-bjcq7    1/1     Running   0          21m    10.244.0.16

$ kubectl -n llm-namespace get services
NAME                         TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)     AGE
vllm-llama3-8b-epp           ClusterIP   10.96.249.74   <none>        9002/TCP    21m
vllm-llama3-8b-ip-22dc7de1   ClusterIP   None           <none>        54321/TCP   21m
```

Test 환경의 Model Server는 [File 1]과 같이 GPU 없이 동작하는 vLLM Simulator 3개의 Pod로 구성하며, Lightweight EPP 기반의 `vllm-llama3-8b-epp` Deployment와 Service를 함께 생성한다. EPP는 TLS로 요청을 수신하기 때문에 Gateway와 EPP 사이의 TLS 연결을 위한 DestinationRule도 설정하며, EPP가 InferencePool과 Pod를 조회하기 위한 RBAC 구성은 [File 1]에서 생략하였다.

[File 1]을 적용하면 [Shell 2]와 같이 3개의 Model Server Pod와 EPP Pod, EPP Service가 생성된 것을 확인할 수 있다. Service 목록의 `vllm-llama3-8b-ip-22dc7de1` Service는 이후 [File 2]의 InferencePool을 적용하면 istiod가 생성하는 Shadow Service이다.

```yaml {caption="[File 2] InferencePool, HTTPRoute 구성", linenos=table}
apiVersion: inference.networking.k8s.io/v1
kind: InferencePool
metadata:
  name: vllm-llama3-8b
  namespace: llm-namespace
spec:
  selector:
    matchLabels:
      app: vllm-llama3-8b
  targetPorts:
  - number: 8000
  endpointPickerRef:
    name: vllm-llama3-8b-epp
    port:
      number: 9002
    failureMode: FailOpen
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: llm-route
  namespace: llm-namespace
spec:
  parentRefs:
  - name: gateway
    namespace: gateway-namespace
  hostnames:
  - "llm.ssup2.com"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - group: inference.networking.k8s.io
      kind: InferencePool
      name: vllm-llama3-8b
```

```shell {caption="[Shell 3] InferencePool 상태 확인"}
$ kubectl -n llm-namespace get inferencepool
NAME             AGE
vllm-llama3-8b   40m

$ kubectl -n llm-namespace get inferencepool vllm-llama3-8b -o jsonpath='{range .status.parents[0].conditions[*]}{.type}={.status} ({.reason}){"\n"}{end}'
Accepted=True (Accepted)
ResolvedRefs=True (ResolvedRefs)
```

Gateway는 `gateway-namespace` Namespace의 `istio` GatewayClass Gateway를 이용하며, [File 2]는 Model Server Pod를 묶는 `vllm-llama3-8b` InferencePool과 `llm.ssup2.com` Hostname의 Traffic을 InferencePool로 전달하는 HTTPRoute를 나타내고 있다. [Shell 3]은 [File 2] 적용 이후 생성된 InferencePool과 status를 나타내고 있다. status의 `Accepted` Condition을 통해서 InferencePool이 HTTPRoute를 통해서 Gateway에 정상적으로 연결된 것을 확인할 수 있고, `ResolvedRefs` Condition을 통해서 `endpointPickerRef`에 명시된 EPP 참조가 정상적으로 해석된 것을 확인할 수 있다. 이후 본문의 동작 확인은 이 상태의 Test 환경에서 수행한다.

### 1.2. InferencePool 변환

istiod는 InferencePool을 Istio의 기존 Service Model로 변환하여 처리한다. InferencePool이 생성되면 istiod는 InferencePool마다 `[InferencePool 이름]-ip-[Hash].[Namespace].svc.cluster.local` 형태의 이름을 갖는 **Shadow Service**를 Headless Service로 생성한다. Shadow Service의 selector와 Target Port는 InferencePool의 `selector`와 Target Port로 설정되기 때문에, `selector`에 부합하는 Model Server Pod들이 Shadow Service의 Endpoint로 등록된다. 따라서 Model Server Pod의 생성과 제거는 기존 Istio의 Service Discovery와 동일하게 EDS (Endpoint Discovery Service)를 통해서 Envoy에 반영된다.

Envoy에는 Shadow Service에 대응하는 `outbound|54321||[Shadow Service 이름]` 형태의 `EDS` Type Cluster가 생성된다. Cluster 이름의 `54321`은 Shadow Service에 이용되는 고정된 가상 Port이며, Traffic이 실제로 전달되는 Port는 Cluster의 Endpoint에 설정된 InferencePool의 Target Port이다. HTTPRoute의 `backendRefs`에 InferencePool이 명시되어 있으면, 해당 Route의 Cluster는 InferencePool의 Shadow Service Cluster로 설정된다. 이처럼 Istio는 InferencePool을 별도의 개념으로 처리하지 않고 기존 Service Model로 변환하기 때문에, Istio가 제공하는 mTLS와 Telemetry 기능도 InferencePool의 Model Server에 동일하게 적용할 수 있다.

```shell {caption="[Shell 4] Shadow Service의 Cluster, Endpoint 확인"}
$ istioctl proxy-config clusters gateway-istio-6cf9dd97dd-8lrn4 -n gateway-namespace | grep vllm
vllm-llama3-8b-epp.llm-namespace.svc.cluster.local             9002      -          outbound      EDS        vllm-llama3-8b-epp-tls.llm-namespace
vllm-llama3-8b-ip-22dc7de1.llm-namespace.svc.cluster.local     54321     -          outbound      EDS

$ istioctl proxy-config endpoints gateway-istio-6cf9dd97dd-8lrn4 -n gateway-namespace | grep vllm-llama3-8b-ip
10.244.0.13:8000        HEALTHY     OK     outbound|54321||vllm-llama3-8b-ip-22dc7de1.llm-namespace.svc.cluster.local
10.244.0.14:8000        HEALTHY     OK     outbound|54321||vllm-llama3-8b-ip-22dc7de1.llm-namespace.svc.cluster.local
10.244.0.15:8000        HEALTHY     OK     outbound|54321||vllm-llama3-8b-ip-22dc7de1.llm-namespace.svc.cluster.local
```

[Shell 4]는 `vllm-llama3-8b` InferencePool 생성 이후 Gateway Envoy의 Cluster와 Endpoint를 나타내고 있다. Model Server를 위한 Service는 별도로 생성하지 않았지만, [Shell 2]의 Service 목록에는 istiod가 생성한 `vllm-llama3-8b-ip-22dc7de1` 이름의 Shadow Service가 Headless Service로 존재하는 것을 확인할 수 있다. Envoy에는 Shadow Service에 대응하는 Cluster가 생성되어 있고, Cluster의 Endpoint에는 InferencePool의 `selector`로 선택된 3개의 Model Server Pod IP가 Target Port인 8000 Port와 함께 등록된 것을 확인할 수 있다.

### 1.3. 요청 처리 과정

{{< figure caption="[Figure 2] Istio Inference Gateway의 요청 처리 과정" src="images/istio-inference-request-flow.png" width="900px" >}}

```shell {caption="[Shell 5] InferencePool Route의 ext-proc Filter 설정 확인"}
$ istioctl proxy-config routes gateway-istio-6cf9dd97dd-8lrn4 -n gateway-namespace --name http.80 -o json
...
        "routes": [
            {
                "name": "llm-namespace.llm-route.0",
                ...
                "route": {
                    "cluster": "outbound|54321||vllm-llama3-8b-ip-22dc7de1.llm-namespace.svc.cluster.local",
                    ...
                },
                "typedPerFilterConfig": {
                    "envoy.filters.http.ext_proc": {
                        "@type": "type.googleapis.com/envoy.extensions.filters.http.ext_proc.v3.ExtProcPerRoute",
                        "overrides": {
                            "processingMode": {
                                "requestHeaderMode": "SEND",
                                "responseHeaderMode": "SEND",
                                "requestBodyMode": "FULL_DUPLEX_STREAMED",
                                "responseBodyMode": "FULL_DUPLEX_STREAMED",
                                ...
                            },
                            "grpcService": {
                                "envoyGrpc": {
                                    "clusterName": "outbound|9002||vllm-llama3-8b-epp.llm-namespace.svc.cluster.local"
                                }
                            },
                            "failureModeAllow": true
                        }
                    }
                }
            }
        ]
...
```

[Figure 2]는 Istio Inference Gateway의 요청 처리 과정을 나타내고 있고, [Shell 5]는 InferencePool을 참조하는 Route에 설정된 ext-proc Filter의 실제 설정을 나타내고 있다. Route의 Cluster는 InferencePool의 Shadow Service Cluster로 설정되어 있으며, ext-proc Filter의 `grpcService`에는 EPP의 Cluster가 명시되어 있다. Gateway의 Envoy가 요청을 수신하면 HTTPRoute의 `matches` 조건에 따라서 InferencePool의 Route가 선택되고, Route에 설정된 ext-proc Filter는 요청의 Header와 Body를 EPP에게 gRPC로 전달한다. ext-proc Filter는 InferencePool을 참조하는 Route에만 설정되기 때문에, 동일한 Gateway에서 일반 Service로 전달되는 요청은 EPP를 경유하지 않는다.

```shell {caption="[Shell 6] Inference 요청 확인"}
$ curl -s -i -H "Host: llm.ssup2.com" http://127.0.0.1:8080/v1/completions \
    -d '{"model": "reviews-1", "prompt": "What do reviewers think about The Comedy of Errors?", "max_tokens": 100, "temperature": 0}'
HTTP/1.1 200 OK
...
server: istio-envoy
x-inference-pod: vllm-llama3-8b-56d558cb78-hnfzl
x-inference-port: 8000
...
{"id":"cmpl-02401d40-5ed9-5702-9895-6e8cf93783bb","created":1789907157,"model":"reviews-1","usage":{"prompt_tokens":10,"completion_tokens":36,"total_tokens":46},"object":"text_completion",...}
```

[Shell 6]은 port-forward를 통해서 Gateway로 Inference 요청을 전송한 결과를 나타내고 있다. 요청은 vLLM Simulator에 의해서 정상적으로 처리되며, 응답의 `x-inference-pod` Header를 통해서 요청을 처리한 Model Server Pod를 확인할 수 있다.

EPP는 Model Server의 Queue 길이, KV Cache 사용률, LoRA Adapter 적재 여부 Metric을 기반으로 최적의 Model Server Pod를 선택하고, 선택한 Pod의 주소를 ext-proc 응답의 `envoy.lb` Metadata에 `x-gateway-destination-endpoint` Key로 설정하여 Envoy에게 반환한다. Envoy의 Cluster에는 Override Host Load Balancing Policy가 설정되어 있기 때문에, Envoy는 일반적인 Load Balancing 알고리즘 대신 Metadata에 명시된 Pod로 요청을 전달한다. Metadata가 존재하지 않는 경우에는 Fallback으로 설정된 Load Balancing 알고리즘을 이용한다.

```shell {caption="[Shell 7] Shadow Service Cluster의 Override Host Load Balancing Policy 확인"}
$ istioctl proxy-config clusters gateway-istio-6cf9dd97dd-8lrn4 -n gateway-namespace \
    --fqdn "vllm-llama3-8b-ip-22dc7de1.llm-namespace.svc.cluster.local" -o json
...
        "loadBalancingPolicy": {
            "policies": [
                {
                    "typedExtensionConfig": {
                        "name": "envoy.load_balancing_policies.override_host",
                        "typedConfig": {
                            "@type": "type.googleapis.com/envoy.extensions.load_balancing_policies.override_host.v3.OverrideHost",
                            "overrideHostSources": [
                                {
                                    "metadata": {
                                        "key": "envoy.lb",
                                        "path": [
                                            {
                                                "key": "x-gateway-destination-endpoint"
                                            }
                                        ]
                                    }
                                }
                            ],
                            ...
                            "fallbackPolicy": {
                                "policies": [
                                    {
                                        "typedExtensionConfig": {
                                            "name": "envoy.load_balancing_policies.round_robin",
                                            ...
```

[Shell 7]은 Shadow Service Cluster에 설정된 Override Host Load Balancing Policy를 나타내고 있다. EPP가 반환한 Endpoint 주소는 Envoy의 `envoy.lb` Metadata에 `x-gateway-destination-endpoint` Key로 저장되어 참조되며, Fallback Load Balancing 알고리즘은 Round Robin으로 설정되어 있는 것을 확인할 수 있다.

InferencePool의 `failureMode`는 ext-proc Filter의 `failure_mode_allow` 설정으로 변환된다. `FailOpen`으로 설정되어 있으면 `failure_mode_allow`는 `true`로 설정되어 EPP 장애시에도 요청은 Fallback Load Balancing을 통해서 전달되며, `FailClose`로 설정되어 있으면 EPP 장애시 요청은 실패한다. Test 환경의 InferencePool은 `FailOpen`으로 설정되어 있기 때문에, [Shell 5]에서 `failureModeAllow`가 `true`로 변환된 것을 확인할 수 있다.

### 1.4. Envoy Gateway 구현과 비교

Gateway API Inference Extension은 EPP와의 통신 방식만 ext-proc Protocol로 표준화하고 있기 때문에, EPP가 선택한 Model Server Pod로 요청을 전달하는 방식은 구현체마다 다르다. Envoy Gateway는 Cluster를 `ORIGINAL_DST` Type으로 설정하고 `use_http_header` 옵션을 통해서 `x-gateway-destination-endpoint` Header에 명시된 주소로 요청을 전달한다. `ORIGINAL_DST` Type Cluster는 Endpoint 정보를 관리하지 않기 때문에 구현이 단순하지만, Envoy의 Endpoint 기반 기능들을 이용할 수 없다.

반면 Istio는 `EDS` Type Cluster를 유지하면서 Override Host Load Balancing Policy를 통해서 Header에 명시된 Endpoint를 선택한다. 따라서 Istio는 InferencePool의 Model Server도 기존 Service와 동일하게 Endpoint 기반으로 관리하며, Istio의 Service Model과 자연스럽게 통합된다는 장점을 갖는다. 초기 Version의 Istio Gateway API Inference Extension은 Gateway를 통한 North-South Traffic만 지원하며, Ambient Mesh의 Waypoint를 통한 East-West Traffic 지원은 이후 Version에서 개발되고 있다.

## 2. 참조

* Istio Gateway API Inference Extension 지원 : [https://istio.io/latest/blog/2025/inference-extension-support/](https://istio.io/latest/blog/2025/inference-extension-support/)
* Istio Gateway API Inference Extension Task : [https://istio.io/latest/docs/tasks/traffic-management/ingress/gateway-api-inference-extension/](https://istio.io/latest/docs/tasks/traffic-management/ingress/gateway-api-inference-extension/)
* Gateway API Inference Extension : [https://gateway-api-inference-extension.sigs.k8s.io/](https://gateway-api-inference-extension.sigs.k8s.io/)
* Gateway API Inference Extension Deep Dive : [https://www.cncf.io/blog/2025/04/21/deep-dive-into-the-gateway-api-inference-extension/](https://www.cncf.io/blog/2025/04/21/deep-dive-into-the-gateway-api-inference-extension/)
* Envoy Override Host Load Balancing Policy : [https://github.com/istio/istio/issues/56230](https://github.com/istio/istio/issues/56230)
* Istio InferencePool 변환 : [https://github.com/istio/istio/issues/57638](https://github.com/istio/istio/issues/57638)

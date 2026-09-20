---
title: Kubernetes Gateway API Inference Extension
draft: true
---

Kubernetes에서 LLM Inference Traffic을 위한 Routing 기능을 제공하는 Gateway API Inference Extension을 분석한다. 분석한 Gateway API Inference Extension의 Version은 v1.6이다.

## 1. Kubernetes Gateway API Inference Extension

{{< figure caption="[Figure 1] Inference Gateway 구성" src="images/inference-gateway.png" width="900px" >}}

**Gateway API Inference Extension**은 Gateway API를 확장하여 LLM Inference Traffic에 최적화된 Routing 기능을 제공하는 확장 API이다. LLM Inference Traffic은 일반적인 Web Traffic과 다른 특성을 갖는다. 요청마다 처리해야 하는 Token의 개수가 다르기 때문에 요청별 처리 비용의 편차가 크고, 하나의 요청을 처리하는데 수 초에서 수 분까지 소요된다. 또한 Model Server는 고가의 GPU를 이용하기 때문에 일반적인 Web Server와 다르게 적은 수의 Replica로 운영된다.

이러한 특성 때문에 Kubernetes Service의 Round Robin, Random 방식의 Load Balancing을 LLM Inference Traffic에 이용하는 경우, 처리 비용이 큰 요청이 특정 Model Server에 몰리면 해당 Model Server의 Queue에 요청이 쌓여 Tail Latency가 증가하고 GPU 활용률도 불균형해지는 문제가 발생한다. Gateway API Inference Extension은 Model Server의 상태를 기반으로 최적의 Model Server를 선택하는 Load Balancing을 통해서 이러한 문제를 해결하며, Gateway API Inference Extension이 적용된 Gateway를 **Inference Gateway**라고 부른다.

[Figure 1]은 Inference Gateway의 구성을 나타내고 있다. Gateway API Inference Extension은 Model Server의 집합을 정의하는 **InferencePool** Resource와 최적의 Model Server를 선택하는 **Endpoint Picker (EPP)** Component로 구성된다. Inference Gateway는 Envoy의 **External Processing (ext-proc) Filter**를 기반으로 동작하기 때문에 ext-proc을 지원하는 Gateway API 구현체에서 이용할 수 있으며, 대표적인 구현체로는 Envoy Gateway, Istio, kgateway, NGINX Gateway Fabric, GKE Inference Gateway가 존재한다.

### 1.1. InferencePool

```yaml {caption="[File 1] InferencePool 예제", linenos=table}
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
```

**InferencePool**은 동일한 Model을 서비스하는 Model Server Pod의 집합을 정의하는 Resource이다. [File 1]은 vLLM 기반의 Model Server Pod를 묶는 InferencePool의 예제를 나타내고 있다. selector에는 InferencePool에 포함될 Model Server Pod의 Label을 명시하고, targetPorts에는 Model Server가 요청을 수신하는 Port를 명시한다. InferencePool은 Kubernetes Service와 유사하게 Pod의 집합을 정의하지만, Load Balancing 대상 선택을 endpointPickerRef에 명시된 EPP에게 위임한다는 차이점이 존재한다.

endpointPickerRef의 failureMode는 EPP에 장애가 발생한 경우의 동작을 정의한다. `FailOpen`으로 설정되어 있으면 EPP 장애시 Traffic은 일반적인 Load Balancing 방식으로 전달되며, `FailClose`로 설정되어 있으면 EPP 장애시 Traffic은 전달되지 않고 실패한다. InferencePool은 Gateway API의 역할 지향 설계와 동일하게 GPU Node와 Model Server를 관리하는 Inference Platform Owner가 관리하며, App 개발자는 HTTPRoute를 통해서 InferencePool을 참조만 하여 이용한다.

### 1.2. HTTPRoute 연동

```yaml {caption="[File 2] InferencePool을 참조하는 HTTPRoute 예제", linenos=table}
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

Gateway API Inference Extension은 별도의 Route Resource를 정의하지 않고 기존 Gateway API의 Gateway와 HTTPRoute를 그대로 이용한다. [File 2]는 InferencePool을 참조하는 HTTPRoute의 예제를 나타내고 있다. HTTPRoute의 backendRefs에 Service 대신 group과 kind를 통해서 InferencePool을 명시하면, HTTPRoute의 matches 조건에 부합하는 Traffic은 InferencePool로 전달되고 EPP가 선택한 Model Server Pod로 Routing된다. 따라서 기존 Gateway API의 Hostname, Path 기반 Routing과 Traffic 비율 제어 기능도 InferencePool과 같이 이용할 수 있다.

### 1.3. Endpoint Picker

{{< figure caption="[Figure 2] Endpoint Picker의 요청 처리 과정" src="images/endpoint-picker.png" width="900px" >}}

**Endpoint Picker** (EPP)는 InferencePool에 포함된 Model Server 중에서 요청을 처리할 최적의 Model Server를 선택하는 Component이며, 별도의 Pod로 배포되어 Envoy의 ext-proc Protocol을 통해서 Gateway와 통신한다. [Figure 2]는 EPP의 요청 처리 과정을 나타내고 있다. Gateway는 HTTPRoute를 통해서 Traffic이 전달될 InferencePool을 결정한 다음, 요청 정보를 EPP에게 전달한다. EPP는 InferencePool에 포함된 Model Server의 Metric을 기반으로 최적의 Model Server를 선택하여 Gateway에게 반환하고, Gateway는 선택된 Model Server Pod로 요청을 전달한다.

EPP는 Model Server가 노출하는 Metric을 주기적으로 수집하며, Model Server의 Queue에 대기중인 요청의 개수, KV Cache 사용률, 적재된 LoRA Adapter 목록, Prefix Cache 상태를 기반으로 Model Server를 선택한다. 예를 들어 Queue가 짧고 KV Cache에 여유가 있는 Model Server를 우선 선택하고, LoRA Adapter를 이용하는 요청은 해당 Adapter가 이미 적재된 Model Server로 전달하여 Adapter 적재 비용을 제거한다. Model Server가 노출해야 하는 Metric의 규격은 **Model Server Protocol**로 표준화되어 있으며, vLLM과 같은 Model Serving Platform이 지원하고 있다.

EPP의 선택 기법은 Plugin 형태로 구현되어 있기 때문에 필요에 따라서 Custom Plugin을 추가하여 선택 기법을 확장할 수 있다. v1.6 Version부터는 경량화된 **Lightweight EPP**가 기본 EPP로 제공되며, 기존의 EPP와 요청 Body의 Model 이름 기반으로 Routing을 수행하는 **Body-based Router**는 llm-d Project로 이관되어 개발되고 있다.

### 1.4. InferenceObjective

```yaml {caption="[File 3] InferenceObjective 예제", linenos=table}
apiVersion: inference.networking.x-k8s.io/v1alpha2
kind: InferenceObjective
metadata:
  name: chat-critical
  namespace: llm-namespace
spec:
  priority: 10
  poolRef:
    name: vllm-llama3-8b
```

**InferenceObjective**는 요청의 우선순위를 정의하는 Resource이다. [File 3]은 `vllm-llama3-8b` InferencePool에 우선순위를 설정하는 InferenceObjective의 예제를 나타내고 있다. priority에는 요청의 우선순위를 명시하며, InferencePool의 Model Server가 포화 상태인 경우 EPP는 우선순위가 낮은 요청을 거절하여 우선순위가 높은 요청의 처리를 보장한다. InferenceObjective는 아직 Alpha 단계의 Resource이기 때문에 향후 변경될 수 있으며, v1.6 Version부터는 별도의 Repository로 이관되어 개발되고 있다.

## 2. 참조

* Gateway API Inference Extension : [https://gateway-api-inference-extension.sigs.k8s.io/](https://gateway-api-inference-extension.sigs.k8s.io/)
* Gateway API Inference Extension GitHub : [https://github.com/kubernetes-sigs/gateway-api-inference-extension](https://github.com/kubernetes-sigs/gateway-api-inference-extension)
* Gateway API Inference Extension 소개 : [https://kubernetes.io/blog/2025/06/05/introducing-gateway-api-inference-extension/](https://kubernetes.io/blog/2025/06/05/introducing-gateway-api-inference-extension/)
* InferencePool : [https://gateway-api-inference-extension.sigs.k8s.io/api-types/inferencepool/](https://gateway-api-inference-extension.sigs.k8s.io/api-types/inferencepool/)
* InferenceObjective : [https://gateway-api-inference-extension.sigs.k8s.io/api-types/inferenceobjective/](https://gateway-api-inference-extension.sigs.k8s.io/api-types/inferenceobjective/)
* llm-d : [https://llm-d.ai/](https://llm-d.ai/)

---
title: Istio Gateway API Inference Extension
draft: true
---

Istio에서 Gateway API Inference Extension이 어떻게 구현되어 동작하는지 분석한다. Istio는 1.27 Version부터 Gateway API Inference Extension을 지원한다.

## 1. Istio Gateway API Inference Extension

{{< figure caption="[Figure 1] Istio Inference Gateway 구성" src="images/istio-inference-gateway.png" width="900px" >}}

Envoy에는 Inference를 위한 전용 기능이 존재하지 않는다. 따라서 Istio는 Envoy의 범용 기능인 **External Processing (ext-proc) Filter**와 **Override Host Load Balancing Policy**를 조합하여 **Gateway API Inference Extension**을 구현한다. istiod는 InferencePool Resource를 Watch하고 있다가 InferencePool을 참조하는 HTTPRoute가 존재하면, Gateway 역할을 수행하는 Envoy에 ext-proc Filter와 Override Host Load Balancing Policy 설정을 전달한다.

[Figure 1]은 Istio Inference Gateway의 구성을 나타내고 있다. Gateway가 수신한 요청은 ext-proc Filter를 통해서 **EPP** (Endpoint Picker)에게 전달되고, EPP가 선택한 Model Server Pod의 주소는 Header를 통해서 Envoy에게 반환된다. Envoy는 Override Host Load Balancing Policy를 통해서 Header에 명시된 Model Server Pod로 요청을 전달한다.

```shell {caption="[Shell 1] Istio Gateway API Inference Extension 활성화"}
# Install istio with gateway api inference extension
$ istioctl install --set profile=minimal \
    --set values.pilot.env.SUPPORT_GATEWAY_API_INFERENCE_EXTENSION=true \
    --set values.pilot.env.ENABLE_GATEWAY_API_INFERENCE_EXTENSION=true
```

Gateway API Inference Extension은 아직 Istio의 기본 기능으로 활성화되어 있지 않기 때문에, [Shell 1]과 같이 istiod의 환경 변수를 통해서 활성화해야 한다. 활성화 이후에는 별도의 Istio 전용 설정 없이 Gateway API Inference Extension의 InferencePool과 Gateway API의 Gateway, HTTPRoute Resource만으로 Inference Gateway를 구성할 수 있다.

### 1.1. InferencePool 변환

istiod는 InferencePool을 Istio의 기존 Service Model로 변환하여 처리한다. InferencePool이 생성되면 istiod는 InferencePool마다 `[InferencePool 이름]-ip-[Hash].[Namespace].svc.cluster.local` 형태의 이름을 갖는 내부 **Shadow Service**를 생성하고, InferencePool의 selector에 부합하는 Model Server Pod들을 Shadow Service의 Endpoint로 등록한다. 따라서 Model Server Pod의 생성과 제거는 기존 Istio의 Service Discovery와 동일하게 EDS (Endpoint Discovery Service)를 통해서 Envoy에 반영된다.

Envoy에는 Shadow Service에 대응하는 `outbound|[Target Port]||[Shadow Service 이름]` 형태의 `EDS` Type Cluster가 생성된다. HTTPRoute의 backendRefs에 InferencePool이 명시되어 있으면, 해당 Route의 Cluster는 InferencePool의 Shadow Service Cluster로 설정된다. 이처럼 Istio는 InferencePool을 별도의 개념으로 처리하지 않고 기존 Service Model로 변환하기 때문에, Istio가 제공하는 mTLS와 Telemetry 기능도 InferencePool의 Model Server에 동일하게 적용할 수 있다.

### 1.2. 요청 처리 과정

{{< figure caption="[Figure 2] Istio Inference Gateway의 요청 처리 과정" src="images/istio-inference-request-flow.png" width="900px" >}}

```json {caption="[File 1] InferencePool Route의 ext-proc Filter 설정 예시", linenos=table}
{
  "typed_per_filter_config": {
    "envoy.filters.http.ext_proc": {
      "@type": "type.googleapis.com/envoy.extensions.filters.http.ext_proc.v3.ExtProcPerRoute",
      "overrides": {
        "grpc_service": {
          "envoy_grpc": {
            "cluster_name": "outbound|9002||vllm-llama3-8b-epp.llm-namespace.svc.cluster.local"
          }
        }
      }
    }
  }
}
```

[Figure 2]는 Istio Inference Gateway의 요청 처리 과정을 나타내고 있고, [File 1]은 InferencePool을 참조하는 Route에 설정되는 ext-proc Filter의 설정 예시를 나타내고 있다. Gateway의 Envoy가 요청을 수신하면 HTTPRoute의 matches 조건에 따라서 InferencePool의 Route가 선택되고, Route에 설정된 ext-proc Filter는 요청의 Header와 Body를 EPP에게 gRPC로 전달한다. ext-proc Filter는 InferencePool을 참조하는 Route에만 설정되기 때문에, 동일한 Gateway에서 일반 Service로 전달되는 요청은 EPP를 경유하지 않는다.

EPP는 Model Server의 Queue 길이, KV Cache 사용률, LoRA Adapter 적재 여부 Metric을 기반으로 최적의 Model Server Pod를 선택하고, 선택한 Pod의 주소를 `x-gateway-destination-endpoint` Header에 설정하여 Envoy에게 반환한다. Envoy의 Cluster에는 Override Host Load Balancing Policy가 설정되어 있기 때문에, Envoy는 일반적인 Load Balancing 알고리즘 대신 `x-gateway-destination-endpoint` Header에 명시된 Pod로 요청을 전달한다. Header가 존재하지 않는 경우에는 Fallback으로 설정된 Load Balancing 알고리즘을 이용한다.

InferencePool의 failureMode는 ext-proc Filter의 `failure_mode_allow` 설정으로 변환된다. `FailOpen`으로 설정되어 있으면 `failure_mode_allow`는 `true`로 설정되어 EPP 장애시에도 요청은 Fallback Load Balancing을 통해서 전달되며, `FailClose`로 설정되어 있으면 EPP 장애시 요청은 실패한다.

### 1.3. Envoy Gateway 구현과 비교

Gateway API Inference Extension은 EPP와의 통신 방식만 ext-proc Protocol로 표준화하고 있기 때문에, EPP가 선택한 Model Server Pod로 요청을 전달하는 방식은 구현체마다 다르다. Envoy Gateway는 Cluster를 `ORIGINAL_DST` Type으로 설정하고 `use_http_header` 옵션을 통해서 `x-gateway-destination-endpoint` Header에 명시된 주소로 요청을 전달한다. `ORIGINAL_DST` Type Cluster는 Endpoint 정보를 관리하지 않기 때문에 구현이 단순하지만, Envoy의 Endpoint 기반 기능들을 이용할 수 없다.

반면 Istio는 `EDS` Type Cluster를 유지하면서 Override Host Load Balancing Policy를 통해서 Header에 명시된 Endpoint를 선택한다. 따라서 Istio는 InferencePool의 Model Server도 기존 Service와 동일하게 Endpoint 기반으로 관리하며, Istio의 Service Model과 자연스럽게 통합된다는 장점을 갖는다. 초기 Version의 Istio Gateway API Inference Extension은 Gateway를 통한 North-South Traffic만 지원하며, Ambient Mesh의 Waypoint를 통한 East-West Traffic 지원은 이후 Version에서 개발되고 있다.

## 2. 참조

* Istio Gateway API Inference Extension 지원 : [https://istio.io/latest/blog/2025/inference-extension-support/](https://istio.io/latest/blog/2025/inference-extension-support/)
* Istio Gateway API Inference Extension Task : [https://istio.io/latest/docs/tasks/traffic-management/ingress/gateway-api-inference-extension/](https://istio.io/latest/docs/tasks/traffic-management/ingress/gateway-api-inference-extension/)
* Gateway API Inference Extension : [https://gateway-api-inference-extension.sigs.k8s.io/](https://gateway-api-inference-extension.sigs.k8s.io/)
* Gateway API Inference Extension Deep Dive : [https://www.cncf.io/blog/2025/04/21/deep-dive-into-the-gateway-api-inference-extension/](https://www.cncf.io/blog/2025/04/21/deep-dive-into-the-gateway-api-inference-extension/)
* Envoy Override Host Load Balancing Policy : [https://github.com/istio/istio/issues/56230](https://github.com/istio/istio/issues/56230)
* Istio InferencePool 변환 : [https://github.com/istio/istio/issues/57638](https://github.com/istio/istio/issues/57638)

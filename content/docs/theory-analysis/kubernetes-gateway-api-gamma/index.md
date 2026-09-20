---
title: Kubernetes Gateway API GAMMA
draft: true
---

Kubernetes Gateway API를 Service Mesh의 East-West Traffic 제어로 확장하는 GAMMA를 분석한다. 분석한 Gateway API의 Version은 v1.6이다.

## 1. Kubernetes Gateway API GAMMA

{{< figure caption="[Figure 1] GAMMA의 Route, Service 연결 구조" src="images/gamma-route-service.png" width="900px" >}}

**GAMMA** (Gateway API for Mesh Management and Administration)는 Cluster 외부 Traffic을 대상으로 설계된 Gateway API를 Service Mesh 내부의 East-West Traffic 제어에도 이용할 수 있도록 확장하는 표준이다. 기존의 Service Mesh는 Istio의 VirtualService, Linkerd의 ServiceProfile처럼 구현체마다 전용 API를 제공하기 때문에 Mesh 구현체를 변경하는 경우 Traffic 제어 설정도 같이 수정되어야 하는 이식성 문제가 존재한다. GAMMA는 이러한 문제를 해결하기 위해서 등장하였으며, Gateway API v1.1부터 Mesh 지원이 Standard Channel로 승격되었다.

[Figure 1]은 GAMMA의 Route와 Service 연결 구조를 나타내고 있다. GAMMA는 별도의 Resource를 추가하지 않고 기존 Route의 `parentRefs`에 Gateway 대신 Service를 명시하는 방식으로 동작하기 때문에, GatewayClass와 Gateway Resource 없이 Route만으로 Mesh 내부의 Traffic을 제어할 수 있다. Mesh 구현체는 Service에 연결된 Route를 Watch하여 Data Plane에 Routing 규칙을 적용하며, Sidecar Mode에서는 요청을 전송하는 Client의 Sidecar에서, Ambient Mode에서는 Waypoint에서 규칙이 적용된다.

Mesh에서 이용할 수 있는 Route는 HTTPRoute와 GRPCRoute이며, TCPRoute와 TLSRoute의 Mesh 지원은 아직 실험 단계이다. GAMMA를 지원하는 대표적인 Mesh 구현체로는 Istio, Linkerd, Kuma, Cilium이 존재하며, Gateway API는 Mesh 전용 Conformance Profile을 통해서 구현체의 GAMMA 표준 준수 여부를 검증한다.

### 1.1. Service Frontend, Backend

GAMMA는 Service의 역할을 **Frontend**와 **Backend**로 구분하여 정의한다. Frontend는 Service의 이름과 ClusterIP처럼 Client가 요청을 전송하는 대상을 의미하며, Backend는 Service의 Selector로 선택된 Endpoint IP의 집합을 의미한다. Route는 Service의 Frontend로 전달되는 Traffic을 대상으로 동작하며, Traffic이 실제로 전달되는 Backend는 Route의 `backendRefs`를 통해서 결정된다. 따라서 Client는 기존과 동일하게 Service의 DNS 이름으로 요청을 전송하지만, 요청은 Route의 규칙에 따라서 다른 Version의 Service나 다른 Service로 전달될 수 있다.

Route가 연결된 Service는 요청 처리 방식이 변경된다는 점에 주의해야 한다. Route의 `matches` 조건에 부합하는 요청은 `backendRefs`에 명시된 Backend로 전달되지만, 부합하지 않는 요청은 Service의 Backend로 전달되지 않고 거부된다. Route가 연결되지 않은 Service는 기존과 동일하게 동작한다.

### 1.2. Producer Route

```yaml {caption="[File 1] Producer Route 예제", linenos=table}
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: version-producer
  namespace: version-namespace
spec:
  parentRefs:
  - group: ""
    kind: Service
    name: version
  rules:
  - backendRefs:
    - name: version-v1
      port: 8080
      weight: 90
    - name: version-v2
      port: 8080
      weight: 10
```

**Producer Route**는 대상 Service와 동일한 Namespace에 생성되는 Route이며, Service를 소유한 App 개발자가 자신의 Service로 전달되는 Traffic의 처리 방식을 정의할 때 이용한다. [File 1]은 `version` Service로 전달되는 Traffic을 `version-v1`, `version-v2` Service로 분배하는 Producer Route의 예제를 나타내고 있다. `parentRefs`에 `kind: Service`와 함께 대상 Service의 이름을 명시하며, Producer Route의 규칙은 요청을 전송하는 Client의 Namespace와 관계없이 Mesh 내부의 모든 요청에 적용된다. 따라서 Producer Route는 Canary 배포처럼 Service 소유자가 모든 Client에게 동일하게 적용할 규칙을 정의할 때 이용된다.

### 1.3. Consumer Route

```yaml {caption="[File 2] Consumer Route 예제", linenos=table}
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: version-consumer
  namespace: client-namespace
spec:
  parentRefs:
  - group: ""
    kind: Service
    name: version
    namespace: version-namespace
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    filters:
    - type: RequestHeaderModifier
      requestHeaderModifier:
        add:
        - name: x-consumer
          value: client-namespace
    backendRefs:
    - name: version
      namespace: version-namespace
      port: 8080
```

**Consumer Route**는 대상 Service와 다른 Namespace에 생성되는 Route이며, Service를 이용하는 Client가 자신의 요청에만 적용될 규칙을 정의할 때 이용한다. [File 2]는 `client-namespace` Namespace의 Client가 `version` Service로 전송하는 요청에 Header를 추가하는 Consumer Route의 예제를 나타내고 있다. Consumer Route의 규칙은 Route와 동일한 Namespace의 Client가 전송하는 요청에만 적용되며, 다른 Namespace의 Client가 전송하는 요청에는 영향을 주지 않는다.

동일한 요청에 Producer Route와 Consumer Route가 모두 부합하는 경우에는 Consumer Route가 우선 적용된다. 다만 동일한 Namespace의 다수의 Route는 병합되어 동작하기 때문에, 하나의 Namespace 안에서 Client별로 서로 다른 Consumer Route를 정의할 수는 없다. 또한 Consumer Route는 다른 Namespace의 Service를 `backendRefs`에 명시하기 때문에 대상 Namespace에 ReferenceGrant가 존재해야 하며, Consumer Route의 지원 여부는 Mesh 구현체마다 다르기 때문에 이용하는 구현체의 지원 범위를 확인해야 한다.

### 1.4. Gateway API 비교

{{< table caption="[Table 1] Gateway API, GAMMA 비교" >}}
| 구분 | Gateway API | GAMMA |
|---|---|---|
| 대상 Traffic | Cluster 외부에서 유입되는 North-South Traffic | Mesh 내부의 East-West Traffic |
| Route의 `parentRefs` 대상 | Gateway | Service |
| 필요 Resource | GatewayClass, Gateway, Route | Route |
| 규칙 적용 지점 | Gateway의 Proxy | Client의 Sidecar 또는 Waypoint |
{{< /table >}}

[Table 1]은 Gateway API와 GAMMA의 주요 차이점을 나타내고 있다. GAMMA는 별도의 API를 정의하지 않고 Route의 연결 대상만 Service로 변경하는 방식이기 때문에, Gateway API의 `matches`, `filters`, `backendRefs` 문법을 North-South Traffic과 East-West Traffic에 동일하게 이용할 수 있다. 따라서 App 개발자는 하나의 API로 Cluster 외부 노출과 Mesh 내부 Traffic 제어를 모두 정의할 수 있으며, Mesh 구현체가 변경되어도 Route를 그대로 이용할 수 있다.

## 2. 참조

* Gateway API for Service Mesh : [https://gateway-api.sigs.k8s.io/docs/mesh/mesh-overview/](https://gateway-api.sigs.k8s.io/docs/mesh/mesh-overview/)
* GAMMA GEP-1426 : [https://gateway-api.sigs.k8s.io/geps/gep-1426/](https://gateway-api.sigs.k8s.io/geps/gep-1426/)
* Gateway API v1.1 Release : [https://kubernetes.io/blog/2024/05/09/gateway-api-v1-1/](https://kubernetes.io/blog/2024/05/09/gateway-api-v1-1/)
* Istio Mesh Traffic : [https://istio.io/latest/docs/tasks/traffic-management/ingress/gateway-api/#mesh-traffic](https://istio.io/latest/docs/tasks/traffic-management/ingress/gateway-api/#mesh-traffic)
* Cilium GAMMA Support : [https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gamma/](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gamma/)

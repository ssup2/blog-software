---
title: Kubernetes Gateway API
draft: true
---

Kubernetes에서 Ingress의 한계를 극복하기 위해서 등장한 Gateway API를 분석한다. 분석한 Gateway API의 Version은 v1.6이다.

## 1. Kubernetes Gateway API

{{< figure caption="[Figure 1] Gateway API Resource 관계" src="images/gateway-api-resource.png" width="900px" >}}

**Gateway API**는 Kubernetes Cluster 외부의 Traffic을 Cluster 내부의 Service로 Routing하는 방법을 정의하는 표준 API이다. 기존의 Ingress는 HTTP/HTTPS Protocol 중심으로 설계되어 있고, 표준으로 정의된 기능이 부족하기 때문에 대부분의 Ingress Controller는 Annotation을 통해서 기능을 확장한다.

Annotation은 Ingress Controller마다 다르게 정의되어 있기 때문에 Ingress Controller를 변경하는 경우 Ingress도 같이 수정되어야 하는 이식성 문제가 존재한다. 또한 Ingress는 하나의 Resource에 Load Balancer 설정과 Routing 규칙이 모두 정의되기 때문에 Cluster 관리자와 App 개발자의 역할을 분리하기 어려운 문제도 존재한다. Gateway API는 이러한 Ingress의 한계를 극복하기 위해서 등장하였다.

[Figure 1]은 Gateway API의 주요 Resource와 각 Resource를 관리하는 역할의 관계를 나타내고 있다. Gateway API는 **역할 지향 (Role-oriented)** 설계를 기반으로 GatewayClass, Gateway, Route 3가지 계층의 Resource를 제공한다. GatewayClass는 Gateway의 구현체를 정의하는 Resource이며 Infrastructure Provider가 관리한다. Gateway는 Traffic을 수신하는 Load Balancer (Proxy)를 정의하는 Resource이며 Cluster Operator가 관리한다. HTTPRoute를 포함한 Route는 수신한 Traffic을 Service로 Routing하는 규칙을 정의하는 Resource이며 App 개발자가 관리한다.

이처럼 Gateway API는 역할별로 Resource가 분리되어 있기 때문에, App 개발자는 Cluster Operator가 관리하는 Gateway를 수정하지 않고 자신의 Namespace에서 Route만 정의하여 App을 외부에 노출할 수 있다.

Gateway API는 Kubernetes에 내장되어 있지 않으며 CRD (Custom Resource Definition) 형태로 별도로 설치된다. 또한 Gateway API는 API 표준만 정의하고 실제 동작은 Gateway Controller 구현체가 담당한다. 대표적인 구현체로는 Istio, Envoy Gateway, NGINX Gateway Fabric, Cilium, Kong이 존재하며, AWS/GCP/Azure와 같은 Cloud Provider도 자신의 Load Balancer와 연동되는 구현체를 제공한다.

### 1.1. GatewayClass

```yaml {caption="[File 1] GatewayClass 예제", linenos=table}
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: istio
spec:
  controllerName: istio.io/gateway-controller
```

**GatewayClass**는 Gateway의 구현체를 정의하는 Cluster Scope의 Resource이다. [File 1]은 Istio 구현체를 이용하는 GatewayClass의 예제를 나타내고 있다. `controllerName`에는 GatewayClass를 처리하는 Gateway Controller의 이름을 명시하며, 해당 Gateway Controller가 GatewayClass를 참조하는 Gateway의 생성과 관리를 담당한다. GatewayClass는 Kubernetes의 StorageClass와 유사한 개념이며, 일반적으로 구현체를 설치하면 GatewayClass도 같이 생성된다. 하나의 Kubernetes Cluster에는 다수의 GatewayClass가 존재할 수 있기 때문에 하나의 Cluster에서 다수의 구현체를 같이 이용할 수 있다.

### 1.2. Gateway

```yaml {caption="[File 2] Gateway 예제", linenos=table}
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: gateway
  namespace: gateway-namespace
spec:
  gatewayClassName: istio
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    hostname: "*.ssup2.com"
    allowedRoutes:
      namespaces:
        from: All
  - name: https
    protocol: HTTPS
    port: 443
    hostname: "*.ssup2.com"
    tls:
      certificateRefs:
      - name: ssup2-tls-secret
    allowedRoutes:
      namespaces:
        from: Selector
        selector:
          matchLabels:
            gateway-access: "true"
  - name: tls
    protocol: TLS
    port: 8443
    hostname: "*.ssup2.com"
    tls:
      mode: Passthrough
    allowedRoutes:
      namespaces:
        from: All
  - name: tcp
    protocol: TCP
    port: 5432
    allowedRoutes:
      namespaces:
        from: All
  - name: udp
    protocol: UDP
    port: 53
    allowedRoutes:
      namespaces:
        from: All
```

**Gateway**는 Traffic을 수신하는 Load Balancer를 정의하는 Resource이며, GatewayClass의 인스턴스에 해당한다. Gateway가 생성되면 Gateway Controller는 Gateway의 내용에 따라서 실제 Traffic을 수신하는 Proxy (Envoy, Nginx)와 `LoadBalancer` Type의 Service를 생성한다. [File 2]는 HTTP, HTTPS, TLS, TCP, UDP Traffic을 수신하는 Gateway의 예제를 나타내고 있다. `gatewayClassName`에는 Gateway의 생성과 관리를 담당할 GatewayClass의 이름을 명시하며, `listeners`에는 Gateway가 Traffic을 수신하는 진입점을 정의한다. 하나의 Gateway에는 다수의 Listener를 정의할 수 있으며, 각 Listener에는 Protocol, Port, Hostname을 설정할 수 있다. Listener의 Protocol에는 `HTTP`, `HTTPS`, `TLS`, `TCP`, `UDP`를 설정할 수 있다.

[File 2]의 https Listener처럼 `tls`의 `certificateRefs`에 인증서가 저장된 Secret을 명시하면 Listener는 TLS Termination을 수행한다. 반면 tls Listener처럼 TLS Mode가 `Passthrough`로 설정되어 있으면 Listener는 TLS Termination을 수행하지 않고 Traffic을 그대로 전달한다.

`allowedRoutes`는 Listener에 연결될 수 있는 Route를 제한하는 역할을 수행한다. http Listener의 `allowedRoutes`에는 `All`이 설정되어 있기 때문에 모든 Namespace의 Route가 연결될 수 있지만, https Listener의 `allowedRoutes`에는 `Selector`가 설정되어 있기 때문에 `gateway-access: "true"` Label이 설정된 Namespace의 Route만 연결될 수 있다. `allowedRoutes`의 기본값은 `Same`이며, 이 경우에는 Gateway와 동일한 Namespace의 Route만 연결될 수 있다. 이처럼 Cluster Operator는 `allowedRoutes`를 통해서 App 개발자가 이용할 수 있는 Listener의 범위를 제어할 수 있다.

### 1.3. Route

{{< table caption="[Table 1] Route 종류" >}}
| Route | 대상 Protocol | Routing 기준 | Standard Channel 승격 Version |
|---|---|---|---|
| HTTPRoute | HTTP, HTTPS | Hostname, Path, Header, Method, Query Parameter | v0.5 |
| GRPCRoute | gRPC | Hostname, Service, Method, Header | v1.1 |
| TLSRoute | TLS | SNI Hostname | v1.5 |
| TCPRoute | TCP | Listener Port | v1.6 |
| UDPRoute | UDP | Listener Port | v1.6 |
{{< /table >}}

**Route**는 Gateway가 수신한 Traffic을 Service로 Routing하는 규칙을 정의하는 Resource이다. Route는 `parentRefs`를 통해서 연결될 Gateway를 명시하며, 필요에 따라서 `sectionName`을 통해서 Gateway의 특정 Listener에만 연결될 수도 있다. [Table 1]은 Gateway API가 제공하는 Route의 종류를 나타내고 있다.

Gateway API는 Protocol에 따라서 HTTPRoute, GRPCRoute, TLSRoute, TCPRoute, UDPRoute 5가지 Route Resource를 제공하며, 각 Route는 서로 다른 시점에 Standard Channel로 승격되었기 때문에 v1.6 Version 기준으로 모든 Route Resource를 Standard Channel에서 이용할 수 있다. 다만 실제 이용 가능 여부는 구현체의 지원 여부에 따라서 결정되기 때문에 이용하는 구현체의 지원 범위를 확인해야 한다.

#### 1.3.1. HTTPRoute

{{< figure caption="[Figure 2] Gateway, HTTPRoute를 통한 Traffic Routing" src="images/gateway-httproute.png" width="900px" >}}

```yaml {caption="[File 3] HTTPRoute 예제", linenos=table}
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: version
  namespace: version-namespace
spec:
  parentRefs:
  - name: gateway
    namespace: gateway-namespace
  hostnames:
  - "version.ssup2.com"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /version
    filters:
    - type: RequestHeaderModifier
      requestHeaderModifier:
        add:
        - name: x-gateway
          value: gateway-api
    backendRefs:
    - name: version-v1
      port: 8080
      weight: 90
    - name: version-v2
      port: 8080
      weight: 10
```

**HTTPRoute**는 Gateway가 수신한 HTTP Traffic을 Service로 Routing하는 규칙을 정의하는 Resource이다. [Figure 2]와 [File 3]은 `version.ssup2.com` Hostname으로 수신한 Traffic을 `version-v1`, `version-v2` Service로 Routing하는 HTTPRoute의 예제를 나타내고 있다. `parentRefs`에는 HTTPRoute가 연결될 Gateway를 명시하며, `hostnames`에는 Routing 대상이 되는 Hostname을 명시한다. HTTPRoute의 `hostnames`는 연결된 Gateway Listener의 `hostname`과 겹치는 경우에만 유효하며, [File 3]의 `version.ssup2.com`은 [File 2]의 `*.ssup2.com`에 포함되기 때문에 HTTPRoute는 정상적으로 Gateway에 연결된다.

`rules`에는 Traffic의 Routing 규칙을 정의한다. `matches`는 Routing 대상이 되는 Traffic의 조건을 정의하며 Path뿐만 아니라 Header, Method, Query Parameter 기반의 조건도 정의할 수 있다. `filters`는 Routing 과정에서 Traffic을 조작하는 역할을 수행하며, Request/Response Header 수정 (`RequestHeaderModifier`, `ResponseHeaderModifier`), Redirect (`RequestRedirect`), URL 재작성 (`URLRewrite`), Traffic 복제 (`RequestMirror`) 기능을 표준으로 제공한다. Ingress에서는 이러한 기능들을 Annotation을 통해서 이용해야 하지만, Gateway API에서는 표준 API로 제공되기 때문에 구현체와 관계없이 동일하게 이용할 수 있다.

`backendRefs`에는 Traffic이 전달될 Service를 명시하며, 다수의 Service를 명시하는 경우 `weight`를 통해서 Traffic의 비율을 설정할 수 있다. [File 3]에서는 `version-v1` Service에 90%, `version-v2` Service에 10%의 Traffic이 전달되도록 설정되어 있는 것을 확인할 수 있다. 따라서 Gateway API는 Ingress와 다르게 별도의 구현체 확장 기능 없이 Canary 배포를 수행할 수 있다.

#### 1.3.2. GRPCRoute

```yaml {caption="[File 4] GRPCRoute 예제", linenos=table}
apiVersion: gateway.networking.k8s.io/v1
kind: GRPCRoute
metadata:
  name: version
  namespace: version-namespace
spec:
  parentRefs:
  - name: gateway
    namespace: gateway-namespace
  hostnames:
  - "grpc.ssup2.com"
  rules:
  - matches:
    - method:
        service: version.VersionService
        method: GetVersion
    backendRefs:
    - name: version-grpc
      port: 9090
```

**GRPCRoute**는 Gateway가 수신한 gRPC Traffic을 Service로 Routing하는 규칙을 정의하는 Resource이다. [File 4]는 `grpc.ssup2.com` Hostname으로 수신한 gRPC Traffic을 `version-grpc` Service로 Routing하는 GRPCRoute의 예제를 나타내고 있다. gRPC는 HTTP/2 기반으로 동작하기 때문에 HTTPRoute를 통해서도 gRPC Traffic을 Routing할 수 있지만, GRPCRoute는 [File 4]의 `matches`처럼 gRPC의 Service와 Method 기반의 Routing 규칙을 정의할 수 있다. HTTPRoute와 동일하게 Header 기반의 조건과 Header 수정, Traffic 복제 `filters`도 이용할 수 있다.

#### 1.3.3. TLSRoute

```yaml {caption="[File 5] TLSRoute 예제", linenos=table}
apiVersion: gateway.networking.k8s.io/v1
kind: TLSRoute
metadata:
  name: version
  namespace: version-namespace
spec:
  parentRefs:
  - name: gateway
    namespace: gateway-namespace
    sectionName: tls
  hostnames:
  - "version.ssup2.com"
  rules:
  - backendRefs:
    - name: version
      port: 8443
```

**TLSRoute**는 Gateway가 수신한 TLS Traffic을 복호화하지 않고 **SNI** (Server Name Indication) 기반으로 Routing하는 규칙을 정의하는 Resource이다. [File 5]는 SNI가 `version.ssup2.com`인 TLS Traffic을 `version` Service로 Routing하는 TLSRoute의 예제를 나타내고 있다. TLSRoute를 이용하기 위해서는 연결된 Gateway Listener의 Protocol이 `TLS`로 설정되어 있고 TLS Mode가 `Passthrough`로 설정되어 있어야 한다. Gateway는 TLS Handshake 과정의 SNI만 확인하고 Traffic을 복호화하지 않고 전달하기 때문에, TLS Termination은 Traffic을 전달받는 Backend에서 수행된다.

#### 1.3.4. TCPRoute

```yaml {caption="[File 6] TCPRoute 예제", linenos=table}
apiVersion: gateway.networking.k8s.io/v1
kind: TCPRoute
metadata:
  name: database
  namespace: database-namespace
spec:
  parentRefs:
  - name: gateway
    namespace: gateway-namespace
    sectionName: tcp
  rules:
  - backendRefs:
    - name: database
      port: 5432
```

**TCPRoute**는 Gateway가 수신한 TCP Traffic을 Service로 Routing하는 규칙을 정의하는 Resource이다. [File 6]은 Gateway의 tcp Listener가 수신한 Traffic을 `database` Service로 전달하는 TCPRoute의 예제를 나타내고 있다. TCPRoute는 L4 기반으로 동작하기 때문에 HTTPRoute와 다르게 `matches`, `filters` 없이 `backendRefs`만 정의할 수 있으며, Traffic을 구분하는 기준은 연결된 Listener의 Port만 존재한다. 따라서 TCPRoute는 일반적으로 `sectionName`을 통해서 특정 Listener에 연결하여 이용하며, Database와 같은 HTTP 기반이 아닌 App을 Cluster 외부에 노출할 때 이용된다.

#### 1.3.5. UDPRoute

```yaml {caption="[File 7] UDPRoute 예제", linenos=table}
apiVersion: gateway.networking.k8s.io/v1
kind: UDPRoute
metadata:
  name: dns
  namespace: dns-namespace
spec:
  parentRefs:
  - name: gateway
    namespace: gateway-namespace
    sectionName: udp
  rules:
  - backendRefs:
    - name: dns
      port: 53
```

**UDPRoute**는 Gateway가 수신한 UDP Traffic을 Service로 Routing하는 규칙을 정의하는 Resource이다. [File 7]은 Gateway의 udp Listener가 수신한 Traffic을 `dns` Service로 전달하는 UDPRoute의 예제를 나타내고 있다. UDPRoute도 TCPRoute와 동일하게 L4 기반으로 동작하기 때문에 연결된 Listener의 Port 기반으로만 Traffic을 구분하며, DNS, VoIP, Game Server와 같은 UDP 기반의 App을 Cluster 외부에 노출할 때 이용된다.

### 1.4. ReferenceGrant

{{< figure caption="[Figure 3] ReferenceGrant를 통한 Namespace 간 참조 허용" src="images/reference-grant.png" width="700px" >}}

```yaml {caption="[File 8] ReferenceGrant 예제", linenos=table}
apiVersion: gateway.networking.k8s.io/v1
kind: ReferenceGrant
metadata:
  name: allow-version-route
  namespace: backend-namespace
spec:
  from:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    namespace: version-namespace
  to:
  - group: ""
    kind: Service
```

**ReferenceGrant**는 서로 다른 Namespace의 Resource 참조를 허용하는 Resource이다. Gateway API에서 Route의 `backendRefs`에 다른 Namespace의 Service를 명시하는 경우, 대상 Service의 Namespace에 ReferenceGrant가 존재하지 않으면 참조가 거부된다. 임의의 Namespace의 Route가 다른 Namespace의 Service를 참조하여 Traffic을 가로챌 수 있는 보안 문제를 방지하기 위함이다.

[Figure 3]과 [File 8]은 `version-namespace` Namespace의 HTTPRoute가 `backend-namespace` Namespace의 Service를 참조할 수 있도록 허용하는 ReferenceGrant의 예제를 나타내고 있다. ReferenceGrant는 참조 대상 Resource가 존재하는 Namespace에 생성되어야 하며, `from`에는 참조를 수행하는 Resource를, `to`에는 참조를 허용할 Resource를 명시한다.

### 1.5. Ingress 비교

{{< table caption="[Table 2] Ingress, Gateway API 비교" >}}
| 구분 | Ingress | Gateway API |
|---|---|---|
| Resource 구성 | Ingress 단일 Resource | GatewayClass, Gateway, Route |
| 역할 분리 | 불가능 | Infrastructure Provider, Cluster Operator, App 개발자 분리 |
| 지원 Protocol | HTTP, HTTPS | HTTP, HTTPS, gRPC, TLS, TCP, UDP |
| 기능 확장 방식 | 구현체별 Annotation | 표준 Filter, Policy |
| Traffic 비율 제어 | 미지원 (구현체 확장 필요) | `backendRefs`의 `weight` 지원 |
{{< /table >}}

[Table 2]는 Ingress와 Gateway API의 주요 차이점을 나타내고 있다. Gateway API는 Ingress의 후속 표준으로 자리잡고 있으며, Kubernetes 공식 문서에서도 신규 환경에서는 Gateway API 이용을 권장하고 있다. Ingress는 더 이상 신규 기능이 추가되지 않는 **Frozen** 상태이며, 대부분의 Ingress Controller 구현체도 Gateway API 지원을 제공하고 있다. 또한 Gateway API는 **GAMMA** (Gateway API for Mesh Management and Administration)를 통해서 Cluster 외부 Traffic뿐만 아니라 Service Mesh의 East-West Traffic 제어에도 이용 범위를 확장하고 있다.

## 2. 참조

* Gateway API : [https://gateway-api.sigs.k8s.io/](https://gateway-api.sigs.k8s.io/)
* Gateway API Concepts : [https://kubernetes.io/docs/concepts/services-networking/gateway/](https://kubernetes.io/docs/concepts/services-networking/gateway/)
* Gateway API v1.5 Release : [https://kubernetes.io/blog/2026/04/21/gateway-api-v1-5/](https://kubernetes.io/blog/2026/04/21/gateway-api-v1-5/)
* Gateway API v1.6 Release : [https://kubernetes.io/blog/2026/08/03/gateway-api-v1-6-release/](https://kubernetes.io/blog/2026/08/03/gateway-api-v1-6-release/)
* Gateway API Implementations : [https://gateway-api.sigs.k8s.io/implementations/](https://gateway-api.sigs.k8s.io/implementations/)

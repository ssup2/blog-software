---
title: Istio Gateway API
draft: true
---

Istio가 Kubernetes Gateway API를 어떻게 구현하여 동작하는지 분석한다. 분석한 Istio의 Version은 1.31이고, Gateway API의 Version은 v1.6이다.

## 1. Istio Gateway API

{{< figure caption="[Figure 1] Istio Gateway API 구성" src="images/istio-gateway-api.png" width="900px" >}}

Istio는 자체 Traffic 관리 API인 Gateway, VirtualService Resource를 제공하지만, Kubernetes 표준 API인 Gateway API의 구현체 역할도 수행한다. Istio는 향후 Gateway API를 기본 Traffic 관리 API로 전환할 계획이며, 신규 기능인 Ambient Mode의 Waypoint도 Gateway API를 기반으로 동작한다. Gateway API의 CRD는 Istio에 포함되어 있지 않기 때문에 별도로 설치되어야 하며, CRD가 설치되어 있으면 istiod가 Gateway API Resource를 Watch하여 처리하기 때문에 별도의 Controller 설치는 필요하지 않다.

[Figure 1]은 Istio Gateway API의 구성을 나타내고 있다. istiod는 Gateway API의 Gateway, Route Resource를 내부의 Istio Gateway, VirtualService 설정으로 변환하고, 변환된 설정은 기존 Istio 설정과 동일한 과정을 거쳐서 xDS를 통해 Envoy에 전달된다. 따라서 Gateway API를 이용해도 실제 Traffic 처리 방식은 Istio API를 이용하는 경우와 동일하다.

{{< table caption="[Table 1] Istio가 제공하는 GatewayClass 종류" >}}
| GatewayClass | 용도 |
|---|---|
| `istio` | Cluster 외부의 Traffic을 수신하는 일반 Gateway |
| `istio-remote` | 원격 Cluster에 존재하여 istiod가 직접 배포하지 않는 Gateway |
| `istio-waypoint` | Ambient Mode에서 L7 Traffic을 처리하는 Waypoint |
| `istio-east-west` | Ambient Mode의 Multi-Cluster 구성에서 Cluster 간 Traffic을 수신하는 Gateway |
{{< /table >}}

[Table 1]은 Istio가 제공하는 GatewayClass의 종류를 나타내고 있다. 일반적인 Ingress Gateway 용도로는 `istio` GatewayClass를 이용하며, 나머지 GatewayClass는 Multi-Cluster 구성이나 Ambient Mode에서 이용된다. `istio-east-west` GatewayClass는 아직 실험 단계의 기능이다.

### 1.1. Gateway 배포

#### 1.1.1. 자동 배포

```yaml {caption="[File 1] Gateway 예제", linenos=table}
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
  infrastructure:
    parametersRef:
      group: ""
      kind: ConfigMap
      name: gateway-options
```

```shell {caption="[Shell 1] Gateway 자동 배포 확인"}
$ kubectl -n gateway-namespace get gateway,deployment,service
NAME                                          CLASS   ADDRESS        PROGRAMMED   AGE
gateway.gateway.networking.k8s.io/gateway     istio   10.0.100.10    True         1m

NAME                            READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/gateway-istio   1/1     1            1           1m

NAME                    TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)                        AGE
service/gateway-istio   LoadBalancer   10.96.10.10    10.0.100.10   15021:30641/TCP,80:31684/TCP   1m
```

Istio API의 Gateway Resource는 이미 배포되어 있는 Ingress Gateway의 설정만 정의하기 때문에 Ingress Gateway를 Helm Chart나 IstioOperator를 통해서 별도로 배포해야 하지만, Gateway API의 Gateway Resource는 설정뿐만 아니라 배포까지 담당한다. [File 1]과 같이 `istio` GatewayClass를 이용하는 Gateway를 생성하면, [Shell 1]과 같이 istiod는 `[Gateway 이름]-[GatewayClass 이름]` 형태의 이름을 갖는 Deployment와 Service를 자동으로 생성한다. 생성된 Deployment의 Pod에서는 Envoy가 동작하며, istiod로부터 xDS를 통해서 설정을 전달받는다. Service의 Type은 기본적으로 `LoadBalancer`로 설정되며, `networking.istio.io/service-type` Annotation을 통해서 변경할 수 있다.

```yaml {caption="[File 2] Gateway 배포 Customize를 위한 ConfigMap 예제", linenos=table}
apiVersion: v1
kind: ConfigMap
metadata:
  name: gateway-options
  namespace: gateway-namespace
data:
  deployment: |
    spec:
      replicas: 3
      template:
        spec:
          containers:
          - name: istio-proxy
            resources:
              requests:
                cpu: 500m
                memory: 512Mi
  service: |
    spec:
      type: ClusterIP
```

자동 배포되는 Deployment와 Service는 Gateway의 infrastructure 설정을 통해서 Customize할 수 있다. infrastructure의 labels, annotations에 명시된 값은 생성되는 Resource에 그대로 전파되며, parametersRef에는 [File 2]와 같은 ConfigMap을 명시할 수 있다. ConfigMap에는 `deployment`, `service`, `serviceAccount`, `horizontalPodAutoscaler`, `podDisruptionBudget` Key를 정의할 수 있으며, 각 Key의 내용은 Strategic Merge Patch 방식으로 생성되는 Resource에 반영된다. Cluster 전체에 적용되는 기본값은 `istio-system` Namespace에 `gateway.istio.io/defaults-for-class` Label을 갖는 ConfigMap을 통해서 GatewayClass 단위로 설정할 수 있다.

#### 1.1.2. 수동 배포

```yaml {caption="[File 3] 수동 배포된 Ingress Gateway를 이용하는 Gateway 예제", linenos=table}
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: gateway
  namespace: istio-system
spec:
  gatewayClassName: istio
  addresses:
  - type: Hostname
    value: istio-ingressgateway.istio-system.svc.cluster.local
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    hostname: "*.ssup2.com"
    allowedRoutes:
      namespaces:
        from: All
```

자동 배포를 이용하지 않고 기존에 배포되어 있는 Ingress Gateway에 Gateway API의 설정만 적용할 수도 있다. [File 3]과 같이 Gateway의 addresses에 Ingress Gateway Service의 이름을 `Hostname` Type으로 명시하면, istiod는 Deployment와 Service를 생성하지 않고 명시된 Service의 Ingress Gateway에 Listener 설정만 전달한다. 이 경우 Ingress Gateway의 Pod에는 `gateway.networking.k8s.io/gateway-name` Label이 설정되어야 Gateway에 연결된 Route와 Policy가 정상적으로 적용된다. 수동 배포는 Ingress Gateway의 배포를 직접 제어해야 하는 경우에 이용되며, 일반적으로는 자동 배포 방식이 권장된다.

### 1.2. Istio 설정 변환

istiod의 Gateway API Controller는 Gateway API Resource를 Istio API와 동일한 형태의 내부 설정으로 변환한다. Gateway Resource는 Istio의 Gateway 설정으로 변환되며, HTTPRoute, GRPCRoute, TLSRoute, TCPRoute Resource는 VirtualService 설정으로 변환된다. 변환된 설정은 istiod의 Memory에만 존재하고 Kubernetes에 저장되지 않기 때문에 kubectl을 통해서는 조회할 수 없으며, Envoy에 전달된 최종 설정은 `istioctl proxy-config` 명령어를 통해서 확인할 수 있다.

Istio는 Gateway API의 Route 중에서 HTTPRoute, GRPCRoute, TLSRoute, TCPRoute를 지원하며, Envoy 기반의 Istio가 UDP Proxy 기능을 제공하지 않기 때문에 UDPRoute는 지원하지 않는다. 또한 Gateway API는 아직 Istio의 모든 기능을 표준으로 제공하지 않기 때문에, Fault Injection이나 Circuit Breaking 같은 기능이 필요한 경우에는 Istio API를 함께 이용해야 한다. DestinationRule은 Host를 기준으로 적용되기 때문에 Gateway API의 Route와 함께 이용할 수 있다.

### 1.3. Istio API 비교

{{< table caption="[Table 2] Istio API, Gateway API 비교" >}}
| 구분 | Istio API | Gateway API |
|---|---|---|
| Resource 구성 | Gateway, VirtualService, DestinationRule | GatewayClass, Gateway, Route |
| Gateway 역할 | 배포된 Ingress Gateway의 설정만 정의 | Gateway 설정과 배포 모두 담당 |
| Protocol 처리 | 하나의 VirtualService에서 HTTP, TLS, TCP 정의 | Protocol별 Route Resource 분리 |
| 역할 분리 | 제한적 | Cluster Operator, App 개발자 분리 |
| 기능 범위 | Istio 전체 기능 | 표준 기능 중심 |
{{< /table >}}

[Table 2]는 Istio API와 Gateway API의 주요 차이점을 나타내고 있다. Istio API는 Istio의 모든 기능을 이용할 수 있지만 Istio 전용 API이기 때문에 다른 구현체로 이식할 수 없으며, Gateway API는 표준 API이기 때문에 이식성이 높지만 Istio의 모든 기능을 이용할 수는 없다. Istio는 두 API를 같이 지원하기 때문에 하나의 Cluster에서 혼용할 수 있지만, 하나의 Ingress Gateway에는 하나의 API만 이용하는 것이 관리 측면에서 권장된다.

### 1.4. Mesh Traffic 제어

```yaml {caption="[File 4] Service에 연결된 HTTPRoute 예제", linenos=table}
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: version
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

Gateway API는 **GAMMA** (Gateway API for Mesh Management and Administration)를 통해서 Cluster 외부에서 유입되는 North-South Traffic뿐만 아니라 Mesh 내부의 East-West Traffic 제어에도 이용할 수 있다. [File 4]는 parentRefs에 Gateway 대신 Service를 명시하여 Mesh 내부에서 `version` Service로 전달되는 Traffic을 `version-v1`, `version-v2` Service로 분배하는 HTTPRoute의 예제를 나타내고 있다. Sidecar Mode에서는 요청을 전송하는 Client의 Sidecar에서 Routing 규칙이 적용되며, 이는 VirtualService를 mesh Gateway에 적용하는 방식과 동일한 역할을 수행한다.

### 1.5. Ambient Mode Waypoint

```yaml {caption="[File 5] Waypoint Gateway 예제", linenos=table}
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: waypoint
  namespace: version-namespace
  labels:
    istio.io/waypoint-for: service
spec:
  gatewayClassName: istio-waypoint
  listeners:
  - name: mesh
    port: 15008
    protocol: HBONE
```

Ambient Mode에서 L7 Traffic을 처리하는 **Waypoint**도 Gateway API를 기반으로 배포된다. [File 5]는 istioctl의 `istioctl waypoint apply` 명령어가 생성하는 Waypoint Gateway를 나타내고 있다. `istio-waypoint` GatewayClass와 HBONE Protocol의 Listener가 설정되어 있으며, Gateway가 생성되면 istiod는 일반 Gateway와 동일하게 Waypoint의 Deployment와 Service를 자동으로 배포한다. 다만 Waypoint의 경우에는 생성되는 Resource의 이름에 GatewayClass 이름이 붙지 않는다.

배포된 Waypoint는 Namespace, Service, Pod에 `istio.io/use-waypoint` Label을 설정하여 이용하며, Label이 설정된 Resource로 전달되는 Traffic은 Waypoint를 경유한다. Waypoint를 경유하는 Traffic에도 [File 4]와 같은 Service에 연결된 HTTPRoute를 통해서 L7 Routing 규칙을 적용할 수 있다. 이처럼 Ambient Mode는 Istio API가 아닌 Gateway API를 중심으로 설계되어 있다.

## 2. 참조

* Istio Kubernetes Gateway API : [https://istio.io/latest/docs/tasks/traffic-management/ingress/gateway-api/](https://istio.io/latest/docs/tasks/traffic-management/ingress/gateway-api/)
* Istio Gateway 배포 : [https://istio.io/latest/docs/setup/additional-setup/gateway/](https://istio.io/latest/docs/setup/additional-setup/gateway/)
* Istio Waypoint : [https://istio.io/latest/docs/ambient/usage/waypoint/](https://istio.io/latest/docs/ambient/usage/waypoint/)
* Gateway API : [https://gateway-api.sigs.k8s.io/](https://gateway-api.sigs.k8s.io/)
* Gateway API GAMMA : [https://gateway-api.sigs.k8s.io/mesh/](https://gateway-api.sigs.k8s.io/mesh/)
* Istio Gateway API 변환 : [https://deepwiki.com/istio/istio/3.5.1-gateway-api-integration-and-conversion](https://deepwiki.com/istio/istio/3.5.1-gateway-api-integration-and-conversion)

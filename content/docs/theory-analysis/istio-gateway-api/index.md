---
title: Istio Gateway API
draft: true
---

Istio가 Kubernetes Gateway API를 어떻게 구현하여 동작하는지 분석한다. 분석한 Istio의 Version은 1.31이고, Gateway API의 Version은 v1.6이다.

## 1. Istio Gateway API

{{< figure caption="[Figure 1] Istio Gateway API 구성" src="images/istio-gateway-api.png" width="900px" >}}

Istio는 자체 Traffic 관리 API인 Gateway, VirtualService Resource를 제공하지만, Kubernetes 표준 API인 **Gateway API**의 구현체 역할도 수행한다. Istio는 향후 Gateway API를 기본 Traffic 관리 API로 전환할 계획이며, 신규 기능인 Ambient Mode의 Waypoint도 Gateway API를 기반으로 동작한다. Gateway API의 CRD는 Istio에 포함되어 있지 않기 때문에 별도로 설치되어야 하며, CRD가 설치되어 있으면 istiod가 Gateway API Resource를 Watch하여 처리하기 때문에 별도의 Controller 설치는 필요하지 않다.

[Figure 1]은 Istio Gateway API의 구성을 나타내고 있다. istiod는 Gateway API의 Gateway, Route Resource를 내부의 Istio Gateway, VirtualService 설정으로 변환하고, 변환된 설정은 기존 Istio 설정과 동일한 과정을 거쳐서 xDS를 통해 Envoy에 전달된다. 따라서 Gateway API를 이용해도 실제 Traffic 처리 방식은 Istio API를 이용하는 경우와 동일하다.

{{< table caption="[Table 1] Istio가 제공하는 GatewayClass 종류" >}}
| GatewayClass | 용도 |
|---|---|
| `istio` | Cluster 외부의 Traffic을 수신하는 일반 Gateway |
| `istio-remote` | 원격 Cluster에 존재하여 istiod가 직접 배포하지 않는 Gateway |
| `istio-waypoint` | Ambient Mode에서 L7 Traffic을 처리하는 Waypoint |
| `istio-east-west` | Ambient Mode의 Multi-Cluster 구성에서 Cluster 간 Traffic을 수신하는 Gateway |
{{< /table >}}

[Table 1]은 Istio가 제공하는 GatewayClass의 종류를 나타내고 있다. 일반적인 Ingress Gateway 용도로는 `istio` GatewayClass를 이용하며, 나머지 GatewayClass는 Multi-Cluster 구성이나 Ambient Mode에서 이용된다. Sidecar Mode로 설치하는 경우에는 `istio`, `istio-remote` GatewayClass만 생성되며, `istio-waypoint`와 `istio-east-west` GatewayClass는 Ambient Mode로 설치하는 경우에 생성된다. `istio-east-west` GatewayClass는 아직 실험 단계의 기능이다.

### 1.1. Test 환경 구축

```shell {caption="[Shell 1] Test 환경 구성"}
# Create kind cluster
$ kind create cluster --name istio-gateway-api

# Install gateway api CRDs (v1.6.0 standard channel)
$ kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.0/standard-install.yaml

# Install istio (minimal profile, sidecar mode)
$ istioctl install --set profile=minimal -y
```

```shell {caption="[Shell 2] GatewayClass 확인"}
$ kubectl get gatewayclass
NAME           CONTROLLER                    ACCEPTED   AGE
istio          istio.io/gateway-controller   True       5s
istio-remote   istio.io/unmanaged-gateway    True       5s
```

```yaml {caption="[File 1] Test Workload 구성", linenos=table}
apiVersion: v1
kind: Namespace
metadata:
  name: gateway-namespace
---
apiVersion: v1
kind: Namespace
metadata:
  name: version-namespace
  labels:
    istio-injection: enabled
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: version-v1
  namespace: version-namespace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: version
      version: v1
  template:
    metadata:
      labels:
        app: version
        version: v1
    spec:
      containers:
      - name: http-echo
        image: hashicorp/http-echo:1.0
        args:
        - -text=version-v1
        - -listen=:8080
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: version-v1
  namespace: version-namespace
spec:
  selector:
    app: version
    version: v1
  ports:
  - name: http
    port: 8080
    targetPort: 8080
---
# version-v2 Deployment and Service are identical to version-v1 except the version label and text
apiVersion: v1
kind: Service
metadata:
  name: version
  namespace: version-namespace
spec:
  selector:
    app: version
  ports:
  - name: http
    port: 8080
    targetPort: 8080
---
apiVersion: v1
kind: Pod
metadata:
  name: client
  namespace: version-namespace
  labels:
    app: client
spec:
  containers:
  - name: curl
    image: curlimages/curl:8.10.1
    command: ["sleep", "infinity"]
```

```shell {caption="[Shell 3] Test Workload 확인"}
$ kubectl -n version-namespace get pods,services
NAME                              READY   STATUS    RESTARTS   AGE
pod/client                        2/2     Running   0          3h20m
pod/version-v1-7cf5688dfc-rcw7t   2/2     Running   0          3h20m
pod/version-v2-69bf76f867-htddz   2/2     Running   0          3h20m

NAME                 TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
service/version      ClusterIP   10.96.4.246     <none>        8080/TCP   3h20m
service/version-v1   ClusterIP   10.96.255.26    <none>        8080/TCP   3h20m
service/version-v2   ClusterIP   10.96.153.106   <none>        8080/TCP   3h20m
```

이후 본문의 동작 확인은 [Shell 1]과 같이 kind Cluster에 Gateway API v1.6.0 Standard Channel CRD와 Istio 1.31.0을 minimal Profile의 Sidecar Mode로 설치하여 수행한다. istiod가 설치되면 GatewayClass도 함께 생성되기 때문에, [Shell 2]의 GatewayClass 목록을 통해서 Istio가 Gateway API 구현체로 정상 설치된 것을 확인할 수 있다. `istio`, `istio-remote` GatewayClass가 생성되어 있으며, Ambient Mode를 설치하지 않았기 때문에 `istio-waypoint` GatewayClass는 존재하지 않는다.

Test Workload는 [File 1]과 같이 자신의 이름을 응답하는 `version-v1`, `version-v2` Deployment와 Service, 두 Deployment의 Pod를 모두 선택하는 `version` Service, 요청을 전송하는 `client` Pod로 구성하며, [File 1]을 적용하면 [Shell 3]과 같이 `version-namespace` Namespace에 Test Workload가 생성된 것을 확인할 수 있다. `version-namespace` Namespace에는 `istio-injection` Label이 설정되어 있기 때문에, 모든 Pod의 READY가 2/2로 Sidecar가 주입된 것을 확인할 수 있다. Gateway는 `gateway-namespace` Namespace에 생성한다.

### 1.2. Gateway 배포

#### 1.2.1. 자동 배포

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
  infrastructure:
    parametersRef:
      group: ""
      kind: ConfigMap
      name: gateway-options
```

Istio API의 Gateway Resource는 이미 배포되어 있는 Ingress Gateway의 설정만 정의하기 때문에 Ingress Gateway를 Helm Chart나 IstioOperator를 통해서 별도로 배포해야 하지만, Gateway API의 Gateway Resource는 설정뿐만 아니라 배포까지 담당한다. [File 2]와 같이 `istio` GatewayClass를 이용하는 Gateway를 생성하면 istiod는 `[Gateway 이름]-[GatewayClass 이름]` 형태의 이름을 갖는 Deployment와 Service를 자동으로 생성한다. 생성된 Deployment의 Pod에서는 Envoy가 동작하며, istiod로부터 xDS를 통해서 설정을 전달받는다. Service의 Type은 기본적으로 `LoadBalancer`로 설정되며, `networking.istio.io/service-type` Annotation을 통해서 변경할 수 있다.

```yaml {caption="[File 3] Gateway 배포 Customize를 위한 ConfigMap 예제", linenos=table}
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

자동 배포되는 Deployment와 Service는 Gateway의 `infrastructure` 설정을 통해서 Customize할 수 있다. `infrastructure`의 `labels`, `annotations`에 명시된 값은 생성되는 Resource에 그대로 전파되며, `parametersRef`에는 [File 3]과 같은 ConfigMap을 명시할 수 있다. ConfigMap에는 `deployment`, `service`, `serviceAccount`, `horizontalPodAutoscaler`, `podDisruptionBudget` Key를 정의할 수 있으며, 각 Key의 내용은 Strategic Merge Patch 방식으로 생성되는 Resource에 반영된다. Cluster 전체에 적용되는 기본값은 `istio-system` Namespace에 `gateway.istio.io/defaults-for-class` Label을 갖는 ConfigMap을 통해서 GatewayClass 단위로 설정할 수 있다.

```shell {caption="[Shell 4] Gateway 자동 배포 확인"}
$ kubectl -n gateway-namespace get gateway,deployment,service
NAME                                        CLASS   ADDRESS                                             PROGRAMMED   AGE
gateway.gateway.networking.k8s.io/gateway   istio   gateway-istio.gateway-namespace.svc.cluster.local   True         25s

NAME                            READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/gateway-istio   3/3     3            3           25s

NAME                    TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)            AGE
service/gateway-istio   ClusterIP   10.96.214.92   <none>        15021/TCP,80/TCP   25s

$ kubectl -n gateway-namespace get deployment gateway-istio -o jsonpath='{.spec.template.spec.containers[0].resources.requests}'
{"cpu":"500m","memory":"512Mi"}
```

[File 2]의 Gateway와 [File 3]의 ConfigMap을 실제로 적용하면 [Shell 4]와 같이 `gateway-istio` Deployment와 Service가 자동으로 생성된 것을 확인할 수 있다. ConfigMap의 내용에 따라서 Deployment의 Replica는 3개로, istio-proxy Container의 resources는 명시된 값으로, Service의 Type은 `ClusterIP`로 생성되어 `parametersRef`를 통한 Customize가 반영된 것도 확인할 수 있다. kind Cluster에는 LoadBalancer가 존재하지 않기 때문에 Service의 Type을 `ClusterIP`로 변경하였으며, Gateway의 ADDRESS에는 생성된 Service의 Domain 주소가 설정된다.

#### 1.2.2. 수동 배포

```yaml {caption="[File 4] 수동 배포된 Ingress Gateway를 이용하는 Gateway 예제", linenos=table}
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

자동 배포를 이용하지 않고 기존에 배포되어 있는 Ingress Gateway에 Gateway API의 설정만 적용할 수도 있다. [File 4]와 같이 Gateway의 `addresses`에 Ingress Gateway Service의 이름을 `Hostname` Type으로 명시하면, istiod는 Deployment와 Service를 생성하지 않고 명시된 Service의 Ingress Gateway에 Listener 설정만 전달한다. 이 경우 Ingress Gateway의 Pod에는 `gateway.networking.k8s.io/gateway-name` Label이 설정되어야 Gateway에 연결된 Route와 Policy가 정상적으로 적용된다. 수동 배포는 Ingress Gateway의 배포를 직접 제어해야 하는 경우에 이용되며, 일반적으로는 자동 배포 방식이 권장된다.

#### 1.2.3. 원격 Gateway 등록

```yaml {caption="[File 5] 원격 Cluster의 East-West Gateway를 등록하는 Gateway 예제", linenos=table}
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: cross-network-gateway
  namespace: istio-system
  labels:
    topology.istio.io/network: network2
spec:
  gatewayClassName: istio-remote
  addresses:
  - type: IPAddress
    value: 10.0.200.10
  listeners:
  - name: cross-network
    port: 15443
    protocol: TLS
    tls:
      mode: Passthrough
```

`istio-remote` GatewayClass는 istiod가 배포하거나 관리하지 않는 Gateway를 등록할 때 이용하며, [Shell 2]에서 확인할 수 있는 것처럼 별도의 `istio.io/unmanaged-gateway` Controller 이름으로 처리된다. `istio-remote` GatewayClass를 이용하는 Gateway가 생성되어도 istiod는 Deployment와 Service를 생성하지 않으며, `addresses`에 명시된 주소 정보만 이용한다. [File 5]는 Multi-Network Mesh 구성에서 다른 Network의 원격 Cluster에 존재하는 East-West Gateway를 등록하는 Gateway의 예제를 나타내고 있다.

`topology.istio.io/network` Label에는 원격 Gateway가 속한 Network를 명시하며, 등록 이후 해당 Network의 Workload로 전달되는 Traffic은 `addresses`에 명시된 East-West Gateway 주소로 전송된다. 기존에는 Network 간 Gateway 주소를 meshConfig의 `meshNetworks` 설정으로 관리해야 했지만, `istio-remote` GatewayClass를 이용하면 Gateway API Resource로 선언적으로 관리할 수 있다.

### 1.3. Istio 설정 변환

istiod의 Gateway API Controller는 Gateway API Resource를 Istio API와 동일한 형태의 내부 설정으로 변환한다. Gateway Resource는 Istio의 Gateway 설정으로 변환되며, HTTPRoute, GRPCRoute, TLSRoute, TCPRoute Resource는 VirtualService 설정으로 변환된다. 변환된 설정은 istiod의 Memory에만 존재하고 Kubernetes에 저장되지 않기 때문에 kubectl을 통해서는 조회할 수 없으며, Envoy에 전달된 최종 설정은 `istioctl proxy-config` 명령어를 통해서 확인할 수 있다.

```yaml {caption="[File 6] Gateway에 연결된 HTTPRoute 예제", linenos=table}
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
        value: /
    backendRefs:
    - name: version-v1
      port: 8080
      weight: 90
    - name: version-v2
      port: 8080
      weight: 10
```

```shell {caption="[Shell 5] Gateway를 통한 Traffic 분배 확인"}
# Port-forward to the gateway service
$ kubectl -n gateway-namespace port-forward svc/gateway-istio 8080:80 &

# Send 100 requests
$ for i in $(seq 1 100); do curl -s -H "Host: version.ssup2.com" http://127.0.0.1:8080/; done | sort | uniq -c
  93 version-v1
   7 version-v2
```

[File 6]은 Gateway가 수신한 Traffic을 `version-v1` Service에 90%, `version-v2` Service에 10% 비율로 분배하는 HTTPRoute의 예제를 나타내고 있다. HTTPRoute 적용 후 [Shell 5]와 같이 100번의 요청을 전송하면 93번은 version-v1이, 7번은 version-v2가 응답하여 weight 설정에 근접한 비율로 분배되는 것을 확인할 수 있다. kind Cluster에는 LoadBalancer가 존재하지 않기 때문에 port-forward를 통해서 요청을 전송하였다.

```shell {caption="[Shell 6] HTTPRoute의 내부 설정 변환 확인"}
# No VirtualService is stored in kubernetes
$ kubectl get virtualservice -A
No resources found

# Check the converted route config of the gateway envoy
$ istioctl proxy-config routes gateway-istio-6cf9dd97dd-8lrn4 -n gateway-namespace --name http.80 -o json
[
    {
        "name": "http.80",
        "virtualHosts": [
            {
                "name": "version.ssup2.com:80",
                "domains": [
                    "version.ssup2.com"
                ],
                "routes": [
                    {
                        "name": "version-namespace.version.0",
                        ...
                        "route": {
                            "weightedClusters": {
                                "clusters": [
                                    {
                                        "name": "outbound|8080||version-v1.version-namespace.svc.cluster.local",
                                        "weight": 90
                                    },
                                    {
                                        "name": "outbound|8080||version-v2.version-namespace.svc.cluster.local",
                                        "weight": 10
                                    }
                                ]
                            },
                            ...
                        },
                        "metadata": {
                            "filterMetadata": {
                                "istio": {
                                    "config": "/apis/networking.istio.io/v1/namespaces/version-namespace/virtual-service/gateway-namespace~gateway~istio-autogenerated-k8s-gateway~http~version.ssup2.com"
                                }
                            }
                        },
                        ...
```

[Shell 6]과 같이 HTTPRoute를 적용해도 Kubernetes에는 VirtualService가 저장되지 않지만, Gateway Envoy의 Route 설정에는 HTTPRoute의 내용이 weightedClusters로 변환되어 반영된 것을 확인할 수 있다. Route의 metadata에는 `istio-autogenerated-k8s-gateway` 이름이 포함된 VirtualService 경로가 명시되어 있으며, 이를 통해서 istiod가 HTTPRoute를 Memory 상의 VirtualService로 변환하여 처리하는 것을 확인할 수 있다.

Istio는 Gateway API의 Route 중에서 HTTPRoute, GRPCRoute, TLSRoute, TCPRoute를 지원하며, Envoy 기반의 Istio가 UDP Proxy 기능을 제공하지 않기 때문에 UDPRoute는 지원하지 않는다. 또한 Gateway API는 아직 Istio의 모든 기능을 표준으로 제공하지 않기 때문에, Fault Injection이나 Circuit Breaking 같은 기능이 필요한 경우에는 Istio API를 함께 이용해야 한다. DestinationRule은 Host를 기준으로 적용되기 때문에 Gateway API의 Route와 함께 이용할 수 있다.

### 1.4. Istio API 비교

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

### 1.5. Mesh Traffic 제어

```yaml {caption="[File 7] Service에 연결된 HTTPRoute 예제", linenos=table}
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: version-mesh
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

Gateway API는 **GAMMA** (Gateway API for Mesh Management and Administration)를 통해서 Cluster 외부에서 유입되는 North-South Traffic뿐만 아니라 Mesh 내부의 East-West Traffic 제어에도 이용할 수 있다. [File 7]은 `parentRefs`에 Gateway 대신 Service를 명시하여 Mesh 내부에서 `version` Service로 전달되는 Traffic을 `version-v1`, `version-v2` Service로 분배하는 HTTPRoute의 예제를 나타내고 있다. Sidecar Mode에서는 요청을 전송하는 Client의 Sidecar에서 Routing 규칙이 적용되며, 이는 VirtualService를 mesh Gateway에 적용하는 방식과 동일한 역할을 수행한다.

```shell {caption="[Shell 7] Mesh Traffic 분배 확인"}
# Before applying the mesh httproute
$ kubectl -n version-namespace exec client -c curl -- sh -c 'for i in $(seq 1 100); do curl -s http://version:8080/; done' | sort | uniq -c
  55 version-v1
  45 version-v2

# After applying the mesh httproute
$ kubectl -n version-namespace exec client -c curl -- sh -c 'for i in $(seq 1 100); do curl -s http://version:8080/; done' | sort | uniq -c
  90 version-v1
  10 version-v2
```

[Shell 7]은 [File 7]의 HTTPRoute 적용 전후에 `client` Pod에서 `version` Service로 100번의 요청을 전송한 결과를 나타내고 있다. 적용 전에는 Routing 규칙이 없기 때문에 요청은 `version` Service의 Endpoint인 version-v1, version-v2 Pod로 약 50:50 비율로 분배되지만, 적용 후에는 HTTPRoute의 weight 설정에 따라서 `version-v1`, `version-v2` Service로 90:10 비율로 분배되는 것을 확인할 수 있다.

```shell {caption="[Shell 8] Client Sidecar의 Route 설정 확인"}
$ istioctl proxy-config routes client -n version-namespace --name 8080 -o json
...
            {
                "name": "version.version-namespace.svc.cluster.local:8080",
                "domains": [
                    "version.version-namespace.svc.cluster.local",
                    ...
                ],
                "routes": [
                    {
                        "name": "version-namespace.version-mesh.0",
                        ...
                        "route": {
                            "weightedClusters": {
                                "clusters": [
                                    {
                                        "name": "outbound|8080||version-v1.version-namespace.svc.cluster.local",
                                        "weight": 90
                                    },
                                    {
                                        "name": "outbound|8080||version-v2.version-namespace.svc.cluster.local",
                                        "weight": 10
                                    }
                                ]
                            },
                            ...
```

[Shell 8]과 같이 Routing 규칙은 요청을 전송하는 `client` Pod의 Sidecar Route 설정에 반영된 것을 확인할 수 있으며, Mesh Traffic의 규칙이 Gateway가 아니라 Client의 Sidecar에서 적용되는 것을 알 수 있다.

### 1.6. Ambient Mode Waypoint

```yaml {caption="[File 8] Waypoint Gateway 예제", linenos=table}
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

Ambient Mode에서 L7 Traffic을 처리하는 **Waypoint**도 Gateway API를 기반으로 배포된다. [File 8]은 istioctl의 `istioctl waypoint apply` 명령어가 생성하는 Waypoint Gateway를 나타내고 있다. `istio-waypoint` GatewayClass와 HBONE Protocol의 Listener가 설정되어 있으며, Gateway가 생성되면 istiod는 일반 Gateway와 동일하게 Waypoint의 Deployment와 Service를 자동으로 배포한다. 다만 Waypoint의 경우에는 생성되는 Resource의 이름에 GatewayClass 이름이 붙지 않는다.

배포된 Waypoint는 Namespace, Service, Pod에 `istio.io/use-waypoint` Label을 설정하여 이용하며, Label이 설정된 Resource로 전달되는 Traffic은 Waypoint를 경유한다. Waypoint를 경유하는 Traffic에도 [File 7]과 같은 Service에 연결된 HTTPRoute를 통해서 L7 Routing 규칙을 적용할 수 있다. 이처럼 Ambient Mode는 Istio API가 아닌 Gateway API를 중심으로 설계되어 있다.

## 2. 참조

* Istio Kubernetes Gateway API : [https://istio.io/latest/docs/tasks/traffic-management/ingress/gateway-api/](https://istio.io/latest/docs/tasks/traffic-management/ingress/gateway-api/)
* Istio Gateway 배포 : [https://istio.io/latest/docs/setup/additional-setup/gateway/](https://istio.io/latest/docs/setup/additional-setup/gateway/)
* Istio Waypoint : [https://istio.io/latest/docs/ambient/usage/waypoint/](https://istio.io/latest/docs/ambient/usage/waypoint/)
* Gateway API : [https://gateway-api.sigs.k8s.io/](https://gateway-api.sigs.k8s.io/)
* Gateway API GAMMA : [https://gateway-api.sigs.k8s.io/docs/mesh/mesh-overview/](https://gateway-api.sigs.k8s.io/docs/mesh/mesh-overview/)
* Istio Gateway API 변환 : [https://deepwiki.com/istio/istio/3.5.1-gateway-api-integration-and-conversion](https://deepwiki.com/istio/istio/3.5.1-gateway-api-integration-and-conversion)

---
title: Istio Gateway API
---

This post analyzes how Istio implements and operates the Kubernetes Gateway API. The analyzed Istio Version is 1.31, and the Gateway API Version is v1.6.

## 1. Istio Gateway API

{{< figure caption="[Figure 1] Istio Gateway API Architecture" src="images/istio-gateway-api.png" width="900px" >}}

Istio provides its own Traffic management APIs, the Gateway and VirtualService Resources, but it also serves as an implementation of the **Gateway API**, the Kubernetes standard API. Istio plans to transition to the Gateway API as its default Traffic management API in the future, and the Waypoint of the new Ambient Mode also operates based on the Gateway API. Since the CRDs of the Gateway API are not included in Istio, they must be installed separately, and once the CRDs are installed, istiod Watches and processes Gateway API Resources, so no separate Controller installation is required.

[Figure 1] shows the architecture of the Istio Gateway API. istiod converts the Gateway API's Gateway and Route Resources into internal Istio Gateway and VirtualService configuration, and the converted configuration goes through the same process as existing Istio configuration and is delivered to Envoy via xDS. Therefore, even when using the Gateway API, the actual Traffic processing behavior is identical to the case of using the Istio API.

{{< table caption="[Table 1] GatewayClass Types Provided by Istio" >}}
| GatewayClass | Purpose |
|---|---|
| `istio` | General Gateway that receives Traffic from outside the Cluster |
| `istio-remote` | Gateway that exists in a remote Cluster and is not deployed directly by istiod |
| `istio-waypoint` | Waypoint that handles L7 Traffic in Ambient Mode |
| `istio-east-west` | Gateway that receives inter-Cluster Traffic in the Multi-Cluster setup of Ambient Mode |
{{< /table >}}

[Table 1] shows the types of GatewayClasses provided by Istio. The `istio` GatewayClass is used for the typical Ingress Gateway purpose, and the remaining GatewayClasses are used in Multi-Cluster setups or Ambient Mode. When installing in Sidecar Mode, only the `istio` and `istio-remote` GatewayClasses are created, and the `istio-waypoint` and `istio-east-west` GatewayClasses are created when installing in Ambient Mode. The `istio-east-west` GatewayClass is still an experimental feature.

### 1.1. Test Environment Setup

{{< figure caption="[Figure 2] Test Environment" src="images/test-environment.png" width="1000px" >}}

```shell {caption="[Shell 1] Test Environment Setup"}
# Create kind cluster
$ kind create cluster --name istio-gateway-api

# Install gateway api CRDs (v1.6.0 standard channel)
$ kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.0/standard-install.yaml

# Install istio (minimal profile, sidecar mode)
$ istioctl install --set profile=minimal -y
```

```shell {caption="[Shell 2] Checking GatewayClasses"}
$ kubectl get gatewayclass
NAME           CONTROLLER                    ACCEPTED   AGE
istio          istio.io/gateway-controller   True       5s
istio-remote   istio.io/unmanaged-gateway    True       5s
```

The behavior checks in the rest of this post are performed by installing the Gateway API v1.6.0 Standard Channel CRDs and Istio 1.31.0 with the `minimal` Profile in Sidecar Mode on a kind Cluster, as shown in [Shell 1]. Since the GatewayClasses are created together when istiod is installed, the GatewayClass list in [Shell 2] confirms that Istio has been installed correctly as a Gateway API implementation. The `istio` and `istio-remote` GatewayClasses have been created, and since Ambient Mode was not installed, the `istio-waypoint` GatewayClass does not exist.

```yaml {caption="[File 1] Test Workload Configuration", linenos=table}
apiVersion: v1
kind: Namespace
metadata:
  name: gateway-namespace
---
apiVersion: v1
kind: Namespace
metadata:
  name: server-namespace
  labels:
    istio-injection: enabled
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: server-v1
  namespace: server-namespace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: server
      version: v1
  template:
    metadata:
      labels:
        app: server
        version: v1
    spec:
      containers:
      - name: http-echo
        image: hashicorp/http-echo:1.0
        args:
        - -text=server-v1
        - -listen=:8080
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: server-v1
  namespace: server-namespace
spec:
  selector:
    app: server
    version: v1
  ports:
  - name: http
    port: 8080
    targetPort: 8080
---
# server-v2 Deployment and Service are identical to server-v1 except the version label and text
apiVersion: v1
kind: Service
metadata:
  name: server
  namespace: server-namespace
spec:
  selector:
    app: server
  ports:
  - name: http
    port: 8080
    targetPort: 8080
---
apiVersion: v1
kind: Pod
metadata:
  name: client
  namespace: server-namespace
  labels:
    app: client
spec:
  containers:
  - name: curl
    image: curlimages/curl:8.10.1
    command: ["sleep", "infinity"]
```

```shell {caption="[Shell 3] Checking Test Workloads"}
$ kubectl -n server-namespace get pods,services
NAME                              READY   STATUS    RESTARTS   AGE
pod/client                        2/2     Running   0          3h20m
pod/server-v1-7cf5688dfc-rcw7t    2/2     Running   0          3h20m
pod/server-v2-69bf76f867-htddz    2/2     Running   0          3h20m

NAME                TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
service/server      ClusterIP   10.96.4.246     <none>        8080/TCP   3h20m
service/server-v1   ClusterIP   10.96.255.26    <none>        8080/TCP   3h20m
service/server-v2   ClusterIP   10.96.153.106   <none>        8080/TCP   3h20m
```

The Test Workloads consist of the `server-v1` and `server-v2` Deployments and Services that respond with their own names, the `server` Service that selects the Pods of both Deployments, and the `client` Pod that sends requests, as shown in [File 1]. Applying [File 1] creates the Test Workloads in the `server-namespace` Namespace as shown in [Shell 3]. Since the `istio-injection` Label is set on the `server-namespace` Namespace, the READY of every Pod is 2/2, confirming that the Sidecar has been injected. The Gateway is created in the `gateway-namespace` Namespace.

### 1.2. Gateway Deployment

#### 1.2.1. Automated Deployment

```yaml {caption="[File 2] Gateway Example", linenos=table}
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

The Gateway Resource of the Istio API defines only the configuration of an already deployed Ingress Gateway, so the Ingress Gateway must be deployed separately through a Helm Chart or IstioOperator, whereas the Gateway Resource of the Gateway API is responsible not only for configuration but also for deployment. When a Gateway using the `istio` GatewayClass is created as shown in [File 2], istiod automatically creates a Deployment and Service whose names take the form `[Gateway name]-[GatewayClass name]`. Envoy runs in the Pods of the created Deployment and receives its configuration from istiod via xDS. The Type of the Service is set to `LoadBalancer` by default and can be changed through the `networking.istio.io/service-type` Annotation.

```yaml {caption="[File 3] ConfigMap Example for Customizing Gateway Deployment", linenos=table}
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

The automatically deployed Deployment and Service can be Customized through the `infrastructure` setting of the Gateway. Values specified in `labels` and `annotations` of `infrastructure` are propagated as-is to the created Resources, and a ConfigMap like [File 3] can be specified in `parametersRef`. The ConfigMap can define the `deployment`, `service`, `serviceAccount`, `horizontalPodAutoscaler`, and `podDisruptionBudget` Keys, and the contents of each Key are reflected in the created Resources in the Strategic Merge Patch manner. Cluster-wide defaults can be set per GatewayClass through a ConfigMap with the `gateway.istio.io/defaults-for-class` Label in the `istio-system` Namespace.

```shell {caption="[Shell 4] Checking Automated Gateway Deployment"}
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

Applying the Gateway of [File 2] and the ConfigMap of [File 3] shows that the `gateway-istio` Deployment and Service are automatically created, as can be seen in [Shell 4]. According to the contents of the ConfigMap, the Deployment has 3 Replicas, the `resources` of the `istio-proxy` Container are set to the specified values, and the Service Type is created as `ClusterIP`, confirming that the Customization through `parametersRef` has been reflected. Since no LoadBalancer exists in a kind Cluster, the Service Type was changed to `ClusterIP`, and the ADDRESS of the Gateway is set to the Domain address of the created Service.

#### 1.2.2. Manual Deployment

```yaml {caption="[File 4] Gateway Example Using a Manually Deployed Ingress Gateway", linenos=table}
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

Instead of using automated deployment, it is also possible to apply only the Gateway API configuration to an already deployed Ingress Gateway. When the name of the Ingress Gateway Service is specified in the Gateway's `addresses` with the `Hostname` Type as shown in [File 4], istiod does not create a Deployment and Service and only delivers the Listener configuration to the Ingress Gateway of the specified Service. In this case, the `gateway.networking.k8s.io/gateway-name` Label must be set on the Pods of the Ingress Gateway for the Routes and Policies attached to the Gateway to be applied correctly. Manual deployment is used when the deployment of the Ingress Gateway must be controlled directly, and the automated deployment approach is generally recommended.

#### 1.2.3. Remote Gateway Registration

```yaml {caption="[File 5] Gateway Example Registering an East-West Gateway in a Remote Cluster", linenos=table}
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

The `istio-remote` GatewayClass is used to register Gateways that istiod does not deploy or manage, and as can be seen in [Shell 2], it is processed under the separate Controller name `istio.io/unmanaged-gateway`. Even when a Gateway using the `istio-remote` GatewayClass is created, istiod does not create a Deployment and Service and only uses the address information specified in `addresses`. [File 5] shows an example of a Gateway that registers an East-West Gateway existing in a remote Cluster on a different Network in a Multi-Network Mesh setup.

The `topology.istio.io/network` Label specifies the Network to which the remote Gateway belongs, and after registration, Traffic sent to Workloads of that Network is transmitted to the East-West Gateway address specified in `addresses`. Previously, inter-Network Gateway addresses had to be managed through the `meshNetworks` setting of `meshConfig`, but with the `istio-remote` GatewayClass, they can be managed declaratively as Gateway API Resources.

### 1.3. Istio Configuration Conversion

istiod's Gateway API Controller converts Gateway API Resources into internal configuration of the same form as the Istio API. The Gateway Resource is converted into Istio's Gateway configuration, and the HTTPRoute, GRPCRoute, TLSRoute, and TCPRoute Resources are converted into VirtualService configuration. The converted configuration exists only in istiod's Memory and is not stored in Kubernetes, so it cannot be queried through `kubectl`, and the final configuration delivered to Envoy can be checked through the `istioctl proxy-config` command.

```yaml {caption="[File 6] HTTPRoute Example Attached to a Gateway", linenos=table}
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: server
  namespace: server-namespace
spec:
  parentRefs:
  - name: gateway
    namespace: gateway-namespace
  hostnames:
  - "server.ssup2.com"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: server-v1
      port: 8080
      weight: 90
    - name: server-v2
      port: 8080
      weight: 10
```

```shell {caption="[Shell 5] Checking Traffic Distribution through the Gateway"}
# Port-forward to the gateway service
$ kubectl -n gateway-namespace port-forward svc/gateway-istio 8080:80 &

# Send 100 requests
$ for i in $(seq 1 100); do curl -s -H "Host: server.ssup2.com" http://127.0.0.1:8080/; done | sort | uniq -c
  93 server-v1
   7 server-v2
```

[File 6] shows an example of an HTTPRoute that distributes the Traffic received by the Gateway to the `server-v1` Service at a 90% ratio and the `server-v2` Service at a 10% ratio. After applying the HTTPRoute, sending 100 requests as shown in [Shell 5] results in 93 responses from `server-v1` and 7 responses from `server-v2`, confirming that the distribution follows a ratio close to the `weight` setting. Since no LoadBalancer exists in a kind Cluster, the requests were sent through `port-forward`.

```shell {caption="[Shell 6] Checking the Internal Configuration Conversion of the HTTPRoute"}
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
                "name": "server.ssup2.com:80",
                "domains": [
                    "server.ssup2.com"
                ],
                "routes": [
                    {
                        "name": "server-namespace.server.0",
                        ...
                        "route": {
                            "weightedClusters": {
                                "clusters": [
                                    {
                                        "name": "outbound|8080||server-v1.server-namespace.svc.cluster.local",
                                        "weight": 90
                                    },
                                    {
                                        "name": "outbound|8080||server-v2.server-namespace.svc.cluster.local",
                                        "weight": 10
                                    }
                                ]
                            },
                            ...
                        },
                        "metadata": {
                            "filterMetadata": {
                                "istio": {
                                    "config": "/apis/networking.istio.io/v1/namespaces/server-namespace/virtual-service/gateway-namespace~gateway~istio-autogenerated-k8s-gateway~http~server.ssup2.com"
                                }
                            }
                        },
                        ...
```

As shown in [Shell 6], even after applying the HTTPRoute, no VirtualService is stored in Kubernetes, but the contents of the HTTPRoute have been converted into `weightedClusters` and reflected in the Route configuration of the Gateway Envoy. The `metadata` of the Route specifies a VirtualService path containing the name `istio-autogenerated-k8s-gateway`, which confirms that istiod converts the HTTPRoute into an in-Memory VirtualService for processing.

Among the Routes of the Gateway API, Istio supports HTTPRoute, GRPCRoute, TLSRoute, and TCPRoute, and since Envoy-based Istio does not provide a UDP Proxy feature, UDPRoute is not supported. Also, since the Gateway API does not yet provide all of Istio's features as standards, the Istio API must be used together when features like Fault Injection or Circuit Breaking are needed. DestinationRule is applied based on the Host, so it can be used together with the Routes of the Gateway API.

### 1.4. Comparison with the Istio API

{{< table caption="[Table 2] Comparison of Istio API and Gateway API" >}}
| Category | Istio API | Gateway API |
|---|---|---|
| Resource Composition | Gateway, VirtualService, DestinationRule | GatewayClass, Gateway, Route |
| Gateway Role | Defines only the configuration of a deployed Ingress Gateway | Handles both Gateway configuration and deployment |
| Protocol Handling | Defines HTTP, TLS, TCP in a single VirtualService | Separate Route Resources per Protocol |
| Role Separation | Limited | Separation of Cluster Operators and App developers |
| Feature Scope | All Istio features | Focused on standard features |
{{< /table >}}

[Table 2] shows the main differences between the Istio API and the Gateway API. The Istio API allows the use of all of Istio's features, but since it is an Istio-specific API, it cannot be ported to other implementations, whereas the Gateway API is a standard API with high portability but cannot use all of Istio's features. Since Istio supports both APIs, they can be mixed in a single Cluster, but from a management perspective it is recommended to use only one API per Ingress Gateway.

### 1.5. Mesh Traffic Control

```yaml {caption="[File 7] HTTPRoute Example Attached to a Service", linenos=table}
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: server-mesh
  namespace: server-namespace
spec:
  parentRefs:
  - group: ""
    kind: Service
    name: server
  rules:
  - backendRefs:
    - name: server-v1
      port: 8080
      weight: 90
    - name: server-v2
      port: 8080
      weight: 10
```

Through **GAMMA** (Gateway API for Mesh Management and Administration), the Gateway API can be used not only for controlling North-South Traffic coming from outside the Cluster but also for controlling East-West Traffic inside the Mesh. [File 7] shows an example of an HTTPRoute that specifies a Service instead of a Gateway in `parentRefs`, distributing the Traffic sent to the `server` Service inside the Mesh to the `server-v1` and `server-v2` Services. In Sidecar Mode, the Routing rules are applied in the Sidecar of the Client sending the request, which performs the same role as applying a VirtualService to the mesh Gateway.

```shell {caption="[Shell 7] Checking Mesh Traffic Distribution"}
# Before applying the mesh httproute
$ kubectl -n server-namespace exec client -c curl -- sh -c 'for i in $(seq 1 100); do curl -s http://server:8080/; done' | sort | uniq -c
  55 server-v1
  45 server-v2

# After applying the mesh httproute
$ kubectl -n server-namespace exec client -c curl -- sh -c 'for i in $(seq 1 100); do curl -s http://server:8080/; done' | sort | uniq -c
  90 server-v1
  10 server-v2
```

[Shell 7] shows the results of sending 100 requests from the `client` Pod to the `server` Service before and after applying the HTTPRoute of [File 7]. Before applying, since there are no Routing rules, the requests are distributed at roughly a 50:50 ratio to the `server-v1` and `server-v2` Pods, which are the Endpoints of the `server` Service, but after applying, it can be confirmed that the requests are distributed at a 90:10 ratio to the `server-v1` and `server-v2` Services according to the `weight` setting of the HTTPRoute.

```shell {caption="[Shell 8] Checking the Route Configuration of the Client Sidecar"}
$ istioctl proxy-config routes client -n server-namespace --name 8080 -o json
...
            {
                "name": "server.server-namespace.svc.cluster.local:8080",
                "domains": [
                    "server.server-namespace.svc.cluster.local",
                    ...
                ],
                "routes": [
                    {
                        "name": "server-namespace.server-mesh.0",
                        ...
                        "route": {
                            "weightedClusters": {
                                "clusters": [
                                    {
                                        "name": "outbound|8080||server-v1.server-namespace.svc.cluster.local",
                                        "weight": 90
                                    },
                                    {
                                        "name": "outbound|8080||server-v2.server-namespace.svc.cluster.local",
                                        "weight": 10
                                    }
                                ]
                            },
                            ...
```

As shown in [Shell 8], it can be confirmed that the Routing rules are reflected in the Sidecar Route configuration of the `client` Pod that sends the requests, which shows that the rules for Mesh Traffic are applied not at the Gateway but at the Client's Sidecar.

### 1.6. Ambient Mode Waypoint

```yaml {caption="[File 8] Waypoint Gateway Example", linenos=table}
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: waypoint
  namespace: server-namespace
  labels:
    istio.io/waypoint-for: service
spec:
  gatewayClassName: istio-waypoint
  listeners:
  - name: mesh
    port: 15008
    protocol: HBONE
```

The **Waypoint**, which handles L7 Traffic in Ambient Mode, is also deployed based on the Gateway API. [File 8] shows the Waypoint Gateway created by istioctl's `istioctl waypoint apply` command. The `istio-waypoint` GatewayClass and a Listener with the HBONE Protocol are configured, and when the Gateway is created, istiod automatically deploys the Waypoint's Deployment and Service in the same way as a general Gateway. However, in the case of the Waypoint, the GatewayClass name is not appended to the names of the created Resources.

The deployed Waypoint is used by setting the `istio.io/use-waypoint` Label on Namespaces, Services, or Pods, and Traffic sent to Resources with the Label set passes through the Waypoint. L7 Routing rules can also be applied to Traffic passing through the Waypoint via an HTTPRoute attached to a Service like [File 7]. In this way, Ambient Mode is designed around the Gateway API rather than the Istio API.

## 2. References

* Istio Kubernetes Gateway API : [https://istio.io/latest/docs/tasks/traffic-management/ingress/gateway-api/](https://istio.io/latest/docs/tasks/traffic-management/ingress/gateway-api/)
* Istio Gateway Deployment : [https://istio.io/latest/docs/setup/additional-setup/gateway/](https://istio.io/latest/docs/setup/additional-setup/gateway/)
* Istio Waypoint : [https://istio.io/latest/docs/ambient/usage/waypoint/](https://istio.io/latest/docs/ambient/usage/waypoint/)
* Gateway API : [https://gateway-api.sigs.k8s.io/](https://gateway-api.sigs.k8s.io/)
* Gateway API GAMMA : [https://gateway-api.sigs.k8s.io/docs/mesh/mesh-overview/](https://gateway-api.sigs.k8s.io/docs/mesh/mesh-overview/)
* Istio Gateway API Conversion : [https://deepwiki.com/istio/istio/3.5.1-gateway-api-integration-and-conversion](https://deepwiki.com/istio/istio/3.5.1-gateway-api-integration-and-conversion)

---
title: Kubernetes Gateway API
---

This post analyzes the Gateway API, which emerged to overcome the limitations of Ingress in Kubernetes. The analyzed Gateway API Version is v1.6.

## 1. Kubernetes Gateway API

The **Gateway API** is a standard API that defines how Traffic from outside a Kubernetes Cluster is routed to Services inside the Cluster. The existing Ingress is designed around the HTTP/HTTPS Protocol and lacks features defined as a standard, so most Ingress Controllers extend their features through Annotations.

Since Annotations are defined differently for each Ingress Controller, there is a portability problem where the Ingress must also be modified when the Ingress Controller is changed. In addition, because Ingress defines both the Load Balancer configuration and the Routing rules in a single Resource, it is difficult to separate the roles of the Cluster administrator and the App developer. The Gateway API emerged to overcome these limitations of Ingress.

{{< figure caption="[Figure 1] Gateway API Resource Relationships" src="images/gateway-api-resource.png" width="1000px" >}}

[Figure 1] shows the main Resources of the Gateway API and the relationships between the roles that manage each Resource. The Gateway API is based on a **Role-oriented** design and provides Resources in three layers: GatewayClass, Gateway, and Route. GatewayClass is the Resource that defines the implementation of Gateways and is managed by the Infrastructure Provider. Gateway is the Resource that defines the Load Balancer (Proxy) that receives Traffic and is managed by the Cluster Operator. Routes, including HTTPRoute, are Resources that define the rules for routing received Traffic to Services and are managed by App developers.

The **Infrastructure Provider** is the role that provides the Gateway API implementation and the underlying environment it runs on, like a Cloud Provider. The **Cluster Operator** is the administrator responsible for operating the Kubernetes Cluster and managing Traffic policies, and the **App developer** is responsible for developing and deploying the Apps running in the Cluster. The Gateway Controller in [Figure 1] is drawn across the boundary between the Infrastructure Provider and Cluster Operator areas because the Infrastructure Provider is responsible for developing the Gateway Controller, while the Cluster Operator is responsible for installing and operating it in the Cluster.

Taking an AWS EKS environment as an example, AWS, which provides the Gateway Controller and Load Balancer, corresponds to the Infrastructure Provider; the Platform team, which creates Gateways and manages Domains and certificates, corresponds to the Cluster Operator; and each service's development team, which defines Routes to expose its own App, corresponds to the App developer.

Since the Gateway API separates Resources by role in this way, App developers can expose their Apps externally by defining only Routes in their own Namespace, without modifying the Gateway managed by the Cluster Operator. However, the roles do not necessarily have to be separated across different parties; in an On-Premise environment where an implementation such as Istio is installed and used directly, a single team can serve as both the Infrastructure Provider and the Cluster Operator.

In [Figure 1], the Cluster Operator operates two Gateways: an External Gateway exposed to the outside and an Internal Gateway exposed only to the internal network, and the App developer attaches an HTTPRoute and a TLSRoute to the External Gateway, and a GRPCRoute, TCPRoute, and UDPRoute to the Internal Gateway. When a Gateway referencing a GatewayClass is created, the Gateway Controller creates, for each Gateway, a Deployment of the Proxy that actually receives Traffic and a Service acting as the Load Balancer, and the Traffic sent by a Client passes through the Load Balancer and the Proxy and is delivered to the App's Service and Pods according to the rules of the Routes.

The Gateway API is not built into Kubernetes and is installed separately in the form of CRDs (Custom Resource Definitions). Also, the Gateway API only defines the API standard, and the actual behavior is handled by Gateway Controller implementations. Representative implementations include Istio, Envoy Gateway, NGINX Gateway Fabric, Cilium, and Kong, and Cloud Providers such as AWS/GCP/Azure also provide implementations that integrate with their own Load Balancers.

### 1.1. GatewayClass

```yaml {caption="[File 1] GatewayClass Example", linenos=table}
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: istio
spec:
  controllerName: istio.io/gateway-controller
```

**GatewayClass** is a Cluster-scoped Resource that defines the implementation of Gateways. [File 1] shows an example of a GatewayClass that uses the Istio implementation. `controllerName` specifies the name of the Gateway Controller that handles the GatewayClass, and that Gateway Controller is responsible for creating and managing the Gateways that reference the GatewayClass. GatewayClass is a concept similar to Kubernetes' StorageClass, and in general, installing an implementation also creates its GatewayClass. Since multiple GatewayClasses can exist in a single Kubernetes Cluster, multiple implementations can be used together in one Cluster.

### 1.2. Gateway

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

**Gateway** is the Resource that defines the Load Balancer that receives Traffic, and it corresponds to an instance of a GatewayClass. When a Gateway is created, the Gateway Controller creates the Proxy (Envoy, Nginx) that actually receives Traffic and a Service of `LoadBalancer` Type according to the contents of the Gateway.

[File 2] shows an example of a Gateway that receives HTTP, HTTPS, TLS, TCP, and UDP Traffic. `gatewayClassName` specifies the name of the GatewayClass responsible for creating and managing the Gateway, and `listeners` defines the entry points through which the Gateway receives Traffic. A single Gateway can define multiple Listeners, and each Listener can be configured with a Protocol, Port, and Hostname. The Protocol of a Listener can be set to `HTTP`, `HTTPS`, `TLS`, `TCP`, or `UDP`.

Like the `https` Listener in [File 2], if a Secret storing a certificate is specified in `certificateRefs` under `tls`, the Listener performs TLS Termination. On the other hand, like the `tls` Listener, if the TLS Mode is set to `Passthrough`, the Listener does not perform TLS Termination and forwards the Traffic as is.

`allowedRoutes` serves to restrict which Routes can be attached to a Listener. Since the `allowedRoutes` of the `http` Listener is set to `All`, Routes from all Namespaces can be attached, but since the `allowedRoutes` of the `https` Listener is set to `Selector`, only Routes in Namespaces with the `gateway-access: "true"` Label can be attached. The default value of `allowedRoutes` is `Same`, in which case only Routes in the same Namespace as the Gateway can be attached. In this way, the Cluster Operator can control the range of Listeners that App developers can use through `allowedRoutes`.

### 1.3. Route

{{< table caption="[Table 1] Route Types" >}}
| Route | Target Protocol | Routing Criteria | Standard Channel Promotion Version |
|---|---|---|---|
| HTTPRoute | HTTP, HTTPS | Hostname, Path, Header, Method, Query Parameter | v0.5 |
| GRPCRoute | gRPC | Hostname, Service, Method, Header | v1.1 |
| TLSRoute | TLS | SNI Hostname | v1.5 |
| TCPRoute | TCP | Listener Port | v1.6 |
| UDPRoute | UDP | Listener Port | v1.6 |
{{< /table >}}

**Route** is the Resource that defines the rules for routing the Traffic received by a Gateway to Services. A Route specifies the Gateway it attaches to through `parentRefs`, and if necessary, it can be attached only to a specific Listener of the Gateway through `sectionName`. [Table 1] shows the types of Routes provided by the Gateway API.

The Gateway API provides five Route Resources according to Protocol: HTTPRoute, GRPCRoute, TLSRoute, TCPRoute, and UDPRoute. Each Route was promoted to the Standard Channel at a different point in time, and as of Version v1.6, all Route Resources are available in the Standard Channel. However, actual availability is determined by whether the implementation supports them, so the support scope of the implementation in use must be checked.

#### 1.3.1. HTTPRoute

```yaml {caption="[File 3] HTTPRoute Example", linenos=table}
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
        value: /server
    filters:
    - type: RequestHeaderModifier
      requestHeaderModifier:
        add:
        - name: x-gateway
          value: gateway-api
    backendRefs:
    - name: server-v1
      port: 8080
      weight: 90
    - name: server-v2
      port: 8080
      weight: 10
```

**HTTPRoute** is the Resource that defines the rules for routing the HTTP Traffic received by a Gateway to Services. [File 3] shows an example of an HTTPRoute that routes Traffic received on the `server.ssup2.com` Hostname to the `server-v1` and `server-v2` Services. `parentRefs` specifies the Gateway the HTTPRoute attaches to, and `hostnames` specifies the Hostnames subject to Routing.

As in [File 3], if only the Gateway is specified in `parentRefs` without a `sectionName`, the HTTPRoute attaches to all Listeners with compatible Protocols. Therefore, the HTTPRoute in [File 3] routes not only the HTTP Traffic received by the `http` Listener in [File 2], but also the HTTPS Traffic on which the `https` Listener has performed TLS Termination. However, since the `allowedRoutes` of the `https` Listener is set to `Selector`, the `server-namespace` Namespace must have the `gateway-access: "true"` Label for the HTTPRoute to be attached to the `https` Listener.

The `hostnames` of an HTTPRoute are valid only when they overlap with the `hostname` of the attached Gateway Listener, and since `server.ssup2.com` in [File 3] is included in `*.ssup2.com` in [File 2], the HTTPRoute is attached to the Gateway normally. Multiple HTTPRoutes specifying the same Hostname can also be attached to a single Gateway, in which case the rules of all HTTPRoutes are **merged and act as a single Routing rule**.

When multiple HTTPRoute rules match the same Traffic, the rule that defines more specific conditions is applied first. Priority is determined in the order of exact Path match, longer PathPrefix, Method condition, more Header conditions, and more Query Parameter conditions. If the specificity of the conditions is the same, the rule of the HTTPRoute created earlier is applied first, and if the creation times are also the same, priority is determined by the alphabetical order of Namespace and name. Because the earlier-created HTTPRoute has priority, it is impossible for a later-created HTTPRoute to define the same conditions and hijack the Traffic of an existing HTTPRoute.

`rules` defines the Routing rules for Traffic. `matches` defines the conditions of the Traffic subject to Routing, and conditions based not only on Path but also on Header, Method, and Query Parameter can be defined. `filters` serves to manipulate Traffic during the Routing process, and Request/Response Header modification (`RequestHeaderModifier`, `ResponseHeaderModifier`), Redirect (`RequestRedirect`), URL rewriting (`URLRewrite`), and Traffic mirroring (`RequestMirror`) features are provided as standard. In Ingress, these features must be used through Annotations, but in the Gateway API, they are provided as standard APIs and can be used identically regardless of the implementation.

`backendRefs` specifies the Services to which Traffic is delivered, and when multiple Services are specified, the Traffic ratio can be set through `weight`. In [File 3], you can see that 90% of the Traffic is set to be delivered to the `server-v1` Service and 10% to the `server-v2` Service. Therefore, unlike Ingress, the Gateway API can perform Canary deployments without separate implementation-specific extension features.

#### 1.3.2. GRPCRoute

```yaml {caption="[File 4] GRPCRoute Example", linenos=table}
apiVersion: gateway.networking.k8s.io/v1
kind: GRPCRoute
metadata:
  name: server
  namespace: server-namespace
spec:
  parentRefs:
  - name: gateway
    namespace: gateway-namespace
  hostnames:
  - "grpc.ssup2.com"
  rules:
  - matches:
    - method:
        service: server.ServerService
        method: Get
    backendRefs:
    - name: server-grpc
      port: 9090
```

**GRPCRoute** is the Resource that defines the rules for routing the gRPC Traffic received by a Gateway to Services. [File 4] shows an example of a GRPCRoute that routes gRPC Traffic received on the `grpc.ssup2.com` Hostname to the `server-grpc` Service. Since gRPC operates on top of HTTP/2, gRPC Traffic can also be routed through an HTTPRoute, but GRPCRoute can define Routing rules based on gRPC Service and Method, as in the `matches` of [File 4]. Like HTTPRoute, Header-based conditions and Header modification and Traffic mirroring `filters` can also be used.

#### 1.3.3. TLSRoute

```yaml {caption="[File 5] TLSRoute Example", linenos=table}
apiVersion: gateway.networking.k8s.io/v1
kind: TLSRoute
metadata:
  name: server
  namespace: server-namespace
spec:
  parentRefs:
  - name: gateway
    namespace: gateway-namespace
    sectionName: tls
  hostnames:
  - "server.ssup2.com"
  rules:
  - backendRefs:
    - name: server
      port: 8443
```

**TLSRoute** is the Resource that defines the rules for routing the TLS Traffic received by a Gateway based on **SNI** (Server Name Indication) without decrypting it. [File 5] shows an example of a TLSRoute that routes TLS Traffic whose SNI is `server.ssup2.com` to the `server` Service. To use a TLSRoute, the Protocol of the attached Gateway Listener must be set to `TLS` and the TLS Mode must be set to `Passthrough`. Since the Gateway only checks the SNI during the TLS Handshake process and forwards the Traffic without decrypting it, TLS Termination is performed by the Backend that receives the Traffic.

#### 1.3.4. TCPRoute

```yaml {caption="[File 6] TCPRoute Example", linenos=table}
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

**TCPRoute** is the Resource that defines the rules for routing the TCP Traffic received by a Gateway to Services. [File 6] shows an example of a TCPRoute that delivers the Traffic received by the Gateway's `tcp` Listener to the `database` Service. Since TCPRoute operates at L4, unlike HTTPRoute, only `backendRefs` can be defined without `matches` or `filters`, and the only criterion for distinguishing Traffic is the Port of the attached Listener. Therefore, TCPRoute is generally used by attaching to a specific Listener through `sectionName`, and it is used to expose non-HTTP-based Apps such as Databases outside the Cluster.

#### 1.3.5. UDPRoute

```yaml {caption="[File 7] UDPRoute Example", linenos=table}
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

**UDPRoute** is the Resource that defines the rules for routing the UDP Traffic received by a Gateway to Services. [File 7] shows an example of a UDPRoute that delivers the Traffic received by the Gateway's `udp` Listener to the `dns` Service. Like TCPRoute, UDPRoute also operates at L4, so it distinguishes Traffic only based on the Port of the attached Listener, and it is used to expose UDP-based Apps such as DNS, VoIP, and Game Servers outside the Cluster.

### 1.4. ReferenceGrant

```yaml {caption="[File 8] ReferenceGrant Example", linenos=table}
apiVersion: gateway.networking.k8s.io/v1
kind: ReferenceGrant
metadata:
  name: allow-server-route
  namespace: backend-namespace
spec:
  from:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    namespace: server-namespace
  to:
  - group: ""
    kind: Service
```

**ReferenceGrant** is the Resource that allows references between Resources in different Namespaces. In the Gateway API, when a Service in another Namespace is specified in a Route's `backendRefs`, the reference is rejected if a ReferenceGrant does not exist in the target Service's Namespace. This is to prevent the security problem where a Route in an arbitrary Namespace could reference a Service in another Namespace and hijack its Traffic.

[File 8] shows an example of a ReferenceGrant that allows an HTTPRoute in the `server-namespace` Namespace to reference Services in the `backend-namespace` Namespace. A ReferenceGrant must be created in the Namespace where the referenced Resource exists, and `from` specifies the Resources that perform the reference, while `to` specifies the Resources for which the reference is allowed.

### 1.5. Comparison with Ingress

{{< table caption="[Table 2] Comparison of Ingress and Gateway API" >}}
| Category | Ingress | Gateway API |
|---|---|---|
| Resource composition | Single Ingress Resource | GatewayClass, Gateway, Route |
| Role separation | Not possible | Separated into Infrastructure Provider, Cluster Operator, App developer |
| Supported Protocols | HTTP, HTTPS | HTTP, HTTPS, gRPC, TLS, TCP, UDP |
| Feature extension method | Implementation-specific Annotations | Standard Filters, Policies |
| Traffic ratio control | Not supported (requires implementation extension) | Supported via `weight` in `backendRefs` |
{{< /table >}}

[Table 2] shows the main differences between Ingress and the Gateway API. The Gateway API is establishing itself as the successor standard to Ingress, and the official Kubernetes documentation also recommends using the Gateway API for new environments. Ingress is in a **Frozen** state where no new features are added, and most Ingress Controller implementations also provide Gateway API support. In addition, the Gateway API is expanding its scope of use through **GAMMA** (Gateway API for Mesh Management and Administration) to control not only Traffic from outside the Cluster but also East-West Traffic in a Service Mesh.

## 2. References

* Gateway API : [https://gateway-api.sigs.k8s.io/](https://gateway-api.sigs.k8s.io/)
* Gateway API Concepts : [https://kubernetes.io/docs/concepts/services-networking/gateway/](https://kubernetes.io/docs/concepts/services-networking/gateway/)
* Gateway API v1.5 Release : [https://kubernetes.io/blog/2026/04/21/gateway-api-v1-5/](https://kubernetes.io/blog/2026/04/21/gateway-api-v1-5/)
* Gateway API v1.6 Release : [https://kubernetes.io/blog/2026/08/03/gateway-api-v1-6-release/](https://kubernetes.io/blog/2026/08/03/gateway-api-v1-6-release/)
* Gateway API Implementations : [https://gateway-api.sigs.k8s.io/implementations/](https://gateway-api.sigs.k8s.io/implementations/)

---
title: Kubernetes Gateway API GAMMA
---

This post analyzes GAMMA, which extends the Kubernetes Gateway API to control East-West Traffic in a Service Mesh. The analyzed Gateway API version is v1.6.

## 1. Kubernetes Gateway API GAMMA

{{< figure caption="[Figure 1] GAMMA Route and Service Connection Structure" src="images/gamma-route-service.png" width="900px" >}}

**GAMMA** (Gateway API for Mesh Management and Administration) is a standard that extends the Gateway API, originally designed for Traffic from outside the Cluster, so that it can also be used to control East-West Traffic inside a Service Mesh. Existing Service Meshes provide implementation-specific APIs, such as Istio's VirtualService and Linkerd's ServiceProfile, so a portability problem exists where Traffic control configuration must also be modified when the Mesh implementation is changed. GAMMA emerged to solve this problem, and Mesh support was promoted to the Standard Channel starting from Gateway API v1.1.

[Figure 1] shows the connection structure between a Route and a Service in GAMMA. GAMMA operates by specifying a Service instead of a Gateway in the `parentRefs` of an existing Route without adding a separate Resource, so Traffic inside the Mesh can be controlled with only a Route, without GatewayClass and Gateway Resources. The Mesh implementation watches the Routes attached to Services and applies Routing rules to the Data Plane; in Sidecar Mode the rules are applied at the Sidecar of the Client sending the request, and in Ambient Mode they are applied at the Waypoint.

The Routes available in a Mesh are HTTPRoute and GRPCRoute, and Mesh support for TCPRoute and TLSRoute is still experimental. Representative Mesh implementations supporting GAMMA include Istio, Linkerd, Kuma, and Cilium, and the Gateway API verifies whether an implementation complies with the GAMMA standard through a Mesh-specific Conformance Profile.

### 1.1. Service Frontend, Backend

GAMMA defines the roles of a Service by dividing them into **Frontend** and **Backend**. The Frontend refers to the target that Clients send requests to, such as the Service's name and ClusterIP, and the Backend refers to the set of Endpoint IPs selected by the Service's Selector. A Route operates on the Traffic delivered to the Service's Frontend, and the Backend to which the Traffic is actually delivered is determined through the Route's `backendRefs`. Therefore, the Client sends requests to the Service's DNS name as before, but the requests can be delivered to a different Version of the Service or to a different Service according to the Route's rules.

Note that a Service with an attached Route changes how requests are handled. Requests that match the Route's `matches` conditions are delivered to the Backends specified in `backendRefs`, but requests that do not match are rejected instead of being delivered to the Service's Backend. A Service without an attached Route operates the same as before.

### 1.2. Producer Route

```yaml {caption="[File 1] Producer Route Example", linenos=table}
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

A **Producer Route** is a Route created in the same Namespace as the target Service, and is used when the App developer who owns the Service defines how the Traffic delivered to their Service is handled. [File 1] shows an example of a Producer Route that distributes the Traffic delivered to the `version` Service across the `version-v1` and `version-v2` Services. The name of the target Service is specified in `parentRefs` along with `kind: Service`, and the rules of a Producer Route are applied to all requests inside the Mesh regardless of the Namespace of the Client sending the request. Therefore, a Producer Route is used when the Service owner defines rules to be applied identically to all Clients, such as a Canary deployment.

### 1.3. Consumer Route

```yaml {caption="[File 2] Consumer Route Example", linenos=table}
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

A **Consumer Route** is a Route created in a different Namespace from the target Service, and is used when a Client using the Service defines rules that apply only to its own requests. [File 2] shows an example of a Consumer Route that adds a Header to requests sent to the `version` Service by Clients in the `client-namespace` Namespace. The rules of a Consumer Route are applied only to requests sent by Clients in the same Namespace as the Route, and do not affect requests sent by Clients in other Namespaces.

When both a Producer Route and a Consumer Route match the same request, the Consumer Route takes precedence. However, since multiple Routes in the same Namespace are merged and operate together, different Consumer Routes cannot be defined per Client within a single Namespace. Also, since a Consumer Route specifies a Service in another Namespace in its `backendRefs`, a ReferenceGrant must exist in the target Namespace, and since Consumer Route support differs by Mesh implementation, the support scope of the implementation in use must be checked.

### 1.4. Gateway API Comparison

{{< table caption="[Table 1] Gateway API, GAMMA Comparison" >}}
| Category | Gateway API | GAMMA |
|---|---|---|
| Target Traffic | North-South Traffic entering from outside the Cluster | East-West Traffic inside the Mesh |
| Route's `parentRefs` Target | Gateway | Service |
| Required Resources | GatewayClass, Gateway, Route | Route |
| Rule Application Point | Gateway's Proxy | Client's Sidecar or Waypoint |
{{< /table >}}

[Table 1] shows the main differences between the Gateway API and GAMMA. Since GAMMA does not define a separate API and only changes the attachment target of a Route to a Service, the `matches`, `filters`, and `backendRefs` syntax of the Gateway API can be used identically for North-South Traffic and East-West Traffic. Therefore, App developers can define both external Cluster exposure and Mesh-internal Traffic control with a single API, and Routes can be used as-is even when the Mesh implementation is changed.

## 2. References

* Gateway API for Service Mesh : [https://gateway-api.sigs.k8s.io/docs/mesh/mesh-overview/](https://gateway-api.sigs.k8s.io/docs/mesh/mesh-overview/)
* GAMMA GEP-1426 : [https://gateway-api.sigs.k8s.io/geps/gep-1426/](https://gateway-api.sigs.k8s.io/geps/gep-1426/)
* Gateway API v1.1 Release : [https://kubernetes.io/blog/2024/05/09/gateway-api-v1-1/](https://kubernetes.io/blog/2024/05/09/gateway-api-v1-1/)
* Istio Mesh Traffic : [https://istio.io/latest/docs/tasks/traffic-management/ingress/gateway-api/#mesh-traffic](https://istio.io/latest/docs/tasks/traffic-management/ingress/gateway-api/#mesh-traffic)
* Cilium GAMMA Support : [https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gamma/](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gamma/)

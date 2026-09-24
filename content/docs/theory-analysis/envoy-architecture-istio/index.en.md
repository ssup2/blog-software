---
title: "Envoy Architecture with Istio"
---

## 1. Envoy as Sidecar Proxy with Istio

{{< figure caption="[Figure 1] Sidecar Proxy with Istio" src="images/envoy-istio-sidecar.png" width="700px" >}}

[Figure 1] shows the components inside the App Pod and the Traffic flows when Envoy operates as a Sidecar Proxy in an Istio environment. The App Pod contains the istio-proxy Container alongside the App Container, and two Processes, pilot-agent and Envoy, run inside the istio-proxy Container. Due to the iptables Rules configured by the istio-init Container at Pod startup, **all Traffic of the App Container passes through Envoy**. The Traffic flows can be classified into the following operations.

### 1.1. xDS

The xDS Server on Port `15012` of istiod delivers the LDS, RDS, CDS, EDS, SDS, NDS, and ECDS configurations to pilot-agent over **a single ADS Stream** (sky blue). Among the received configurations, pilot-agent **relays LDS, RDS, CDS, EDS, and ECDS to Envoy again over ADS** through the `unix:///etc/istio/proxy/XDS` Socket, and delivers the **Workload Certificate** over SDS through the `unix:///var/run/secrets/workload-spiffe-uds/socket` Socket. ECDS is used to deliver the Wasm Filter configuration defined by the WasmPlugin CR, and it allows the HTTP Filter configuration to be updated independently without refreshing the entire Listener.

The reason the Certificate is delivered through a separate SDS Socket is to **separate sensitive information** such as Private Keys from general configuration. In other words, Envoy does not communicate directly with istiod, and **pilot-agent acts as an xDS Proxy**. The reasons Envoy goes through pilot-agent as an xDS Proxy instead of communicating directly with istiod are as follows.

* **Authentication Delegation** : For Envoy to communicate with istiod over mTLS, a Certificate is required, but that Certificate must in turn be issued by istiod, creating a circular problem. pilot-agent solves this problem by generating a CSR (Certificate Signing Request) using the Pod's Service Account Token, receiving a Certificate issued by the istiod CA, and supplying it to Envoy through the SDS Socket. Since pilot-agent is also responsible for Certificate renewal, Envoy does not need to care about the Certificate lifecycle.
* **xDS Modification** : pilot-agent does not simply relay the xDS configuration delivered by istiod, but can modify it in the middle. For example, when istiod delivers an ECDS configuration saying "download the Wasm Filter module from a remote repository and use it", pilot-agent downloads the module on Envoy's behalf and rewrites the remote address in the configuration to a local file path before delivering it to Envoy. Since Envoy only needs to read the local file, all the complex work such as repository authentication and download failure handling is handled by pilot-agent.
* **istiod Failure Handling** : pilot-agent caches the last configuration received from istiod, so even during an istiod failure, it can respond with the cached configuration when Envoy reconnects. From Envoy's perspective, the xDS Server is always the local pilot-agent, so a Control Plane failure does not immediately propagate to the behavior of the Data Plane.

### 1.2. Outbound/Inbound Traffic

**Requests sent externally** by the App Container are redirected by iptables to Envoy's `15001` Port, and then delivered to the destination App Pod through Envoy's routing (orange). Conversely, **requests coming in from other App Pods** are redirected by iptables to Envoy's `15006` Port, and then delivered to the App Container's `8080` Port (yellow).

### 1.3. DNS Lookup

The DNS query path of the App Container differs depending on whether DNS Capture is enabled. **When DNS Capture is disabled**, the App Container's DNS queries pass through iptables and are delivered to CoreDNS as-is (light green). On the other hand, **when DNS Capture is enabled**, DNS queries are redirected by iptables to the DNS Proxy on pilot-agent's `15053` Port and handled there (green). The Hostname information used by the DNS Proxy is delivered from istiod through NDS, which is why NDS is consumed by pilot-agent instead of being relayed to Envoy.

### 1.4. Metrics Collection

There are two paths through which the Prometheus Server collects Metrics. One is the path that directly scrapes `/metrics` on the App Container's `8080` Port to **collect the App's Metrics** (blue), and the other is the path that scrapes `/stats/prometheus` on pilot-agent's `15020` Port to **collect Envoy's Metrics** (navy). pilot-agent fetches Envoy's Metrics from `/stats/prometheus` on Envoy's `15090` Port and serves them.

When merged collection is enabled, **the App's Metrics join the Envoy Metrics path**. pilot-agent also collects `/metrics` on the App Container's `8080` Port and serves the merged Metrics on Port `15020`, so the Prometheus Server can collect both Envoy's and the App's Metrics through the single navy path. Merged collection works only when Prometheus Scrape Annotations such as `prometheus.io/scrape`, `prometheus.io/port`, and `prometheus.io/path` are attached to the App Pod and Istio is configured with `enablePrometheusMerge: true`.

The reason merged collection is needed is that the Annotation-based approach can specify only one Port in the `prometheus.io/port` Annotation, so **only one Metrics Endpoint per Pod can be scraped**. In contrast, the PodMonitor/ServiceMonitor approach of the Prometheus Operator can specify multiple Metrics Ports for a single Pod, so merged collection is not needed.

### 1.5. Health Check

The Probes performed by kubelet are divided into two types depending on the target. The **Health Check of the istio-proxy Container** is performed by kubelet against `/healthz/ready` on Envoy's `15021` Port, and Envoy forwards this request to `/healthz/ready` on pilot-agent's `15020` Port (red).

On the other hand, the **Probe of the App Container** is not performed by kubelet directly against the App Container. During Sidecar injection, the Probe configuration is rewritten to `/app-health/app/livez`, `/app-health/app/readyz`, and `/app-health/app/startupz` on pilot-agent's `15020` Port, and pilot-agent forwards these requests to `/livez`, `/readyz`, and `/startupz` on the App Container's `8080` Port (purple). The `app` in the middle of the path represents the name of the Container targeted by the Probe. This is to prevent Probe requests from failing due to the mTLS policy while passing through Envoy because of the iptables Redirect.

### 1.6. Envoy Admin

istioctl accesses the Admin Interface on Envoy's `15000` Port to **check the configuration and state applied to Envoy** (black). The `istioctl proxy-config` command, which queries configurations such as Listeners, Routes, and Clusters through this path, is a representative example.

## 2. Envoy as Ingress Gateway with Istio

{{< figure caption="[Figure 2] Ingress Gateway with Istio" src="images/envoy-istio-ingress-gateway.png" width="700px" >}}

[Figure 2] shows the components inside the istio-ingressgateway Pod and the Traffic flows when Envoy operates as an Ingress Gateway in an Istio environment. istio-ingressgateway serves as the **entry point for Traffic** coming into the Mesh from outside.

The internal structure of the Pod is almost identical to the Sidecar in [Figure 1]. pilot-agent and Envoy run together inside the istio-proxy Container, the structure in which pilot-agent is responsible for the xDS Proxy role and Certificate supply remains the same, and kubelet's Envoy Probe and istioctl's Envoy Admin access paths are also maintained. There are two differences. First, since there is no App Container, **Envoy is the only Process that handles Traffic**, and it runs in `proxy router` mode. Second, since there is no App Traffic to intercept, **there is no istio-init Container and no iptables Redirect**. Traffic arrives directly at Envoy's Listener Port through the Kubernetes Service rather than through a Redirect. Also, since there is no App Container, Metrics collection has only one path, which collects only Envoy's Metrics via pilot-agent (navy).

**Inbound Traffic (yellow)** is the flow in which an external Client's request enters the Mesh. Since the istio-ingressgateway Service is exposed externally as a `LoadBalancer` Type, the request passes through the external Load Balancer, enters the Service's Port, and arrives at Envoy's Listener according to the `targetPort` mapping. Envoy forwards the request to the Cluster of the internal Mesh service according to the Routes of the VirtualService bound to the Gateway, and communicates with the Upstream Sidecar over mTLS. The roles of the Ports exposed by the istio-ingressgateway Service are as follows.

* **Ports `80`, `443`** : The default entrances for receiving HTTP/HTTPS requests. According to the `targetPort` mapping, they are delivered to Envoy's `8080` and `8443` Listeners respectively.
* **Port `15021` (`status-port`)** : Used by the external Load Balancer to check the Health of the Gateway (light green).
* **Port `31400`** : A general-purpose entrance for receiving raw TCP Traffic that is not HTTP.
* **Port `15443`** : A Passthrough entrance that routes based on SNI without terminating TLS, used for cross-cluster Traffic in Multi-cluster environments.

Except for the `status-port`, these Ports are merely pre-exposed on the Service; a Listener is opened in Envoy only when a Server is declared through a Gateway CR.

## 3. Envoy as Egress Gateway with Istio

{{< figure caption="[Figure 3] Egress Gateway with Istio" src="images/envoy-istio-egress-gateway.png" width="700px" >}}

[Figure 3] shows the components inside the istio-egressgateway Pod and the Traffic flows when Envoy operates as an Egress Gateway in an Istio environment. istio-egressgateway serves as the **controlled exit for Traffic** leaving the Mesh for the outside.

istio-egressgateway **completely shares its internal structure** with the istio-ingressgateway in [Figure 2]. The two Deployments use the same image and execution arguments, and the Envoy configuration in the default state (Listeners, Clusters, Secrets) is also identical. Only the Pod's Label differs as `istio: egressgateway`, so which Traffic it receives is determined by which Label the `selector` of the Gateway CR selects. What distinguishes the two is not Envoy but **placement and Traffic direction**.

The istio-egressgateway Service is a `ClusterIP` Type and can only be accessed from inside the Mesh. Since there is no external Load Balancer, it does not expose a `status-port`, and since it never receives Traffic coming in from outside, the `31400` and `15443` Ports do not exist either. Only two mappings remain on the Service: `80` → `8080` and `443` → `8443`.

**Outbound Traffic (orange)** is the flow in which a request sent externally by an App is first forwarded by the Sidecar to the Egress Gateway according to the VirtualService Routes, and the Egress Gateway receives it and sends it out to the external service. Since all Outbound Traffic passes through a single point, the Egress Gateway, securing a fixed exit IP, TLS Origination, and external access policy configuration can all be performed in one place.

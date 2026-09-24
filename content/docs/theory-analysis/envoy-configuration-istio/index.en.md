---
title: "Envoy Configuration with Istio"
---

This document summarizes how Envoy's configuration changes according to Kubernetes resources and Istio CRs (Custom Resources) in an Istio environment.

## 1. Envoy Configuration with Istio

{{< figure caption="[Figure 1] Test Environment" src="images/test-environment.png" width="600px" >}}

```yaml {caption="[Config 1] Test Environment Workload Manifest", linenos=table}
# kubectl label namespace default istio-injection=enabled
apiVersion: v1
kind: Pod
metadata:
  name: server-a
  namespace: default
  labels:
    app: server-a
spec:
  containers:
  - name: server-a
    image: ghcr.io/ssup2/mock-go-server:commit-f8ad4477
    ports:
    - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: server-a
  namespace: default
spec:
  selector:
    app: server-a
  ports:
  - name: http
    port: 8080
    targetPort: 8080
---
# server-b Pod/Service: same as server-a except for the name (8080 Port)
---
apiVersion: v1
kind: Pod
metadata:
  name: server-c
  namespace: default
  labels:
    app: server-c
spec:
  containers:
  - name: server-c
    image: ghcr.io/ssup2/mock-go-server:commit-f8ad4477
    ports:
    - containerPort: 9090
---
apiVersion: v1
kind: Service
metadata:
  name: server-c
  namespace: default
spec:
  selector:
    app: server-c
  ports:
  - name: grpc
    port: 9090
    targetPort: 9090
---
apiVersion: v1
kind: Pod
metadata:
  name: client
  namespace: default
  labels:
    app: client
spec:
  containers:
  - name: client
    image: nicolaka/netshoot
    command: ["sleep", "infinity"]
```

[Figure 1] shows the Workloads used for the Envoy Configuration Test, and [Config 1] shows the Workload Manifest that composes them. The test environment is a kind Cluster + Istio 1.24, and the istiod and istio-ingressgateway Pods are installed in the `istio-system` Namespace. Since the `istio-injection=enabled` Label is set on the `default` Namespace, every Pod runs with the istio-proxy Sidecar injected. The role of each Workload is as follows.

* **`server-a`, `server-b` Pod/Service** : Servers that receive requests, each exposing the `8080` Port. Two of them are deployed to examine the configuration when multiple Services expose the same Port.
* **`server-c` Pod/Service** : A server that receives requests, exposing the `9090` Port. It is deployed to examine the configuration when a Service exposes a different Port.
* **`client` Pod** : Acts as the Client that sends requests.

The Envoy Configuration Test using Istio CRs applies them only to the `server-a` Pod among the servers, and the changes are observed on the `server-a` Pod for CRs that modify the Inbound configuration (PeerAuthentication, AuthorizationPolicy, etc.) and on the `client` Pod for CRs that modify the Outbound configuration (VirtualService, DestinationRule, etc.).

### 1.1. Default Configuration

Even without any Istio CR applied, istiod builds the default configuration required for Mesh-wide communication using only Kubernetes Service and Endpoint information, and distributes it to every Sidecar. This section examines the default configuration by taking the Outbound configuration from the `client` Pod's Envoy Configuration and the Inbound configuration from the `server-a` Pod's Envoy Configuration.

#### 1.1.1. Outbound Configuration

{{< figure caption="[Figure 2] Default Outbound Configuration of the client Pod" src="images/envoy-outbound-configs.png" width="1100px" >}}

```yaml {caption="[Config 2] Default Outbound Configuration Dump of the client Pod", linenos=table}
# LDS: virtualOutbound - entry point for all outbound traffic (iptables redirect)
- '@type': type.googleapis.com/envoy.config.listener.v3.Listener
  address:
    socket_address:
      address: 0.0.0.0
      port_value: 15001
  filter_chains:
  - filter_chain_match:                # branch 2: original destination is 15001 itself -> block
      destination_port: 15001
    filters:
    - name: envoy.filters.network.tcp_proxy
      typed_config:
        '@type': type.googleapis.com/envoy.extensions.filters.network.tcp_proxy.v3.TcpProxy
        cluster: BlackHoleCluster
        stat_prefix: BlackHoleCluster
    name: virtualOutbound-blackhole
  - filters:                           # branch 3: no matching 0.0.0.0_<Port> Listener -> passthrough
    - name: envoy.filters.network.tcp_proxy
      typed_config:
        '@type': type.googleapis.com/envoy.extensions.filters.network.tcp_proxy.v3.TcpProxy
        cluster: PassthroughCluster
        stat_prefix: PassthroughCluster
    name: virtualOutbound-catchall-tcp
  name: virtualOutbound
  traffic_direction: OUTBOUND
  use_original_dst: true               # branch 1: hand off to the 0.0.0.0_<Port> Listener matching the original destination

# LDS: per-port outbound Listener (one per Service Port in the Mesh)
- '@type': type.googleapis.com/envoy.config.listener.v3.Listener
  address:
    socket_address:
      address: 0.0.0.0
      port_value: 8080
  default_filter_chain:                # fallback chain for non-HTTP traffic
    filters:
    - name: istio.stats                # TCP-level Istio standard metrics
      ...
    - name: envoy.filters.network.tcp_proxy
      typed_config:
        '@type': type.googleapis.com/envoy.extensions.filters.network.tcp_proxy.v3.TcpProxy
        cluster: PassthroughCluster
        ...
    name: PassthroughFilterChain
  filter_chains:
  - filter_chain_match:                # HTTP traffic detected by the Listener Filters
      application_protocols:
      - http/1.1
      - h2c
      transport_protocol: raw_buffer
    filters:
    - name: envoy.filters.network.http_connection_manager
      typed_config:
        '@type': type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
        http_filters:
        - name: istio.metadata_exchange        # exchange peer metadata via HTTP headers
          ...
        - name: envoy.filters.http.grpc_stats
          ...
        - name: istio.alpn                     # advertise Istio ALPN for upstream mTLS
          ...
        - name: envoy.filters.http.fault       # VirtualService fault injection
          ...
        - name: envoy.filters.http.cors        # VirtualService corsPolicy
          ...
        - name: istio.stats                    # Istio standard metrics
          ...
        - name: envoy.filters.http.router
          ...
        rds:
          config_source:
            ads: {}
          route_config_name: "8080"
        ...
  listener_filters:
  - name: envoy.filters.listener.tls_inspector
    ...
  - name: envoy.filters.listener.http_inspector
    ...
  name: 0.0.0.0_8080
  traffic_direction: OUTBOUND

# LDS: 0.0.0.0_9090 Listener for server-c's 9090 Port (same structure as 0.0.0.0_8080)
- '@type': type.googleapis.com/envoy.config.listener.v3.Listener
  address:
    socket_address:
      address: 0.0.0.0
      port_value: 9090
  filter_chains:
  - filters:
    - name: envoy.filters.network.http_connection_manager
      typed_config:
        '@type': type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
        rds:
          config_source:
            ads: {}
          route_config_name: "9090"
        ...
  name: 0.0.0.0_9090
  traffic_direction: OUTBOUND

# RDS: "8080" Route Table - one Virtual Host per Service + allow_any catch-all
# Virtual Host is selected by matching the request's Host header against domains
- route_config:
    ignore_port_in_host_matching: true     # strip ":<Port>" from the Host header before matching
    name: "8080"
    virtual_hosts:
    - domains:                             # all name variants + ClusterIP of the server-a Service
      - server-a.default.svc.cluster.local
      - server-a
      - server-a.default.svc
      - server-a.default
      - 10.96.202.153
      name: server-a.default.svc.cluster.local:8080
      routes:
      - match:
          prefix: /
        name: default
        route:
          cluster: outbound|8080||server-a.default.svc.cluster.local
    - domains:                             # all name variants + ClusterIP of the server-b Service
      - server-b.default.svc.cluster.local
      - server-b
      - server-b.default.svc
      - server-b.default
      - 10.96.118.1
      name: server-b.default.svc.cluster.local:8080
      routes:
      - match:
          prefix: /
        name: default
        route:
          cluster: outbound|8080||server-b.default.svc.cluster.local
    - domains:
      - '*'
      name: allow_any
      routes:
      - match:
          prefix: /
        name: allow_any
        route:
          cluster: PassthroughCluster

# RDS: "9090" Route Table - server-c Virtual Host + allow_any catch-all
- route_config:
    ignore_port_in_host_matching: true
    name: "9090"
    virtual_hosts:
    - domains:                             # all name variants + ClusterIP of the server-c Service
      - server-c.default.svc.cluster.local
      - server-c
      - server-c.default.svc
      - server-c.default
      - 10.96.77.59
      name: server-c.default.svc.cluster.local:9090
      routes:
      - match:
          prefix: /
        name: default
        route:
          cluster: outbound|9090||server-c.default.svc.cluster.local
    - domains:
      - '*'
      name: allow_any
      ...

# CDS: per-Service outbound Cluster (Endpoints via EDS)
- cluster:
    eds_cluster_config:
      eds_config:
        ads: {}
      service_name: outbound|8080||server-a.default.svc.cluster.local
    lb_policy: LEAST_REQUEST
    name: outbound|8080||server-a.default.svc.cluster.local
    transport_socket_matches:      # upstream mTLS when the endpoint has an Istio sidecar
    - match:
        tlsMode: istio
      name: tlsMode-istio
      transport_socket:
        name: envoy.transport_sockets.tls
        typed_config:
          '@type': type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.UpstreamTlsContext
          common_tls_context:
            alpn_protocols:        # default ALPN for sidecar mTLS (istio.alpn Filter overrides for HTTP)
            - istio-peer-exchange
            - istio
            ...
    ...
    type: EDS
- cluster:
    eds_cluster_config:
      eds_config:
        ads: {}
      service_name: outbound|8080||server-b.default.svc.cluster.local
    lb_policy: LEAST_REQUEST
    name: outbound|8080||server-b.default.svc.cluster.local
    ...
    type: EDS
- cluster:
    eds_cluster_config:
      eds_config:
        ads: {}
      service_name: outbound|9090||server-c.default.svc.cluster.local
    lb_policy: LEAST_REQUEST
    name: outbound|9090||server-c.default.svc.cluster.local
    ...
    type: EDS

# EDS: Endpoints of the server-a Cluster - the Pod IPs behind the Service
# server-b, server-c Clusters have their own ClusterLoadAssignment in the same shape
- endpoint_config:
    '@type': type.googleapis.com/envoy.config.endpoint.v3.ClusterLoadAssignment
    cluster_name: outbound|8080||server-a.default.svc.cluster.local
    endpoints:
    - lb_endpoints:
      - endpoint:
          address:
            socket_address:
              address: 10.244.2.4  # server-a Pod IP
              port_value: 8080
        health_status: HEALTHY
        load_balancing_weight: 1
        metadata:
          filter_metadata:
            envoy.transport_socket_match:
              tlsMode: istio       # endpoint has a sidecar -> mTLS transport socket is selected
            ...

# CDS: BlackHoleCluster - STATIC Cluster without Endpoints, blocks traffic
- cluster:
    alt_stat_name: BlackHoleCluster;
    connect_timeout: 10s
    name: BlackHoleCluster
    type: STATIC

# CDS: PassthroughCluster - forward to the original destination address
- cluster:
    lb_policy: CLUSTER_PROVIDED
    name: PassthroughCluster
    type: ORIGINAL_DST
    ...
```

[Figure 2] shows the Outbound part of the `client` Pod's Envoy Configuration, and [Config 2] shows the Dump that composes it. Every request sent by the App Container is redirected by iptables to the virtualOutbound Listener on Port `15001`. The role of each Listener in [Config 2] is as follows.

* **virtualOutbound Listener** : The entry point for all Outbound requests. It does not handle requests directly but branches into three paths. The default path hands the request off, according to the `use_original_dst` setting, to the `0.0.0.0_<Port>` Listener that matches the request's original destination Port. Requests whose original destination is Port `15001` itself are sent to BlackHoleCluster and blocked by the `virtualOutbound-blackhole` Network Filter Chain, and requests with no matching Listener are sent to PassthroughCluster by the `virtualOutbound-catchall-tcp` Network Filter Chain.
* **`0.0.0.0_8080`, `0.0.0.0_9090` Listener** : Per-Port Outbound Listeners. They are created based not on the Ports the Pod itself opens but on the **Ports of Services that exist in the Mesh**, because istiod cannot know in advance which Pod will send requests where, so it creates an Outbound Listener for every Service Port in the Mesh and distributes them to every Sidecar. These Listeners exist even on the `client` Pod, which opens no Port at all, because the `server-a` and `server-b` Services expose the `8080` Port and the `server-c` Service exposes the `9090` Port regardless of `client` itself. No matter how many Services expose the same Port, there is one Listener per Port. Requests are split into two Network Filter Chains according to the Protocol detected by the Listener Filters.
  * **HTTP connections** : Matched by `filter_chain_match` and handled by the HTTP Connection Manager. They are routed by referring to the Route Table of the same name (`"8080"`, `"9090"`) received via RDS.
  * **Non-HTTP connections** : Matching no Chain, they fall into the `default_filter_chain`. Only TCP-level Metrics are recorded by `istio.stats`, and `tcp_proxy` passes them through to the original destination via PassthroughCluster.

The Outbound Network Filter configurations are mostly identical across Chains, and what differs per Chain is mainly the part that specifies the destination. In the TCP-family Chains (the virtualOutbound Chains and the `default_filter_chain` of the per-Port Outbound Listeners), `istio.stats` is identical in every Chain down to its configuration, and `tcp_proxy` is also identical among the Chains that send to PassthroughCluster. Only the `tcp_proxy` of the `virtualOutbound-blackhole` Chain differs in its destination Cluster (BlackHoleCluster) and the presence of an Access Log. For the HTTP Connection Manager, only the `route_config_name` of `rds`, which specifies the Route Table to reference, and the `stat_prefix` differ per per-Port Outbound Listener, and the rest of the configuration, including the internal HTTP Filter composition, is all identical.

The configurations are identical because istiod replicates the same configuration into each Chain when distributing it, and it does not mean Envoy shares Filter instances. Filter instances are newly created per connection (per request for HTTP Filters) and share no state; only the Clusters and Stats that Filters reference by name are shared.

The per-Port Outbound Listener determines the Protocol of a connection with Listener Filters before selecting a Network Filter Chain. The virtualOutbound Listener only hands requests off to the per-Port Listeners, so it has no Listener Filters. The role of each Listener Filter in [Config 2] is as follows.

* **`tls_inspector`** : Inspects the first Bytes of the connection to determine whether it is TLS. The result is used as the `transport_protocol` value (`tls`, `raw_buffer`) in Network Filter Chain matching.
* **`http_inspector`** : Determines whether a Plaintext connection is HTTP and its version. The result is used as the `application_protocols` value (`http/1.1`, `h2c`, etc.) in Network Filter Chain matching.

The HTTP Connection Manager of the per-Port Outbound Listener contains the default HTTP Filters in the following order.

* **`istio.metadata_exchange`** : Both Sidecars exchange each other's Workload information by carrying their own Workload information (Workload name, Namespace, Labels, etc.) in the `x-envoy-peer-metadata` Header on requests and responses, and conversely reading and removing the Header carried by the peer Sidecar. Since all Envoy can know at the network level is the peer's IP:Port, the `istio.stats` Filter uses the Peer information exchanged this way to fill Metrics Labels such as `source_workload` and `destination_workload`.
* **`envoy.filters.http.grpc_stats`** : Generates gRPC statistics such as Message counts for gRPC requests.
* **`istio.alpn`** : When the Upstream is a Sidecar mTLS target, it changes the ALPN advertised in the mTLS Handshake to Istio-specific values. The Cluster's transport socket configuration contains `istio-peer-exchange` and `istio` as defaults, and for HTTP requests this Filter advertises `istio-http/1.0`, `istio-http/1.1`, or `istio-h2` instead, matching the Upstream's HTTP version. By advertising values with the `istio-` Prefix instead of the standard ALPN (`http/1.1`, `h2`), the receiving Sidecar can simultaneously recognize that it is an mTLS connection created by a Sidecar and the HTTP version inside the Tunnel.
* **`envoy.filters.http.fault`** : The place where the fault settings of a VirtualService are reflected.
* **`envoy.filters.http.cors`** : The place where the corsPolicy settings of a VirtualService are reflected.
* **`istio.stats`** : Generates the Istio standard Metrics.
* **`envoy.filters.http.router`** : The last Filter, which performs the actual routing by referring to the Route Table.

The Route Table referenced by the last router Filter is created one per Port with the same name as the per-Port Outbound Listener, and contains one Virtual Host for each Mesh Service that exposes that Port. The role of each Route Table in [Config 2] and of the components common to all Route Tables is as follows.

* **`"8080"` Route Table** : Since the two Services `server-a` and `server-b` both expose the `8080` Port, there are two Virtual Hosts. The `0.0.0.0_8080` Listener receives every request headed to the `8080` Port regardless of the destination Service, so it is not the Listener but the Route Table's Domain matching that distinguishes requests per Service. The `domains` of each Virtual Host lists all the name variants of the Service (`server-a`, `server-a.default`, `server-a.default.svc`, FQDN) and the Service's ClusterIP, so no matter what form the App uses to call, the request's Host Header matches that Service's Virtual Host. Each Virtual Host also contains one default Route named `default` created by istiod, and this Route routes requests to that Service's Cluster (`outbound|8080||server-a...`, `outbound|8080||server-b...`). In the end, requests entering through the same Listener are split into different Services at the Route Table.
* **`"9090"` Route Table** : Has only the single Virtual Host of the `server-c` Service, and routes to the `outbound|9090||server-c...` Cluster in the same way.
* **`allow_any` Virtual Host** : The Catch-all Virtual Host at the end of every Route Table, which forwards requests that match no Virtual Host to PassthroughCluster.
* **`ignore_port_in_host_matching` setting** : Set commonly on every Route Table; before Domain matching it strips the Port notation, such as `server-a:8080`, from the Host Header. Thanks to this, whether the App calls with or without the Port attached, it matches the same Virtual Host.

The role of each Cluster in [Config 2] is as follows.

* **`outbound|8080||server-a...`, `outbound|8080||server-b...`, `outbound|9090||server-c...` Cluster** : `EDS` Type Clusters created per Mesh Service Port with the name `outbound|<Port>||<Host>`, which receive their Endpoint list via EDS. They are the routing targets of the default Route (`name: default`) in each Route Table. Even `server-a` and `server-b`, which share the `0.0.0.0_8080` Listener and the `"8080"` Route Table, have separate Clusters, because unlike Listeners and Route Tables, Clusters are per Service rather than per Port. The Endpoints received via EDS are the IP:Port of the Pods belonging to the Service, as in the EDS excerpt of [Config 2], and istiod watches Kubernetes Endpoint information and pushes updates whenever Pods appear or disappear. The `tlsMode: istio` marker in the Endpoint metadata indicates that a Sidecar is injected into that Pod, and it matches the Cluster's `transport_socket_matches` so that the mTLS transport socket is selected for connections to this Endpoint.
* **BlackHoleCluster** : A `STATIC` Type Cluster with no Endpoints at all, so connection attempts fail immediately; it is used by the virtualOutbound Listener to block requests whose original destination is Port `15001` itself.
* **PassthroughCluster** : An `ORIGINAL_DST` Type Cluster that connects directly to the request's original destination IP:Port without separate Endpoints; it is the routing target of the virtualOutbound Listener's `virtualOutbound-catchall-tcp` Network Filter Chain and the `allow_any` Virtual Host of the Route Tables.

This Outbound configuration is not tied to a specific Pod, and every Sidecar in the Mesh receives it identically. The scope of the received configuration can be limited with the Sidecar CR.

#### 1.1.2. Inbound Configuration

{{< figure caption="[Figure 3] Default Inbound Configuration of the server-a Pod" src="images/envoy-inbound-configs.png" width="1100px" >}}

```yaml {caption="[Config 3] Default Inbound Configuration Dump of the server-a Pod", linenos=table}
# LDS: virtualInbound - entry point for all inbound traffic (iptables redirect)
- '@type': type.googleapis.com/envoy.config.listener.v3.Listener
  address:
    socket_address:
      address: 0.0.0.0
      port_value: 15006
  filter_chains:
  - filter_chain_match:                # block requests whose original destination is 15006 itself
      destination_port: 15006
    filters:
    - name: istio.metadata_exchange
      ...
    - name: istio.stats
      ...
    - name: envoy.filters.network.tcp_proxy
      typed_config:
        '@type': type.googleapis.com/envoy.extensions.filters.network.tcp_proxy.v3.TcpProxy
        cluster: BlackHoleCluster
        ...
    name: virtualInbound-blackhole
  # catch-all chains for ports not exposed by any Service
  # HTTP chains (mTLS/plaintext) use HCM, TCP chains use tcp_proxy - all to InboundPassthroughCluster
  - filter_chain_match:                # HTTP catch-all (sidecar mTLS)
      application_protocols:
      - istio-http/1.0
      - istio-http/1.1
      - istio-h2
      transport_protocol: tls
    filters:
    - name: istio.metadata_exchange
      ...
    - name: envoy.filters.network.http_connection_manager
      ...                              # route_config -> InboundPassthroughCluster
    name: virtualInbound-catchall-http
    transport_socket:                  # mTLS termination
      name: envoy.transport_sockets.tls
      ...
  - filter_chain_match:                # HTTP catch-all (plaintext)
      application_protocols:
      - http/1.1
      - h2c
      transport_protocol: raw_buffer
    filters:
      ...                              # same filters as the HTTP catch-all (sidecar mTLS) chain above
    name: virtualInbound-catchall-http
  - filter_chain_match:                # TCP catch-all (sidecar mTLS)
      application_protocols:
      - istio-peer-exchange
      - istio
      transport_protocol: tls
    filters:
    - name: istio.metadata_exchange
      ...
    - name: istio.stats
      ...
    - name: envoy.filters.network.tcp_proxy
      typed_config:
        '@type': type.googleapis.com/envoy.extensions.filters.network.tcp_proxy.v3.TcpProxy
        cluster: InboundPassthroughCluster
        ...
    name: virtualInbound
    transport_socket:                  # mTLS termination
      name: envoy.transport_sockets.tls
      ...
  - filter_chain_match:                # TCP catch-all (plaintext)
      transport_protocol: raw_buffer
    filters:
      ...                              # same filters as the TCP catch-all (sidecar mTLS) chain above
    name: virtualInbound
  - filter_chain_match:                # TCP catch-all (any other TLS, passed through still encrypted)
      transport_protocol: tls
    filters:
      ...                              # same filters as the TCP catch-all (sidecar mTLS) chain above
    name: virtualInbound
  - filter_chain_match:                # mTLS Chain
      application_protocols:
      - istio
      - istio-peer-exchange
      - istio-http/1.0
      - istio-http/1.1
      - istio-h2
      destination_port: 8080
      transport_protocol: tls
    filters:
    - name: istio.metadata_exchange            # network filter: exchange peer metadata (TCP)
      ...
    - name: envoy.filters.network.http_connection_manager
      typed_config:
        '@type': type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
        http_filters:
        - name: istio.metadata_exchange        # exchange peer metadata via HTTP headers
          ...
        - name: envoy.filters.http.grpc_stats
          ...
        - name: envoy.filters.http.fault
          ...
        - name: envoy.filters.http.cors
          ...
        - name: istio.stats                    # Istio standard metrics
          ...
        - name: envoy.filters.http.router
          ...
        route_config:                  # inline route config (no RDS)
          name: inbound|8080||
          virtual_hosts:
          - domains:
            - '*'
            name: inbound|http|8080
            routes:
            - match:
                prefix: /
              name: default
              route:
                cluster: inbound|8080||
        ...
    name: 0.0.0.0_8080
    transport_socket:
      name: envoy.transport_sockets.tls
      typed_config:
        ...
        require_client_certificate: true
  - filter_chain_match:                # Plaintext Chain - no transport_socket (no TLS termination)
      destination_port: 8080
      transport_protocol: raw_buffer
    filters:
    - name: istio.metadata_exchange
      ...
    - name: envoy.filters.network.http_connection_manager
      ...                              # same http_filters and route_config as the mTLS Chain
    name: 0.0.0.0_8080
  listener_filters:
  - name: envoy.filters.listener.original_dst
  - name: envoy.filters.listener.tls_inspector
    ...
  - name: envoy.filters.listener.http_inspector
    ...
  name: virtualInbound
  traffic_direction: INBOUND

# CDS: inbound Cluster - forward to the App Container
- cluster:
    lb_policy: CLUSTER_PROVIDED
    name: inbound|8080||
    type: ORIGINAL_DST
    upstream_bind_config:
      source_address:
        address: 127.0.0.6
        port_value: 0

# CDS: InboundPassthroughCluster - same shape, used by the catch-all chains
- cluster:
    lb_policy: CLUSTER_PROVIDED
    name: InboundPassthroughCluster
    type: ORIGINAL_DST
    upstream_bind_config:
      source_address:
        address: 127.0.0.6
        port_value: 0

# CDS: BlackHoleCluster - used by the virtualInbound-blackhole chain (shared with outbound)
- cluster:
    alt_stat_name: BlackHoleCluster;
    connect_timeout: 10s
    name: BlackHoleCluster
    type: STATIC
```

[Config 3] shows the Inbound configuration of the `server-a` Pod's Envoy Configuration. Requests coming in from other Pods are redirected by iptables to the virtualInbound Listener on Port `15006`. The virtualInbound Listener is the entry point for all Inbound requests, and it obtains information about the request with Listener Filters before selecting a Network Filter Chain. The role of each Listener Filter in [Config 3] is as follows.

* **`original_dst`** : Restores the original destination address (IP:Port) from before the iptables Redirect. The restored Port is used as the `destination_port` value in Network Filter Chain matching.
* **`tls_inspector`** : Inspects the first Bytes of the connection to determine whether it is TLS, and for TLS connections also reads the ALPN values advertised in the Handshake. The results are used for the `transport_protocol` value in Network Filter Chain matching and the `application_protocols` matching of the `tls` Chain.
* **`http_inspector`** : Determines whether a Plaintext connection is HTTP and its version.

The virtualInbound Listener has one blocking Chain, five Catch-all Chains, and a Chain pair matched by `destination_port` for each Port exposed by a Service. The role of each Network Filter Chain in [Config 3] is as follows.

* **`virtualInbound-blackhole` Chain** : Blocks requests whose original destination is Port `15006` itself by sending them to BlackHoleCluster. It plays the same role as the `virtualOutbound-blackhole` Network Filter Chain of the virtualOutbound Listener.
* **`virtualInbound-catchall-http` Chain** : The Fallback that handles HTTP requests arriving at Ports no Service exposes. Since they pass through the HTTP Connection Manager, HTTP-level Metrics and Access Logs are recorded, and then the Route forwards them to InboundPassthroughCluster.
  * **For Sidecar mTLS** : Selects mTLS connections created by Sidecars with the ALPN `istio-http/1.0`·`istio-http/1.1`·`istio-h2` Match, and performs TLS Termination.
  * **For Plaintext** : Selects Plaintext HTTP connections with the `http/1.1`·`h2c` Match.
* **`virtualInbound` Chain** : The final Fallback that handles all remaining connections not caught even by the HTTP Catch-all. `tcp_proxy` records only TCP-level information and forwards to InboundPassthroughCluster. The Plaintext and other-TLS Chains have only `transport_protocol` as their Match condition, so any connection is guaranteed to be caught, which is why virtualInbound has no `default_filter_chain`, unlike the per-Port Outbound Listener.
  * **For Sidecar mTLS** : Selects mTLS TCP connections created by Sidecars with the ALPN `istio-peer-exchange`·`istio` Match, and performs TLS Termination.
  * **For Plaintext** : Matches with only `transport_protocol: raw_buffer` and receives all remaining Plaintext connections.
  * **For other TLS** : Matches with only `transport_protocol: tls`, and passes TLS connections without Istio ALPN, such as TLS the App handles itself, through still encrypted without Termination.
* **`tls` Chain** : The Chain that handles Sidecar-to-Sidecar mTLS connections arriving at the `8080` Port, and together with the Plaintext Chain it bears the name `0.0.0.0_8080`. It selects mTLS connections created by the sending Sidecar with the `transport_protocol: tls` and `application_protocols` Match. The values listed in `application_protocols` are all Istio-specific ALPN values: `istio` is the basic marker indicating Sidecar mTLS, `istio-peer-exchange` is the marker indicating that metadata can be exchanged over TCP connections with the Network Filter version of `istio.metadata_exchange`, and `istio-http/1.0`·`istio-http/1.1`·`istio-h2` are values that combine the mTLS marker with the HTTP version inside the Tunnel. TLS connections the App handles itself advertise standard ALPN, so they do not match this Chain. Matched connections have the Client certificate verified according to the `require_client_certificate` setting, TLS is Terminated, and then the request is processed.
* **`raw_buffer` Chain** : The Chain that handles Plaintext connections. `PERMISSIVE`, Istio's default mTLS Mode, is a Mode that accepts both mTLS and Plaintext connections, meant to keep communication working with Clients that cannot use mTLS, such as Pods without a Sidecar. So in `PERMISSIVE` Mode a `tls` Chain for mTLS and a `raw_buffer` Chain for Plaintext exist as a pair per Port, and switching to `STRICT` Mode, which allows only mTLS connections, removes the `raw_buffer` Chain.

The Catch-all Chains exist because requests can also arrive at Ports not declared in any Service. A Service is not a firewall, so any Port the App has opened can be accessed directly via the Pod IP. Examples include Ports the App opened but did not declare in a Service, Metrics Ports that Prometheus scrapes directly via the Pod IP, and direct Pod communication through a Headless Service. Pod-to-Pod communication that was possible in Kubernetes must remain possible even after the Sidecar is injected, so istiod creates Catch-all Chains that pass such requests through to the App instead of blocking them. This is symmetrical to the Outbound side passing requests headed to destinations not registered in the Mesh through PassthroughCluster.

The virtualInbound Network Filter configurations are mostly identical across Chains, and what differs per Chain is mainly the part that specifies the destination. `istio.metadata_exchange` is identical in every Chain, and `istio.stats` is identical down to its configuration in every TCP-family Chain. `tcp_proxy` is identical among the TCP Catch-all Chains, and only the `virtualInbound-blackhole` Chain differs in its destination Cluster (BlackHoleCluster) and the presence of an Access Log.

The HTTP Connection Manager is also identical in every Chain that has one, except for the `route_config` that specifies the destination (InboundPassthroughCluster for the Catch-all Chains, `inbound|8080||` for the `0.0.0.0_8080` Chains) and the `stat_prefix`. Accordingly, the internal HTTP Filter composition is exactly the same in every Chain, and when an HTTP Filter is inserted due to an Istio CR, it is reflected identically in every Chain. [Config 3] shows only the one from the mTLS Chain. The Inbound Filter composition is also mostly the same as the Outbound one, with only the following two differences.

* **Additional `istio.metadata_exchange` Network Filter** : Present additionally at the front of the Chain, separate from the HTTP Filter version, it performs the same style of metadata exchange even on TCP connections where HTTP Headers cannot be used.
* **Absence of the `istio.alpn` HTTP Filter** : Inbound is not the side that sends requests to an Upstream, so there is no need to advertise ALPN.

The role of the Route and Clusters in [Config 3] is as follows.

* **`inbound|8080||` Route** : Unlike Outbound, it does not use RDS but is Inlined into the HTTP Connection Manager as `route_config`, with a simple structure that sends every request to the `inbound|8080||` Cluster. Since there is always only one Route, there is no need to update it dynamically.
* **`inbound|8080||` Cluster** : An `ORIGINAL_DST` Type that forwards to the request's original destination, the App Container's `8080` Port. It uses `127.0.0.6` as the Source address, which is a Loop-prevention mechanism so that iptables does not redirect Traffic originating from this address back to Outbound.
* **InboundPassthroughCluster** : The routing target of the Catch-all Chains. An `ORIGINAL_DST` Type Cluster with the same structure as the `inbound|8080||` Cluster, it forwards requests arriving at Ports not exposed by a Service to the App Container with the original destination Port intact.
* **BlackHoleCluster** : The routing target of the `virtualInbound-blackhole` Chain. Only one BlackHoleCluster exists in Envoy, and it is the same Cluster in [Config 2] that the Outbound `virtualOutbound-blackhole` Chain references.

### 1.2. Envoy Configuration with Kubernetes Resources

This section examines the changes made by adding or modifying **Kubernetes resources** such as Services and Pods. These changes are reflected in the Outbound configuration of every Sidecar in the Mesh, so they are observed on the `client` Pod. The Envoy resource types that each Kubernetes resource is reflected in are summarized as follows.

{{< table caption="[Table 1] Envoy Resource Types Affected by Kubernetes Resources" >}}
| Resource | Listener | Route | Cluster | Endpoint | Notes |
|---|:---:|:---:|:---:|:---:|---|
| Pod | - | - | - | O | Endpoint added/removed in the Cluster of the Service selecting it by Label |
| Service | O | O | O | O | Per-Port Listener/Route Table and per-Service Cluster created |
| Service Port Sharing | - | O | O | O | Only a Virtual Host in the Route Table and a Cluster added |
| TCP Service | O | O | - | - | Replaced by a TCP Listener bound to the ClusterIP when the Port Protocol is declared as TCP |
| Headless Service | - | O | O | - | ORIGINAL_DST Type Cluster created instead of EDS |
| ExternalName Service | - | - | - | - | No change (alias added to the target Virtual Host only when pointing to an in-mesh Host) |
| ServiceAccount | - | - | O | - | SAN list of the Cluster's mTLS validation updated |
| Node Topology | - | - | - | O | Node's Topology Labels reflected in the Endpoint's locality |
{{< /table >}}

#### 1.2.1. Pod

```yaml {caption="[Config 4] server-a-2 Pod Manifest", linenos=table}
# Second Pod with the same app=server-a Label as the existing server-a Pod
apiVersion: v1
kind: Pod
metadata:
  name: server-a-2
  namespace: default
  labels:
    app: server-a
spec:
  containers:
  - name: server-a-2
    image: ghcr.io/ssup2/mock-go-server:commit-f8ad4477
    ports:
    - containerPort: 8080
```

```diff {caption="[Diff 4] client Pod proxy-config before and after adding the server-a-2 Pod (EDS of the server-a Cluster)"}
 - endpoint_config:
     '@type': type.googleapis.com/envoy.config.endpoint.v3.ClusterLoadAssignment
     cluster_name: outbound|8080||server-a.default.svc.cluster.local
     endpoints:
     - lb_endpoints:
       - endpoint:
           address:
             socket_address:
               address: 10.244.2.6    # existing server-a Pod IP
               port_value: 8080
         health_status: HEALTHY
         load_balancing_weight: 1
         metadata:
           filter_metadata:
             envoy.transport_socket_match:
               tlsMode: istio
             istio:
               workload: server-a;default;server-a;;Kubernetes
+      - endpoint:
+          address:
+            socket_address:
+              address: 10.244.1.10   # added server-a-2 Pod IP
+              port_value: 8080
+        health_status: HEALTHY
+        load_balancing_weight: 1
+        metadata:
+          filter_metadata:
+            envoy.transport_socket_match:
+              tlsMode: istio
+            istio:
+              workload: server-a-2;default;server-a;;Kubernetes
-      load_balancing_weight: 1
+      load_balancing_weight: 2
       locality: {}
```

[Config 4] shows the Manifest of a second Pod with the same `app: server-a` Label as the existing server-a Pod. When applied, the new Pod IP is registered in the Endpoints of the `server-a` Service, and istiod detects this and, as shown in [Diff 4], **only adds one Endpoint** to the server-a Cluster's EDS while the Listeners, Route Tables, and Clusters do not change at all (measurement confirmed that the diff of the entire Config Dump excluding EDS is 0 lines). The `workload` marker of the Endpoint identifies which Pod it corresponds to, and the Locality-level `load_balancing_weight` also increases from `1` to `2` following the Endpoint count.

Everyday changes such as Replica scaling of a Deployment or Pod replacement during a Rolling Update are all handled by this EDS update alone. Since only the LB target list changes without recreating Listeners or Clusters, the most frequent change in the Mesh is absorbed by the cheapest configuration update.

#### 1.2.2. Service

```yaml {caption="[Config 5] server-d Pod/Service Manifest (7070 Port)", linenos=table}
apiVersion: v1
kind: Pod
metadata:
  name: server-d
  namespace: default
  labels:
    app: server-d
spec:
  containers:
  - name: server-d
    image: ghcr.io/ssup2/mock-go-server:commit-f8ad4477
    ports:
    - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: server-d
  namespace: default
spec:
  selector:
    app: server-d
  ports:
  - name: http
    port: 7070
    targetPort: 8080
```

```diff {caption="[Diff 5] client Pod proxy-config before and after creating the server-d Service (7070 Port)"}
 - '@type': type.googleapis.com/envoy.admin.v3.ClustersConfigDump
   dynamic_active_clusters:
   ...
+  - cluster:
+      '@type': type.googleapis.com/envoy.config.cluster.v3.Cluster
+      name: outbound|7070||server-d.default.svc.cluster.local
+      type: EDS
+      eds_cluster_config:
+        eds_config:
+          ads: {}
+        service_name: outbound|7070||server-d.default.svc.cluster.local
+      lb_policy: LEAST_REQUEST
+      transport_socket_matches:
+      - match:
+          tlsMode: istio
+        name: tlsMode-istio
+        ...
 - '@type': type.googleapis.com/envoy.admin.v3.ListenersConfigDump
   dynamic_listeners:
   ...
+  - active_state:
+      listener:
+        '@type': type.googleapis.com/envoy.config.listener.v3.Listener
+        address:
+          socket_address:
+            address: 0.0.0.0
+            port_value: 7070
+        default_filter_chain:              # fallback chain for non-HTTP traffic
+          filters:
+          - name: istio.stats
+            ...
+          - name: envoy.filters.network.tcp_proxy
+            typed_config:
+              '@type': type.googleapis.com/envoy.extensions.filters.network.tcp_proxy.v3.TcpProxy
+              cluster: PassthroughCluster
+              ...
+          name: PassthroughFilterChain
+        filter_chains:
+        - filter_chain_match:              # HTTP traffic detected by the Listener Filters
+            application_protocols:
+            - http/1.1
+            - h2c
+            transport_protocol: raw_buffer
+          filters:
+          - name: envoy.filters.network.http_connection_manager
+            typed_config:
+              '@type': type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
+              rds:
+                config_source:
+                  ads: {}
+                route_config_name: "7070"
+              ...
+        listener_filters:
+        - name: envoy.filters.listener.tls_inspector
+          ...
+        - name: envoy.filters.listener.http_inspector
+          ...
+        name: 0.0.0.0_7070
+        traffic_direction: OUTBOUND
+    name: 0.0.0.0_7070
 - '@type': type.googleapis.com/envoy.admin.v3.RoutesConfigDump
   dynamic_route_configs:
   ...
+  - route_config:
+      '@type': type.googleapis.com/envoy.config.route.v3.RouteConfiguration
+      ignore_port_in_host_matching: true
+      name: "7070"
+      virtual_hosts:
+      - domains:                           # all name variants + ClusterIP of the server-d Service
+        - server-d.default.svc.cluster.local
+        - server-d
+        - server-d.default.svc
+        - server-d.default
+        - 10.96.121.134
+        name: server-d.default.svc.cluster.local:7070
+        routes:
+        - match:
+            prefix: /
+          name: default
+          route:
+            cluster: outbound|7070||server-d.default.svc.cluster.local
+            ...
+      - domains:
+        - '*'
+        name: allow_any
+        routes:
+        - match:
+            prefix: /
+          name: allow_any
+          route:
+            cluster: PassthroughCluster
+            ...
```

[Config 5] shows the Manifest of the `server-d` Service exposing the `7070` Port, which did not exist in the Mesh, along with its target Pod, and [Diff 5] shows the proxy-config change of the `client` Pod before and after applying it. Since a new Service Port has appeared in the Mesh, **a Cluster, a Listener, and a Route Table are created all at once**. The Cluster is created as an `EDS` Type with the per-Service name `outbound|7070||server-d...`, the Listener is created at the per-Port address `0.0.0.0_7070` with the same structure as the per-Port Outbound Listener in [Config 2], and the Route Table `"7070"` contains the server-d Virtual Host and the Catch-all `allow_any` Virtual Host.

```yaml {caption="[Config 6] EDS Endpoint Dump of the server-d Cluster", linenos=table}
# EDS: Endpoints of the server-d Cluster - Pod IP with targetPort
- endpoint_config:
    '@type': type.googleapis.com/envoy.config.endpoint.v3.ClusterLoadAssignment
    cluster_name: outbound|7070||server-d.default.svc.cluster.local
    endpoints:
    - lb_endpoints:
      - endpoint:
          address:
            socket_address:
              address: 10.244.2.11  # server-d Pod IP
              port_value: 8080      # targetPort of the server-d Service
        health_status: HEALTHY
        load_balancing_weight: 1
        metadata:
          filter_metadata:
            envoy.transport_socket_match:
              tlsMode: istio
            ...
```

[Config 6] shows the Endpoint that the server-d Cluster received via EDS. While the Listener address, the Route Table name, and the Cluster name are all based on the Service's `port` value of `7070`, the Endpoint is the combination of the Pod IP and the `targetPort` value of `8080`. In other words, the translation from the Service's `port` to its `targetPort` happens at the **boundary between the Cluster and the Endpoint** in the Envoy configuration, and Envoy connects directly to the Pod IP and targetPort without the help of kube-proxy.

#### 1.2.3. Service Port Sharing

```yaml {caption="[Config 7] server-d Pod/Service Manifest (Sharing the 8080 Port)", linenos=table}
# server-d Pod: same as the Pod in [Config 5]
apiVersion: v1
kind: Service
metadata:
  name: server-d
  namespace: default
spec:
  selector:
    app: server-d
  ports:
  - name: http
    port: 8080
    targetPort: 8080
```

```diff {caption="[Diff 7] client Pod proxy-config before and after creating the server-d Service (8080 Port)"}
 - '@type': type.googleapis.com/envoy.admin.v3.ClustersConfigDump
   dynamic_active_clusters:
   ...
   - cluster:
       name: outbound|8080||server-b.default.svc.cluster.local
       ...
+  - cluster:
+      '@type': type.googleapis.com/envoy.config.cluster.v3.Cluster
+      name: outbound|8080||server-d.default.svc.cluster.local
+      type: EDS
+      eds_cluster_config:
+        eds_config:
+          ads: {}
+        service_name: outbound|8080||server-d.default.svc.cluster.local
+      lb_policy: LEAST_REQUEST
+      ...
 - '@type': type.googleapis.com/envoy.admin.v3.RoutesConfigDump
   dynamic_route_configs:
   - route_config:
       name: "8080"
       virtual_hosts:
       ...
       - domains:
         - server-b.default.svc.cluster.local
         ...
         name: server-b.default.svc.cluster.local:8080
         ...
+      - domains:                           # all name variants + ClusterIP of the server-d Service
+        - server-d.default.svc.cluster.local
+        - server-d
+        - server-d.default.svc
+        - server-d.default
+        - 10.96.190.121
+        name: server-d.default.svc.cluster.local:8080
+        routes:
+        - match:
+            prefix: /
+          name: default
+          route:
+            cluster: outbound|8080||server-d.default.svc.cluster.local
+            ...
       - domains:
         - '*'
         name: allow_any
```

When the same server-d Pod is registered this time with a Service exposing the same `8080` Port as the existing `server-a` and `server-b`, as in [Config 7] (the Pod Manifest is omitted since it is the same as [Config 5]), **the Listener does not change at all**, as shown in [Diff 7]. This is because the `0.0.0.0_8080` Listener already exists and there is one Listener per Port. What is added is only the server-d Cluster and the server-d Virtual Host in the `"8080"` Route Table, and the structure from 1.1.1 — where requests entering through the same Listener are split per Service by the Route Table's Domain matching — is confirmed by measurement.

#### 1.2.4. TCP Service

```yaml {caption="[Config 8] server-d Service Manifest (Port name tcp)", linenos=table}
# Applied on top of [Config 5] (same Service, only the port name changes)
apiVersion: v1
kind: Service
metadata:
  name: server-d
  namespace: default
spec:
  selector:
    app: server-d
  ports:
  - name: tcp
    port: 7070
    targetPort: 8080
```

```diff {caption="[Diff 8] client Pod proxy-config before and after changing the server-d Service Port name from http to tcp"}
 - '@type': type.googleapis.com/envoy.admin.v3.ListenersConfigDump
   dynamic_listeners:
   ...
   - active_state:
       listener:
         '@type': type.googleapis.com/envoy.config.listener.v3.Listener
         address:
           socket_address:
-            address: 0.0.0.0
+            address: 10.96.121.134
             port_value: 7070
-        default_filter_chain:            # fallback chain for non-HTTP traffic
-          filters:
-          ...
-          name: PassthroughFilterChain
         filter_chains:
-        - filter_chain_match:            # HTTP traffic detected by the Listener Filters
-            application_protocols:
-            - http/1.1
-            - h2c
-            transport_protocol: raw_buffer
-          filters:
-          - name: envoy.filters.network.http_connection_manager
-            typed_config:
-              '@type': type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
-              rds:
-                config_source:
-                  ads: {}
-                route_config_name: "7070"
-              ...
-        listener_filters:
-        - name: envoy.filters.listener.tls_inspector
-          ...
-        - name: envoy.filters.listener.http_inspector
-          ...
-        name: 0.0.0.0_7070
+        - filters:
+          - name: istio.stats
+            ...
+          - name: envoy.filters.network.tcp_proxy
+            typed_config:
+              '@type': type.googleapis.com/envoy.extensions.filters.network.tcp_proxy.v3.TcpProxy
+              cluster: outbound|7070||server-d.default.svc.cluster.local
+              ...
+        name: 10.96.121.134_7070
         traffic_direction: OUTBOUND
-    name: 0.0.0.0_7070
+    name: 10.96.121.134_7070
 - '@type': type.googleapis.com/envoy.admin.v3.RoutesConfigDump
   dynamic_route_configs:
   ...
-  - route_config:
-      '@type': type.googleapis.com/envoy.config.route.v3.RouteConfiguration
-      name: "7070"
-      virtual_hosts:
-      - domains:
-        - server-d.default.svc.cluster.local
-        ...
-        name: server-d.default.svc.cluster.local:7070
-      - domains:
-        - '*'
-        name: allow_any
-        ...
```

Istio determines the Protocol of a Service Port from the `name` Prefix (`http`, `grpc`, `tcp`, etc.) or the `appProtocol` field, and the structure of the Listener it creates differs accordingly. When only the Port name of the Service in [Config 5] is changed from `http` to `tcp` as in [Config 8], the `0.0.0.0_7070` Listener is **replaced by the `10.96.121.134_7070` Listener bound to the ClusterIP**, as shown in [Diff 8]. This is because TCP Traffic has no Host Header, so the destination Service cannot be distinguished by the Route Table, and the Traffic must be distinguished by the destination IP itself.

The inside of the Listener also becomes simpler. Instead of the HTTP Connection Manager, tcp_proxy connects directly to the server-d Cluster, the Route Table `"7070"` is removed entirely since nothing references it anymore, and the Listener Filters disappear since there is no need to detect the Protocol. On the other hand, the Cluster and its EDS Endpoints do not change, because the Protocol declaration only affects how a request is delivered to the Cluster and has nothing to do with the per-Cluster Endpoint management.

#### 1.2.5. Headless Service

```yaml {caption="[Config 9] server-d Headless Service Manifest", linenos=table}
# server-d Pod: same as the Pod in [Config 4]
apiVersion: v1
kind: Service
metadata:
  name: server-d
  namespace: default
spec:
  clusterIP: None
  selector:
    app: server-d
  ports:
  - name: http
    port: 8080
    targetPort: 8080
```

```diff {caption="[Diff 9] client Pod proxy-config before and after creating the server-d Headless Service"}
 - '@type': type.googleapis.com/envoy.admin.v3.ClustersConfigDump
   dynamic_active_clusters:
   ...
+  - cluster:
+      '@type': type.googleapis.com/envoy.config.cluster.v3.Cluster
+      name: outbound|8080||server-d.default.svc.cluster.local
+      type: ORIGINAL_DST
+      lb_policy: CLUSTER_PROVIDED
+      transport_socket:                  # fixed mTLS transport socket (no per-endpoint tlsMode match)
+        name: envoy.transport_sockets.tls
+        typed_config:
+          '@type': type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.UpstreamTlsContext
+          ...
+          sni: outbound_.8080_._.server-d.default.svc.cluster.local
+      ...
 - '@type': type.googleapis.com/envoy.admin.v3.RoutesConfigDump
   dynamic_route_configs:
   - route_config:
       name: "8080"
       virtual_hosts:
       ...
+      - domains:                         # name variants + Pod DNS wildcards (no ClusterIP)
+        - server-d.default.svc.cluster.local
+        - server-d
+        - server-d.default.svc
+        - server-d.default
+        - '*.server-d.default.svc.cluster.local'
+        - '*.server-d'
+        - '*.server-d.default.svc'
+        - '*.server-d.default'
+        name: server-d.default.svc.cluster.local:8080
+        routes:
+        - match:
+            prefix: /
+          name: default
+          route:
+            cluster: outbound|8080||server-d.default.svc.cluster.local
+            ...
       - domains:
         - '*'
         name: allow_any
```

[Config 9] shows the Manifest of a Headless Service declared with `clusterIP: None` (the Pod Manifest is omitted since it is the same as [Config 5]). When applied, the Cluster is **created as an `ORIGINAL_DST` Type** rather than an `EDS` Type, as shown in [Diff 9]. A Headless Service has no ClusterIP and DNS queries return Pod IPs directly, so the LB decision is made not by Envoy but by the App that queried DNS. Therefore, instead of receiving an Endpoint list via EDS and performing LB, Envoy connects to the original destination Pod IP that the App has already chosen. The Upstream mTLS configuration is also set as a fixed `transport_socket` instead of `transport_socket_matches`, which matches against the Endpoint's `tlsMode` marker, because there is no EDS Endpoint metadata to select whether the target Pod has a Sidecar.

The Virtual Host's `domains` contains Wildcards of the form `*.server-d...` instead of a ClusterIP, meant to match calls using individual Pod DNS names of the form `<pod>.<service>`, as with a StatefulSet. Since a Service exposing the `8080` Port already exists, the Listener does not change, and the Virtual Host is also added to the existing `"8080"` Route Table.

#### 1.2.6. ExternalName Service

```yaml {caption="[Config 10] server-external ExternalName Service Manifest", linenos=table}
apiVersion: v1
kind: Service
metadata:
  name: server-external
  namespace: default
spec:
  type: ExternalName
  externalName: external.example.com
```

[Config 10] shows the Manifest of an `ExternalName` Type Service pointing to an external Host. In Kubernetes, an ExternalName Service is used as a DNS alias for calling an external Host by a Service name, but applying it makes **no change at all to the Envoy configuration** (measurement confirmed that the diff of the entire Config Dump is 0 lines). istiod does not create a separate Listener or Cluster for an ExternalName Service and treats it only as an alias of the target Host, and since `external.example.com` is not registered in the Mesh, there is no Virtual Host to reflect the alias into.

Accordingly, requests sent to `server-external` go through DNS CNAME resolution and are handled by the Catch-all path (PassthroughCluster), and to register an external Host in the Envoy configuration a ServiceEntry must be used. The alias treatment becomes visible only when `externalName` points to a Host registered in the Mesh, in which case measurement confirmed that the name variants of server-external are added to the `domains` of the target Host's Virtual Host.

#### 1.2.7. ServiceAccount

```yaml {caption="[Config 11] server-d-sa ServiceAccount and server-d-2 Pod Manifest", linenos=table}
# Applied on top of [Config 5] (adds a second server-d Pod with a dedicated ServiceAccount)
apiVersion: v1
kind: ServiceAccount
metadata:
  name: server-d-sa
  namespace: default
---
apiVersion: v1
kind: Pod
metadata:
  name: server-d-2
  namespace: default
  labels:
    app: server-d
spec:
  serviceAccountName: server-d-sa
  containers:
  - name: server-d-2
    image: ghcr.io/ssup2/mock-go-server:commit-f8ad4477
    ports:
    - containerPort: 8080
```

```diff {caption="[Diff 11] client Pod proxy-config before and after adding the Pod with the server-d-sa ServiceAccount"}
 - '@type': type.googleapis.com/envoy.admin.v3.ClustersConfigDump
   dynamic_active_clusters:
   ...
   - cluster:
       name: outbound|7070||server-d.default.svc.cluster.local
       transport_socket_matches:
       - match:
           tlsMode: istio
         name: tlsMode-istio
         transport_socket:
           name: envoy.transport_sockets.tls
           typed_config:
             '@type': type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.UpstreamTlsContext
             common_tls_context:
               combined_validation_context:
                 default_validation_context:
                   match_subject_alt_names:
                   - exact: spiffe://cluster.local/ns/default/sa/default
+                  - exact: spiffe://cluster.local/ns/default/sa/server-d-sa
                 ...
```

[Config 11] shows the Manifest that adds, on top of the [Config 5] state, a second server-d Pod using the dedicated ServiceAccount `server-d-sa`. When applied, the only change is that **one `match_subject_alt_names` entry is added** to the mTLS validation configuration of the server-d Cluster, as shown in [Diff 11]. In Istio, a Workload's Identity is derived from its ServiceAccount in the form `spiffe://<trust-domain>/ns/<namespace>/sa/<serviceaccount>`, and the sending Envoy verifies during the mTLS Handshake that the SAN of the peer certificate is included in this list.

So istiod maintains the set of ServiceAccounts used by a Service's Endpoints as the SAN list of that Cluster, and when a Pod using a new ServiceAccount is added to the Service, a CDS update occurs in addition to EDS. This contrasts with 1.2.1, where adding a Pod with the same ServiceAccount updated only EDS.

#### 1.2.8. Node Topology

```yaml {caption="[Config 12] Worker Node Topology Labels (Excerpt)", linenos=table}
apiVersion: v1
kind: Node
metadata:
  name: kind-worker
  labels:
    topology.kubernetes.io/region: region-a
    topology.kubernetes.io/zone: zone-a
    ...
---
apiVersion: v1
kind: Node
metadata:
  name: kind-worker2
  labels:
    topology.kubernetes.io/region: region-a
    topology.kubernetes.io/zone: zone-b
    ...
```

```diff {caption="[Diff 12] client Pod proxy-config before and after labeling the Nodes and recreating the server-a Pod (EDS of the server-a Cluster)"}
 - endpoint_config:
     '@type': type.googleapis.com/envoy.config.endpoint.v3.ClusterLoadAssignment
     cluster_name: outbound|8080||server-a.default.svc.cluster.local
     endpoints:
     - lb_endpoints:
       - endpoint:
           address:
             socket_address:
-              address: 10.244.2.13
+              address: 10.244.2.14   # server-a Pod recreated on the kind-worker Node
               port_value: 8080
         health_status: HEALTHY
         load_balancing_weight: 1
         ...
       load_balancing_weight: 1
-      locality: {}
+      locality:
+        region: region-a
+        zone: zone-a
```

[Config 12] shows the Topology Labels attached to the two Worker Nodes (the `region` is common while the `zone` differs per Node), and [Diff 12] shows the EDS change of the server-a Cluster when the server-a Pod is recreated after attaching the Labels. The previously empty `locality` of the Endpoint is filled with the Label values of the kind-worker Node where the Pod is located, because when istiod registers an Endpoint, it looks up the Node via the Pod's `nodeName` and reads its Topology Labels. The locality filled this way becomes the basis for Locality Load Balancing, which prefers Endpoints in the same Zone, and for Traffic distribution across Zones.

A point to note is that attaching Labels to a Node alone is **not retroactively reflected in already registered Endpoints** (measurement confirmed that the EDS diff after labeling is 0 lines). It is reflected only when the Pod is deleted and recreated so that the Endpoint is registered again, and the Pod IP in [Diff 12] has also changed because of the recreation. In Cloud environments, the Cloud Provider attaches the Topology Labels at Node creation time, so Endpoint localities are registered already filled from the beginning.

### 1.3. Envoy Configuration with Istio Custom Resources

This section examines the changes made by applying **Istio CRs** (Custom Resources) such as VirtualService and PeerAuthentication. CRs that modify the Outbound configuration are observed on the `client` Pod, and CRs that modify the Inbound configuration are observed on the `server-a` Pod. The Envoy resource types that each Istio CR is reflected in are summarized as follows.

{{< table caption="[Table 2] Envoy Resource Types Affected by Istio CRs" >}}
| CR | Listener | Route | Cluster | Endpoint | Notes |
|---|:---:|:---:|:---:|:---:|---|
| Gateway | O | O | - | - | Reflected in the Gateway Pod, not the Workload's Sidecar |
| VirtualService | - | O | - | - | Reflected in the Gateway Pod's Route when bound to a Gateway |
| DestinationRule | - | - | O | - | Additional Cluster created per Subset |
| ServiceEntry | - | O | O | - | Virtual Host and Cluster added for the external Host |
| Sidecar | O | O | O | - | Limits the received configuration scope rather than adding configuration |
| EnvoyFilter | O | - | - | - | Can Patch arbitrary locations depending on applyTo (example is an HTTP Filter) |
| WorkloadEntry | - | - | O | O | Combined with a ServiceEntry, its address is registered as an Endpoint |
| WorkloadGroup | - | - | - | - | No change by itself since it is a Template for WorkloadEntry |
| ProxyConfig | - | - | - | - | Bootstrap configuration, reflected when the Pod is recreated |
| PeerAuthentication | O | - | - | - | Changes the virtualInbound Network Filter Chains |
| RequestAuthentication | O | - | - | - | Adds the jwt_authn HTTP Filter |
| AuthorizationPolicy | O | - | - | - | Adds the rbac HTTP Filter |
| Telemetry | O | - | - | - | Replaces the Listener's Access Logger |
| WasmPlugin | O | - | - | - | Adds a Wasm HTTP Filter, configuration delivered via ECDS |
{{< /table >}}

#### 1.3.1. Gateway

```yaml {caption="[Config 13] istio-ingressgateway Service Port Mapping (Excerpt)", linenos=table}
apiVersion: v1
kind: Service
metadata:
  name: istio-ingressgateway
  namespace: istio-system
spec:
  type: LoadBalancer
  selector:
    app: istio-ingressgateway
    istio: ingressgateway
  ports:
  - name: http2
    port: 80          # Server Port declared in Gateway CR
    targetPort: 8080  # Port where Envoy Listener actually binds
  - name: https
    port: 443
    targetPort: 8443
  ...
```

```yaml {caption="[Config 14] Gateway Example", linenos=table}
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: server-a
  namespace: default
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "server-a.dev"
```

```diff {caption="[Diff 14] istio-ingressgateway Pod proxy-config before and after applying the Gateway"}
 - '@type': type.googleapis.com/envoy.admin.v3.ListenersConfigDump
+  dynamic_listeners:
+  - active_state:
+      listener:
+        '@type': type.googleapis.com/envoy.config.listener.v3.Listener
+        address:
+          socket_address:
+            address: 0.0.0.0
+            port_value: 8080
+        filter_chains:
+        - filters:
+          - name: envoy.filters.network.http_connection_manager
+            typed_config:
+              '@type': type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
+              rds:
+                config_source:
+                  ads: {}
+                route_config_name: http.8080
+              ...
+        name: 0.0.0.0_8080
+        traffic_direction: OUTBOUND
+    name: 0.0.0.0_8080
   static_listeners:
   ...
 - '@type': type.googleapis.com/envoy.admin.v3.RoutesConfigDump
+  dynamic_route_configs:
+  - route_config:
+      '@type': type.googleapis.com/envoy.config.route.v3.RouteConfiguration
+      name: http.8080
+      virtual_hosts:
+      - domains:
+        - '*'
+        name: blackhole:80
   static_route_configs:
```

A Gateway is **reflected in the Envoy of the Gateway Pod (istio-ingressgateway) selected by its selector**, not in a Sidecar. Although the Gateway CR declares the `80` Port, the Listener is created at `0.0.0.0_8080`, because istiod follows the Port mapping of the istio-ingressgateway Service (the `80` Port → `8080` targetPort in [Config 13]) and creates the Listener at the targetPort where the Traffic actually arrives. The Listener and Route names (`http.8080`) are based on the actual binding port, while the Virtual Host name (`blackhole:80`) is based on the Server Port declared in the Gateway CR. Since no VirtualService is bound to this Gateway yet, every request is handled as `404` by the `blackhole` Virtual Host.

#### 1.3.2. VirtualService

```yaml {caption="[Config 15] VirtualService Example", linenos=table}
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: server-a
  namespace: default
spec:
  hosts:
  - server-a
  http:
  - match:
    - uri:
        prefix: /api
    route:
    - destination:
        host: server-a
        port:
          number: 8080
    timeout: 3s
  - route:
    - destination:
        host: server-a
        port:
          number: 8080
```

```diff {caption="[Diff 15] client Pod proxy-config before and after applying the VirtualService"}
 - '@type': type.googleapis.com/envoy.admin.v3.RoutesConfigDump
   dynamic_route_configs:
   - route_config:
       '@type': type.googleapis.com/envoy.config.route.v3.RouteConfiguration
       name: "8080"
       virtual_hosts:
       - domains:
         - server-a.default.svc.cluster.local
         - server-a
         ...
         name: server-a.default.svc.cluster.local:8080
         routes:
+        - decorator:
+            operation: server-a.default.svc.cluster.local:8080/api*
+          match:
+            case_sensitive: true
+            prefix: /api
+          metadata:
+            filter_metadata:
+              istio:
+                config: /apis/networking.istio.io/v1/namespaces/default/virtual-service/server-a
+          route:
+            cluster: outbound|8080||server-a.default.svc.cluster.local
+            timeout: 3s
+            ...
         - decorator:
             operation: server-a.default.svc.cluster.local:8080/*
           match:
             prefix: /
-          name: default
+          metadata:
+            filter_metadata:
+              istio:
+                config: /apis/networking.istio.io/v1/namespaces/default/virtual-service/server-a
           route:
             cluster: outbound|8080||server-a.default.svc.cluster.local
       # server-b Virtual Host in the same "8080" Route Table is unchanged
       - domains:
         - server-b.default.svc.cluster.local
         ...
```

A VirtualService is **reflected in the Sidecar's Outbound Route (RDS)**. The Route Entries of the `server-a` Virtual Host, previously a single `/*`, grow into two — a `/api*` Match and a Catch-all — and `timeout: 3s` is reflected in the Route. The disappeared `name: default` is the name istiod attaches to the default Route it auto-generates when no VirtualService exists, and Routes derived from a VirtualService are created without a name unless `spec.http[].name` is specified. Instead, the path of the VirtualService that created the configuration is recorded in each Route Entry's `metadata.filter_metadata.istio.config`, making the origin of the configuration traceable. The `server-b` Virtual Host sharing the same `"8080"` Route Table does not change, nor do the Clusters or Listeners.

```yaml {caption="[Config 16] VirtualService with Gateway Example", linenos=table}
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: server-a-gateway
  namespace: default
spec:
  hosts:
  - server-a.dev
  gateways:
  - server-a
  http:
  - route:
    - destination:
        host: server-a
        port:
          number: 8080
```

```diff {caption="[Diff 16] istio-ingressgateway Pod proxy-config before and after binding the VirtualService to the Gateway"}
 - '@type': type.googleapis.com/envoy.admin.v3.RoutesConfigDump
   dynamic_route_configs:
   - route_config:
       '@type': type.googleapis.com/envoy.config.route.v3.RouteConfiguration
       name: http.8080
       virtual_hosts:
       - domains:
-        - '*'
-        name: blackhole:80
+        - server-a.dev
+        name: server-a.dev:80
+        routes:
+        - decorator:
+            operation: server-a.default.svc.cluster.local:8080/*
+          match:
+            prefix: /
+          metadata:
+            filter_metadata:
+              istio:
+                config: /apis/networking.istio.io/v1/namespaces/default/virtual-service/server-a-gateway
+          route:
+            cluster: outbound|8080||server-a.default.svc.cluster.local
+            ...
```

[Config 16] is an example of a VirtualService bound to the Gateway of [Config 14] via the `gateways` field. In this case it is **reflected in the Route of the Gateway Pod (istio-ingressgateway)**, not a Sidecar, and the `http.8080` Route Table, which in [Diff 14] contained only the `blackhole` Virtual Host, is replaced by the `server-a.dev` Virtual Host and starts routing to the `server-a` Cluster. Since the Gateway Pod, just like a Sidecar, receives the Cluster configuration of every service in the Mesh, the routing target `outbound|8080||server-a...` Cluster already exists.

#### 1.3.3. DestinationRule

```yaml {caption="[Config 17] DestinationRule Example", linenos=table}
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: server-a
  namespace: default
spec:
  host: server-a
  trafficPolicy:
    loadBalancer:
      simple: RANDOM
  subsets:
  - name: v1
    labels:
      version: v1
```

```diff {caption="[Diff 17] client Pod proxy-config before and after applying the DestinationRule"}
 - '@type': type.googleapis.com/envoy.admin.v3.ClustersConfigDump
   dynamic_active_clusters:
   ...
+  - cluster:
+      '@type': type.googleapis.com/envoy.config.cluster.v3.Cluster
+      name: outbound|8080|v1|server-a.default.svc.cluster.local
+      type: EDS
+      eds_cluster_config:
+        eds_config:
+          ads: {}
+        service_name: outbound|8080|v1|server-a.default.svc.cluster.local
+      lb_policy: RANDOM
+      metadata:
+        filter_metadata:
+          istio:
+            config: /apis/networking.istio.io/v1/namespaces/default/destination-rule/server-a
+            subset: v1
+      ...
   - cluster:
       '@type': type.googleapis.com/envoy.config.cluster.v3.Cluster
       name: outbound|8080||server-a.default.svc.cluster.local
-      lb_policy: LEAST_REQUEST
+      lb_policy: RANDOM
       metadata:
         filter_metadata:
           istio:
+            config: /apis/networking.istio.io/v1/namespaces/default/destination-rule/server-a
             services:
             - host: server-a.default.svc.cluster.local
```

A DestinationRule is **reflected in the Sidecar's Outbound Clusters (CDS)**. The `lb_policy` of the `server-a` Cluster specified by `host` changes from the default `LEAST_REQUEST` to `RANDOM`, and when Subsets are defined, a separate Cluster (`outbound|8080|v1|...`) is additionally created per Subset. The `server-b` and `server-c` Clusters and the Routes do not change, so to send Traffic to a Subset Cluster, the Subset must be specified in a VirtualService.

#### 1.3.4. ServiceEntry

```yaml {caption="[Config 18] ServiceEntry Example", linenos=table}
apiVersion: networking.istio.io/v1
kind: ServiceEntry
metadata:
  name: external-server
  namespace: default
spec:
  hosts:
  - external.example.com
  ports:
  - number: 80
    name: http
    protocol: HTTP
  resolution: DNS
  location: MESH_EXTERNAL
```

```diff {caption="[Diff 18] client Pod proxy-config before and after applying the ServiceEntry"}
 - '@type': type.googleapis.com/envoy.admin.v3.ClustersConfigDump
   dynamic_active_clusters:
   ...
+  - cluster:
+      '@type': type.googleapis.com/envoy.config.cluster.v3.Cluster
+      name: outbound|80||external.example.com
+      type: STRICT_DNS
+      dns_lookup_family: V4_ONLY
+      dns_refresh_rate: 60s
+      respect_dns_ttl: true
+      lb_policy: LEAST_REQUEST
+      load_assignment:
+        cluster_name: outbound|80||external.example.com
+        endpoints:
+        - lb_endpoints:
+          - endpoint:
+              address:
+                socket_address:
+                  address: external.example.com
+                  port_value: 80
+      metadata:
+        filter_metadata:
+          istio:
+            external: true
+      ...
   - cluster:
       '@type': type.googleapis.com/envoy.config.cluster.v3.Cluster
       name: outbound|80||istio-egressgateway.istio-system.svc.cluster.local
 - '@type': type.googleapis.com/envoy.admin.v3.RoutesConfigDump
   dynamic_route_configs:
   ...
   - route_config:
       '@type': type.googleapis.com/envoy.config.route.v3.RouteConfiguration
       name: "80"
       virtual_hosts:
+      - domains:
+        - external.example.com
+        name: external.example.com:80
+        routes:
+        - decorator:
+            operation: external.example.com:80/*
+          match:
+            prefix: /
+          name: default
+          route:
+            cluster: outbound|80||external.example.com
+            ...
       ...
       - domains:
         - '*'
         name: allow_any
         routes:
         - match:
             prefix: /
           name: allow_any
           route:
             cluster: PassthroughCluster
             ...
```

A ServiceEntry registers an external service in the Mesh's Service Registry, and is **reflected in the Sidecar's Outbound Clusters and Routes**. The `external.example.com` Cluster is created as a `STRICT_DNS` Type, and a Virtual Host for that Host is added to the `80` Port Route Table. Unlike Clusters of Kubernetes Services, which are `EDS` Type and receive their Endpoint list from istiod, a `STRICT_DNS` Type Cluster obtains its Endpoints by Envoy directly resolving DNS.

Before applying, requests headed to an external Host not registered in the Mesh matched the Catch-all `allow_any` Virtual Host and were forwarded to `PassthroughCluster`, but after applying, the dedicated Virtual Host added in front matches first and requests are handled through the dedicated Cluster. The `allow_any` Virtual Host itself does not change and remains as is.

#### 1.3.5. Sidecar

```yaml {caption="[Config 19] Sidecar Example", linenos=table}
apiVersion: networking.istio.io/v1
kind: Sidecar
metadata:
  name: client
  namespace: default
spec:
  workloadSelector:
    labels:
      app: client
  egress:
  - hosts:
    - "./server-a.default.svc.cluster.local"
```

```diff {caption="[Diff 19] client Pod proxy-config before and after applying the Sidecar"}
 - '@type': type.googleapis.com/envoy.admin.v3.ClustersConfigDump
   dynamic_active_clusters:
-  - cluster:
-      '@type': type.googleapis.com/envoy.config.cluster.v3.Cluster
-      name: outbound|15010||istiod.istio-system.svc.cluster.local
-      ...
-  - cluster:
-      name: outbound|443||kubernetes.default.svc.cluster.local
-      ...
-  - cluster:
-      name: outbound|53||kube-dns.kube-system.svc.cluster.local
-      ...
-  - cluster:
-      name: outbound|8080||server-b.default.svc.cluster.local
-      ...
-  - cluster:
-      name: outbound|9090||server-c.default.svc.cluster.local
-      ...
   - cluster:
       name: outbound|8080||server-a.default.svc.cluster.local
       ...
 - '@type': type.googleapis.com/envoy.admin.v3.ListenersConfigDump
   dynamic_listeners:
   ...
-  - active_state:
-      listener:
-        '@type': type.googleapis.com/envoy.config.listener.v3.Listener
-        ...
-        name: 0.0.0.0_9090
 - '@type': type.googleapis.com/envoy.admin.v3.RoutesConfigDump
   dynamic_route_configs:
   - route_config:
       name: "8080"
       virtual_hosts:
       - domains:
         - server-a.default.svc.cluster.local
         ...
-      - domains:
-        - server-b.default.svc.cluster.local
-        ...
-        name: server-b.default.svc.cluster.local:8080
       - domains:
         - '*'
         name: allow_any
```

The Sidecar CR does not add new configuration to Envoy but **limits the scope of the configuration the Sidecar receives**. By default every Sidecar receives the Clusters, Listeners, and Routes of every service in the Mesh, and limiting the egress hosts to `server-a` removes the Outbound configuration of every other service including `server-b` and `server-c`. The removal looks different depending on the unit of the configuration. Clusters are per Service, so every Cluster except `server-a` is removed; the `9090` Port, exposed only by `server-c`, has its Listener itself removed; and for `server-b`, which shared the Port with `server-a`, the `0.0.0.0_8080` Listener remains and only its Virtual Host in the `"8080"` Route Table is removed. Since this example limits only egress, the Inbound configuration (the virtualInbound Listener) does not change. It is the key means of reducing Sidecar Memory usage and xDS Push cost in large Clusters.

#### 1.3.6. EnvoyFilter

```yaml {caption="[Config 20] EnvoyFilter Example", linenos=table}
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: add-response-header
  namespace: default
spec:
  workloadSelector:
    labels:
      app: server-a
  configPatches:
  - applyTo: HTTP_FILTER
    match:
      context: SIDECAR_INBOUND
      listener:
        filterChain:
          filter:
            name: envoy.filters.network.http_connection_manager
            subFilter:
              name: envoy.filters.http.router
    patch:
      operation: INSERT_BEFORE
      value:
        name: envoy.filters.http.lua
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.http.lua.v3.Lua
          inlineCode: |
            function envoy_on_response(response_handle)
              response_handle:headers():add("x-added-by-envoyfilter", "true")
            end
```

```diff {caption="[Diff 20] server-a Pod proxy-config before and after applying the EnvoyFilter (virtualInbound Listener)"}
         name: virtualInbound
         filter_chains:
         ...
         - filter_chain_match:          # 0.0.0.0_8080 mTLS Chain - the same Filter is inserted into all 4 inbound HTTP Chains
             destination_port: 8080
             transport_protocol: tls
             ...
           filters:
           - name: envoy.filters.network.http_connection_manager
             typed_config:
               '@type': type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
               ...
               http_filters:
               ...
               - name: istio.stats
                 typed_config:
                   '@type': type.googleapis.com/stats.PluginConfig
                   disable_host_header_fallback: true
+              - name: envoy.filters.http.lua
+                typed_config:
+                  '@type': type.googleapis.com/envoy.extensions.filters.http.lua.v3.Lua
+                  inline_code: |
+                    function envoy_on_response(response_handle)
+                      response_handle:headers():add("x-added-by-envoyfilter", "true")
+                    end
               - name: envoy.filters.http.router
                 typed_config:
                   '@type': type.googleapis.com/envoy.extensions.filters.http.router.v3.Router
```

An EnvoyFilter is a CR that **directly Patches the Envoy configuration** generated by istiod, giving access to Envoy features that other CRs do not abstract. The example inserts a Lua Filter into the Inbound HTTP Filter Chain of the `server-a` Sidecar to add a response Header. `context: SIDECAR_INBOUND` limits the Patch target to the Sidecar's Inbound configuration; the Outbound configuration is specified with `SIDECAR_OUTBOUND` and the Gateway Pod with `GATEWAY`. `applyTo: HTTP_FILTER` means the `http_filters` array of the HTTP Connection Manager is the Patch target.

`operation: INSERT_BEFORE` is an operation that inserts the new Filter before the reference Filter specified by the match's `subFilter`. In [Diff 20] the Lua Filter can be seen added right before the reference Filter `envoy.filters.http.router`, and if `subFilter` is not specified, it is inserted at the front of the array. Since an EnvoyFilter depends directly on Envoy's internal implementation like this, it can break on Istio Upgrades and requires caution.

#### 1.3.7. WorkloadEntry

```yaml {caption="[Config 21] WorkloadEntry Example", linenos=table}
apiVersion: networking.istio.io/v1
kind: ServiceEntry
metadata:
  name: vm-server
  namespace: default
spec:
  hosts:
  - vm.example.com
  ports:
  - number: 8080
    name: http
    protocol: HTTP
  resolution: STATIC
  location: MESH_INTERNAL
  workloadSelector:
    labels:
      app: vm-server
---
apiVersion: networking.istio.io/v1
kind: WorkloadEntry
metadata:
  name: vm-server
  namespace: default
spec:
  address: 10.10.10.10
  labels:
    app: vm-server
```

```diff {caption="[Diff 21] client Pod proxy-config before and after applying the WorkloadEntry"}
 - '@type': type.googleapis.com/envoy.admin.v3.ClustersConfigDump
   dynamic_active_clusters:
   ...
+  - cluster:
+      '@type': type.googleapis.com/envoy.config.cluster.v3.Cluster
+      name: outbound|8080||vm.example.com
+      type: EDS
+      eds_cluster_config:
+        eds_config:
+          ads: {}
+        service_name: outbound|8080||vm.example.com
+      ...
 - '@type': type.googleapis.com/envoy.admin.v3.EndpointsConfigDump
   ...
+  - endpoint_config:
+      '@type': type.googleapis.com/envoy.config.endpoint.v3.ClusterLoadAssignment
+      cluster_name: outbound|8080||vm.example.com
+      endpoints:
+      - lb_endpoints:
+        - endpoint:
+            address:
+              socket_address:
+                address: 10.10.10.10
+                port_value: 8080
+          health_status: HEALTHY
+          load_balancing_weight: 1
```

A WorkloadEntry is a CR that **registers a Workload running outside the Kubernetes Cluster into the Mesh in the same way as a Pod**. The representative target is a Server Process running on a VM outside the Cluster. It has no effect on its own and must be used together with a ServiceEntry that selects it via workloadSelector. When the Labels match, the WorkloadEntry's address is registered as an Endpoint (EDS) of the corresponding Outbound Cluster, becoming an LB target in the same way as a Pod's Endpoint.

#### 1.3.8. WorkloadGroup

```yaml {caption="[Config 22] WorkloadGroup Example", linenos=table}
apiVersion: networking.istio.io/v1
kind: WorkloadGroup
metadata:
  name: vm-server
  namespace: default
spec:
  metadata:
    labels:
      app: vm-server
  template:
    serviceAccount: default
    network: vm-network
```

Applying a WorkloadGroup makes **no change to the Envoy configuration**. A WorkloadGroup is not a resource that registers a Workload into the Mesh by itself, but a Template for WorkloadEntries to be created later.

When istio-agent runs outside the Kubernetes Cluster, it connects to istiod's xDS Server, announcing the WorkloadGroup it belongs to along with its own address. istiod creates a WorkloadEntry object in the Kubernetes API Server by filling the received address into that WorkloadGroup's `template` (serviceAccount, network, etc.), and automatically deletes it if there is no reconnection within a grace period after the connection with istio-agent is lost. The WorkloadEntry created this way is reflected in the Cluster's Endpoints in the same way as the WorkloadEntry of the previous section, so the change in the Envoy configuration appears only at that point.

#### 1.3.9. ProxyConfig

```yaml {caption="[Config 23] ProxyConfig Example", linenos=table}
apiVersion: networking.istio.io/v1beta1
kind: ProxyConfig
metadata:
  name: client
  namespace: default
spec:
  selector:
    matchLabels:
      app: client
  concurrency: 4
```

A ProxyConfig also makes **no change to the running Envoy at the time of application**. Settings like `concurrency` are not delivered dynamically via xDS but belong to the Envoy Bootstrap Configuration. They are injected at Sidecar Injection time, so the Pod must be recreated for them to take effect.

#### 1.3.10. PeerAuthentication

```yaml {caption="[Config 24] PeerAuthentication Example", linenos=table}
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: server-a
  namespace: default
spec:
  selector:
    matchLabels:
      app: server-a
  mtls:
    mode: STRICT
```

```diff {caption="[Diff 24] server-a Pod proxy-config before and after applying the PeerAuthentication (virtualInbound Listener)"}
         name: virtualInbound
         filter_chains:
         ...
         - filter_chain_match:
-            application_protocols:
-            - istio
-            - istio-peer-exchange
-            - istio-http/1.0
-            - istio-http/1.1
-            - istio-h2
             destination_port: 8080
             transport_protocol: tls
           filters:
           ... (inbound|8080|| mTLS Chain)
-        - filter_chain_match:
-            destination_port: 8080
-            transport_protocol: raw_buffer
-          filters:
-          ... (the whole inbound|8080|| Plaintext Chain removed)
```

A PeerAuthentication is **reflected in the Network Filter Chains of the Inbound `virtualInbound` Listener of the Workload selected by its selector**. In the default `PERMISSIVE` Mode, a `tls` Chain for mTLS and a `raw_buffer` Chain for Plaintext exist together per Port, but changing to `STRICT` Mode removes all the `raw_buffer` Chains, making non-mTLS connections impossible to even establish.

The values `istio`, `istio-peer-exchange`, `istio-http/1.1`, and `istio-h2` listed in the `application_protocols` Match of the `tls` Chain are Istio-specific ALPN values that the sending Sidecar advertises during the mTLS Handshake to announce that the connection is an mTLS connection created by a Sidecar. In `PERMISSIVE` Mode, TLS connections handled by the App itself can also arrive at the same Port, so Envoy performs TLS Termination and decrypts only the Sidecar mTLS connections selected by this ALPN condition, and passes other TLS connections through to the App still encrypted.

In `STRICT` Mode, this Match condition also disappears, because the Plaintext Chain has been removed so there is nothing left to distinguish, and connections that are not Istio mTLS fail Client certificate verification anyway.

#### 1.3.11. RequestAuthentication

```yaml {caption="[Config 25] RequestAuthentication Example", linenos=table}
apiVersion: security.istio.io/v1
kind: RequestAuthentication
metadata:
  name: server-a
  namespace: default
spec:
  selector:
    matchLabels:
      app: server-a
  jwtRules:
  - issuer: "testing@secure.istio.io"
    jwksUri: "https://raw.githubusercontent.com/istio/istio/release-1.24/security/tools/jwt/samples/jwks.json"
```

```diff {caption="[Diff 25] server-a Pod proxy-config before and after applying the RequestAuthentication (virtualInbound Listener)"}
         name: virtualInbound
         filter_chains:
         ...
         - filter_chain_match:          # 0.0.0.0_8080 mTLS Chain - the same Filter is inserted into all 4 inbound HTTP Chains
             destination_port: 8080
             transport_protocol: tls
             ...
           filters:
           - name: envoy.filters.network.http_connection_manager
             typed_config:
               ...
               http_filters:
               - name: istio.metadata_exchange
                 ...
+              - name: envoy.filters.http.jwt_authn
+                typed_config:
+                  '@type': type.googleapis.com/envoy.extensions.filters.http.jwt_authn.v3.JwtAuthentication
+                  bypass_cors_preflight: true
+                  providers:
+                    origins-0:
+                      issuer: testing@secure.istio.io
+                      local_jwks:
+                        inline_string: '{ "keys":[ {"e":"AQAB","kid":"DHFbpoIU...","kty":"RSA","n":"..."} ] }'
+                      payload_in_metadata: payload
+                  rules:
+                  - match:
+                      prefix: /
+                    requires:
+                      requires_any:
+                        requirements:
+                        - provider_name: origins-0
+                        - allow_missing: {}
               - name: envoy.filters.http.grpc_stats
                 typed_config:
                   '@type': type.googleapis.com/envoy.extensions.filters.http.grpc_stats.v3.FilterConfig
```

A RequestAuthentication **adds the `jwt_authn` Filter to the Sidecar's Inbound HTTP Filter Chains**. Although the CR specifies a `jwksUri`, it is reflected as `local_jwks` in the Envoy configuration. This is because istiod fetches the JWKS (public key list) from the `jwksUri` on Envoy's behalf and distributes the key content via xDS, embedded directly as the `inline_string` value of the `jwt_authn` Filter configuration.

Thanks to this, each Envoy can verify JWTs immediately with the keys included in the configuration without accessing the external JWKS Endpoint directly, and key renewal is also handled by istiod periodically re-fetching and reflecting them via xDS Push. This Filter verifies the request's JWT, rejects it with 401 if invalid, and if valid makes the Claim information available to later Filters (such as the RBAC of an AuthorizationPolicy). Requests without a JWT pass through due to the `allow_missing` Rule, so blocking unauthenticated requests must be combined with an AuthorizationPolicy.

#### 1.3.12. AuthorizationPolicy

```yaml {caption="[Config 26] AuthorizationPolicy Example", linenos=table}
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: server-a
  namespace: default
spec:
  selector:
    matchLabels:
      app: server-a
  action: DENY
  rules:
  - to:
    - operation:
        paths: ["/admin"]
```

```diff {caption="[Diff 26] server-a Pod proxy-config before and after applying the AuthorizationPolicy (virtualInbound Listener)"}
         name: virtualInbound
         filter_chains:
         ...
         - filter_chain_match:          # 0.0.0.0_8080 mTLS Chain - the same Filter is inserted into all 4 inbound HTTP Chains
             destination_port: 8080
             transport_protocol: tls
             ...
           filters:
           - name: envoy.filters.network.http_connection_manager
             typed_config:
               ...
               http_filters:
               - name: istio.metadata_exchange
                 ...
+              - name: envoy.filters.http.rbac
+                typed_config:
+                  '@type': type.googleapis.com/envoy.extensions.filters.http.rbac.v3.RBAC
+                  rules:
+                    action: DENY
+                    policies:
+                      ns[default]-policy[server-a]-rule[0]:
+                        permissions:
+                        - and_rules:
+                            rules:
+                            - or_rules:
+                                rules:
+                                - url_path:
+                                    path:
+                                      exact: /admin
+                        principals:
+                        - and_ids:
+                            ids:
+                            - any: true
               - name: envoy.filters.http.grpc_stats
                 typed_config:
                   '@type': type.googleapis.com/envoy.extensions.filters.http.grpc_stats.v3.FilterConfig
```

An AuthorizationPolicy **adds the `rbac` Filter to the Sidecar's Inbound HTTP Filter Chains**. The example is a DENY policy that rejects requests to the `/admin` path, converted into RBAC Filter Rules, and matching requests are rejected with 403. Since the policy uses L7 attributes (path, Method, etc.), it is implemented as an HTTP Filter, and a separate Network Filter is used for TCP Ports.

#### 1.3.13. Telemetry

```yaml {caption="[Config 27] Telemetry Example", linenos=table}
apiVersion: telemetry.istio.io/v1
kind: Telemetry
metadata:
  name: server-a
  namespace: default
spec:
  selector:
    matchLabels:
      app: server-a
  accessLogging:
  - providers:
    - name: otel
```

```diff {caption="[Diff 27] server-a Pod proxy-config before and after applying the Telemetry (Access Logger of every Listener replaced)"}
         name: virtualInbound           # every Listener's Access Logger is replaced in the same way
         ...
           - name: envoy.filters.network.http_connection_manager
             typed_config:
               '@type': type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
               access_log:
-              - name: envoy.access_loggers.file
+              - name: envoy.access_loggers.open_telemetry
                 typed_config:
-                  '@type': type.googleapis.com/envoy.extensions.access_loggers.file.v3.FileAccessLog
-                  log_format:
-                    text_format_source:
-                      inline_string: |
-                        [%START_TIME%] "%REQ(:METHOD)% ... %ROUTE_NAME%
-                  path: /dev/stdout
+                  '@type': type.googleapis.com/envoy.extensions.access_loggers.open_telemetry.v3.OpenTelemetryAccessLogConfig
+                  body:
+                    string_value: |
+                      [%START_TIME%] "%REQ(:METHOD)% ... %ROUTE_NAME%
+                  common_config:
+                    grpc_service:
+                      envoy_grpc:
+                        authority: opentelemetry-collector.observability.svc.cluster.local
+                        cluster_name: outbound|4317||opentelemetry-collector.observability.svc.cluster.local
+                    log_name: otel_envoy_accesslog
+                    transport_api_version: V3
```

A Telemetry is **reflected in the Access Logger, Tracing, and Stats configuration of every Listener and HTTP Connection Manager, regardless of Inbound/Outbound**. The example environment has the global File Logger (`/dev/stdout`) enabled via meshConfig's `accessLogFile`, and when the `otel` Provider (an OpenTelemetry ALS defined in meshConfig's extensionProviders) is specified via Telemetry, every File Logger of the `server-a` Workload selected by the selector is replaced with the OpenTelemetry Logger. Note that the Service the Provider points to must exist in the Cluster for it to be reflected.

#### 1.3.14. WasmPlugin

```yaml {caption="[Config 28] WasmPlugin Example", linenos=table}
apiVersion: extensions.istio.io/v1alpha1
kind: WasmPlugin
metadata:
  name: basic-auth
  namespace: default
spec:
  selector:
    matchLabels:
      app: server-a
  url: oci://ghcr.io/istio-ecosystem/wasm-extensions/basic_auth:1.12.0
  phase: AUTHN
  pluginConfig:
    basic_auth_rules:
    - prefix: /api
      request_methods:
      - GET
      credentials:
      - admin:admin
```

```diff {caption="[Diff 28] server-a Pod proxy-config before and after applying the WasmPlugin (ECDS, virtualInbound Listener)"}
 - '@type': type.googleapis.com/envoy.admin.v3.EcdsConfigDump
+  ecds_filters:
+  - ecds_filter:
+      '@type': type.googleapis.com/envoy.config.core.v3.TypedExtensionConfig
+      name: extenstions.istio.io/wasmplugin/default.basic-auth
+      typed_config:
+        '@type': type.googleapis.com/envoy.extensions.filters.http.wasm.v3.Wasm
+        config:
+          configuration:
+            '@type': type.googleapis.com/google.protobuf.StringValue
+            value: '{"basic_auth_rules":[{"credentials":["admin:admin"],"prefix":"/api","request_methods":["GET"]}]}'
+          name: default.basic-auth
+          vm_config:
+            code:
+              local:
+                filename: /var/lib/istio/data/<hash>/<hash>.wasm
+            runtime: envoy.wasm.runtime.v8
 - '@type': type.googleapis.com/envoy.admin.v3.ListenersConfigDump
   ...
         name: virtualInbound
         filter_chains:
         ...
         - filter_chain_match:          # 0.0.0.0_8080 mTLS Chain - the same Filter is inserted into all 4 inbound HTTP Chains
             destination_port: 8080
             transport_protocol: tls
             ...
           filters:
           - name: envoy.filters.network.http_connection_manager
             typed_config:
               ...
               http_filters:
               - name: istio.metadata_exchange
                 ...
+              - config_discovery:
+                  config_source:
+                    ads: {}
+                  type_urls:
+                  - type.googleapis.com/envoy.extensions.filters.http.wasm.v3.Wasm
+                name: extenstions.istio.io/wasmplugin/default.basic-auth
               - name: envoy.filters.http.grpc_stats
                 typed_config:
                   '@type': type.googleapis.com/envoy.extensions.filters.http.grpc_stats.v3.FilterConfig
```

A WasmPlugin **adds a Wasm Filter to the Inbound HTTP Filter Chains**, and unlike other Filters, the Filter's actual configuration is delivered as a separate Resource via ECDS (Extension Config Discovery Service). The Wasm module is downloaded from the OCI Registry by pilot-agent on Envoy's behalf, converted to a local path, and delivered to Envoy.

`phase` is a field that specifies the insertion position within the HTTP Filter Chain as a stage. `AUTHN` inserts before the Istio authentication Filters, `AUTHZ` after the authentication Filters and before the authorization Filter (`rbac`), and `STATS` after the authorization Filter and before the Stats Filter (`istio.stats`); if unspecified, it is inserted at the end of the HTTP Filter Chain (before the Router Filter). Since the example uses `phase: AUTHN`, in [Diff 28] it was inserted right after `istio.metadata_exchange`, which is always at the front. Unlike the `subFilter` of an EnvoyFilter, it specifies the position by stage without depending on a specific Filter name, making it a safer extension mechanism across Istio Upgrades.

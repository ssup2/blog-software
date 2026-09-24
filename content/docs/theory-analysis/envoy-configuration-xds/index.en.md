---
title: "Envoy Configuration with xDS"
---

## 1. Envoy Configuration

Envoy Configuration consists of the combination of the **Bootstrap Configuration file**, which serves as the Root Configuration, and the xDS (eXtensible Discovery Services) Protocol, which is used to fetch configuration dynamically from the outside.

### 1.1. xDS (eXtensible Discovery Services) Protocol

{{< figure caption="[Figure 1] xDS (eXtensible Discovery Services) Resources and API" src="images/xds-resources-api.png" width="1100px" >}}

**xDS** (eXtensible Discovery Services) refers to the standard Protocol used to dynamically fetch the configuration Envoy needs to operate from the outside. [Figure 1] shows the Resources and APIs that make up xDS. The following kinds of xDS Resources exist.

* **Listener** : Defines the address and Port to receive Traffic on, and the Filter Chains (Protocol, TLS, etc.) to process it.
* **Route** : Defines the routing rules that decide which Cluster a request is sent to.
* **Cluster** : A logical group of an Upstream service, defining the connection method and LB policy.
* **Endpoint** : Defines the list of IP:Port of the actual instances belonging to a Cluster.
* **Secret** : Defines sensitive information such as TLS certificates and keys.
* **Extension Config** : Defines the actual configuration of an Extension (such as a Wasm Filter) that is referenced only by name in a Listener's Filter slot.

Each xDS Resource is configured dynamically through its corresponding xDS API. The kinds of xDS APIs are as follows.

* **LDS (Listener Discovery Service)** : Delivers Listener configuration dynamically.
* **RDS (Route Discovery Service)** : Delivers Route configuration dynamically.
* **CDS (Cluster Discovery Service)** : Delivers Cluster configuration dynamically.
* **EDS (Endpoint Discovery Service)** : Delivers Endpoint configuration dynamically.
* **SDS (Secret Discovery Service)** : Delivers Secret configuration dynamically.
* **ECDS (Extension Config Discovery Service)** : A dynamic configuration technique used generically for Envoy's various extension points, such as HTTP Filters and Listener Filters. Instead of embedding the whole extension configuration inside a Listener or Route, only a reference saying "fetch this configuration from ECDS" is left, and Envoy fetches just that extension's configuration separately when needed. Therefore, when you want to change the configuration of one extension, you can update only that configuration independently without receiving the whole Listener or Route again.
* **ADS (Aggregated Discovery Service)** : Not an API that delivers new configuration, but a transport technique that bundles LDS/RDS/CDS/EDS/SDS/ECDS into a single gRPC Stream instead of separate connections. This allows the Management Server to guarantee an application order that respects dependencies, such as CDS → EDS → LDS → RDS, and prevents Traffic loss that could occur during configuration updates.

#### 1.1.1. LDS (Listener Discovery Service)

```yaml {caption="[Config 1] LDS Configuration", linenos=table}
resources:

# ── Listener 1 · single chain · HTTP · mTLS terminate ─────────────────
- "@type": type.googleapis.com/envoy.config.listener.v3.Listener
  name: internal-listener                      # arbitrary string
  address:
    socket_address: { address: 0.0.0.0, port_value: 8080 }
  filter_chains:
  - transport_socket:
      name: envoy.transport_sockets.tls
      typed_config:
        "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.DownstreamTlsContext
        require_client_certificate: true       # mTLS: require client cert
        common_tls_context:
          tls_certificate_sds_secret_configs:
          - name: internal-cert                # SDS: the server cert I present
            sds_config: { ads: {} }
          validation_context_sds_secret_config:
            name: internal-ca                  # SDS: CA to verify the client cert
            sds_config: { ads: {} }
    filters:
    - name: envoy.filters.network.http_connection_manager
      typed_config:
        "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
        stat_prefix: ingress_http
        rds:
          route_config_name: internal-routes   # RDS: Route table to read (L7 only)
          config_source: { ads: {} }
        http_filters:
        - name: internal-wasm           # ECDS: config fetched separately BY NAME
          config_discovery:
            config_source: { ads: {} }
            type_urls:
            - type.googleapis.com/envoy.extensions.filters.http.wasm.v3.Wasm
        - name: envoy.filters.http.router      # terminal — executes the matched RDS entry
          typed_config:
            "@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router

# ── Listener 2 · two SNI chains · different SDS per chain ─────────────
- "@type": type.googleapis.com/envoy.config.listener.v3.Listener
  name: external-listener
  address:
    socket_address: { address: 0.0.0.0, port_value: 443 }
  listener_filters:
  - name: envoy.filters.listener.tls_inspector # reads SNI to pick a Filter Chain
    typed_config:
      "@type": type.googleapis.com/envoy.extensions.filters.listener.tls_inspector.v3.TlsInspector
  filter_chains:

  - filter_chain_match:
      server_names: ["web.com"]                # SNI → this chain
    transport_socket:
      name: envoy.transport_sockets.tls
      typed_config:
        "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.DownstreamTlsContext
        common_tls_context:
          tls_certificate_sds_secret_configs:
          - name: web-cert                     # SDS: cert whose SAN is web.com
            sds_config: { ads: {} }
    filters:
    - name: envoy.filters.network.http_connection_manager
      typed_config:
        "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
        stat_prefix: https_web
        rds:
          route_config_name: external-routes   # RDS: this chain's own Route table
          config_source: { ads: {} }
        http_filters:
        - name: envoy.filters.http.router
          typed_config:
            "@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router

  - filter_chain_match:
      server_names: ["kafka.com"]
    transport_socket:
      name: envoy.transport_sockets.tls
      typed_config:
        "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.DownstreamTlsContext
        common_tls_context:
          tls_certificate_sds_secret_configs:
          - name: kafka-cert                   # SDS: different cert per chain
            sds_config: { ads: {} }
    filters:
    - name: envoy.filters.network.tcp_proxy    # L4 — no RDS field
      typed_config:
        "@type": type.googleapis.com/envoy.extensions.filters.network.tcp_proxy.v3.TcpProxy
        stat_prefix: tcp_kafka
        cluster: kafka                         # straight to cluster, no Route table
```

[Config 1] shows an example LDS configuration corresponding to the Listener part of [Figure 1]. `internal-listener` receives Traffic with mTLS on the `8080` Port, proves itself with the `internal-cert` Secret, verifies the Client with the `internal-ca` Secret, and then hands requests to the `internal-routes` Route Table. In its HTTP Filter Chain, a Wasm Filter is present only as a `config_discovery` reference named `internal-wasm`, and the actual Filter configuration is delivered separately via ECDS. `external-listener` inspects the SNI with the TLS Inspector on the `443` Port to select a Filter Chain. The `web.com` Chain terminates TLS with the `web-cert` Secret and then hands requests to the `external-routes` Route Table, while the `kafka.com` Chain terminates TLS with the `kafka-cert` Secret and forwards directly to the `kafka` Cluster through the TCP Proxy without going through a Route Table.

#### 1.1.2. RDS (Route Discovery Service)

```yaml {caption="[Config 2] RDS Configuration", linenos=table}
resources:
 
# ── Table 1 · read by internal-listener (RDS: internal-routes) ────────
- "@type": type.googleapis.com/envoy.config.route.v3.RouteConfiguration
  name: internal-routes                        # arbitrary string
  virtual_hosts:
 
  - name: reviews-vhost                        # label only — not matched
    domains: ["reviews"]                       # matched against Host header
    routes:                                    # first match wins — order matters
    - match: { prefix: "/api" }                # specific entry before the catch-all
      route:
        weighted_clusters:                     # CDS: names of target Clusters
          clusters:
          - name: reviews-v1
            weight: 80
          - name: reviews-v2
            weight: 20
        timeout: 15s
    - match: { prefix: "/" }                   # catch-all for the rest
      route:
        cluster: reviews-v1                    # multiple routes may share a Cluster
 
  - name: ratings-vhost
    domains: ["ratings"]
    routes:
    - match: { prefix: "/" }
      route:
        cluster: ratings
 
# ── Table 2 · read only by the web.com chain (RDS: external-routes) ───
- "@type": type.googleapis.com/envoy.config.route.v3.RouteConfiguration
  name: external-routes
  virtual_hosts:
  - name: web-vhost
    domains: ["web.com"]                       # Host header after TLS termination
    routes:
    - match: { prefix: "/" }
      route:
        cluster: web
```

[Config 2] shows an example RDS configuration corresponding to the Route part of [Figure 1]. The `internal-routes` Route Table selects a Virtual Host based on the Host Header. Requests to the `/api` path of the `reviews` Host are distributed to the `reviews-v1` and `reviews-v2` Clusters with an 80:20 weight, and requests to all other paths are forwarded to the `reviews-v1` Cluster.

Here, the `routes` list inside a Virtual Host is evaluated in order from the top and operates in a **First Match Wins** manner where the first matching entry is applied. Therefore, specific entries like `/api` must be placed before the catch-all entry (`/`); if the order is reversed, every request matches the catch-all entry first and the `/api` entry is never selected. Requests to the `ratings` Host are all forwarded to the `ratings` Cluster. The `external-routes` Route Table forwards all requests to the `web.com` Host to the `web` Cluster.

#### 1.1.3. CDS (Cluster Discovery Service)

```yaml {caption="[Config 3] CDS Configuration", linenos=table}
resources:

- "@type": type.googleapis.com/envoy.config.cluster.v3.Cluster
  name: reviews-v1
  type: EDS
  eds_cluster_config:
    eds_config: { ads: {} }                    # EDS: endpoints arrive by this name
  connect_timeout: 1s
  transport_socket: &mtls-client               # YAML anchor — reused by the Clusters below
    name: envoy.transport_sockets.tls
    typed_config:
      "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.UpstreamTlsContext
      common_tls_context:
        tls_certificate_sds_secret_configs:
        - name: internal-cert                  # SDS: the client cert I present
          sds_config: { ads: {} }
        validation_context_sds_secret_config:
          name: internal-ca                    # SDS: CA to verify the server cert
          sds_config: { ads: {} }

- "@type": type.googleapis.com/envoy.config.cluster.v3.Cluster
  name: reviews-v2
  type: EDS
  eds_cluster_config: { eds_config: { ads: {} } }
  connect_timeout: 1s
  transport_socket: *mtls-client

- "@type": type.googleapis.com/envoy.config.cluster.v3.Cluster
  name: ratings
  type: EDS
  eds_cluster_config: { eds_config: { ads: {} } }
  connect_timeout: 1s
  transport_socket: *mtls-client

- "@type": type.googleapis.com/envoy.config.cluster.v3.Cluster
  name: web
  type: EDS
  eds_cluster_config: { eds_config: { ads: {} } }
  connect_timeout: 1s
  transport_socket: *mtls-client

- "@type": type.googleapis.com/envoy.config.cluster.v3.Cluster
  name: kafka                                  # TCP Upstream — same Cluster shape
  type: EDS
  eds_cluster_config: { eds_config: { ads: {} } }
  connect_timeout: 1s
  transport_socket: *mtls-client
```

[Config 3] shows an example CDS configuration corresponding to the Cluster part of [Figure 1]. Five Clusters — `reviews-v1`, `reviews-v2`, `ratings`, `web`, and `kafka` — are defined, and all are set to `type: EDS`, so the actual instance lists are delivered separately via EDS. All Clusters also share the mTLS configuration that uses the `internal-cert` Secret as the Client certificate and verifies the peer with the `internal-ca` Secret when connecting Upstream, which is what `SDS: internal-cert` marked on each Cluster in [Figure 1] means.

#### 1.1.4. EDS (Endpoint Discovery Service)

```yaml {caption="[Config 4] EDS Configuration", linenos=table}
resources:
 
- "@type": type.googleapis.com/envoy.config.endpoint.v3.ClusterLoadAssignment
  cluster_name: reviews-v1                     # CDS: must match the Cluster name
  endpoints:                                   # locality groups
  - lb_endpoints:
    - endpoint:
        address:
          socket_address: { address: 10.0.0.11, port_value: 80 }
    - endpoint:
        address:
          socket_address: { address: 10.0.0.12, port_value: 80 }
 
- "@type": type.googleapis.com/envoy.config.endpoint.v3.ClusterLoadAssignment
  cluster_name: reviews-v2
  endpoints:
  - lb_endpoints:
    - endpoint:
        address:
          socket_address: { address: 10.0.0.21, port_value: 80 }
 
- "@type": type.googleapis.com/envoy.config.endpoint.v3.ClusterLoadAssignment
  cluster_name: ratings
  endpoints:
  - lb_endpoints:
    - endpoint:
        address:
          socket_address: { address: 10.0.0.31, port_value: 80 }
 
- "@type": type.googleapis.com/envoy.config.endpoint.v3.ClusterLoadAssignment
  cluster_name: web
  endpoints:
  - lb_endpoints:
    - endpoint:
        address:
          socket_address: { address: 10.0.0.41, port_value: 80 }
    - endpoint:
        address:
          socket_address: { address: 10.0.0.42, port_value: 80 }
 
- "@type": type.googleapis.com/envoy.config.endpoint.v3.ClusterLoadAssignment
  cluster_name: kafka
  endpoints:
  - lb_endpoints:
    - endpoint:
        address:
          socket_address: { address: 10.0.0.51, port_value: 9092 }   # TCP backend — its own port
```

[Config 4] shows an example EDS configuration corresponding to the Endpoint part of [Figure 1]. The `cluster_name` of each ClusterLoadAssignment must match the Cluster name defined in CDS, which links the Cluster to the actual instance list. Requests to the `reviews-v1` Cluster are distributed across the two Endpoints `10.0.0.11:80` and `10.0.0.12:80`, and the `kafka` Cluster, a TCP Upstream, has the `10.0.0.51:9092` Endpoint.

#### 1.1.5. SDS (Secret Discovery Service)

```yaml {caption="[Config 5] SDS Configuration", linenos=table}
resources:
 
- "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.Secret
  name: internal-cert                          # shared by 1 Listener Chain + 5 Clusters
  tls_certificate:
    certificate_chain: { filename: "/etc/certs/cert-chain.pem" }
    private_key: { filename: "/etc/certs/key.pem" }      # redacted in config_dump
 
- "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.Secret
  name: internal-ca                            # same Secret type, different payload
  validation_context:                          # CA bundle for verifying peers
    trusted_ca: { filename: "/etc/certs/root-cert.pem" }
 
- "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.Secret
  name: web-cert                               # SAN must cover web.com (SNI)
  tls_certificate:
    certificate_chain: { filename: "/etc/certs/web-com.pem" }
    private_key: { filename: "/etc/certs/web-com-key.pem" }
 
- "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.Secret
  name: kafka-cert                             # SAN: kafka.com
  tls_certificate:
    certificate_chain: { filename: "/etc/certs/kafka-com.pem" }
    private_key: { filename: "/etc/certs/kafka-com-key.pem" }
```

[Config 5] shows an example SDS configuration corresponding to the Secret part of [Figure 1]. `internal-cert` is used both for the mTLS termination of `internal-listener` and as the Client certificate of every Cluster, and `internal-ca` is the CA Bundle used to verify peer certificates. `web-cert` and `kafka-cert` are the per-Filter-Chain Server certificates selected by SNI in `external-listener`.

#### 1.1.6. ECDS (Extension Config Discovery Service)

```yaml {caption="[Config 6] ECDS Configuration", linenos=table}
resources:

# ── Extension Config referenced by internal-listener (BY NAME) ────────
- "@type": type.googleapis.com/envoy.config.core.v3.TypedExtensionConfig
  name: internal-wasm                   # must match config_discovery name
  typed_config:
    "@type": type.googleapis.com/envoy.extensions.filters.http.wasm.v3.Wasm
    config:
      vm_config:
        runtime: envoy.wasm.runtime.v8
        code:
          local: { filename: "/etc/envoy/filter.wasm" }
```

[Config 6] shows an ECDS example that delivers the actual configuration of `internal-wasm`, which the `internal-listener` of [Config 1] references via `config_discovery`. In the Listener's HTTP Filter slot, only a reference (name and type_url) is placed instead of the configuration body, and the actual Filter configuration is delivered separately as a TypedExtensionConfig Resource of the same name.

If the Filter configuration is Inlined inside the Listener, changing the Filter configuration also becomes a Listener change. Envoy cannot directly modify the configuration of a running Listener, so it creates a new Listener with the changed configuration and swaps it in. During this process, the connections handled by the old Listener go through a Drain and are all disconnected within a certain time. In other words, changing even one line of Filter configuration can break Long-lived connections on that Port.

In contrast, with ECDS the Filter configuration is separated into an independent Resource outside the Listener, so on configuration updates the Listener stays intact and only the referenced configuration is replaced. Existing connections are unaffected, and the updated Filter configuration applies to new requests from then on. Just as RDS separated Routes from Listeners so that Route changes do not trigger Listener replacement, ECDS performs the same separation for Filter configuration. It is mainly used for Extensions with large or frequently changing configuration, such as Wasm Filters, and Istio's WasmPlugin CR being reflected this way is a representative example.

#### 1.1.7. ADS (Aggregated Discovery Service)

```yaml {caption="[Config 7] ADS Configuration", linenos=table}
# ── 1 · Envoy → Server: CDS wildcard subscription ─────────────────────
DiscoveryRequest:
  node: { id: envoy-node-1 }           # identity — sent once per stream
  type_url: "type.googleapis.com/envoy.config.cluster.v3.Cluster"
  resource_names: []                   # empty = wildcard (CDS/LDS subscribe like this)
 
# ── 2 · Server → Envoy: every Cluster ─────────────────────────────────
DiscoveryResponse:
  version_info: "v1"
  nonce: "n1"
  type_url: "type.googleapis.com/envoy.config.cluster.v3.Cluster"
  resources: [ ... ]                   # → [Config 3] CDS Configuration
 
# ── 3 · Envoy → Server: ACK, then derived EDS subscription BY NAME ────
DiscoveryRequest:
  type_url: "type.googleapis.com/envoy.config.cluster.v3.Cluster"
  version_info: "v1"                   # ACK — echo version + nonce back
  response_nonce: "n1"
DiscoveryRequest:
  type_url: "type.googleapis.com/envoy.config.endpoint.v3.ClusterLoadAssignment"
  resource_names: [reviews-v1, reviews-v2, ratings, web, kafka]   # names came from CDS
# ... the same pattern repeats — LDS (wildcard) → RDS / SDS / ECDS (by name):
#     RDS: [internal-routes, external-routes]  ·  SDS: [internal-cert, internal-ca, web-cert, kafka-cert]
#     ECDS: [internal-wasm]
 
# ── 4 · NACK: reject a broken update, keep the last good version ──────
DiscoveryRequest:
  type_url: "type.googleapis.com/envoy.config.listener.v3.Listener"
  version_info: "v1"                   # still the LAST GOOD version, not the broken one
  response_nonce: "n5"
  error_detail: { code: 3, message: "invalid filter_chain_match" }
```

[Config 7] shows the flow of xDS messages exchanged over a single gRPC Stream, corresponding to "1 Stream with ADS" at the top of [Figure 1]. Envoy subscribes to CDS and LDS with a Wildcard, and the EDS, RDS, SDS, and ECDS subscriptions are derived from the names referenced by the Clusters and Listeners received in the responses. Envoy sends an ACK for each response echoing back its `version_info` and `nonce`, and when it receives a broken configuration, it sends a NACK and keeps the last good version.

### 1.2. Bootstrap Configuration

```shell {caption="[Shell 1] Envoy Configuration Command Example", linenos=table}
./envoy -c config.yaml
```

[Shell 1] shows an example of running Envoy with a **Bootstrap Configuration file**. The Bootstrap Configuration file is, as the name suggests, the file Envoy loads when it starts, and it is the Root Configuration that serves as the starting point of all other configuration.

Envoy's configuration approach is largely divided into **Static Configuration**, which puts all the required configuration into the Bootstrap Configuration file and uses it as fixed values, and **Dynamic Configuration**, which fetches configuration dynamically from the outside through the xDS Protocol.

#### 1.2.1. Static Configuration

```yaml {caption="[Config 8] Static Configuration Example", linenos=table}
static_resources:

  listeners:                                           # INLINE → LDS
  - name: listener_http
    address:
      socket_address: { address: 0.0.0.0, port_value: 10000 }
    filter_chains:
    - filters:
      - name: envoy.filters.network.http_connection_manager
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
          stat_prefix: ingress_http
          route_config:                                # INLINE → RDS
            name: local_route
            virtual_hosts:
            - name: backend_vh
              domains: ["*"]
              routes:
              - match: { prefix: "/" }
                route: { cluster: service_backend }
          http_filters:
          - name: envoy.filters.http.router
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router

  clusters:                                            # INLINE → CDS
  - name: service_backend
    connect_timeout: 5s
    lb_policy: ROUND_ROBIN
    type: STATIC                                       # IP endpoints — no discovery
    load_assignment:                                   # INLINE → EDS
      cluster_name: service_backend
      endpoints:
      - lb_endpoints:
        - endpoint:
            address:
              socket_address: { address: 10.0.0.11, port_value: 8080 }
        - endpoint:
            address:
              socket_address: { address: 10.0.0.12, port_value: 8080 }

admin:
  address:
    socket_address: { address: 127.0.0.1, port_value: 9901 }
```

[Config 8] shows a **Static Configuration example** for Envoy. Static Configuration is the approach of putting all the configuration Envoy needs into the Bootstrap Configuration file as fixed values. Listeners, Routes, Clusters, and Endpoints are all defined Inline under `static_resources`, which is the form where each Resource that was delivered through the xDS APIs in [Figure 1] goes directly into the file.

`listener_http` forwards every request received on the `10000` Port through the Inline Route Table (`local_route`) to the two Endpoints of the `service_backend` Cluster. No xDS Server is needed, making the setup simple, but changing the configuration requires editing the file and restarting Envoy.

#### 1.2.2. Mostly Static with Dynamic EDS

```yaml {caption="[Config 9] Mostly Static with Dynamic EDS Example", linenos=table}
static_resources:
 
  listeners:                                           # INLINE (not LDS)
  - name: listener_http
    address:
      socket_address: { address: 0.0.0.0, port_value: 10000 }
    filter_chains:
    - filters:
      - name: envoy.filters.network.http_connection_manager
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
          stat_prefix: ingress_http
          route_config:                                # INLINE (not RDS)
            name: local_route
            virtual_hosts:
            - name: backend_vh
              domains: ["*"]
              routes:
              - match: { prefix: "/" }
                route: { cluster: service_backend }
          http_filters:
          - name: envoy.filters.http.router
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router
 
  clusters:                                            # INLINE (not CDS)
  - name: service_backend
    connect_timeout: 5s
    lb_policy: ROUND_ROBIN
    type: EDS                                          # EDS on
    eds_cluster_config:                                # EDS subscription
      service_name: service_backend                    #   key = cluster_name on the xDS Server
      eds_config:
        resource_api_version: V3
        api_config_source:                             # Dedicated gRPC stream (not ADS)
          api_type: GRPC
          transport_api_version: V3
          grpc_services:
          - envoy_grpc: { cluster_name: xds_cluster }  #   → static cluster below
 
  - name: xds_cluster                                  # STATIC bootstrap
    type: STRICT_DNS
    connect_timeout: 5s
    typed_extension_protocol_options:
      envoy.extensions.upstreams.http.v3.HttpProtocolOptions:
        "@type": type.googleapis.com/envoy.extensions.upstreams.http.v3.HttpProtocolOptions
        explicit_http_config:
          http2_protocol_options: {}                   # gRPC needs h2
    load_assignment:
      cluster_name: xds_cluster
      endpoints:
      - lb_endpoints:
        - endpoint:
            address:
              socket_address: { address: my-control-plane, port_value: 18000 }
 
admin:
  address:
    socket_address: { address: 127.0.0.1, port_value: 9901 }
```

[Config 9] shows an example that keeps the Listener, Route, and Cluster Static and **receives only the Endpoints dynamically via EDS**. The `service_backend` Cluster is set to `type: EDS`, so the actual instance list is subscribed from the xDS Server specified in `eds_config` with the `service_name` (`service_backend`) as the Key. Here the `api_config_source` uses a dedicated EDS gRPC Stream rather than ADS.

Since the address of the xDS Server itself cannot be fetched dynamically, `xds_cluster` must be defined directly in the Bootstrap file as a Static Cluster, with HTTP/2 enabled for gRPC communication. This approach is used in environments where only instance IPs change frequently due to deployments or Scaling, when you want to keep the routing structure fixed while reflecting Endpoint updates without a restart.

#### 1.2.3. Dynamic Configuration

```yaml {caption="[Config 10] Dynamic Configuration Example", linenos=table}
node:                                                  # xDS identity — xDS Server keys config on this
  id: envoy-node-1
  cluster: demo-cluster
 
dynamic_resources:
  lds_config:                                          # LDS on
    resource_api_version: V3
    ads: {}                                            #   via shared ADS stream
  cds_config:                                          # CDS on
    resource_api_version: V3
    ads: {}                                            #   via shared ADS stream
  ads_config:                                          # The single ADS stream
    api_type: GRPC
    transport_api_version: V3
    grpc_services:
    - envoy_grpc: { cluster_name: xds_cluster }        #   → static cluster below
    set_node_on_first_message_only: true
 
static_resources:
  clusters:
  - name: xds_cluster                                  # STATIC bootstrap
    type: STRICT_DNS
    connect_timeout: 5s
    typed_extension_protocol_options:
      envoy.extensions.upstreams.http.v3.HttpProtocolOptions:
        "@type": type.googleapis.com/envoy.extensions.upstreams.http.v3.HttpProtocolOptions
        explicit_http_config:
          http2_protocol_options: {}                   # gRPC needs h2
    load_assignment:
      cluster_name: xds_cluster
      endpoints:
      - lb_endpoints:
        - endpoint:
            address:
              socket_address: { address: my-control-plane, port_value: 18000 }
 
admin:
  address:
    socket_address: { address: 127.0.0.1, port_value: 9901 }
```

[Config 10] shows a **Dynamic Configuration example** that receives every Resource, starting from the Listeners and Clusters, via xDS. Both `lds_config` and `cds_config` under `dynamic_resources` are set to `ads`, so the LDS and CDS subscriptions are delivered over the single gRPC Stream defined in `ads_config`, and the RDS, EDS, SDS, and ECDS subscriptions derived from the responses also share the same Stream. The message flow exchanged over this Stream is [Config 7].

`node` is the Identity by which the xDS Server distinguishes which configuration to deliver to which Envoy, and `set_node_on_first_message_only` carries `node` only in the first message of the Stream to reduce the size of subsequent messages. As a result, only the xDS Server connection information (`xds_cluster`) and `admin` remain in the Bootstrap file, and all the Resources of [Config 1~6] examined earlier are delivered dynamically through this connection.

## 2. References

* Envoy xDS Protocol : [https://www.envoyproxy.io/docs/envoy/latest/api-docs/xds_protocol](https://www.envoyproxy.io/docs/envoy/latest/api-docs/xds_protocol)
* Envoy Life of a Request : [https://www.envoyproxy.io/docs/envoy/latest/intro/life_of_a_request](https://www.envoyproxy.io/docs/envoy/latest/intro/life_of_a_request)
* Envoy Listener Filters : [https://www.envoyproxy.io/docs/envoy/latest/configuration/listeners/listener_filters/listener_filters](https://www.envoyproxy.io/docs/envoy/latest/configuration/listeners/listener_filters/listener_filters)
* Envoy Network Filters : [https://www.envoyproxy.io/docs/envoy/latest/configuration/listeners/network_filters/network_filters](https://www.envoyproxy.io/docs/envoy/latest/configuration/listeners/network_filters/network_filters)

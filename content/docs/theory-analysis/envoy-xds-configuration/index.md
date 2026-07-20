---
title: "Envoy xDS, Configuration"
---

## 1. Envoy Configuration

Envoy Configuration은 Root Configration 역할을 수행하는 **Bootstrap Configuration 파일**과, 외부에서 동적으로 설정을 가져오는데 사용되는 xDS (eXtensible Discovery Services) Protocol이 함께 사용되어 이루어진다.

### 1.1. xDS (eXtensible Discovery Services) Protocol

{{< figure caption="[Figure 1] xDS (eXtensible Discovery Services) Resources and API" src="images/xds-resources-api.png" width="1100px" >}}

**xDS** **(eXtensible Discovery Services)**는 Envoy의 동작에 필요한 설정을 외부에서 동적으로 가져오는데 사용되는 CNCF의 표준 Protocol을 의미한다. [Figure 1]은 xDS를 이루는 Resource와 API를 나타내고 있다. xDS Resource는 다음과 같은 종류가 존재한다.

* **Listener** : Traffic을 받을 포트와 이를 처리할 Filter Chain(Protocol, TLS 등)을 정의한다.
* **Route** : Traffic을 어느 Cluster로 보낼지 정하는 Route Table을 정의한다.
* **Cluster** : Upstream 서비스 그룹의 정의와 LB 정책을 정의한다.
* **Endpoint** : Cluster에 속한 실제 인스턴스 IP, Port 목록을 정의한다.
* **Secret** : TLS 인증서와 키 등 민감 정보를 정의하며, 다른 Resource와 달리 SDS를 통해 별도 채널로 안전하게 전달된다.

[Figure 1]은 xDS 관점에서 xDS은 다음과 같은 종류가 존재한다.

* LDS (Listener Discovery Service) : Listener 설정(어느 포트로 트래픽을 받을지)을 동적으로 가져온다.
* RDS (Route Discovery Service) : Route 설정(요청을 어느 Cluster로 보낼지 정하는 라우팅 테이블)을 동적으로 가져온다.
* CDS (Cluster Discovery Service) : Cluster 설정(Upstream 서비스 그룹의 정의와 LB 정책)을 동적으로 가져온다.
* EDS (Endpoint Discovery Service) : Endpoint 설정(Cluster에 속한 실제 인스턴스 IP:Port 목록)을 동적으로 가져온다.
* SDS (Secret Discovery Service) : Secret 설정(TLS 인증서와 키)을 동적으로 가져온다.
* ADS (Aggregated Discovery Service) : 위의 xDS들(LDS/RDS/CDS/EDS/SDS)을 별도의 연결이 아닌 하나의 gRPC 스트림으로 묶어서 전달하는 방식이다. 새로운 설정 종류를 가져오는 것이 아니라, 여러 xDS 간의 적용 순서를 보장하기 위한 전송 메커니즘이며, Istio는 기본적으로 ADS만 사용한다.

#### 1.1.1. LDS (Listener Discovery Service)

```yaml {caption="[Config 1] LDS Configuration", linenos=table}
resources:

# ── Listener 1 · single chain · HTTP · mTLS terminate ─────────────────
- "@type": type.googleapis.com/envoy.config.listener.v3.Listener
  name: internal-listener                      # arbitrary string (istiod convention would be "0.0.0.0_8080")
  address:
    socket_address: { address: 0.0.0.0, port_value: 8080 }   # binding — unrelated to the name
  filter_chains:
  - transport_socket:                          # ← belongs to the CHAIN, not the listener
      name: envoy.transport_sockets.tls
      typed_config:
        "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.DownstreamTlsContext
        require_client_certificate: true       # the "m" in mTLS — require client cert
        common_tls_context:
          tls_certificate_sds_secret_configs:
          - name: internal-cert                # ← sds: the server cert I present
            sds_config: { ads: {} }
          validation_context_sds_secret_config:
            name: internal-ca                  # ← CA to verify the peer (proving ≠ verifying)
            sds_config: { ads: {} }
    filters:
    - name: envoy.filters.network.http_connection_manager
      typed_config:
        "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
        stat_prefix: ingress_http
        rds:
          route_config_name: internal-routes   # ← rds: the Route table to read (L7 only)
          config_source: { ads: {} }
        http_filters:
        - name: envoy.filters.http.router      # terminal — executes the matched RDS entry
          typed_config:
            "@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router

# ── Listener 2 · two SNI chains · different sds per chain ─────────────
- "@type": type.googleapis.com/envoy.config.listener.v3.Listener
  name: external-listener
  address:
    socket_address: { address: 0.0.0.0, port_value: 443 }
  listener_filters:
  - name: envoy.filters.listener.tls_inspector # reads SNI to pick a chain below (once per connection)
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
          - name: web-cert                     # ← sds: cert whose SAN is web.com
            sds_config: { ads: {} }
    filters:
    - name: envoy.filters.network.http_connection_manager
      typed_config:
        "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
        stat_prefix: https_web
        rds:
          route_config_name: external-routes   # ← rds: this chain's own Route table
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
          - name: kafka-cert                   # ← sds: same listener, different chain → different cert
            sds_config: { ads: {} }
    filters:
    - name: envoy.filters.network.tcp_proxy    # L4 — has no rds field at all
      typed_config:
        "@type": type.googleapis.com/envoy.extensions.filters.network.tcp_proxy.v3.TcpProxy
        stat_prefix: tcp_kafka
        cluster: kafka                         # straight to cluster, no Route table (no rds ≠ no sds)
```

#### 1.1.2. RDS (Route Discovery Service)

```yaml {caption="[Config 2] RDS Configuration", linenos=table}
resources:
- "@type": type.googleapis.com/envoy.config.route.v3.RouteConfiguration
  name: "8080"
  virtual_hosts:
  - name: "reviews.default.svc.cluster.local:8080"
    domains: ["reviews.default.svc.cluster.local"]
    routes:
    - match: { prefix: "/" }
      route:
        cluster: "outbound|8080||reviews.default.svc.cluster.local"
        timeout: 15s
```

#### 1.1.3. CDS (Cluster Discovery Service)

```yaml {caption="[Config 3] CDS Configuration", linenos=table}
resources:
 
# ── Table 1 · read by internal-listener (rds: internal-routes) ────────
- "@type": type.googleapis.com/envoy.config.route.v3.RouteConfiguration
  name: internal-routes                        # arbitrary string (istiod convention would be "8080")
  virtual_hosts:
 
  - name: reviews-vhost                        # vhost label — not matched, just a name
    domains: ["reviews"]                       # HOST rung: matched against Host header
    routes:                                    # PATH rung: first match wins — order matters
    - match: { prefix: "/api" }                # specific entry BEFORE the catch-all
      route:
        weighted_clusters:                     # WEIGHT rung: refs are CDS cluster names
          clusters:
          - name: reviews-v1
            weight: 80
          - name: reviews-v2
            weight: 20
        timeout: 15s
    - match: { prefix: "/" }                   # catch-all — everything /api didn't take
      route:
        cluster: reviews-v1                    # converges onto v1: entries may SHARE a cluster (N:1)
 
  - name: ratings-vhost
    domains: ["ratings"]
    routes:
    - match: { prefix: "/" }
      route:
        cluster: ratings
 
# ── Table 2 · read only by the web.com chain (rds: external-routes) ───
- "@type": type.googleapis.com/envoy.config.route.v3.RouteConfiguration
  name: external-routes
  virtual_hosts:
  - name: web-vhost
    domains: ["web.com"]                       # after TLS terminate, Host header says web.com
    routes:
    - match: { prefix: "/" }
      route:
        cluster: web
```

#### 1.1.4. EDS (Endpoint Discovery Service)

```yaml {caption="[Config 4] EDS Configuration", linenos=table}
resources:
 
- "@type": type.googleapis.com/envoy.config.endpoint.v3.ClusterLoadAssignment
  cluster_name: reviews-v1                     # must equal the CDS cluster's name
  endpoints:                                   # locality groups — contained field, not a resource
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

#### 1.1.5. SDS (Secret Discovery Service)

```yaml {caption="[Config 5] SDS Configuration", linenos=table}
resources:
 
- "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.Secret
  name: internal-cert                          # ← 6 refs share this one (1 chain + 5 clusters)
  tls_certificate:
    certificate_chain: { filename: "/etc/certs/cert-chain.pem" }
    private_key: { filename: "/etc/certs/key.pem" }      # redacted in config_dump
 
- "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.Secret
  name: internal-ca                            # same resource type, different payload:
  validation_context:                          # a CA bundle for verifying PEERS
    trusted_ca: { filename: "/etc/certs/root-cert.pem" }
 
- "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.Secret
  name: web-cert                               # SAN inside must cover web.com (matches the SNI)
  tls_certificate:
    certificate_chain: { filename: "/etc/certs/web-com.pem" }
    private_key: { filename: "/etc/certs/web-com-key.pem" }
 
- "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.Secret
  name: kafka-cert                             # SAN: kafka.com
  tls_certificate:
    certificate_chain: { filename: "/etc/certs/kafka-com.pem" }
    private_key: { filename: "/etc/certs/kafka-com-key.pem" }
```

#### 1.1.7. ADS (Aggregated Discovery Service)

```yaml {caption="[Config 6] ADS Configuration", linenos=table}
# ── 1 · stream opens: envoy identifies itself (node sent once) ────────
DiscoveryRequest:
  node:
    id: "sidecar~10.44.0.12~reviews-v1-abc.default~default.svc.cluster.local"
    #     role ~ podIP     ~ pod.namespace        ~ dns domain
  type_url: "type.googleapis.com/envoy.config.cluster.v3.Cluster"
  resource_names: []                   # empty = wildcard (CDS/LDS subscribe like this)
 
# ── 2 · server: CDS response ──────────────────────────────────────────
DiscoveryResponse:
  version_info: "v1"
  nonce: "n1"
  type_url: "type.googleapis.com/envoy.config.cluster.v3.Cluster"
  resources: [ ... ]                   # → envoy-cds-clusters-example.yaml
 
# ── 3 · envoy: ACK = echo version + nonce back on the same type ───────
DiscoveryRequest:
  type_url: "type.googleapis.com/envoy.config.cluster.v3.Cluster"
  version_info: "v1"                   # accepted this version
  response_nonce: "n1"
 
# ── 4 · derived subscription: EDS BY NAME (names came from CDS) ───────
DiscoveryRequest:
  type_url: "type.googleapis.com/envoy.config.endpoint.v3.ClusterLoadAssignment"
  resource_names: [reviews-v1, reviews-v2, ratings, web, kafka]
 
DiscoveryResponse:
  version_info: "v1"
  nonce: "n2"
  type_url: "type.googleapis.com/envoy.config.endpoint.v3.ClusterLoadAssignment"
  resources: [ ... ]                   # → envoy-eds-endpoints-example.yaml
 
# ── 5 · LDS (wildcard) → RDS / SDS (by name, derived from listeners) ──
DiscoveryRequest:
  type_url: "type.googleapis.com/envoy.config.listener.v3.Listener"
  resource_names: []                   # wildcard again
# ... response → envoy-lds-listeners-sds-rds.yaml, then:
DiscoveryRequest:
  type_url: "type.googleapis.com/envoy.config.route.v3.RouteConfiguration"
  resource_names: [internal-routes, external-routes]     # from rds: fields
DiscoveryRequest:
  type_url: "type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.Secret"
  resource_names: [internal-cert, internal-ca, web-cert, kafka-cert]
  # sds_config: { ads: {} } in L/C is what put these on THIS stream
 
# ── 6 · NACK example: keep last-good, report why ──────────────────────
DiscoveryRequest:
  type_url: "type.googleapis.com/envoy.config.listener.v3.Listener"
  version_info: "v1"                   # still the LAST GOOD version, not the broken one
  response_nonce: "n5"
  error_detail: { code: 3, message: "invalid filter_chain_match" }
```

```yaml {caption="[Config 7] ADS Configuration", linenos=table}
resources:

- "@type": type.googleapis.com/envoy.config.cluster.v3.Cluster
  name: reviews-v1
  type: EDS
  eds_cluster_config:
    eds_config: { ads: {} }                    # endpoints arrive separately, by this name
  connect_timeout: 1s
  transport_socket: &mtls-client               # YAML anchor — reused below (same value, per-cluster field)
    name: envoy.transport_sockets.tls
    typed_config:
      "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.UpstreamTlsContext
      common_tls_context:
        tls_certificate_sds_secret_configs:
        - name: internal-cert                  # ← sds: client cert (I prove myself)
          sds_config: { ads: {} }
        validation_context_sds_secret_config:
          name: internal-ca                    # ← CA to verify the SERVER side
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
  name: kafka                                  # TCP upstream — cluster shape is identical;
  type: EDS                                    # payload protocol is irrelevant here
  eds_cluster_config: { eds_config: { ads: {} } }
  connect_timeout: 1s
  transport_socket: *mtls-client
```

### 1.2. Bootstrap Configuration

```shell {caption="[Shell 1] Envoy Configuration Command Example", linenos=table}
./envoy -c config.yaml
```

Envoy Configuration은 **Bootstrap Configuration 파일**을 통해서 이루어진다. Bootstrap Configuration 파일은 이름에서 알 수 있듯이 Envoy의 Bootstrap 시에 사용되는 Configuration 파일을 의미하며, Envoy의 Root Configuration을 의미한다. [Shell 1]은 Envoy를 Bootstrap Configuration 파일과 함께 실행하는 예시를 나타내고 있다.

Envoy는 Bootstrap Configuration 파일에 필요한 설정을 모두 넣어서 고정적으로 이용하는 **Static Configuration**과, xDS (eXtensible Discovery Services) Protocol을 통해서 외부로부터 동적으로 가져와 이용하는 **Dynamic Configuration**으로 크게 구분할 수 있다.

#### 1.2.1. Static Configuration

```yaml {caption="[Config 1] Static Configuration Example", linenos=table}
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
    type: STRICT_DNS                                   # INLINE → EDS (w/ load_assignment)
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

[Config 1]은 Envoy의 **Static Configuration 예시**를 나타내고 있다. Static Configuration은 Bootstrap Configuration 파일에 Envoy 동작에 필요한 모든 설정을 고정값으로 넣어서 이용하는 방식을 의미한다. 

#### 1.2.2. Mostly Static with Dynamic EDS

```yaml {caption="[Config 2] Mostly Static with Dynamic EDS Example", linenos=table}
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
      service_name: service_backend                    #   key = server's cluster_name
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

#### 1.2.3. Dynamic Configuration

```yaml {caption="[Config 3] Dynamic Configuration Example", linenos=table}
node:                                                  # xDS identity (server keys config on this)
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

## 2. 참조

* Envoy Life of a Request : [https://www.envoyproxy.io/docs/envoy/latest/intro/life_of_a_request](https://www.envoyproxy.io/docs/envoy/latest/intro/life_of_a_request)
* Envoy Listener Filters : [https://www.envoyproxy.io/docs/envoy/latest/configuration/listeners/listener_filters/listener_filters](https://www.envoyproxy.io/docs/envoy/latest/configuration/listeners/listener_filters/listener_filters)
* Envoy Network Filters : [https://www.envoyproxy.io/docs/envoy/latest/configuration/listeners/network_filters/network_filters](https://www.envoyproxy.io/docs/envoy/latest/configuration/listeners/network_filters/network_filters)

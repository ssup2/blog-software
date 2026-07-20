---
title: "Envoy xDS, Configuration"
---

## 1. Envoy Configuration

Envoy Configuration은 Root Configration 역할을 수행하는 **Bootstrap Configuration 파일**과, 외부에서 동적으로 설정을 가져오는데 사용되는 xDS (eXtensible Discovery Services) Protocol이 함께 사용되어 이루어진다.

### 1.1. xDS (eXtensible Discovery Services) Protocol

{{< figure caption="[Figure 1] xDS (eXtensible Discovery Services) Resources and API" src="images/xds-resources-api.png" width="1100px" >}}

**xDS** **(eXtensible Discovery Services)**는 Envoy의 동작에 필요한 설정을 외부에서 동적으로 가져오는데 사용되는 CNCF의 표준 Protocol을 의미한다. [Figure 1]은 xDS를 이루는 Resource와 API를 나타내고 있다. xDS Resource는 다음과 같은 종류가 존재한다.

* **Listener** : Traffic을 수신할 주소와 Port, 그리고 이를 처리할 Filter Chain(Protocol, TLS 등)을 정의한다.
* **Route** : 요청을 어느 Cluster로 보낼지 결정하는 라우팅 규칙을 정의한다.
* **Cluster** : Upstream 서비스의 논리적 그룹으로, 연결 방식과 LB 정책을 정의한다.
* **Endpoint** : Cluster에 속한 실제 인스턴스의 IP:Port 목록을 정의한다.
* **Secret** : TLS 인증서와 키 등 민감 정보를 정의한다.

각 xDS Resource는 대응하는 xDS API를 통해 동적으로 설정된다. xDS API의 종류는 다음과 같다.

* **LDS (Listener Discovery Service)** : Listener 설정을 동적으로 전달한다.
* **RDS (Route Discovery Service)** : Route 설정을 동적으로 전달한다.
* **CDS (Cluster Discovery Service)** : Cluster 설정을 동적으로 전달한다.
* **EDS (Endpoint Discovery Service)** : Endpoint 설정을 동적으로 전달한다.
* **SDS (Secret Discovery Service)** : Secret 설정을 동적으로 전달한다.
* **ADS (Aggregated Discovery Service)** : 새로운 설정을 전달하는 API가 아니라, LDS/RDS/CDS/EDS/SDS를 별도의 연결 대신 하나의 gRPC Stream으로 묶어 전달하는 전송 메커니즘이다. 이를 통해 Management Server가 CDS → EDS → LDS → RDS와 같이 의존성에 맞는 적용 순서를 보장할 수 있으며, 설정 갱신 과정에서 발생할 수 있는 Traffic 유실을 방지할 수 있다.

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

[Config 1]은 [Figure 1]의 Listener 부분에 해당하는 LDS 설정 예시를 나타내고 있다. `internal-listener`는 `8080` Port에서 mTLS로 Traffic을 수신하며, `internal-cert` Secret으로 자신을 증명하고 `internal-ca` Secret으로 Client를 검증한 뒤 요청을 `internal-routes` Route Table로 넘긴다. `external-listener`는 `443` Port에서 TLS Inspector로 SNI를 확인하여 Filter Chain을 선택한다. `web.com` Chain은 `web-cert` Secret으로 TLS를 종료한 뒤 `external-routes` Route Table로 요청을 넘기고, `kafka.com` Chain은 `kafka-cert` Secret으로 TLS를 종료한 뒤 Route Table을 거치지 않고 TCP Proxy를 통해 `kafka` Cluster로 바로 전달한다.

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

[Config 2]는 [Figure 1]의 Route 부분에 해당하는 RDS 설정 예시를 나타내고 있다. `internal-routes` Route Table은 Host Header를 기준으로 Virtual Host를 선택한다. `reviews` Host의 `/api` 경로 요청은 `reviews-v1`과 `reviews-v2` Cluster로 80:20 가중치로 분배되고, 나머지 경로의 요청은 모두 `reviews-v1` Cluster로 전달된다.

여기서 Virtual Host 내부의 `routes` 목록은 위에서부터 순서대로 평가되어 처음 매칭되는 항목이 적용되는 **First Match Wins** 방식으로 동작한다. 따라서 `/api`처럼 구체적인 항목을 catch-all 항목(`/`) 앞에 두어야 하며, 순서가 반대가 되면 모든 요청이 catch-all 항목에 먼저 매칭되어 `/api` 항목은 선택되지 않는다. `ratings` Host의 요청은 모두 `ratings` Cluster로 전달된다. `external-routes` Route Table은 `web.com` Host의 요청을 모두 `web` Cluster로 전달한다.

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

[Config 3]은 [Figure 1]의 Cluster 부분에 해당하는 CDS 설정 예시를 나타내고 있다. `reviews-v1`, `reviews-v2`, `ratings`, `web`, `kafka` 다섯 개의 Cluster가 정의되어 있으며, 모두 `type: EDS`로 설정되어 실제 인스턴스 목록은 EDS를 통해 별도로 전달받는다. 또한 모든 Cluster는 Upstream 연결 시 `internal-cert` Secret을 Client 인증서로 사용하고 `internal-ca` Secret으로 상대방을 검증하는 mTLS 설정을 공유하며, [Figure 1]의 각 Cluster에 표시된 `SDS: internal-cert`가 이를 의미한다.

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

[Config 4]는 [Figure 1]의 Endpoint 부분에 해당하는 EDS 설정 예시를 나타내고 있다. 각 ClusterLoadAssignment의 `cluster_name`은 CDS에서 정의한 Cluster 이름과 일치해야 하며, 이를 통해 Cluster와 실제 인스턴스 목록이 연결된다. `reviews-v1` Cluster는 `10.0.0.11:80`과 `10.0.0.12:80` 두 개의 Endpoint로 요청이 분배되고, TCP Upstream인 `kafka` Cluster는 `10.0.0.51:9092` Endpoint를 가진다.

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

[Config 5]는 [Figure 1]의 Secret 부분에 해당하는 SDS 설정 예시를 나타내고 있다. `internal-cert`는 `internal-listener`의 mTLS 종료와 모든 Cluster의 Client 인증서로 함께 사용되며, `internal-ca`는 상대방 인증서 검증에 사용되는 CA Bundle이다. `web-cert`와 `kafka-cert`는 `external-listener`에서 SNI에 따라 선택되는 Filter Chain별 Server 인증서이다.

#### 1.1.6. ADS (Aggregated Discovery Service)

```yaml {caption="[Config 6] ADS Configuration", linenos=table}
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
# ... the same pattern repeats — LDS (wildcard) → RDS / SDS (by name):
#     RDS: [internal-routes, external-routes]  ·  SDS: [internal-cert, internal-ca, web-cert, kafka-cert]
 
# ── 4 · NACK: reject a broken update, keep the last good version ──────
DiscoveryRequest:
  type_url: "type.googleapis.com/envoy.config.listener.v3.Listener"
  version_info: "v1"                   # still the LAST GOOD version, not the broken one
  response_nonce: "n5"
  error_detail: { code: 3, message: "invalid filter_chain_match" }
```

[Config 6]은 [Figure 1] 상단의 1 Stream with ADS에 해당하는, 하나의 gRPC Stream 위에서 오가는 xDS 메시지 흐름을 나타내고 있다. Envoy는 CDS와 LDS를 Wildcard로 구독하고, 응답으로 받은 Cluster와 Listener가 참조하는 이름을 기반으로 EDS, RDS, SDS 구독이 파생된다. Envoy는 각 응답에 대해 `version`과 `nonce`를 되돌려주는 ACK를 보내며, 잘못된 설정을 받은 경우에는 NACK를 보내고 마지막 정상 버전을 유지한다.

### 1.2. Bootstrap Configuration

```shell {caption="[Shell 1] Envoy Configuration Command Example", linenos=table}
./envoy -c config.yaml
```

Envoy Configuration은 **Bootstrap Configuration 파일**을 통해서 이루어진다. Bootstrap Configuration 파일은 이름에서 알 수 있듯이 Envoy의 Bootstrap 시에 사용되는 Configuration 파일을 의미하며, Envoy의 Root Configuration을 의미한다. [Shell 1]은 Envoy를 Bootstrap Configuration 파일과 함께 실행하는 예시를 나타내고 있다.

Envoy는 Bootstrap Configuration 파일에 필요한 설정을 모두 넣어서 고정적으로 이용하는 **Static Configuration**과, xDS (eXtensible Discovery Services) Protocol을 통해서 외부로부터 동적으로 가져와 이용하는 **Dynamic Configuration**으로 크게 구분할 수 있다.

#### 1.2.1. Static Configuration

```yaml {caption="[Config 7] Static Configuration Example", linenos=table}
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

[Config 7]은 Envoy의 **Static Configuration 예시**를 나타내고 있다. Static Configuration은 Bootstrap Configuration 파일에 Envoy 동작에 필요한 모든 설정을 고정값으로 넣어서 이용하는 방식을 의미한다. `static_resources` 아래에 Listener, Route, Cluster, Endpoint가 모두 Inline으로 정의되어 있으며, [Figure 1]에서 xDS API를 통해 전달되던 각 Resource가 파일 안에 그대로 들어간 형태이다. `listener_http`는 `10000` Port로 수신한 모든 요청을 Inline Route Table(`local_route`)을 거쳐 `service_backend` Cluster의 두 Endpoint로 전달한다. xDS Server가 필요 없어 구성이 단순하지만, 설정을 변경하려면 파일을 수정하고 Envoy를 재시작해야 한다.

#### 1.2.2. Mostly Static with Dynamic EDS

```yaml {caption="[Config 8] Mostly Static with Dynamic EDS Example", linenos=table}
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

[Config 8]은 Listener, Route, Cluster는 Static으로 고정하고 **Endpoint만 EDS로 동적으로 받는 예시**를 나타내고 있다. `service_backend` Cluster가 `type: EDS`로 설정되어 있어, 실제 인스턴스 목록은 `eds_config`에 지정된 xDS Server로부터 `service_name`(`service_backend`)을 Key로 구독한다. 이때 `api_config_source`는 ADS가 아닌 EDS 전용 gRPC Stream을 사용한다. xDS Server의 주소 자체는 동적으로 받아올 수 없으므로, `xds_cluster`는 Static Cluster로 Bootstrap 파일에 직접 정의되어야 하며 gRPC 통신을 위해 HTTP/2가 활성화되어 있다. 이 방식은 배포나 Scaling으로 인스턴스 IP만 자주 바뀌는 환경에서, 라우팅 구조는 고정한 채 Endpoint 갱신만 재시작 없이 반영하고 싶을 때 사용된다.

#### 1.2.3. Dynamic Configuration

```yaml {caption="[Config 9] Dynamic Configuration Example", linenos=table}
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

[Config 9]는 Listener와 Cluster부터 모든 Resource를 xDS로 받아오는 **Dynamic Configuration 예시**를 나타내고 있다. `dynamic_resources`의 `lds_config`와 `cds_config`가 모두 `ads`로 지정되어 있어, LDS와 CDS 구독이 `ads_config`에 정의된 단일 gRPC Stream으로 전달되고, 응답에서 파생되는 RDS, EDS, SDS 구독도 같은 Stream을 공유한다. 이 Stream 위에서 오가는 메시지 흐름이 [Config 6]이다. `node`는 xDS Server가 어느 Envoy에게 어떤 설정을 내려줄지 구분하는 Identity이며, `set_node_on_first_message_only`는 Stream의 첫 메시지에만 `node`를 실어 이후 메시지의 크기를 줄인다. 결과적으로 Bootstrap 파일에는 xDS Server 접속 정보(`xds_cluster`)와 `admin`만 남고, 앞서 살펴본 [Config 1]~[Config 5]의 모든 Resource가 이 연결을 통해 동적으로 전달된다.

## 2. 참조

* Envoy Life of a Request : [https://www.envoyproxy.io/docs/envoy/latest/intro/life_of_a_request](https://www.envoyproxy.io/docs/envoy/latest/intro/life_of_a_request)
* Envoy Listener Filters : [https://www.envoyproxy.io/docs/envoy/latest/configuration/listeners/listener_filters/listener_filters](https://www.envoyproxy.io/docs/envoy/latest/configuration/listeners/listener_filters/listener_filters)
* Envoy Network Filters : [https://www.envoyproxy.io/docs/envoy/latest/configuration/listeners/network_filters/network_filters](https://www.envoyproxy.io/docs/envoy/latest/configuration/listeners/network_filters/network_filters)

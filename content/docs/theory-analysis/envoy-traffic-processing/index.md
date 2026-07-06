---
title: "Envoy Traffic Processing"
---

## 1. Envoy HTTP Traffic Processing

{{< figure caption="[Figure 1] Envoy HTTP Traffic Processing" src="images/envoy-traffic-processing.png" width="1000px" >}}

### 1.1. Listener

**Listener**는 커널이 TCP 3-way Handshake를 완료해 Accept Queue에 올려둔 Downstream 연결을 `accept()` 함수로 수락하여 새로운 Socket을 얻는다. 이후에 얻은 Socket을 Dispatcher에 등록하고, TCP Connection 관련 정보를 얻기위한 **Listener Filter Chain**을 Instance를 생성한다. 다수의 Listner가 등록되어 있는 경우에는 일반적으로 IP, Port를 통해서 어떤 Listener가 해당 Connection을 처리할지 결정하게 된다.

### 1.2. Listener Filter Chain

**Listener Filter Chain**은 Downstream과 TCP 연결이 맺어진 뒤, 들어온 트래픽의 앞부분을 소비하지 않고 `recv(..., MSG_PEEK)`로 엿보아 필요한 연결 정보를 얻는 데 사용된다. 일부  Filter(`proxy_protocol`)는 앞쪽의 PROXY Protocol Header를 실제로 읽어 원래 클라이언트 주소를 복원하고 그 헤더를 소비(제거)하기도 한다. Listener는 새로운 연결마다 Listener Filter 인스턴스를 생성하므로, 각 TCP 연결별로 별도의 Listener Filter Chain이 존재한다. Envoy가 제공하는 대표적인 Listener Filter는 다음과 같다.

* `envoy.filters.listener.original_dst` : iptables `REDIRECT` 등으로 가려진 원래 목적지 IP, Port를 `getsockopt(SO_ORIGINAL_DST)` System Call로 복원한다. Istio 같은 Mesh Network 환경에서 Envoy가 실제 목적지 정보를 얻기 위해 사용된다.
* `envoy.filters.listener.original_src` : 원래 Downstream의 출발지 IP, Port를 `setsockopt(IP_TRANSPARENT)` System Call로 보존하여 Upstream으로 전송한다.
* `envoy.filters.listener.proxy_protocol` : PROXY Protocol을 사용하는 경우, 맨 앞 PROXY Header를 읽어 원래 Client IP, Port를 Envoy에서 Downstream IP, Port로 설정하고 그 Header를 제거한다.
* `envoy.filters.listener.tls_inspector` : TLS를 사용하는 경우, ClientHello를 엿보아 SNI(Server Name Indication), ALPN(Application Layer Protocol Negotiation) 등 정보를 추출한다.
* `envoy.filters.listener.http_inspector` : TLS를 사용하지 않아 ALPN 이용이 불가능한 경우, 앞쪽 Byte를 엿보아 HTTP 프로토콜 버전(HTTP/1.x인지 HTTP/2인지)을 감지한다.

Listener Filter Chain은 Envoy Config에 따라서 자유롭게 구성할 수 있지만, 일반적으로 목적지 IP, Port를 복원하기 위한 `original_dst` Filter를 첫 번째로 사용하며, Proxy Protocol을 사용하는 경우, Proxy Header를 제거하기 위한 `proxy_protocol` Filter를 두 번째로 구성한다. 단순히 TCP Connection의 Meta 정보를 얻기 위한 `tls_inspector`, `http_inspector` Filter는 뒤에 구성하며, 일반적으로 `tls_inspector`, `http_inspector` 순서대로 구성하여 TLS가 아닌 경우, `http_inspector` Filter가 HTTP 버전을 판별하도록 한다.

```cpp linenos {caption="[Code 1] Listener Filter Chain Interface", linenos=table}
virtual FilterStatus onAccept(ListenerFilterCallbacks& cb) PURE;
```

[Code 1]은 Listener Filter Chain이 구현해야하는 `onAccept()` Interface를 나타내고 있다. Parameter로 `onAccept()` 함수 내부에서 현재 TCP Connection을 제어할 수 있는 `ListenerFilterCallbacks` Callback 함수를 전달하며, 결과로 Listener Filter Chain을 계속 진행할지 또는 잠깐 중단할지를 결정하는 `FilterStatus`를 반환한다.

### 1.3. Filter Chain Manager

Listener Filter Chain의 `tls_inspector` Filter 또는 `http_inspector` Filter를 통해서 Server Name과 Application Protocol을 파악한 이후에, **Filter Chain Manager**는 해당 TCP Connection으로 전송되는 요청을 처리하기 위한 Downstream Transport Socket Instance와 Network Filter Chain Instance를 생성한다. 즉 각 TCP Connection별로 별도의 Downstream Transport Socket Instance와 Network Filter Chain Instance가 존재하게 된다.

### 1.4. Downstream Transport Socket

**Downstream Transport Socket** Downstream으로 부터 전달받은 Traffic을 Network Filter Chain으로 전달하기 위한 다리 역할을 수행한다. TLS가 적용된 경우 **TLS Transport Socket**을 통해서 Downstream으로 부터 전달받은 Traffic을 복호화하여 Network Filter Chain으로 전달하고, 반대로 Network Filter Chain으로 부터 전달받은 Traffic을 암호화하여 Downstream으로 전송한다. 따라서 Network Filter Chain은 암호화되지 않은 Plain Text를 처리하게 된다.

TLS가 적용되지 않은 경우에는 **Raw Buffer Transport Socket**을 통해서 Downstream으로 부터 전달받은 Traffic을 변형 없이 그대로 Network Filter Chain으로 전달하거나, 반대로 Network Filter Chain으로 부터 전달받은 Traffic을 변형 없이 Downstream으로 전송하는 역할을 수행한다.

```cpp linenos {caption="[Code 2] Downstream Transport Socket Interface", linenos=table}
virtual void onConnected() PURE;
virtual IoResult doRead(Buffer::Instance& buffer) PURE;
virtual IoResult doWrite(Buffer::Instance& buffer, bool end_stream) PURE;
virtual void closeSocket(Network::ConnectionEvent event) PURE;
```

[Code 2]는 Downstream Transport Socket이 구현해야하는 `onConnected()`, `doRead()`, `doWrite()`, `closeSocket()` Interface를 나타내고 있으며, 역할은 다음과 같다.

* `onConnected()` : TCP Connection이 맺어진 이후 호출되며, TLS를 이용하는 경우 TLS Handshake를 개시한다.
* `doRead()` : Downstream으로부터 전달받은 트래픽을 읽어 Network Filter Chain으로 전달한다. TLS를 이용하는 경우 복호화하여 Plain Text를 올린다.
* `doWrite()` : Network Filter Chain으로부터 전달받은 트래픽을 Downstream으로 전송한다. TLS를 이용하는 경우 암호화하여 Cipher Text를 내보낸다.
* `closeSocket()` : Socket이 닫히면 호출되며, TLS를 이용하는 경우 `close_notify` Alert을 전송하고 Session을 종료한다.

### 1.5. Network Filter Chain

Network Filter Chain은 Downstream으로 부터 전달받은 Plain Text를 가공하여 Upstream HTTP Filter Chain으로 전달하는 역할을 수행한다. Envoy의 대부분의 핵심 기능은 Network Filter Chain에서 구현된다. Network Filter는 Chain 중간에 실행되는 **Non-terminal Filter**와 Chain의 마지막에 실행되는 **Terminal Filter**로 구분되며, Non-terminal Filter는 자유롭게 순서를 변경하여 구성할 수 있지만, Terminal Filter는 반드시 Network Filter Chain의 마지막에 위치해야 한다.

Envoy에서 제공하는 주요 Non-terminal Filter는 다음과 같다.

* `envoy.filters.network.connection_limit` : Downstream 동시 커넥션 수 제한 수행.
* `envoy.filters.network.rbac` : L4 기반 접근 제어 수행. (IP/SNI/mTLS Principal)
* `envoy.filters.network.ext_authz` : L4 기반 외부 인가 수행. (gRPC authz 서버 호출)
* `envoy.filters.network.local_ratelimit` : L4 기반 Local Rate Limit 수행. (Local Token Bucket 이용)
* `envoy.filters.network.ratelimit` : L4 기반 Global Rate Limit 수행. (Rate Limit Service를 활용한 Global Token Bucket 이용)
* `envoy.filters.network.wasm` : WASM(WebAssembly)을 이용한 커스텀 L4 로직 수행.
* `envoy.filters.network.mysql_proxy` : MySQL Protocol 파싱 및 통계 처리 수행. Terminal Filter로 `mysql_proxy` Filter 이용.
* `envoy.filters.network.postgres_proxy` : PostgreSQL Protocol 파싱 및 통계 처리 수행. Terminal Filter로 `postgres_proxy` Filter 이용.
* `envoy.filters.network.mongo_proxy` : MongoDB Protocol 파싱 및 통계 처리 수행. Terminal Filter로 `tcp_proxy` Filter 이용.

Envoy에서 제공하는 Terminal Filter는 다음과 같다.

* `envoy.filters.network.tcp_proxy` : TCP Proxy 수행.
* `envoy.filters.network.redis_proxy` : Redis Protocol 처리.
* `envoy.filters.network.kafka_broker` : Kafka Protocol 처리.
* `envoy.filters.network.http_connection_manager` : HTTP/1.x, HTTP/2.0, HTTP/3 Protocol 처리.

```cpp linenos {caption="[Code 3] Network Filter Chain Interface", linenos=table}
virtual FilterStatus onNewConnection() PURE;
virtual FilterStatus onData(Buffer::Instance& data, bool end_stream) PURE;
virtual FilterStatus onWrite(Buffer::Instance& data, bool end_stream) PURE;
```

[Code 3]는 Network Filter Chain이 구현해야하는 `onNewConnection()`, `onData()`, `onWrite()` Interface를 나타내고 있으며, 역할은 다음과 같다.

* `onNewConnection()` : 처음 TCP Connection이 맺어진 이후 한번 호출되며, TCP Connection의 속성만으로 초기 판단(동시 커넥션 수 제한, L4 접근 제어)을 하고, 결과로 `Continue` 또는 `StopIteration`을 반환한다.
* `onData()` : Downstream에서 Upstream으로 요청 Traffic을 전송할 때마다 호출된다. 결과로 `Continue` 또는 `StopIteration`을 반환한다.
* `onWrite()` : Upstream에서 Downstream으로 응답 Traffic을 전송할 때마다 호출된다. 결과로 `Continue` 또는 `StopIteration`을 반환한다.

#### 1.5.1. HTTP Connection Manager

**HTTP Connection Manager** (HCM)은 HTTP Protocol을 처리하는 Terminal Network Filter로 동작한다. 앞의 Network Filter Chain에서는 L4 기반으로 동작하지만, HTTP Connection Manager는 **L7 기반**으로 동작한다.

##### 1.5.1.1. HTTP Codec

**HTTP Codec**은 Downstream에서 Upstream으로 요청 Traffic을 전송하는 경우에는, HTTP Protocol Version에 관계없이 HTTP Filter가 일관된 형태로 처리할 수 있도록 Stream을 Decoding 하여 Header와 Body를 분리한다. 반대로 Upstream에서 Downstream으로 응답 Traffic을 전송하는 경우에는, Downstream에서 이용중인 HTTP Protocol Version에 맞춰서 Stream을 Encoding하여 전송하는 역할을 수행한다.

##### 1.5.1.2. Downstream HTTP Filter

**Downstream HTTP Filter**는 Router에 넘기기 전에 L7 기반으로 Traffic을 처리하는 역할을 수행한다. 인증/인가, Traffic 제한, Traffic 가공등의 다양한 기능을 수행할 수 있다. Downstream HTTP Filter도 자유롭게 순서를 변경하여 구성할 수 있지만, Router Filter는 반드시 마지막에 위치해야 한다.

Envoy에서 제공하는 인증/인가 Filter는 다음과 같다. 일반적으로 Chain 앞쪽에 구성한다.

* `envoy.filters.http.jwt_authn` : JWT 검증. 검증된 claim을 뒤 필터가 쓸 수 있게 전달.
* `envoy.filters.http.ext_authz` : 외부 인가 서비스(gRPC/HTTP) 호출로 허용/차단 결정.
* `envoy.filters.http.rbac` : L7 접근 제어. (경로/헤더/JWT Claim 기반)
* `envoy.filters.http.oauth2` : OAuth2 Login 처리.

Envoy에서 제공하는 Traffic 제한 Filter는 다음과 같다.

* `envoy.filters.http.local_ratelimit` : L7 기반 Local Rate Limit 수행. (Local Token Bucket 이용)
* `envoy.filters.http.ratelimit` : L7 기반 Global Rate Limit 수행. (Rate Limit Service를 활용한 Global Token Bucket 이용)

Envoy에서 제공하는 Traffic 가공 Filter는 다음과 같다.

* `envoy.filters.http.cors` : CORS 처리.
* `envoy.filters.http.grpc_web` : gRPC-Web <-> gRPC 변환.
* `envoy.filters.http.grpc_json_transcoder` : REST/JSON <-> gRPC 변환.
* `envoy.filters.http.compressor` : Upstream에서 Downstream으로 나가는 응답 Traffic 압축.
* `envoy.filters.http.decompressor` : Downstream에서 Upstream으로 들어오는 요청 Traffic 압축 해제.
* `envoy.filters.http.header_mutation` : HTTP Header 추가/삭제/수정.
* `envoy.filters.http.grpc_stats` : gRPC 통계 수집.

Envoy에서 제공하는 커스텀 로직 Filter는 다음과 같다.

* `envoy.filters.http.lua` : Lua Script를 이용한 커스텀 로직.
* `envoy.filters.http.wasm` : L7 WASM (WebAssembly) 기반 커스텀 로직.
* `envoy.filters.http.fault` : Fault Injection
* `envoy.filters.http.buffer` : 요청 전체를 Buffering.
* `envoy.filters.http.health_check` : 특정 경로를 Health Check 응답으로 처리.

##### 1.5.1.3. Router Filter

**Router Filter**는 Downstream HTTP Filter 의 마지막에 위치하는 Terminal Filter로, 요청을 실제 Upstream으로 보내는 역할을 담당한다. 앞의 모든 Filter를 통과한 요청에 대해, Route Config의 규칙에 따라 **Target Cluster**를 결정한다. 이후 **Outlier Detection** 정책을 통해서 Cluster에 소속되어 있는 Host 중에서 비정상 Host를 제외한다. 이후에는 남은 정상 Host 중에서 **Load Balancing** 정책에 따라 실제 Host를 선택하고, 해당 Host로의 연결을 통해 요청을 전달한다.

Router Filter는 다음과 같은 Load Balancing 정책을 제공한다.

* `envoy.load_balancing_policies.round_robin` : Host를 순서대로 하나씩 선택이며, 가장 기본적인 정책.
* `envoy.load_balancing_policies.least_request` : 활성 요청이 적은 Host 우선. 무작위 2개를 뽑아 비교하는 P2C 방식.
* `envoy.load_balancing_policies.random` : 정상 Host 중 무작위 선택. 단순하고 가벼운 방식.
* `envoy.load_balancing_policies.ring_hash` : 일관 해싱. 같은 키(Header/Cookie/IP 등)는 같은 Host로. 세션 어피니티용.
* `envoy.load_balancing_policies.maglev` : Lookup Table 기반 일관 해싱. `ring_hash`보다 빠르고 균등하나 Host 변동 시 재배치가 다소 큼.
* `envoy.load_balancing_policies.client_side_weighted_round_robin` : Host가 리포트한 부하 지표로 Weight를 동적 계산해 반영하는 Round Robin.
* `envoy.load_balancing_policies.wrr_locality` : Locality(Zone) 간 분배를 Weight로 제어하고, Zone 내부 선택은 하위 정책에 위임하는 계층형 정책.

### 1.6. Upstream HTTP Filter

Upstream HTTP Filter는 Router Filter에 의해서 어느 Host로 Traffic을 전달할지 결정도니 이후에 실행되는 Filter이다. Upstresm Filter Instance는 매 재시도마다 Router Filter에 의해서 새로운 Instance가 생성되는 특징을 갖는다. Envoy에서 제공하는 Upstream HTTP Filter는 다음과 같다.

* `envoy.filters.http.header_mutation` : 선택된 Upstream Host를 기준으로 Header를 추가/삭제/수정. 어느 Host로 Traffic이 전달되는지 정해진 뒤에 헤더를 조작해야 할 때 이용.
* `envoy.filters.http.lua` : Upstream Context에서 Lua Script로 Custom Logic 수행.
* `envoy.filters.http.wasm` : Upstream Context에서 WASM (WebAssembly) 기반 Custom Logic 수행.
* `envoy.filters.http.upstream_codec` : Upstream HTTP Filter Chain의 마지막에 위치하는 Terminal Filter로, HTTP Connection Manager 내부의 HTTP Codec과 대칭적으로 Upstream 방향의 Encoding/Decoding을 담당한다. 생략시 자동으로 추가되는 특징을 갖는다.

### 1.7. Upstream Transport Socket

**Upstream Transport Socket**은 Downstream Transport Socket과 대칭적으로 Upstream 방향의 Transport Socket을 제공한다. TLS가 적용된 경우, Upstream Codec Filter로부터 전달받은 요청 트래픽을 암호화하여 Upstream으로 전송하고, 반대로 Upstream으로부터 받은 응답 트래픽을 복호화하여 Upstream Codec Filter로 올린다. TLS가 적용되지 않은 경우에는 Downstream과 동일하게 Raw Buffer Transport Socket이 트래픽을 변형 없이 그대로 전달한다.

## 2. Envoy Configuration

```yaml linenos {caption="[Text 1] Envoy Configuration", linenos=table}
static_resources:

  listeners:
  # ── 1. Listener ──────────────────────────────────────────────
  - name: main_listener
    address:
      socket_address: { address: 0.0.0.0, port_value: 10000 }

    # ── 2. Listener Filter Chain (names only) ───────────────────
    listener_filters:
    - name: envoy.filters.listener.tls_inspector       # Peeks at ClientHello to extract SNI/ALPN
    - name: envoy.filters.listener.http_inspector       # Detects HTTP version (h1/h2)
    - name: envoy.filters.listener.proxy_protocol       # Parses the leading PROXY header
    - name: envoy.filters.listener.original_dst         # Restores original destination (iptables REDIRECT)

    # ── 3. Filter Chain Manager ──────────────────────────────────
    # Selects one of the filter_chains below based on info extracted
    # by listener_filters (SNI, ALPN, etc.)
    filter_chains:

    # (a) Match by SNI (server_names) — most common case
    - filter_chain_match:
        server_names: ["example.com", "*.example.com"]

      # ── 4. Downstream Transport Socket (TLS termination) ──────
      transport_socket:
        name: envoy.transport_sockets.tls
        common_tls_context:
          tls_certificates:
          - certificate_chain: { filename: "/etc/envoy/cert.pem" }
            private_key:       { filename: "/etc/envoy/key.pem" }

      # ── 5. Network Filter Chain ──────────────────────────────
      filters:
      - name: envoy.filters.network.connection_limit
      - name: envoy.filters.network.rbac
      - name: envoy.filters.network.local_ratelimit

      # ── 6. HTTP Connection Manager (terminal filter of the network chain) ──
      - name: envoy.filters.network.http_connection_manager
        stat_prefix: ingress_http
        codec_type: AUTO                              # ── 7. HTTP Codec ──

        route_config:
          name: local_route
          virtual_hosts:
          - name: backend_vh
            domains: ["*"]
            routes:
            - match: { prefix: "/" }
              route: { cluster: backend }

        # ── 8. Downstream HTTP Filter ──────────────────────────
        http_filters:
        - name: envoy.filters.http.cors
        - name: envoy.filters.http.jwt_authn
        - name: envoy.filters.http.local_ratelimit
        - name: envoy.filters.http.fault
        - name: envoy.filters.http.compressor
        - name: envoy.filters.http.lua

        # ── 9. Router Filter (terminal filter of the downstream chain) ──
        - name: envoy.filters.http.router

    # (b) Match by ALPN — route h2 traffic to this chain
    - filter_chain_match:
        application_protocols: ["h2"]
      # (filters omitted — in practice, build a full network/http filter chain like (a))

  # ── 1b. Listener (second listener — plain HTTP, e.g. internal/health traffic) ──
  - name: internal_listener
    address:
      socket_address: { address: 0.0.0.0, port_value: 8080 }
    # (filter_chains omitted — in practice, build a full network/http filter chain like (a))

  clusters:
  - name: backend
    type: STRICT_DNS
    lb_policy: ROUND_ROBIN
    load_assignment:
      cluster_name: backend
      endpoints:
      - lb_endpoints:
        - endpoint:
            address:
              socket_address: { address: httpbin.org, port_value: 443 }

    typed_extension_protocol_options:
      envoy.extensions.upstreams.http.v3.HttpProtocolOptions:
        explicit_http_config:
          http_protocol_options: {}

        # ── 10. Upstream HTTP Filter ──────────────────────────
        http_filters:
        - name: envoy.filters.http.header_mutation
        - name: envoy.filters.http.lua
        - name: envoy.filters.http.upstream_codec        # terminal

    # ── 11. Upstream Transport Socket (TLS origination) ────────
    transport_socket:
      name: envoy.transport_sockets.tls
      sni: httpbin.org
```

## 3. 참조

* Envoy Life of a Request : [https://www.envoyproxy.io/docs/envoy/latest/intro/life_of_a_request](https://www.envoyproxy.io/docs/envoy/latest/intro/life_of_a_request)
* Envoy Listener Filters : [https://www.envoyproxy.io/docs/envoy/latest/configuration/listeners/listener_filters/listener_filters](https://www.envoyproxy.io/docs/envoy/latest/configuration/listeners/listener_filters/listener_filters)
* Envoy Network Filters : [https://www.envoyproxy.io/docs/envoy/latest/configuration/listeners/network_filters/network_filters](https://www.envoyproxy.io/docs/envoy/latest/configuration/listeners/network_filters/network_filters)


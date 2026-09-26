---
title: "Envoy Traffic Processing"
---

## 1. Envoy HTTP Traffic Processing

{{< figure caption="[Figure 1] Envoy HTTP Traffic Processing" src="images/envoy-traffic-processing.png" width="1000px" >}}

### 1.1. Listener

The **Listener** accepts, with the `accept()` function, a Downstream connection that the kernel has completed the TCP 3-way Handshake for and placed in the Accept Queue, obtaining a new Socket. It then registers the obtained Socket with the Dispatcher and creates a **Listener Filter Chain** Instance for obtaining TCP Connection related information. When multiple Listeners are registered, which Listener handles the Connection is generally determined by the IP and Port.

### 1.2. Listener Filter Chain

The **Listener Filter Chain** is used, after the TCP connection with the Downstream is established, to obtain necessary connection information by peeking at the front of the incoming Traffic with `recv(..., MSG_PEEK)` without consuming it. Some Filters (`proxy_protocol`) actually read the leading PROXY Protocol Header to restore the original client address and consume (remove) that header. Since the Listener creates Listener Filter instances for every new connection, a separate Listener Filter Chain exists per TCP connection. Representative Listener Filters provided by Envoy are as follows.

* `envoy.filters.listener.original_dst` : Restores the original destination IP and Port hidden by iptables `REDIRECT` and the like with the `getsockopt(SO_ORIGINAL_DST)` System Call. It is used in Mesh Network environments such as Istio for Envoy to obtain the actual destination information.
* `envoy.filters.listener.original_src` : Preserves the original Downstream source IP and Port with the `setsockopt(IP_TRANSPARENT)` System Call and sends them to the Upstream.
* `envoy.filters.listener.proxy_protocol` : When the PROXY Protocol is used, reads the leading PROXY Header, sets the original Client IP and Port as the Downstream IP and Port in Envoy, and removes that Header.
* `envoy.filters.listener.tls_inspector` : When TLS is used, peeks at the ClientHello to extract information such as SNI (Server Name Indication) and ALPN (Application Layer Protocol Negotiation).
* `envoy.filters.listener.http_inspector` : When TLS is not used and ALPN is therefore unavailable, peeks at the leading Bytes to detect the HTTP protocol version (whether it is HTTP/1.x or HTTP/2).

The Listener Filter Chain can be composed freely according to the Envoy Config, but generally the `original_dst` Filter for restoring the destination IP and Port is used first, and when the Proxy Protocol is used, the `proxy_protocol` Filter for removing the Proxy Header is placed second. The `tls_inspector` and `http_inspector` Filters, which simply obtain Meta information of the TCP Connection, are placed later, generally in the order of `tls_inspector` then `http_inspector`, so that the `http_inspector` Filter determines the HTTP version when the connection is not TLS.

```cpp linenos {caption="[Code 1] Listener Filter Chain Interface", linenos=table}
virtual FilterStatus onAccept(ListenerFilterCallbacks& cb) PURE;
```

[Code 1] shows the `onAccept()` Interface that a Listener Filter Chain must implement. The `ListenerFilterCallbacks` Callback, which can control the current TCP Connection inside the `onAccept()` function, is passed as a Parameter, and a `FilterStatus`, which decides whether to continue the Listener Filter Chain or pause it, is returned as the result.

### 1.3. Filter Chain Manager

After the Server Name and Application Protocol are identified through the `tls_inspector` Filter or `http_inspector` Filter of the Listener Filter Chain, the **Filter Chain Manager** creates the Downstream Transport Socket Instance and the Network Filter Chain Instance for processing the requests sent over that TCP Connection. In other words, a separate Downstream Transport Socket Instance and Network Filter Chain Instance exist per TCP Connection.

### 1.4. Downstream Transport Socket

The **Downstream Transport Socket** serves as a bridge that delivers the Traffic received from the Downstream to the Network Filter Chain. When TLS is applied, the **TLS Transport Socket** decrypts the Traffic received from the Downstream and delivers it to the Network Filter Chain, and conversely encrypts the Traffic received from the Network Filter Chain and sends it to the Downstream. Accordingly, the Network Filter Chain processes unencrypted Plain Text.

When TLS is not applied, the **Raw Buffer Transport Socket** delivers the Traffic received from the Downstream to the Network Filter Chain as is without modification, and conversely sends the Traffic received from the Network Filter Chain to the Downstream without modification.

```cpp linenos {caption="[Code 2] Downstream Transport Socket Interface", linenos=table}
virtual void onConnected() PURE;
virtual IoResult doRead(Buffer::Instance& buffer) PURE;
virtual IoResult doWrite(Buffer::Instance& buffer, bool end_stream) PURE;
virtual void closeSocket(Network::ConnectionEvent event) PURE;
```

[Code 2] shows the `onConnected()`, `doRead()`, `doWrite()`, and `closeSocket()` Interfaces that a Downstream Transport Socket must implement, and their roles are as follows.

* `onConnected()` : Called after the TCP Connection is established, and initiates the TLS Handshake when TLS is used.
* `doRead()` : Reads the Traffic received from the Downstream and delivers it to the Network Filter Chain. When TLS is used, it decrypts the Traffic and pushes up Plain Text.
* `doWrite()` : Sends the Traffic received from the Network Filter Chain to the Downstream. When TLS is used, it encrypts the Traffic and sends out Cipher Text.
* `closeSocket()` : Called when the Socket is closed, and when TLS is used, sends the `close_notify` Alert and terminates the Session.

### 1.5. Network Filter Chain

The Network Filter Chain processes the Plain Text received from the Downstream and delivers it to the Upstream HTTP Filter Chain. Most of Envoy's core features are implemented in the Network Filter Chain. Network Filters are divided into **Non-terminal Filters**, which run in the middle of the Chain, and **Terminal Filters**, which run at the end of the Chain; Non-terminal Filters can be freely reordered, but a Terminal Filter must be located at the end of the Network Filter Chain.

The main Non-terminal Filters provided by Envoy are as follows.

* `envoy.filters.network.connection_limit` : Limits the number of concurrent Downstream connections.
* `envoy.filters.network.rbac` : Performs L4-based access control. (IP/SNI/mTLS Principal)
* `envoy.filters.network.ext_authz` : Performs L4-based external authorization. (calls a gRPC authz server)
* `envoy.filters.network.local_ratelimit` : Performs L4-based Local Rate Limiting. (using a Local Token Bucket)
* `envoy.filters.network.ratelimit` : Performs L4-based Global Rate Limiting. (using a Global Token Bucket via the Rate Limit Service)
* `envoy.filters.network.wasm` : Performs custom L4 logic using WASM (WebAssembly).
* `envoy.filters.network.mysql_proxy` : Performs MySQL Protocol parsing and statistics processing. Uses the `mysql_proxy` Filter as the Terminal Filter.
* `envoy.filters.network.postgres_proxy` : Performs PostgreSQL Protocol parsing and statistics processing. Uses the `postgres_proxy` Filter as the Terminal Filter.
* `envoy.filters.network.mongo_proxy` : Performs MongoDB Protocol parsing and statistics processing. Uses the `tcp_proxy` Filter as the Terminal Filter.

The Terminal Filters provided by Envoy are as follows.

* `envoy.filters.network.tcp_proxy` : Performs TCP Proxying.
* `envoy.filters.network.redis_proxy` : Handles the Redis Protocol.
* `envoy.filters.network.kafka_broker` : Handles the Kafka Protocol.
* `envoy.filters.network.http_connection_manager` : Handles the HTTP/1.x, HTTP/2.0, and HTTP/3 Protocols.

```cpp linenos {caption="[Code 3] Network Filter Chain Interface", linenos=table}
virtual FilterStatus onNewConnection() PURE;
virtual FilterStatus onData(Buffer::Instance& data, bool end_stream) PURE;
virtual FilterStatus onWrite(Buffer::Instance& data, bool end_stream) PURE;
```

[Code 3] shows the `onNewConnection()`, `onData()`, and `onWrite()` Interfaces that a Network Filter Chain must implement, and their roles are as follows.

* `onNewConnection()` : Called once after the TCP Connection is first established. It makes initial decisions based only on the properties of the TCP Connection (concurrent connection limits, L4 access control) and returns `Continue` or `StopIteration` as the result.
* `onData()` : Called whenever request Traffic is sent from the Downstream to the Upstream. It returns `Continue` or `StopIteration` as the result.
* `onWrite()` : Called whenever response Traffic is sent from the Upstream to the Downstream. It returns `Continue` or `StopIteration` as the result.

#### 1.5.1. HTTP Connection Manager

The **HTTP Connection Manager** (HCM) operates as the Terminal Network Filter that handles the HTTP Protocol. While the preceding Network Filter Chain operates on an L4 basis, the HTTP Connection Manager operates on an **L7 basis**.

##### 1.5.1.1. HTTP Codec

When request Traffic is sent from the Downstream to the Upstream, the **HTTP Codec** decodes the Stream and separates the Header and Body so that HTTP Filters can process it in a consistent form regardless of the HTTP Protocol Version. Conversely, when response Traffic is sent from the Upstream to the Downstream, it encodes the Stream to match the HTTP Protocol Version in use by the Downstream and sends it.

##### 1.5.1.2. Downstream HTTP Filter

The **Downstream HTTP Filter** processes Traffic on an L7 basis before handing it to the Router. It can perform various functions such as authentication/authorization, Traffic limiting, and Traffic transformation. Downstream HTTP Filters can also be freely reordered, but the Router Filter must be located last.

The authentication/authorization Filters provided by Envoy are as follows. They are generally placed at the front of the Chain.

* `envoy.filters.http.jwt_authn` : JWT verification. Passes the verified claims so that later filters can use them.
* `envoy.filters.http.ext_authz` : Decides allow/deny by calling an external authorization service (gRPC/HTTP).
* `envoy.filters.http.rbac` : L7 access control. (based on path/headers/JWT Claims)
* `envoy.filters.http.oauth2` : Handles OAuth2 Login.

The Traffic limiting Filters provided by Envoy are as follows.

* `envoy.filters.http.local_ratelimit` : Performs L7-based Local Rate Limiting. (using a Local Token Bucket)
* `envoy.filters.http.ratelimit` : Performs L7-based Global Rate Limiting. (using a Global Token Bucket via the Rate Limit Service)

The Traffic transformation Filters provided by Envoy are as follows.

* `envoy.filters.http.cors` : Handles CORS.
* `envoy.filters.http.grpc_web` : gRPC-Web <-> gRPC conversion.
* `envoy.filters.http.grpc_json_transcoder` : REST/JSON <-> gRPC conversion.
* `envoy.filters.http.compressor` : Compresses response Traffic going out from the Upstream to the Downstream.
* `envoy.filters.http.decompressor` : Decompresses request Traffic coming in from the Downstream to the Upstream.
* `envoy.filters.http.header_mutation` : Adds/removes/modifies HTTP Headers.
* `envoy.filters.http.grpc_stats` : Collects gRPC statistics.

The custom logic Filters provided by Envoy are as follows.

* `envoy.filters.http.lua` : Custom logic using Lua Scripts.
* `envoy.filters.http.wasm` : L7 WASM (WebAssembly) based custom logic.
* `envoy.filters.http.fault` : Fault Injection.
* `envoy.filters.http.buffer` : Buffers the entire request.
* `envoy.filters.http.health_check` : Handles a specific path as the Health Check response.

##### 1.5.1.3. Router Filter

The **Router Filter** is the Terminal Filter located at the end of the Downstream HTTP Filters, responsible for sending the request to the actual Upstream. For a request that has passed all the preceding Filters, it determines the **Target Cluster** according to the rules of the Route Config. Then, unhealthy Hosts among the Hosts belonging to the Cluster are excluded through the **Outlier Detection** policy. Afterwards, the actual Host is selected from the remaining healthy Hosts according to the **Load Balancing** policy, and the request is delivered through the connection to that Host.

The Router Filter provides the following Load Balancing policies.

* `envoy.load_balancing_policies.round_robin` : Selects Hosts one by one in order; the most basic policy.
* `envoy.load_balancing_policies.least_request` : Prefers the Host with fewer active requests. A P2C approach that picks two at random and compares them.
* `envoy.load_balancing_policies.random` : Random selection among healthy Hosts. A simple and lightweight approach.
* `envoy.load_balancing_policies.ring_hash` : Consistent hashing. The same key (Header/Cookie/IP, etc.) goes to the same Host. For session affinity.
* `envoy.load_balancing_policies.maglev` : Lookup-Table-based consistent hashing. Faster and more uniform than `ring_hash`, but redistribution is somewhat larger when Hosts change.
* `envoy.load_balancing_policies.client_side_weighted_round_robin` : Round Robin that dynamically calculates and applies Weights from load metrics reported by Hosts.
* `envoy.load_balancing_policies.wrr_locality` : A hierarchical policy that controls distribution across Localities (Zones) with Weights and delegates the selection within a Zone to a sub-policy.

### 1.6. Upstream HTTP Filter

The Upstream HTTP Filter is a Filter that runs after the Router Filter has decided which Host the Traffic is delivered to. An Upstream HTTP Filter Instance has the characteristic that a new Instance is created by the Router Filter on every retry. The Upstream HTTP Filters provided by Envoy are as follows.

* `envoy.filters.http.header_mutation` : Adds/removes/modifies Headers based on the selected Upstream Host. Used when headers must be manipulated after it is decided which Host the Traffic is delivered to.
* `envoy.filters.http.lua` : Performs Custom Logic with Lua Scripts in the Upstream Context.
* `envoy.filters.http.wasm` : Performs WASM (WebAssembly) based Custom Logic in the Upstream Context.
* `envoy.filters.http.upstream_codec` : The Terminal Filter located at the end of the Upstream HTTP Filter Chain, responsible for Encoding/Decoding in the Upstream direction, symmetrical to the HTTP Codec inside the HTTP Connection Manager. It has the characteristic of being added automatically when omitted.

### 1.7. Upstream Transport Socket

The **Upstream Transport Socket** provides the Transport Socket in the Upstream direction, symmetrical to the Downstream Transport Socket. When TLS is applied, it encrypts the request Traffic received from the Upstream Codec Filter and sends it to the Upstream, and conversely decrypts the response Traffic received from the Upstream and pushes it up to the Upstream Codec Filter. When TLS is not applied, the Raw Buffer Transport Socket delivers the Traffic as is without modification, the same as on the Downstream side.

## 2. Envoy Configuration

```yaml linenos {caption="[Config 1] Envoy Configuration Example", linenos=table}
static_resources:

  listeners:
  # ── 1. Listener ──────────────────────────────────────────────
  - name: main_listener
    address:
      socket_address: { address: 0.0.0.0, port_value: 10000 }

    # ── 2. Listener Filter Chain (names only) ───────────────────
    listener_filters:
    - name: envoy.filters.listener.original_dst         # Restores original destination (iptables REDIRECT)
    - name: envoy.filters.listener.proxy_protocol       # Parses the leading PROXY header
    - name: envoy.filters.listener.tls_inspector        # Peeks at ClientHello to extract SNI/ALPN
    - name: envoy.filters.listener.http_inspector       # Detects HTTP version (h1/h2)

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

[Config 1] is an example showing where the components examined in Chapter 1 are defined in an actual Envoy configuration, and the numbers in the comments correspond to the components of [Figure 1]. For brevity, the detailed configuration of each Filter (`typed_config`) is omitted and only the Filter names are shown. It can be seen that the components in the Downstream direction (1-9) are defined under `listeners`, and the components in the Upstream direction (10-11) are defined under `clusters`.

`main_listener` is the Listener that accepts Downstream connections on the `10000` Port (1), and `listener_filters` contains the Listener Filter Chain composed in the recommended order described in 1.2 (2). The SNI and ALPN information extracted by the Listener Filters is compared against the `filter_chain_match` conditions of each Filter Chain defined in `filter_chains` and used to select the one Filter Chain that will handle the connection, and this selection is the role of the Filter Chain Manager (3). In the example, Chain (a) is matched by SNI and Chain (b) is matched by ALPN.

The `transport_socket` of the selected Filter Chain corresponds to the Downstream Transport Socket, and since the TLS Transport Socket is specified together with certificates, it performs TLS Termination and pushes Plain Text up to the Network Filter Chain (4). The Network Filter Chain is composed in `filters` (5), where the three Non-terminal Filters `connection_limit`, `rbac`, and `local_ratelimit` inspect the connection at the L4 level, and then the Terminal Filter, the HTTP Connection Manager, takes charge of HTTP processing (6). The `codec_type` of the HTTP Connection Manager is the setting that specifies the HTTP Codec, and since it is set to `AUTO`, the Codec matching the HTTP Version used by the Downstream is selected automatically (7).

The `http_filters` of the HTTP Connection Manager composes the Downstream HTTP Filter Chain (8), and the Router Filter located at the end determines the Target Cluster according to the rules of `route_config` (9). The `route_config` in the example is a simple configuration that routes requests of every Domain (`*`) and every path (`/`) to the `backend` Cluster, and the actual Host is selected according to the Load Balancing policy specified in the `lb_policy` of the `backend` Cluster.

The components in the Upstream direction are located in the definition of the Cluster that the Router Filter selects. The Upstream HTTP Filter Chain is composed as `http_filters` under the Cluster's `typed_extension_protocol_options`, and the `upstream_codec` Terminal Filter at the end is responsible for Encoding/Decoding in the Upstream direction (10). The Cluster's `transport_socket` corresponds to the Upstream Transport Socket, and since the TLS Transport Socket is specified, it performs TLS Origination, which encrypts the Traffic going out to the Upstream (11). In this way, the Listener's Transport Socket terminates TLS in the Downstream direction and the Cluster's Transport Socket newly starts TLS in the Upstream direction, so the Filter Chains between the two Transport Sockets always process Plain Text.

## 3. References

* Envoy Life of a Request : [https://www.envoyproxy.io/docs/envoy/latest/intro/life_of_a_request](https://www.envoyproxy.io/docs/envoy/latest/intro/life_of_a_request)
* Envoy Listener Filters : [https://www.envoyproxy.io/docs/envoy/latest/configuration/listeners/listener_filters/listener_filters](https://www.envoyproxy.io/docs/envoy/latest/configuration/listeners/listener_filters/listener_filters)
* Envoy Network Filters : [https://www.envoyproxy.io/docs/envoy/latest/configuration/listeners/network_filters/network_filters](https://www.envoyproxy.io/docs/envoy/latest/configuration/listeners/network_filters/network_filters)
* Envoy Configuration with xDS : [https://ssup2.github.io/blog-software/en/docs/theory-analysis/envoy-configuration-xds/](https://ssup2.github.io/blog-software/en/docs/theory-analysis/envoy-configuration-xds/)

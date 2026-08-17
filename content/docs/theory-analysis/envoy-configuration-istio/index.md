---
title: "Envoy Configuration with Istio"
---

Istio의 CR (Custom Resource)에 따른 Envoy의 설정 변경을 정리한다.

## 1. Envoy Configuration with Istio

```yaml {caption="[Config 1] Experiment Environment (server-a, server-b, server-c, client)", linenos=table}
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

실험 환경은 kind Cluster + Istio 1.24이며, `istio-system` Namespace에는 istiod와 istio-ingressgateway가 설치되어 있다. [Config 1]은 실험에 사용하는 Workload를 나타내고 있다. `default` Namespace에 `istio-injection=enabled` Label이 설정되어 있어 모든 Pod에 istio-proxy Sidecar가 주입된 상태로 동작한다. 각 Workload의 역할은 다음과 같다.

* **`server-a`, `server-b` Pod/Service** : 요청을 받는 서버이며, 각각 `8080` Port를 노출한다. 같은 Port를 노출하는 Service가 여러 개일 때의 설정을 확인하기 위해 두 개를 배치했다.
* **`server-c` Pod/Service** : 요청을 받는 서버이며, `9090` Port를 노출한다. 다른 Port를 노출하는 Service가 있을 때의 설정을 확인하기 위해 배치했다.
* **`client` Pod** : 요청을 보내는 Client 역할이다.
* **istio-ingressgateway Pod** : Gateway CR 실험의 관찰 대상이다.

1.2의 CR 실험은 서버 중에서는 `server-a` Pod만을 대상으로 적용하며, Inbound 설정을 변경하는 CR(PeerAuthentication, AuthorizationPolicy 등)은 `server-a` Pod에서, Outbound 설정을 변경하는 CR(VirtualService, DestinationRule 등)은 `client` Pod에서 변경 내역을 관찰한다.

### 1.1. Default Configuration

Istio CR을 하나도 적용하지 않은 상태에서도, istiod는 Kubernetes의 Service와 Endpoint 정보만으로 Mesh 전체 통신에 필요한 기본 설정을 만들어 모든 Sidecar에 배포한다. 이 절에서는 `client` Pod의 Envoy Configuration의 Outbound 설정과 `server-a` Pod의 Envoy Configuration의 Inbound 설정을 가져와 기본 설정을 살펴본다.

#### 1.1.1. Outbound Configuration

```yaml {caption="[Config 2] client Pod의 Default Outbound Configuration", linenos=table}
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
  filter_chains:
  - filters:
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

[Config 2]는 `client` Pod의 Envoy Configuration의 Outbound 설정을 나타내고 있다. App Container가 보내는 모든 요청은 iptables에 의해 `15001` Port의 virtualOutbound Listener로 Redirect된다. [Config 2]에 있는 각 Listener의 역할은 다음과 같다.

* **virtualOutbound Listener** : 모든 Outbound 요청의 진입점이며, 요청을 직접 처리하지 않고 세 갈래로 분기한다. 기본 경로는 `use_original_dst` 설정에 따라 요청의 원래 목적지 Port와 일치하는 `0.0.0.0_<Port>` Listener로 넘기는 것이다. 원래 목적지가 `15001` Port 자체인 요청은 `virtualOutbound-blackhole` Filter Chain이 BlackHoleCluster로 보내 차단하고, 일치하는 Listener가 없는 요청은 `virtualOutbound-catchall-tcp` Filter Chain이 PassthroughCluster로 보낸다.
* **`0.0.0.0_8080`, `0.0.0.0_9090` Listener** : Port별 Outbound Listener이며, 해당 Pod 자신이 여는 Port가 아니라 **Mesh에 존재하는 Service의 Port** 기준으로 생성된다. istiod는 어떤 Pod가 어디로 요청을 보낼지 미리 알 수 없으므로 Mesh의 모든 Service Port마다 Outbound Listener를 만들어 모든 Sidecar에 배포하며, 아무 Port도 열지 않는 `client` Pod에 이 Listener들이 존재하는 것도 `client` 자신과는 무관하게 `server-a`, `server-b` Service가 `8080` Port를, `server-c` Service가 `9090` Port를 노출하고 있기 때문이다. 같은 Port를 노출하는 Service가 몇 개든 Port당 Listener는 하나이다. tls_inspector와 http_inspector로 Protocol을 판별하고, HTTP 요청이면 HTTP Connection Manager가 RDS로 받은 같은 이름의 Route Table(`"8080"`, `"9090"`)을 참조한다.

Route Table에는 해당 Port를 노출하는 Mesh의 Service마다 Virtual Host가 하나씩 생성되며, `8080` Port는 `server-a`, `server-b` 두 Service가 함께 노출하므로 `"8080"` Route Table에 Virtual Host가 두 개 생긴다. `0.0.0.0_8080` Listener는 목적지 Service가 무엇이든 `8080` Port로 향하는 요청을 모두 받으므로, 요청을 Service별로 구분하는 것은 Listener가 아니라 Route Table의 Domain 매칭이다. 각 Virtual Host의 `domains`에는 해당 Service의 모든 이름 축약형(`server-a`, `server-a.default`, `server-a.default.svc`, FQDN)과 Service의 ClusterIP가 나열되어 있어, App이 어떤 형태로 호출하든 요청의 Host Header가 해당 Service의 Virtual Host로 매칭된다. `ignore_port_in_host_matching` 설정에 의해 Host Header에 붙는 `:8080` 같은 Port 표기는 매칭 전에 제거된다.

매칭된 Virtual Host에는 istiod가 만든 기본 Route(`name: default`)가 들어 있으며, 이 Route가 요청을 각 Service의 Cluster로 라우팅한다. Host Header가 `server-a`인 요청은 `outbound|8080||server-a.default.svc.cluster.local` Cluster로, `server-b`인 요청은 `outbound|8080||server-b.default.svc.cluster.local` Cluster로 전달되어, 같은 Listener로 들어온 요청이 여기서 서로 다른 Service로 갈라진다. 어느 Virtual Host에도 매칭되지 않는 요청은 Catch-all인 `allow_any` Virtual Host를 통해 PassthroughCluster로 전달된다.

HTTP Connection Manager에는 기본 HTTP Filter들이 다음의 순서대로 들어 있다.

* **`istio.metadata_exchange`** : 요청 Header를 통해 Peer의 메타데이터(Workload 이름, Namespace 등)를 교환한다.
* **`envoy.filters.http.grpc_stats`** : gRPC 요청일 때 Message 수 등의 gRPC 통계를 생성한다.
* **`istio.alpn`** : Upstream이 Sidecar mTLS 대상일 때 Istio 전용 ALPN을 광고한다 (1.2.10에서 Inbound의 `application_protocols` Match와 짝을 이루는 부분이다).
* **`envoy.filters.http.fault`** : VirtualService의 fault 설정이 반영되는 자리이다.
* **`envoy.filters.http.cors`** : VirtualService의 corsPolicy 설정이 반영되는 자리이다.
* **`istio.stats`** : Istio 표준 Metrics를 생성한다.
* **`envoy.filters.http.router`** : Route Table을 참조해 실제 라우팅을 수행하는 마지막 Filter이다.

[Config 2]에 있는 각 Cluster의 역할은 다음과 같다.

* **`outbound|8080||server-a...`, `outbound|8080||server-b...`, `outbound|9090||server-c...` Cluster** : Mesh의 Service Port마다 `outbound|<Port>||<Host>` 이름으로 생성되는 `EDS` Type Cluster이며, Endpoint 목록을 EDS로 전달받는다. 각 Route Table의 기본 Route(`name: default`)가 라우팅하는 대상이다. `0.0.0.0_8080` Listener와 `"8080"` Route Table을 공유하는 `server-a`, `server-b`도 Cluster는 각각 따로 가지는데, Listener나 Route Table과 달리 Cluster는 Port가 아니라 Service 단위이기 때문이다.
* **BlackHoleCluster** : Endpoint가 하나도 없는 `STATIC` Type Cluster라 연결 시도가 즉시 실패하며, virtualOutbound Listener가 원래 목적지가 `15001` Port 자체인 요청을 차단하는 데 쓰인다.
* **PassthroughCluster** : `ORIGINAL_DST` Type Cluster라 별도의 Endpoint 없이 요청의 원래 목적지 IP:Port로 그대로 연결하며, virtualOutbound Listener의 `virtualOutbound-catchall-tcp` Filter Chain과 Route Table의 `allow_any` Virtual Host가 라우팅하는 대상이다.

이 Outbound 설정은 특정 Pod에 종속되지 않으며, Mesh의 모든 Sidecar가 동일하게 전달받는다.

#### 1.1.2. Inbound Configuration

```yaml {caption="[Config 3] Default Inbound Configuration (server-a Pod 발췌)", linenos=table}
# LDS: virtualInbound - entry point for all inbound traffic (iptables redirect)
- '@type': type.googleapis.com/envoy.config.listener.v3.Listener
  address:
    socket_address:
      address: 0.0.0.0
      port_value: 15006
  filter_chains:
  ...
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
    transport_socket:
      name: envoy.transport_sockets.tls
      typed_config:
        ...
        require_client_certificate: true
  - filter_chain_match:                # Plaintext Chain
      destination_port: 8080
      transport_protocol: raw_buffer
    ...
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
```

다른 Pod로부터 들어오는 요청은 iptables에 의해 `15006` Port의 virtualInbound Listener로 Redirect된다. virtualInbound는 Service가 노출하는 Port마다 `destination_port`로 매칭되는 Filter Chain을 가지며, 기본값인 `PERMISSIVE` Mode에서는 mTLS용 `tls` Chain과 Plaintext용 `raw_buffer` Chain이 쌍으로 존재한다 (1.2.10에서 자세히 다룬다).

Filter 구성은 Outbound와 유사하지만, Chain 앞단에 TCP 수준에서 메타데이터를 교환하는 `istio.metadata_exchange` Network Filter가 추가로 있고, Upstream ALPN을 광고할 필요가 없으므로 `istio.alpn`은 없다. 기본 상태의 HTTP Filter는 이것이 전부이며, `jwt_authn`(RequestAuthentication), `rbac`(AuthorizationPolicy), Wasm Filter(WasmPlugin) 등은 1.2에서 해당 CR을 적용할 때 이 Filter Chain 사이에 삽입된다.

Inbound Route는 Outbound와 달리 RDS를 사용하지 않고 HTTP Connection Manager에 `route_config`로 Inline되어 있으며, 모든 요청을 `inbound|8080||` Cluster로 보내는 단순한 구조이다. Route가 항상 하나뿐이므로 동적으로 갱신할 필요가 없기 때문이다.

`inbound|8080||` Cluster는 `ORIGINAL_DST` Type으로 요청의 원래 목적지인 App Container의 `8080` Port로 전달한다. 이때 `127.0.0.6`을 Source 주소로 사용하는데, iptables가 이 주소에서 나온 Traffic을 다시 Outbound로 Redirect하지 않도록 하는 Loop 방지 장치이다.

### 1.2. Envoy Configuration with Istio and Kubernetes Resources

1.1의 기본 설정을 기준으로, Istio의 각 CR (Custom Resource)이 Envoy 설정에 어떻게 반영되는지 살펴본다. 각 CR을 적용하기 전후의 `istioctl proxy-config all <pod> -o yaml` 출력을 비교하여, Envoy Config Dump의 어느 부분이 변경되는지 앞뒤 Context와 함께 diff로 기록한다. 변경과 무관한 부분은 `...`으로 표기한다.

#### 1.2.1. Gateway

```yaml {caption="[Config 4] istio-ingressgateway Service Port Mapping (발췌)", linenos=table}
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

```yaml {caption="[Config 5] Gateway Example", linenos=table}
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

```diff {caption="[Diff 5] Gateway 적용 전후 istio-ingressgateway Pod의 proxy-config"}
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

Gateway는 Sidecar가 아닌 **selector로 선택된 Gateway Pod(`istio-ingressgateway`)의 Envoy에 반영**된다. Gateway CR에는 `80` Port를 선언했지만 Listener는 `0.0.0.0_8080`에 생성되는데, istiod가 `istio-ingressgateway` Service의 Port 매핑([Config 4]의 `80` Port → `8080` targetPort)을 따라 실제 Traffic을 받는 targetPort에 Listener를 생성하기 때문이다. Listener와 Route 이름(`http.8080`)은 실제 바인딩 포트 기준이고, Virtual Host 이름(`blackhole:80`)은 Gateway CR에 선언된 Server Port 기준이다. 아직 이 Gateway에 연결된 VirtualService가 없으므로 모든 요청은 `blackhole` Virtual Host에 의해 `404`로 처리된다.

#### 1.2.2. VirtualService

```yaml {caption="[Config 6] VirtualService Example", linenos=table}
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

```diff {caption="[Diff 6] VirtualService 적용 전후 client Pod의 proxy-config"}
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

VirtualService는 **Sidecar의 Outbound Route(RDS)에 반영**된다. 기존에 `/*` 하나였던 `server-a` Virtual Host의 Route Entry가 `/api*` Match와 Catch-all 두 개로 늘어나고, `timeout: 3s`가 Route에 반영된다. 사라진 `name: default`는 VirtualService가 없을 때 istiod가 자동 생성하는 기본 Route에 붙이는 이름이며, VirtualService 유래 Route는 `spec.http[].name`을 지정하지 않는 한 이름 없이 생성된다. 대신 각 Route Entry의 `metadata.filter_metadata.istio.config`에 이 설정을 만든 VirtualService의 경로가 기록되어 설정의 출처를 추적할 수 있다. 같은 `"8080"` Route Table을 공유하는 `server-b` Virtual Host는 변하지 않으며, Cluster나 Listener도 변하지 않는다.

```yaml {caption="[Config 7] VirtualService with Gateway Example", linenos=table}
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

```diff {caption="[Diff 7] Gateway에 VirtualService 연결 전후 istio-ingressgateway Pod의 proxy-config"}
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

[Config 7]은 `gateways` 필드로 [Config 5]의 Gateway에 연결한 VirtualService 예시이다. 이 경우 Sidecar가 아닌 **Gateway Pod(istio-ingressgateway)의 Route에 반영**되며, [Diff 5]에서 `blackhole` Virtual Host뿐이었던 `http.8080` Route Table이 `server-a.dev` Virtual Host로 교체되어 `server-a` Cluster로 라우팅되기 시작한다. Gateway Pod도 Sidecar와 동일하게 Mesh 전체 서비스의 Cluster 설정을 받고 있으므로, 라우팅 대상인 `outbound|8080||server-a...` Cluster는 이미 존재한다.

#### 1.2.3. DestinationRule

```yaml {caption="[Config 8] DestinationRule Example", linenos=table}
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

```diff {caption="[Diff 8] DestinationRule 적용 전후 client Pod의 proxy-config"}
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

DestinationRule은 **Sidecar의 Outbound Cluster(CDS)에 반영**된다. `host`로 지정한 `server-a` Cluster의 `lb_policy`가 기본값 `LEAST_REQUEST`에서 `RANDOM`으로 변경되고, Subset을 정의하면 Subset마다 별도의 Cluster(`outbound|8080|v1|...`)가 추가로 생성된다. `server-b`, `server-c` Cluster와 Route는 변하지 않으므로, Subset Cluster로 Traffic을 보내려면 VirtualService에서 Subset을 지정해야 한다.

#### 1.2.4. ServiceEntry

```yaml {caption="[Config 9] ServiceEntry Example", linenos=table}
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

```diff {caption="[Diff 9] ServiceEntry 적용 전후 client Pod의 proxy-config"}
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

ServiceEntry는 외부 서비스를 Mesh의 Service Registry에 등록하며, **Sidecar의 Outbound Cluster와 Route에 반영**된다. `external.example.com` Cluster가 `STRICT_DNS` Type으로 생성되고, `80` Port Route Table에 해당 Host의 Virtual Host가 추가된다. Kubernetes Service의 Cluster가 `EDS` Type으로 istiod로부터 Endpoint 목록을 전달받는 것과 달리, `STRICT_DNS` Type Cluster는 Envoy가 직접 DNS를 조회하여 Endpoint를 얻는다.

적용 전에는 Mesh에 등록되지 않은 외부 Host로 향하는 요청이 Catch-all인 `allow_any` Virtual Host에 매칭되어 `PassthroughCluster`로 전달되었지만, 적용 후에는 앞에 추가된 전용 Virtual Host가 먼저 매칭되어 전용 Cluster를 통해 처리된다. `allow_any` Virtual Host 자체는 변하지 않고 그대로 남는다.

#### 1.2.5. Sidecar

```yaml {caption="[Config 10] Sidecar Example", linenos=table}
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

```diff {caption="[Diff 10] Sidecar 적용 전후 client Pod의 proxy-config"}
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

Sidecar CR은 Envoy에 새로운 설정을 추가하는 것이 아니라 **Sidecar가 받는 설정의 범위를 제한**한다. 기본적으로 모든 Sidecar는 Mesh 전체 서비스의 Cluster, Listener, Route를 받는데, egress hosts를 `server-a`로 제한하면 `server-b`, `server-c`를 포함한 나머지 모든 서비스의 Outbound 설정이 제거된다. 이때 설정의 단위에 따라 제거되는 모습이 다르다. Cluster는 Service 단위라 `server-a`를 제외한 모든 Cluster가 제거되고, `server-c`만 노출하던 `9090` Port는 Listener 자체가 제거되며, `server-a`와 Port를 공유하던 `server-b`는 `0.0.0.0_8080` Listener는 남고 `"8080"` Route Table의 Virtual Host만 제거된다. egress만 제한하는 예시이므로 Inbound 설정(virtualInbound Listener)은 변하지 않는다. 대규모 Cluster에서 Sidecar의 Memory 사용량과 xDS Push 비용을 줄이는 핵심 수단이다.

#### 1.2.6. EnvoyFilter

```yaml {caption="[Config 11] EnvoyFilter Example", linenos=table}
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

```diff {caption="[Diff 11] EnvoyFilter 적용 전후 server-a Pod의 proxy-config (virtualInbound Listener)"}
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

EnvoyFilter는 istiod가 생성한 Envoy 설정을 **직접 Patch하는 CR**로, 다른 CR이 추상화하지 않는 Envoy 기능에 접근할 수 있다. 예시는 `server-a` Sidecar의 Inbound HTTP Filter Chain에 Lua Filter를 삽입하여 응답 Header를 추가한다. `context: SIDECAR_INBOUND`는 Patch 대상을 Sidecar의 Inbound 설정으로 한정하며, Outbound 설정은 `SIDECAR_OUTBOUND`, Gateway Pod는 `GATEWAY`로 지정한다. `applyTo: HTTP_FILTER`는 HTTP Connection Manager의 `http_filters` 배열이 Patch 대상임을 의미한다.

`operation: INSERT_BEFORE`는 match의 `subFilter`로 지정한 기준 Filter 앞에 새 Filter를 삽입하는 연산이다. [Diff 11]에서 Lua Filter가 기준 Filter인 `envoy.filters.http.router` 바로 앞에 추가된 것을 확인할 수 있으며, `subFilter`를 지정하지 않으면 배열의 맨 앞에 삽입된다. 이처럼 EnvoyFilter는 Envoy 내부 구현에 직접 의존하므로 Istio Upgrade 시 깨질 수 있어 주의가 필요하다.

#### 1.2.7. WorkloadEntry

```yaml {caption="[Config 12] WorkloadEntry Example", linenos=table}
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

```diff {caption="[Diff 12] WorkloadEntry 적용 전후 client Pod의 proxy-config"}
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

WorkloadEntry는 **Kubernetes Cluster 외부에서 동작하는 Workload를 Pod와 동일한 방식으로 Mesh에 등록**하는 CR이다. 대표적인 대상은 Cluster 밖의 VM에서 동작하는 Server Process이다. 단독으로는 효과가 없고, workloadSelector로 이를 선택하는 ServiceEntry와 함께 사용해야 한다. Label이 매칭되면 WorkloadEntry의 address가 해당 Outbound Cluster의 Endpoint(EDS)로 등록되어, Pod의 Endpoint와 동일한 방식으로 LB 대상이 된다.

#### 1.2.8. WorkloadGroup

```yaml {caption="[Config 13] WorkloadGroup Example", linenos=table}
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

WorkloadGroup은 적용해도 **Envoy 설정에 아무 변화가 없다**. WorkloadGroup은 그 자체로 Workload를 Mesh에 등록하는 리소스가 아니라, 이후 생성될 WorkloadEntry의 Template이기 때문이다.

Kubernetes Cluster 외부에서 istio-agent를 실행하면 istio-agent가 istiod의 xDS Server에 접속하는데, 이때 자신이 속한 WorkloadGroup과 자신의 address를 함께 알린다. istiod는 해당 WorkloadGroup의 `template`(serviceAccount, network 등)에 전달받은 address를 채운 WorkloadEntry 오브젝트를 Kubernetes API Server에 생성하며, istio-agent와의 연결이 끊어진 뒤 유예 시간 동안 재연결이 없으면 자동으로 삭제한다. 이렇게 생성된 WorkloadEntry가 앞 절의 WorkloadEntry와 동일한 방식으로 Cluster의 Endpoint에 반영되므로, Envoy 설정의 변화는 이 시점에 비로소 나타난다.

#### 1.2.9. ProxyConfig

```yaml {caption="[Config 14] ProxyConfig Example", linenos=table}
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

ProxyConfig도 적용 시점에는 **동작 중인 Envoy에 변화가 없다**. `concurrency` 같은 설정은 xDS로 동적 전달되는 것이 아니라 Envoy Bootstrap Configuration에 속하기 때문이다. Sidecar Injection 시점에 주입되므로, Pod를 재생성해야 반영된다.

#### 1.2.10. PeerAuthentication

```yaml {caption="[Config 15] PeerAuthentication Example", linenos=table}
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

```diff {caption="[Diff 15] PeerAuthentication 적용 전후 server-a Pod의 proxy-config (virtualInbound Listener)"}
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
-          ... (inbound|8080|| Plaintext Chain 전체 제거)
```

PeerAuthentication은 **selector로 선택된 Workload의 Inbound `virtualInbound` Listener Filter Chain에 반영**된다. 기본값인 `PERMISSIVE` Mode에서는 Port마다 mTLS용 `tls` Chain과 Plaintext용 `raw_buffer` Chain이 함께 존재하지만, `STRICT` Mode로 변경하면 `raw_buffer` Chain이 모두 제거되어 mTLS가 아닌 연결은 수립 자체가 불가능해진다.

`tls` Chain의 `application_protocols` Match에 나열된 `istio`, `istio-peer-exchange`, `istio-http/1.1`, `istio-h2`는 Istio 전용 ALPN 값으로, 보내는 쪽 Sidecar가 mTLS Handshake 시 광고하여 Sidecar가 만든 mTLS 연결임을 알린다. `PERMISSIVE` Mode에서는 App이 자체적으로 TLS를 처리하는 연결도 같은 Port로 들어올 수 있으므로, 이 ALPN 조건으로 선별한 Sidecar mTLS 연결만 Envoy가 TLS Termination을 수행하여 복호화하고, 그 외의 TLS 연결은 암호화된 상태 그대로 App에 전달한다.

`STRICT` Mode에서는 이 Match 조건도 사라지는데, Plaintext Chain이 제거되어 더 이상 구분할 대상이 없고, Istio mTLS가 아닌 연결은 어차피 Client 인증서 검증에서 실패하기 때문이다.

#### 1.2.11. RequestAuthentication

```yaml {caption="[Config 16] RequestAuthentication Example", linenos=table}
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

```diff {caption="[Diff 16] RequestAuthentication 적용 전후 server-a Pod의 proxy-config (virtualInbound Listener)"}
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

RequestAuthentication은 **Sidecar의 Inbound HTTP Filter Chain에 `jwt_authn` Filter를 추가**한다. CR에는 `jwksUri`를 지정했지만 Envoy 설정에는 `local_jwks`로 반영된다. istiod가 `jwksUri`의 JWKS(공개키 목록)를 대신 가져온 뒤, 키 내용을 `jwt_authn` Filter 설정의 `inline_string` 값에 그대로 담아 xDS로 배포하기 때문이다. 

덕분에 각 Envoy는 외부 JWKS Endpoint에 직접 접근할 필요 없이 설정에 포함된 키로 바로 JWT를 검증할 수 있으며, 키 갱신도 istiod가 주기적으로 다시 가져와 xDS Push로 반영한다. 이 Filter는 요청의 JWT를 검증하여 유효하지 않으면 401로 거부하고, 유효하면 Claim 정보를 뒤의 Filter(AuthorizationPolicy의 RBAC 등)에서 사용할 수 있게 한다. `allow_missing` Rule에 의해 JWT가 없는 요청은 통과되므로, 미인증 요청 차단은 AuthorizationPolicy와 조합해야 한다.

#### 1.2.12. AuthorizationPolicy

```yaml {caption="[Config 17] AuthorizationPolicy Example", linenos=table}
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

```diff {caption="[Diff 17] AuthorizationPolicy 적용 전후 server-a Pod의 proxy-config (virtualInbound Listener)"}
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

AuthorizationPolicy는 **Sidecar의 Inbound HTTP Filter Chain에 `rbac` Filter를 추가**한다. 예시는 `/admin` 경로 요청을 거부하는 DENY 정책으로, RBAC Filter의 Rule로 변환되어 매칭되는 요청은 403으로 거부된다. L7 속성(경로, Method 등)을 사용하는 정책이므로 HTTP Filter로 구현되며, TCP Port에는 별도 Network Filter가 사용된다.

#### 1.2.13. Telemetry

```yaml {caption="[Config 18] Telemetry Example", linenos=table}
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

```diff {caption="[Diff 18] Telemetry 적용 전후 server-a Pod의 proxy-config (모든 Listener의 Access Logger 교체)"}
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

Telemetry는 **Inbound/Outbound 구분 없이 모든 Listener와 HTTP Connection Manager의 Access Logger, Tracing, Stats 설정에 반영**된다. 예시 환경은 meshConfig의 `accessLogFile`로 전역 File Logger(`/dev/stdout`)가 켜져 있는 상태인데, Telemetry로 `otel` Provider(meshConfig의 extensionProviders에 정의된 OpenTelemetry ALS)를 지정하면 selector로 선택된 `server-a` Workload의 File Logger가 모두 OpenTelemetry Logger로 교체된다. Provider가 가리키는 Service가 Cluster에 존재해야 반영된다는 점에 주의한다.

#### 1.2.14. WasmPlugin

```yaml {caption="[Config 19] WasmPlugin Example", linenos=table}
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

```diff {caption="[Diff 19] WasmPlugin 적용 전후 server-a Pod의 proxy-config (ECDS, virtualInbound Listener)"}
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

WasmPlugin은 **Inbound HTTP Filter Chain에 Wasm Filter를 추가**하며, Filter의 실제 설정은 다른 Filter와 달리 ECDS (Extension Config Discovery Service)를 통해 별도 Resource로 전달된다. Wasm 모듈은 pilot-agent가 OCI Registry에서 대신 다운로드하여 로컬 경로로 변환 후 Envoy에 전달한다.

`phase`는 Filter Chain 내 삽입 위치를 단계로 지정하는 필드이다. `AUTHN`은 Istio 인증 Filter 앞, `AUTHZ`는 인증 Filter 뒤이자 인가 Filter(`rbac`) 앞, `STATS`는 인가 Filter 뒤이자 Stats Filter(`istio.stats`) 앞에 삽입되며, 지정하지 않으면 Filter Chain의 끝(Router Filter 앞)에 삽입된다. 예시는 `phase: AUTHN`이므로 [Diff 19]에서 항상 맨 앞에 위치하는 `istio.metadata_exchange` 바로 뒤에 삽입되었다. EnvoyFilter의 `subFilter`처럼 특정 Filter 이름에 의존하지 않고 단계로 위치를 지정하므로, Istio Upgrade에 더 안전한 확장 수단이다.

## 2. 참조

---
title: "Envoy with Istio"
---

## 1. Envoy as Sidecar Proxy with Istio

{{< figure caption="[Figure 1] Sidecar Proxy with Istio" src="images/envoy-istio-sidecar.png" width="700px" >}}

[Figure 1]은 Istio 환경에서 Envoy가 Sidecar Proxy로 동작할 때 App Pod 내부의 구성 요소와 Traffic 흐름을 나타내고 있다. App Pod에는 App Container와 함께 istio-proxy Container가 배치되며, istio-proxy Container 안에서는 pilot-agent와 Envoy 두 Process가 동작한다. Pod 시작 시 istio-init Container가 설정한 iptables Rule에 의해 App Container의 모든 Traffic은 Envoy를 경유한다. 주요 흐름은 다음과 같다.

* **xDS 설정 전달 (하늘색)** : istiod의 `15012` Port xDS Server는 LDS, RDS, CDS, EDS, SDS, NDS 설정을 하나의 ADS Stream으로 pilot-agent에 전달한다. pilot-agent는 받은 설정을 `unix:///etc/istio/proxy/XDS` Socket을 통해 다시 ADS로 Envoy에 중계하며, Workload 인증서는 `unix:///var/run/secrets/workload-spiffe-uds/socket` Socket을 통해 SDS로 전달한다. 인증서를 별도의 SDS Socket으로 분리하여 전달하는 이유는 Private Key와 같은 민감 정보를 일반 설정과 분리하기 위함이다. 즉 Envoy는 istiod와 직접 통신하지 않으며, pilot-agent가 xDS Proxy 역할을 수행한다.
* **Outbound Traffic (주황색)** : App Container가 외부로 보내는 요청은 iptables에 의해 Envoy의 `15001` Port로 Redirect된 뒤, Envoy의 라우팅을 거쳐 상대 App Pod로 전달된다.
* **Inbound Traffic (노란색)** : 다른 App Pod로부터 들어오는 요청은 iptables에 의해 Envoy의 `15006` Port로 Redirect된 뒤, App Container의 `8080` Port로 전달된다.
* **DNS Lookup (초록색)** : DNS Capture가 활성화된 경우 App Container의 DNS 질의는 pilot-agent의 `15053` Port DNS Proxy로 Redirect되어 처리된다. 이때 DNS Proxy가 사용하는 Hostname 정보가 istiod로부터 NDS를 통해 전달되며, NDS가 Envoy로 중계되지 않고 pilot-agent에서 소비되는 이유이다.
* **Metrics 수집 (파란색)** : Prometheus Server는 pilot-agent의 `15020` Port `/stats/prometheus` 하나만 Scrape한다. pilot-agent는 Envoy의 `15090` Port `/stats/prometheus`와 App Container의 `8080` Port `/metrics`를 함께 수집하여 병합된 Metrics를 제공한다.
* **Health Check (빨간색)** : kubelet은 Envoy의 `15021` Port `/healthz/ready`로 istio-proxy Container의 Health Check를 수행하며, Envoy는 이 요청을 pilot-agent의 `15020` Port `/healthz/ready`로 전달한다.
* **Envoy Admin (검정색)** : istioctl은 Envoy의 `15000` Port Admin Interface에 접근하여 Envoy에 적용된 설정과 상태를 확인한다. `istioctl proxy-config` 명령어가 이 경로를 통해 Listener, Route, Cluster 등의 설정을 조회하는 대표적인 예이다.

이처럼 Envoy가 istiod와 직접 통신하지 않고 pilot-agent를 xDS Proxy로 경유하는 이유는 다음과 같다.

* **인증 위임** : Envoy가 istiod와 mTLS로 통신하려면 인증서가 필요하지만, 그 인증서는 다시 istiod로부터 발급받아야 하는 순환 문제가 존재한다. pilot-agent가 Pod의 Service Account Token을 이용해 CSR (Certificate Signing Request)을 생성하고 istiod CA로부터 인증서를 발급받은 뒤 SDS Socket으로 Envoy에 공급하는 방식으로 이 문제를 해결하며, 인증서 갱신도 pilot-agent가 담당하므로 Envoy는 인증서 수명 주기를 신경 쓰지 않아도 된다.
* **xDS 변조** : pilot-agent는 istiod가 내려준 xDS 설정을 단순히 중계하는 것이 아니라 중간에서 변조할 수 있다. 예를 들어 istiod가 "원격 저장소에서 Wasm 필터 모듈을 다운로드해서 사용하라"는 설정을 내려주면, pilot-agent가 모듈을 대신 다운로드해 두고 설정 안의 원격 주소를 로컬 파일 경로로 바꿔서 Envoy에 전달한다. Envoy는 로컬 파일만 읽으면 되므로, 저장소 인증이나 다운로드 실패 처리 같은 복잡한 일은 모두 pilot-agent가 담당한다.
* **istiod 장애 대응** : pilot-agent는 istiod로부터 받은 마지막 설정을 캐시하고 있어, istiod 장애 중에도 Envoy가 재연결하면 캐시된 설정으로 응답할 수 있다. Envoy 입장에서 xDS Server는 항상 로컬의 pilot-agent이므로, Control Plane 장애가 Data Plane의 동작에 바로 전파되지 않는다.

## 2. Envoy as Ingress/Egress Gateway with Istio

## 3. Envoy Configuration with Istio and Kubernetes Resources 

```yaml {caption="[Config 1] Experiment Environment (mock-server, shell)", linenos=table}
# kubectl label namespace default istio-injection=enabled
apiVersion: v1
kind: Pod
metadata:
  name: mock-server
  namespace: default
  labels:
    app: mock-server
spec:
  containers:
  - name: mock-server
    image: ghcr.io/ssup2/mock-go-server:commit-f8ad4477
    ports:
    - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: mock-server
  namespace: default
spec:
  selector:
    app: mock-server
  ports:
  - name: http
    port: 8080
    targetPort: 8080
---
apiVersion: v1
kind: Pod
metadata:
  name: shell
  namespace: default
  labels:
    app: shell
spec:
  containers:
  - name: shell
    image: nicolaka/netshoot
    command: ["sleep", "infinity"]
```

실험 환경은 kind Cluster + Istio 1.24이며, istio-system Namespace에는 istiod와 istio-ingressgateway가 설치되어 있다. [Config 1]은 실험에 사용하는 Workload를 나타내고 있다. `default` Namespace에 `istio-injection=enabled` Label이 설정되어 있어 두 Pod 모두 istio-proxy Sidecar가 주입된 상태로 동작한다. 각 Workload의 역할은 다음과 같다.

* **`mock-server` Pod/Service** : 요청을 받는 대상 서버이며, `8080` Port를 노출한다. Inbound 설정을 변경하는 CR(PeerAuthentication, AuthorizationPolicy 등)의 관찰 대상이다.
* **`shell` Pod** : 요청을 보내는 Client 역할이며, Outbound 설정을 변경하는 CR(VirtualService, DestinationRule 등)의 관찰 대상이다.
* **istio-ingressgateway Pod** : Gateway CR 실험의 관찰 대상이다.

이러한 실험 환경에서 Istio의 각 CR (Custom Resource)이 Envoy 설정에 어떻게 반영되는지 살펴본다. 각 CR을 적용하기 전후의 `istioctl proxy-config all <pod> -o yaml` 출력을 비교하여, Envoy Config Dump의 어느 부분이 변경되는지 앞뒤 Context와 함께 diff로 기록한다. 변경과 무관한 부분은 `...`으로 표기한다.

### 3.1. Gateway

```yaml {caption="[Config 2] Gateway Example", linenos=table}
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: mock-server
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
    - "mock-server.dev"
```

```diff {caption="[Diff 2] Gateway 적용 전후 istio-ingressgateway Pod의 proxy-config"}
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

Gateway는 Sidecar가 아닌 **selector로 선택된 Gateway Pod(istio-ingressgateway)의 Envoy에 반영**된다. Gateway CR에는 `80` Port를 선언했지만 Listener는 `0.0.0.0_8080`에 생성되는데, istiod가 `istio-ingressgateway` Service의 Port 매핑(`80` Port → `8080` targetPort)을 따라 실제 Traffic을 받는 targetPort에 Listener를 생성하기 때문이다. Listener와 Route 이름(`http.8080`)은 실제 바인딩 포트 기준이고, Virtual Host 이름(`blackhole:80`)은 Gateway CR에 선언된 Server Port 기준이다. 아직 이 Gateway에 연결된 VirtualService가 없으므로 모든 요청은 `blackhole` Virtual Host에 의해 `404`로 처리된다.

### 3.2. VirtualService

```yaml {caption="[Config 3] VirtualService Example", linenos=table}
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: mock-server
  namespace: default
spec:
  hosts:
  - mock-server
  http:
  - match:
    - uri:
        prefix: /api
    route:
    - destination:
        host: mock-server
        port:
          number: 8080
    timeout: 3s
  - route:
    - destination:
        host: mock-server
        port:
          number: 8080
```

```diff {caption="[Diff 3] VirtualService 적용 전후 shell Pod의 proxy-config"}
 - '@type': type.googleapis.com/envoy.admin.v3.RoutesConfigDump
   dynamic_route_configs:
   - route_config:
       '@type': type.googleapis.com/envoy.config.route.v3.RouteConfiguration
       name: "8080"
       virtual_hosts:
       ...
       - domains:
         - mock-server
         - mock-server.default.svc.cluster.local
         name: mock-server.default.svc.cluster.local:8080
         routes:
+        - decorator:
+            operation: mock-server.default.svc.cluster.local:8080/api*
+          match:
+            case_sensitive: true
+            prefix: /api
+          metadata:
+            filter_metadata:
+              istio:
+                config: /apis/networking.istio.io/v1/namespaces/default/virtual-service/mock-server
+          route:
+            cluster: outbound|8080||mock-server.default.svc.cluster.local
+            timeout: 3s
+            ...
         - decorator:
             operation: mock-server.default.svc.cluster.local:8080/*
           match:
             prefix: /
-          name: default
+          metadata:
+            filter_metadata:
+              istio:
+                config: /apis/networking.istio.io/v1/namespaces/default/virtual-service/mock-server
           route:
             cluster: outbound|8080||mock-server.default.svc.cluster.local
```

VirtualService는 **요청을 보내는 쪽 Sidecar의 Route(RDS)에 반영**된다. 기존에 `/*` 하나였던 `mock-server` Virtual Host의 Route Entry가 `/api*` Match와 Catch-all 두 개로 늘어나고, `timeout: 3s`가 Route에 반영된다. 각 Route Entry의 `metadata.filter_metadata.istio.config`에는 이 설정을 만든 VirtualService의 경로가 기록되어 설정의 출처를 추적할 수 있다. Cluster나 Listener는 변하지 않는다.

```yaml {caption="[Config 4] VirtualService with Gateway Example", linenos=table}
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: mock-server-gateway
  namespace: default
spec:
  hosts:
  - mock-server.dev
  gateways:
  - mock-server
  http:
  - route:
    - destination:
        host: mock-server
        port:
          number: 8080
```

```diff {caption="[Diff 4] Gateway에 VirtualService 연결 전후 istio-ingressgateway Pod의 proxy-config"}
 - '@type': type.googleapis.com/envoy.admin.v3.RoutesConfigDump
   dynamic_route_configs:
   - route_config:
       '@type': type.googleapis.com/envoy.config.route.v3.RouteConfiguration
       name: http.8080
       virtual_hosts:
       - domains:
-        - '*'
-        name: blackhole:80
+        - mock-server.dev
+        name: mock-server.dev:80
+        routes:
+        - decorator:
+            operation: mock-server.default.svc.cluster.local:8080/*
+          match:
+            prefix: /
+          metadata:
+            filter_metadata:
+              istio:
+                config: /apis/networking.istio.io/v1/namespaces/default/virtual-service/mock-server-gateway
+          route:
+            cluster: outbound|8080||mock-server.default.svc.cluster.local
+            ...
```

[Config 4]는 `gateways` 필드로 [Config 2]의 Gateway에 연결한 VirtualService 예시이다. 이 경우 Sidecar가 아닌 **Gateway Pod(istio-ingressgateway)의 Route에 반영**되며, [Diff 2]에서 `blackhole` Virtual Host뿐이었던 `http.8080` Route Table이 `mock-server.dev` Virtual Host로 교체되어 `mock-server` Cluster로 라우팅되기 시작한다. Gateway Pod도 Sidecar와 동일하게 Mesh 전체 서비스의 Cluster 설정을 받고 있으므로, 라우팅 대상인 `outbound|8080||mock-server...` Cluster는 이미 존재한다.

### 3.3. DestinationRule

```yaml {caption="[Config 5] DestinationRule Example", linenos=table}
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: mock-server
  namespace: default
spec:
  host: mock-server
  trafficPolicy:
    loadBalancer:
      simple: RANDOM
  subsets:
  - name: v1
    labels:
      version: v1
```

```diff {caption="[Diff 5] DestinationRule 적용 전후 shell Pod의 proxy-config"}
 - '@type': type.googleapis.com/envoy.admin.v3.ClustersConfigDump
   dynamic_active_clusters:
   ...
+  - cluster:
+      '@type': type.googleapis.com/envoy.config.cluster.v3.Cluster
+      name: outbound|8080|v1|mock-server.default.svc.cluster.local
+      type: EDS
+      eds_cluster_config:
+        eds_config:
+          ads: {}
+        service_name: outbound|8080|v1|mock-server.default.svc.cluster.local
+      lb_policy: RANDOM
+      metadata:
+        filter_metadata:
+          istio:
+            config: /apis/networking.istio.io/v1/namespaces/default/destination-rule/mock-server
+            subset: v1
+      ...
   - cluster:
       '@type': type.googleapis.com/envoy.config.cluster.v3.Cluster
       name: outbound|8080||mock-server.default.svc.cluster.local
-      lb_policy: LEAST_REQUEST
+      lb_policy: RANDOM
       metadata:
         filter_metadata:
           istio:
+            config: /apis/networking.istio.io/v1/namespaces/default/destination-rule/mock-server
             services:
             - host: mock-server.default.svc.cluster.local
```

DestinationRule은 **요청을 보내는 쪽 Sidecar의 Cluster(CDS)에 반영**된다. 기존 Cluster의 `lb_policy`가 기본값 `LEAST_REQUEST`에서 `RANDOM`으로 변경되고, Subset을 정의하면 Subset마다 별도의 Cluster(`outbound|8080|v1|...`)가 추가로 생성된다. Route는 변하지 않으므로, Subset Cluster로 Traffic을 보내려면 VirtualService에서 Subset을 지정해야 한다.

### 3.4. ServiceEntry

```yaml {caption="[Config 6] ServiceEntry Example", linenos=table}
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

```diff {caption="[Diff 6] ServiceEntry 적용 전후 shell Pod의 proxy-config"}
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
```

ServiceEntry는 외부 서비스를 Mesh의 Service Registry에 등록하며, **모든 Sidecar의 Cluster와 Route에 반영**된다. `external.example.com` Cluster가 `STRICT_DNS` Type으로 생성되고(Kubernetes Service의 `EDS` Type과 달리 DNS로 Endpoint를 조회), `80` Port Route Table에 해당 Host의 Virtual Host가 추가된다. 이후 해당 Host로 향하는 Traffic은 PassthroughCluster가 아닌 전용 Cluster를 통해 처리된다.

### 3.5. Sidecar

```yaml {caption="[Config 7] Sidecar Example", linenos=table}
apiVersion: networking.istio.io/v1
kind: Sidecar
metadata:
  name: default
  namespace: default
spec:
  egress:
  - hosts:
    - "./mock-server.default.svc.cluster.local"
```

```diff {caption="[Diff 7] Sidecar 적용 전후 shell Pod의 proxy-config (Cluster 22개 → 8개)"}
 - '@type': type.googleapis.com/envoy.admin.v3.ClustersConfigDump
   dynamic_active_clusters:
-  - cluster:
-      '@type': type.googleapis.com/envoy.config.cluster.v3.Cluster
-      name: outbound|15010||istiod.istio-system.svc.cluster.local
-      ...
-  - cluster:
-      name: outbound|53||kube-dns.kube-system.svc.cluster.local
-      ...
-  - cluster:
-      name: outbound|443||kubernetes.default.svc.cluster.local
-      ...
   - cluster:
       name: outbound|8080||mock-server.default.svc.cluster.local
       ...
```

Sidecar CR은 Envoy에 새로운 설정을 추가하는 것이 아니라 **Sidecar가 받는 설정의 범위를 제한**한다. 기본적으로 모든 Sidecar는 Mesh 전체 서비스의 Cluster, Listener, Route를 받는데, egress hosts를 `mock-server`로 제한하면 나머지 서비스의 설정이 모두 제거된다 (Cluster 22개 → 8개, Listener와 Route도 동일하게 축소). 대규모 Cluster에서 Sidecar의 Memory 사용량과 xDS Push 비용을 줄이는 핵심 수단이다.

### 3.6. EnvoyFilter

```yaml {caption="[Config 8] EnvoyFilter Example", linenos=table}
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: add-response-header
  namespace: default
spec:
  workloadSelector:
    labels:
      app: mock-server
  configPatches:
  - applyTo: HTTP_FILTER
    match:
      context: SIDECAR_INBOUND
      listener:
        filterChain:
          filter:
            name: envoy.filters.network.http_connection_manager
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

```diff {caption="[Diff 8] EnvoyFilter 적용 전후 mock-server Pod의 proxy-config (virtualInbound Listener)"}
           - name: envoy.filters.network.http_connection_manager
             typed_config:
               '@type': type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
               ...
               forward_client_cert_details: APPEND_FORWARD
               http_filters:
+              - name: envoy.filters.http.lua
+                typed_config:
+                  '@type': type.googleapis.com/envoy.extensions.filters.http.lua.v3.Lua
+                  inline_code: |
+                    function envoy_on_response(response_handle)
+                      response_handle:headers():add("x-added-by-envoyfilter", "true")
+                    end
               - name: istio.metadata_exchange
                 typed_config:
                   '@type': type.googleapis.com/udpa.type.v1.TypedStruct
```

EnvoyFilter는 istiod가 생성한 Envoy 설정을 **직접 Patch하는 CR**로, 다른 CR이 추상화하지 않는 Envoy 기능에 접근할 수 있다. 예시는 mock-server Sidecar의 Inbound HTTP Filter Chain에 Lua Filter를 삽입하여 응답 Header를 추가한다. Envoy 내부 구현에 직접 의존하므로 Istio Upgrade 시 깨질 수 있어 주의가 필요하다.

### 3.7. WorkloadEntry

```yaml {caption="[Config 9] WorkloadEntry Example", linenos=table}
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

```diff {caption="[Diff 9] WorkloadEntry 적용 전후 shell Pod의 proxy-config"}
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

WorkloadEntry는 **VM 같은 Kubernetes 외부 Workload를 Pod처럼 등록**하는 CR이다. 단독으로는 효과가 없고, workloadSelector로 이를 선택하는 ServiceEntry와 함께 사용해야 한다. Label이 매칭되면 WorkloadEntry의 address가 해당 Cluster의 Endpoint(EDS)로 등록되어, Pod의 Endpoint와 동일한 방식으로 LB 대상이 된다.

### 3.8. WorkloadGroup

```yaml {caption="[Config 10] WorkloadGroup Example", linenos=table}
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

WorkloadGroup은 적용해도 **Envoy 설정에 아무 변화가 없다** (proxy-config diff 없음). Deployment가 Pod의 Template인 것처럼, WorkloadGroup은 WorkloadEntry의 Template이기 때문이다. VM의 istio-agent가 Auto-registration으로 Mesh에 참여할 때 이 Template을 기반으로 WorkloadEntry가 자동 생성되며, 그 시점에 비로소 Endpoint가 반영된다.

### 3.9. ProxyConfig

```yaml {caption="[Config 11] ProxyConfig Example", linenos=table}
apiVersion: networking.istio.io/v1beta1
kind: ProxyConfig
metadata:
  name: mock-server
  namespace: default
spec:
  selector:
    matchLabels:
      app: mock-server
  concurrency: 4
```

ProxyConfig도 적용 시점에는 **동작 중인 Envoy에 변화가 없다** (proxy-config diff 없음). concurrency(Worker Thread 수) 같은 설정은 xDS로 동적 전달되는 것이 아니라 Envoy Bootstrap Configuration에 속하기 때문이다. Sidecar Injection 시점에 주입되므로, Pod를 재생성해야 반영된다.

### 3.10. PeerAuthentication

```yaml {caption="[Config 12] PeerAuthentication Example", linenos=table}
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: default
spec:
  mtls:
    mode: STRICT
```

```diff {caption="[Diff 12] PeerAuthentication 적용 전후 mock-server Pod의 proxy-config (virtualInbound Listener)"}
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

PeerAuthentication은 **받는 쪽 Sidecar의 virtualInbound Listener Filter Chain에 반영**된다. 기본값인 PERMISSIVE Mode에서는 Port마다 mTLS용 `tls` Chain(Istio ALPN 조건 포함)과 Plaintext용 `raw_buffer` Chain이 함께 존재하지만, STRICT Mode로 변경하면 `raw_buffer` Chain이 모두 제거되어 mTLS가 아닌 연결은 수립 자체가 불가능해진다. `tls` Chain의 `application_protocols` Match 조건도 사라지는데, 더 이상 Plaintext Chain과 구분할 필요 없이 모든 연결이 TLS Chain으로 처리되기 때문이다.

### 3.11. RequestAuthentication

```yaml {caption="[Config 13] RequestAuthentication Example", linenos=table}
apiVersion: security.istio.io/v1
kind: RequestAuthentication
metadata:
  name: mock-server
  namespace: default
spec:
  selector:
    matchLabels:
      app: mock-server
  jwtRules:
  - issuer: "testing@secure.istio.io"
    jwksUri: "https://raw.githubusercontent.com/istio/istio/release-1.24/security/tools/jwt/samples/jwks.json"
```

```diff {caption="[Diff 13] RequestAuthentication 적용 전후 mock-server Pod의 proxy-config (virtualInbound Listener)"}
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

RequestAuthentication은 **받는 쪽 Sidecar의 Inbound HTTP Filter Chain에 `jwt_authn` Filter를 추가**한다. CR에는 `jwksUri`를 지정했지만 Envoy 설정에는 `local_jwks`로 반영되는데, istiod가 JWKS를 미리 가져와 인라인으로 내려주기 때문이다. 이 Filter는 요청의 JWT를 검증하여 유효하지 않으면 401로 거부하고, 유효하면 Claim 정보를 뒤의 Filter(AuthorizationPolicy의 RBAC 등)에서 사용할 수 있게 한다. `allow_missing` Rule에 의해 JWT가 없는 요청은 통과되므로, 미인증 요청 차단은 AuthorizationPolicy와 조합해야 한다.

### 3.12. AuthorizationPolicy

```yaml {caption="[Config 14] AuthorizationPolicy Example", linenos=table}
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: mock-server
  namespace: default
spec:
  selector:
    matchLabels:
      app: mock-server
  action: DENY
  rules:
  - to:
    - operation:
        paths: ["/admin"]
```

```diff {caption="[Diff 14] AuthorizationPolicy 적용 전후 mock-server Pod의 proxy-config (virtualInbound Listener)"}
               http_filters:
               - name: istio.metadata_exchange
                 ...
+              - name: envoy.filters.http.rbac
+                typed_config:
+                  '@type': type.googleapis.com/envoy.extensions.filters.http.rbac.v3.RBAC
+                  rules:
+                    action: DENY
+                    policies:
+                      ns[default]-policy[mock-server]-rule[0]:
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

AuthorizationPolicy는 **받는 쪽 Sidecar의 Inbound HTTP Filter Chain에 `rbac` Filter를 추가**한다. 예시는 `/admin` 경로 요청을 거부하는 DENY 정책으로, RBAC Filter의 Rule로 변환되어 매칭되는 요청은 403으로 거부된다. L7 속성(경로, Method 등)을 사용하는 정책이므로 HTTP Filter로 구현되며, TCP Port에는 별도 Network Filter가 사용된다.

### 3.13. Telemetry

```yaml {caption="[Config 15] Telemetry Example", linenos=table}
apiVersion: telemetry.istio.io/v1
kind: Telemetry
metadata:
  name: mock-server
  namespace: default
spec:
  accessLogging:
  - providers:
    - name: otel
```

```diff {caption="[Diff 15] Telemetry 적용 전후 mock-server Pod의 proxy-config (Listener Access Logger 8개 전부 교체)"}
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

Telemetry는 **Listener와 HTTP Connection Manager의 Access Logger, Tracing, Stats 설정에 반영**된다. 예시 환경은 meshConfig의 `accessLogFile`로 전역 File Logger(`/dev/stdout`)가 켜져 있는 상태인데, Telemetry로 `otel` Provider(meshConfig의 extensionProviders에 정의된 OpenTelemetry ALS)를 지정하면 해당 Workload의 File Logger가 모두 OpenTelemetry Logger로 교체된다. Provider가 가리키는 Service가 Cluster에 존재해야 반영된다는 점에 주의한다.

### 3.14. WasmPlugin

```yaml {caption="[Config 16] WasmPlugin Example", linenos=table}
apiVersion: extensions.istio.io/v1alpha1
kind: WasmPlugin
metadata:
  name: basic-auth
  namespace: default
spec:
  selector:
    matchLabels:
      app: mock-server
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

```diff {caption="[Diff 16] WasmPlugin 적용 전후 mock-server Pod의 proxy-config (ECDS, virtualInbound Listener)"}
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

WasmPlugin은 **Inbound HTTP Filter Chain에 Wasm Filter를 추가**하며, Filter의 실제 설정은 다른 Filter와 달리 ECDS (Extension Config Discovery Service)를 통해 별도 Resource로 전달된다 (적용 전에는 ECDS Resource가 아예 없다). Wasm 모듈은 pilot-agent가 OCI Registry에서 대신 다운로드하여 로컬 경로로 변환 후 Envoy에 전달한다. phase(AUTHN, AUTHZ, STATS 등)로 Filter Chain 내 삽입 위치를 제어할 수 있어, EnvoyFilter보다 안전한 확장 수단이다.

## 4. 참조

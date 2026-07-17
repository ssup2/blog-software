---
title: "Envoy Configuration, xDS"
draft: true
---

## 1. Envoy Configuration

```shell {caption="[Shell 1] Envoy Configuration Command Example", linenos=table}
./envoy -c config.yaml
```

Envoy Configuration은 **Bootstrap Configuration 파일**을 통해서 이루어진다. Bootstrap Configuration 파일은 이름에서 알 수 있듯이 Envoy의 Bootstrap 시에 사용되는 Configuration 파일을 의미하며, Envoy의 Root Configuration 파일이라고 할 수 있다. [Shell 1]은 Envoy를 Bootstrap Configuration 파일과 함께 실행하는 예시를 나타내고 있다.

Envoy는 Bootstrap Configuration 파일에 필요한 설정을 모두 넣어서 고정적으로 이용하는 **Static Configuration**과, xDS (eXtensible Discovery Services)를 통해서 외부로부터 동적으로 가져와 이용하는 **Dynamic Configuration**으로 크게 구분할 수 있다.

### 1.1. Static Configuration

```yaml {caption="[Config 1] Static Configuration Example", linenos=table}
# CASE 0 · fully static — run: envoy -c envoy-static.yaml
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

### 1.2. Mostly Static with Dynamic EDS

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
    type: EDS                                          # xDS: EDS on
    eds_cluster_config:                                # xDS: EDS subscription
      service_name: service_backend                    #   key = server's cluster_name
      eds_config:
        resource_api_version: V3
        api_config_source:                             # xDS: dedicated gRPC stream (not ADS)
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

### 1.3. Dynamic Configuration

```yaml {caption="[Config 3] Dynamic Configuration Example", linenos=table}
node:                                                  # xDS identity (server keys config on this)
  id: envoy-node-1
  cluster: demo-cluster
 
dynamic_resources:
  lds_config:                                          # xDS: LDS
    resource_api_version: V3
    ads: {}                                            #   via shared ADS stream
  cds_config:                                          # xDS: CDS
    resource_api_version: V3
    ads: {}                                            #   via shared ADS stream
  ads_config:                                          # xDS: the single ADS stream
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

## 2. xDS (eXtensible Discovery Services)

### 2.1. LDS (Listener Discovery Service)

```yaml {caption="[Config 1] LDS Configuration", linenos=table}
resources:
- "@type": type.googleapis.com/envoy.config.listener.v3.Listener
  name: "0.0.0.0_8080"
  address:
    socket_address: { address: 0.0.0.0, port_value: 8080 }
  filter_chains:
  - filters:
    - name: envoy.filters.network.http_connection_manager
      typed_config:
        "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
        stat_prefix: ingress_http
        rds:
          route_config_name: "8080"
          config_source: { ads: {} }
```

### 2.2. RDS (Route Discovery Service)

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

### 2.3. CDS (Cluster Discovery Service)

```yaml {caption="[Config 3] CDS Configuration", linenos=table}
resources:
- "@type": type.googleapis.com/envoy.config.cluster.v3.Cluster
  name: "outbound|8080||reviews.default.svc.cluster.local"
  type: EDS
  eds_cluster_config:
    eds_config: { ads: {} }
  lb_policy: ROUND_ROBIN
  connect_timeout: 10s
```

### 2.4. EDS (Endpoint Discovery Service)

```yaml {caption="[Config 4] EDS Configuration", linenos=table}
resources:
- "@type": type.googleapis.com/envoy.config.endpoint.v3.ClusterLoadAssignment
  cluster_name: "outbound|8080||reviews.default.svc.cluster.local"
  endpoints:
  - lb_endpoints:
    - endpoint:
        address:
          socket_address: { address: 10.44.0.12, port_value: 8080 }
```

### 2.5. SDS (Secret Discovery Service)

```yaml {caption="[Config 5] SDS Configuration", linenos=table}
resources:
- "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.Secret
  name: "default"
  tls_certificate:
    certificate_chain: { filename: "/etc/certs/cert-chain.pem" }
    private_key: { filename: "/etc/certs/key.pem" }
```

### 2.6. NDS (Name Discovery Service)

```yaml {caption="[Config 6] NDS Configuration", linenos=table}
resources:
- "@type": type.googleapis.com/istio.networking.nds.v1.NameTable
  table:
    "reviews.default.svc.cluster.local":
      ips: ["10.96.23.15", "10.96.23.16"]
      registry: Kubernetes
```

### 2.7. ADS (Aggregated Discovery Service)

```yaml {caption="[Config 6] ADS Configuration", linenos=table}
# 하나의 gRPC 스트림 안에서 type_url로 리소스 종류를 구분해서 순차 전송
node: { id: "sidecar~10.44.0.12~reviews-v1-abc.default~default.svc.cluster.local" }
type_url: "type.googleapis.com/envoy.config.cluster.v3.Cluster"
```

## 2. 참조

* Envoy Life of a Request : [https://www.envoyproxy.io/docs/envoy/latest/intro/life_of_a_request](https://www.envoyproxy.io/docs/envoy/latest/intro/life_of_a_request)
* Envoy Listener Filters : [https://www.envoyproxy.io/docs/envoy/latest/configuration/listeners/listener_filters/listener_filters](https://www.envoyproxy.io/docs/envoy/latest/configuration/listeners/listener_filters/listener_filters)
* Envoy Network Filters : [https://www.envoyproxy.io/docs/envoy/latest/configuration/listeners/network_filters/network_filters](https://www.envoyproxy.io/docs/envoy/latest/configuration/listeners/network_filters/network_filters)

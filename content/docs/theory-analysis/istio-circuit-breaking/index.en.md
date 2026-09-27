---
title: Istio Circuit Breaking
---

## 1. Istio Circuit Breaking

Istio provides the Circuit Breaking feature by leveraging the Sidecar Proxy (Envoy). Using a **Destination Rule**, an **individual Circuit Breaking rule** can be configured for each Service, and if needed, a **Global Circuit Breaking rule** can also be configured. Circuit Breaking operates in the **Sidecar Proxy of the Client Pod** (Envoy). Therefore, if the Sidecar Proxy is not injected into the Client Pod and running, Circuit Breaking does not work.

### 1.1. Destination Rule for Circuit Breaking

```yaml {caption="[File 1] Destination Rule with Circuit Breaking Example", linenos=table}
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: productpage
spec:
  host: productpage
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 20
      http:
        maxRetries: 20
        http1MaxPendingRequests: 20
        maxRequestsPerConnection: 20
    outlierDetection:
      consecutive5xxErrors: 20
      interval: 20s
      baseEjectionTime: 20s
      maxEjectionPercent: 20
```

Circuit Breaking is mainly configured through the **Connection Pool** (`trafficPolicy.connectionPool`) Field and the **Outlier Detection** (`trafficPolicy.outlierDetection`) Field of a **Destination Rule**. [File 1] shows an example of a Destination Rule for Circuit Breaking.

Connection Pool specifies settings related to the **maximum concurrent Connections** or **maximum concurrent requests** that the **Sidecar Proxy of a single Client Pod** can use, and Circuit Breaking operates when the specified settings are exceeded. Each setting value is applied per Host (Service) specified in the Destination Rule. The main settings provided by the Connection Pool for the `productpage` Service in [File 1] are as follows.

* `tcp.maxConnections` : Sets the maximum number of TCP Connections.
* `tcp.connectTimeout` : Sets the maximum time allowed to establish a TCP Connection. The default is 10 seconds.
* `tcp.maxConnectionDuration` : Sets the maximum time a TCP Connection can be kept. If not set, there is no limit on the maximum duration.
* `tcp.idleTimeout` : Sets the TCP Idle Timeout. The default is `1h`, and setting it to `0s` (0 seconds) removes the limit.
* `http.http1MaxPendingRequests` : Sets the maximum number of pending HTTP requests. Although the name contains `http1`, it applies not only to HTTP/1.1 but also to HTTP/2 requests. The default is `2^31-1`.
* `http.http2MaxRequests` : Sets the maximum number of HTTP requests that can be processed concurrently. Although the name contains `http2`, it applies not only to HTTP/2 but also to HTTP/1.1 requests. The default is `2^31-1`.
* `http.maxRequestsPerConnection` : Sets the maximum number of HTTP requests that can be processed per TCP Connection. The default is `2^31-1`, and setting it to `0` removes the limit. Setting it to `1` means disabling the Keep Alive feature, because at most one HTTP request is processed per TCP Connection.
* `http.maxRetries` : Sets the maximum number of HTTP retries that can be processed concurrently. The default is `2^32-1`.
* `http.maxConcurrentStreams` : Sets the maximum number of Streams that can be processed per HTTP/2 Connection. The default is `2^31-1`.

Outlier Detection defines the criteria for judging abnormal states, and Circuit Breaking operates when something is judged to be an Outlier. The main settings provided by Outlier Detection are as follows.

* `consecutiveGatewayErrors` : Sets the number of consecutive 502, 503, 504 errors. Setting it to `0` removes the limit.
* `consecutive5xxErrors` : Sets the number of consecutive 5xx errors. Setting it to `0` removes the limit.
* `interval` : Sets the time interval used to judge the Outlier state. The default is `10s`.
* `baseEjectionTime` : Sets the minimum Circuit Breaking time when judged to be in the Outlier state. The default is `30s`.
* `maxEjectionPercent` : Sets the maximum percentage of Outliers to which Circuit Breaking can be applied. The default is `10`(%), and setting it to `100`(%) allows Circuit Breaking to be applied to all Outliers.

Destination Rule rules are applied **individually to each Client Pod**. For example, in [File 1] `trafficPolicy.connectionPool.tcp.maxConnections: 1` is configured, which means limiting the maximum number of TCP Connections delivered from the Client Pod's Sidecar Proxy to the Server Pod to one, and it is applied separately to the Sidecar Proxy of each Client Pod. That is, if there are 5 Client Pods, the number of TCP Connections delivered to the Server Pod becomes at most 5.

### 1.2. Sidecar Proxy (Envoy) Access Log

```text {caption="[Text 1] Sidecar Proxy (Envoy) Access Log"}
[2025-06-01T15:37:04.857Z] "GET /get HTTP/1.1" 503 UO upstream_reset_before_response_started{overflow} - "-" 0 81 0 - "-" "fortio.org/fortio-1.69.5" "d4e65b2b-3a80-9caa-a6ca-df79908d4d7e" "httpbin:8000" "-" outbound|8000||httpbin.default.svc.cluster.local - 10.96.243.7:8000 10.244.2.30:59002 - default
[2025-06-01T15:37:04.857Z] "GET /get HTTP/1.1" 503 UO upstream_reset_before_response_started{overflow} - "-" 0 81 0 - "-" "fortio.org/fortio-1.69.5" "431d0cda-450d-9d54-8edd-c835cddcfb2c" "httpbin:8000" "-" outbound|8000||httpbin.default.svc.cluster.local - 10.96.243.7:8000 10.244.2.30:59006 - default
[2025-06-01T15:37:04.858Z] "GET /get HTTP/1.1" 503 UO upstream_reset_before_response_started{overflow} - "-" 0 81 0 - "-" "fortio.org/fortio-1.69.5" "1c44aff2-e93e-98d1-a690-5f8eabfe0315" "httpbin:8000" "-" outbound|8000||httpbin.default.svc.cluster.local - 10.96.243.7:8000 10.244.2.30:59018 - default
[2025-06-01T15:37:04.814Z] "GET /get HTTP/1.1" 200 - via_upstream - "-" 0 621 94 63 "-" "fortio.org/fortio-1.69.5" "f47fa353-177d-9834-ac08-5c5be28f4593" "httpbin:8000" "10.244.1.27:8080" outbound|8000||httpbin.default.svc.cluster.local 10.244.2.30:42658 10.96.243.7:8000 10.244.2.30:58932 - default
[2025-06-01T15:37:04.909Z] "GET /get HTTP/1.1" 200 - via_upstream - "-" 0 621 1 1 "-" "fortio.org/fortio-1.69.5" "43e95e7a-20f3-95f4-b63c-42defe29f27e" "httpbin:8000" "10.244.1.27:8080" outbound|8000||httpbin.default.svc.cluster.local 10.244.2.30:42672 10.96.243.7:8000 10.244.2.30:58932 - default
[2025-06-01T15:37:04.911Z] "GET /get HTTP/1.1" 200 - via_upstream - "-" 0 621 0 0 "-" "fortio.org/fortio-1.69.5" "602fe5bd-6564-9bab-b4c6-e87ad31776c4" "httpbin:8000" "10.244.1.27:8080" outbound|8000||httpbin.default.svc.cluster.local 10.244.2.30:42686 10.96.243.7:8000 10.244.2.30:58932 - default
```

[Text 1] shows an example of the Access Log generated by the Client Pod's Sidecar Proxy (Envoy). Even when Circuit Breaking operates in the Client Pod's Sidecar Proxy, no Log is left by default, and the Log can be checked by **enabling the Access Log** on the Client Pod's Sidecar Proxy. When Circuit Breaking operates, it can be seen that a `503` response is delivered to the Client. Envoy's `UO (UpstreamOverflow)` Response Flag and the `upstream_reset_before_response_started{overflow}` message can also be seen.

### 1.3. Global Circuit Breaking

Destination Rules are applied with the following priority.

1. The Destination Rule in the Namespace where the Client Pod is located
2. The Destination Rule in the Namespace where the Server Pod is located
3. The Destination Rule in the Root Namespace (`istio-system`)

The Destination Rule in the Namespace where the Client Pod is located and the Destination Rule in the Namespace where the Server Pod is located are both applied only inside the Namespace. In contrast, the Destination Rule in the Root Namespace (`istio-system`) has the lowest priority but has the characteristic of being applied to all Namespaces. Therefore, Global Circuit Breaking can be configured using a **Destination Rule in the Root Namespace**.

```yaml {caption="[File 2] Global Circuit Breaking Example"}
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: global-dr
  namespace: istio-system
spec:
  host: "*.cluster.local"
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 20
      http:
        maxRetries: 20
        http1MaxPendingRequests: 20
        maxRequestsPerConnection: 20
    outlierDetection:
      consecutive5xxErrors: 20
      interval: 20s
      baseEjectionTime: 20s
      maxEjectionPercent: 20
```

```text {caption="[Text 2] Global Circuit Breaking Envoy Proxy consecutive5xx Configuration Example"}
$ istioctl pc cluster deploy/productpage-v1 -o yaml | grep maxRetries -B 6 -A 1
--
- altStatName: outbound|9080||productpage.default.svc.cluster.local;
  circuitBreakers:
    thresholds:
    - maxConnections: 20
      maxPendingRequests: 20
      maxRequests: 4294967295
      maxRetries: 20
      trackRemaining: true
--
- altStatName: outbound|9080||ratings.default.svc.cluster.local;
  circuitBreakers:
    thresholds:
    - maxConnections: 20
      maxPendingRequests: 20
      maxRequests: 4294967295
      maxRetries: 20
      trackRemaining: true
--
- altStatName: outbound|9080||reviews.default.svc.cluster.local;
  circuitBreakers:
    thresholds:
    - maxConnections: 20
      maxPendingRequests: 20
      maxRequests: 4294967295
      maxRetries: 20

$ istioctl pc cluster deploy/productpage-v1 -o yaml | grep consecutive5xx -A 4 -B 3
...
--
  name: outbound|9080||productpage.default.svc.cluster.local
  outlierDetection:
    baseEjectionTime: 20s
    consecutive5xx: 20
    enforcingConsecutive5xx: 100
    enforcingSuccessRate: 0
    interval: 20s
    maxEjectionPercent: 20
--
  name: outbound|9080||ratings.default.svc.cluster.local
  outlierDetection:
    baseEjectionTime: 20s
    consecutive5xx: 20
    enforcingConsecutive5xx: 100
    enforcingSuccessRate: 0
    interval: 20s
    maxEjectionPercent: 20
--
  name: outbound|9080||reviews.default.svc.cluster.local
  outlierDetection:
    baseEjectionTime: 20s
    consecutive5xx: 20
    enforcingConsecutive5xx: 100
    enforcingSuccessRate: 0
    interval: 20s
    maxEjectionPercent: 20
```

[File 2] shows an example of a Destination Rule for Global Circuit Breaking, and [Text 2] shows an example where the `maxRetries: 20` and `consecutive5xxErrors: 20` settings are applied to the Config of an Envoy Proxy to which [File 2] is applied. If no Destination Rule other than the Destination Rule of [File 2] is applied, the `maxRetries: 20` and `consecutive5xxErrors: 20` settings are applied to every Host (Service) as shown in [Text 2]. That is, it means the setting values are applied per Host (Service).

[Text 2] shows only the Config of the Envoy Proxy applied to the `productpage-v1` Deployment in the `default` Namespace, but the same Circuit Breaking settings are applied to the Envoy Proxies of all other Pods.

```yaml {caption="[File 3] Namespace Circuit Breaking Example"}
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: productpage
spec:
  host: productpage
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 10
      http:
        maxRetries: 10
        http1MaxPendingRequests: 10
        maxRequestsPerConnection: 10
    outlierDetection:
      consecutive5xxErrors: 10
```

```text {caption="[Text 3] Namespace Circuit Breaking Example"}
$ istioctl pc cluster deploy/productpage-v1 -o yaml | grep consecutive5xx -A 4 -B 3
...
--
          namespace: default
  name: outbound|9080||productpage.default.svc.cluster.local
  outlierDetection:
    consecutive5xx: 10
    enforcingConsecutive5xx: 100
    enforcingSuccessRate: 0
  transportSocketMatches:
  - match:
--
  name: outbound|9080||ratings.default.svc.cluster.local
  outlierDetection:
    baseEjectionTime: 20s
    consecutive5xx: 20
    enforcingConsecutive5xx: 100
    enforcingSuccessRate: 0
    interval: 20s
    maxEjectionPercent: 20
--
  name: outbound|9080||reviews.default.svc.cluster.local
  outlierDetection:
    baseEjectionTime: 20s
    consecutive5xx: 20
    enforcingConsecutive5xx: 100
    enforcingSuccessRate: 0
    interval: 20s
    maxEjectionPercent: 20
```

[File 3] shows an example of a Destination Rule for Circuit Breaking applied only inside a Namespace, and [Text 3] shows an example where the `consecutive5xxErrors: 10` setting is applied to the Config of an Envoy Proxy to which [File 3] is applied. [File 3] applies the `consecutive5xxErrors: 10` setting only to the `httpbin` Service in the `default` Namespace, and because the Global Destination Rule has the lowest priority, it can be seen that the `consecutive5xxErrors: 10` setting is applied only to the `httpbin` Service in the `default` Namespace, while the `consecutive5xxErrors: 20` setting is applied to all the other Services.

In the past, there was a feature that inherited the Global Destination Rule by setting `PILOT_ENABLE_DESTINATION_RULE_INHERITANCE` on istiod, but the feature was removed from istio `v1.20.0` Version. Therefore, currently, all the necessary settings must be configured one by one with Destination Rules individually in each Namespace.

## 2. References

* Istio Circuit Breaking : [https://istio.io/latest/docs/tasks/traffic-management/circuit-breaking/](https://istio.io/latest/docs/tasks/traffic-management/circuit-breaking/)
* Istio Destination Rule Cross Namespace : [https://learncloudnative.com/blog/2023-02-03-global-dr](https://learncloudnative.com/blog/2023-02-03-global-dr)
* Istio Destination Rule Cross Namespace : [https://istio.io/latest/docs/ops/best-practices/traffic-management/#cross-namespace-configuration](https://istio.io/latest/docs/ops/best-practices/traffic-management/#cross-namespace-configuration)
* Istio Global Traffic Policy: [https://docs.google.com/document/d/1TkIiovpPLwd-JQ_zKA1Fhy5MVGW3dQKtNwOlFTCKb_Y/edit?tab=t.0](https://docs.google.com/document/d/1TkIiovpPLwd-JQ_zKA1Fhy5MVGW3dQKtNwOlFTCKb_Y/edit?tab=t.0)
* Envoy Circuit Breaking : [https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/upstream/circuit_breaking](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/upstream/circuit_breaking)
* Drop PILOT_ENABLE_DESTINATION_RULE_INHERITANCE : [https://github.com/istio/istio/pull/46270](https://github.com/istio/istio/pull/46270)

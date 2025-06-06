---
title: Istio Circuit Breaking
---

## 1. Istio Circuit Breaking

Istio는 Sidecar Proxy (Envoy)를 활용하여 Circuit Breaking 기능을 제공한다. **Destination Rule**을 활용하여 각 Service 마다 **개별의 Circuit Breaking 규칙**을 설정할 수 있으며, 필요에 따라서는 **Global Circuit Breaking 규칙**도 설정 가능하다. 

Circuit Breaking은 **Client Pod의 Sidecar Proxy** (Envoy)에서 동작한다. 따라서 Client Pod에 Sidecar Proxy가 Injection되어 동작하지 않으면 Circuit Breaking이 동작하지 않는다.

### 1.1. Circuit Breaking을 위한 Destination Rule

```yaml {caption="[File 1] Destination Rule with Circuit Breaking Example", linenos=table}
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: httpbin
spec:
  host: httpbin
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 1
      http:
        http1MaxPendingRequests: 1
        maxRequestsPerConnection: 1
    outlierDetection:
      consecutive5xxErrors: 1
      interval: 1s
      baseEjectionTime: 3m
      maxEjectionPercent: 100
```

Circuit Breaking은 주로 **Destination Rule**의 **Connection Pool** (`trafficPolicy.connectionPool`) 필드와 **Outlier Detection** (`trafficPolicy.outlierDetection`) 필드를 통해 설정한다. [File 1]은 Circuit Breaking을 위한 Destination Rule의 예제를 나타내고 있다.

Connection Pool은 Client Pod의 Sidecar Proxy에서 이용할 수 있는 **최대 Connection의 개수** 또는 **최대 요청 대기 개수**를 정의한다. Connection Pool의 Client에서 많은 요청이 발생하여 설정된 최대 Connection Pool 이상으로 Connection이 필요한 경우, 또는 설정된 최대 요청 대기 개수 이상으로 요청 대기가 발생하는 경우 **Circuit Breaking이 동작**한다. Connection Pool에서 제공하는 주요 설정들은 다음과 같다.

* `tcp.maxConnections` : TCP Connection의 최대 개수를 설정한다.
* `tcp.connectTimeout` : TCP Connection을 맺는데 걸리는 최대 시간을 설정한다. 기본값은 10초이다.
* `tcp.maxConnectionDuration` : TCP Connection을 유지할 수 있는 최대 시간을 설정한다. 설정하지 않으면 최대 유지 시간에 제한이 없어진다.
* `tcp.idleTimeout` : TCP Idle Timeout 시간을 설정한다. 기본값은 1시간 이며, 0s (0초)로 설정하는 경우 제한이 없어진다.
* `http.http1MaxPendingRequests` : HTTP 요청의 최대 대기 개수를 설정한다. 이름에는 `http1`이 포함되어 있지만, HTTP/1.1 뿐만 아니라 HTTP/2 요청에도 적용된다. 기본값은 2^31-1이다.
* `http.http2MaxRequests` : 동시에 처리할 수 있는 최대 HTTP 요청의 개수를 설정한다. 이름에는 `http2`가 포함되어 있지만, HTTP/2 뿐만 아니라 HTTP/1.1 요청에도 적용된다. 기본값은 2^31-1이다.
* `http.maxRequestsPerConnection` : 하나의 TCP Connection당 처리할 수 있는 최대 HTTP 요청 개수를 설정한다. 기본값은 2^31-1이며, 0으로 설정하는 경우에는 제한이 없어진다. 1로 설정하는 경우에는 하나의 TCP Connection당 최대 1개의 HTTP 요청만 처리하기 때문에 Keep Alive 기능 비활성활르 의미한다.
* `http.maxRetries` : HTTP 최대 재시도 개수를 설정한다. 여기서 최대 재시도 횟수는 Host (Service)당 횟수를 의미한다. 기본값은 2^32-1이다.
* `http.maxConcurrentStreams` : 하나의 HTTP/2 Connection당 처리할 수 있는 최대 Stream의 개수를 설정한다. 기본값은 2^31-1이다.

Outlier Detection은 비정상 상태를 판단하는 기준을 정의하며, Outlier로 판단되면 Circuit Breaking이 동작한다. Outlier Detection에서 제공하는 주요 설정은 다음과 같다.

* `consecutiveGatewayErrors` : 연속적으로 발생한 502,503,504 에러의 개수를 설정한다. 0으로 설정하는 경우 제한이 없어진다.
* `consecutive5xxErrors` : 연속적으로 발생한 5xx 에러의 개수를 설정한다. 0으로 설정하는 경우 제한이 없어진다.
* `interval` : Outlier 상태를 판단하는데 이용되는 시간 간격을 설정한다. 기본값은 10초이다.
* `baseEjectionTime` : Outlier 상태로 판단될 경우 최소 Circuit Breaking 시간을 설정한다. 기본값은 30초이다.
* `maxEjectionPercent` : Circuit Breaking 적용 가능한 최대 Outlier의 비율을 설정한다. 기본값은 10%이며, 100%로 설정하는 경우 모든 Outlier에 Circuit Breaking이 적용될 수 있다.

Destination Rule 규칙은 **각 Client Pod에 개별**로 적용된다. 예를들어 [File 1]에서는 `trafficPolicy.connectionPool.tcp.maxConnections: 1`이 설정되어 있는데, 이는 Client Pod의 Sidecar Proxy에서 Server Pod로 전달되는 최대 TCP Connection의 개수를 1개로 제한하는 것을 의미하며, 각 Client Pod의 Sidecar Proxy마다 별도로 적용된다. 즉 Client Pod가 5개라면 Server Pod로 전달되는 TCP Connection의 개수는 최대 5개가 된다.

### 1.2. Sidecar Proxy (Envoy) Access Log

```text {caption="[Text 1] Sidecar Proxy (Envoy) Access Log"}
[2025-06-01T15:37:04.857Z] "GET /get HTTP/1.1" 503 UO upstream_reset_before_response_started{overflow} - "-" 0 81 0 - "-" "fortio.org/fortio-1.69.5" "d4e65b2b-3a80-9caa-a6ca-df79908d4d7e" "httpbin:8000" "-" outbound|8000||httpbin.default.svc.cluster.local - 10.96.243.7:8000 10.244.2.30:59002 - default
[2025-06-01T15:37:04.857Z] "GET /get HTTP/1.1" 503 UO upstream_reset_before_response_started{overflow} - "-" 0 81 0 - "-" "fortio.org/fortio-1.69.5" "431d0cda-450d-9d54-8edd-c835cddcfb2c" "httpbin:8000" "-" outbound|8000||httpbin.default.svc.cluster.local - 10.96.243.7:8000 10.244.2.30:59006 - default
[2025-06-01T15:37:04.858Z] "GET /get HTTP/1.1" 503 UO upstream_reset_before_response_started{overflow} - "-" 0 81 0 - "-" "fortio.org/fortio-1.69.5" "1c44aff2-e93e-98d1-a690-5f8eabfe0315" "httpbin:8000" "-" outbound|8000||httpbin.default.svc.cluster.local - 10.96.243.7:8000 10.244.2.30:59018 - default
[2025-06-01T15:37:04.814Z] "GET /get HTTP/1.1" 200 - via_upstream - "-" 0 621 94 63 "-" "fortio.org/fortio-1.69.5" "f47fa353-177d-9834-ac08-5c5be28f4593" "httpbin:8000" "10.244.1.27:8080" outbound|8000||httpbin.default.svc.cluster.local 10.244.2.30:42658 10.96.243.7:8000 10.244.2.30:58932 - default
[2025-06-01T15:37:04.909Z] "GET /get HTTP/1.1" 200 - via_upstream - "-" 0 621 1 1 "-" "fortio.org/fortio-1.69.5" "43e95e7a-20f3-95f4-b63c-42defe29f27e" "httpbin:8000" "10.244.1.27:8080" outbound|8000||httpbin.default.svc.cluster.local 10.244.2.30:42672 10.96.243.7:8000 10.244.2.30:58932 - default
[2025-06-01T15:37:04.911Z] "GET /get HTTP/1.1" 200 - via_upstream - "-" 0 621 0 0 "-" "fortio.org/fortio-1.69.5" "602fe5bd-6564-9bab-b4c6-e87ad31776c4" "httpbin:8000" "10.244.1.27:8080" outbound|8000||httpbin.default.svc.cluster.local 10.244.2.30:42686 10.96.243.7:8000 10.244.2.30:58932 - default
```

[Text 1]은 Client Pod의 Sidecar Proxy (Envoy)에서 생성된 Access Log의 예제를 나타내고 있다. Client Pod의 Sidecar Proxy에서 Circuit Breaking이 동작해도 기본적으로는 어떠한 Log도 남지 않으며, Client Pod의 Sidecar Proxy에 **Access Log를 활성화**하면 해당 Log를 확인할 수 있다. Circuit Breaking이 동작하면 `503` 응답이 Client에 전달되는 것을 확인할 수 있다. 또한 Envoy의 `UO (UpstreamOverflow)` Response Flag와 `upstream_reset_before_response_started{overflow}` 메세지도 확인할 수 있다.

### 1.3. Global Circuit Breaking

Destination Rule은 다음과 같은 우선순위로 적용된다.

1. Client Pod가 위치한 Namespace의 Destination Rule
2. Server Pod가 위치한 Namespace의 Destination Rule
3. Root Namespace (istio-system)의 Destination Rule

Client Pod가 위치한 Namespace의 Destination Rule과 Server Pod가 위치한 Namespace의 Destination Rule은 모두 Namespace 내부에서만 적용된다. 반면에 Root Namespace (istio-system)의 Destination Rule은 우선순위가 가장 낮지만 모든 Namespace에 적용되는 특징을 갖는다. 따라서 **Root Namespace의 Destination Rule**을 이용하여 Global Circuit Breaking을 설정할 수 있다.

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
        http1MaxPendingRequests: 20
        maxRequestsPerConnection: 20
    outlierDetection:
      consecutive5xxErrors: 20
      interval: 20s
      baseEjectionTime: 20s
      maxEjectionPercent: 20
```

```text {caption="[Text 2] Global Circuit Breaking Envoy Proxy consecutive5xx Configuration Example"}
$ istioctl pc cluster deploy/httpbin -o yaml | grep consecutive5xx -A 4 -B 3
  name: outbound|9080||details.default.svc.cluster.local
  outlierDetection:
    baseEjectionTime: 20s
    consecutive5xx: 20
    enforcingConsecutive5xx: 100
    enforcingSuccessRate: 0
    interval: 20s
    maxEjectionPercent: 20
--
  name: outbound|8080||fortio.default.svc.cluster.local
  outlierDetection:
    baseEjectionTime: 20s
    consecutive5xx: 20
    enforcingConsecutive5xx: 100
    enforcingSuccessRate: 0
    interval: 20s
    maxEjectionPercent: 20
--
  name: outbound|8000||httpbin.default.svc.cluster.local
  outlierDetection:
    baseEjectionTime: 20s
    consecutive5xx: 20
    enforcingConsecutive5xx: 100
    enforcingSuccessRate: 0
    interval: 20s
    maxEjectionPercent: 20
--
...

$ istioctl pc cluster deploy/fortio -o yaml | grep consecutive5xx -A 4 -B 3
  name: outbound|9080||details.default.svc.cluster.local
  outlierDetection:
    baseEjectionTime: 20s
    consecutive5xx: 20
    enforcingConsecutive5xx: 100
    enforcingSuccessRate: 0
    interval: 20s
    maxEjectionPercent: 20
--
  name: outbound|8080||fortio.default.svc.cluster.local
  outlierDetection:
    baseEjectionTime: 20s
    consecutive5xx: 20
    enforcingConsecutive5xx: 100
    enforcingSuccessRate: 0
    interval: 20s
    maxEjectionPercent: 20
--
  name: outbound|8000||httpbin.default.svc.cluster.local
  outlierDetection:
    baseEjectionTime: 20s
    consecutive5xx: 20
    enforcingConsecutive5xx: 100
    enforcingSuccessRate: 0
    interval: 20s
    maxEjectionPercent: 20
--
...
```

[File 2]는 Global Circuit Breaking을 위한 Destination Rule의 예제를 나타내고 있으며, [Text 2]는 [File 2]가 적용된 Envoy Proxy의 Config에 `consecutive5xxErrors: 20` 설정이 적용된 예시를 나타내고 있다. [File 2]를 제외하고 적용된 Destination Rule이 없다면 [Text 2]에 나타난 것처럼 모든 Service에 대해서 `consecutive5xx: 20` 설정이 적용된다. [Text 2]에는 `default` Namespace에 존재하는 `httpbin`, `fortio` Deployment에 적용된 Envoy Proxy의 Config만을 보여주고 있지만, 그 외의 모든 Pod의 Envoy Proxy에 Circuit Breaking이 적용된다.

```yaml {caption="[File 3] Namespace Circuit Breaking Example"}
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: httpbin
spec:
  host: httpbin
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 10
      http:
        http1MaxPendingRequests: 10
        maxRequestsPerConnection: 10
    outlierDetection:
      consecutive5xxErrors: 10
```

```text {caption="[Text 3] Namespace Circuit Breaking Example"}
$ istioctl pc cluster deploy/httpbin -o yaml | grep consecutive5xx -A 4 -B 3
  name: outbound|9080||details.default.svc.cluster.local
  outlierDetection:
    baseEjectionTime: 20s
    consecutive5xx: 20
    enforcingConsecutive5xx: 100
    enforcingSuccessRate: 0
    interval: 20s
    maxEjectionPercent: 20
--
  name: outbound|8080||fortio.default.svc.cluster.local
  outlierDetection:
    baseEjectionTime: 20s
    consecutive5xx: 20
    enforcingConsecutive5xx: 100
    enforcingSuccessRate: 0
    interval: 20s
    maxEjectionPercent: 20
--
          namespace: default
  name: outbound|8000||httpbin.default.svc.cluster.local
  outlierDetection:
    consecutive5xx: 10
    enforcingConsecutive5xx: 100
    enforcingSuccessRate: 0
  transportSocketMatches:
  - match:
--
...

$ istioctl pc cluster deploy/fortio -o yaml | grep consecutive5xx -A 4 -B 3
  name: outbound|9080||details.default.svc.cluster.local
  outlierDetection:
    baseEjectionTime: 20s
    consecutive5xx: 20
    enforcingConsecutive5xx: 100
    enforcingSuccessRate: 0
    interval: 20s
    maxEjectionPercent: 20
--
  name: outbound|8080||fortio.default.svc.cluster.local
  outlierDetection:
    baseEjectionTime: 20s
    consecutive5xx: 20
    enforcingConsecutive5xx: 100
    enforcingSuccessRate: 0
    interval: 20s
    maxEjectionPercent: 20
--
          namespace: default
  name: outbound|8000||httpbin.default.svc.cluster.local
  outlierDetection:
    consecutive5xx: 10
    enforcingConsecutive5xx: 100
    enforcingSuccessRate: 0
  transportSocketMatches:
  - match:
--
...
```

[File 3]는 Namespace 내부에서만 적용되는 Circuit Breaking을 위한 Destination Rule의 예제를 나타내고 있으며, [Text 3]은 [File 3]가 적용된 Envoy Proxy의 Config에 `consecutive5xxErrors: 10` 설정이 적용된 예시를 나타내고 있다. [File 3]에서는 `default` Namespace에 존재하는 `httpbin` 서비스에만 `consecutive5xxErrors: 10` 설정을 적용하고 있으며, Global Destination Rule의 우선순위가 가장 낮기 때문에 `default` Namespace에 존재하는 `httpbin` 서비스에만 `consecutive5xxErrors: 10` 설정이 적용되며, 그외 나머지 서비스에는 `consecutive5xxErrors: 20` 설정이 적용된걸 확인할 수 있다.

`PILOT_ENABLE_DESTINATION_RULE_INHERITANCE`를 istiod에 설정하여 Global Destination Rule을 상속받는 기능이 존재했었지만, istio `v1.20.0` Version부터 해당 기능이 제거되었다. 따라서 현재는 각 Namespace에 개별적으로 필요한 설정들을 모두 일일히 Destination Rule을 설정해야 한다.

## 2. 참조

* Istio Circuit Breaking : [https://istio.io/latest/docs/tasks/traffic-management/circuit-breaking/](https://istio.io/latest/docs/tasks/traffic-management/circuit-breaking/)
* Istio Destination Rule Cross Namespace : [https://learncloudnative.com/blog/2023-02-03-global-dr](https://learncloudnative.com/blog/2023-02-03-global-dr)
* Istio Destination Rule Cross Namespace : [https://istio.io/latest/docs/ops/best-practices/traffic-management/#cross-namespace-configuration](https://istio.io/latest/docs/ops/best-practices/traffic-management/#cross-namespace-configuration)
* Istio Global Traffic Policy: [https://docs.google.com/document/d/1TkIiovpPLwd-JQ_zKA1Fhy5MVGW3dQKtNwOlFTCKb_Y/edit?tab=t.0](https://docs.google.com/document/d/1TkIiovpPLwd-JQ_zKA1Fhy5MVGW3dQKtNwOlFTCKb_Y/edit?tab=t.0)
* Envoy Circuit Breaking : [https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/upstream/circuit_breaking](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/upstream/circuit_breaking)
* Drop PILOT_ENABLE_DESTINATION_RULE_INHERITANCE : [https://github.com/istio/istio/pull/46270](https://github.com/istio/istio/pull/46270)
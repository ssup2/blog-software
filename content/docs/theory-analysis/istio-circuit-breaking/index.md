---
title: Istio Circuit Breaking
draft: true
---

## 1. Istio Circuit Breaking

Istio는 Sidecar Proxy (Envoy)를 활용하여 Circuit Breaking 기능을 제공한다. **Destination Rule**을 활용하여 각 Service 마다 **개별의 Circuit Breaking 규칙**을 설정할 수 있으며, 필요에 따라서는 **Global Circuit Breaking 규칙**도 설정 가능하다. Circuit Breaking은 **Client Pod의 Sidecar Proxy** (Envoy)에서 동작한다. 따라서 Client Pod에 Sidecar Proxy가 Injection되어 동작하지 않으면 Circuit Breaking이 동작하지 않는다.

### 1.1. Circuit Breaking을 위한 Destination Rule Spec

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

Connection Pool은 Client Pod의 Sidecar Proxy에서 이용할 수 있는 **최대 Connection의 개수** 또는 **Request의 대기 개수**를 정의한다. Connection Pool의 Client에서 많은 요청이 발생하여 Client Pool에 설정된 이상이 필요할 경우에는 Circuit Breaking이 동작하며, Client의 요청은 Client Pod의 Sidecar Proxy에서 중단된다. Connection Pool에서 제공하는 주요 설정들은 다음과 같다.

* `tcp.maxConnections` : TCP Connection의 최대 개수를 의미한다.
* `tcp.connectTimeout` : TCP Connection을 맺는데 걸리는 최대 시간. 기본값은 10초이다.
* `tcp.maxConnectionDuration` : TCP Connection을 유지할 수 있는 최대 시간. 설정하지 않으면 최대 유지 시간에 제한이 없어진다.
* `tcp.idleTimeout` : TCP Idle Timeout 시간. 기본값은 1시간 이며, 0s (0초)로 설정하는 경우 제한이 없어진다.
* `http.http1MaxPendingRequests` : HTTP/1.1 요청의 최대 대기 개수를 의미한다.
* `http.maxRequestsPerConnection` : 각 TCP Connection당 최대 요청 개수를 의미한다.
* 

또한 Destination Rule 규칙은 각 Client Pod에 별개로 적용된다. 예를들어 [File 1]에서는 `trafficPolicy.connectionPool.tcp.maxConnections: 1`이 설정되어 있는데, 이는 Client Pod의 Sidecar Proxy에서 Server Pod로 전달되는 최대 TCP Connection의 개수를 1개로 제한하는 것을 의미하며, 각 Client Pod의 Sidecar Proxy마다 별도로 적용된다. 즉 Client Pod가 5개라면 Server Pod로 전달되는 TCP Connection의 개수는 최대 5개가 된다.

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

## 2. 참조

* Istio Circuit Breaking : [https://istio.io/latest/docs/tasks/traffic-management/circuit-breaking/](https://istio.io/latest/docs/tasks/traffic-management/circuit-breaking/)
* Istio Destination Rule Cross Namespace : [https://learncloudnative.com/blog/2023-02-03-global-dr](https://learncloudnative.com/blog/2023-02-03-global-dr)
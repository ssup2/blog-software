---
title: Istio Circuit Breaking
draft: true
---

## 1. Istio Circuit Breaking

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

Istio는 Sidecar Proxy (Envoy)를 활용하여 Circuit Breaking 기능을 제공한다. Circuit Breaking은 Destination Rule에 

### 1.1. Sidecar Proxy (Envoy) Access Log

```text {caption="[Text 1] Sidecar Proxy (Envoy) Access Log"}
[2025-06-01T15:37:04.857Z] "GET /get HTTP/1.1" 503 UO upstream_reset_before_response_started{overflow} - "-" 0 81 0 - "-" "fortio.org/fortio-1.69.5" "d4e65b2b-3a80-9caa-a6ca-df79908d4d7e" "httpbin:8000" "-" outbound|8000||httpbin.default.svc.cluster.local - 10.96.243.7:8000 10.244.2.30:59002 - default
[2025-06-01T15:37:04.857Z] "GET /get HTTP/1.1" 503 UO upstream_reset_before_response_started{overflow} - "-" 0 81 0 - "-" "fortio.org/fortio-1.69.5" "431d0cda-450d-9d54-8edd-c835cddcfb2c" "httpbin:8000" "-" outbound|8000||httpbin.default.svc.cluster.local - 10.96.243.7:8000 10.244.2.30:59006 - default
[2025-06-01T15:37:04.858Z] "GET /get HTTP/1.1" 503 UO upstream_reset_before_response_started{overflow} - "-" 0 81 0 - "-" "fortio.org/fortio-1.69.5" "1c44aff2-e93e-98d1-a690-5f8eabfe0315" "httpbin:8000" "-" outbound|8000||httpbin.default.svc.cluster.local - 10.96.243.7:8000 10.244.2.30:59018 - default
[2025-06-01T15:37:04.814Z] "GET /get HTTP/1.1" 200 - via_upstream - "-" 0 621 94 63 "-" "fortio.org/fortio-1.69.5" "f47fa353-177d-9834-ac08-5c5be28f4593" "httpbin:8000" "10.244.1.27:8080" outbound|8000||httpbin.default.svc.cluster.local 10.244.2.30:42658 10.96.243.7:8000 10.244.2.30:58932 - default
[2025-06-01T15:37:04.909Z] "GET /get HTTP/1.1" 200 - via_upstream - "-" 0 621 1 1 "-" "fortio.org/fortio-1.69.5" "43e95e7a-20f3-95f4-b63c-42defe29f27e" "httpbin:8000" "10.244.1.27:8080" outbound|8000||httpbin.default.svc.cluster.local 10.244.2.30:42672 10.96.243.7:8000 10.244.2.30:58932 - default
[2025-06-01T15:37:04.911Z] "GET /get HTTP/1.1" 200 - via_upstream - "-" 0 621 0 0 "-" "fortio.org/fortio-1.69.5" "602fe5bd-6564-9bab-b4c6-e87ad31776c4" "httpbin:8000" "10.244.1.27:8080" outbound|8000||httpbin.default.svc.cluster.local 10.244.2.30:42686 10.96.243.7:8000 10.244.2.30:58932 - default
```

[Text 1]은 Client Pod의 Sidecar Proxy (Envoy)에서 생성된 Access Log의 예제를 나타내고 있다. Client Pod의 Sidecar Proxy에서 Circuit Breaking이 동작해도 기본적으로는 어떠한 Log도 남지 않으며, Client Pod의 Sidecar Proxy에 **Access Log를 활성화**하면 해당 Log를 확인할 수 있다. Circuit Breaking이 동작하면 `503` 응답이 Client에 전달되는 것을 확인할 수 있다. 또한 Envoy의 `UO (UpstreamOverflow)` Response Flag도 같이 확인 할 수 있다.

### 1.2. Global Circuit Breaking

## 2. 참조

* Istio Circuit Breaking : [https://istio.io/latest/docs/tasks/traffic-management/circuit-breaking/](https://istio.io/latest/docs/tasks/traffic-management/circuit-breaking/)
* Istio Destination Rule Cross Namespace : [https://learncloudnative.com/blog/2023-02-03-global-dr](https://learncloudnative.com/blog/2023-02-03-global-dr)
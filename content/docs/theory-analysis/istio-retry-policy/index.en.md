---
title: Istio Retry Policy
---

## 1. Istio Retry Policy

Istio's Retry Policy provides retry functionality using Sidecar Proxy (Envoy). Retry Policy operates in the **Client Pod's Sidecar Proxy** (Envoy). Therefore, if the Client Pod's Sidecar Proxy is not injected and running, retry will not work.

### 1.1. Applying Retry Policy

```yaml {caption="[File 1] Applying Retry Policy"}
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: httpbin
spec:
  hosts:
  - httpbin
  http:
  - route:
    - destination:
        host: httpbin
    timeout: 5s
    retries:
      attempts: 3
      perTryTimeout: 2s
      retryOn: 503,reset,connect-failure,refused-stream
      retryRemoteLocalities: true
```

Retry Policy can be configured through the `http.retries` field of Virtual Service. The meaning of each field is as follows. [File 1] shows an example of applying Retry Policy.

* `attempts` : Sets the maximum number of retries. Although it may vary depending on the `http.timeout` field and `perTryTimeout` field values, the maximum number of requests is `attempts` field value + 1. Therefore, if the attempts value is `3`, a maximum of 4 requests are sent. The default value is `2`, and if set to `0`, no retry is performed.
* `perTryTimeout` : Sets the timeout for each retry. It is set with units in the form of `1h`, `1m`, `1s`, `1ms`, and the minimum value is `1ms`. If no value is specified, the same timeout value as the `http.timeout` field is set.
* `retryOn` : Sets retry conditions. You can set the following HTTP and gRPC Retry Policy conditions provided by Envoy. The default value is `connect-failure,refused-stream,unavailable,cancelled`. The main settings are as follows.
  * HTTP Retry Policy
    * `<Status Code>` : Performs retry when the corresponding Status Code occurs.
    * `5XX` : Performs retry when HTTP Status Code `5XX` occurs.
    * `gateway-error` : Performs retry when HTTP Status Code `502`, `503`, `504` occurs.
    * `reset` : Performs retry when the server is no longer able to send responses. This includes cases where the connection with the server is broken, Reset, Read Timeout, etc.
    * `reset-before-request` : Performs retry when the server is no longer able to send responses before sending the request. This includes cases where the connection with the server is broken, Reset, Read Timeout, etc.
    * `connect-failure` : Performs retry when connection with the server fails.
    * `envoy-ratelimited` : When a request sent to the server is rejected by Envoy's Rate Limit, the client receives a response including the `x-envoy-ratelimited` header. In this case, retry is performed.
    * `retriable-4xx` : Performs retry when HTTP Status Code `4XX` occurs. Currently, only `409` Status Code is included in retry conditions.
    * `refused-stream` : Performs retry when the server returns HTTP/2's `REFUSED_STREAM` Error Code.
  * gRPC Retry Policy
    * `cancelled` : Performs retry when gRPC Status Code `CANCELLED (0)` occurs. This means the client cancelled the request.
    * `deadline-exceeded` : Performs retry when gRPC Status Code `DEADLINE_EXCEEDED (4)` occurs. This means the request timed out.
    * `internal` : Performs retry when gRPC Status Code `INTERNAL (13)` occurs. This means an error occurred inside the server.
    * `resource-exhausted` : Performs retry when gRPC Status Code `RESOURCE_EXHAUSTED (8)` occurs. This means the client sent too many requests or the server received too many requests, causing capacity overflow, memory shortage, etc.
    * `unavailable` : Performs retry when gRPC Status Code `UNAVAILABLE (14)` occurs. This means the server is down or unreachable.
* `retryRemoteLocalities` : Sets whether to allow retry to server pods in other localities. The default value is `false`.
* `retryIgnorePreviousHosts` : Sets whether to perform retry excluding previously failed hosts (server pods). The default value is `true`.
* `backoff` : Sets the waiting time between retry attempts. It is set with units in the form of `1h`, `1m`, `1s`, `1ms`, and the default value is `25ms`.

### 1.2. Envoy Access Log

```yaml {caption="[File 2] Istio Access Log Format for Retry Policy", linenos=table}
  mesh: |-
    accessLogFile: /dev/stdout
    accessLogEncoding: TEXT
    accessLogFormat: |
      [%START_TIME%] "%REQ(:METHOD)% %REQ(X-ENVOY-ORIGINAL-PATH?:PATH)%" %RESPONSE_CODE% retry_attempts=%UPSTREAM_REQUEST_ATTEMPT_COUNT% flags=%RESPONSE_FLAGS% details=%RESPONSE_CODE_DETAILS%
```

The number of request retries caused by Istio's Retry Policy is recorded in `UPSTREAM_REQUEST_ATTEMPT_COUNT` of Envoy Access Log. However, since it is not included in the default log format, you need to set the Access Log Format separately. [File 2] shows an example of applying the Istio Access Log Format configured to include request retry counts to the Istio Mesh Config.

The `UPSTREAM_REQUEST_ATTEMPT_COUNT` field includes the first attempt, so if 3 retries occur, `4` is recorded. On the other hand, if `0` is recorded, it means that not only no retry occurred but also no request was sent at all.

```yaml {caption="[File 3] test-retry-policy.yaml", linenos=table}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpbin
spec:
  replicas: 1
  selector:
    matchLabels:
      app: httpbin
  template:
    metadata:
      labels:
        app: httpbin
    spec:
      containers:
      - name: helloworld
        image: docker.io/kennethreitz/httpbin:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: httpbin
spec:
  ports:
  - port: 80
    name: http
  selector:
    app: httpbin
---
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: httpbin
spec:
  hosts:
  - httpbin
  http:
  - route:
    - destination:
        host: httpbin
    retries:
      attempts: 3
      perTryTimeout: 2s
      retryOn: "503"
---
apiVersion: v1
kind: Pod
metadata:
  name: my-shell
spec:
  containers:
  - name: netshoot
    image: nicolaka/netshoot:latest
    command:
    - sleep
    - infinity
    tty: true
    stdin: true
```

[File 3] shows an example of Kubernetes Manifest for Retry Policy testing. It consists of `httpbin` Deployment that serves as a server, along with Service and Virtual Service. The `httpbin` Virtual Service has Retry Policy applied, configured to perform 3 retries only when `503` Status Code occurs. It also includes a `my-shell` pod that serves as a client.

```shell {caption="[Shell 1] Retry Policy Test"}
$ kubectl apply -f test-retry-policy.yaml
$ kubectl exec -it my-shell -- bash

(my-shell)# curl -I http://httpbin/status/501
HTTP/1.1 501 Not Implemented
server: envoy
date: Sat, 27 Sep 2025 01:13:56 GMT
content-type: text/html; charset=utf-8
access-control-allow-origin: *
access-control-allow-credentials: true
content-length: 0
x-envoy-upstream-service-time: 234

(my-shell)# curl -I http://httpbin/status/502
HTTP/1.1 502 Bad Gateway
server: envoy
date: Sat, 27 Sep 2025 01:14:00 GMT
content-type: text/html; charset=utf-8
access-control-allow-origin: *
access-control-allow-credentials: true
content-length: 0
x-envoy-upstream-service-time: 24

(my-shell)# curl -I http://httpbin/status/503
HTTP/1.1 503 Service Unavailable
server: envoy
date: Sat, 27 Sep 2025 01:14:06 GMT
content-type: text/html; charset=utf-8
access-control-allow-origin: *
access-control-allow-credentials: true
content-length: 0
x-envoy-upstream-service-time: 69
```

[Shell 1] shows an example of applying the Kubernetes Manifest for Retry Policy testing and sending requests to the `httpbin` service from inside the `my-shell` pod. The `httpbin` service returns the corresponding Status Code when a request is sent to the `/status/{status_code}` path. Therefore, the curl commands receive `501`, `502`, and `503` Status Code responses respectively.

```shell {caption="[Shell 2] my-shell istio-proxy Log"}
$ kubectl logs my-shell istio-proxy
[2025-09-27T01:13:55.899Z] "HEAD /status/501" 501 retry_attempts=1 flags=- details=via_upstream
[2025-09-27T01:14:00.419Z] "HEAD /status/502" 502 retry_attempts=1 flags=- details=via_upstream
[2025-09-27T01:14:05.930Z] "HEAD /status/503" 503 retry_attempts=4 flags=URX details=via_upstream
```
[Shell 2] shows an example of checking the istio-proxy log of the `my-shell` pod afterwards. Since no retry occurred for 501, 502 Status Codes, `retry_attempts=1` was recorded, and since retry occurred for 503 Status Code, `retry_attempts=4` was recorded.

## 2. References

* Istio Retry Policy : [https://istio.io/latest/docs/reference/config/networking/virtual-service/#HTTPRetry](https://istio.io/latest/docs/reference/config/networking/virtual-service/#HTTPRetry)
* Envoy HTTP Retry Policy : [https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/router_filter#x-envoy-retry-on](https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/router_filter#x-envoy-retry-on)
* Envoy GRPC Retry Policy : [https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/router_filter#x-envoy-retry-grpc-on](https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/router_filter#x-envoy-retry-grpc-on)

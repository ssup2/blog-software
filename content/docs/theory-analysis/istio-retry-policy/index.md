---
title: Istio Retry Policy
---

## 1. Istio Retry Policy

Istio의 Retry Policy는 Sidecar Proxy (Envoy)를 활용하여 Retry 기능을 제공한다. Retry Policy는 **Client Pod의 Sidecar Proxy** (Envoy)에서 동작한다. 따라서 Client Pod에 Sidecar Proxy가 Injection되어 동작하지 않으면 Retry가 동작하지 않는다.

### 1.1. Retry Policy 적용

```yaml {caption="[File 1] Retry Policy 적용"}
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

Retry Policy는 Virtual Service의 `http.retries` Field를 통해서 설정할 수 있다. 각 Field의 의미는 다음과 같다. [File 1]은 Retry Policy를 적용한 예제를 나타내고 있다. 

* `attempts` : 최대 재시도 횟수를 설정한다. `http.timeout` Field와 `perTryTimeout` Field 값에 따라서 달라질수 있지만, 최대 요청 횟수는 `attempts` Field 값 + 1이다. 따라서 attempts의 값이 `3`이라면 최대 4번의 요청이 전송된다. 기본값은 `2`이며, `0`으로 설정하는 경우 재시도가 수행되지 않는다.
* `perTryTimeout` : 각 재시도별 Timeout을 설정한다. `1h`, `1m`, `1s`, `1ms` 형태로 단위와 함께 설정하며, 최소값은 `1ms`이다. 값을 명시하지 않으면 `http.timeout` Field와 동일한 Timeout 값이 설정된다.
* `retryOn` : 재시도 조건을 설정한다. Envoy에서 제공하는 다음과 같은 HTTP, GRPC Retry Policy 조건들을 설정할 수 있다. 기본값은 `connect-failure,refused-stream,unavailable,cancelled` 이다. 주요 설정은 다음과 같다.
  * HTTP Retry Policy
    * `<Status Code>` : 해당 Status Code 발생 시 재시도를 수행한다.
    * `5XX` : HTTP Status Code `5XX` 발생 시 재시도를 수행한다.
    * `gateway-error` : HTTP Status Code `502`, `503`, `504` 발생 시 재시도를 수행한다.
    * `reset` : Server가 더 이상 응답을 보내지 못하는 상태가 되었을 때 재시도를 수행한다. Server와의 Connection이 끊어진 경우, Reset, Read Timeout 등이 발생한 경우 모두 재시도 조건에 포함한다.
    * `reset-before-request` : Request를 전송하기 전에 Server가 더 이상 응답을 보내지 못하는 상태가 되었을 때 재시도를 수행한다. Server와의 Connection이 끊어진 경우, Reset, Read Timeout 등이 발생한 경우 모두 재시도 조건에 포함한다.
    * `connect-failure` : Server와의 Connection이 실패한 경우 재시도를 수행한다.
    * `envoy-ratelimited` : Server로 전달한 요청이 Envoy의 Rate Limit에 의해서 거절되는 경우, Client는 `x-envoy-ratelimited` Header를 포함하여 응답을 받는다. 이 경우 재시도를 수행한다.
    * `retriable-4xx` : HTTP Status Code `4XX` 발생 시 재시도를 수행한다. 현재는 `409` Status Code만 재시도 조건에 포함된다.
    * `refused-stream` : Server가 HTTP/2의 `REFUSED_STREAM` Error Code를 반환하는 경우 재시도를 수행한다.
  * gRPC Retry Policy
    * `cancelled` : gRPC Status Code `CANCELLED (0)` 발생 시 재시도를 수행한다. Client가 요청을 취소한 경우를 의미한다.
    * `deadline-exceeded` : gRPC Status Code `DEADLINE_EXCEEDED (4)` 발생 시 재시도를 수행한다. 요청이 Timeout이 발생한 경우를 의미한다.
    * `internal` : gRPC Status Code `INTERNAL (13)` 발생 시 재시도를 수행한다. Server 내부에서 오류가 발생한 경우를 의미한다.
    * `resource-exhausted` : gRPC Status Code `RESOURCE_EXHAUSTED (8)` 발생 시 재시도를 수행한다. Client가 너무 많은 요청을 보내거나, Server가 너무 많은 요청을 받아 용량 초과, 메모리 부족 등 리소스 소진 상태를 의미한다.
    * `unavailable` : gRPC Status Code `UNAVAILABLE (14)` 발생 시 재시도를 수행한다. Server가 다운되었거나 연결 불가.
* `retryRemoteLocalities` : 다른 Locality의 Server Pod에 재시도 허용 여부를 설정한다. 기본값은 `false`이다.
* `retryIgnorePreviousHosts` : 이전에 실패한 Host(Server Pod)를 제외하고 재시도를 수행할지 설정한다. 기본값은 `true`이다.
* `backoff` : 재시도 횟수 사이의 대기 시간을 설정한다. `1h`, `1m`, `1s`, `1ms` 형태로 단위와 함께 설정하며, 기본값은 `25ms`이다.

### 1.2. Envoy Access Log

```yaml {caption="[File 2] Istio Access Log Format for Retry Policy", linenos=table}
  mesh: |-
    accessLogFile: /dev/stdout
    accessLogEncoding: TEXT
    accessLogFormat: |
      [%START_TIME%] "%REQ(:METHOD)% %REQ(X-ENVOY-ORIGINAL-PATH?:PATH)%" %RESPONSE_CODE% retry_attempts=%UPSTREAM_REQUEST_ATTEMPT_COUNT% flags=%RESPONSE_FLAGS% details=%RESPONSE_CODE_DETAILS%
```

Istio의 Retry Policy로 인해서 발생한 요청 재시도 횟수는 Envoy Access Log의 `UPSTREAM_REQUEST_ATTEMPT_COUNT`에 기록된다. 다만 기본 Log Format에는 포함되어 있지 않기 때문에, 별도로 Access Log Format을 설정해야 한다. [File 2]는 요청 재시도 횟수를 포함하도록 설정한 Istio Access Log Format을 Istio Mesh Config에 적용하는 예시를 나타내고 있다.

`UPSTREAM_REQUEST_ATTEMPT_COUNT` Field는 첫번째 시도도 포함한 값이기 때문에, 만약 3번의 재시도가 발생한 경우에는 `4`가 기록된다. 반면에 `0`이 남는다면 재시도 뿐만 아니라 한번도 요청 전송이 발생하지 않은 경우를 의미한다.

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

[File 3]은 Retry Policy Test를 위한 Kubernetes Manifest 예시를 나타내고 있다. Server 역할을 수행하는 `httpbin` Deployment와 함께 Service, Virtual Service를 구성하고 있다. `httpbin` Virtual Service에는 Retry Policy가 적용되어 있으며, `503` Status Code가 발생하는 경우에만 3번의 재시도를 수행하도록 설정되어 있다. 또한 Client 역할을 수행하는 `my-shell` Pod을 하나 구성하고 있다. 

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

[Shell 1]은 Retry Policy Test를 위한 Kubernetes Manifest를 적용하고, `my-shell` Pod의 내부에서 `httpbin` Service에 요청을 보내는 예시를 나타내고 있다. `httpbin` Service는 `/status/{status_code}` Path에 요청을 보내면 해당 Status Code를 반환한다. 따라서 curl 명령어는 각각 `501`, `502`, `503` Status Code를 응답을 받는다.

```shell {caption="[Shell 2] my-shell istio-proxy Log"}
$ kubectl logs my-shell istio-proxy
[2025-09-27T01:13:55.899Z] "HEAD /status/501" 501 retry_attempts=1 flags=- details=via_upstream
[2025-09-27T01:14:00.419Z] "HEAD /status/502" 502 retry_attempts=1 flags=- details=via_upstream
[2025-09-27T01:14:05.930Z] "HEAD /status/503" 503 retry_attempts=4 flags=URX details=via_upstream
```
[Shell 2]는 이후에 `my-shell` Pod의 istio-proxy Log를 확인하는 예시를 나타내고 있다. 501, 502 Status Code는 재시도가 발생하지 않았기 때문에 `retry_attempts=1`이 기록되었으며, 503 Status Code는 재시도가 발생했기 때문에 `retry_attempts=4`가 기록된걸 확인할 수 있다.

## 2. 참고

* Istio Retry Policy : [https://istio.io/latest/docs/reference/config/networking/virtual-service/#HTTPRetry](https://istio.io/latest/docs/reference/config/networking/virtual-service/#HTTPRetry)
* Envoy HTTP Retry Policy : [https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/router_filter#x-envoy-retry-on](https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/router_filter#x-envoy-retry-on)
* Envoy GRPC Retry Policy : [https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/router_filter#x-envoy-retry-grpc-on](https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/router_filter#x-envoy-retry-grpc-on)
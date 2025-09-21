---
title: Istio Retry Policy
draft: true
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
* `retryOn` : 재시도 조건을 설정한다. Envoy에서 제공하는 다음과 같은 HTTP, GRPC Retry Policy 조건들을 설정할 수 있다. 기본값은 `connect-failure,refused-stream,unavailable,cancelled`
  * HTTP Retry Policy
    * `503` : Service Unavailable
  * `reset` : Connection Reset
  * `connect-failure` : Connection Failure
  * `refused-stream` : Refused Stream
* `retryRemoteLocalities` : 다른 Locality의 Server Pod에 재시도 허용 여부를 설정한다. 기본값은 `false`이다.
* `retryIgnorePreviousHosts` : 이전에 실패한 Host(Server Pod)를 제외하고 재시도를 수행할지 설정한다. 기본값은 `true`이다.
* `backoff` : 재시도 횟수 사이의 대기 시간을 설정한다. `1h`, `1m`, `1s`, `1ms` 형태로 단위와 함께 설정하며, 기본값은 `25ms`이다.

### 1.2. Istio Access Log

```yaml {caption="[File 1] Test Environment Manifest", linenos=table}
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
      retryOn: reset,connect-failure,refused-stream
      retryRemoteLocalities: true
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

## 2. 참고

* Istio Retry Policy : [https://istio.io/latest/docs/reference/config/networking/virtual-service/#HTTPRetry](https://istio.io/latest/docs/reference/config/networking/virtual-service/#HTTPRetry)
* Envoy HTTP Retry Policy : [https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/router_filter#x-envoy-retry-on](https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/router_filter#x-envoy-retry-on)
* Envoy GRPC Retry Policy : [https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/router_filter#x-envoy-retry-grpc-on](https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/router_filter#x-envoy-retry-grpc-on)
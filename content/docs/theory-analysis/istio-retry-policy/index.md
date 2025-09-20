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

* `attempts` : 최대 재시도 횟수를 설정한다. 여기서 재시도 횟수는 원래 요청을 포함하지 않는다. 따라서 attempts의 값이 `3`이라면 최대 4번의 요청이 전송된다.
* `perTryTimeout` : 각 재시도별 타임아웃을 설정한다. `1h, 1m, 1s, 1ms` 형태로 설정한다. 값을 명시하지 않으면 `http.timeout` Field와 동일한 Timeout 값이 설정된다. [File 1]의 예제에서는 `5s`가 설정된다.
* `retryOn` : 재시도 조건을 설정한다.
* `retryRemoteLocalities` : 다른 지역으로 재시도 허용 여부를 설정한다.
* `retryIgnorePreviousHosts` : 이전 요청을 무시하고 재시도 여부를 설정한다.
* `backoff` : 

### 1.2. Test 환경 구성

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
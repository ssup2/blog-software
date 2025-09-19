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
    retries:
      attempts: 3
      perTryTimeout: 2s
      retryOn: reset,connect-failure,refused-stream
      retryRemoteLocalities: true
```

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
* Envoy Retry Policy : [https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/router_filter#x-envoy-retry-on](https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/router_filter#x-envoy-retry-on)
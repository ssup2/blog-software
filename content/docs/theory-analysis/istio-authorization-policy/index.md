---
title: Istio Authorization Policy
draft: true
---

## 1. Istio Authorization Policy

```yaml {caption="[Code 1] Linux NFS4 Mount 함수", linenos=table}
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-user1
  namespace: default
spec:
  selector:
    matchLabels:
      app: my-service
  action: ALLOW | DENY | CUSTOM
  rules:
...
```

### 1.1. from Rules

```yaml {caption="[Code 1] Linux NFS4 Mount 함수", linenos=table}
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-user1
  namespace: default
spec:
  selector:
    matchLabels:
      app: my-service
  action: ALLOW
  rules:
  - from:
    - source:
        namespaces: ["test"]
    - source:
        ipBlocks: ["10.0.0.0/24"]
    - source:
        principals: ["cluster.local/ns/default/sa/user1"]
    - source:
        requestPrincipals: ["user1"]
    - source:
        remoteIpBlocks: ["20.0.0.0/24"]
```

### 1.2. to Rules

```yaml {caption="[Code 1] Linux NFS4 Mount 함수", linenos=table}
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-read-only
  namespace: default
spec:
  selector:
    matchLabels:
      app: my-api
  rules:
  - to:
    - operation:
        methods: ["GET", "POST"]
        paths: ["/api/v1/data"]
        hosts: ["api.example.com", "api.example2.com"]
    - 
```

### 1.3. Custom

### 1.4. vs Network Policy

Istio Authorization Policy와 유사한 Kubernetes Object중에 하나는 Network Policy가 존재한다. Network Policy 또한 Pod와 Pod 사이의 통신 또는 Pod와 외부 사이의 통신을 제어하는데 이용된다. 다만 Istio Authorization Policy는 **Network Layer 7**에서 동작하는 반면 Network Policy는 **Network Layer 3/4**에서 동작한다.

```yaml {caption="[Code 1] Linux NFS4 Mount 함수", linenos=table}

```

## 2. 참조

* Istio Authorization Policy : [https://istio.io/latest/docs/reference/config/security/authorization-policy/](https://istio.io/latest/docs/reference/config/security/authorization-policy/)
* Istio Authorization Policy : [https://nginxstore.com/blog/istio/istio-authorization-policy-%ED%99%9C%EC%9A%A9-deny-allow-%EC%A0%91%EA%B7%BC-%EC%A0%9C%ED%95%9C-%EA%B5%AC%EC%84%B1-%EA%B0%80%EC%9D%B4%EB%93%9C/](https://nginxstore.com/blog/istio/istio-authorization-policy-%ED%99%9C%EC%9A%A9-deny-allow-%EC%A0%91%EA%B7%BC-%EC%A0%9C%ED%95%9C-%EA%B5%AC%EC%84%B1-%EA%B0%80%EC%9D%B4%EB%93%9C/)
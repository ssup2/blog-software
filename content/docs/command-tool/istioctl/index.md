---
title: istioctl
draft: true
---

istioctl의 사용법을 정리한다.

## 1. istioctl

### 1.1. istioctl dashboard proxy [Pod]

Pod의 Envoy Sidecar Proxy의 Web에 접근가능하도록 Port Forwarding을 수행한다. Envoy Sidecar Proxy가 존재하는 Pod를 대상으로 `kubectl port-forward [Pod] 15000:15000` 명령어와 동일한 역할을 수행한다.

```shell
$ istioctl dashboard proxy details-v1-79dfbd6fff-jd2n7
http://localhost:15000
```

### 1.2. istioctl dashboard istiod [Istiod Pod]

istiod Debug의 Web에 접근가능하도록 Port Forwarding을 수행한다. `kubectl -n istio-system port-forward [Istiod Pod] 15014:15014` 명령어와 동일한 역할을 수행한다.

```shell
$ istioctl -n istio-system dashboard istiod-debug istiod-b877844fb-bw4qx
http://localhost:15014/debug
```

### 1.3. istioctl analyze [Istio Ingress Pod]

### 1.4. istioctl admin log [Istio Ingress Pod]

### 1.5. istioctl validate [Istio Ingress Pod]

---
title: istioctl
---

istioctl의 사용법을 정리한다.

## 1. istioctl

### 1.1. istioctl dashboard proxy [Pod]

Pod의 Envoy Sidecar Proxy의 Web UI에 접근가능하도록 Port Forwarding을 수행한다. Envoy Sidecar Proxy가 존재하는 Pod를 대상으로 `kubectl port-forward [Pod] 15000:15000` 명령어와 동일하다.

```shell
$ istioctl dashboard proxy details-v1-79dfbd6fff-jd2n7
http://localhost:15000
```

### 1.2. istioctl 

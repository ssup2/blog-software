---
title: istioctl
draft: true
---

This document summarizes the usage of `istioctl`.

## 1. istioctl

### 1.1. istioctl dashboard proxy [Pod]

Performs port forwarding to access the web of the Envoy sidecar proxy of the pod. Performs the same role as the `kubectl port-forward [Pod] 15000:15000` command for pods with Envoy sidecar proxy.

```shell
$ istioctl dashboard proxy details-v1-79dfbd6fff-jd2n7
http://localhost:15000
```

### 1.2. istioctl dashboard istiod [Istiod Pod]

Performs port forwarding to access the web of istiod debug. Performs the same role as the `kubectl -n istio-system port-forward [Istiod Pod] 15014:15014` command.

```shell
$ istioctl -n istio-system dashboard istiod-debug istiod-b877844fb-bw4qx
http://localhost:15014/debug
```

### 1.3. istioctl analyze [Istio Ingress Pod]

### 1.4. istioctl admin log [Istio Ingress Pod]

### 1.5. istioctl validate [Istio Ingress Pod]


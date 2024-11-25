---
title: Kubernetes Helm 설치 / Ubuntu 18.04 환경
---

## 1. 설치 환경

설치 환경은 다음과 같다.
* Kubernetes 1.12
  * Network Addon : cilium 이용

## 2. Helm 설치

```shell
$ snap install helm --classic
```

Helm Package를 설치한다.

```shell
$ kubectl create serviceaccount --namespace kube-system tiller
$ kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
$ helm init --service-account tiller
```

Helm Tiller를 설치한다.

## 3. 참조

* Helm Issue : [https://github.com/helm/helm/issues/3055](https://github.com/helm/helm/issues/3055)
---
title: Kubernetes Helm Installation / Ubuntu 18.04 Environment
---

## 1. Installation Environment

The installation environment is as follows:
* Kubernetes 1.12
  * Network Addon : Using cilium

## 2. Helm Installation

```shell
$ snap install helm --classic
```

Install Helm package.

```shell
$ kubectl create serviceaccount --namespace kube-system tiller
$ kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
$ helm init --service-account tiller
```

Install Helm Tiller.

## 3. References

* Helm Issue : [https://github.com/helm/helm/issues/3055](https://github.com/helm/helm/issues/3055)

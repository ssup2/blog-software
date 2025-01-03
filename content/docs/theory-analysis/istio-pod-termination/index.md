---
title: Istio Pod Termination
draft: true
---

## 1. with Istio Sidecar

Istio를 이용하는 경우 Pod 종료시에 Istio의 Sidecar Container로 우아하게 종료되어야 한다. Istio의 Sidecar Container인 Envoy의 경우에도 `SIGTERM` Signal을 받으면 신규 Request를 처리하지 않으며, 

기존에 처리중인 Request를 완료하고 종료된다. 이때 Istio의 `terminationDrainDuration` 설정값 만큼 처리중인 Request가 완료될때까지 대기하며 이후에는 강제로 종료된다. 따라서 Pod의 `terminationGracePeriodSeconds`의 시간이 반드시 `terminationDrainDuration` 시간보다 커야한다. 만약에 크지 않다면 `SIGKILL` Signal에 의해서 Sidecar Container도 강제로 종료되기 때문이다.

``` {caption="[File 3] Istio terminationDrainDuration Configuration", linenos=table}
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  meshConfig:
    defaultConfig:
      drainDuration: 45s
      terminationDrainDuration: 30s
...
```

[File 3]은 Istio Operator 이용시 `terminationDrainDuration`을 60초로 설정하는 예시를 나타내고 있으며, 기본값은 30초이다.

## 2. 참조

* Istio Sidecar : [https://github.com/hashicorp/consul-k8s/issues/650](https://github.com/hashicorp/consul-k8s/issues/650)
* Istio Gracefully Shutown : [https://github.com/istio/istio/issues/47779](https://github.com/istio/istio/issues/47779)
* Istio EXIT_ON_ZERO_ACTIVE_CONNECTIONS : [https://umi0410.github.io/blog/devops/istio-exit-on-zero-active-connections/](https://umi0410.github.io/blog/devops/istio-exit-on-zero-active-connections/)

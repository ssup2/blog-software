---
title: Istio Pod Termination
draft: true
---

## 1. Istio Pod Gracefully Termination

{{< figure caption="[Figure 1] Istio Pod Component" src="images/istio-pod-component.png" width="600px" >}}

Istio 환경에서 App Container가 안정적으로 Request를 처리하며 Gracefully Termination을 수행하기 위해서는, Istio 환경에서의 Pod의 종료 과정을 완전히 이해하고 적절하게 Pod를 설정해야 한다. [Figure 1]은 Istio 환경에서의 App Pod의 구성 요소를 나타내고 있다. App Pod에는 App을 동작시키는 Container와 함께 App Container에서 발생하는 모든 Traffic을 송수신하는 Sidecar Container인 Envoy Proxy Container가 같이 동작한다.

Envoy Proxy Container 내부에는 **pilot-agent**와 Envory Proxy와 동작하며, pilot-agent가 Init Process로 동작하며 가장 먼져 실행되고 이후에 pilot-agent는 Envoy Proxy를 실행한다. pilot-agent는 Istio의 Control Plane 역할을 수행하는 **istiod**와 통신하며 Envoy Proxy를 제어하는 역할을 수행하며, App Pod가 종료될때 kubelet으로부터 `SIGTERM` Singal을 수신하여 Envoy Proxy를 종료시키는 역할도 수행한다. Envoy Proxy Container의 Init Process가 pilot-agent이기 때문에 `SIGTERM` Signal은 pilot-agent만 수신하며, Envoy Proxy는 수신하지 않는다.

Istio 환경에서 App Pod의 Grace 과정은 App Container와 Envoy Proxy Container로 구분할 수 있다.

### 1.1. App Container Termination

{{< figure caption="[Figure 2] App Container Gracefully Termination" src="images/istio-app-container-termination-with-gracefully-termination.png" width="1000px" >}}

[Figure 2]는 App Container의 Gracefully Termination을 수행하는 과정을 나타내고 있다. App Container의 Gracefully Termination 과정은 Istio 환경이 아닌 일반적인 Pod 내부의 App Container의 Gracefully Termination 과정과 완전히 동일하며, 다음의 3가지 설정을 신경써야 한다.

* Endpoint Slice Propagatio Delay로 인한 
* 

### 1.2. Envoy Proxy Container Termination

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

* `terminationDrainDuration` : Agent가 `SIGTERM`을 받고 envoy가 죽기를 대기하는 시간. 이후에도 죽지 않는다면 강제로 envoy 제거
* `MINIMUM_DRAIN_DURATION` : Agent가 `SIGTERM`을 받은 다음 Connection을 체크하고 envoy를 drain mode로 변환하고 죽이기를 시작하는 시간. prestop hook sleep의 역할을 대신 수행
* `EXIT_ON_ZERO_ACTIVE_CONNECTIONS` : Agent가 proxy의 모든 Connection이 제거되어야 envoy 제거 수행. `MINIMUM_DRAIN_DURATION`가 먼져 적용된 이후에 해당 옵션 적용되며, `terminationDrainDuration` 설정은 무시됨.

## 2. 참조

* Istio Sidecar : [https://github.com/hashicorp/consul-k8s/issues/650](https://github.com/hashicorp/consul-k8s/issues/650)
* Istio Gracefully Shutown : [https://github.com/istio/istio/issues/47779](https://github.com/istio/istio/issues/47779)
* Istio `terminationDrainDuration` : [https://www.alibabacloud.com/help/en/asm/user-guide/configure-a-sidecar-proxy-by-adding-resource-annotations](https://www.alibabacloud.com/help/en/asm/user-guide/configure-a-sidecar-proxy-by-adding-resource-annotations)
* Istio `MINIMUM_DRAIN_DURATION` : [https://github.com/istio/istio/issues/47779](https://github.com/istio/istio/issues/47779)
* Istio `EXIT_ON_ZERO_ACTIVE_CONNECTIONS` : [https://umi0410.github.io/blog/devops/istio-exit-on-zero-active-connections/](https://umi0410.github.io/blog/devops/istio-exit-on-zero-active-connections/)
* Istio `terminationDrainDuration` & `EXIT_ON_ZERO_ACTIVE_CONNECTIONS` : [https://github.com/istio/istio/discussions/49426](https://github.com/istio/istio/discussions/49426)
* Istio pilot-agent : [https://istio.io/latest/docs/reference/commands/pilot-agent/](https://istio.io/latest/docs/reference/commands/pilot-agent/)

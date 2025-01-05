---
title: Istio Pod Gracefully Termination
draft: true
---

## 1. Istio Pod Gracefully Termination

{{< figure caption="[Figure 1] Istio Pod Component" src="images/istio-app-pod-component.png" width="600px" >}}

[Figure 1]은 Istio 환경에서의 App Pod의 구성 요소를 나타내고 있다. 크게 App이 동작하는 App Container와 App Container이 송수신하는 모든 Traffic이 거치는 Sidecar Container인 Envoy Proxy Container로 구분할 수 있다. 따라서 Gracefully Termination도 App Container와 Envoy Container를 나누어 고려해야 한다.

### 1.1. App Container Gracefully Termination

{{< figure caption="[Figure 2] App Container Gracefully Termination" src="images/istio-app-container-gracefully-termination.png" width="1000px" >}}

[Figure 2]는 App Container의 Gracefully Termination을 수행하는 과정을 나타내고 있다. App Container의 Gracefully Termination 과정은 Istio 환경이 아닌 일반적인 Pod 내부의 App Container의 Gracefully Termination 과정과 동일하며, 일반적으로 다음의 3가지 설정을 진행해야 Gracefully Termination을 수행할 수 있다.

* Endpoint Slice Propagation Delay로 인해서 신규 Request를 처리하지 못하는 문제를 해결하기 위한 `sleep` CLI 기반의 preStop Hook
* App에서 `SIGTERM` Signal 수신시 현재 처리하고 있는 Request를 완료한 다음 종료
* App에서 Request를 처리하는 시간보다 큰 시간으로 Pod의 `terminationDrainDuration`을 설정

### 1.2. Envoy Proxy Container Gracefully Termination

Envoy Proxy Container 내부에는 **pilot-agent**와 Envory Proxy가 동작한다. pilot-agent가 Envoy Proxy Container의 Init Process로 동작하여 가장 먼져 실행되고 이후에 pilot-agent는 Envoy Proxy를 실행한다. 따라서 Pod 종료시 `SIGTERM` Signal은 Envoy Proxy Container의 Init Process인 pilot-agent만 수신하며, Envoy Proxy는 수신하지 않는다. `SIGTERM` Signal을 받은 pilot-agent는 Envoy Proxy를 종료시키는 역할도 수행하며, Envoy Proxy Container의 Gracefully Termination을 위해 설정되는 값들은 모두 `SIGTERM` Signal을 수신하는 pilot-agent의 설정값이다.

{{< figure caption="[Figure 3] Envoy Proxy Container Gracefully Termination" src="images/istio-envoy-container-gracefully-termination.png" width="1000px" >}}

[Figure 3]은 Envoy Proxy Container의 Gracefully Termination을 나타내고 있다. `SIGTERM` Signal을 받은 pilot-agent는 곧바로 Envoy Proxy를 Drain Mode로 전환하지 않고 `MINIMUM_DRAIN_DURATION` 설정값의 시간만큼 대기한 이후에 Drain Mode로 전환한다. Envoy Proxy가 Drain Mode로 전환되면 신규 Request를 더이상 수용하지 않기 때문에 Endpoint Slice Propagation Delay로 인한 신규 Request를 처리하지 못하는 문제가 발생할 수 있으며, 이를 해결하기 위해서 `MINIMUM_DRAIN_DURATION` 설정값 만큼 pilot-agents는 대기한 이후에 Envoy Proxy를 Drain Mode로 전환한다. App Container의 PreStop Hook과 동일한 역할을 수행한다.

---

pilot-agent는 Istio의 Control Plane 역할을 수행하는 **istiod**와 통신하며 Envoy Proxy를 제어하는 역할을 수행하며, App Pod가 종료될때 kubelet으로부터 `SIGTERM` Signal을 수신하여 Envoy Proxy를 종료시키는 역할도 수행한다. Envoy Proxy Container의 Init Process가 pilot-agent이기 때문에 `SIGTERM` Signal은 pilot-agent만 수신하며, Envoy Proxy는 수신하지 않는다.


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

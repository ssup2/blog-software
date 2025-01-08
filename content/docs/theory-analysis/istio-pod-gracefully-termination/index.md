---
title: Istio Pod Gracefully Termination
---

## 1. Istio Pod Gracefully Termination

{{< figure caption="[Figure 1] Istio Pod Component" src="images/istio-app-pod-component.png" width="600px" >}}

[Figure 1]은 Istio 환경에서의 App Pod의 구성 요소를 나타내고 있다. 크게 App이 동작하는 App Container와 App Container이 송수신하는 모든 Traffic이 거치는 Sidecar Container인 Envoy Proxy Container로 구분할 수 있다. 따라서 Gracefully Termination도 App Container와 Envoy Container를 나누어 고려해야 한다.

### 1.1. App Container Gracefully Termination

{{< figure caption="[Figure 2] App Container Gracefully Termination" src="images/istio-app-container-gracefully-termination.png" width="1000px" >}}

[Figure 2]는 App Container의 Gracefully Termination 수행 과정을 나타내고 있다. App Container의 Gracefully Termination 과정은 Istio 환경이 아닌 일반적인 Pod 내부의 App Container의 Gracefully Termination 과정과 동일하며, 일반적으로 다음의 3가지 설정을 진행해야 Gracefully Termination을 수행할 수 있다.

* Envoy Proxy Propagation Delay로 인해서 일부의 신규 Request를 처리하지 못하는 문제를 해결하기 위한 `sleep` CLI 기반의 preStop Hook
* App에서 `SIGTERM` Signal 수신시 현재 처리하고 있는 Request를 완료한 다음 종료
* App에서 Request를 처리하는 시간보다 큰 시간으로 Pod의 `terminationGracePeriodSeconds`을 설정

단 `terminationGracePeriodSeconds`은 각 Container에 설정할 수 있는 설정값이 아니라 Pod에 하나의 값만 설정할 수 있는 값이기 때문에 Enovy Proxy Container의 설정값도 같이 고려하여 설정해야 한다.

### 1.2. Envoy Proxy Container Gracefully Termination

Envoy Proxy Container 내부에는 **pilot-agent**와 Envory Proxy가 동작한다. pilot-agent가 Envoy Proxy Container의 Init Process로 동작하여 가장 먼져 실행되고 이후에 pilot-agent는 Envoy Proxy를 실행한다. 따라서 Pod 종료시 `SIGTERM` Signal은 pilot-agent만 수신하며, Envoy Proxy는 수신하지 않는다. `SIGTERM` Signal을 받은 pilot-agent는 Envoy Proxy를 종료시키는 역할도 수행하며, 아래서 소개되는 Envoy Proxy Container의 Gracefully Termination을 위해 설정되는 값들은 모두 `SIGTERM` Signal을 수신하는 pilot-agent의 설정값이다.

Envoy Proxy Container의 Termination 수행 과정은 `EXIT_ON_ZERO_ACTIVE_CONNECTIONS`의 설정 유무에 따라서 달라지며, `EXIT_ON_ZERO_ACTIVE_CONNECTIONS`가 설정되어 있지 않다면 `terminationDrainDuration` 설정값에 따라서 Evony Proxy Container가 종료된다.

#### 1.2.1. terminationDrainDuration

{{< figure caption="[Figure 3] Envoy Proxy Container Termination with terminationDrainDuration" src="images/istio-envoy-container-termination-with-terminationdrainduration.png" width="1000px" >}}

[Figure 3]은 `EXIT_ON_ZERO_ACTIVE_CONNECTIONS`이 설정되지 않은, 즉 `terminationDrainDuration` 설정값에 따라서 Enovy Proxy가 종료되는 과정을 나타내고 있다. `SIGTERM` Signal을 받은 pilot-agents는 Envoy Proxy를 Drain Mode로 전환하며, 전환한 이후에는 Drain Mode로 전환한 이후에는 Istio의 `terminationDrainDuration` 설정값 만큼 대기하며 Envoy Proxy를 종료하고 자기 자신을 종료시킨다. pilot-agents가 종료되면 Envoy Proxy Container가 제거된다. 여기서 중요한 점은 pilot-agents가 Envoy Proxy를 Drain Mode로 전환한 이후에 반드시 `terminationDrainDuration` 설정값 만큼 대기한 다음에 Envoy Proxy를 종료한다는 점이다.

이는 Drain Mode로 진입한 Envoy가 `terminationDrainDuration` 시간 이전에 모든 Request를 처리하였어도 `terminationDrainDuration` 설정값 만큼 대기한 다음 종료가 된다는 것을 의미한다. 따라서 `terminationDrainDuration` 시간이 너무 길어도 Envoy Proxy Container의 종료 시간이 늦어지게 된다. 반대로 Envoy가 `terminationDrainDuration` 시간 이후에도 처리하지 못한 Request가 존재한다면, 해당 Request를 처리하지 못하고 종료된다. 따라서 적절한 `terminationDrainDuration` 설정값이 필요하다.

Envoy Proxy는 Drain Mode에 진입해도 신규 Request를 계속해서 처리가 가능하다. 이는 Envoy Proxy Propagation Delay 발생으로 인해서 신규 Request가 늦게 도착해도 문제없이 처리가 가능하도록 만든다. 이는 App Container와 다르게 Envoy Proxy Container에는 preStop이 존재하지 않는 이유기도 하다. `terminationDrainDuration` 값 이상으로 Pod의 `terminationGracePeriodSeconds` 값도 같이 설정해야 Envoy Proxy가 `SIGKILL` Signal에 의해서 강제로 제거되지 않는다.

```yaml {caption="[File 1] terminationDrainDuration Configuration on IstioOperator", linenos=table}
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  meshConfig:
    defaultConfig:
      terminationDrainDuration: 30s
...
```

```yaml {caption="[File 2] terminationDrainDuration Configuration on IstioOperator", linenos=table}
...
  template:
    metadata:
      annotations:
        proxy.istio.io/config: |
          terminationDrainDuration: 30s
...
```

[File 1]은 `terminationDrainDuration` 설정값을 전역으로 30초로 설정하기 위한 IstioOperator를 나타내고 있으며, [File 2]는 특정 Pod에만 30초로 설정하기 위한 Annotation 예제를 나타내고 있다. `terminationDrainDuration`를 별도로 설정하지 않으면 기본값인 **5초**로 설정이 된다.

```text {caption="[Log 1] Envoy Proxy Termination Log with terminationDrainDuration", linenos=table}
2025-01-06T15:53:11.767769Z     info    Status server has successfully terminated
2025-01-06T15:53:11.767874Z     info    Agent draining Proxy for termination
2025-01-06T15:53:11.769427Z     info    Graceful termination period is 30s, starting...
2025-01-06T15:53:31.165680Z     warn    Envoy proxy is NOT ready: server is terminated: received signal: terminated
2025-01-06T15:53:31.770674Z     info    Graceful termination period complete, terminating remaining proxies.
2025-01-06T15:53:31.770785Z     warn    Aborting proxy
2025-01-06T15:53:31.770967Z     info    Envoy aborted normally
2025-01-06T15:53:31.770986Z     warn    Aborted proxy instance
2025-01-06T15:53:31.770994Z     info    Agent has successfully terminated
2025-01-06T15:53:31.772158Z     info    ads     ADS: "" 2 terminated
2025-01-06T15:53:31.772415Z     info    ads     ADS: "" 1 terminated
```

[Log 1]은 `terminationDrainDuration` 값이 30초로 설정되어 있는 Enovy Container의 종료 Log의 예시를 나타내고 있다. `Graceful termination period is 30s, starting...` Log가 대기 시작을 의미하며 `Graceful termination period complete, terminating remaining proxies.` Log가 대기 종료를 나타낸다. 두 Log의 시간 차이가 약 30초인 것을 확인할 수 있다.

#### 1.2.2. EXIT_ON_ZERO_ACTIVE_CONNECTIONS

{{< figure caption="[Figure 4] Envoy Proxy Container Termination with terminationDrainDuration" src="images/istio-envoy-container-termination-with-terminationdrainduration.png" width="1000px" >}}

[Figure 4]는 `EXIT_ON_ZERO_ACTIVE_CONNECTIONS`이 설정된 Envoy Proxy Container의 Termination 수행 과정을 나타내고 있다. `SIGTERM` Signal을 받은 pilot-agent는 곧바로 Envoy Proxy를 Drain Mode로 전환하고 `MINIMUM_DRAIN_DURATION` 설정값의 시간만큼 대기한다. 이후에 Envoy Proxy의 모든 Connection이 종료될때까지 대기하다가 모든 Connection이 종료되면 Envoy Proxy를 종료하고 자기 자신을 종료한다. pilot-agents가 종료되면 Envoy Proxy Container가 제거된다.

`EXIT_ON_ZERO_ACTIVE_CONNECTIONS`이 설정되면 `terminationDrainDuration` 설정값은 무시된다. `terminationDrainDuration` 설정값으로 종료될때와 동일하게 Drain Mode에 진입한 Envoy Proxy는 신규 Request를 계속해서 처리가 가능하며, 이로 인해서 Envoy Proxy Container에는 preStop이 존재하지 않는다. `terminationGracePeriodSeconds` 값도 같이 크게 설정해야 Envoy Proxy가 `SIGKILL` Signal에 의해서 강제로 제거되지 않는다.

```yaml {caption="[File 3] EXIT_ON_ZERO_ACTIVE_CONNECTIONS Configuration on IstioOperator", linenos=table}
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  meshConfig:
    defaultConfig:
      proxyMetadata:
        EXIT_ON_ZERO_ACTIVE_CONNECTIONS: "true"
        MINIMUM_DRAIN_DURATION: "15s"
...
```

```yaml {caption="[File 4] EXIT_ON_ZERO_ACTIVE_CONNECTIONS Configuration on Pod Annotation", linenos=table}
...
spec:
  template:
    metadata:
      annotations:
        proxy.istio.io/config: |
          proxyMetadata:
            EXIT_ON_ZERO_ACTIVE_CONNECTIONS: "true"
            MINIMUM_DRAIN_DURATION: "15s"
...
```

[File 3]은 `EXIT_ON_ZERO_ACTIVE_CONNECTIONS`를 설정하고 `MINIMUM_DRAIN_DURATION` 설정값을 전역으로 15초로 설정하기 위한 IstioOperator를 나타내고 있으며, [File 4]는 동일한 설정을 특정 Pod에만 적용하기 위한 Annotation 예제를 나타내고 있다. `MINIMUM_DRAIN_DURATION`를 별도로 설정하지 않으면 기본값인 **5초**로 설정이 된다.

```text {caption="[Log 2] Envoy Proxy Termination Log with EXIT_ON_ZERO_ACTIVE_CONNECTIONS", linenos=table}
2025-01-06T18:27:37.713164Z     info    Status server has successfully terminated
2025-01-06T18:27:37.713268Z     info    Agent draining Proxy for termination
2025-01-06T18:27:37.716404Z     info    Agent draining proxy for 15s, then waiting for active connections to terminate...
2025-01-06T18:27:42.252904Z     warn    Envoy proxy is NOT ready: server is terminated: received signal: terminated
2025-01-06T18:27:52.718251Z     info    Checking for active connections...
2025-01-06T18:27:53.723579Z     info    There are no more active connections. terminating proxy...
2025-01-06T18:27:53.723654Z     warn    Aborting proxy
2025-01-06T18:27:53.723890Z     info    Envoy aborted normally
2025-01-06T18:27:53.723906Z     warn    Aborted proxy instance
2025-01-06T18:27:53.723913Z     info    Agent has successfully terminated
2025-01-06T18:27:53.725330Z     info    ads     ADS: "" 2 terminated
2025-01-06T18:27:53.725580Z     info    ads     ADS: "" 1 terminated
```

[Log 2]는 `MINIMUM_DRAIN_DURATION` 값이 15초로 설정되어 있는 Enovy Container의 종료 Log의 예시를 나타내고 있다. `Agent draining Proxy for termination` Log가 대기 시작을 의미하며 ` Checking for active connections...` Log가 대기 종료를 나타낸다. 두 Log의 시간 차이가 약 15초인 것을 확인할 수 있다.

## 2. 참조

* Istio Sidecar : [https://github.com/hashicorp/consul-k8s/issues/650](https://github.com/hashicorp/consul-k8s/issues/650)
* Istio Pod Gracefully Termination : [https://github.com/hashicorp/consul-k8s/issues/536](https://github.com/hashicorp/consul-k8s/issues/536)
* Istio Pod Gracefully Termination : [https://github.com/istio/istio/issues/47779](https://github.com/istio/istio/issues/47779)
* Istio Pod Gracefully Termination : [https://blog.fatedier.com/2021/12/16/istio-sidecar-graceful-shutdown/](https://blog.fatedier.com/2021/12/16/istio-sidecar-graceful-shutdown/)
* Istio `terminationDrainDuration` : [https://www.alibabacloud.com/help/en/asm/user-guide/configure-a-sidecar-proxy-by-adding-resource-annotations](https://www.alibabacloud.com/help/en/asm/user-guide/configure-a-sidecar-proxy-by-adding-resource-annotations)
* Istio `MINIMUM_DRAIN_DURATION` : [https://github.com/istio/istio/issues/47779](https://github.com/istio/istio/issues/47779)
* Istio `EXIT_ON_ZERO_ACTIVE_CONNECTIONS` : [https://umi0410.github.io/blog/devops/istio-exit-on-zero-active-connections/](https://umi0410.github.io/blog/devops/istio-exit-on-zero-active-connections/)
* Istio `terminationDrainDuration` & `EXIT_ON_ZERO_ACTIVE_CONNECTIONS` : [https://github.com/istio/istio/discussions/49426](https://github.com/istio/istio/discussions/49426)
* Istio pilot-agent : [https://istio.io/latest/docs/reference/commands/pilot-agent/](https://istio.io/latest/docs/reference/commands/pilot-agent/)
* Istio pilot-agent Code Analysis : [https://www.luozhiyun.com/archives/410](https://www.luozhiyun.com/archives/410)

---
title: Istio Pod Gracefully Termination
---

## 1. Istio Pod Gracefully Termination

{{< figure caption="[Figure 1] Istio Pod Component" src="images/istio-app-pod-component.png" width="600px" >}}

[Figure 1] shows the components of an App Pod in an Istio environment. It can be largely divided into the **App Container** where the App runs and the **Envoy Proxy Container**, which is a Sidecar Container through which all Traffic sent and received by the App Container passes. Therefore, Graceful Termination must also be considered separately for the App Container and the Envoy Proxy Container.

### 1.1. App Container Graceful Termination

{{< figure caption="[Figure 2] App Container Graceful Termination" src="images/istio-app-container-gracefully-termination.png" width="1000px" >}}

[Figure 2] shows the process of performing Graceful Termination of the App Container. The Graceful Termination process of the App Container is the same as the Graceful Termination process of an App Container inside a general Pod in a non-Istio environment, and generally, the following 3 settings must be configured to perform Graceful Termination.

* `sleep` CLI-based preStop Hook to solve the problem of not being able to process some new Requests due to Envoy Proxy Propagation Delay
* App completes currently processing Requests and then terminates when receiving `SIGTERM` Signal
* Set Pod's `terminationGracePeriodSeconds` to a time greater than the time it takes for the App to process Requests

However, since Pod's `terminationGracePeriodSeconds` is not a setting value that can be set for each Container but a value that can only be set once for a Pod, it must be set considering the Envoy Proxy Container's setting value as well.

### 1.2. Envoy Proxy Container Graceful Termination

Inside the Envoy Proxy Container, **pilot-agent** and Envoy Proxy run. pilot-agent runs as the Init Process of the Envoy Proxy Container, so it runs first, and then pilot-agent runs Envoy Proxy. Therefore, when the Pod terminates, the `SIGTERM` Signal is only received by pilot-agent, and Envoy Proxy does not receive it. pilot-agent, which receives the `SIGTERM` Signal, also performs the role of terminating Envoy Proxy, and all values set for Graceful Termination of the Envoy Proxy Container introduced below are setting values of pilot-agent, which receives the `SIGTERM` Signal.

The Termination process of the Envoy Proxy Container differs depending on whether `EXIT_ON_ZERO_ACTIVE_CONNECTIONS` is set, and if `EXIT_ON_ZERO_ACTIVE_CONNECTIONS` is not set, the Envoy Proxy Container terminates according to the `terminationDrainDuration` setting value.

#### 1.2.1. terminationDrainDuration

{{< figure caption="[Figure 3] Envoy Proxy Container Termination with terminationDrainDuration" src="images/istio-envoy-container-termination-with-terminationdrainduration.png" width="1000px" >}}

[Figure 3] shows the process of Envoy Proxy performing Graceful Termination according to the `terminationDrainDuration` setting value when `EXIT_ON_ZERO_ACTIVE_CONNECTIONS` is not set. pilot-agent, which receives the `SIGTERM` Signal, switches Envoy Proxy to **Drain Mode**, and after switching, waits for the Istio `terminationDrainDuration` setting value and then terminates Envoy Proxy and terminates itself. When pilot-agent terminates, the Envoy Proxy Container is removed. The important point here is that pilot-agent waits for the `terminationDrainDuration` setting value after switching Envoy Proxy to Drain Mode and then terminates Envoy Proxy.

This means that even if Envoy that entered Drain Mode has processed all Requests before the `terminationDrainDuration` time, it must wait for the `terminationDrainDuration` setting value and then terminate. Therefore, if the `terminationDrainDuration` time is too long, the termination time of the Envoy Proxy Container is delayed. Conversely, if Envoy has Requests that it could not process even after the `terminationDrainDuration` time, those Requests are not processed and it terminates. Therefore, an appropriate `terminationDrainDuration` setting value is necessary.

Envoy Proxy can continue to process new Requests even after entering Drain Mode. This allows new Requests that arrive late due to **Envoy Proxy Propagation Delay** shown in [Figure 3] to be processed without problems. This is also the reason why preStop does not exist in the Envoy Proxy Container, unlike the App Container. The Pod's `terminationGracePeriodSeconds` value must be set to at least the `terminationDrainDuration` value. Otherwise, Envoy Proxy cannot wait for the `terminationDrainDuration` time and is forcibly terminated by the `SIGKILL` Signal due to Pod's `terminationGracePeriodSeconds`.

```yaml {caption="[File 1] terminationDrainDuration Configuration on IstioOperator", linenos=table}
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  meshConfig:
    defaultConfig:
      terminationDrainDuration: 30s
...
```

```yaml {caption="[File 2] terminationDrainDuration Configuration on Pod Annotation", linenos=table}
...
  template:
    metadata:
      annotations:
        proxy.istio.io/config: |
          terminationDrainDuration: 30s
...
```

The `terminationDrainDuration` value can be set both globally and per Pod. [File 1] shows an IstioOperator to set the `terminationDrainDuration` setting value to 30 seconds globally, and [File 2] shows an Annotation example to set it to 30 seconds only for a specific Pod. If `terminationDrainDuration` is not set separately, it is set to the default value of **5 seconds**.

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

[Log 1] shows an example of termination Logs of an Envoy Container with the `terminationDrainDuration` value set to 30 seconds. The `Graceful termination period is 30s, starting...` Log indicates the start of waiting, and the `Graceful termination period complete, terminating remaining proxies.` Log indicates the end of waiting. You can see that the time difference between the two Logs is approximately 30 seconds.

#### 1.2.2. EXIT_ON_ZERO_ACTIVE_CONNECTIONS

{{< figure caption="[Figure 4] Envoy Proxy Container Termination with EXIT_ON_ZERO_ACTIVE_CONNECTIONS" src="images/istio-envoy-container-termination-with-zeroactiveconnections.png" width="1000px" >}}

[Figure 4] shows the Termination process of an Envoy Proxy Container with `EXIT_ON_ZERO_ACTIVE_CONNECTIONS` set. pilot-agent, which receives the `SIGTERM` Signal, immediately switches Envoy Proxy to **Drain Mode** and waits for the time set by the `MINIMUM_DRAIN_DURATION` setting value. After that, it waits until all Connections of Envoy Proxy are terminated, and when all Connections are terminated, it terminates Envoy Proxy and terminates itself. When pilot-agent terminates, the Envoy Proxy Container is removed.

When `EXIT_ON_ZERO_ACTIVE_CONNECTIONS` is set, the `terminationDrainDuration` setting value is ignored. Similar to when terminating with the `terminationDrainDuration` setting value, Envoy Proxy that entered Drain Mode can continue to process new Requests, and for this reason, preStop does not exist in the Envoy Proxy Container. The `terminationGracePeriodSeconds` value must also be set large so that Envoy Proxy is not forcibly removed by the `SIGKILL` Signal.

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

Both `EXIT_ON_ZERO_ACTIVE_CONNECTIONS` and `MINIMUM_DRAIN_DURATION` values can be set both globally and per Pod. [File 3] shows an IstioOperator to set `EXIT_ON_ZERO_ACTIVE_CONNECTIONS` globally and set the `MINIMUM_DRAIN_DURATION` setting value to 15 seconds, and [File 4] shows an Annotation example to apply the same settings only to a specific Pod. If `MINIMUM_DRAIN_DURATION` is not set separately, it is set to the default value of **5 seconds**.

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

[Log 2] shows an example of termination Logs of an Envoy Container with the `MINIMUM_DRAIN_DURATION` value set to 15 seconds. The `Agent draining Proxy for termination` Log indicates the start of waiting, and the `Checking for active connections...` Log indicates the end of waiting. You can see that the time difference between the two Logs is approximately 15 seconds.

## 2. References

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


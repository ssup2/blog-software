---
title: Kubernetes Pod Termination
draft: true
---

## 1. Kuberentes Pod Termination

{{< figure caption="[Figure 1] Kubernetes Pod Termination" src="images/kubernetes-pod-termination.png" width="1000px" >}}

Pod가 종료되도 Pod 안에서 동작하는 App Container가 안정적으로 Request을 처리하며 우아하게 종료되기 위해서는 Pod의 종료 과정을 완전히 이해하고 적절하게 Pod를 설정해야한다. [Figure 1]은 상세한 Pod의 종료 과정을 나타내고 있다.

1. K8s API 서버는 Pod 종료 요청을 받으면 종료 요청을 받은 Pod가 동작하는 Node의 kubelet에게 Pod 종료 요청을 전달한다. 또한 K8s API 서버는 Endpoint Slice Controller에게도 Pod 종료를 전달한다.
2. Pod 종료 요청을 받은 Kubelet은 Pod 안에서 동작하고 있는 App Container의 PreStop Hook을 동작시킨다.
3. Endpoint Slice Controller는 종료될 Pod를 Endpoint Slice에서 제거하여 kube-proxy가 신규 Request를 종료될 Pod로 전달되지 못하도록 만든다.
4. PreStop Hook의 동작이 완료되면 kubelet은 `SIGTERM` Signal을 전송한다. `SIGTERM` Signal을 받은 App Container는 현재 처리중인 Request를 모두 처리하고 종료를 시도한다.
5. 만약 `SIGTERM`을 받은 App Container가 종료되지 않으면 `SIGKILL` Signal을 받고 강제로 종료된다. kubelet은 K8s API 서버가 받은 Pod 종료 요청 시간부터 App Container에 설정된 `terminationGracePeriodSeconds` 시간만큼 대기후에 `SIGKILL` Signal을 전송한다. `terminationGracePeriodSeconds`의 기본값은 30초이다.

App Container가 우아하게 종료되기 위해서는 마지막 `SIGKILL` 과정을 제외한 **1~4의 과정이 수행**되어야 한다. 1,3번의 과정은 Kubernetes 내부적으로 자동으로 수행되는 과정이지만, 2번의 과정은 Pod 내부의 App Container에 PreStop Hook을 설정하지 않으면 수행되지 않으며, 4번의 과정은 App Container에서 `SIGTERM` Signal을 처리하지 않도록 설정하면 수행되지 않기 때문에 관리가 필요하다. 또한 App Container가 `SIGKILL`을 받으면 Request가 제대로 처리되지 않고 강제로 종료될 수 있기 때문에 `terminationGracePeriodSeconds`의 값도 적절하게 설정해야한다.

### 1.1. PreStop Hook 설정

{{< figure caption="[Figure 2] Kubernetes Pod Termination without PreStop Hook" src="images/kubernetes-pod-termination-without-prestop-hook.png" width="1000px" >}}

[Figure 2] 과정은 App Container에 PreStop Hook을 설정하지 않았을 경우 발생할 수 있는 App Container로 전달된 Request가 처리되지 못한 문제를 나타내고 있다. App Container에 PreStop Hook이 설정되어 있지 않으면 Pod Termination 요청을 받은 kubelet은 `SIGTERM` Signal을 곧바로 전송한다. `SIGTERM` Signal을 받은 App Container는 이후에 전달받은 Request를 처리하지 않거나, 곧바로 종료되어 제거될 수 있다.

문제는 Pod Termination 요청 Endpoint Slice Controller가 처리하고 다시 kube-proxy로 전달되고, kube-proxy가 다시 iptable/IPVS Rule을 설정하는데 시간이 소요된다는 점이다. 즉 **Endpoint Slice Propagation Delay**가 발생하고 이로 인해서 `SIGTERM` Signal을 받은 App Container는 이후에도 짧은 시간동안 다른 Pod로부터 Request를 전달 받을수 있다. [Figure 1]처럼 App Container에 PreStop Hook이 설정되어 있다면 App Container가 늦게 `SIGTERM` Signal을 받고 늦게 종료가 시작되기 때문에 Endpoint Slice Propagation Delay로 인해서 늦게 Request가 도착해도 문제없이 처리가 가능해 진다.

전반적인 Endpoint Slice Propagation Delay는 파악이 어렵지만 kube-proxy가 iptable/IPVS Rule을 설정하는데 소모된 시간은 kube-proxy가 제공하는 `kubeproxy_sync_proxy_rules_duration_seconds` Metric을 통해서 확인할 수 있다.

```yaml {caption="[File 1] PreStop Hook sleep command Example", linenos=table}
spec:
  terminationGracePeriodSeconds: 60
  containers:
  - name: "app"
    lifecycle:
      preStop:
        exec:
          command: ["/bin/sh","-c","sleep 20"]
```

PreStop Hook은 `SIGTERM` Signal을 늦게 받기 위한 용도로 활용되기 때문에 일반적으로는 [File 1]의 내용과 같이 `sleep` 명령어를 활용하여 구성한다. 따라서 App Container Image에는 `sleep` 명령어와, Shell이 설치되어 있어야 한다. 추후에는 Kubernetes 자체에서 Sleep 기능을 제공할 예정이며 자세한 내용은 [Link](https://github.com/kubernetes/enhancements/blob/master/keps/sig-node/3960-pod-lifecycle-sleep-action/README.md)에서 확인 할 수 있다.

### 1.2. App Container의 SIGTERM 처리

### 1.3. terminationGracePeriodSeconds 설정

### 1.4. with Istio Sidecar

`terminationDrainDuration`

## 2. 참조

* Pod Termination : [https://docs.aws.amazon.com/eks/latest/best-practices/load-balancing.html](https://docs.aws.amazon.com/eks/latest/best-practices/load-balancing.html)
* Pod PreStop Hook Sleep KEP : [https://github.com/kubernetes/enhancements/blob/master/keps/sig-node/3960-pod-lifecycle-sleep-action/README.md](https://github.com/kubernetes/enhancements/blob/master/keps/sig-node/3960-pod-lifecycle-sleep-action/README.md)
* Pod Readiness Gates : [https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/deploy/pod_readiness_gate/](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/deploy/pod_readiness_gate/)
* Istio Sidecar : [https://github.com/hashicorp/consul-k8s/issues/650](https://github.com/hashicorp/consul-k8s/issues/650)
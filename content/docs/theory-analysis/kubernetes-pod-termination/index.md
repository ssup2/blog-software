---
title: Kubernetes Pod Termination
draft: true
---

## 1. Kuberentes Pod Termination

{{< figure caption="[Figure 1] Kubernetes Pod Termination" src="images/kubernetes-pod-termination.png" width="1000px" >}}

Pod가 종료되도 Pod 안에서 동작하는 App Container가 안정적으로 Request을 처리하며 **우아하게 종료**(Gracefully Termination)되기 위해서는 Pod의 종료 과정을 완전히 이해하고 적절하게 Pod를 설정해야한다. [Figure 1]은 상세한 Pod의 종료 과정을 나타내고 있다.

1. K8s API 서버는 Pod 종료 요청을 받으면 종료 요청을 받은 Pod가 동작하는 Node의 kubelet에게 Pod 종료 요청을 전달한다. 또한 K8s API 서버는 Endpoint Slice Controller에게도 Pod 종료를 전달한다.
2. Pod 종료 요청을 받은 Kubelet은 Pod 안에서 동작하고 있는 App Container의 PreStop Hook을 동작시킨다.
3. Endpoint Slice Controller는 종료될 Pod를 Endpoint Slice에서 제거하여 kube-proxy가 신규 Request를 종료될 Pod로 전달되지 못하도록 만든다.
4. PreStop Hook의 동작이 완료되면 kubelet은 `SIGTERM` Signal을 전송한다. `SIGTERM` Signal을 받은 App Container는 현재 처리중인 Request를 모두 완료하고 종료를 시도한다.
5. 만약 `SIGTERM`을 받은 App Container가 종료되지 않으면 `SIGKILL` Signal을 받고 강제로 종료된다. kubelet은 K8s API 서버가 받은 Pod 종료 요청 시간부터 App Container에 설정된 `terminationGracePeriodSeconds` 시간만큼 대기후에 `SIGKILL` Signal을 전송한다.

{{< figure caption="[Figure 2] Kubernetes Pod Termination with Gracefully Termination" src="images/kubernetes-pod-termination-with-gracefully-termination.png" width="1000px" >}}

App Container가 우아하게 종료되기 위해서는 [Figure 2]와 같이 마지막 `SIGKILL` 과정을 제외한 **1~4의 과정이 수행**되어야 한다. 1,3번의 과정은 Kubernetes 내부적으로 자동으로 수행되는 과정이지만, 2번의 과정은 Pod 내부의 App Container에 **PreStop Hook**을 설정하지 않으면 수행되지 않으며, 4번의 과정은 App Container에서 `SIGTERM` Signal을 처리하지 않도록 설정하면 수행되지 않기 때문에 관리가 필요하다. 또한 App Container가 `SIGKILL`을 받으면 Request가 제대로 처리되지 않고 강제로 종료될 수 있기 때문에 `terminationGracePeriodSeconds`의 값도 적절하게 설정해야한다.

### 1.1. PreStop Hook 설정

{{< figure caption="[Figure 3] Kubernetes Pod Termination without PreStop Hook" src="images/kubernetes-pod-termination-without-prestop-hook.png" width="1000px" >}}

[Figure 3] 과정은 App Container에 PreStop Hook을 설정하지 않았을 경우 발생할 수 있는 App Container로 전달된 Request가 처리되지 못한 문제를 나타내고 있다. App Container에 PreStop Hook이 설정되어 있지 않으면 Pod Termination 요청을 받은 kubelet은 `SIGTERM` Signal을 곧바로 전송한다. `SIGTERM` Signal을 받은 App Container는 이후에 전달받은 Request를 처리하지 않거나, 곧바로 종료되어 제거될 수 있다.

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
          command: ["/bin/sh","-c","sleep 5"]
```

PreStop Hook은 `SIGTERM` Signal을 늦게 받기 위한 용도로 활용되기 때문에 일반적으로는 [File 1]의 내용과 같이 `sleep` 명령어를 활용하여 구성한다. 따라서 App Container Image에는 `sleep` 명령어와, Shell이 설치되어 있어야 한다. 일반적으로는 **5~10초** 정도로 설정하며, 너무 큰 값을 설정하면 Pod 종료가 늦어져 배포 속도가 느려지기 때문에 적절한 값을 설정해야 한다. 추후에는 Kubernetes 자체에서 Sleep 기능을 제공할 예정이며 자세한 내용은 [Link](https://github.com/kubernetes/enhancements/blob/master/keps/sig-node/3960-pod-lifecycle-sleep-action/README.md)에서 확인할 수 있다.

### 1.2. App Container의 SIGTERM 처리

{{< figure caption="[Figure 4] Kubernetes Pod Termination without PreStop Hook" src="images/kubernetes-pod-termination-without-sigterm-handler.png" width="1000px" >}}

Linux 환경에서 `SIGTERM` Signal Handler가 설정되지 않는 Application (Process)는 `SIGTERM` Signal을 받는 순간 죽으며, App Container도 동일하다. [Figure 4]는 App Container가 SIGTERM Handler가 설정되지 않았을 때를 나타내고 있다. SIGTERM을 받자마자 App Container가 제거되기 때문에, 현재 처리중인 Request를 제대로 처리하지 못하고 종료될 수 있다. 따라서 App Container는 `SIGTERM` Signal을 받더라도 현재 처리중 Request를 완료하고 죽도록 설정되어 있어야 한다.

```yaml {caption="[File 2] SpringBoot SIGTEM Handler Configuration", linenos=table}
server:
  shutdown: graceful
```

대부분의 App Server Framework에서는 `SIGTERM` Signal을 손쉽게 처리할 수 있는 Gracefully Termination 설정을 제공하기 때문에, 직접 `SIGTERM` Handler를 작성할 필요는 없으며, App Container의 경우에도 동일하다. [File 2]는 SpringBoot의 예제를 나타내고 있다. Spring Boot에 `shutdown: graceful`을 설정하면 `SIGTERM` Signal을 수신하는 순간 신규 Request의 처리는 거절되며, 현재 처리중인 모든 Request가 완료 된 이후에 종료된다.

SpringBoot 뿐만이 아니라 대부분의 App Server Framework에서는 Gracefully Termination이 동작하면 `SIGTERM` Signal을 수신하는 순간 신규 Request도 거절하기 때문에, `SIGTERM` Signal을 App Container로 전송한 이후에는 신규 Request도 App Container로 전달되면 안되며, 이러한 역할은 PreStop Hook이 수행한다.

App Container가 `SIGTERM` Signal을 처리하지 않는 상태에서 우아한 종료를 수행하기 위해서는 PreStop Hook의 시간을 30초 이상으로 늘리는 방법이 존재한다. PreStop Hook이 길어질 수록 App Container가 `SIGTERM` Signal을 받는 시간이 늘어나고 그만큼 현재 처리중인 Request를 완료할 수 있는 시간을 얻을 수 있기 때문이다. 하지만 PreStop Hook이 길어질 수록 Pod 종료 시간도 길어지고 그 만큼 Pod 배포 시간도 증가하기 때문에 가능하면 App Container에서 `SIGTERM` Signal Handler를 설정하는 방법이 권장된다.

### 1.3. terminationGracePeriodSeconds 설정

`terminationGracePeriodSeconds`은 kubelet이 PreStop Hook을 실행하고 난뒤 `SIGKILL` Singal을 전송하기 전까지 대기하는 시간이다. Linux 환경에서 `SIGTERM` Signal과 달리 `SIGKILL` Signal을 받는 Application (Process)는 반드시 죽는다. 따라서 `terminationGracePeriodSeconds` 값은 PreStop Hook 시간과 App Container에서 대부분의 요청을 처리하는 시간의 합보다 반드시 커야한다. `terminationGracePeriodSeconds`의 기본값은 30초이며 Pod 내부의 각 Container마다 설정할 수 없고 Pod에 설정하는 값이다.

### 1.4. with Istio Sidecar

Istio를 이용하는 경우 Pod 종료시에 Istio의 Sidecar Container로 우아하게 종료되어야 한다. Istio의 Sidecar Container인 Envoy의 경우에도 `SIGTERM` Signal을 받으면 신규 Request를 처리하지 않으며, 기존에 처리중인 Request를 완료하고 종료된다. 이때 Istio의 `terminationDrainDuration` 설정값 만큼 처리중인 Request가 완료될때까지 대기하며 이후에는 강제로 종료된다. 따라서 Pod의 `terminationGracePeriodSeconds`의 시간이 반드시 `terminationDrainDuration` 시간보다 커야한다. 만약에 크지 않다면 `SIGKILL` Signal에 의해서 Sidecar Container도 강제로 종료되기 때문이다.

``` {caption="[File 3] Istio terminationDrainDuration Configuration", linenos=table}
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  meshConfig:
    defaultConfig:
      terminationDrainDuration: 60s
...
```

[File 3]은 Istio Operator 이용시 `terminationDrainDuration`을 60초로 설정하는 예시를 나타내고 있으며, 기본값은 30초이다.

### 1.5. 우아한 종료 Test

## 2. 참조

* Pod Termination : [https://docs.aws.amazon.com/eks/latest/best-practices/load-balancing.html](https://docs.aws.amazon.com/eks/latest/best-practices/load-balancing.html)
* Pod PreStop Hook Sleep KEP : [https://github.com/kubernetes/enhancements/blob/master/keps/sig-node/3960-pod-lifecycle-sleep-action/README.md](https://github.com/kubernetes/enhancements/blob/master/keps/sig-node/3960-pod-lifecycle-sleep-action/README.md)
* Pod Readiness Gates : [https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/deploy/pod_readiness_gate/](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/deploy/pod_readiness_gate/)
* Istio Sidecar : [https://github.com/hashicorp/consul-k8s/issues/650](https://github.com/hashicorp/consul-k8s/issues/650)
* Istio Gracefully Shutown : [https://github.com/istio/istio/issues/47779](https://github.com/istio/istio/issues/47779)
* Istio EXIT_ON_ZERO_ACTIVE_CONNECTIONS : [https://umi0410.github.io/blog/devops/istio-exit-on-zero-active-connections/](https://umi0410.github.io/blog/devops/istio-exit-on-zero-active-connections/)
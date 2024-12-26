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
4. PreStop Hook의 동작이 완료되면 kubelet은 `SIGTERM` Signal을 전송한다. `SIGTERM`을 받은 App Container는 현재 처리중인 Request를 모두 처리하고 종료를 시도한다.
5. 만약 `SIGTERM`을 받은 App Container가 종료되지 않으면 `SIGKILL` Signal을 받고 강제로 종료된다. kubelet은 K8s API 서버가 받은 Pod 종료 요청 시간부터 App Container에 설정된 `terminationGracePeriodSeconds` 시간만큼 대기후에 `SIGKILL` Signal을 전송하며, `terminationGracePeriodSeconds`의 기본값은 30초이다.

{{< figure caption="[Figure 2] Kubernetes Pod Termination without Prestop Hook" src="images/kubernetes-pod-termination-without-prestop-hook.png" width="1000px" >}}

App Container가 우아하게 종료되기 위해서는 `SIGKILL` 과정을 제외한 **1에서 4의 과정이 반드시 수행**되어야 한다. [Figure 2] 과정은 App Container에 Prestop Hook을 설정하지 않았을 경우, App Container로 전달된 일부 App 

### 1.1. with Istio Sidecar

`terminationDrainDuration`

## 2. 참조

* Pod Termination : [https://docs.aws.amazon.com/eks/latest/best-practices/load-balancing.html](https://docs.aws.amazon.com/eks/latest/best-practices/load-balancing.html)
* Pod Readiness Gates : [https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/deploy/pod_readiness_gate/](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/deploy/pod_readiness_gate/)
* Istio Sidecar : [https://github.com/hashicorp/consul-k8s/issues/650](https://github.com/hashicorp/consul-k8s/issues/650)
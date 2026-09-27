---
title: Kubernetes Pod Gracefully Termination
---

## 1. Kuberentes Pod Gracefully Termination

{{< figure caption="[Figure 1] Kubernetes Pod Gracefully Termination" src="images/kubernetes-pod-gracefully-termination.png" width="1000px" >}}

The process in which the App Container running inside a Pod terminates while stably handling Requests when the Pod is terminated is called **Gracefully Termination**. [Figure 1] shows the Gracefully Termination process of a Pod.

1. When the K8s API Server receives a Pod termination request, it delivers the termination request to the kubelet of the Node where the Pod to be terminated is running. The K8s API Server also delivers the Pod termination to the Endpoint Slice Controller.
2. The kubelet that received the Pod termination request runs the preStop Hook of the App Container running inside the Pod.
3. The Endpoint Slice Controller removes the Pod to be terminated from the Endpoint Slice so that kube-proxy cannot deliver new Requests to the Pod being terminated.
4. When the preStop Hook completes, the kubelet sends the `SIGTERM` Signal. The App Container that received the `SIGTERM` Signal completes all Requests currently being processed and attempts to terminate. 

Steps 1 and 3 are performed automatically inside Kubernetes when a Pod is terminated, but step 2 is not performed unless the **preStop Hook** is configured on the App Container inside the Pod, and step 4 is not performed if the App Container is configured not to handle the `SIGTERM` Signal, so separate configuration is required. In addition, if the App Container that received the `SIGTERM` Signal does not terminate within the `terminationGracePeriodSeconds` time configured on the Pod, the App Container receives the `SIGKILL` Signal and is forcibly terminated, so Requests may not be processed properly and be forcibly terminated. Therefore, the value of `terminationGracePeriodSeconds` must also be set appropriately.

### 1.1. preStop Hook Configuration

{{< figure caption="[Figure 2] Kubernetes Pod Termination without preStop Hook" src="images/kubernetes-pod-termination-without-prestop-hook.png" width="1000px" >}}

[Figure 2] shows the problem where Requests delivered to the App Container are not processed, which can occur when the preStop Hook is not configured on the App Container. If the preStop Hook is not configured on the App Container, the kubelet that received the Pod Termination request sends the `SIGTERM` Signal immediately. Depending on the App configuration, the App Container that received the `SIGTERM` Signal does not process new Requests delivered afterwards, or is immediately terminated and removed.

The problem is that it takes time for the Pod Termination request to be processed by the Endpoint Slice Controller, delivered again to kube-proxy, and for kube-proxy to configure the iptable/IPVS Rules. In other words, a **kube-proxy Propagation Delay** occurs, and because of this, the App Container that received the `SIGTERM` Signal may still receive Requests from other Pods for a short time afterwards. If the preStop Hook is configured on the App Container as in [Figure 1], the App Container receives the `SIGTERM` Signal late and starts terminating late, so even if Requests arrive late due to the kube-proxy Propagation Delay, they can be processed without problems.

The overall kube-proxy Propagation Delay is difficult to determine, but the time spent by kube-proxy configuring the iptable/IPVS Rules can be checked through the `kubeproxy_sync_proxy_rules_duration_seconds` Metric provided by kube-proxy.

```yaml {caption="[File 1] preStop Hook sleep command Example", linenos=table}
spec:
  terminationGracePeriodSeconds: 60
  containers:
  - name: "app"
    lifecycle:
      preStop:
        exec:
          command: ["/bin/sh","-c","sleep 5"]
```

Since the preStop Hook is used so that the App Container receives the `SIGTERM` Signal late, it is generally configured using the `sleep` command as shown in [File 1]. Therefore, the `sleep` command and a Shell must be installed in the App Container Image. It is generally set to about **5 seconds**, and setting too large a value delays Pod termination and slows down deployment speed, so an appropriate value must be set. In the future, Kubernetes itself plans to provide a Sleep feature, and details can be found at [Link](https://github.com/kubernetes/enhancements/blob/master/keps/sig-node/3960-pod-lifecycle-sleep-action/README.md).

### 1.2. SIGTERM Signal Handling in the App Container

{{< figure caption="[Figure 3] Kubernetes Pod Termination without preStop Hook" src="images/kubernetes-pod-termination-without-sigterm-handler.png" width="1000px" >}}

In a Linux environment, an Application (Process) without a `SIGTERM` Signal Handler configured dies the moment it receives the `SIGTERM` Signal, and the App Container is the same. [Figure 3] shows the case where the App Container has no `SIGTERM` Handler configured. Since the App Container is removed as soon as it receives `SIGTERM`, it may terminate without properly processing the Requests currently being processed. Therefore, the App Container must be configured to complete the Requests currently being processed and then die even when it receives the `SIGTERM` Signal.

```yaml {caption="[File 2] SpringBoot SIGTEM Handler Configuration", linenos=table}
server:
  shutdown: graceful
```

Most App Server Frameworks provide a Gracefully Termination configuration that makes it easy to handle the `SIGTERM` Signal, so there is no need to write a `SIGTERM` Handler directly, and the same applies to the App Container. [File 2] shows an example for SpringBoot. If `shutdown: graceful` is configured in Spring Boot, the processing of new Requests is rejected the moment the `SIGTERM` Signal is received, and termination occurs after all Requests currently being processed are completed.

Not only SpringBoot but most App Server Frameworks also reject new Requests the moment the `SIGTERM` Signal is received when Gracefully Termination operates, so after the `SIGTERM` Signal is sent to the App Container, new Requests must not be delivered to the App Container, and this role is performed by the preStop Hook.

To perform Gracefully Termination when the App Container does not handle the `SIGTERM` Signal, there is a method of increasing the duration of the preStop Hook to be longer than the Request processing time of the App Container. This is because the longer the preStop Hook, the later the App Container receives the `SIGTERM` Signal, and it gains that much time to complete the Requests currently being processed. However, the longer the preStop Hook, the longer the Pod termination time and thus the Pod deployment time, so configuring a `SIGTERM` Signal Handler in the App Container is recommended if possible.

### 1.3. terminationGracePeriodSeconds Configuration

{{< figure caption="[Figure 4] Kubernetes Pod Termination with SIGKILL" src="images/kubernetes-pod-termination-with-sigkill.png" width="1000px" >}}

`terminationGracePeriodSeconds` is the time the kubelet waits after running the preStop Hook before sending the `SIGKILL` Singal. In a Linux environment, unlike the `SIGTERM` Signal, an Application (Process) that receives the `SIGKILL` Signal always dies. Therefore, the `terminationGracePeriodSeconds` value must be greater than the sum of the preStop Hook time and the time the App Container takes to process most Requests. The default value of `terminationGracePeriodSeconds` is 30 seconds, and it cannot be set for each Container inside the Pod but can only be set for the entire Pod. [Figure 4] shows the process in which the App Container is forcibly killed through the `SIGKILL` Signal.

### 1.4. Considerations for Gracefully Termination Configuration

For the Gracefully Termination of a Pod, various durations such as the duration of the App Container's preStop Hook and the duration of the Pod's `terminationGracePeriodSeconds` must be set appropriately. There is no formula that determines these durations exactly, and they can change depending on various factors. The preStop Hook is generally set to 5 seconds, but if there are many Endpoint Slice changes due to frequent Pod deployments inside the Kubernetes Cluster, it may need to be set to more than 5 seconds. Alternatively, if the `SIGTERM` Signal Handler is not configured in the App Container, the preStop Hook must be set to be longer than the Request processing time of the App Container. The duration of the Pod's `terminationGracePeriodSeconds` is determined by the Request processing time of the App Container.

Since various factors exist and no clear formula exists, generally, whether Gracefully Termination works well is verified by checking whether Request processing has no problems even in an environment where Pod restarts are repeated, and during this process, the duration of the preStop Hook or the duration of `terminationGracePeriodSeconds` is set in a Heuristic manner.

Even if the Gracefully Termination of a Pod is configured, Kubernetes does not always guarantee that Gracefully Termination is performed when a Pod is terminated. As a representative example, when a specific Node in the Kubernetes Cluster dies due to a failure, the Pods running on the dead Node naturally terminate without performing Gracefully Termination. Alternatively, if the App Container processes most Requests within 1 second but occasionally a specific Request takes a long time and the Request is not completed even after the `terminationGracePeriodSeconds` time configured on the Pod, it can be forcibly terminated through the `SIGKILL` Signal.

The impact on Business Logic that can occur when Gracefully Termination is not performed can mostly be mitigated by retrying from the Client or Sidecar Container. Therefore, when setting durations for Gracefully Termination, rather than setting long durations with the goal of terminating while completely processing 100% of all Requests, it is generally more correct to give up the completion of some Requests, such as 99%, and instead set short durations to enable fast deployment.

## 2. References

* Pod Termination : [https://docs.aws.amazon.com/eks/latest/best-practices/load-balancing.html](https://docs.aws.amazon.com/eks/latest/best-practices/load-balancing.html)
* Pod PreStop Hook Sleep : [https://blog.gruntwork.io/delaying-shutdown-to-wait-for-pod-deletion-propagation-445f779a8304](https://blog.gruntwork.io/delaying-shutdown-to-wait-for-pod-deletion-propagation-445f779a8304)
* Pod PreStop Hook Sleep KEP : [https://github.com/kubernetes/enhancements/blob/master/keps/sig-node/3960-pod-lifecycle-sleep-action/README.md](https://github.com/kubernetes/enhancements/blob/master/keps/sig-node/3960-pod-lifecycle-sleep-action/README.md)
* Pod Readiness Gates : [https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/deploy/pod_readiness_gate/](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/deploy/pod_readiness_gate/)

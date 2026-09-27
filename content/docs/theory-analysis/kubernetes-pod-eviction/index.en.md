---
title: Kubernetes Pod Eviction
---

This post summarizes the Pod Eviction techniques of Kubernetes.

## 1. Kubernetes Pod Eviction

Kubernetes provides the **Pod Eviction** technique, which secures Resources by removing lower-priority Pods when the Cluster runs short of Resources. There are two kinds of Pod Eviction techniques: one performed by the Kubernetes Scheduler and one performed by the kubelet. The Pod Eviction technique performed by the Kubernetes Scheduler is a Cluster-Level technique, and the Pod Eviction technique performed by the kubelet is a Node-Level technique.

### 1.1. Pod Eviction by the Kubernetes Scheduler

The Pod Eviction technique performed by the Kubernetes Scheduler is a Cluster-Level technique. When the Kubernetes Scheduler schedules a newly created Pod and no Node capable of running the Pod exists, the Kubernetes Scheduler evicts and removes already running Pods and assigns the newly created Pod. This Pod replacement process is called Preemption.

For Preemption to occur, the Priority of the newly created Pod must be higher than the Priority of the already running Pods. If the Priority of the newly created Pod is higher than the Priority of the existing running Pods, the Scheduler removes the lower-priority Pods through Eviction and runs the newly created Pod. In this case, not just a single Pod may be evicted and removed; multiple Pods may be evicted and removed to secure the required Resources.

Also, it is not necessarily the Pod with the lowest Priority among the currently running Pods that is removed first. To secure Resources for the newly created Pod on a specific Node, a Pod may be removed first even if it does not have the lowest Priority. One thing that is certain is that Pods with a lower Priority than the newly created Pod's Priority are evicted and removed.

If all running Pods have a higher Priority than the newly created Pod's Priority, the newly created Pod is not scheduled and remains in the Pending state.

#### 1.1.1. Pod PriorityClass

```yaml {caption="[File 1] Priority Class", linenos=table}
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: my-priority
value: 1000000
globalDefault: false
description: "My Priority Class"
```

```yaml {caption="[File 2] Nginx Pod with Priority Class", linenos=table}
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  priorityClassName: my-priority
  containers:
  - name: nginx
    image: nginx
```

A Pod's Priority is configured by creating a Priority Class that stores the Priority information and specifying the created Priority Class in the Pod. [File 1] shows the Manifest file for creating a Priority Class named `my-priority`, and [File 2] shows the process of setting the `my-priority` Priority Class created through [File 1] on an Nginx Pod.

The higher the value of a Priority Class, the higher the Priority, and the maximum value is "1 billion". The `globalDefault` of a Priority Class is a value that configures whether the Priority Class is used as the Default Priority Class. When no Default Priority Class exists, the Priority of a Pod with no Priority Class specified is set to `0`. Kubernetes provides the following Priority Classes with high Priority by default to protect the Pods essential to the Cluster's composition.

* `system-cluster-critical` : `2000000000`
* `system-node-critical` : `2000001000`

### 1.2. Pod Eviction by the kubelet

The Pod Eviction technique performed by the kubelet is a Node-Level technique. A Pod scheduled by the Kubernetes Scheduler and running on a specific Node can be evicted and forcibly removed by the kubelet when the Node runs short of Resources for various reasons. The kubelet's Pod Eviction can be considered in two cases: when the Node's CPU and Memory Resources are insufficient, and when the Node's Disk or inodes are insufficient.

#### 1.2.1. CPU and Memory Shortage

A Pod (Container) has Request and Limit values for CPU and Memory Resources. The Request is the value the Kubernetes Scheduler uses when scheduling the Pod, and the Limit means the maximum value the Pod can use. Therefore, this means Pods can use more CPU and Memory Resources than the Request value. Since the Kubernetes Scheduler performs Pod Scheduling based on the Request value, when CPU and Memory Resources run short, the kubelet selects the Pods actually using more CPU and Memory Resources than their Request values as Eviction targets.

If no Request value is set on a Pod, Kubernetes regards the Request value as `0`. Therefore, a `BestEffort` QoS Pod, which sets no Request value for either CPU or Memory, is always an Eviction target of the kubelet. In the case of a `Burstable` QoS Pod, if Request values are set for both CPU and Memory and the actual CPU and Memory Resource usage is smaller than the Request values, it escapes the kubelet's Eviction targets; otherwise, it becomes an Eviction target of the kubelet. A `Guaranteed` QoS Pod, whose CPU and Memory Request and Limit are identical, always escapes the kubelet's Eviction targets.

Among the Pods that became Eviction targets, the kubelet removes the Pods with lower Priority according to the Priority Class first. If there are Pods with the same Priority, the Pod using more Resources in excess of its Request value is removed first. The kubelet monitors the actual CPU and Memory Resource usage of Pods by polling through its embedded cAdvisor. If Memory usage increases suddenly between polling intervals and the kubelet cannot obtain the Node's Memory state from cAdvisor and thus cannot perform Pod Eviction, the Pod is killed by the OOM Killer of the Linux Kernel.

#### 1.2.2. Disk and inode Shortage

When Disk capacity runs short, the kubelet removes Pods with lower QoS first through Eviction. Among Pods with the same QoS, the Pod using more Disk capacity is removed first. When inodes run short, the kubelet removes arbitrary Pods with lower QoS first through Eviction.

## 2. References

* Pod Priority and Preemption : [https://kubernetes.io/docs/concepts/configuration/pod-priority-preemption/](https://kubernetes.io/docs/concepts/configuration/pod-priority-preemption/)
* Node-pressure Eviction : [https://kubernetes.io/docs/tasks/administer-cluster/out-of-resource/#evicting-end-user-pods](https://kubernetes.io/docs/tasks/administer-cluster/out-of-resource/#evicting-end-user-pods)
* Kubernetes Pod Eviction : [https://m.blog.naver.com/PostView.nhn?blogId=alice-k106&logNo=221676471427&referrerCode=0&searchKeyword=Eviction](https://m.blog.naver.com/PostView.nhn?blogId=alice-k106&logNo=221676471427&referrerCode=0&searchKeyword=Eviction)
* Does Kubernetes consider the current memory usage when scheduling pods - Stack Overflow : [https://stackoverflow.com/questions/56486023/does-kubernetes-consider-the-current-memory-usage-when-scheduling-pods](https://stackoverflow.com/questions/56486023/does-kubernetes-consider-the-current-memory-usage-when-scheduling-pods)

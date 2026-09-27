---
title: Kubernetes Pod with Linux OOM Killer
---

This post organizes the behavior of the Linux Kernel's OOM Killer related to Kubernetes Pods.

## 1. Kubernetes Pod with Linux OOM Killer

The cases where the Linux Kernel's OOM Killer forcibly kills a Pod's Container can be largely divided into two cases. The first case is when a Pod's Container uses more Memory than the Container's Memory Limit value specified in the Pod's Manifest. The second case is when the Node runs short of available Memory. Each case is organized below.

### 1.1. When the Memory Limit is Exceeded

```yaml {caption="[File 1] Pod Manifest Example with nginx Container Memory Limit", linenos=table}
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  labels:
    name: nginx
spec:
  containers:
  - name: nginx
    image: nginx
    resources:
      requests:
        memory: "100Mi"
      limits:
        memory: "200Mi"
```

[File 1] shows the Manifest file of a Pod that owns an `nginx` Container with a Memory Limit set to 200MB. When a Pod is created using [File 1], the Limit of the Memory Cgroup used by the `nginx` Container is set to 200MB. Therefore, the `nginx` Container cannot use more than 200MB of Memory.

```shell {caption="[Shell 1] OOM Killer Log with Memory Cgroup", linenos=table}
$ dmesg
...
[ 1869.151779] Memory cgroup out of memory: Kill process 27881 (stress) score 1100 or sacrifice child
[ 1869.155654] Killed process 27881 (stress) total-vm:8192780kB, anon-rss:7152284kB, file-rss:4kB, shmem-rss:0kB
[ 1869.434078] oom-reaper: reaped process 27881 (stress), now anon-rss:0kB, file-rss:0kB, shmem-rss:0kB
```

If there is available Swap Memory space on the Node, the `nginx` Container uses the Swap Memory space when it uses more than 200MB of Memory. If there is no available Swap Memory space on the Node, or Swap Memory is disabled, the `nginx` Container is forcibly killed by the OOM Killer when it uses more than 200MB of Memory. [Shell 1] shows the Linux Kernel Log when a Pod's Container is selected and killed by the OOM Killer because it used more Memory than the Limit value of the Memory Cgroup.

### 1.2. When the Node Runs Short of Memory

The kubelet running on each Node of a Kubernetes Cluster monitors the Resource usage of all Containers running on the Node on a **Polling** basis through the cAdvisor embedded in the kubelet. cAdvisor is a tool that measures the Resource usage of all Containers based on Cgroups. If the total Memory usage of all Containers on the Node exceeds the Memory capacity allocatable to the Node's Containers, the kubelet secures the Node's Memory by deleting Pods through the Pod Eviction process according to priority.

The problem is that if the total Memory usage of all Containers on the Node surges suddenly, an arbitrary Container can be forcibly killed by the OOM Killer before the kubelet obtains the Memory usage of all Containers on the Node through cAdvisor Polling and performs Pod Eviction. Kubernetes sets the `oom_score_adj` value so that Pods with a higher Level of QoS are selected last by the OOM Killer.

{{< table caption="[Table 1] oom-score-adj Values According to Pod QoS" >}}
| Pod QoS | `oom_score_adj` |
|---|---|
| Guaranteed | -998 |
| Burstable | `min(max(2, 1000 - (1000 * memoryRequestBytes) / machineMemoryCapacityBytes), 999)` |
| BestEffort | 1000 |
{{< /table >}}

[Table 1] shows the `oom_score_adj` values set by Kubernetes according to the Pod's QoS. Guaranteed has a fixed value of -998, and BestEffort has a fixed value of 1000. Burstable has a lower value as the Container's Memory Request value specified in the Pod's Manifest is higher, and has a value between 2 and 999. The Linux Kernel manages an `oom_score` value for each Process, and the higher a Process's Memory usage, the higher the `oom_score` value. The `oom_score` value ranges between 0 and 1000.

The higher the sum of the `oom_score` value of a Container's Process and the `oom_score_adj` value set by Kubernetes, the higher the probability of being selected by the OOM Killer. Also, if the sum is 0, the Process is excluded from OOM Killer selection targets, and if the sum exceeds 1000, the Process is necessarily selected and removed by the OOM Killer. Therefore, the Containers of a Pod with Guaranteed QoS are rarely selected by the OOM Killer, and the Containers of a Pod with BestEffort QoS are necessarily selected and removed by the OOM Killer.

The Containers of a Pod with Burstable QoS have a high probability of being removed by the OOM Killer even if their Memory usage is very low, because the `oom_score_adj` value becomes 999. Conversely, if Memory usage is high, the probability of being removed by the OOM Killer is high because the `oom_score` value is high even if the `oom_score_adj` value is low. In other words, the Containers of a Pod with Burstable QoS are not necessarily selected and removed by the OOM Killer, but they can be selected and removed by the OOM Killer with a high probability.

```shell {caption="[Shell 2] OOM Killer Log with Lack of Node Memory", linenos=table}
$ dmesg
...
[ 2826.282883] Out of memory: Kill process 4070 (stress) score 972 or sacrifice child
[ 2826.289059] Killed process 4070 (stress) total-vm:8192780kB, anon-rss:7231748kB, file-rss:0kB, shmem-rss:0kB
[ 2826.635944] oom-reaper: reaped process 4070 (stress), now anon-rss:0kB, file-rss:0kB, shmem-rss:0kB
```

[Shell 2] shows the Linux Kernel Log when a Pod's Container is selected and killed by the OOM Killer in a state where the Node runs short of Memory. Comparing it with [Shell 1], which contains the Log when killed by the Limit value of the Memory Cgroup, you can see that the contents of the Log are different.

## 2. References

* Node-pressure Eviction : [https://kubernetes.io/docs/tasks/administer-cluster/out-of-resource/#node-oom-behavior](https://kubernetes.io/docs/tasks/administer-cluster/out-of-resource/#node-oom-behavior)

---
title: Kubernetes Pod with Linux OOM Killer
---

Kubernetes Pod와 연관된 Linux Kernel의 OOM Killer의 동작을 정리한다.

## 1. Kubernetes Pod with Linux OOM Killer

Linux Kernel의 OOM Killer가 Pod의 Container를 강제로 죽이는 경우는 크게 2가지의 경우로 나눌수 있다. 첫번째 경우는 Pod의 Container가 Pod의 Manifest에 명시된 Container의 Memory Limit 값보다 더 많은 Memory 용량을 이용할 경우이다. 두번째 경우는 Node에 가용 가능한 Memory 용량이 부족할 경우이다. 각각의 경우를 정리한다.

### 1.1. Memory Limit을 초과한 경우

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

[File 1]은 Memory limit이 200MB로 설정된 nginx Container를 소유하고 있는 Pod의 Manifest 파일을 나타내고 있다. [File 1]을 이용하여 Pod를 생성하면 nginx Container가 이용하는 Memory Cgroup의 Limit에는 200MB가 설정된다. 따라서 nginx Container는 200MB 이상의 Memory 용량을 이용하지 못한다.

```shell {caption="[Shell 1] OOM Killer Log with Memory Cgroup", linenos=table}
$ dmesg
...
[ 1869.151779] Memory cgroup out of memory: Kill process 27881 (stress) score 1100 or sacrifice child
[ 1869.155654] Killed process 27881 (stress) total-vm:8192780kB, anon-rss:7152284kB, file-rss:4kB, shmem-rss:0kB
[ 1869.434078] oom-reaper: reaped process 27881 (stress), now anon-rss:0kB, file-rss:0kB, shmem-rss:0kB
```

만약 Node에 이용가능한 Swap Memory 공간이 존재한다면 nginx Container가 200MB 이상의 Memory 용량을 이용하는 경우 Swap Memory 공간을 이용하게 된다. 만약 Node에 이용가능한 Swap Memory 공간이 존재하지 않거나, Swap Memory가 Disable되어 있는 상태라면 nginx Container가 200MB 이상의 Memory 용량을 이용하는 경우 nginx Container는 OOM Killer에 의해서 강제로 죽는다. [Shell 1]은 Pod의 Container가 Memory Cgroup의 Limit 값보다 많은 Memory 용량을 이용하여 OOM Killer부터 선택되어 죽을때의 Linux Kernel Log를 나타내고 있다.

### 1.2. Node에 Memory가 부족한 경우

Kubernetes Cluster의 각 Node에서 동작하는 kubelet은 kubelet이 내장하고 있는 cAdvisor를 통해서 Node에서 동작하는 모든 Container의 Resource 사용량을 **Polling** 기반으로 Monitoring한다. cAdvisor는 Cgroup을 기반으로 모든 Container의 Resource 사용량을 측정하는 도구이다. 만약 Node의 모든 Container의 총 Memory 사용량이 Node의 Container에게 할당 가능한 Memory 용량을 초과하면, kubelet은 우선순위에 따라서 Pod Eviction 과정을 통해서 Pod를 삭제하여 Node의 Memory를 확보한다.

문제는 Node의 모든 Container의 총 Memory 사용량이 갑작스럽게 급증하게되면, kubelet이 cAdvisor Polling을 통해서 Node의 모든 Container의 Memory 사용량을 얻고 Pod Eviction을 수행하기전에 OOM Killer에 의해서 임의의 Container가 강제로 죽을수 있다. Kubernetes는 높은 Level의 QoS를 갖는 Pod이 OOM Killer로부터 가장 마지막에 선택되도록 oom-score-adj 값을 설정해둔다.

{{< table caption="[Table 1] Pod의 QoS에 따른 oom-score-adj 값" >}}
| Pod QoS | oom-score-adj |
|---|---|
| Guaranteed | -998 |
| Burstable | min(max(2, 1000 - (1000 * memoryRequestBytes) / machineMemoryCapacityBytes), 999) |
| BestEffort | 1000 |
{{< /table >}}

[Table 1]은 Pod의 QoS에 따른 Kubernetes가 설정하는 oom-score-adj 값을 나타내고 있다. Guaranteed는 -998의 고정된 값을 갖으며, BestEffort는 1000의 고정된 값을 갖는다. Burstable는 Pod의 Manifest에 명시된 Container의 Memory Request의 값이 높을수록 낮은 값을 갖으며, 2 ~ 999 사이의 값을 갖는다. Linux Kernel은 각 Process마다 oom-score 값을 관리하고 있으며 Process의 Memory 사용이 높을수록 oom-score 값도 증가한다. oom-score 값은 0 ~ 1000 사이의 값을 갖는다.

Container의 Process의 oom-score 값과 Kubernetes가 설정한 oom-score-adj 값의 합이 높을수록 OOM Killer에 의해서 선택될 확률이 높아진다. 또한 합이 0이면 OOM Killer 선택 대상에서 제외되며, 합이 1000을 넘어가면 OOM Killer에 의해서 반드시 선택되어 제거된다. 따라서 Guaranted QoS를 갖는 Pod의 Container는 OOM killer에 의해서 거의 선택되지 않으며, BestEffort QoS를 갖는 Pod의 Container는 OOM Killer에 의해서 반드시 선택되어 제거된다.

Burstable QoS를 갖는 Pod의 Container는 Memory 사용량이 거의 없더라도 oom-score-adj 값이 999가 되기때문에 높은 확률로 OOM Killer에 의해서 제거될 확률이 높다. 반대로 Memory 사용량이 높으면 oom-score-adj 값이 낮더라도 oom-score 값이 높기 때문에 OOM Killer에 의해서 제거될 확률이 높다. 즉 Burstable QoS를 갖는 Pod의 Container는 OOM Killer에 의해서 반드시 선택되어 제거되지는 않지만, 높은 확률로 OOM Killer에 의해서 선택되어 제거될 수 있다.

```shell {caption="[Shell 2] OOM Killer Log with Lack of Node Memory", linenos=table}
$ dmesg
...
[ 2826.282883] Out of memory: Kill process 4070 (stress) score 972 or sacrifice child
[ 2826.289059] Killed process 4070 (stress) total-vm:8192780kB, anon-rss:7231748kB, file-rss:0kB, shmem-rss:0kB
[ 2826.635944] oom-reaper: reaped process 4070 (stress), now anon-rss:0kB, file-rss:0kB, shmem-rss:0kB
```

[Shell 2]는 Node에 Memory가 부족한 상태에서 Pod의 Container가 OOM Killer부터 선택되어 죽을때의 Linux Kernel Log를 나타내고 있다. Memory Cgroup의 Limit 값에 의해서 죽을때의 Log 내용이 있는 [Shell 1]과 비교해보면, Log의 내용이 다른걸 확인할 수 있다.

## 2. 참조

* [https://kubernetes.io/docs/tasks/administer-cluster/out-of-resource/#node-oom-behavior](https://kubernetes.io/docs/tasks/administer-cluster/out-of-resource/#node-oom-behavior)
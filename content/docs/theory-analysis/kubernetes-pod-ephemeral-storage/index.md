---
title: Kubernetes Pod Ephemeral Storage
draft: true
---

Kubernetes Pod가 이용할 수 있는 Ephemeral Storage는 Node의 Storage를 이용하는 방식과 Node의 Memory를 이용하는 방식이 존재한다. 어떠한 저장소를 이용하냐에 따라서 Pod의 설정과 동작이 달라진다.

## 1. Node Storage 기반의 Ephemeral Storage

Node Storage를 기반으로 하는 Pod의 Ephemeral Storage는 다음과 같은 목적으로 이용된다.

* Container Writable Layer
* Container Log
* `medium` Type이 `Memory`가 아닌 `emptyDir` Volume

```yaml {caption="[File 1] Ephemeral Storage Pod Example", linenos=table}
apiVersion: v1
kind: Pod
metadata:
  name: my-shell-storage
spec:
  containers:
  - name: my-shell
    image: nicolaka/netshoot:v0.14
    args:
    - sleep
    - infinity
    resources:
      requests:
        ephemeral-storage: "1Gi"
      limits:
        ephemeral-storage: "2Gi"
    volumeMounts:
    - name: emptydir-storage
      mountPath: "/tmp"
  volumes:
    - name: emptydir-storage
      emptyDir:
        sizeLimit: 512Mi
```

Node Storage를 기반으로 하는 Ephemeral Storage는 Pod Resource의 `ephemeral-storage`를 통해서 설정할 수 있다. [File 1]은 Ephemeral Storage를 설정하는 `my-shell-storage` Pod의 예제를 나타낸다. `my-shell` Container는 Request로 `1Gi`를 설정하고, Limit으로 `2Gi`를 설정하였다. `emptydir-storage` 이름의 `emptyDir` Volume도 설정되어 있으며 크기는 `512Mi`로 제한되어 있다.

Request의 Ephemeral Storage는 Scheduler가 Pod를 스케줄링할 때만 참조되며, Limit의 Ephemeral Storage는 Container가 실제 사용할 수 있는 최대 크기를 의미한다. 따라서 `my-shell` Container의 Container Writable Layer, Container Log, `emptyDir` Volume를 Ephemeral Storage의 크기의 합이 `4Gi`를 초과하는 경우에는 Evicted 된다. 또한 `emptydir-storage` Volume의 크기가 `512Mi`를 초과하는 경우에도 Evicted 된다.

```bash {caption="[Shell 0] Node Storage Mounted", linenos=table}
$ kubectl exec -it my-shell-storage -- mount | grep /tmp
/dev/nvme0n1p2 on /tmp type ext4 (rw,noatime,errors=remount-ro,commit=600)
```

[Shell 0]은 `my-shell-storage` Pod의 `my-shell` Container에서 `emptydir-storage` Volume를 마운트한 결과를 나타낸다. Node의 Storage가 마운트되어 있음을 확인할 수 있다.

```bash {caption="[Shell 1] Ephemeral Storage Exceeded Example", linenos=table}
$ kubectl get pod 
NAME               READY   STATUS   RESTARTS   AGE
my-shell-storage   0/1     Error    0          2m16s

$ kubectl describe pod my-shell-storage
Events:
  Type     Reason               Age   From               Message
  ----     ------               ----  ----               -------
  Normal   Scheduled            2m6s  default-scheduler  Successfully assigned default/my-shell-storage to dp-worker-6
  Normal   Pulled               2m5s  kubelet            Container image "nicolaka/netshoot:v0.14" already present on machine
  Normal   Created              2m5s  kubelet            Created container my-shell
  Normal   Started              2m5s  kubelet            Started container my-shell
  Warning  Evicted              82s   kubelet            Pod ephemeral local storage usage exceeds the total limit of containers 2Gi.
  Normal   Killing              82s   kubelet            Stopping container my-shell
  Warning  ExceededGracePeriod  72s   kubelet            Container runtime did not kill the pod within specified grace period.
```

```bash {caption="[Shell 2] EmptyDir Volume Exceeded Example", linenos=table}
$ kubectl get pod              
NAME               READY   STATUS   RESTARTS   AGE
my-shell-storage   0/1     Error    0          10m

$ kubectl describe pod my-shell-storage
Events:
  Type     Reason               Age    From               Message
  ----     ------               ----   ----               -------
  Normal   Scheduled            4m38s  default-scheduler  Successfully assigned default/my-shell-storage to dp-worker-6
  Normal   Pulling              4m38s  kubelet            Pulling image "nicolaka/netshoot:v0.14"
  Normal   Pulled               4m6s   kubelet            Successfully pulled image "nicolaka/netshoot:v0.14" in 32.124s (32.124s including waiting). Image size: 203934215 bytes.
  Normal   Created              4m6s   kubelet            Created container my-shell
  Normal   Started              4m5s   kubelet            Started container my-shell
  Warning  Evicted              50s    kubelet            Usage of EmptyDir volume "emptydir-storage" exceeds the limit "512Mi".
  Normal   Killing              50s    kubelet            Stopping container my-shell
  Warning  ExceededGracePeriod  40s    kubelet            Container runtime did not kill the pod within specified grace period.
```

[Shell 1]은 Ephemeral Storage가 `2Gi`를 초과되어 Evicted 된 경우를 나타내며, [Shell 2]는 `emptydir-storage` Volume가 `512Mi`를 초과되어 Evicted 된 경우를 나타낸다.

## 2. Node Memory 기반의 Ephemeral Storage

Node Memory를 기반으로 하는 Ephemeral Storage는 다음과 같은 목적으로 이용된다.

* `medium` Type이 `Memory`인 `emptyDir` Volume

```yaml {caption="[File 2] Ephemeral Storage Pod Example", linenos=table}
apiVersion: v1
kind: Pod
metadata:
  name: my-shell-memory
spec:
  containers:
  - name: my-shell
    image: nicolaka/netshoot:v0.14
    args:
    - sleep
    - infinity
    volumeMounts:
    - name: emptydir-memory
      mountPath: "/tmp"
  volumes:
    - name: emptydir-memory
      emptyDir:
        medium: Memory
        sizeLimit: 512Mi
```

[File 2]는 Node Memory를 기반으로 하는 Ephemeral Storage를 설정하는 `my-shell-memory` Pod의 예제를 나타낸다. `my-shell` Container는 `emptydir-memory` 이름의 `emptyDir` Volume를 이용하며, `512Mi`의 크기를 가지며 `medium` Type이 `Memory`로 설정되어 있다.

```bash {caption="[Shell 3] Memory Medium emptyDir Volume Example", linenos=table}
$ kubectl exec -it my-shell-memory -- mount | grep /tmp
tmpfs on /tmp type tmpfs (rw,relatime,size=524288k)
```

[Shell 3]은 `my-shell-memory` Pod의 `my-shell` Container에서 `emptydir-memory` Volume를 마운트한 결과를 나타낸다. tmpfs Type의 Volume이 `/tmp`에 마운트되어 있음을 확인할 수 있다. tmpfs Volume의 크기는 `512Mi`인 것을 확인할 수 있다. 즉 Pod 내부에서는 tmpfs Volume 크기 이상으로 용량을 사용할 수 없다.

### 2.1. Shared Memory 용량 제한

## 3. 참조

* Ephemeral Storage : [https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#local-ephemeral-storage](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#local-ephemeral-storage)
* Kubernetes Shared Memory : [https://ykarma1996.tistory.com/106](https://ykarma1996.tistory.com/106)
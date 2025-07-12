---
title: Kubernetes Pod Ephemeral Storage
---

Kubernetes Pod가 이용할 수 있는 Ephemeral Storage는 Node의 Storage를 이용하는 방식과 Node의 Memory를 이용하는 방식이 존재한다. 어떠한 저장소를 이용하냐에 따라서 Pod의 설정과 동작이 달라진다.

## 1. Node Storage 기반의 Ephemeral Storage

Node Storage를 기반으로 하는 Pod의 Ephemeral Storage는 다음과 같은 목적으로 이용된다.

* Container Writable Layer
* Container Log (stdout, stderr)
* **Memory** Type의 Medium이 아닌 **emptyDir** Volume

```yaml {caption="[File 1] Node Storage Ephemeral Storage Pod Example", linenos=table}
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

Node Storage를 기반으로 하는 Ephemeral Storage는 Pod Resource의 `ephemeral-storage`를 통해서 설정할 수 있다. [File 1]은 Node Storage를 기반으로 하는 Ephemeral Storage를 설정하는 `my-shell-storage` Pod의 예제를 나타낸다. `my-shell` Container는 Request로 `1Gi`를 설정하고, Limit으로 `2Gi`를 설정하였다. `emptydir-storage` 이름의 **empyDir** Volume도 설정되어 있으며 크기는 `512Mi`로 제한되어 있다.

Request의 Ephemeral Storage는 Scheduler가 Pod를 스케줄링할 때만 참조되며, Limit의 Ephemeral Storage는 Container가 실제 사용할 수 있는 최대 크기를 의미한다. 따라서 `my-shell` Container의 Container Writable Layer, Container Log, **empyDir** Volume를 Ephemeral Storage의 크기의 합이 `4Gi`를 초과하는 경우에는 Evicted 된다. 또한 `emptydir-storage` Volume의 크기가 `512Mi`를 초과하는 경우에도 Evicted 된다.

```bash {caption="[Shell 1] Node Storage Mounted", linenos=table}
$ kubectl exec -it my-shell-storage -- mount | grep /tmp
/dev/nvme0n1p2 on /tmp type ext4 (rw,noatime,errors=remount-ro,commit=600)
```

[Shell 1]은 `my-shell-storage` Pod에서 `emptydir-storage` Volume를 마운트한 결과를 나타낸다. Node의 Storage가 Bind Mount되어 있음을 확인할 수 있다.

```bash {caption="[Shell 2] Node Storage Ephemeral Storage Exceeded Example", linenos=table}
$ kubectl get pod
NAME               READY   STATUS   RESTARTS   AGE
my-shell-storage   0/1     Error    0          107s

$ kubectl describe pod my-shell-storage
Events:
  Type     Reason               Age   From               Message
  ----     ------               ----  ----               -------
  Normal   Scheduled            112s  default-scheduler  Successfully assigned default/my-shell-storage to dp-worker-6
  Normal   Pulled               112s  kubelet            Container image "nicolaka/netshoot:v0.14" already present on machine
  Normal   Created              112s  kubelet            Created container my-shell
  Normal   Started              112s  kubelet            Started container my-shell
  Warning  Evicted              49s   kubelet            Pod ephemeral local storage usage exceeds the total limit of containers 2Gi.
  Normal   Killing              49s   kubelet            Stopping container my-shell
  Warning  ExceededGracePeriod  39s   kubelet            Container runtime did not kill the pod within specified grace period.
```

```bash {caption="[Shell 3] Node Storage EmptyDir Volume Exceeded Example", linenos=table}
$ kubectl get pod
NAME               READY   STATUS   RESTARTS   AGE
my-shell-storage   0/1     Error    0          106s

$ kubectl describe pod my-shell-storage
Events:
  Type     Reason               Age   From               Message
  ----     ------               ----  ----               -------
  Normal   Scheduled            112s  default-scheduler  Successfully assigned default/my-shell-storage to dp-worker-6
  Normal   Pulled               112s  kubelet            Container image "nicolaka/netshoot:v0.14" already present on machine
  Normal   Created              112s  kubelet            Created container my-shell
  Normal   Started              112s  kubelet            Started container my-shell
  Warning  Evicted              62s   kubelet            Usage of EmptyDir volume "emptydir-storage" exceeds the limit "512Mi".
  Normal   Killing              62s   kubelet            Stopping container my-shell
  Warning  ExceededGracePeriod  52s   kubelet            Container runtime did not kill the pod within specified grace period.
```

[Shell 1]은 `my-shell-storage` Pod의 Ephemeral Storage가 `2Gi`를 초과되어 Pod가 Evicted 된 경우를 나타내며, [Shell 2]는 `my-shell-storage` Pod의 `emptydir-storage` Volume가 `512Mi`를 초과되어 Pod가 Evicted 된 경우를 나타낸다. Node Storage 기반의 Ephemeral Storage의 사용량은 kubelet이 주기적으로 측정하는 방식이다. 따라서 Pod가 사용하는 Node Storage 기반의 Ephemeral Storage가 Limit을 초과하자 마자 Pod는 즉시 Evicted 되지 않고 일정 시간 동안 존재할 수 있다. 일반적으로 용량이 초과되고 30~40초 정도 동안 존재할 수 있다.

## 2. Node Memory 기반의 Ephemeral Storage

Node Memory를 기반으로 하는 Ephemeral Storage는 다음과 같은 목적으로 이용된다.

* **Memory** Type의 Medium을 가지는 **emptyDir** Volume

```yaml {caption="[File 2] Node Memory Ephemeral Storage Pod Example", linenos=table}
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
    resources:
      requests:
        memory: "1Gi"
      limits:
        memory: "2Gi"
    volumeMounts:
    - name: emptydir-memory
      mountPath: "/tmp"
  volumes:
    - name: emptydir-memory
      emptyDir:
        medium: Memory
        sizeLimit: 512Mi
```

[File 2]는 Node Memory를 기반으로 하는 Ephemeral Storage를 설정하는 `my-shell-memory` Pod의 예제를 나타낸다. `my-shell` Container는 `emptydir-memory` 이름의 **emptyDir** Volume를 이용하며, `512Mi`의 크기를 가지며 medium Type이 **Memory**로 설정되어 있다.

```bash {caption="[Shell 3] Memory Medium emptyDir Volume Example", linenos=table}
$ kubectl exec -it my-shell-memory -- mount | grep /tmp
tmpfs on /tmp type tmpfs (rw,relatime,size=524288k)
```

[Shell 3]은 `my-shell-memory` Pod의 `my-shell` Container에서 `emptydir-memory` Volume를 마운트한 결과를 나타낸다. **tmpfs** Type의 Volume이 `/tmp`에 마운트되어 있음을 확인할 수 있다. tmpfs Volume의 크기는 `512Mi`인 것을 확인할 수 있다. 즉 Pod 내부에서는 tmpfs Volume 크기 이상으로 용량을 사용할 수 없다.

```yaml {caption="[File 3] Node Memory Ephemeral Storage without Size Limit Pod Example", linenos=table}
apiVersion: v1
kind: Pod
metadata:
  name: my-shell-memory-no-limit
spec:
  containers:
  - name: my-shell
    image: nicolaka/netshoot:v0.14
    args:
    - sleep
    - infinity
    resources:
      requests:
        memory: "1Gi"
      limits:
        memory: "2Gi"
    volumeMounts:
    - name: emptydir-memory
      mountPath: "/tmp"
  volumes:
    - name: emptydir-memory
      emptyDir:
        medium: Memory
```

[File 3]과 같이 만약 **Memory** Medium의 **empyDir** Volume에 용량을 제약을 설정하지 않을수 있으며, 이 경우에는 최대 Container의 Memory Limit의 크기만큼 사용할 수 있다. [File 3]의 경우에는 `my-shell` Container의 Limit Memory가 `2Gi`이므로 최대 2Gi의 용량을 사용할 수 있다. 만약 Container에 Memory Limit을 설정하지 않으면 최대 Node의 Memory 크기만큼 사용할 수 있다.

하지만 Node의 모든 Memory를 이용하는 경우 해당 Node에서 동작하는 다른 Pod에 영향을 줄수 있기 때문에 권장되는 방법은 아니다. 따라서 **Memory** Medium의 **emptyDir** Volume을 안전하게 이용하기 위해서는 반드시 Container의 Memory Limit을 설정하거나 **empyDir** Volume의 용량을 제한해야 한다.

```bash {caption="[Shell 4] Memory Medium emptyDir Volume without Size Limit Example", linenos=table}
$  kubectl exec -it my-shell-memory -- mount | grep /tmp
tmpfs on /tmp type tmpfs (rw,relatime,size=16245444k)
```

[Shell 4]는 `my-shell-memory-no-limit` Pod의 `my-shell` Container에서 `emptydir-memory` Volume를 마운트한 결과를 나타낸다. **tmpfs** Type의 Volume이 `/tmp`에 마운트되어 있고, 크기는 `16Gi`인 것을 확인할 수 있다. 여기서 `16Gi`는 Node의 Memory 크기이며, **emptyDir** Volume의 용량을 제한하지 않았기 때문에 Node의 Memory 크기만큼 설정되어 있다.

### 2.1. Shared Memory 용량 제한

```yaml {caption="[File 4] Ephemeral Storage Pod Example", linenos=table}
apiVersion: v1
kind: Pod
metadata:
  name: my-shell-memory-shm
spec:
  containers:
  - name: my-shell
    image: nicolaka/netshoot:v0.14
    args:
    - sleep
    - infinity
    resources:
      requests:
        memory: "1Gi"
      limits:
        memory: "2Gi"
    volumeMounts:
    - name: emptydir-memory
      mountPath: "/dev/shm"
  volumes:
    - name: emptydir-memory
      emptyDir:
        medium: Memory
        sizeLimit: 512Mi
```

## 3. 참조

* Ephemeral Storage : [https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#local-ephemeral-storage](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#local-ephemeral-storage)
* Kubernetes Shared Memory : [https://ykarma1996.tistory.com/106](https://ykarma1996.tistory.com/106)
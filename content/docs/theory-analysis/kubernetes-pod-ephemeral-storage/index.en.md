---
title: Kubernetes Pod Ephemeral Storage
---

The Ephemeral Storage available to a Kubernetes Pod comes in two forms: one that uses the **Node's Storage** and one that uses the **Node's Memory**. The Pod's configuration and behavior differ depending on which storage is used.

## 1. Ephemeral Storage based on Node Storage

Ephemeral Storage based on Node Storage is used by a Pod for the following purposes.

* Container Writable Layer
* Container Log (stdout, stderr)
* `emptyDir` Volume whose Medium is not the `Memory` Type

```yaml {caption="[File 1] Node Storage Ephemeral Storage Pod Example", linenos=table}
apiVersion: v1
kind: Pod
metadata:
  name: my-shell-storage
spec:
  containers:
  - name: my-shell
    image: nicolaka/netshoot:v0.14
    args: [sleep, infinity]
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

Ephemeral Storage based on Node Storage can be configured through the `ephemeral-storage` field of the Pod Resource. [File 1] shows an example of the `my-shell-storage` Pod that configures Ephemeral Storage based on Node Storage. The `my-shell` Container sets `1Gi` as the Request and `2Gi` as the Limit. An `emptyDir` Volume named `emptydir-storage` is also configured, and its size is limited to `512Mi`.

The Ephemeral Storage of the Request is referenced only when the Scheduler schedules the Pod, while the Ephemeral Storage of the Limit means the maximum size the Container can actually use. Therefore, if the total Ephemeral Storage size of the `my-shell` Container's Container Writable Layer, Container Log, and `emptyDir` Volume exceeds `4Gi`, the Pod is Evicted. The Pod is also Evicted if the size of the `emptydir-storage` Volume exceeds `512Mi`.

```bash {caption="[Shell 1] Node Storage Mounted", linenos=table}
$ kubectl exec -it my-shell-storage -- mount | grep /tmp
/dev/nvme0n1p2 on /tmp type ext4 (rw,noatime,errors=remount-ro,commit=600)
```

[Shell 1] shows the result of mounting the `emptydir-storage` Volume in the `my-shell-storage` Pod. It can be seen that the Node's Storage is Bind Mounted.

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

[Shell 2] shows the case where the Pod is Evicted because the Ephemeral Storage of the `my-shell-storage` Pod exceeds `2Gi`, and [Shell 3] shows the case where the Pod is Evicted because the `emptydir-storage` Volume of the `my-shell-storage` Pod exceeds `512Mi`. The usage of Ephemeral Storage based on Node Storage is measured periodically by the kubelet. Therefore, the moment the Node Storage based Ephemeral Storage used by the Pod exceeds the Limit, the Pod is not Evicted immediately and can exist for a certain period of time. In general, it can exist for about 30 to 40 seconds after the capacity is exceeded.

## 2. Ephemeral Storage based on Node Memory

Ephemeral Storage based on Node Memory is used for the following single purpose.

* `emptyDir` Volume with the `Memory` Type Medium

```yaml {caption="[File 2] Node Memory Ephemeral Storage Pod Example", linenos=table}
apiVersion: v1
kind: Pod
metadata:
  name: my-shell-memory
spec:
  containers:
  - name: my-shell
    image: nicolaka/netshoot:v0.14
    args: [sleep, infinity]
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

[File 2] shows an example of the `my-shell-memory` Pod that configures Ephemeral Storage based on Node Memory. The `my-shell` Container uses an `emptyDir` Volume named `emptydir-memory`, which has a size of `512Mi` and is configured with the `Memory` Type as its `medium` Type.

An `emptyDir` Volume of the `Memory` Type is included in the Container's Memory usage. Therefore, the Container's Memory Request and Limit must be set larger than the capacity of the `emptyDir` Volume, and must also be set considering the Memory size to be used by the App inside the Container. In the case of [File 2], since the `emptydir-memory` Volume is `512Mi`, the Memory size available to the App inside the Container is at least `1Gi - 512Mi = 512Mi` based on the Request, and at least `2Gi - 512Mi = 1.5Gi` based on the Limit.

```bash {caption="[Shell 4] Memory Medium emptyDir Volume Example", linenos=table}
$ kubectl exec -it my-shell-memory -- mount | grep /tmp
tmpfs on /tmp type tmpfs (rw,relatime,size=524288k)
```

[Shell 4] shows the result of mounting the `emptydir-memory` Volume in the `my-shell` Container of the `my-shell-memory` Pod. It can be seen that a **tmpfs** Type Volume is mounted at `/tmp`. The size of the tmpfs Volume is confirmed to be `512Mi`. In other words, inside the Pod, capacity cannot be used beyond the size of the tmpfs Volume. Since Ephemeral Storage based on Node Storage checks capacity periodically, a temporary capacity excess can occur. This can cause the Pod to be Evicted, but Ephemeral Storage based on Node Memory limits the tmpfs size, so a temporary capacity excess does not occur.

```yaml {caption="[File 3] Node Memory Ephemeral Storage without Size Limit Pod Example", linenos=table}
apiVersion: v1
kind: Pod
metadata:
  name: my-shell-memory-no-limit
spec:
  containers:
  - name: my-shell
    image: nicolaka/netshoot:v0.14
    args: [sleep, infinity]
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

As shown in [File 3], it is possible not to set a capacity limit on an `emptyDir` Volume with the `Memory` Medium, and in this case, it can be used up to the size of the Container's Memory Limit. In the case of [File 3], since the Limit Memory of the `my-shell` Container is `2Gi`, up to `2Gi` of capacity can be used. If no Memory Limit is set on the Container, it can be used up to the size of the Node's Memory.

However, using all of the Node's Memory can affect other Pods running on that Node, so it is not a recommended approach. Therefore, to safely use an `emptyDir` Volume with the `Memory` Medium, the Container's Memory Limit must be set or the capacity of the `emptyDir` Volume must be limited.

```bash {caption="[Shell 5] Memory Medium emptyDir Volume without Size Limit Example", linenos=table}
$  kubectl exec -it my-shell-memory -- mount | grep /tmp
tmpfs on /tmp type tmpfs (rw,relatime,size=16245444k)
```

[Shell 5] shows the result of mounting the `emptydir-memory` Volume in the `my-shell` Container of the `my-shell-memory-no-limit` Pod. It can be seen that a tmpfs Type Volume is mounted at `/tmp` and its size is `16Gi`. Here, `16Gi` is the Memory size of the Node, and since the capacity of the `emptyDir` Volume was not limited, it is set to the Node's Memory size.

### 2.1. Limiting Shared Memory Capacity

```yaml {caption="[File 4] Ephemeral Storage Pod Example", linenos=table}
apiVersion: v1
kind: Pod
metadata:
  name: my-shell-memory-shm
spec:
  containers:
  - name: my-shell
    image: nicolaka/netshoot:v0.14
    args: [sleep, infinity]
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

Setting an `emptyDir` Volume with the `Memory` Medium at the `/dev/shm` path makes it possible to limit the size of the Shared Memory used by the App. [File 4] shows an example of the `my-shell-memory-shm` Pod that limits the size of the Shared Memory. Since the size of the `emptyDir` Volume is limited to `512Mi`, the size of the Shared Memory is also limited to `512Mi`.

## 3. References

* Ephemeral Storage : [https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#local-ephemeral-storage](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#local-ephemeral-storage)
* Kubernetes Shared Memory : [https://ykarma1996.tistory.com/106](https://ykarma1996.tistory.com/106)

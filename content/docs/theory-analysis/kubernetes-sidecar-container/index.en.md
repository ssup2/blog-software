---
title: "Kubernetes Sidecar Container"
---

## 1. Kubernetes Sidecar Container

The Sidecar Container Pattern is used in various ways in Kubernetes environments. For example, Istio implements a mesh architecture using Envoy Proxy running in sidecar containers. However, there were several problems when using the Sidecar Container Pattern in traditional Kubernetes environments.

* It was not possible to specify dependency relationships between Sidecar Containers and App Containers. It was impossible to make Sidecar Containers start first and then App Containers start, or to make App Containers die first and Sidecar Containers die later.
* There was a problem where Pods would not terminate even if App Containers terminated normally, as long as Sidecar Containers did not terminate. This was particularly problematic in Job Pods performing Job workloads.

To solve these problems with the Sidecar Container Pattern, Kubernetes released the Sidecar Container feature. It is available from `version 1.28`. Kubernetes' Sidecar Container feature has the following characteristics:

* Sidecar Containers start before App Containers start. When there are multiple Sidecar Containers, they start one by one according to the manifest order.
* When a Pod terminates, App Containers terminate first, and Sidecar Containers terminate in reverse order of creation. That is, they terminate in reverse order of the manifest.
* When App Containers terminate normally, Sidecar Containers also receive **SIGTERM** and terminate.

```yaml {caption="[File 1] Sidecar Container Example", linenos=table}
apiVersion: v1
kind: Pod
metadata:
  name: sidecar-container-example
spec:
  containers:
  - name: app
    image: nicolaka/netshoot:v0.14
    command: ["sleep", "infinity"]
  initContainers:
  - name: sidecar
    image: nicolaka/netshoot:v0.14
    command: ["sleep", "infinity"]
    restartPolicy: Always
    livenessProbe:
      exec:
        command: ["sh", "-c", "exit 0"]
    readinessProbe:
      exec:
        command: ["sh", "-c", "exit 0"]
```

[File 1] shows a simple Sidecar Container example. In Kubernetes, Sidecar Containers are considered **special Init Containers**. Therefore, to declare Sidecar Containers within a Pod, they must be defined under `initContainers`, and among Init Containers, those with `restartPolicy` set to `Always` are considered Sidecar Containers. If `restartPolicy` is not set or not set to `Always`, they are considered regular Init Containers that run briefly before App Containers start.

Since Sidecar Containers have `restartPolicy` set to `Always`, they continue to restart repeatedly even if terminated for any reason, and operate independently of App Containers. Unlike regular Init Containers, Sidecar Containers can have **Probe** settings. They automatically restart when Liveness Probe fails, and change Pod status to non-**Ready** when Readiness Probe fails, so care must be taken when configuring Readiness Probe.

### 1.1. Verifying Sidecar Container Creation and Termination Order

```yaml {caption="[File 2] Sidecar Container Order Test Example", linenos=table}
apiVersion: v1
kind: Pod
metadata:
  name: sidecar-container-order-example
spec:
  containers:
  - name: app
    image: nicolaka/netshoot:v0.14
    command: ["sh", "-c", "trap 'sleep 3; echo app; exit 0' TERM; sleep infinity & wait"]
  initContainers:
  - name: first-sidecar
    image: nicolaka/netshoot:v0.14
    command: ["sh", "-c", "trap 'sleep 3; echo first-sidecar; exit 0' TERM; sleep infinity & wait"]
    restartPolicy: Always
  - name: second-sidecar
    image: nicolaka/netshoot:v0.14
    command: ["sh", "-c", "trap 'sleep 3; echo second-sidecar; exit 0' TERM; sleep infinity & wait"]
    restartPolicy: Always
```

[File 2] shows an example for verifying the creation and termination order of Sidecar Containers. It consists of one App Container named `app` and two Sidecar Containers named `first-sidecar` and `second-sidecar`. Each container waits using the `sleep` CLI and, upon receiving a SIGTERM signal, waits for **3 seconds** and then outputs its name and terminates.

```bash {caption="[Shell 1] Sidecar Container Order Text Example", linenos=table}
$ kubectl apply -f sidecar-container-order-example.yaml
pod/sidecar-container-order-example created

$ kubectl delete -f sidecar-container-order-example.yaml
pod "sidecar-container-order-example" deleted

$ kubectl get event --sort-by='.lastTimestamp'
LAST SEEN   TYPE     REASON      OBJECT                                MESSAGE
59s         Normal   Pulled      pod/sidecar-container-order-example   Container image "nicolaka/netshoot:v0.14" already present on machine
59s         Normal   Created     pod/sidecar-container-order-example   Created container first-sidecar
59s         Normal   Started     pod/sidecar-container-order-example   Started container first-sidecar
58s         Normal   Pulled      pod/sidecar-container-order-example   Container image "nicolaka/netshoot:v0.14" already present on machine
58s         Normal   Created     pod/sidecar-container-order-example   Created container second-sidecar
58s         Normal   Started     pod/sidecar-container-order-example   Started container second-sidecar
57s         Normal   Pulled      pod/sidecar-container-order-example   Container image "nicolaka/netshoot:v0.14" already present on machine
57s         Normal   Created     pod/sidecar-container-order-example   Created container app
57s         Normal   Started     pod/sidecar-container-order-example   Started container app
30s         Normal   Killing     pod/sidecar-container-order-example   Stopping container first-sidecar
30s         Normal   Killing     pod/sidecar-container-order-example   Stopping container app
30s         Normal   Killing     pod/sidecar-container-order-example   Stopping container second-sidecar
```

```text {caption="[Log 1] Sidecar Container Order Test Example", linenos=table}
2025-07-13 23:47:31.060	app
2025-07-13 23:47:34.206	second-sidecar
2025-07-13 23:47:37.333	first-sidecar
```

[Shell 1] shows an example of creating and deleting the Pod defined in [File 2] and checking events. Since the `first-sidecar` container is defined above the `second-sidecar` container, it can be confirmed through events that the `first-sidecar` container is created first, the `second-sidecar` container is created later, and then the `app` container is created.

When a Pod terminates, events show that Killing events occur simultaneously for each container, but the actual termination time of each container cannot be confirmed. The actual termination time of each container can be confirmed through container logs. [Log 1] shows the logs of each container. It can be confirmed that the `app` container terminates first, the `second-sidecar` container terminates 3 seconds later, and the `first-sidecar` container terminates 3 seconds after that. It can be confirmed that creation and termination occur in reverse order.

### 1.2. Verifying Sidecar Container Termination After App Container Termination

```yaml {caption="[File 3] Sidecar Container Exit Test Example", linenos=table}
apiVersion: v1
kind: Pod
metadata:
  name: sidecar-container-exit-example
spec:
  restartPolicy: Never
  containers:
  - name: app
    image: nicolaka/netshoot:v0.14
    command: ["sh", "-c", "sleep 3; echo app; exit 0"]
  initContainers:
  - name: first-sidecar
    image: nicolaka/netshoot:v0.14
    command: ["sh", "-c", "trap 'sleep 3; echo first-sidecar; exit 0' TERM; sleep infinity & wait"]
    restartPolicy: Always
  - name: second-sidecar
    image: nicolaka/netshoot:v0.14
    command: ["sh", "-c", "trap 'sleep 3; echo second-sidecar; exit 0' TERM; sleep infinity & wait"]
    restartPolicy: Always
```

[File 3] shows an example for verifying that Sidecar Containers terminate after App Container termination. The `app` container outputs its name and terminates 3 seconds after creation, and the `first-sidecar` and `second-sidecar` Sidecar Containers wait using the `sleep` CLI and, upon receiving a SIGTERM signal, wait for **3 seconds** and then output their names and terminate.

```bash {caption="[Shell 2] Sidecar Container Exit Test Example", linenos=table}
$ kubectl apply -f sidecar-container-exit-example.yaml
pod/sidecar-container-exit-example created

$ kubectl get pod sidecar-container-exit-example
NAME                             READY   STATUS      RESTARTS   AGE
sidecar-container-exit-example   0/3     Completed   0          50s

$ kubectl get event --sort-by='.lastTimestamp'
LAST SEEN   TYPE      REASON      OBJECT                               MESSAGE
71s         Normal    Created     pod/sidecar-container-exit-example   Created container first-sidecar
71s         Normal    Pulled      pod/sidecar-container-exit-example   Container image "nicolaka/netshoot:v0.14" already present on machine
71s         Normal    Started     pod/sidecar-container-exit-example   Started container first-sidecar
70s         Normal    Pulled      pod/sidecar-container-exit-example   Container image "nicolaka/netshoot:v0.14" already present on machine
70s         Normal    Created     pod/sidecar-container-exit-example   Created container second-sidecar
70s         Normal    Started     pod/sidecar-container-exit-example   Started container second-sidecar
69s         Normal    Pulled      pod/sidecar-container-exit-example   Container image "nicolaka/netshoot:v0.14" already present on machine
69s         Normal    Created     pod/sidecar-container-exit-example   Created container app
69s         Normal    Started     pod/sidecar-container-exit-example   Started container app
65s         Normal    Killing     pod/sidecar-container-exit-example   Stopping container first-sidecar
65s         Normal    Killing     pod/sidecar-container-exit-example   Stopping container second-sidecar
```

```text {caption="[Log 2] Sidecar Container Exit Test Example", linenos=table}2025-07-14 01:16:50.237	
2025-07-14 01:16:50.237	app
2025-07-14 01:16:54.116	second-sidecar
2025-07-14 01:16:57.242	first-sidecar
```

[Shell 2] shows an example of creating the Pod defined in [File 3] and checking Pod status and events. It can be confirmed that when the `app` container terminates normally, the `second-sidecar` and `first-sidecar` Sidecar Containers also terminate normally in order. [Log 2] confirms through each container's logs that Sidecar Containers receive SIGTERM signals and terminate.

### 1.3. Verifying Sidecar Container Probe

```yaml {caption="[File 4] Sidecar Container Liveness Probe Test Example", linenos=table}
apiVersion: v1
kind: Pod
metadata:
  name: sidecar-container-liveness-fail-example
spec:
  containers:
  - name: app
    image: nicolaka/netshoot:v0.14
    command: ["sleep", "infinity"]
  initContainers:
  - name: sidecar
    image: nicolaka/netshoot:v0.14
    command: ["sleep", "infinity"]
    restartPolicy: Always
    livenessProbe:
      exec:
        command: ["sh", "-c", "exit 1"]
    readinessProbe:
      exec:
        command: ["sh", "-c", "exit 0"]
```

```bash {caption="[Shell 3] Sidecar Container Liveness Probe Test Example", linenos=table}
$ kubectl get pod
NAME                                      READY   STATUS    RESTARTS      AGE
sidecar-container-liveness-fail-example   2/2     Running   1 (60s ago)   2m1s

$ kubectl describe pod sidecar-container-liveness-fail-example
Events:
  Type     Reason     Age                 From               Message
  ----     ------     ----                ----               -------
  Normal   Scheduled  117s                default-scheduler  Successfully assigned default/sidecar-container-liveness-fail-example to dp-worker-6
  Normal   Pulled     116s                kubelet            Container image "nicolaka/netshoot:v0.14" already present on machine
  Normal   Created    116s                kubelet            Created container app
  Normal   Started    116s                kubelet            Started container app
  Normal   Pulled     57s (x2 over 117s)  kubelet            Container image "nicolaka/netshoot:v0.14" already present on machine
  Normal   Created    57s (x2 over 117s)  kubelet            Created container sidecar
  Normal   Started    57s (x2 over 117s)  kubelet            Started container sidecar
  Warning  Unhealthy  27s (x6 over 108s)  kubelet            Liveness probe failed:
  Normal   Killing    27s (x2 over 87s)   kubelet            Init container sidecar failed liveness probe
```

[File 4] shows an example for verifying when a Sidecar Container's Liveness Probe fails. [Shell 3] shows an example of creating the Pod defined in [File 4] and checking Pod status and events. It can be confirmed that the Sidecar's Liveness Probe fails and continues to attempt restarts.

```yaml {caption="[File 5] Sidecar Container Readiness Probe Test Example", linenos=table}
apiVersion: v1
kind: Pod
metadata:
  name: sidecar-container-readiness-fail-example
spec:
  containers:
  - name: app
    image: nicolaka/netshoot:v0.14
    command: ["sleep", "infinity"]
  initContainers:
  - name: sidecar
    image: nicolaka/netshoot:v0.14
    command: ["sleep", "infinity"]
    restartPolicy: Always
    livenessProbe:
      exec:
        command: ["sh", "-c", "exit 0"]
    readinessProbe:
      exec:
        command: ["sh", "-c", "exit 1"]
```

```bash {caption="[Shell 4] Sidecar Container Readiness Probe Test Example", linenos=table}
$ kubectl get pod
NAME                                       READY   STATUS    RESTARTS   AGE
sidecar-container-readiness-fail-example   1/2     Running   0          106s

$ kubectl describe pod sidecar-container-readiness-fail-example
Events:
  Type     Reason     Age                From               Message
  ----     ------     ----               ----               -------
  Normal   Scheduled  73s                default-scheduler  Successfully assigned default/sidecar-container-readiness-fail-example to dp-worker-6
  Normal   Pulled     72s                kubelet            Container image "nicolaka/netshoot:v0.14" already present on machine
  Normal   Created    72s                kubelet            Created container sidecar
  Normal   Started    72s                kubelet            Started container sidecar
  Normal   Pulled     71s                kubelet            Container image "nicolaka/netshoot:v0.14" already present on machine
  Normal   Created    71s                kubelet            Created container app
  Normal   Started    71s                kubelet            Started container app
  Warning  Unhealthy  2s (x11 over 71s)  kubelet            Readiness probe failed:
```

[File 5] shows an example for verifying when a Sidecar Container's Readiness Probe fails. [Shell 4] shows an example of creating the Pod defined in [File 5] and checking Pod status and events. It can be confirmed that the Sidecar's Readiness Probe fails and the Pod status remains non-**Ready**.

## 2. References

* Kubernetes Sidecar Container : [https://kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/](https://kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/)


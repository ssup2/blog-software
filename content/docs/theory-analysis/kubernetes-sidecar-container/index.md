---
title: "Kubernetes Sidecar Container"
---

## 1. Kubernetes Sidecar Container

Kubernetes 환경에서 Sidecar Container Pattern은 다양한 방법으로 활용되고 있다. 대표적으로 Istio에서는 Sidecar Container에서 동작하는 Envoy Proxy를 이용하여 Mesh Architecture를 구현하고 있다. 하지만 기존의 Kubernetes 환경에서 Sidecar Container Pattern을 이용하는데는 몇가지 문제가 있었다.

* Sidecar Container와 App Container의 의존성 관계를 명시할 수 없었다. Sidecar Container가 먼저 시작되고 App Container 시작되게 만들거나, App Container가 먼저 죽고 Sidecar Container가 나중에 죽게 만들거나 하는 것이 불가능했다.
* App Container가 정상 종료가 되어도 Sidecar Container가 종료되지 않으면 Pod가 종료되지 않는 문제가 있었다. 이러한 문제는 Job Workload를 수행하는 Job Pod에서 특히 문제가 되었다.

이러한 Sidecar Container Pattern의 문제를 해결하기 위해서 Kubernetes는 Sidecar Container 기능을 출시했다. `1.28 Version`부터 이용이 가능하다. Kubernetes의 Sidecar Container 기능은 다음과 같은 특징을 갖는다.

* App Container가 시작하기 전에 Sidecar Container가 먼저 시작된다. 다수의 Sidecar Container가 있을 경우에는 Manifest 순서에 따라서 하나씩 시작된다.
* Pod가 종료되면 먼저 App Container가 종료되고, Sidecar Container가 생성된 순서의 역순으로 종료된다. 즉 Manifest의 역순으로 종료된다.
* App Container가 정상 종료되면 Sidecar Container도 **SIGTERM**을 전달받고 종료된다.

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

[File 1]은 간단한 Sidecar Container의 예제를 나타낸다. Kubernetes에서는 Sidecar Container를 **특수한 Init Container**로 간주한다. 따라서 Pod 내부에서 Sidecar Container를 선언하기 `initContainers` 하위에 정의해야 하며, Init Container 중에서 `restartPolicy`가 `Always`로 설정되어 있으면 Sidecar Container로 간주된다. `restartPolicy`가 설정되어 있지 않거나 `Always`로 설정되어 있지 않은 경우에는 App Container 동작전 잠깐 동안 동작하는 일반적인 Init Container로 간주된다.

Sidecar Container는 `restartPolicy`가 `Always`로 설정되어 있기 어떤한 이유로 종료되어도 계속해서 반복해서 실행되며, App Container와 별개로 동작한다. Sidecar Container는 일반 Init Container와 다르게 **Probe** 설정이 가능하다. Livness Probe 실패시 자동으로 재시작하며, Readiness Probe 실패시에는 Pod의 상태를 **Ready**가 아닌 상태로 변경하기 때문에, Readiness Probe 설정에는 주의가 필요하다.

### 1.1. Sidecar Container 생성, 종료 순서 확인

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

[File 2]는 Sidecar Container의 생성, 종료 순서를 확인하기 위한 예제를 나타낸다. `app` 이름을 갖는 하나의 App Container와 `first-sidecar`와 `second-sidecar` 이름을 갖는 두 개의 Sidecar Container로 구성되어 있다. 각 Container는 `sleep` CLI로 대기하고 있다가 SIGTERM Signal을 받으면 **3초**동안 대기 이후에 자신의 이름을 출력하고 종료되도록 구성하였다.

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

[Shell 1]은 [File 2]에 정의된 Pod를 생성, 삭제를 수행하고 이벤트를 확인하는 예제를 나타낸다. `first-sidecar` Container가 `second-sidecar` Container보다 위에 정의되어 있기 때문에, `first-sidecar` Container가 먼저 생성되고 `second-sidecar` Container가 나중에 생성되고 이후에 `app` Container가 생성되는걸 이벤트를 통해서 확인할 수 있다.

Pod가 종료될때는 Event에는 동시간에 각 Container에 대해서 Killing 이벤트가 발생하는걸 확인할 수 있으며, 실제 각 Container가 언제 종료되는지는 확인할 수 없다. 실제 각 Container가 종료되는 시간은 Container Log를 통해서 확인할 수 있다. [Log 1]은 각 Container의 Log를 나타낸다. 가장 먼저 `app` Container가 종료되고, 3초 이후에 `second-sidecar` Container가 종료되고, 3초 이후에 `first-sidecar` Container가 종료되는걸 확인할 수 있다. 생성과 종료 순서가 역순으로 발생하는걸 확인할 수 있다.

### 1.2. App Container 종료 후 Sidecar Container 종료 확인

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

[File 3]은 App Container가 종료된 후 Sidecar Container가 종료되는 것을 확인하기 위한 예제를 나타낸다. `app` Container는 생성후 3초 이후에 이름을 출력하고 종료되며, `first-sidecar`, `second-sidecar` Sidecar Container는 `sleep` CLI로 대기하고 있다가 SIGTERM Signal을 받으면 **3초**동안 대기 이후에 자신의 이름을 출력하고 종료되도록 구성하였다.

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

[Shell 2]는 [File 3]에 정의된 Pod를 생성하고 Pod의 상태와 이벤트를 확인하는 예제를 나타낸다. `app` Container가 정상 종료되면 `second-sidecar`, `first-sidecar` Sidecar Container도 순서대로 정상 종료되는걸 확인할 수 있다. [Log 2]는 각 Container의 Log를 통해서 Sidecar Container가 SIGTERM Signal을 받고 종료되는걸 확인할 수 있다.

### 1.3. Sidecar Container Probe 확인

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

[File 4]는 Sidecar Container의 Liveness Probe가 실패하는 경우를 확인하기 위한 예제를 나타낸다. [Shell 3]은 [File 4]에 정의된 Pod를 생성하고 Pod의 상태와 이벤트를 확인하는 예제를 나타낸다. Sidecar의 Liveness Probe가 실패하면서 계속해서 재시작을 시도하는걸 확인할 수 있다.

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

[File 5]는 Sidecar Container의 Readiness Probe가 실패하는 경우를 확인하기 위한 예제를 나타낸다. [Shell 4]는 [File 5]에 정의된 Pod를 생성하고 Pod의 상태와 이벤트를 확인하는 예제를 나타낸다. Sidecar의 Readiness Probe가 실패하면서 Pod의 상태가 **Ready**가 아닌 상태로 유지되는걸 확인할 수 있다.

## 2. 참조

* Kubernetes Sidecar Container : [https://kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/](https://kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/)
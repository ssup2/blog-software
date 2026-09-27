---
title: Kubernetes Pod
---

This post analyzes the Kubernetes Pod.

## 1. Pod

{{< figure caption="[Figure 1] Kubernetes Pod" src="images/pod-component.png" width="500px" >}}

A **Pod** is the **Container management unit** used in Kubernetes. Kubernetes performs Scheduling and Load Balancing on a per-Pod basis. Most Pods consist of a single Container, but they can also consist of multiple Containers. Such a Pod is called a Multi-container Pod. The Containers of a Multi-container Pod share the same Network Namespace and IPC Namespace. They also share the same Volume (Storage).

Each Container of a Pod mostly runs only one App. If only one App runs in a Container, the Container is removed when the App dies. That is, the Life Time of the App and the Life Time of the Container become identical. In addition, if the App's Log is configured to be output to stdout/stderr, the App's Log can be easily grasped from outside the Container. Of course, it is also possible to run multiple Apps in one Container and run only one Container in one Pod, but the advantages mentioned above disappear.

The Apps running inside each Container of a Multi-container Pod generally operate tightly coupled with each other. They mainly consist of one Main App and auxiliary Apps that assist the Main App. A Web Server and a Log Watcher that analyzes the Web Server's Log are a representative example.

### 1.1. (Linux) Namespace

{{< figure caption="[Figure 2] Kubernetes Pod Namespace" src="images/pod-namespace.png" width="650px" >}}

As mentioned above, the Containers of a Multi-container Pod have the characteristic of sharing the same Network Namespace and IPC Namespace. The shared Namespace here is not the Namespace of an App Container, but the Namespace of the Pause Container that Kubernetes creates one for each Pod. The reason for not using the Namespace of an App Container is the instability of App Containers. If the App of an App Container dies, the App Container is removed, and the Namespace of the App Container is also removed together. Since Kubernetes cannot know when the App of an App Container will die, it also cannot know when the Namespace of the App Container will be removed. Therefore, Kubernetes does not use the Namespace of an App Container as the shared Namespace of the Pod.

The Pause Container runs a Binary called `pause`. The `pause` Binary calls the `pause()` System Call and becomes Blocked until it receives a Signal. That is, since the `pause` Binary does not die until it receives a Signal, the Pause Container can exist stably. Therefore, Kubernetes uses the Namespace of the stable Pause Container as the shared Namespace of the Pod.

### 1.2. Resource Manage (Cgroup)

{{< figure caption="[Figure 3] Kubernetes Pod Cgroup " src="images/pod-cgroup.png" width="650px" >}}

The Resources of a Pod include **CPU** and **Memory**. Both CPU and Memory are controlled using the Cgroup of the Linux Kernel. [Figure 3] shows how Kubernetes organizes Cgroups. There are Cgroups on a per-Pod basis, such as Pod A, Pod B, and Pod C. And under a Pod Cgroup, there are the Cgroup of the App Container belonging to the Pod and the Cgroup of the Pause Container, respectively.

Kubernetes provides 3 QoS Classes: Guaranteed, Burstable, and BestEffort. Depending on the Resource configuration of a Pod, the QoS of the Pod belongs to one of the 3 Classes. Pods belonging to the Burstable and BestEffort Classes belong under the corresponding Cgroup. And Pods belonging to the Guaranteed Cgroup belong under the `kubepods` Cgroup, the top-level Cgroup created by Kubernetes. The `kubepods` Cgroup is created under all Cgroups such as `cpu`, `memory`, and `freezer`, respectively.

```yaml {caption="[File 1] Kubernetes Pod Example", linenos=table}
apiVersion: v1
kind: Pod
metadata:
  name: frontend
spec:
  containers:
  - name: db
    image: mysql
    env:
    - name: MYSQL-ROOT-PASSWORD
      value: "password"
      resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"
  - name: wp
    image: wordpress
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"
```

[File 1] is a configuration file of a Kubernetes Pod. There is no feature to configure Pod Resources on a per-Pod basis; CPU and Memory can be configured on a per-App Container basis for the Containers belonging to the Pod. There are two CPU and Memory configuration values: **Request** and **Limit**. Request means the guaranteed value that the Container can use, and Limit represents the maximum value that the Container can use.

#### 1.2.1. CPU

The CPU Resource value uses a unique unit called **milicpu**. 1000milicpu is equal to 1cpu. Here, 1cpu means the Bandwidth of 1 CPU Core seen by the Container. If the Container runs on a physical machine, 1cpu means the Bandwidth of 1 physical CPU Core, and if the Container runs on a VM, 1cpu means the Bandwidth of 1 vCPU Core, a virtual CPU.

```text {caption="[Formula 1] CPU Quota Calculation 01", linenos=table}
(cfs-quota-us / cfs-period-us) * 1000 = Limit milicpu
(150000 / 100000) * 1000 = 1500 milicpu
```

```text {caption="[Formula 1] CPU Quota Calculation 02", linenos=table}
(milicpu / 1000) * cfs-period-us = cfs-quota-us
0.5 * 100000 = 50000
```

The **CPU Limit** value is used to set the CPU Quota of the Cgroup, which is used to limit the CPU Bandwidth of a Process in Linux. The CPU Quota is manipulated with two values: `cfs-period-us` and `cfs-quota-us`. `cfs-period-us` means the Quota period, and the Default value is 100000. `cfs-quota-us` is a value that sets how much CPU can be used at most during the Quota period. If the `cfs-quota-us` value is set to 150000, the Container can use at most 1500milicpu according to [Formula 1].

The maximum CPU Limit value that can be set is limited by the number of (v)CPUs on which the Container runs. If the Node where the Container runs has only 4 (v)CPUs, at most 4000milicpu can be allocated to the Container. [Formula 2] can be made using [Formula 1]. [Formula 2] shows how Kubernetes calculates the `cfs-quota-us` value according to the CPU limit. The `cfs-period-us` value always uses the Default value of 100000. If the CPU limit is set to 500milicpu, the `cfs-quota-us` value becomes 50000 according to [Formula 2].

```text {caption="[Formula 3] CPU Weight Calculation", linenos=table}
Contaier A : (1500 / 2000) * 1024 = 768
Contaier B : (500 / 2000) * 1024 = 256
```

The **CPU Request** value is used to set the CPU Weight of the Cgroup, which is used to give Scheduling weights to Processes in Linux. In the Cgroup, the CPU Weight is manipulated with a value called `shares`. If Process A has 1024 `shares` and Process B has 512 `shares`, Process A can use twice as much CPU Bandwidth as Process B. Using the CPU Weight and Kubernetes Pod Scheduling, the CPU Request value that the Container demands can be provided to the Container.

Assuming that on a Node with 2000 milicpu (2 CPUs), Container A requests 1500 milicpu as the Request and Container B requests 500 milicpu as the Request, only the 3:1 ratio of the Weights of Container A and Container B needs to be satisfied. The reference value for applying the ratio uses 1024, the default value of `shares`. Therefore, the `shares` value of Container A becomes 768 and the `shares` value of Container B becomes 256. The `shares` value can be calculated through [Formula 3].

#### 1.2.2. Memory

The Memory Resource value uses common capacity units (Byte, MB, GB). The **Memory Limit** value is used to set the Memory Limit value of the Cgroup, which is used to limit the Memory usage of a Process in Linux. The capacity value set for the Container is used as the Memory Limit value as it is. The Memory Limit value cannot be larger than the Memory value of the Node where the Container runs. The Memory Limit value is manipulated with a value called `limit-in-bytes` of the Cgroup. The **Memory Request** value is not used for Cgroup configuration and is only used during Kubernetes Pod Scheduling.

#### 1.2.3. QoS

As mentioned above, Kubernetes provides 3 QoS Classes: **Guaranteed, Burstable, and BestEffort**. Depending on the Resource configuration of the Containers belonging to a Pod, the Pod is classified into one QoS Class and managed.

* **Guaranteed** : The QoS Class with the highest priority, focusing on guaranteeing the Resources that the Pod will use. Kubernetes forcibly kills a Guaranteed Pod only when the Resources used by the Guaranteed Pod grow beyond the Limit value. If all Containers belonging to the Pod have the same CPU Limit and CPU Request values and the same Memory Limit and Memory Request values, the Pod is set to the Guaranteed Class. When only the Limit value is set without setting the Request value, Kubernetes matches the Request value to the Limit value by default, so a Pod becomes a Guaranteed Pod even if only the CPU Limit and Memory Limit values are set.
* **Burstable** : The middle-priority QoS Class, focusing on providing the minimum Resources that the Pod will use. Kubernetes can forcibly kill a Burstable Pod when the Node lacks Resources, there are no BestEffort Pods, and the Resources used by the Burstable Pod are larger than the Request value. If the Pod does not satisfy the Resource Limit Guaranteed Class condition and at least one Container belonging to the Pod has a Request value in its Resources, the Pod is set to the Burstable Class.
* **BestEffort** : The QoS Class with the lowest priority, which does not intervene in the Pod's Resource usage. However, Kubernetes starts forcibly killing BestEffort Pods first when the Node lacks Resources. If none of the Resources of all Containers belonging to the Pod are set, the Pod is set to the BestEffort Class.

### 1.3. Manage

Kubernetes provides several techniques for Pod management and control.

#### 1.3.1. Probe

Probe is a technique in Kubernetes for monitoring the normal operation of Containers. The kubelet Daemon running on each Node periodically calls the Handler defined for each Container to monitor the normal operation of the Container. There are broadly 3 Types of Handlers: Exec, TCP Socket, and HTTP Get.

* **Exec** : Executes a specific command inside the Container. If the Exit Code of the executed command is 0, the Container is considered to be in a normal state, and if it is not 0, it is considered not to be in a normal state.
* **TCP Socket** : If the Container has a specific Port number open, the Container is considered to be in a normal state.
* **HTTP Get** : Sends an HTTP Get Request to the Container, and if a normal response comes, the Container is considered to be in a normal state.

There are 2 kinds of Probes: `livenessProbe` and `readinessProbe`. `livenessProbe` and `readinessProbe` can be defined for each Container.

* `livenessProbe` : A Probe for detecting that the Container is in the Running state. If the result of the `livenessProbe` is failure, Kubernetes deletes the Container and either restarts the Container or leaves it as it is according to the Container's Restart Policy.
* `readinessProbe` : A Probe for detecting whether the Container is in a state where it can receive Service requests. If the result of the `readinessProbe` is failure, Kubernetes removes the IP setting of the Pod that has the Container, preventing the Pod from providing the Service.

```yaml {caption="[File 2] Kubernetes Pod livenessProbe Example", linenos=table}
apiVersion: v1
kind: Pod
metadata:
  labels:
    test: liveness
  name: liveness-exec
spec:
  containers:
  - name: liveness
    image: k8s.gcr.io/busybox
    args:
    - /bin/sh
    - -c
    - touch /tmp/healthy; sleep 30; rm -rf /tmp/healthy; sleep 600
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/healthy
      initialDelaySeconds: 5
      periodSeconds: 5
```

[File 2] shows an example of a Pod using an Exec Type `livenessProbe`. [File 2] represents a Pod that creates the `/tmp/healthy` file, waits for 30 seconds, deletes the `/tmp/healthy` file, waits for 600 seconds, and then disappears. The `livenessProbe` performs the command that reads the `/tmp/healthy` file through the `cat` command every 5 seconds. For 30 seconds, the `/tmp/healthy` file exists, so the Probe result will be success, but after 30 seconds, the `/tmp/healthy` file disappears, so the Probe result becomes failure.

#### 1.3.2. Init Container

An Init Container is a Container created before the App Containers of a Pod operate, for purposes such as Pod initialization and waiting for external Services. Init Containers use the Network Namespace and IPC Namespace of the Pause Container in the same way as App Containers. They can also access the Volumes provided by the Pod in the same way. Therefore, through Init Containers, the Network Routing Table used by App Containers can be changed, or Volumes can be initialized.

```yaml {caption="[File 3] Kubernetes Pod Init Container Example", linenos=table}
apiVersion: v1
kind: Pod
metadata:
  name: myapp-pod
  labels:
    app: myapp
spec:
  containers:
  - name: myapp-container
    image: busybox
    command: ['sh', '-c', 'echo The app is running! && sleep 3600']
  initContainers:
  - name: init-myservice
    image: busybox
    command: ['sh', '-c', 'until nslookup myservice; do echo waiting for myservice; sleep 2; done;']
  - name: init-mydb
    image: busybox
    command: ['sh', '-c', 'until nslookup mydb; do echo waiting for mydb; sleep 2; done;']
```

[File 3] is an example using 2 Init Containers. When multiple Init Containers exist, they are executed in order starting from the Init Container defined first. The next Init Container is executed only after the previous Init Container terminates normally. Only after the last Init Container terminates normally are the App Containers executed. Therefore, Init Containers must be Containers that terminate after performing initialization. In [File 3], Containers are created in the order of `init-myservice` -> `init-mydb` -> `myapp-container`. If an Init Container does not terminate normally, the Pod is restarted to execute the Init Containers again or left as it is, according to the Pod's Restart policy.

#### 1.3.3. Container Life Cycle Hook

```yaml {caption="[File 4] Kubernetes Container Life Cycle Hook Example", linenos=table}
apiVersion: v1
kind: Pod
metadata:
  name: lifecycle-demo
spec:
  containers:
  - name: lifecycle-demo-container
    image: nginx
    lifecycle:
      postStart:
        exec:
          command: ["/bin/sh", "-c", "echo test"]
      preStop:
        httpGet:
          path: "/test"
          port: 8080
```

Container Life Cycle Hooks make it possible to perform specific actions according to the life cycle Events of each Container. [File 4] shows Container Life Cycle Hooks. Currently, Kubernetes provides the `postStart` Hook and the `preStop` Hook. Neither the `postStart` Hook nor the `preStop` Hook provides a feature to pass specific Data as a Parameter.

* `postStart` Hook : A Hook executed after creating the Container's Init Process (Command) and Namespaces. Even if the Container's Init Process operates normally, if the Container's `postStart` Hook does not complete execution properly, the Container does not change to the Running state. If the Container's `postStart` Hook fails, Kubernetes forcibly kills the Container.
* `preStop` Hook : A Hook executed before stopping the Container. Container deletion is attempted only after the `preStop` Hook completes normally. Therefore, if the Container's `preStop` Script does not terminate, the Container cannot be deleted. To solve this problem, Kubernetes allows the Timeout duration of the `preStop` Hook to be specified through the `terminationGracePeriodSeconds` option. If the Container's `preStop` Hook fails or is forcibly terminated due to a Timeout, Kubernetes forcibly kills the Container.

The Hook Handler Types provided are Exec and HTTP.

* **Exec** : Executes a command inside the Container's Namespace. If the Exit Code value of the command is 0, it is considered a success, and if it is not 0, it is considered a failure. The `postStart` Hook in [File 4] is an Exec Type Hook Handler.
* **HTTP** : Sends an HTTP Request to the Container. If the HTTP result is in the 200 range, it is considered a success, and if not, it is considered a failure. The `preStop` Hook in [File 4] is an HTTP Type Hook Handler.

## 2. References

* Kubernetes Pods : [https://kubernetes.io/docs/concepts/workloads/pods/pod-overview/](https://kubernetes.io/docs/concepts/workloads/pods/pod-overview/)
* Kubernetes Pod vs. Container: Multi-Container Communication : [https://www.mirantis.com/blog/multi-container-pods-and-container-communication-in-kubernetes/](https://www.mirantis.com/blog/multi-container-pods-and-container-communication-in-kubernetes/)
* Quality of Service Class (QoS) in Kubernetes : [https://medium.com/google-cloud/quality-of-service-class-qos-in-kubernetes-bb76a89eb2c6](https://medium.com/google-cloud/quality-of-service-class-qos-in-kubernetes-bb76a89eb2c6)

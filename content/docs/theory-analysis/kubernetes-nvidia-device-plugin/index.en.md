---
title: Kubernetes NVIDIA Device Plugin
---

## 1. Kubernetes NVIDIA Device Plugin

{{< figure caption="[Figure 1] NVIDIA Device Plugin Architecture" src="images/nvidia-device-plugin-architecture.png" width="900px" >}}

**Kubernetes NVIDIA Device Plugin** is a component for using NVIDIA GPUs in Kubernetes environments. To allocate GPUs to Pods, the NVIDIA Device Plugin must be installed in the Kubernetes cluster. [Figure 1] shows the Architecture of the NVIDIA Device Plugin. The NVIDIA Device Plugin runs on nodes where GPUs exist through a DaemonSet. The NVIDIA Device Plugin performs three roles: registering GPUs with Kubernetes, allocating GPUs to Pods, and checking GPU status.

By default, one GPU is allocated to and operates with only one container. In [Figure 1], there are 4 GPUs on one host, Container A in Pod A has one GPU allocated, Container B has two GPUs allocated, and Container C in Pod B has one GPU allocated. That is, you can see that each GPU is allocated to only one container.

Each container can identify the GPU information allocated to it through the `NVIDIA_VISIBLE_DEVICES` environment variable. When a single GPU is allocated to a container, it is set in the environment variable as `NVIDIA_VISIBLE_DEVICES=GPU-[UUID]`, and when multiple GPUs are allocated to a container, it is set as `NVIDIA_VISIBLE_DEVICES=GPU-[UUID1],GPU-[UUID2],...`. Since the `NVIDIA_VISIBLE_DEVICES` environment variable is used by CUDA libraries/tools, applications can use GPUs through CUDA libraries/tools without additional configuration.

To allocate GPUs to Pods, set the same number of GPUs in the Pod's Resource Request and Limit as the `nvidia.com/gpu` type. Integer values must be set, and decimal values are not allowed. You can see that the Resources of Container A, B, and C also have GPU counts set as the `nvidia.com/gpu` type.

When the NVIDIA Device Plugin starts, it checks whether the [NVIDIA Container Toolkit](https://github.com/NVIDIA/nvidia-container-toolkit) is installed on the node, and if it is not installed, the NVIDIA Device Plugin will not operate. The NVIDIA Container Toolkit provides a container runtime for allocating GPUs to containers. This means that not only the Device Plugin but also the NVIDIA Container Toolkit must be installed on GPU nodes.

### 1.1. GPU Node Registration Process

{{< figure caption="[Figure 2] GPU Node Registration Process" src="images/nvidia-gpu-registration-process.png" width="600px" >}}

The first role of the NVIDIA Device Plugin is to register GPU information and status that exists on the node to the Kubernetes Node's Allocatable/Capacity as the `nvidia.com/gpu` type. [Figure 2] shows the GPU node registration process.

1. The NVIDIA Device Plugin is deployed as a DaemonSet and starts operating on the node, running a gRPC server through a Unix Domain Socket (`/var/lib/kubelet/device-plugins/nvidia-gpu.sock`).
2. The NVIDIA Device Plugin begins to identify GPU information and status information on the node.
3. The NVIDIA Device Plugin sends a `Register()` gRPC request through kubelet's Device Plugin Unix Domain Socket (`/var/lib/kubelet/device-plugins/kubelet.sock`) to register itself with kubelet. In this process, it passes its Unix Domain Socket path (`/var/lib/kubelet/device-plugins/nvidia-gpu.sock`) to kubelet.
4. kubelet sends a `ListAndWatch()` gRPC request to the Unix Domain Socket path (`/var/lib/kubelet/device-plugins/nvidia-gpu.sock`) received through the NVIDIA Device Plugin's `Register()` gRPC request to request GPU information.
5. kubelet registers GPU information to the Node's Allocatable/Capacity as the `nvidia.com/gpu` type based on the GPU information received from the NVIDIA Device Plugin.

### 1.2. GPU Pod Allocation Process

{{< figure caption="[Figure 3] GPU Pod Allocation Process" src="images/nvidia-gpu-allocation-process.png" width="600px" >}}

The second role of the NVIDIA Device Plugin is to perform GPU scheduling, which determines which GPU to allocate to containers. [Figure 3] shows the GPU Pod allocation process.

1. The Kubernetes client creates a GPU Pod by specifying the number of GPUs as the `nvidia.com/gpu` type in the Pod's Resource.
2. The Kubernetes Scheduler selects a node that can provide the number of GPUs requested by the GPU Pod and places the Pod on that node.
3. The kubelet of the node selected by the Kubernetes Scheduler receives GPU count information specified in the GPU Pod.
4. kubelet sends an `Allocate()` gRPC request to the NVIDIA Device Plugin for the number of GPUs specified in the GPU Pod to allocate GPUs. At this time, the GPU allocation information that kubelet receives is provided as a GPU UUID array that will be set in the GPU Pod's `NVIDIA_VISIBLE_DEVICES` environment variable.
5. kubelet injects the allocated GPU information to Pods/containers through the NVIDIA Container Toolkit installed on the node.

### 1.3. GPU Health Check

The third role of the NVIDIA Device Plugin is to perform GPU Health Check, which checks GPU status. GPU Health Check is performed through NVIDIA's **NVML** (NVIDIA Management Library). NVIDIA's NVML provides various functions for checking GPU status and mainly monitors the following events to check GPU status:

* EventTypeXidCriticalError : XID (eXtended ID) Error Events. XID is a code that indicates GPU errors.
* EventTypeDoubleBitEccError : Double Bit ECC (Error Correcting Code) Error Events
* EventTypeSingleBitEccError : Single Bit ECC (Error Correcting Code) Error Events

If an abnormal GPU occurs, the Node's Allocatable GPU count decreases by the number of abnormal GPUs. For example, if there are 4 GPUs on a node and one GPU becomes abnormal, the Node's Allocatable GPU count becomes a maximum of 3.

### 1.4. GPU Sharing

By default, one GPU is allocated to and operates with only one container. However, by using GPU sharing techniques, one GPU can be allocated to multiple containers. NVIDIA GPU sharing techniques include Time-slicing, MPS, and MIG, and the NVIDIA Device Plugin provides all three techniques.

#### 1.4.1. with Time-slicing

{{< figure caption="[Figure 4] NVIDIA Device Plugin Architecture with Time-slicing" src="images/nvidia-device-plugin-architecture-timeslicing.png" width="900px" >}}

Time-slicing is a technique that allows multiple apps/containers to share and use GPUs by **time-sharing** the GPU's SM (Streaming Multiprocessor). [Figure 4] shows the structure of the Time-slicing technique. With the Time-slicing technique, **one container can be allocated and use multiple GPUs**. There are two GPUs, and you can see that Container A and Container B share and use the first GPU, and Container B and Container C share and use the second GPU.

To allocate GPUs to containers by sharing them, the NVIDIA Device Plugin multiplies the number of GPUs and passes them to kubelet. For example, if there are 4 GPUs, when passed to kubelet with a multiplier of 4, kubelet receives it as if there are 16 GPUs on the node. This means that one GPU can be allocated to a maximum of 4 containers.

```yaml {caption="[Config 1] nvidia-device-plugin-configs ConfigMap Example for Time-slicing", linenos=table}
apiVersion: v1
data:
...
  timeslicing-4: |-
    version: v1
    sharing:
      timeSlicing:
        renameByDefault: true
        resources:
        - name: nvidia.com/gpu
          replicas: 4
```

The multiplier can be configured in the `nvidia-device-plugin-configs` ConfigMap in the namespace where the NVIDIA Device Plugin exists. [Config 1] shows a configuration that applies the Time-slicing technique with a multiplier of 4. It uses the name `timeslicing-4`, and this name should be set in the Label of the node where Time-slicing is to be applied as `nvidia.com/device-plugin.config: timeslicing-4`. GPUs on nodes where the Time-slicing technique is applied use the `nvidia.com/gpu.shared` resource by default instead of the `nvidia.com/gpu` resource if `renameByDefault: true` is set as in [Config 1].

{{< figure caption="[Figure 5] NVIDIA Device Plugin GPU Scheduling" src="images/nvidia-device-plugin-gpu-scheduling.png" width="600px" >}}

The scheduling role that determines which GPU to allocate to containers is performed by the NVIDIA Device Plugin in the same way as in the GPU allocation process in [Figure 3]. [Figure 5] shows the GPU scheduling process of the NVIDIA Device Plugin in an environment where 4 GPUs exist and are configured with a multiplier of 2. The NVIDIA Device Plugin performs scheduling to preferentially allocate GPUs with fewer container allocations. When Container A requests 3 GPUs, since no Pods are allocated to all GPUs, the NVIDIA Device Plugin allocates any 3 GPUs to Container A. In [Figure 5], GPUs 0, 1, and 2 are allocated to Container A.

Subsequently, when Container B requests 3 GPUs, since only GPU 3 has no allocated Pod yet, the NVIDIA Device Plugin allocates GPU 3 to Container B. The NVIDIA Device Plugin then allocates two more GPUs to Container B from any available GPUs. In [Figure 5], GPUs 1 and 3 are allocated to Container B. Finally, when Container C requests 2 GPUs, the NVIDIA Device Plugin allocates the remaining GPUs 1 and 2 to Container C.

One notable point is that Container B requested 3 GPUs but was actually allocated only 2 GPUs due to GPU scheduling. That is, cases can occur where Pods do not receive the number of GPUs they requested. The Time-slicing technique does not provide functionality to limit GPU usage rates for each app/container. Therefore, if a specific app/container uses GPUs excessively, problems can occur where other apps/containers cannot properly use GPUs.

#### 1.4.2. with MPS (Multi-Process Service)

{{< figure caption="[Figure 6] NVIDIA Device Plugin Architecture with MPS" src="images/nvidia-device-plugin-architecture-mps.png" width="1100px" >}}

MPS (Multi-Process Service) is a technique that allows multiple apps/containers to share and use GPUs by **spatially dividing** the GPU's SM. [Figure 6] shows the structure of the MPS technique. There are two GPUs, and you can see that Container A and Container B share and use the first GPU, and Container C uses the second GPU. When using the MPS technique, **one container must be allocated and use exactly one GPU**. Also, the MPS technique and Time-slicing technique cannot be used simultaneously.

To use the MPS technique, an additional **MPS Control Daemon Pod** (DaemonSet) must be deployed. The MPS Control Daemon Pod runs **MPS Control** (`nvidia-cuda-mps-control`) and **MPS Server** (`nvidia-cuda-mps-server`) internally. MPS Control performs the role of managing and controlling the MPS Server, and MPS Server performs the role of controlling so that SMs can be used by spatially dividing them for each app/container.

```shell {caption="[Shell 1] MPS Control Files"}
$ ls -l /mps/
total 0
drwxr-xr-x. 3 root root 60 Mar  6 18:07 nvidia.com
drwxrwxrwt. 2 root root 40 Mar  6 18:07 shm

$ ls -l /mps/nvidia.com/gpu.shared/log/
total 4
-rw-r--r--. 1 root root 1256 Mar  6 18:17 control.log
-rw-r--r--. 1 root root    0 Mar  6 18:07 server.log

$ ls -l /mps/nvidia.com/gpu.shared/pipe/
total 4
srw-rw-rw-. 1 root root 0 Mar  6 18:07 control
-rw-rw-rw-. 1 root root 0 Mar  6 18:07 control_lock
srwxr-xr-x. 1 root root 0 Mar  6 18:07 control_privileged
prwxrwxrwx. 1 root root 0 Mar  6 18:17 log
-rw-rw-rw-. 1 root root 3 Mar  6 18:07 nvidia-cuda-mps-control.pid
```

Apps/containers must communicate with MPS Control to use MPS, and communication is performed through Unix Domain Sockets. Therefore, so that apps/containers can access the MPS Control's Unix Domain Socket, the NVIDIA Device Plugin connects the host's `/run/nvidia/mps` path to the `/mps/nvidia.com/gpu.shared` path of the MPS Control Daemon Pod and apps/containers through bind mount. Subsequently, MPS Control creates Unix Domain Sockets in the bind-mounted path and exposes them to apps/containers. [Shell 1] shows the list of Unix Domain Sockets and other files created by the MPS Control Daemon Pod and exposed to apps/containers.

When using MPS, not only the `NVIDIA_VISIBLE_DEVICES` environment variable but also the `CUDA_MPS_PIPE_DIRECTORY` environment variable is set for apps/containers. The `CUDA_MPS_PIPE_DIRECTORY` environment variable specifies the directory path containing the MPS Control's Unix Domain Socket. Therefore, the `CUDA_MPS_PIPE_DIRECTORY` environment variable is set to the `/mps/nvidia.com/gpu.shared/pipe` path. CUDA libraries in apps/containers operate by default to use MPS if the `CUDA_MPS_PIPE_DIRECTORY` environment variable exists.

```yaml {caption="[Config 2] nvidia-device-plugin-configs ConfigMap Example for MPS", linenos=table}
apiVersion: v1
data:
...
  mps-4: |-
    version: v1
    sharing:
      mps:
        renameByDefault: true
        resources:
        - name: nvidia.com/gpu
          replicas: 4
```

Like the Time-slicing technique, to allocate GPUs to containers by sharing them, the NVIDIA Device Plugin multiplies the number of GPUs and passes them to kubelet. [Config 2] shows a configuration that applies the MPS technique with a multiplier of 4. It uses the name `mps-4`, and this name should be set in the Label of the node where the MPS technique is to be applied as `nvidia.com/device-plugin.config: mps-4`. Also, to run the MPS Control Daemon Pod on the node, the `nvidia.com/mps.capable: "true"` Label must be set.

Like the Time-slicing technique, GPUs on nodes where the MPS technique is applied are registered on the node as the `nvidia.com/gpu.shared` resource name instead of the `nvidia.com/gpu` resource if `renameByDefault: true` is set as in [Config 2].

#### 1.4.3. with MIG (Multi-Instance GPU)

{{< figure caption="[Figure 7] NVIDIA Device Plugin Architecture with MIG" src="images/nvidia-device-plugin-architecture-mig.png" width="1100px" >}}

MIG (Multi-Instance GPU) is a hardware-level virtualization technique that completely isolates the GPU's SM and Memory to create vGPUs and provides them for use by CUDA apps. Since it is a hardware-level virtualization technique, it is only available on GPUs that support MIG, which are GPUs after Ampere Architecture (A100). [Figure 7] shows the structure of the MIG technique. The MIG technique virtualizes GPUs in two units: **GPU Instance**, which isolates Memory, and **Compute Instance**, which isolates SM.

GPU Instance and Compute Instance can be configured in a 1:1 or 1:N ratio. When configured in a 1:N ratio, Compute Instances share and use the GPU Instance's Memory. When Compute Instance and GPU Instance are configured in a 1:1 ratio, Compute Instances are created using profiles in the form `[x]g.[x]gb`. Here, `[x]g` means the number of SM slices allocated to the Compute Instance, and `[x]gb` means the size of Memory allocated to the Compute Instance. Also, when Compute Instance and GPU Instance are configured in a 1:N ratio, Compute Instances are created using profiles in the form `[x]c.[x]g.[x]gb`. Here, `[x]c` means the number of SM slices allocated to the Compute Instance.

In [Figure 7], you can see that the `4g.20gb` and `1g.5gb` GPU Instances are configured with Compute Instances in a 1:1 ratio, and the `2g.10gb` GPU Instance is configured with `1c.2g.10gb` Compute Instances in a 1:2 ratio. Containers can be allocated and use multiple Compute Instances simultaneously, but the allocated Compute Instances must operate on the same GPU Instance. In [Figure 7], Container B is allocated and uses two `1c.2g.10gb` Compute Instances, and both Compute Instances operate on one `2g.10gb` GPU Instance.

```yaml {caption="[Config 3] NVIDIA Device Plugin MIG_STRATEGY Environment Variable", linenos=table}
    containers:
      - env:
        - name: MIG_STRATEGY
          value: mixed
```

When the NVIDIA Device Plugin's `MIG_STRATEGY` environment variable is set to `mixed` as in [Config 3], the NVIDIA Device Plugin registers `nvidia.com/gpu-[GPU Instance Profile Name]` resources on the node. For example, `nvidia.com/gpu-4g.20gb` resource is registered for the `4g.20gb` GPU Instance, and `nvidia.com/gpu-2g.10gb` resource is registered for the `2g.10gb` GPU Instance. And the count of that resource is registered as the number of Compute Instances. Therefore, based on [Figure 7], there is only 1 `nvidia.com/gpu-4g.20gb` resource and 2 `nvidia.com/gpu-2g.10gb` resources are registered.

To use the MIG technique, apps/containers need not only `/dev/nvidia[x]` device files connected to GPUs but also `/dev/nvidia-caps/nvidia-cap[x]` device files connected to GPU Instances and Compute Instances. Therefore, the NVIDIA Device Plugin also creates `/dev/nvidia-caps/nvidia-cap[x]` device files for containers in apps/containers.

## 2. References

* NVIDIA MIG : [https://toss.tech/article/toss-securities-gpu-mig](https://toss.tech/article/toss-securities-gpu-mig)

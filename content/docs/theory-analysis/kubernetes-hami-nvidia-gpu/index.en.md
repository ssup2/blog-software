---
title: Kubernetes HAMi NVIDIA GPU
draft: true
---

## 1. Kubernetes HAMi NVIDIA GPU

**HAMi** supports sharing one NVIDIA GPU among multiple Pods. The Time-slicing technique of NVIDIA Device Plugin can also allocate one GPU to multiple Pods, but since all Pods use the GPU's Memory and compute resources together without limits, one Pod can occupy all Memory or monopolize computation. In contrast, HAMi uses a unit called **vGPU** that divides a GPU and allocates it to Pods, and divides the GPU in the following two ways depending on the Node's `operatingmode` setting.

* **HAMi-core Mode** : Shares one GPU through Time-slicing while dividing Memory size and compute ratio for each Pod. Each Pod is subject to the **Memory Size Limit**, which prevents allocating Memory beyond the allocated size, and the **SM Utilization Limit**, which keeps the utilization of SM (Streaming Multiprocessor), the compute unit of the GPU, at or below the allocated ratio. Since these limits are applied at the Software Level by intercepting CUDA API calls, Memory size and SM utilization can be specified as arbitrary values.
* **MIG Mode** : Partitions a MIG-capable GPU at the Hardware Level into MIG Instances with independent Memory and SMs and allocates them to Pods. It uses the **Dynamic MIG** feature that creates MIG Instances dynamically on request, and while the isolation is reliable, the GPU can only be divided in units of **MIG Profile**, the Memory and SM combinations NVIDIA defines for each GPU model.

{{< figure caption="[Figure 1] HAMi NVIDIA GPU Architecture" src="images/hami-nvidia-architecture.png" width="900px" >}}

[Figure 1] shows HAMi's NVIDIA GPU support configuration. Node A is in HAMi-core Mode, where Pod A and Pod B share one GPU by dividing Memory size and SM utilization, and Node B is in MIG Mode, where Pod C and Pod D are each allocated a separate MIG Instance. Neither Mode provides sharing based on NVIDIA MPS. NVIDIA GPU support is handled by the following three elements.

* **HAMi Scheduler** : Compares the NVIDIA GPU Resources in [Table 1] requested by a Pod with the GPU information recorded in each Node's `hami.io/node-nvidia-register` Annotation to select the Node and GPU on which to place the vGPU. On HAMi-core Mode Nodes, it selects a GPU with enough remaining Memory size and SM utilization, and on MIG Mode Nodes, it also selects the MIG Profile that covers the requested Memory size and the position at which to create it.
* **HAMi Device Plugin** : Runs on GPU Nodes through the `hami-device-plugin` DaemonSet, and in one Pod, the `device-plugin` Container, which registers vGPUs with kubelet, checks the Health state of GPUs, and allocates vGPUs, runs together with the `vgpu-monitor` Container, which exposes GPU and vGPU usage as Metrics. On MIG Mode Nodes, it also creates and reclaims MIG Instances.
* **HAMi-core** : The `libvgpu.so` Library injected into Containers in HAMi-core Mode, which intercepts CUDA Driver API calls to enforce the vGPU's Memory Size Limit and SM Utilization Limit.

{{< table caption="[Table 1] vGPU Resources provided by HAMi" >}}
| Resource | Purpose | HAMi-core Mode | MIG Mode |
|---|---|---|---|
| `nvidia.com/gpu` | Number of vGPUs to allocate to the Container | O | O |
| `nvidia.com/gpumem` | Memory size to allocate to each vGPU (in MiB) | O | O |
| `nvidia.com/gpumem-percentage` | Ratio of Memory to allocate to each vGPU relative to the physical GPU Memory (%). For example, specifying `50` allocates 8GiB on a 16GiB GPU and 40GiB on an 80GiB GPU, so the same ratio can be requested regardless of the GPU's Memory size | O | O |
| `nvidia.com/gpucores` | SM utilization each vGPU can use (%). For example, specifying `30` limits SM utilization to 30% or less on average, and specifying `100` allocates the entire physical GPU exclusively. If not specified, SM utilization is not limited | O | X |
| `nvidia.com/priority` | Priority between vGPU Workloads sharing the same GPU, where `0` is high, `1` is low, and the default is `1`. For example, while a Workload with `0` uses the GPU, kernel launches of a Workload with `1` are paused. It works only for Workloads to which the SM Utilization Limit applies by specifying `nvidia.com/gpucores` between 1 and 99 | O | X |
{{< /table >}}

[Table 1] shows the vGPU Resources provided by HAMi. Both Modes request vGPUs with the same Resources, but MIG Mode does not use `nvidia.com/gpucores` and `nvidia.com/priority` because it selects the MIG Profile by Memory size only and HAMi-core is not injected. HAMi Scheduler determines the number of vGPUs from `nvidia.com/gpu`, the Memory size of each vGPU from `nvidia.com/gpumem` or `nvidia.com/gpumem-percentage`, and the SM utilization from `nvidia.com/gpucores`, and compares them with the remaining capacity of each GPU. As with NVIDIA Device Plugin, the number of GPUs is requested with the `nvidia.com/gpu` Resource, but in HAMi it means the number of vGPUs, not physical GPUs.

```yaml {caption="[File 1] Example Pod requesting a vGPU", linenos=table}
apiVersion: v1
kind: Pod
metadata:
  name: vgpu-pod
spec:
  containers:
  - name: cuda
    image: nvidia/cuda:12.4.0-base-ubuntu22.04
    command: ["sleep", "infinity"]
    resources:
      limits:
        nvidia.com/gpu: 1
        nvidia.com/gpumem: 3000
        nvidia.com/gpucores: 30
```

[File 1] shows an example Pod requesting one vGPU with 3000MiB of Memory and 30% SM utilization. When one Container requests multiple vGPUs, each vGPU is placed on a different physical GPU, and the Memory size and SM utilization limits apply equally to each vGPU. If `nvidia.com/gpumem` is omitted, the request is treated as the entire Memory of the physical GPU, resulting in an exclusive allocation that does not share the GPU with other Pods.

### 1.1. Test Environment Setup

The Test is performed on the environment built in the [Kubernetes HAMi Installation and vLLM Model Serving](https://ssup2.github.io/blog-software/en/docs/record/kubernetes-hami-vllm-gpu-ubuntu-26.04/) post. A single Server at `192.168.1.32` has one Nvidia RTX 5060 Ti 16GB GPU, with Kubernetes v1.34.12 and HAMi 2.11.0 installed. All subsequent Shell/File blocks are measured results in this environment.

```yaml {caption="[File 2] hami-isolation-test.yaml", linenos=table}
apiVersion: v1
kind: Pod
metadata:
  name: hami-isolation-test
spec:
  containers:
  - name: cuda
    image: vllm/vllm-openai:latest
    command: ["sleep", "infinity"]
    env:
    - name: GPU_CORE_UTILIZATION_POLICY
      value: force
    resources:
      limits:
        nvidia.com/gpu: 1
        nvidia.com/gpumem: 2000
        nvidia.com/gpucores: 30
```

```shell {caption="[Shell 1] Creating the Test Pod and checking vGPU environment variables"}
$ kubectl apply -f hami-isolation-test.yaml
pod/hami-isolation-test created

$ kubectl exec hami-isolation-test -- env | grep -E 'CUDA_DEVICE|GPU_CORE' | sort
CUDA_DEVICE_MEMORY_LIMIT_0=2000m
CUDA_DEVICE_MEMORY_SHARED_CACHE=/usr/local/vgpu/usage.cache
CUDA_DEVICE_SM_LIMIT=30
GPU_CORE_UTILIZATION_POLICY=force

$ kubectl exec hami-isolation-test -- cat /etc/ld.so.preload
/usr/local/vgpu/libvgpu.so
```

[File 2] is an example Pod requesting one vGPU limited to 2000MiB of Memory and 30% SM utilization. `GPU_CORE_UTILIZATION_POLICY=force` enforces the SM Utilization Limit even when no other Container uses the same GPU, and the official vLLM image containing CUDA 13.0 PyTorch is reused as the image. Other Workloads using the Test Node's GPU were stopped during the measurement.

[Shell 1] shows the environment variables and Preload setting inside the Container after the Pod is created. It can be seen that HAMi Device Plugin injected `CUDA_DEVICE_MEMORY_LIMIT_0` and `CUDA_DEVICE_SM_LIMIT` according to the `nvidia.com/gpumem` and `nvidia.com/gpucores` requests, and that `libvgpu.so` is registered in the `/etc/ld.so.preload` file.

```yaml {caption="[File 3] HAMi Annotations recorded on the Test Pod", linenos=table}
apiVersion: v1
kind: Pod
metadata:
  name: hami-isolation-test
  annotations:
    hami.io/vgpu-devices-to-allocate: ;;
    hami.io/vgpu-devices-allocated: GPU-034026c4-...,NVIDIA,2000,30:;
    hami.io/vgpu-node: gpu
    hami.io/bind-phase: success
    hami.io/bind-time: "1795279541"
    hami.io/vgpu-time: "1795279541"
```

[File 3] shows the HAMi Annotations recorded on the Test Pod. NVIDIA GPU uses `vgpu`, the name of the initial implementation, in the Accelerator part of Annotation names, so names such as `hami.io/vgpu-devices-allocated` are used, and `NVIDIA` is recorded in the Type that indicates the kind of Accelerator. Since the allocation has completed, only the Container delimiters remain in `hami.io/vgpu-devices-to-allocate`, and `hami.io/bind-phase` is `success`. HAMi Device Plugin reads these Annotations at `Allocate()` time to determine the GPU to allocate and the limit values, and the result is injected as the environment variables in [Shell 1].

### 1.2. vGPU Settings

{{< table caption="[Table 2] Major vGPU settings" >}}
| Setting | Purpose (Default) |
|---|---|
| `deviceSplitCount` | Maximum number of vGPUs that can be allocated on one physical GPU (`10`) |
| `deviceMemoryScaling` | Ratio of allocatable Memory to physical Memory size (`1`) |
| `deviceCoreScaling` | Ratio of allocatable SM utilization to physical SMs (`1`) |
| `operatingmode` | vGPU operating Mode of the Node. One of `hami-core`, `mig`, `remote` (`hami-core`) |
{{< /table >}}

[Table 2] shows the major vGPU settings of NVIDIA GPU. Cluster-wide settings are defined in the `nvidia` Section of the `hami-scheduler-device` ConfigMap, and per-Node overrides are defined with the Node name in the `nodeconfig` list of the `hami-device-plugin` ConfigMap. For NVIDIA GPU, the number of physical GPUs × `deviceSplitCount` of `nvidia.com/gpu` is registered in the Node's Allocatable. `operatingmode` decides whether the Node divides GPUs in HAMi-core Mode or MIG Mode, and `remote` is a Mode that uses GPUs of other Servers over the network, which this post does not cover. Since `operatingmode` is specified per Node in `nodeconfig` by Node name or `nodelabelselector`, different Nodes in one Cluster can use different Modes, but different Modes cannot be specified for GPUs within one Node. Since HAMi Device Plugin reads the settings and Node Labels when it starts, the HAMi Device Plugin on the Node must be restarted after changing them.

Setting `deviceMemoryScaling` above 1 enables over-allocation, allocating more Memory than the physical Memory. The per-vGPU Memory limit is maintained, but it is an experimental feature that can cause physical GPU OOM if all vGPUs use Memory up to their limits. Setting `deviceCoreScaling` above 1 also allows allocating more SM utilization than the physical SMs. The two Scaling settings do not apply to MIG Mode, and in MIG Mode, the number of MIG Instances a GPU can hold limits the number of Containers that can share it instead of `deviceSplitCount`.

{{< table caption="[Table 3] vGPU settings that adjust Pod requests" >}}
| Setting | Applied At | Behavior (Default) |
|---|---|---|
| `defaultGPUNum` | Mutating Webhook | If a Container requests only GPU Memory or SM utilization without requesting the number of GPUs, fills `nvidia.com/gpu` with this value (`1`) |
| `defaultMemory` | HAMi Scheduler | Memory size (MiB) applied when a Container does not request GPU Memory. `0` treats the request as the entire GPU Memory (`0`) |
| `defaultCores` | HAMi Scheduler | SM utilization applied when a Container does not request SM utilization (`0`) |
| `overwriteEnv` | Mutating Webhook | If `true`, adds the `NVIDIA_VISIBLE_DEVICES=none` environment variable to Containers that do not request GPUs so that GPUs are not visible (`false`) |
| `runtimeClassName` | Mutating Webhook | If no RuntimeClass is specified for a Pod requesting GPUs, sets this value in the Pod's `spec.runtimeClassName` (`""`) |
{{< /table >}}

[Table 3] shows the vGPU settings that adjust Pod requests. The settings in [Table 3] are unrelated to the `Allocate()` response of HAMi Device Plugin and are applied when the Mutating Webhook changes the Pod spec at Pod creation or when HAMi Scheduler calculates the requested amount during Scheduling. If `runtimeClassName` is empty, Kubernetes' Default RuntimeClass is used.

```yaml {caption="[File 4] Node Annotation reflecting the vGPU settings", linenos=table}
apiVersion: v1
kind: Node
metadata:
  name: gpu
  annotations:
    hami.io/node-nvidia-register: '[{"id":"GPU-034026c4-...","count":10,"devmem":16311,"devcore":100,"type":"NVIDIA GeForce RTX 5060 Ti","mode":"hami-core","health":true}]'
```

[File 4] shows the `hami.io/node-nvidia-register` Annotation that HAMi Device Plugin periodically records on GPU Nodes, and each GPU entry records values reflecting the settings in [Table 2] as shown in [Table 4].

{{< table caption="[Table 4] Node Register Annotation values for NVIDIA GPU" >}}
| Item | Value recorded for NVIDIA GPU |
|---|---|
| `id` | GPU UUID queried through NVML |
| `index` | GPU number within the Node |
| `count` | Value of `deviceSplitCount` |
| `devmem` | Physical Memory size (MiB) × `deviceMemoryScaling` |
| `devcore` | `100` × `deviceCoreScaling` (SM utilization %, `100` in MIG Mode) |
| `type` | GPU model name queried through NVML (normalized with the `NVIDIA` prefix) |
| `numa` | NUMA Node of the GPU queried through sysfs |
| `mode` | Value of `operatingmode` (`hami-core`, `mig`, `remote`) |
| `health` | GPU Health Check result |
{{< /table >}}

As with the first GPU in [File 4], `index` and `numa` are omitted from the JSON when they are `0`. Since `devmem` is the physical Memory size reported by the Driver, a value slightly smaller than the GPU's labeled capacity is recorded.

### 1.3. HAMi-core Mode

HAMi-core Mode operates on Nodes whose `operatingmode` is `hami-core`, where HAMi Device Plugin injects HAMi-core into Containers and HAMi-core enforces the Memory Size Limit and the SM Utilization Limit.

#### 1.3.1. HAMi-core Injection

A Container needs three kinds of Libraries, and each kind is delivered differently.

* **CUDA SDK** (`libcudart.so`, etc.) : Must be included in the Container Image in advance and is not delivered separately.
* **NVIDIA Driver Library** (`libcuda.so`, `libnvidia-ml.so`, etc.) : **NVIDIA Container Toolkit** mounts the Host's Libraries into the Container. This is the same as when using NVIDIA Device Plugin.
* **HAMi-core** (`libvgpu.so`, etc.) : When HAMi Device Plugin specifies the paths to mount, the Container Runtime mounts them. This method exists only in HAMi.

For the NVIDIA Driver Library, with the default setting (`deviceListStrategy: envvar`), HAMi Device Plugin only indicates the GPUs to allocate through the `NVIDIA_VISIBLE_DEVICES` environment variable in the `Allocate()` response. When the Container is created, the NVIDIA Container Toolkit Runtime reads this environment variable, generates a CDI specification of the required Libraries and Devices on the fly (`jit-cdi` Mode), and applies it to the Container configuration so that the mounts take place.

Since HAMi-core is a file that NVIDIA Container Toolkit does not know about, HAMi Device Plugin handles it separately. Since the mount source must exist on the Host, HAMi Device Plugin copies `libvgpu.so` in the Image to the Host's `/usr/local/vgpu` (based on the Helm `global.gpuHookPath` default) with `vgpu-init.sh` in the `postStart` Hook when it starts, and creates `ld.so.preload`. Later, when a Pod is created, HAMi Device Plugin specifies the following mount targets in the `Allocate()` response.

* `/usr/local/vgpu/libvgpu.so` : The path where the Host's HAMi-core Library is mounted read-only.
* `/etc/ld.so.preload` : The path where the Host's `/usr/local/vgpu/ld.so.preload`, which specifies loading `libvgpu.so` first, is mounted read-only.
* `/usr/local/vgpu` : The path where HAMi-core's shared Cache file is located. The Host's `/usr/local/vgpu/containers/<Pod UID>_<Container name>` Directory is created for each Container and mounted.
* `/tmp/vgpulock` : The path of the Lock file used by HAMi-core. The same Host path is mounted so that the Containers on the Node share it.

HAMi-core is injected through the `/etc/ld.so.preload` file, not the `LD_PRELOAD` environment variable. The `LD_PRELOAD` environment variable applies only to Processes that inherit it, so isolation breaks if the App clears environment variables when creating child Processes, whereas the `/etc/ld.so.preload` file is always read by the dynamic linker at the start of every Process, so it applies to all Processes in the Container regardless of environment variables.

```yaml {caption="[File 5] hami-wholegpu-test.yaml", linenos=table}
apiVersion: v1
kind: Pod
metadata:
  name: hami-wholegpu-test
spec:
  containers:
  - name: cuda
    image: vllm/vllm-openai:latest
    command: ["sleep", "infinity"]
    resources:
      limits:
        nvidia.com/gpu: 1
```

```shell {caption="[Shell 2] Checking that HAMi-core is disabled for a Container allocated an entire GPU"}
$ kubectl apply -f hami-wholegpu-test.yaml
pod/hami-wholegpu-test created

$ kubectl get pod hami-wholegpu-test -o jsonpath='{.metadata.annotations.hami\.io/vgpu-devices-allocated}'
GPU-034026c4-1e0d-1fa0-1b54-9e6030439007,NVIDIA,16311,100:;

$ kubectl exec hami-wholegpu-test -- env | grep -E 'CUDA_DEVICE|CUDA_DISABLE|GPU_CORE' | sort
CUDA_DEVICE_MEMORY_LIMIT_0=16311m
CUDA_DEVICE_MEMORY_SHARED_CACHE=/usr/local/vgpu/usage.cache
CUDA_DEVICE_SM_LIMIT=100
CUDA_DISABLE_CONTROL=true

$ kubectl exec hami-wholegpu-test -- sh -c 'cat /etc/ld.so.preload 2>&1; ls /usr/local/vgpu 2>&1'
cat: /etc/ld.so.preload: No such file or directory
libvgpu.so
```

However, HAMi-core is not injected into Containers that are allocated whole GPUs. If a Container requests the entire Memory of all allocated GPUs and requests no SM utilization or `100`, HAMi Device Plugin injects the `CUDA_DISABLE_CONTROL=true` environment variable instead of mounting `/etc/ld.so.preload`, turning off HAMi-core's limits. This behavior follows the Helm `devicePlugin.monitor.disableHAMiCoreForWholeGPU` setting whose default is `true`, and it applies only on Nodes where both `deviceMemoryScaling` and `deviceCoreScaling` are 1. Pods that omit `nvidia.com/gpumem` are also treated as requesting the entire GPU Memory and are subject to this behavior, and in this case `vgpu-monitor` exposes the usage of the entire GPU queried through NVML as the Container's Metrics.

[File 5] is a Pod requesting only `nvidia.com/gpu`, and as shown in [Shell 2], the entire GPU Memory of `16311` MiB and SM utilization `100` are allocated. Since `CUDA_DISABLE_CONTROL=true` is injected and `/etc/ld.so.preload` is not mounted, the `libvgpu.so` file exists in the Container but is not loaded.

#### 1.3.2. Memory, SM Utilization Limits

{{< figure caption="[Figure 2] HAMi-core Isolation" src="images/hami-core-isolation.png" width="900px" >}}

The vGPU's Memory Size Limit and SM Utilization Limit are enforced by HAMi-core (`libvgpu.so`) inside the Container. [Figure 2] shows how HAMi-core enforces the limits. `libvgpu.so` is a Library that defines functions with the same names as the CUDA Driver API, and since the dynamic linker binds a call to the function of the Library loaded first when a function with the same name exists in multiple Libraries, the functions of `libvgpu.so`, which is registered in `/etc/ld.so.preload` and loaded before the CUDA Library, receive the App's CUDA Driver API calls instead. `libvgpu.so` checks whether a received call satisfies the limit conditions and then passes it to the function of the actual CUDA Library, so it can intervene in every call without modifying the App or the CUDA Library.

The Memory Size Limit is enforced by intercepting Memory allocation APIs. `libvgpu.so` tracks the Container's GPU Memory usage whenever a Memory allocation function such as `cuMemAlloc()` is called, and returns CUDA's OOM (Out of Memory) Error when the usage exceeds the limit set in the `CUDA_DEVICE_MEMORY_LIMIT` environment variable. Also, Memory query functions such as `cuMemGetInfo()` are intercepted to return the vGPU's Memory size instead of the physical GPU's Memory size, so the App and the `nvidia-smi` command recognize the vGPU's Memory size as the total Memory size.

```shell {caption="[Shell 3] Checking the vGPU Memory limit"}
$ kubectl exec hami-isolation-test -- nvidia-smi --query-gpu=memory.total --format=csv
memory.total [MiB]
2000 MiB

$ kubectl exec hami-isolation-test -- python3 -c '
import torch
x = torch.empty(1_200_000_000, dtype=torch.uint8, device="cuda")
print(f"alloc OK, used {torch.cuda.memory_allocated()/2**20:.0f} MiB")'
[HAMI-core Msg(69:124674156162752:multiprocess_memory_limit.c:855)]: Cleanup on exit for PID 69
[HAMI-core Msg(69:124674156162752:multiprocess_memory_limit.c:891)]: Exit cleanup complete for PID 69
alloc OK, used 1144 MiB

$ kubectl exec hami-isolation-test -- python3 -c '
import torch
try:
    x = torch.empty(2_500_000_000, dtype=torch.uint8, device="cuda")
except RuntimeError as e:
    print("OOM:", str(e).split(".")[0])'
[HAMI-core ERROR (pid:105 thread=128301757093696 allocator.c:40)]: Device 0 OOM 2636120064 / 2097152000
[W1121 16:50:16.966628263 CUDACachingAllocator.cpp:3934] memory allocation failed with OOM on device 0 while trying to allocate 2501902336 bytes (free: 1962934272, total: 2097152000).
[HAMI-core ERROR (pid:105 thread=128301757093696 allocator.c:40)]: Device 0 OOM 2636120064 / 2097152000
[W1121 16:50:16.970781125 CUDACachingAllocator.cpp:3934] memory allocation failed with OOM on device 0 while trying to allocate 2501902336 bytes (free: 1962934272, total: 2097152000).
OOM: CUDA out of memory
```

[Shell 3] shows the Memory limit being applied. `nvidia-smi` reports the total Memory as `2000 MiB` inside the Pod, showing that HAMi-core replaced the `cuMemGetInfo()` result with the vGPU size. The 1200MB allocation succeeds because it is within the limit, but the 2500MB allocation is rejected with HAMi-core's `Device 0 OOM 2636120064 / 2097152000` Log, and PyTorch returns `CUDA out of memory`. The `2097152000` Bytes in the log is `2000 MiB` converted to Bytes.

The SM Utilization Limit is enforced by intercepting kernel launch APIs. `libvgpu.so` manages whether kernels can be launched based on Tokens while periodically measuring the GPU's utilization, and when a kernel launch function such as `cuLaunchKernel()` is called and Tokens are insufficient, it delays the kernel launch to keep the vGPU's SM utilization at or below the limit set in the `CUDA_DEVICE_SM_LIMIT` environment variable. The limiting behavior can be changed with the `GPU_CORE_UTILIZATION_POLICY` environment variable as follows.

* `default` : The default, which allows usage beyond the limit when no other Container uses the same GPU. Whether the limit applies is decided periodically by `vgpu-monitor`.
* `force` : Always enforces the limit regardless of whether other Containers use the same GPU.
* `disable` : Does not enforce the SM Utilization Limit.

```shell {caption="[Shell 4] Checking the SM utilization limit"}
$ kubectl exec hami-isolation-test -- python3 -c '
import torch, time
a = torch.randn(2048, 2048, device="cuda"); b = torch.randn(2048, 2048, device="cuda")
end = time.time() + 90
while time.time() < end:
    c = a @ b; torch.cuda.synchronize()' &

$ for i in 1 2 3; do
    curl -s 'http://192.168.1.32:30900/api/v1/query?query=hami_container_device_utilization_ratio' \
      | python3 -c 'import json,sys;r=json.load(sys.stdin)["data"]["result"];print([(e["metric"]["pod"], e["value"][1]) for e in r])'
    sleep 5
  done
[('hami-isolation-test', '32')]
[('hami-isolation-test', '32')]
[('hami-isolation-test', '32')]

$ nvidia-smi dmon -s u -c 10 -o T | awk 'NR>2 {print $1, "sm="$3"%"}'
01:51:12 sm=38%
01:51:13 sm=37%
01:51:14 sm=26%
01:51:15 sm=12%
01:51:16 sm=34%
01:51:17 sm=39%
01:51:18 sm=27%
01:51:19 sm=19%
01:51:20 sm=37%
01:51:21 sm=38%
```

[Shell 4] shows the SM utilization sampled from two Sources while matmul runs continuously in the Pod. The `hami_container_device_utilization_ratio` Metric exposed by `vgpu-monitor` converges to the requested 30% limit at `32`, and the Host's `nvidia-smi dmon` also stays near the limit, moving between 12% and 39% in 1-second samples. Since HAMi-core adjusts utilization by delaying kernel launches, instantaneous samples fluctuate above and below the limit, but the average matches the limit.

HAMi-core does not divide GPU time by itself. Computations of Containers sharing one GPU are executed in turn through the **Time-slicing** of the NVIDIA Driver and GPU, and `libvgpu.so` only adjusts utilization by delaying kernel launches in front of it. In contrast, Memory is not divided by time; the Data of all Containers resides in GPU Memory at the same time, and `libvgpu.so` only limits the allocation amount.

Sharing based on **NVIDIA MPS** (Multi-Process Service), which runs kernels of multiple Processes concurrently, is not supported. Unlike NVIDIA Device Plugin, HAMi Device Plugin does not implement MPS-related behavior, and MPS is not among the behaviors that can be selected with `operatingmode`.

The usage information of App Containers allocated vGPUs is recorded by HAMi-core in the **Shared Memory Region**. Since the Memory limit applies per Container rather than per Process, all CUDA Processes in a Container must share one usage aggregate, and HAMi-core forms Shared Memory between Processes by mmapping the Cache file pointed to by the `CUDA_DEVICE_MEMORY_SHARED_CACHE` environment variable in [Shell 1]. The file stores the Memory and SM limit values and an array of Process Slots, and after the first Process initializes the limit values, each Process records its per-Device Memory usage and SM utilization in its own Slot.

Since the Cache file is created in the path that HAMi Device Plugin mounts into the App Container as a hostPath Volume, the same file can also be read outside the Container, and `vgpu-monitor` periodically reads the Cache files of the vGPU Containers on the Node and exposes per-Container Memory usage and SM utilization as Metrics. Since HAMi's limits are Software Level limits through CUDA API interception, they can be used on all NVIDIA GPUs without separate Hardware support, but the isolation level is lower than Hardware Level isolation such as MIG.

#### 1.3.3. Priority

In HAMi-core Mode, **Priority** can be specified between Containers sharing the same GPU so that kernel launches of lower-priority Containers are paused while a higher-priority Container uses the GPU. Priority is specified as a Resource in the Container's `resources.limits`, such as `nvidia.com/priority: 0`, and a smaller value means a higher priority. The Mutating Webhook converts this value into the Container's `CUDA_TASK_PRIORITY` environment variable, and HAMi-core records this value in the Shared Memory Region when it starts. Containers without a specified priority are recorded as `1`. Priority is applied through the following process.

1. HAMi-core leaves a mark in the Shared Memory Region indicating a recent kernel launch whenever a kernel launch function is called.
2. Every 5 seconds, `vgpu-monitor` reads the Shared Memory Regions of all vGPU Containers on the Node and counts, per GPU and per priority, the Containers that recently launched kernels.
3. If a higher-priority Container is launching kernels on the same GPU, `vgpu-monitor` records the Blocking state in the Shared Memory Region of the lower-priority Containers.
4. When a kernel launch function is called, HAMi-core of a Container with the Blocking state waits in 1-second intervals until the Blocking state is released, and `vgpu-monitor` releases the Blocking state once the higher-priority Container no longer launches kernels.

In the same cycle, `vgpu-monitor` also decides whether the SM Utilization Limit applies to each Container. If a higher-priority Container or another Container with the same priority is launching kernels on the same GPU, it applies the SM Utilization Limit, and otherwise it releases the limit so that a Container using the GPU alone can use it beyond the limit. This is the behavior when `GPU_CORE_UTILIZATION_POLICY` is `default`, and `force` and `disable` respectively always apply or never apply the limit regardless of this decision.

Priority works only for Containers whose SM Utilization Limit is between `1` and `99`. Since HAMi-core skips priority handling at kernel launch for Containers that do not specify `nvidia.com/gpucores` or specify it as `100`, such Containers do not pause kernel launches of other Containers and are not paused themselves.

```yaml {caption="[File 6] hami-priority-high.yaml", linenos=table}
apiVersion: v1
kind: Pod
metadata:
  name: hami-priority-high
spec:
  containers:
  - name: cuda
    image: vllm/vllm-openai:latest
    command: ["sleep", "infinity"]
    resources:
      limits:
        nvidia.com/gpu: 1
        nvidia.com/gpumem: 2000
        nvidia.com/gpucores: 50
        nvidia.com/priority: 0
  restartPolicy: Never
```

```python {caption="[File 7] matmul-rate.py", linenos=table}
import sys, time, torch
dur = float(sys.argv[1])
a = torch.randn(2048, 2048, device="cuda"); b = torch.randn(2048, 2048, device="cuda")
start = time.time(); last = start; n = 0
while time.time() - start < dur:
    c = a @ b; torch.cuda.synchronize(); n += 1
    now = time.time()
    if now - last >= 5:
        print(f"{time.strftime('%H:%M:%S')} {n / (now - last):.0f} matmul/s", flush=True)
        last = now; n = 0
```

```shell {caption="[Shell 5] Checking kernel launch Blocking by priority"}
$ kubectl apply -f hami-priority-high.yaml -f hami-priority-low.yaml
pod/hami-priority-high created
pod/hami-priority-low created

$ for p in high low; do echo "$p: $(kubectl exec hami-priority-$p -- env | grep -E 'CUDA_TASK_PRIORITY|CUDA_DEVICE_SM_LIMIT' | sort | tr '\n' ' ')"; done
high: CUDA_DEVICE_SM_LIMIT=50 CUDA_TASK_PRIORITY=0
low: CUDA_DEVICE_SM_LIMIT=50 CUDA_TASK_PRIORITY=1

$ for p in high low; do kubectl cp matmul-rate.py hami-priority-$p:/tmp/matmul-rate.py; done

$ kubectl exec hami-priority-low -- python3 /tmp/matmul-rate.py 95 | sed 's/^/low  /' &
$ sleep 30; kubectl exec hami-priority-high -- python3 /tmp/matmul-rate.py 30 | sed 's/^/high /'
low  11:19:58 882 matmul/s
low  11:20:03 889 matmul/s
low  11:20:08 886 matmul/s
low  11:20:13 883 matmul/s
low  11:20:18 881 matmul/s
high 11:20:28 869 matmul/s
high 11:20:33 878 matmul/s
high 11:20:38 877 matmul/s
high 11:20:43 877 matmul/s
high 11:20:48 874 matmul/s
low  11:21:03 85 matmul/s
low  11:21:08 881 matmul/s
low  11:21:13 878 matmul/s
low  11:21:18 876 matmul/s
low  11:21:23 876 matmul/s
```

[File 6] is a Pod requesting 50% SM utilization with priority `0`, and the `hami-priority-low` Pod differs only in its name and `nvidia.com/priority: 1`. [File 7] is a Script that repeats 2048 × 2048 matrix multiplication and prints the number of executions per second every 5 seconds. [Shell 5] is the result of creating both Pods on the same GPU and running the Script on the high-priority Pod for 30 seconds while the low-priority Pod is running the Script, and the outputs of the two commands are sorted in time order. Other Workloads using the GPU were stopped during the Test.

In [Shell 5], it can be seen that each Pod's priority is injected into the `CUDA_TASK_PRIORITY` environment variable. The low-priority Pod runs about 880 times per second while using the GPU alone even though its SM Utilization Limit is 50%, because there is no other Container using the same GPU and the limit is released according to the `default` policy. When the high-priority Pod starts running, the low-priority Pod is Blocked and prints nothing for about 45 seconds, and during this time the high-priority Pod runs about 875 times per second without limits because there is no other Container with the same priority. The `85 matmul/s` at 11:21:03 is the average over the roughly 45-second interval including before and after Blocking, and after the high-priority Pod terminates, the Blocking is released in the next cycle of `vgpu-monitor` and the low-priority Pod runs about 880 times per second again.

### 1.4. MIG Mode

MIG Mode operates on Nodes whose `operatingmode` is `mig` and uses the Dynamic MIG feature, which dynamically creates and allocates MIG Instances according to vGPU requests. Unlike HAMi-core's Software Level limits, MIG isolates the GPU's SMs and Memory at the Hardware Level and thus provides a higher isolation level, and Pods request MIG Instances with the same vGPU Resources as in HAMi-core Mode.

Dynamic MIG was introduced in v2.5.0. Initially, it switched the MIG configuration of the entire GPU in units of Geometries (Profile combinations) defined in the `knownMigGeometries` setting, but since Flexible MIG in v2.10.0, it has been restructured into a per-Profile reservation method, so MIG Instances are created and reclaimed per Workload without cordoning the Node. However, since HAMi must be solely responsible for creating and removing MIG Instances, GPU Operator's MIG Manager or the `mig-parted` tool cannot be operated together with HAMi.

Since NVIDIA Device Plugin looks up already created MIG Instances when it starts and registers them with kubelet as Devices, the Device Plugin must be restarted after the MIG configuration changes for the changed Device list to be reflected. In contrast, HAMi Device Plugin registers vGPUs based on the parent GPU with kubelet even in MIG Mode, and creates MIG Instances while handling `Allocate()` and passes their UUIDs to the Container, so the Device Plugin does not need to be restarted when MIG Instances are created and reclaimed. However, if the GPU's MIG Mode is off, HAMi Device Plugin turns MIG Mode on by itself at the first allocation, and since Ampere GPUs such as A100 may require a GPU Reset or VM reboot to change MIG Mode, the allocation fails in that case. Therefore, on Ampere GPUs, it is safer to turn on MIG Mode in advance with the `nvidia-smi -mig 1` command and complete the GPU Reset.

The behavior of MIG Mode is verified in a separate environment from 1.1. An EKS p4d.24xlarge Node with 8 A100-SXM4-40GB GPUs is used, and the Node Group the Node belongs to has the `group=gpu-a100-hami` Label and Taint, with `operatingmode` set to `mig` by matching this Label in `nodeconfig`. The default `migProfileAllowlist` for the A100 40GB GPU defines the `1g.5gb`, `2g.10gb`, `3g.20gb`, `4g.20gb`, and `7g.40gb` Profiles.

The Node is provisioned by Karpenter, and Karpenter does not know HAMi's extended Resources such as `nvidia.com/gpumem`, so Node creation does not start only with Pods requesting them (`no instance type has enough resources`). Therefore the Node was first created with a placeholder Pod that has only the nodeSelector without GPU Resources.

```shell {caption="[Shell 6] MIG Instance allocation failing on a Node with MIG Mode disabled"}
$ kubectl describe pod mig-2g-a
...
  Normal   Scheduled                 3m15s  hami-scheduler  Successfully assigned default/mig-2g-a to ip-10-210-126-83.ap-northeast-2.compute.internal
  Warning  UnexpectedAdmissionError  3m15s  kubelet         Allocate failed due to rpc error: code = Unknown desc = resolve allocated NVIDIA devices: gpu 7 MIG enable is pending (current=0 pending=1): MIG mode change requires a GPU reset or VM reboot. Manual operator action may be needed: try nvidia-smi --gpu-reset, or reboot the VM if the hypervisor does not allow GPU reset. ...

$ kubectl logs -n addon-hami ds/hami-device-plugin -c device-plugin | grep 'MIG enable is pending' | tail -1
I1123 15:06:11.062891   39735 server.go:918] "periodic MIG reconciliation skipped" err="restore MIG instances during initialization: gpu 0 MIG enable is pending (current=0 pending=1): MIG mode change requires a GPU reset or VM reboot. ..."
```

[Shell 6] shows the result of applying a Pod requesting a MIG Instance on a Node booted with MIG Mode disabled. Binding by HAMi Scheduler succeeds, but the Pod is rejected at kubelet's `Allocate()` as HAMi Device Plugin fails while enabling MIG Mode. HAMi Device Plugin sets MIG Mode to the pending state with NVML's `SetMigMode` but cannot perform the GPU Reset itself, because it and `vgpu-monitor` hold NVML Handles, and on NVSwitch systems Fabric Manager must be stopped and all GPUs must be reset together.

In this Test, the issue was resolved by adding a Script to the Node Group's userData that enables MIG Mode of all GPUs with `nvidia-smi -mig 1` at boot time when no Process is using the GPUs. Since the Hopper generation, switching MIG Mode does not require a GPU Reset, so this pre-activation is needed only for the Ampere generation.

#### 1.4.1. MIG Profile Selection

```yaml {caption="[File 8] Example Pod specifying MIG Mode", linenos=table}
apiVersion: v1
kind: Pod
metadata:
  name: mig-pod
  annotations:
    nvidia.com/vgpu-mode: "mig"
spec:
  containers:
  - name: cuda
    image: nvidia/cuda:12.4.0-base-ubuntu22.04
    command: ["sleep", "infinity"]
    resources:
      limits:
        nvidia.com/gpu: 1
        nvidia.com/gpumem: 8000
```

[File 8] shows an example Pod requesting 8000MiB of Memory as a MIG Instance. Among the MIG Profiles defined per GPU model in the `migProfileAllowlist` setting, HAMi Scheduler selects the smallest Profile that covers the Memory size the Pod requested with `nvidia.com/gpumem` or `nvidia.com/gpumem-percentage`. For example, the `1g.10gb`, `2g.20gb`, `3g.40gb`, `4g.40gb`, and `7g.79gb` Profiles are defined for the A100 80GB GPU, so `1g.10gb` is selected for the Pod in [File 8].

Since MIG Profiles are selected by Memory size only, the `nvidia.com/gpucores` request is not used, and the Memory size and Core value of the selected Profile are recorded in the allocation history instead of the requested values. To prefer a specific Profile, specify a Profile name defined in `migProfileAllowlist` or a Slice prefix such as `4g` in the Pod's `nvidia.com/mig-profile-preference` Annotation, and if the specified Profile covers the Memory size, it is selected before smaller Profiles. The `nvidia.com/vgpu-mode` Annotation fixes the Mode in which the vGPU is allocated, and if omitted, HAMi Scheduler treats `mig` Nodes and `hami-core` Nodes as one vGPU Pool and freely selects a Node that satisfies the conditions.

MIG Instances are created on the GPU's Memory Slices, and the start positions at which each MIG Profile can be created are fixed. For example, the A100 40GB GPU has 8 Slices, and `1g.5gb` can start from 0 to 6, `2g.10gb` at 0, 2, 4, `3g.20gb` at 0, 4, and `4g.20gb` and `7g.40gb` only at 0. Therefore, the positions of MIG Instances created first limit the MIG Profiles that can be created afterward.

From the position list that HAMi Device Plugin queries through NVML and registers, HAMi Scheduler selects positions by dividing the GPU into two halves, filling one half with small Profiles from its outer edge and keeping the other half free for half-size Profiles. For example, if `1g.5gb` or `2g.10gb` is created first on an empty A100 40GB GPU, it is placed at position 0, so `3g.20gb` can still be created at position 4 afterward, but `4g.20gb`, which can start only at position 0, cannot be created.

#### 1.4.2. MIG Instance Allocation

{{< figure caption="[Figure 3] Dynamic MIG Allocation Process" src="images/hami-nvidia-dynamic-mig.png" width="900px" >}}

[Figure 3] shows the Dynamic MIG allocation process.

1. HAMi Scheduler reserves the MIG Profile selected as in [File 8] together with the physical position to create it, and records them in the Pod's `hami.io/vgpu-mig-allocations` Annotation.
2. kubelet on the Node to which the Pod is bound sends an `Allocate()` gRPC request to HAMi Device Plugin.
3. HAMi Device Plugin looks up the reserved Profile and position from the Pod's Annotation.
4. HAMi Device Plugin dynamically creates the GPU Instance and Compute Instance of the reserved Profile through NVML and allocates them to the Container. If an Idle MIG Instance of the same size exists at the same position, it reuses it instead of creating a new one.

MIG Instances are not removed immediately when the Pod terminates. This reduces the overhead of removing and recreating MIG Instances when the same Profile is requested again, and a reused MIG Instance keeps the same MIG UUID. Every 5 seconds, HAMi Device Plugin compares the `hami.io/vgpu-mig-allocations` Annotations of running Pods with the MIG Instances it manages, and switches MIG Instances used by no Pod to the Idle state. In contrast, HAMi Scheduler calculates MIG Instance positions only from the Annotations of Pods that have not terminated, so it regards the positions occupied by Idle MIG Instances as free space, and when a newly reserved position overlaps Idle MIG Instances, HAMi Device Plugin removes the overlapping MIG Instances in order of least recent use and then creates the new MIG Instance.

```yaml {caption="[File 10] mig-config8.yaml (the mig-2g-b Pod differing only in name and the nodeSelector and tolerations of mig-3g are omitted)", linenos=table}
apiVersion: v1
kind: Pod
metadata:
  name: mig-2g-a
  annotations:
    nvidia.com/vgpu-mode: "mig"
    nvidia.com/mig-profile-preference: "2g.10gb"
    hami.io/gpu-scheduler-policy: "binpack"
spec:
  nodeSelector:
    group: gpu-a100-hami
  tolerations:
  - key: group
    operator: Equal
    value: gpu-a100-hami
    effect: NoSchedule
  - key: nvidia.com/gpu
    operator: Exists
    effect: NoSchedule
  containers:
  - name: cuda
    image: nvidia/cuda:12.4.0-base-ubuntu22.04
    command: ["sleep", "infinity"]
    resources:
      limits:
        nvidia.com/gpu: 1
        nvidia.com/gpumem: 9000
---
apiVersion: v1
kind: Pod
metadata:
  name: mig-3g
  annotations:
    nvidia.com/vgpu-mode: "mig"
    nvidia.com/mig-profile-preference: "3g.20gb"
    hami.io/gpu-scheduler-policy: "binpack"
spec:
  containers:
  - name: cuda
    image: nvidia/cuda:12.4.0-base-ubuntu22.04
    command: ["sleep", "infinity"]
    resources:
      limits:
        nvidia.com/gpu: 1
        nvidia.com/gpumem: 19000
```

[File 10] shows Pods that compose a combination of two `2g.10gb` and one `3g.20gb` MIG Instances on one A100. Since the default Device Scheduling policy `spread` distributes vGPUs across different GPUs, the `binpack` policy gathers the vGPUs of the three Pods on the same GPU, and according to the position selection algorithm, `2g.10gb` is created at positions 0 and 2 and `3g.20gb` at position 4. Whether the three Pods are gathered on the same GPU and the reserved Profiles and positions are checked with each Pod's `hami.io/vgpu-mig-allocations` Annotation, and the created MIG Instances are checked with the `nvidia-smi -L` output inside the Pods.

```yaml {caption="[File 11] mig-config9.yaml (the mig-1g-b Pod differing only in name and the nodeSelector and tolerations are omitted)", linenos=table}
apiVersion: v1
kind: Pod
metadata:
  name: mig-1g-a
  annotations:
    nvidia.com/vgpu-mode: "mig"
    nvidia.com/mig-profile-preference: "1g.5gb"
    hami.io/gpu-scheduler-policy: "binpack"
spec:
  containers:
  - name: cuda
    image: nvidia/cuda:12.4.0-base-ubuntu22.04
    command: ["sleep", "infinity"]
    resources:
      limits:
        nvidia.com/gpu: 1
        nvidia.com/gpumem: 4500
```

[File 11] shows the two `1g.5gb` Pods applied after deleting the `mig-2g-b` Pod. The `2g.10gb` Instance of the deleted Pod remains in the Idle state, but HAMi Scheduler regards its position as free space, so when the newly reserved `1g.5gb` positions overlap the Idle Instance, HAMi Device Plugin removes the Idle Instance and then creates two `1g.5gb` Instances. This checks the process in which the composition of the same GPU switches to a combination of one `2g.10gb`, two `1g.5gb`, and one `3g.20gb`, and whether the MIG Instances of the running `mig-2g-a` and `mig-3g` Pods are kept during the switch.

At each step, the Logs of HAMi Device Plugin's `device-plugin` and `vgpu-monitor` Containers and HAMi Scheduler, the Node's `hami.io/node-nvidia-register` Annotation, and the `nvidia-smi -L` output inside the Pods are collected to trace the creation, reuse, and removal of MIG Instances. The applied manifests, the collection Script, and the collected results are kept in the `manifests/mig` and `dumps/mig` folders of the post repository.

### 1.5. GPU Selection

HAMi provides features to control the physical GPU on which a vGPU is placed through Pod Annotations. The following Annotations can specify or exclude GPU Types and UUIDs.

* `nvidia.com/use-gputype` : List of GPU Types allowed for allocation (e.g., `A100,V100`)
* `nvidia.com/nouse-gputype` : List of GPU Types excluded from allocation
* `nvidia.com/use-gpuuuid`, `nvidia.com/nouse-gpuuuid` : List of GPU UUIDs allowed for or excluded from allocation

```yaml {caption="[File 9] Example Pod specifying the GPU Type and Scheduling policy", linenos=table}
apiVersion: v1
kind: Pod
metadata:
  name: vgpu-pod
  annotations:
    nvidia.com/use-gputype: "A100"
    hami.io/gpu-scheduler-policy: "binpack"
spec:
  containers:
  - name: cuda
    image: nvidia/cuda:12.4.0-base-ubuntu22.04
    command: ["sleep", "infinity"]
    resources:
      limits:
        nvidia.com/gpu: 1
        nvidia.com/gpumem: 3000
```

[File 9] shows an example Pod that is allocated a vGPU on an A100 GPU with the `binpack` policy. In addition to `binpack` and `spread`, the Device Scheduling policies of NVIDIA GPU include the `mutex` policy, which requires a physical GPU exclusively without sharing, and since v2.10.0, policies can be combined by joining them with commas.

Topology-based GPU selection for Workloads requesting multiple GPUs is also provided since v2.7.0. When the `ENABLE_TOPOLOGY_SCORE` environment variable is enabled in HAMi Device Plugin, it scores the connection type (NVLink, PCIe) between GPU pairs through NVML and records it in the Node's `hami.io/node-nvidia-score` Annotation, and specifying `topology-aware` in the Pod's `hami.io/gpu-scheduler-policy` Annotation preferentially selects GPU sets connected through NVLink to ensure inter-GPU communication performance.

### 1.6. GPU Health Check

HAMi Device Plugin inherits the Health Check implementation of NVIDIA Device Plugin and detects GPU failures through NVML Events. When an **Xid** (GPU error number reported by the NVIDIA Driver) Critical Error Event occurs, it marks the GPU as `Unhealthy`, and although it also subscribes to ECC Events, it does not use them for the `Unhealthy` decision. GPUs whose NVML Event registration fails are also marked `Unhealthy`, and if waiting for Events itself fails, all GPUs are marked `Unhealthy`.

Xids `13`, `31`, `43`, `45`, `68`, and `109` are considered Application errors rather than GPU failures and are ignored by default. The `DP_DISABLE_HEALTHCHECKS` environment variable specifies additional Xids to ignore or disables the entire Health Check with `all`, and the `DP_ENABLE_HEALTHCHECKS` environment variable re-enables ignored Xids. Both environment variables can be specified through Helm's `devicePlugin.extraEnvs`.

Since there is no path that turns a GPU marked `Unhealthy` back to `Healthy`, the HAMi Device Plugin Pod must be restarted to use the GPU again even after it recovers. Also, Health Check only prevents allocation of the GPU and does not terminate Pods already using it.

## 2. References

* HAMi GitHub : [https://github.com/Project-HAMi/HAMi](https://github.com/Project-HAMi/HAMi)
* HAMi-core GitHub : [https://github.com/Project-HAMi/HAMi-core](https://github.com/Project-HAMi/HAMi-core)
* HAMi Dynamic MIG Guide : [https://project-hami.io/docs/userguide/nvidia-device/dynamic-mig-support](https://project-hami.io/docs/userguide/nvidia-device/dynamic-mig-support)
* HAMi Scheduling Policy : [https://project-hami.io/docs/userguide/nvidia-device/scheduling-policy](https://project-hami.io/docs/userguide/nvidia-device/scheduling-policy)
* HAMi GPU Topology Scheduling : [https://project-hami.io/docs/developers/gpu-topology-scheduling](https://project-hami.io/docs/developers/gpu-topology-scheduling)
* HAMi Configuration Guide : [https://project-hami.io/docs/userguide/configure](https://project-hami.io/docs/userguide/configure)
* Kubernetes NVIDIA Device Plugin : [https://ssup2.github.io/blog-software/en/docs/theory-analysis/kubernetes-nvidia-device-plugin/](https://ssup2.github.io/blog-software/en/docs/theory-analysis/kubernetes-nvidia-device-plugin/)

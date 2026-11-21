---
title: Kubernetes HAMi NVIDIA GPU
draft: true
---

## 1. Kubernetes HAMi NVIDIA GPU

{{< figure caption="[Figure 1] HAMi NVIDIA GPU Architecture" src="images/hami-nvidia-architecture.png" width="900px" >}}

**HAMi**는 NVIDIA GPU를 **vGPU** 단위로 가상화하여 하나의 GPU를 다수의 Pod이 공유할 수 있도록 지원한다. NVIDIA Device Plugin의 Time-slicing 기법도 하나의 GPU를 다수의 Pod에 할당할 수 있지만 Container별 Memory 크기 제한이나 연산 사용률 제한은 제공하지 않는 반면, HAMi는 CUDA API 호출을 가로채는 방식으로 Software Level에서 vGPU 단위의 Memory 크기 제한과 **SM** (Streaming Multiprocessor) 사용률 제한을 제공한다. 이 제한은 GPU의 Time-slicing 공유 위에서 동작하며, NVIDIA MPS 기반의 공유 기법은 제공하지 않는다. 또한 MIG를 지원하는 GPU에서는 Workload의 요청에 따라서 MIG Instance를 동적으로 생성하는 Dynamic MIG 기능도 제공한다.

[Figure 1]은 HAMi의 NVIDIA GPU 지원 구성을 나타내고 있다. NVIDIA GPU 지원은 다음의 두 가지 요소가 담당한다.

* **HAMi Device Plugin** : `hami-device-plugin` DaemonSet을 통해서 GPU Node에서 동작하며, 하나의 Pod 안에서 vGPU를 kubelet에 등록하고 GPU의 Health 상태를 확인하며 vGPU를 할당하는 `device-plugin` Container와, GPU와 vGPU의 사용량을 Metric으로 노출하는 `vgpu-monitor` Container가 함께 동작한다.
* **HAMi-core** : Container 내부에 주입되는 `libvgpu.so` Library이며, CUDA Driver API 호출을 가로채서 vGPU의 Memory 크기 제한과 SM 사용률 제한을 수행한다.

{{< table caption="[Table 1] HAMi가 제공하는 vGPU Resource 종류" >}}
| Resource | 용도 |
|---|---|
| `nvidia.com/gpu` | Container에 할당할 vGPU의 개수 |
| `nvidia.com/gpumem` | 각 vGPU에 할당할 Memory의 크기 (MiB 단위) |
| `nvidia.com/gpumem-percentage` | 물리 GPU Memory 대비 각 vGPU에 할당할 Memory의 비율 (%) |
| `nvidia.com/gpucores` | 각 vGPU가 이용할 수 있는 SM 사용률 (%) |
| `nvidia.com/priority` | vGPU Workload의 우선순위 (`0` 높음, `1` 낮음. 기본값 `1`) |
{{< /table >}}

[Table 1]은 HAMi가 제공하는 vGPU Resource의 종류를 나타내고 있다. NVIDIA Device Plugin과 동일하게 `nvidia.com/gpu` Resource로 GPU의 개수를 요청하지만, HAMi에서는 물리 GPU가 아닌 vGPU의 개수를 의미한다. `nvidia.com/gpucores`에 100을 명시하면 물리 GPU 전체를 전용으로 할당받으며, `nvidia.com/priority`가 다른 두 Workload가 하나의 GPU를 공유하면 높은 우선순위의 Workload가 동작하는 동안 낮은 우선순위의 Workload의 연산이 제한된다.

```yaml {caption="[File 1] vGPU를 요청하는 Pod 예제", linenos=table}
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

[File 1]은 3000MiB의 Memory와 30%의 SM 사용률을 갖는 하나의 vGPU를 요청하는 Pod의 예제를 나타내고 있다. 하나의 Container가 다수의 vGPU를 요청하는 경우에는 각 vGPU가 서로 다른 물리 GPU에 배치되며, Memory 크기와 SM 사용률 제한은 각 vGPU마다 동일하게 적용된다. `nvidia.com/gpumem`을 생략하면 물리 GPU의 Memory 전체를 요청한 것으로 처리되기 때문에, 해당 GPU를 다른 Pod와 공유하지 않는 전용 할당이 된다.

### 1.1. Test 환경 구축

Test는 [Kubernetes HAMi 설치 및 vLLM 모델 서빙](https://ssup2.github.io/blog-software/docs/record/kubernetes-hami-vllm-gpu-ubuntu-26.04/) 글에서 구축한 환경을 기반으로 수행한다. `192.168.1.32` 단일 Server에 Nvidia RTX 5060 Ti 16GB GPU 1장이 장착되어 있으며, Kubernetes v1.34.12와 HAMi 2.11.0이 설치되어 있다. 이후 Shell/File 블록은 모두 이 환경에서의 실측 결과이다.

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

```shell {caption="[Shell 1] Test Pod 생성과 vGPU 환경 변수 확인"}
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

[File 2]는 2000MiB Memory와 30% SM 사용률로 제한된 vGPU 하나를 요청하는 Pod 예제이다. `GPU_CORE_UTILIZATION_POLICY=force`로 유휴 상태에서도 SM 사용률 제한을 강제하며, 이미지는 CUDA 13.0 PyTorch가 포함된 vLLM 공식 이미지를 재활용한다. Test Node의 GPU를 이용하는 다른 Workload는 측정 동안 중지하였다.

[Shell 1]은 Pod 생성 후 Container 안의 환경 변수와 Preload 설정을 나타내고 있다. HAMi Device Plugin이 `nvidia.com/gpumem`, `nvidia.com/gpucores` 요청에 맞춰 `CUDA_DEVICE_MEMORY_LIMIT_0`과 `CUDA_DEVICE_SM_LIMIT`을 주입하였고, `/etc/ld.so.preload` 파일에 `libvgpu.so`가 등록된 것을 확인할 수 있다.

```yaml {caption="[File 3] Test Pod에 기록된 HAMi Annotation", linenos=table}
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

[File 3]은 Test Pod에 기록된 HAMi Annotation을 나타내고 있다. NVIDIA GPU는 Annotation 이름의 Accelerator 부분에 초기 구현의 이름인 `vgpu`를 이용하기 때문에 `hami.io/vgpu-devices-allocated` 같은 이름을 쓰며, Accelerator 종류를 나타내는 Type에는 `NVIDIA`가 기록된다. 할당이 완료되었기 때문에 `hami.io/vgpu-devices-to-allocate`에는 Container 구분자만 남아 있고 `hami.io/bind-phase`는 `success`이다. HAMi Device Plugin은 `Allocate()` 시점에 이 Annotation을 읽어서 할당할 GPU와 제한 값을 파악하며, 그 결과가 [Shell 1]의 환경 변수로 주입된 것이다.

### 1.2. vGPU 설정

{{< table caption="[Table 2] 주요 vGPU 설정" >}}
| 설정 | 용도 (기본값) |
|---|---|
| `deviceSplitCount` | 하나의 물리 GPU에 할당할 수 있는 vGPU의 최대 개수 (`10`) |
| `deviceMemoryScaling` | 물리 Memory 크기 대비 할당 가능한 Memory의 비율 (`1`) |
| `deviceCoreScaling` | 물리 SM 대비 할당 가능한 SM 사용률의 비율 (`1`) |
| `operatingmode` | Node의 vGPU 동작 모드. `hami-core`, `mig`, `remote` 중 하나 (`hami-core`) |
{{< /table >}}

[Table 2]는 NVIDIA GPU의 주요 vGPU 설정을 나타내고 있다. Cluster 공통 설정은 `hami-scheduler-device` ConfigMap의 `nvidia` Section에 정의하며, Node 단위의 재정의는 `hami-device-plugin` ConfigMap의 `nodeconfig` 목록에 Node 이름과 함께 정의한다. NVIDIA GPU에서는 물리 GPU 개수 × `deviceSplitCount`개의 `nvidia.com/gpu`가 Node의 Allocatable에 등록된다. `operatingmode`의 `remote`는 네트워크를 통해서 다른 Server의 GPU를 이용하는 Mode이다.

`deviceMemoryScaling`을 1보다 크게 설정하면 물리 Memory보다 많은 Memory를 할당하는 초과 할당이 가능한데, vGPU별 Memory 제한은 유지되지만 모든 vGPU가 제한값까지 Memory를 이용하면 물리 GPU의 OOM이 발생할 수 있는 실험적인 기능이다. `deviceCoreScaling`도 1보다 크게 설정하면 물리 SM보다 많은 SM 사용률을 할당할 수 있다.

{{< table caption="[Table 3] Pod 요청을 보정하는 vGPU 설정" >}}
| 설정 | 적용 위치 | 동작 (기본값) |
|---|---|---|
| `defaultGPUNum` | Mutating Webhook | Container가 GPU Memory나 SM 사용률만 요청하고 GPU 개수를 요청하지 않으면 `nvidia.com/gpu`를 이 값으로 채운다 (`1`) |
| `defaultMemory` | HAMi Scheduler | Container가 GPU Memory를 요청하지 않았을 때 적용할 Memory 크기 (MiB). `0`이면 GPU Memory 전체를 요청한 것으로 처리한다 (`0`) |
| `defaultCores` | HAMi Scheduler | Container가 SM 사용률을 요청하지 않았을 때 적용할 SM 사용률 (`0`) |
| `overwriteEnv` | Mutating Webhook | `true`이면 GPU를 요청하지 않은 Container에 `NVIDIA_VISIBLE_DEVICES=none` 환경 변수를 넣어 GPU가 보이지 않도록 한다 (`false`) |
| `runtimeClassName` | Mutating Webhook | GPU를 요청하는 Pod에 RuntimeClass가 지정되지 않았으면 Pod의 `spec.runtimeClassName`에 이 값을 넣는다 (`""`) |
{{< /table >}}

[Table 3]은 Pod의 요청을 보정하는 vGPU 설정을 나타내고 있다. [Table 3]의 설정은 HAMi Device Plugin의 `Allocate()` 응답과는 관계없이, Pod 생성 시 Mutating Webhook이 Pod spec을 변경하거나 Scheduling 시 HAMi Scheduler가 요청량을 계산할 때 적용된다. `runtimeClassName`이 비어 있으면 Kubernetes의 Default RuntimeClass가 이용된다.

```yaml {caption="[File 4] vGPU 설정이 반영된 Node Annotation", linenos=table}
apiVersion: v1
kind: Node
metadata:
  name: gpu
  annotations:
    hami.io/node-nvidia-register: '[{"id":"GPU-034026c4-...","count":10,"devmem":16311,"devcore":100,"type":"NVIDIA GeForce RTX 5060 Ti","mode":"hami-core","health":true}]'
```

[File 4]는 HAMi Device Plugin이 GPU Node에 주기적으로 기록하는 `hami.io/node-nvidia-register` Annotation을 나타내고 있으며, 각 GPU 항목에는 [Table 4]와 같이 [Table 2]의 설정이 반영된 값이 기록된다.

{{< table caption="[Table 4] NVIDIA GPU의 Node Register Annotation 값" >}}
| 항목 | NVIDIA GPU에서 기록되는 값 |
|---|---|
| `id` | NVML로 조회한 GPU UUID |
| `index` | Node 안에서의 GPU 번호 |
| `count` | `deviceSplitCount` 값 |
| `devmem` | 물리 Memory 크기 (MiB) × `deviceMemoryScaling` |
| `devcore` | `100` × `deviceCoreScaling` (SM 사용률 %, MIG Mode는 `100`) |
| `type` | NVML로 조회한 GPU 모델 이름 (`NVIDIA` 접두사로 정규화) |
| `numa` | sysfs로 조회한 GPU의 NUMA Node |
| `mode` | `operatingmode` 값 (`hami-core`, `mig`, `remote`) |
| `health` | GPU Health Check 결과 |
{{< /table >}}

[File 4]의 첫 번째 GPU처럼 `index`와 `numa`가 `0`인 경우에는 JSON에서 생략된다. `devmem`은 Driver가 보고하는 물리 Memory 크기이기 때문에 GPU의 표기 용량보다 조금 작은 값이 기록된다.

### 1.3. HAMi-core 주입

Container에는 세 종류의 Library가 필요하며, 종류마다 전달 방식이 다르다.

* **CUDA SDK** (`libcudart.so` 등) : Container Image에 미리 포함되어 있어야 하며, 별도로 전달되지 않는다.
* **NVIDIA Driver Library** (`libcuda.so`, `libnvidia-ml.so` 등) : **NVIDIA Container Toolkit**이 Host의 Library를 Container에 Mount한다. NVIDIA Device Plugin을 이용할 때와 동일한 방식이다.
* **HAMi-core** (`libvgpu.so` 등) : HAMi Device Plugin이 Mount할 경로를 지정하면 Container Runtime이 Mount한다. HAMi에만 존재하는 방식이다.

NVIDIA Driver Library의 경우 HAMi Device Plugin은 기본 설정 (`deviceListStrategy: envvar`) 에서 `Allocate()` 응답의 `NVIDIA_VISIBLE_DEVICES` 환경 변수로 할당할 GPU만 알려준다. Container가 생성될 때 NVIDIA Container Toolkit의 Runtime이 이 환경 변수를 읽어서 필요한 Library와 Device 목록을 CDI 명세로 즉석에서 생성하고 (`jit-cdi` Mode), 이를 Container 설정에 반영하여 Mount가 이루어진다.

HAMi-core는 NVIDIA Container Toolkit이 알지 못하는 파일이기 때문에 HAMi Device Plugin이 별도로 처리한다. Mount의 원본은 Host에 존재해야 하므로, HAMi Device Plugin은 시작할 때 `postStart` Hook의 `vgpu-init.sh`로 Image 안의 `libvgpu.so`를 Host의 `/usr/local/vgpu` (Helm `global.gpuHookPath` 기본값 기준) 로 복사하고 `ld.so.preload`를 생성한다. 이후 Pod가 생성되면 HAMi Device Plugin은 `Allocate()` 응답에 다음의 Mount 대상을 지정한다.

* `/usr/local/vgpu/libvgpu.so` : Host의 HAMi-core Library가 읽기 전용으로 Mount되는 경로이다.
* `/etc/ld.so.preload` : `libvgpu.so`를 먼저 Load하도록 지정하는 Host의 `/usr/local/vgpu/ld.so.preload`가 읽기 전용으로 Mount되는 경로이다.
* `/usr/local/vgpu` : HAMi-core의 공유 Cache 파일이 위치하는 경로이다. Host의 `/usr/local/vgpu/containers/<Pod UID>_<Container 이름>` Directory가 Container마다 생성되어 Mount된다.
* `/tmp/vgpulock` : HAMi-core가 이용하는 Lock 파일 경로이다. Host의 같은 경로를 Mount하여 Node의 Container들이 공유한다.

HAMi-core는 `LD_PRELOAD` 환경 변수가 아니라 `/etc/ld.so.preload` 파일로 주입된다. `LD_PRELOAD` 환경 변수는 물려받은 Process에만 적용되기 때문에 App이 자식 Process를 생성하면서 환경 변수를 정리하면 격리가 끊기지만, `/etc/ld.so.preload` 파일은 동적 링커가 모든 Process의 시작 시점에 항상 읽기 때문에 Container 안의 모든 Process에 환경 변수와 무관하게 적용된다.

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

```shell {caption="[Shell 2] GPU 전체를 할당받은 Container의 HAMi-core 비활성화 확인"}
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

다만 GPU를 통째로 할당받는 Container에는 HAMi-core가 주입되지 않는다. Container가 할당받은 모든 GPU의 Memory 전체를 요청하고 SM 사용률을 요청하지 않거나 `100`으로 요청하면, HAMi Device Plugin은 `/etc/ld.so.preload`를 Mount하는 대신 `CUDA_DISABLE_CONTROL=true` 환경 변수를 주입하여 HAMi-core의 제한을 끈다. 이는 기본값이 `true`인 Helm의 `devicePlugin.monitor.disableHAMiCoreForWholeGPU` 설정에 따른 동작이며, `deviceMemoryScaling`과 `deviceCoreScaling`이 모두 1인 Node에서만 적용된다. `nvidia.com/gpumem`을 생략한 Pod도 GPU Memory 전체를 요청한 것으로 처리되기 때문에 이 동작의 대상이 되며, 이 경우 `vgpu-monitor`는 NVML로 조회한 GPU 전체의 사용량을 Container의 Metric으로 노출한다.

[File 5]는 `nvidia.com/gpu`만 요청하는 Pod이며, [Shell 2]와 같이 GPU의 Memory 전체인 `16311` MiB와 SM 사용률 `100`이 할당된다. `CUDA_DISABLE_CONTROL=true`가 주입되고 `/etc/ld.so.preload`는 Mount되지 않기 때문에, `libvgpu.so` 파일은 Container에 존재하지만 Load되지 않는다.

### 1.4. Memory, SM 사용률 제한

{{< figure caption="[Figure 2] HAMi-core Isolation" src="images/hami-core-isolation.png" width="700px" >}}

vGPU의 Memory 크기 제한과 SM 사용률 제한은 Container 내부의 HAMi-core (`libvgpu.so`)가 수행한다. [Figure 2]는 HAMi-core의 제한 동작을 나타내고 있다. `libvgpu.so`는 CUDA Driver API와 같은 이름의 함수들을 정의한 Library이며, 동적 링커는 같은 이름의 함수가 여러 Library에 존재하면 먼저 Load된 Library의 함수에 호출을 연결하기 때문에, `/etc/ld.so.preload`에 등록되어 CUDA Library보다 먼저 Load되는 `libvgpu.so`의 함수가 App의 CUDA Driver API 호출을 대신 받는다. `libvgpu.so`는 전달받은 호출이 제한 조건을 만족하는지 검사한 후 실제 CUDA Library의 함수로 전달하기 때문에, App과 CUDA Library를 수정하지 않고 모든 호출에 개입할 수 있다.

Memory 크기 제한은 Memory 할당 API를 가로채서 수행된다. `libvgpu.so`는 `cuMemAlloc()` 같은 Memory 할당 함수가 호출될 때마다 Container의 GPU Memory 사용량을 추적하며, 사용량이 `CUDA_DEVICE_MEMORY_LIMIT` 환경 변수에 설정된 제한을 초과하면 CUDA의 OOM (Out of Memory) Error를 반환한다. 또한 `cuMemGetInfo()` 같은 Memory 조회 함수는 물리 GPU의 Memory 크기 대신 vGPU의 Memory 크기를 반환하도록 가로채지기 때문에, App과 `nvidia-smi` 명령어는 vGPU의 Memory 크기를 전체 Memory 크기로 인식한다.

```shell {caption="[Shell 3] vGPU Memory 제한 확인"}
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

[Shell 3]은 Memory 제한이 적용되는 모습을 나타내고 있다. `nvidia-smi`는 Pod 안에서 전체 Memory를 `2000 MiB`로 보고하여 HAMi-core가 `cuMemGetInfo()` 결과를 vGPU 크기로 치환한 것을 확인할 수 있다. 1200MB 할당은 제한 안이라 성공하지만, 2500MB 할당은 HAMi-core의 `Device 0 OOM 2636120064 / 2097152000` Log와 함께 거부되어 PyTorch는 `CUDA out of memory`를 반환한다. 로그의 `2097152000` Byte는 `2000 MiB`를 Byte로 환산한 값이다.

SM 사용률 제한은 Kernel 실행 API를 가로채서 수행된다. `libvgpu.so`는 GPU의 사용률을 주기적으로 측정하면서 Token 기반으로 Kernel 실행 가능 여부를 관리하며, `cuLaunchKernel()` 같은 Kernel 실행 함수가 호출될 때 Token이 부족하면 Kernel 실행을 지연시켜 vGPU의 SM 사용률을 `CUDA_DEVICE_SM_LIMIT` 환경 변수에 설정된 제한 이하로 유지한다. 제한 동작은 `GPU_CORE_UTILIZATION_POLICY` 환경 변수로 다음과 같이 변경할 수 있다.

* `default` : GPU가 유휴 상태이면 제한을 초과하는 이용을 허용한다 (기본값).
* `force` : 유휴 상태와 무관하게 항상 제한을 강제한다.
* `disable` : SM 사용률 제한을 수행하지 않는다.

```shell {caption="[Shell 4] SM 사용률 제한 확인"}
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

[Shell 4]는 Pod 안에서 matmul을 지속적으로 수행하는 동안의 SM 사용률을 두 Source에서 샘플링한 결과이다. `vgpu-monitor`가 노출하는 `hami_container_device_utilization_ratio` Metric은 `32`로 요청한 30% 제한에 수렴하며, Host의 `nvidia-smi dmon`도 1초 단위 샘플에서 12%와 39% 사이를 오가며 제한값 근처에 머문다. HAMi-core가 Kernel 실행을 지연시켜 사용률을 조절하기 때문에, 순간 샘플은 제한값 위아래로 변동하지만 평균은 제한값에 맞춰진다.

HAMi-core가 GPU의 시간을 직접 분할하는 것은 아니다. 하나의 GPU를 공유하는 Container들의 연산은 NVIDIA Driver와 GPU의 **Time-slicing**으로 번갈아 실행되며, `libvgpu.so`는 그 앞단에서 Kernel 실행을 지연시켜 사용률만 조절한다. 반면 Memory는 시간으로 나뉘지 않고 모든 Container의 Data가 GPU Memory에 동시에 상주하며, `libvgpu.so`는 할당량만 제한한다.

여러 Process의 Kernel을 동시에 실행하는 **NVIDIA MPS** (Multi-Process Service) 기반의 공유는 지원하지 않는다. NVIDIA Device Plugin과 달리 HAMi Device Plugin에서는 MPS 관련 동작이 구현되어 있지 않으며, `operatingmode`로 선택할 수 있는 동작에도 MPS는 없다.

vGPU를 할당받은 App Container의 사용량 정보는 HAMi-core가 **Shared Memory Region**에 기록한다. Memory 제한은 Process가 아니라 Container 단위로 적용되기 때문에 Container 안의 모든 CUDA Process가 하나의 사용량 집계를 공유해야 하는데, HAMi-core는 [Shell 1]의 `CUDA_DEVICE_MEMORY_SHARED_CACHE` 환경 변수가 가리키는 Cache 파일을 mmap하는 방식으로 Process 사이의 Shared Memory를 구성한다. 파일 안에는 Memory, SM 제한값과 Process Slot 배열이 저장되며, 최초 실행된 Process가 제한값을 초기화한 후 각 Process는 자신의 Slot에 Device별 Memory 사용량과 SM 사용률을 기록한다.

Cache 파일은 HAMi Device Plugin이 hostPath Volume으로 App Container에 Mount한 경로에 생성되기 때문에 Container 밖에서도 같은 파일을 읽을 수 있으며, `vgpu-monitor`는 Node에 존재하는 vGPU Container들의 Cache 파일을 주기적으로 읽어서 Container별 Memory 사용량과 SM 사용률을 Metric으로 노출한다. 이처럼 HAMi의 제한은 CUDA API 가로채기를 통한 Software Level의 제한이기 때문에 별도의 Hardware 지원 없이 모든 NVIDIA GPU에서 이용할 수 있지만, MIG 같은 Hardware Level의 격리보다는 격리 수준이 낮다.

### 1.5. GPU 선택

HAMi는 Pod Annotation을 통해서 vGPU가 배치될 물리 GPU를 제어하는 기능을 제공한다. 다음의 Annotation을 통해서 GPU의 Type과 UUID를 지정하거나 제외할 수 있다.

* `nvidia.com/use-gputype` : 할당을 허용할 GPU Type 목록 (예: `A100,V100`)
* `nvidia.com/nouse-gputype` : 할당에서 제외할 GPU Type 목록
* `nvidia.com/use-gpuuuid`, `nvidia.com/nouse-gpuuuid` : 할당을 허용하거나 제외할 GPU의 UUID 목록

```yaml {caption="[File 6] GPU Type과 Scheduling 정책을 지정하는 Pod 예제", linenos=table}
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

[File 6]은 A100 GPU에서 `binpack` 정책으로 vGPU를 할당받는 Pod의 예제를 나타내고 있다. NVIDIA GPU의 Device Scheduling 정책에는 `binpack`, `spread` 외에도 물리 GPU를 공유 없이 전용으로 요구하는 `mutex` 정책이 있으며, v2.10.0부터는 정책을 쉼표로 연결하여 조합할 수 있다.

다수의 GPU를 요청하는 Workload를 위한 Topology 기반의 GPU 선택도 v2.7.0부터 제공된다. HAMi Device Plugin에 `ENABLE_TOPOLOGY_SCORE` 환경 변수를 활성화하면 NVML을 통해서 GPU 쌍 사이의 연결 방식 (NVLink, PCIe) 을 점수화하여 Node의 `hami.io/node-nvidia-score` Annotation에 기록하고, Pod의 `hami.io/gpu-scheduler-policy` Annotation에 `topology-aware`를 명시하면 NVLink로 연결된 GPU 집합을 우선적으로 선택하여 GPU 간 통신 성능을 보장한다.

### 1.6. Dynamic MIG

{{< figure caption="[Figure 3] Dynamic MIG Allocation Process" src="images/hami-nvidia-dynamic-mig.png" width="650px" >}}

**Dynamic MIG**는 vGPU 요청에 따라서 MIG Instance를 동적으로 생성하여 할당하는 기능이며 v2.5.0에서 도입되었다. HAMi-core의 Software Level 제한과 다르게 MIG는 GPU의 SM과 Memory를 Hardware Level에서 격리하기 때문에 더 높은 격리 수준을 제공한다. Node의 `operatingmode` 설정을 `mig`로 지정하면 해당 Node의 GPU는 HAMi-core 대신 MIG Instance 단위로 할당되며, Pod는 `hami-core` 모드와 동일한 vGPU Resource로 MIG Instance를 요청한다. [Figure 3]은 Dynamic MIG의 할당 과정을 나타내고 있다.

1. HAMi Scheduler는 Pod의 Memory 크기와 SM 사용률 요청을 만족하는 MIG Profile을 `migProfileAllowlist` 설정에 정의된 Profile 중에서 선택하고, Profile과 함께 생성할 물리 위치까지 예약하여 Pod의 Annotation에 기록한다.
2. Pod가 Bind된 Node의 kubelet은 HAMi Device Plugin에게 `Allocate()` gRPC 요청을 전송한다.
3. HAMi Device Plugin은 Pod의 Annotation에서 예약된 Profile과 위치를 조회한다.
4. HAMi Device Plugin은 예약된 Profile의 GPU Instance와 Compute Instance를 NVML을 통해서 동적으로 생성하여 Container에 할당하고, Pod가 종료되면 생성했던 MIG Instance를 회수한다.

```yaml {caption="[File 7] MIG 모드를 지정하는 Pod 예제", linenos=table}
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

[File 7]은 MIG Instance로 8000MiB의 Memory를 요청하는 Pod의 예제를 나타내고 있으며, 요청을 수용할 수 있는 가장 작은 MIG Profile (예: A100의 `1g.10gb`)이 선택된다. `nvidia.com/vgpu-mode` Annotation은 vGPU가 할당될 모드를 고정하는 Annotation이며, 생략하면 HAMi Scheduler가 `mig` Node와 `hami-core` Node를 하나의 vGPU Pool로 취급하여 조건을 만족하는 Node를 자유롭게 선택한다.

도입 초기의 Dynamic MIG는 `knownMigGeometries` 설정에 정의된 Geometry (Profile 조합) 단위로 GPU 전체의 MIG 구성을 전환하는 방식이었지만, v2.10.0의 Flexible MIG부터는 Profile 단위의 예약 방식으로 재구성되어 Node의 Cordon 없이 Workload별로 MIG Instance가 생성되고 회수된다. 단 HAMi가 MIG Instance의 생성과 제거를 단독으로 담당해야 하기 때문에, GPU Operator의 MIG Manager나 `mig-parted` 도구를 HAMi와 함께 운용할 수 없다.

### 1.7. GPU Health Check

HAMi Device Plugin은 NVIDIA Device Plugin의 Health Check 구현을 이어받아 NVML Event로 GPU 장애를 감지한다. **Xid** (NVIDIA Driver가 보고하는 GPU 오류 번호) Critical Error Event가 발생하면 해당 GPU를 `Unhealthy`로 표시하며, ECC Event도 구독하지만 `Unhealthy` 판정에는 이용하지 않는다. NVML Event 등록에 실패한 GPU도 `Unhealthy`로 표시되고, Event 대기 자체가 실패하면 모든 GPU가 `Unhealthy`로 표시된다.

Xid `13`, `31`, `43`, `45`, `68`, `109`는 GPU 장애가 아닌 Application 오류로 간주되어 기본적으로 무시된다. `DP_DISABLE_HEALTHCHECKS` 환경 변수는 추가로 무시할 Xid 목록을 지정하거나 `all`로 Health Check 전체를 비활성화하며, `DP_ENABLE_HEALTHCHECKS` 환경 변수는 무시되는 Xid를 다시 활성화한다. 두 환경 변수는 Helm의 `devicePlugin.extraEnvs`로 지정할 수 있다.

`Unhealthy`로 표시된 GPU를 `Healthy`로 되돌리는 경로는 존재하지 않기 때문에, GPU가 복구되어도 HAMi Device Plugin Pod를 재시작해야 다시 이용할 수 있다. 또한 Health Check는 GPU의 할당만 막을 뿐, 이미 해당 GPU를 이용 중인 Pod를 종료하지는 않는다.

## 2. 참조

* HAMi GitHub : [https://github.com/Project-HAMi/HAMi](https://github.com/Project-HAMi/HAMi)
* HAMi-core GitHub : [https://github.com/Project-HAMi/HAMi-core](https://github.com/Project-HAMi/HAMi-core)
* HAMi Dynamic MIG 가이드 : [https://project-hami.io/docs/userguide/nvidia-device/dynamic-mig-support](https://project-hami.io/docs/userguide/nvidia-device/dynamic-mig-support)
* HAMi Scheduling 정책 : [https://project-hami.io/docs/userguide/nvidia-device/scheduling-policy](https://project-hami.io/docs/userguide/nvidia-device/scheduling-policy)
* HAMi GPU Topology Scheduling : [https://project-hami.io/docs/developers/gpu-topology-scheduling](https://project-hami.io/docs/developers/gpu-topology-scheduling)
* HAMi 설정 가이드 : [https://project-hami.io/docs/userguide/configure](https://project-hami.io/docs/userguide/configure)
* Kubernetes NVIDIA Device Plugin : [https://ssup2.github.io/blog-software/docs/theory-analysis/kubernetes-nvidia-device-plugin/](https://ssup2.github.io/blog-software/docs/theory-analysis/kubernetes-nvidia-device-plugin/)

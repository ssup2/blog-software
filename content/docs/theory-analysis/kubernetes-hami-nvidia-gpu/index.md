---
title: Kubernetes HAMi NVIDIA GPU
draft: true
---

## 1. Kubernetes HAMi NVIDIA GPU

{{< figure caption="[Figure 1] HAMi NVIDIA GPU Architecture" src="images/hami-nvidia-architecture.png" width="900px" >}}

**HAMi**는 NVIDIA GPU를 **vGPU** 단위로 가상화하여 하나의 GPU를 다수의 Pod이 공유할 수 있도록 지원한다. NVIDIA Device Plugin의 Time-slicing 기법도 하나의 GPU를 다수의 Pod에 할당할 수 있지만 Container별 Memory 크기 제한이나 연산 사용률 제한은 제공하지 않는 반면, HAMi는 CUDA API 호출을 가로채는 방식으로 Software Level에서 vGPU 단위의 Memory 크기 제한과 **SM** (Streaming Multiprocessor) 사용률 제한을 제공한다. 또한 MIG를 지원하는 GPU에서는 Workload의 요청에 따라서 MIG Instance를 동적으로 생성하는 Dynamic MIG 기능도 제공한다.

[Figure 1]은 HAMi의 NVIDIA GPU 지원 구성을 나타내고 있다. NVIDIA GPU 지원은 다음의 두 가지 Component가 담당한다.

* **hami-device-plugin** : DaemonSet을 통해서 GPU Node에서 동작하며, 하나의 Pod 안에서 vGPU를 kubelet에 등록하고 할당하는 Device Plugin Container와 vGPU의 사용량을 Metric으로 노출하는 vGPU Monitor Container가 함께 동작한다.
* **HAMi-core** : Container 내부에 주입되는 `libvgpu.so` Library이며, CUDA Driver API 호출을 가로채서 vGPU의 Memory 크기 제한과 SM 사용률 제한을 수행한다.

{{< table caption="[Table 1] HAMi가 제공하는 vGPU Resource 종류" >}}
| Resource | 용도 |
|---|---|
| `nvidia.com/gpu` | Container에 할당할 vGPU의 개수 |
| `nvidia.com/gpumem` | 각 vGPU에 할당할 Memory의 크기 (MB 단위) |
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

[File 1]은 3000MB의 Memory와 30%의 SM 사용률을 갖는 하나의 vGPU를 요청하는 Pod의 예제를 나타내고 있다. 하나의 Container가 다수의 vGPU를 요청하는 경우에는 각 vGPU가 서로 다른 물리 GPU에 배치되며, Memory 크기와 SM 사용률 제한은 각 vGPU마다 동일하게 적용된다. `nvidia.com/gpumem`과 `nvidia.com/gpucores`를 생략하면 Memory 크기와 SM 사용률을 제한하지 않는 vGPU가 할당된다.

### 1.1. vGPU 설정

{{< table caption="[Table 2] 주요 vGPU 설정" >}}
| 설정 | 용도 (기본값) |
|---|---|
| `deviceSplitCount` | 하나의 물리 GPU에 할당할 수 있는 vGPU의 최대 개수 (`10`) |
| `deviceMemoryScaling` | 물리 Memory 크기 대비 할당 가능한 Memory의 비율 (`1`) |
| `deviceCoreScaling` | 물리 SM 대비 할당 가능한 SM 사용률의 비율 (`1`) |
| `operatingmode` | Node의 vGPU 동작 모드. `hami-core` 또는 `mig` (`hami-core`) |
{{< /table >}}

[Table 2]는 NVIDIA GPU의 주요 vGPU 설정을 나타내고 있다. Cluster 공통 설정은 `hami-scheduler-device` ConfigMap의 `nvidia` 섹션에 정의하며, Node 단위의 재정의는 `hami-device-plugin` ConfigMap의 `nodeconfig` 목록에 Node 이름과 함께 정의한다. `deviceMemoryScaling`을 1보다 크게 설정하면 물리 Memory보다 많은 Memory를 할당하는 초과 할당이 가능한데, vGPU별 Memory 제한은 유지되지만 모든 vGPU가 제한값까지 Memory를 이용하면 물리 GPU의 OOM이 발생할 수 있는 실험적인 기능이다.

### 1.2. Memory, SM 사용률 제한

{{< figure caption="[Figure 2] HAMi-core Isolation" src="images/hami-core-isolation.png" width="700px" >}}

vGPU의 Memory 크기 제한과 SM 사용률 제한은 Container 내부의 HAMi-core (`libvgpu.so`)가 수행한다. [Figure 2]는 HAMi-core의 제한 동작을 나타내고 있다. `libvgpu.so`는 `LD_PRELOAD` 환경 변수를 통해서 CUDA Library보다 먼저 Load되기 때문에, App이 호출하는 CUDA Driver API는 실제 CUDA Library에 전달되기 전에 `libvgpu.so`를 거치게 된다.

Memory 크기 제한은 Memory 할당 API를 가로채서 수행된다. `libvgpu.so`는 `cuMemAlloc()` 같은 Memory 할당 함수가 호출될 때마다 Container의 GPU Memory 사용량을 추적하며, 사용량이 `CUDA_DEVICE_MEMORY_LIMIT` 환경 변수에 설정된 제한을 초과하면 CUDA의 OOM (Out of Memory) Error를 반환한다. 또한 `cuMemGetInfo()` 같은 Memory 조회 함수는 물리 GPU의 Memory 크기 대신 vGPU의 Memory 크기를 반환하도록 가로채지기 때문에, App과 `nvidia-smi` 명령어는 vGPU의 Memory 크기를 전체 Memory 크기로 인식한다.

SM 사용률 제한은 Kernel 실행 API를 가로채서 수행된다. `libvgpu.so`는 GPU의 사용률을 주기적으로 측정하면서 Token 기반으로 Kernel 실행 가능 여부를 관리하며, `cuLaunchKernel()` 같은 Kernel 실행 함수가 호출될 때 Token이 부족하면 Kernel 실행을 지연시켜 vGPU의 SM 사용률을 `CUDA_DEVICE_SM_LIMIT` 환경 변수에 설정된 제한 이하로 유지한다. 제한 동작은 `GPU_CORE_UTILIZATION_POLICY` 환경 변수로 변경할 수 있으며, 기본값인 `default`는 GPU가 유휴 상태이면 제한을 초과하는 이용을 허용하고, `force`는 항상 제한을 강제하며, `disable`은 SM 사용률 제한을 수행하지 않는다.

Container의 vGPU 사용량 정보는 Container와 hami-device-plugin이 공유하는 Shared Memory Region에 기록된다. hami-device-plugin의 vGPU Monitor는 Shared Memory Region을 주기적으로 읽어서 Container별 Memory 사용량과 SM 사용률을 GPU Node의 31992 Port로 노출하며, hami-scheduler도 Cluster 전체의 vGPU 할당 현황을 31993 Port로 노출한다. 이처럼 HAMi의 제한은 CUDA API 가로채기를 통한 Software Level의 제한이기 때문에 별도의 Hardware 지원 없이 모든 NVIDIA GPU에서 이용할 수 있지만, MIG 같은 Hardware Level의 격리보다는 격리 수준이 낮다.

### 1.3. GPU 선택과 Scheduling 정책

HAMi는 Pod Annotation을 통해서 vGPU가 배치될 물리 GPU를 제어하는 기능을 제공한다. 다음의 Annotation을 통해서 GPU의 Type과 UUID를 지정하거나 제외할 수 있다.

* `nvidia.com/use-gputype` : 할당을 허용할 GPU Type 목록 (예: `A100,V100`)
* `nvidia.com/nouse-gputype` : 할당에서 제외할 GPU Type 목록
* `nvidia.com/use-gpuuuid`, `nvidia.com/nouse-gpuuuid` : 할당을 허용하거나 제외할 GPU의 UUID 목록

```yaml {caption="[File 2] GPU Type과 Scheduling 정책을 지정하는 Pod 예제", linenos=table}
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

[File 2]는 A100 GPU에서 `binpack` 정책으로 vGPU를 할당받는 Pod의 예제를 나타내고 있다. GPU를 선택하는 정책은 `hami.io/gpu-scheduler-policy` Annotation으로 지정하며, 기본값인 `spread`는 vGPU를 GPU에 고르게 분산하고 `binpack`은 할당량이 많은 GPU에 몰아서 할당한다. v2.10.0부터는 정책을 쉼표로 연결하여 조합할 수 있으며, 물리 GPU를 공유 없이 전용으로 요구하는 `mutex` 정책도 추가되었다.

다수의 GPU를 요청하는 Workload를 위한 Topology 기반의 GPU 선택도 v2.7.0부터 제공된다. hami-device-plugin에 `ENABLE_TOPOLOGY_SCORE` 환경 변수를 활성화하면 NVML을 통해서 GPU 쌍 사이의 연결 방식(NVLink, PCIe)을 점수화하여 Node의 `hami.io/node-nvidia-score` Annotation에 기록하고, Pod의 `hami.io/gpu-scheduler-policy` Annotation에 `topology-aware`를 명시하면 NVLink로 연결된 GPU 집합을 우선적으로 선택하여 GPU 간 통신 성능을 보장한다.

### 1.4. Dynamic MIG

{{< figure caption="[Figure 3] Dynamic MIG Allocation Process" src="images/hami-nvidia-dynamic-mig.png" width="650px" >}}

**Dynamic MIG**는 vGPU 요청에 따라서 MIG Instance를 동적으로 생성하여 할당하는 기능이며 v2.5.0에서 도입되었다. HAMi-core의 Software Level 제한과 다르게 MIG는 GPU의 SM과 Memory를 Hardware Level에서 격리하기 때문에 더 높은 격리 수준을 제공한다. Node의 `operatingmode` 설정을 `mig`로 지정하면 해당 Node의 GPU는 HAMi-core 대신 MIG Instance 단위로 할당되며, Pod는 `hami-core` 모드와 동일한 vGPU Resource로 MIG Instance를 요청한다. [Figure 3]은 Dynamic MIG의 할당 과정을 나타내고 있다.

1. hami-scheduler는 Pod의 Memory 크기와 SM 사용률 요청을 만족하는 MIG Profile을 `migProfileAllowlist` 설정에 정의된 Profile 중에서 선택하고, Profile과 함께 생성할 물리 위치까지 예약하여 Pod의 Annotation에 기록한다.
2. Pod가 Bind된 Node의 kubelet은 hami-device-plugin에게 `Allocate()` gRPC 요청을 전송한다.
3. hami-device-plugin은 Pod의 Annotation에서 예약된 Profile과 위치를 조회한다.
4. hami-device-plugin은 예약된 Profile의 GPU Instance와 Compute Instance를 NVML을 통해서 동적으로 생성하여 Container에 할당하고, Pod가 종료되면 생성했던 MIG Instance를 회수한다.

```yaml {caption="[File 3] MIG 모드를 지정하는 Pod 예제", linenos=table}
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

[File 3]은 MIG Instance로 8000MB의 Memory를 요청하는 Pod의 예제를 나타내고 있으며, 요청을 수용할 수 있는 가장 작은 MIG Profile (예: A100의 `1g.10gb`)이 선택된다. `nvidia.com/vgpu-mode` Annotation은 vGPU가 할당될 모드를 고정하는 Annotation이며, 생략하면 hami-scheduler가 `mig` Node와 `hami-core` Node를 하나의 vGPU Pool로 취급하여 조건을 만족하는 Node를 자유롭게 선택한다.

도입 초기의 Dynamic MIG는 `knownMigGeometries` 설정에 정의된 Geometry (Profile 조합) 단위로 GPU 전체의 MIG 구성을 전환하는 방식이었지만, v2.10.0의 Flexible MIG부터는 Profile 단위의 예약 방식으로 재구성되어 Node의 Cordon 없이 Workload별로 MIG Instance가 생성되고 회수된다. 단 HAMi가 MIG Instance의 생성과 제거를 단독으로 담당해야 하기 때문에, GPU Operator의 MIG Manager나 `mig-parted` 도구를 HAMi와 함께 운용할 수 없다.

## 2. 참조

* HAMi GitHub : [https://github.com/Project-HAMi/HAMi](https://github.com/Project-HAMi/HAMi)
* HAMi-core GitHub : [https://github.com/Project-HAMi/HAMi-core](https://github.com/Project-HAMi/HAMi-core)
* HAMi Dynamic MIG 가이드 : [https://project-hami.io/docs/userguide/nvidia-device/dynamic-mig-support](https://project-hami.io/docs/userguide/nvidia-device/dynamic-mig-support)
* HAMi Scheduling 정책 : [https://project-hami.io/docs/userguide/nvidia-device/scheduling-policy](https://project-hami.io/docs/userguide/nvidia-device/scheduling-policy)
* HAMi GPU Topology Scheduling : [https://project-hami.io/docs/developers/gpu-topology-scheduling](https://project-hami.io/docs/developers/gpu-topology-scheduling)
* HAMi 설정 가이드 : [https://project-hami.io/docs/userguide/configure](https://project-hami.io/docs/userguide/configure)
* Kubernetes HAMi : [https://ssup2.github.io/blog-software/docs/theory-analysis/kubernetes-hami/](https://ssup2.github.io/blog-software/docs/theory-analysis/kubernetes-hami/)
* Kubernetes NVIDIA Device Plugin : [https://ssup2.github.io/blog-software/docs/theory-analysis/kubernetes-nvidia-device-plugin/](https://ssup2.github.io/blog-software/docs/theory-analysis/kubernetes-nvidia-device-plugin/)

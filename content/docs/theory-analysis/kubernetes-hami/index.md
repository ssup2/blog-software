---
title: Kubernetes HAMi
draft: true
---

## 1. Kubernetes HAMi

{{< figure caption="[Figure 1] HAMi Architecture" src="images/hami-architecture.png" width="900px" >}}

**HAMi** (Heterogeneous AI Computing Virtualization Middleware)는 Kubernetes 환경에서 GPU를 가상화하여 하나의 GPU를 다수의 Pod이 공유할 수 있도록 하는 CNCF의 Middleware이다. NVIDIA Device Plugin의 Time-slicing 기법도 하나의 GPU를 다수의 Pod에 할당할 수 있지만 Container별 Memory 크기 제한이나 연산 사용률 제한은 제공하지 않는 반면, HAMi는 CUDA API 호출을 가로채는 방식으로 Software Level에서 **vGPU** 단위의 Memory 크기 제한과 SM (Streaming Multiprocessor) 사용률 제한을 제공한다. HAMi는 NVIDIA GPU뿐만 아니라 Ascend NPU, Cambricon MLU, Hygon DCU 같은 다양한 이기종 가속기도 지원하지만, 본 글에서는 NVIDIA GPU를 기준으로 분석한다.

[Figure 1]은 HAMi의 Architecture를 나타내고 있다. HAMi는 다음의 세 가지 Component로 구성된다.

* **hami-scheduler** : Deployment를 통해서 동작하며, 하나의 Pod 안에서 kube-scheduler Container와 Scheduler Extender Container가 함께 동작한다. vGPU를 요청하는 Pod의 Scheduler를 hami-scheduler로 변경하는 Mutating Webhook도 Scheduler Extender가 함께 제공한다.
* **hami-device-plugin** : DaemonSet을 통해서 GPU Node에서 동작하며, 하나의 Pod 안에서 vGPU를 kubelet에 등록하고 할당하는 Device Plugin Container와 vGPU의 사용량을 Metric으로 노출하는 vGPU Monitor Container가 함께 동작한다.
* **HAMi-core** : Container 내부에 주입되는 `libvgpu.so` Library이며, CUDA Driver API 호출을 가로채서 vGPU의 Memory 크기 제한과 SM 사용률 제한을 수행한다.

{{< table caption="[Table 1] HAMi가 제공하는 vGPU Resource 종류" >}}
| Resource | 용도 |
|---|---|
| `nvidia.com/gpu` | Container에 할당할 vGPU의 개수 |
| `nvidia.com/gpumem` | 각 vGPU에 할당할 Memory의 크기 (MB 단위) |
| `nvidia.com/gpumem-percentage` | 물리 GPU Memory 대비 각 vGPU에 할당할 Memory의 비율 (%) |
| `nvidia.com/gpucores` | 각 vGPU가 이용할 수 있는 SM 사용률 (%) |
{{< /table >}}

[Table 1]은 HAMi가 제공하는 vGPU Resource의 종류를 나타내고 있다. NVIDIA Device Plugin과 동일하게 `nvidia.com/gpu` Resource로 GPU의 개수를 요청하지만, HAMi에서는 물리 GPU가 아닌 vGPU의 개수를 의미한다. `nvidia.com/gpumem` 또는 `nvidia.com/gpumem-percentage` Resource로 vGPU의 Memory 크기를 요청하며, `nvidia.com/gpucores` Resource로 vGPU의 SM 사용률을 요청한다.

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

### 1.1. vGPU 등록 과정

{{< figure caption="[Figure 2] vGPU Registration Process" src="images/hami-vgpu-registration.png" width="650px" >}}

hami-device-plugin의 첫 번째 역할은 Node에 존재하는 GPU를 vGPU로 부풀려서 Kubernetes에 등록하는 역할이다. [Figure 2]는 vGPU 등록 과정을 나타내고 있다.

1. hami-device-plugin이 DaemonSet을 통해서 GPU Node에서 동작을 시작하며, NVML (NVIDIA Management Library)을 통해서 Node에 존재하는 GPU의 UUID, Memory 크기, Core 개수, Type 정보를 파악한다.
2. hami-device-plugin은 kubelet의 Device Plugin Unix Domain Socket을 통해서 `Register()` gRPC 요청을 전송하여 자신을 kubelet에 등록한다.
3. kubelet은 hami-device-plugin에게 `ListAndWatch()` gRPC 요청을 전송하여 GPU 목록을 수신한다. 이때 hami-device-plugin은 물리 GPU의 개수를 `deviceSplitCount` 설정의 배수만큼 부풀려서 전달한다. 예를 들어 물리 GPU가 4개 존재하고 `deviceSplitCount`가 10으로 설정되어 있으면 40개의 GPU가 전달되며, 하나의 물리 GPU를 최대 10개의 Container에 할당할 수 있다는 의미가 된다.
4. kubelet은 전달받은 GPU 개수를 Node의 Allocatable/Capacity에 `nvidia.com/gpu` Type으로 등록한다.
5. hami-device-plugin은 Device Plugin 규격과 별도로 물리 GPU의 상세 정보를 Node의 `hami.io/node-nvidia-register` Annotation에 기록한다.

kubelet의 Device Plugin 규격은 Device의 개수와 ID만 전달할 수 있기 때문에, GPU의 Memory 크기 같은 상세 정보는 Device Plugin 규격으로는 전달할 수 없다. 따라서 hami-device-plugin은 물리 GPU의 상세 정보를 Node의 `hami.io/node-nvidia-register` Annotation에 별도로 기록하며, 이후 Scheduler Extender가 이 Annotation을 참조하여 vGPU Scheduling을 수행한다. Annotation은 주기적으로 갱신되기 때문에 Node의 GPU 상태 변화도 Scheduler Extender에 반영된다.

### 1.2. vGPU Scheduling 과정

{{< figure caption="[Figure 3] vGPU Scheduling Process" src="images/hami-vgpu-scheduling.png" width="650px" >}}

NVIDIA Device Plugin 환경에서는 Node 선택은 kube-scheduler가 수행하고 GPU 선택은 Device Plugin이 수행하지만, HAMi 환경에서는 hami-scheduler가 Node 선택뿐만 아니라 GPU 선택까지 수행한다. vGPU의 Memory 크기와 SM 사용률 조건을 만족하는 GPU를 선택하기 위해서는 Node 전체의 GPU 할당 상태를 알아야 하기 때문이다. [Figure 3]은 vGPU Scheduling 과정을 나타내고 있다.

1. Kubernetes Client는 Pod의 Resource에 vGPU Resource를 명시하여 vGPU Pod를 생성한다.
2. hami-scheduler의 Mutating Webhook은 vGPU Resource를 요청하는 Pod를 감지하고, Pod의 `schedulerName`을 `hami-scheduler`로 변경하여 hami-scheduler가 해당 Pod의 Scheduling을 담당하도록 설정한다.
3. hami-scheduler 내부의 kube-scheduler는 vGPU Pod의 Scheduling을 시작하며, Filter/Score 단계에서 HTTP 기반의 Scheduler Extender를 호출한다.
4. Scheduler Extender는 각 Node의 `hami.io/node-nvidia-register` Annotation에 기록된 GPU 정보와 기존 vGPU 할당 내역을 기반으로, 요청 조건을 만족하는 GPU가 존재하는 Node를 선별하고 Scheduling 정책에 따라 점수를 계산한다.
5. Scheduler Extender는 선택된 GPU의 UUID와 Memory 크기, SM 사용률 제한 값을 Pod의 `hami.io/vgpu-devices-allocated` Annotation에 기록하고, Pod를 선택된 Node에 Bind한다.

Scheduling 정책은 Node를 선택하는 Node Scheduling 정책과 Node 안에서 GPU를 선택하는 GPU Scheduling 정책으로 구분되며, 각각 `binpack`과 `spread` 정책을 이용할 수 있다. `binpack` 정책은 이미 할당량이 많은 Node나 GPU에 vGPU를 몰아서 할당하여 GPU 조각을 최소화하는 정책이고, `spread` 정책은 vGPU를 Node나 GPU에 고르게 분산하여 할당하는 정책이다. 기본 정책은 hami-scheduler의 설정으로 지정하며, Pod의 `hami.io/node-scheduler-policy`, `hami.io/gpu-scheduler-policy` Annotation을 통해서 Pod 단위로 변경할 수 있다.

### 1.3. vGPU 할당 과정

{{< figure caption="[Figure 4] vGPU Allocation Process" src="images/hami-vgpu-allocation.png" width="650px" >}}

hami-device-plugin의 두 번째 역할은 hami-scheduler가 선택한 GPU를 실제로 Container에 할당하는 역할이다. [Figure 4]는 vGPU 할당 과정을 나타내고 있다.

1. vGPU Pod가 Bind된 Node의 kubelet은 hami-device-plugin에게 `Allocate()` gRPC 요청을 전송한다.
2. hami-device-plugin은 kube-apiserver를 통해서 해당 Pod의 `hami.io/vgpu-devices-allocated` Annotation을 조회하여, hami-scheduler가 선택한 GPU의 UUID와 Memory 크기, SM 사용률 제한 값을 파악한다. NVIDIA Device Plugin은 `Allocate()` 요청에 포함된 Device ID만으로 동작하지만, hami-device-plugin은 hami-scheduler의 GPU 선택 결과를 그대로 따라야 하기 때문에 Pod의 Annotation을 참조한다.
3. hami-device-plugin은 `Allocate()` 응답으로 할당할 GPU의 UUID가 설정된 `NVIDIA_VISIBLE_DEVICES` 환경 변수, Memory 크기 제한이 설정된 `CUDA_DEVICE_MEMORY_LIMIT` 환경 변수, SM 사용률 제한이 설정된 `CUDA_DEVICE_SM_LIMIT` 환경 변수와 함께, `libvgpu.so` 파일의 Mount 설정과 `libvgpu.so`를 우선 Load하는 `LD_PRELOAD` 환경 변수를 반환한다.
4. kubelet은 반환받은 환경 변수와 Mount 설정을 반영하여 NVIDIA Container Toolkit을 통해서 Container를 생성한다.

### 1.4. Memory, SM 사용률 제한

{{< figure caption="[Figure 5] HAMi-core Isolation" src="images/hami-core-isolation.png" width="700px" >}}

vGPU의 Memory 크기 제한과 SM 사용률 제한은 Container 내부의 HAMi-core (`libvgpu.so`)가 수행한다. [Figure 5]는 HAMi-core의 제한 동작을 나타내고 있다. `libvgpu.so`는 `LD_PRELOAD` 환경 변수를 통해서 CUDA Library보다 먼저 Load되기 때문에, App이 호출하는 CUDA Driver API는 실제 CUDA Library에 전달되기 전에 `libvgpu.so`를 거치게 된다.

Memory 크기 제한은 Memory 할당 API를 가로채서 수행된다. `libvgpu.so`는 `cuMemAlloc()` 같은 Memory 할당 함수가 호출될 때마다 Container의 GPU Memory 사용량을 추적하며, 사용량이 `CUDA_DEVICE_MEMORY_LIMIT` 환경 변수에 설정된 제한을 초과하면 CUDA의 OOM (Out of Memory) Error를 반환한다. 또한 `cuMemGetInfo()` 같은 Memory 조회 함수는 물리 GPU의 Memory 크기 대신 vGPU의 Memory 크기를 반환하도록 가로채지기 때문에, App과 `nvidia-smi` 명령어는 vGPU의 Memory 크기를 전체 Memory 크기로 인식한다.

SM 사용률 제한은 Kernel 실행 API를 가로채서 수행된다. `libvgpu.so`는 GPU의 사용률을 주기적으로 측정하면서 Token 기반으로 Kernel 실행 가능 여부를 관리하며, `cuLaunchKernel()` 같은 Kernel 실행 함수가 호출될 때 Token이 부족하면 Kernel 실행을 지연시켜 vGPU의 SM 사용률을 `CUDA_DEVICE_SM_LIMIT` 환경 변수에 설정된 제한 이하로 유지한다.

Container의 vGPU 사용량 정보는 Container와 hami-device-plugin이 공유하는 Shared Memory Region에 기록된다. hami-device-plugin의 vGPU Monitor는 Shared Memory Region을 주기적으로 읽어서 vGPU의 Memory 사용량과 SM 사용률을 Metric으로 노출하며, 이를 통해서 Container 단위의 GPU 사용량을 모니터링할 수 있다. 이처럼 HAMi의 제한은 CUDA API 가로채기를 통한 Software Level의 제한이기 때문에 별도의 Hardware 지원 없이 모든 NVIDIA GPU에서 이용할 수 있지만, MIG 같은 Hardware Level의 격리보다는 격리 수준이 낮다.

## 2. 참조

* HAMi GitHub : [https://github.com/Project-HAMi/HAMi](https://github.com/Project-HAMi/HAMi)
* HAMi-core GitHub : [https://github.com/Project-HAMi/HAMi-core](https://github.com/Project-HAMi/HAMi-core)
* HAMi Docs : [https://project-hami.io/docs/](https://project-hami.io/docs/)
* Kubernetes NVIDIA Device Plugin : [https://ssup2.github.io/blog-software/docs/theory-analysis/kubernetes-nvidia-device-plugin/](https://ssup2.github.io/blog-software/docs/theory-analysis/kubernetes-nvidia-device-plugin/)

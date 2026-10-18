---
title: Kubernetes HAMi
draft: true
---

## 1. Kubernetes HAMi

{{< figure caption="[Figure 1] HAMi Architecture" src="images/hami-architecture.png" width="900px" >}}

**HAMi** (Heterogeneous AI Computing Virtualization Middleware)는 Kubernetes 환경에서 GPU, NPU 같은 AI 가속기를 가상화하여 하나의 가속기를 다수의 Pod이 공유할 수 있도록 하는 CNCF의 Middleware이다. Kubernetes의 Device Plugin 방식은 가속기를 개수 단위로만 할당할 수 있지만, HAMi는 Device Plugin 방식 위에서 Memory 크기 제한과 연산 Core 사용률 제한을 제공하여 하나의 가속기를 조각 단위로 나누어 할당한다. 2024년에 CNCF Sandbox Project로 채택되었고 2026년 7월에 Incubating Project로 승격되었다.

[Figure 1]은 HAMi의 Architecture를 나타내고 있다. HAMi는 다음의 세 가지 Component로 구성된다.

* **hami-scheduler** : Deployment를 통해서 동작하며, 하나의 Pod 안에서 kube-scheduler Container와 Scheduler Extender Container가 함께 동작한다. 가속기를 요청하는 Pod의 Scheduler를 hami-scheduler로 변경하는 Mutating Webhook도 Scheduler Extender가 함께 제공한다. 모든 종류의 가속기가 하나의 hami-scheduler를 공유하며, 가속기별 Scheduling 동작은 hami-scheduler 내부의 가속기별 Package로 구현되어 있다.
* **Device Plugin** : DaemonSet을 통해서 가속기가 존재하는 Node에서 동작하며, 가속기를 kubelet에 등록하고 Container에 할당하는 역할을 수행한다. NVIDIA GPU용 hami-device-plugin은 HAMi 설치에 포함되어 있고, 그 외의 가속기는 HAMi가 별도로 제공하는 Device Plugin이나 가속기 제조사가 제공하는 Device Plugin을 이용한다.
* **격리 Library** : Container 내부에 주입되는 가속기별 Library이며, 가속기 API 호출을 가로채서 Memory 크기 제한과 Core 사용률 제한을 수행한다. NVIDIA GPU는 CUDA Driver API 호출을 가로채는 HAMi-core (`libvgpu.so`)를 이용한다.

{{< table caption="[Table 1] HAMi가 지원하는 주요 가속기" >}}
| 가속기 | Resource 이름 | Memory / Core 제한 |
|---|---|---|
| NVIDIA GPU | `nvidia.com/gpu`, `nvidia.com/gpumem`, `nvidia.com/gpucores` | O / O |
| Huawei Ascend NPU | `huawei.com/Ascend910B3`, `huawei.com/Ascend910B3-memory` | O / O |
| Cambricon MLU | `cambricon.com/vmlu`, `cambricon.com/mlu.smlu.vmemory`, `cambricon.com/mlu.smlu.vcore` | O / O |
| Hygon HCU | `hygon.com/hcunum`, `hygon.com/hcumem`, `hygon.com/hcucores` | O / O |
| Iluvatar GPU | `iluvatar.ai/MR-V100-vgpu`, `iluvatar.ai/MR-V100.vMem`, `iluvatar.ai/MR-V100.vCore` | O / O |
| Moore Threads GPU | `mthreads.com/vgpu`, `mthreads.com/sgpu-memory`, `mthreads.com/sgpu-core` | O / O |
| MetaX GPU | `metax-tech.com/sgpu`, `metax-tech.com/vmemory`, `metax-tech.com/vcore` | O / O |
| Kunlunxin XPU | `kunlunxin.com/vxpu`, `kunlunxin.com/vxpu-memory` | O / X |
| AWS Neuron | `aws.amazon.com/neuron`, `aws.amazon.com/neuroncore` | X / O |
| AMD GPU | `amd.com/gpu`, `amd.com/gpumem`, `amd.com/gpucores` | O / O |
{{< /table >}}

[Table 1]은 HAMi가 지원하는 주요 가속기와 Resource 이름을 나타내고 있다 (v2.10.0 기준 14종 지원). 각 가속기는 개수를 요청하는 Resource와 함께 Memory 크기, Core 사용률을 요청하는 Resource를 제공하며, hami-scheduler가 인식할 가속기별 Resource 이름은 `hami-scheduler-device` ConfigMap에 정의된다. 격리 방식은 가속기마다 다른데, NVIDIA GPU처럼 Library가 API 호출을 가로채는 방식뿐만 아니라 Ascend NPU의 가상화 Template 방식, Cambricon MLU의 Driver 수준 sMLU 방식도 이용된다.

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

[File 1]은 NVIDIA GPU를 기준으로 3000MB의 Memory와 30%의 SM (Streaming Multiprocessor) 사용률을 갖는 하나의 **vGPU**를 요청하는 Pod의 예제를 나타내고 있다. 본 글에서는 NVIDIA GPU를 예시로 HAMi의 동작을 분석하지만, 등록·Scheduling·할당의 전체 흐름은 모든 가속기가 동일한 구조를 따른다.

### 1.1. Device 등록 과정

{{< figure caption="[Figure 2] Device Registration Process" src="images/hami-device-registration.png" width="650px" >}}

Device Plugin의 첫 번째 역할은 Node에 존재하는 가속기를 부풀려서 Kubernetes에 등록하는 역할이다. [Figure 2]는 NVIDIA GPU를 예시로 Device 등록 과정을 나타내고 있다.

1. Device Plugin이 DaemonSet을 통해서 가속기 Node에서 동작을 시작하며, 가속기의 UUID, Memory 크기, Core 개수, Type 정보를 파악한다 (NVIDIA GPU는 NVML을 이용).
2. Device Plugin은 kubelet의 Device Plugin Unix Domain Socket을 통해서 `Register()` gRPC 요청을 전송하여 자신을 kubelet에 등록한다.
3. kubelet은 Device Plugin에게 `ListAndWatch()` gRPC 요청을 전송하여 가속기 목록을 수신한다. 이때 Device Plugin은 물리 가속기의 개수를 `deviceSplitCount` 설정의 배수만큼 부풀려서 전달한다. 예를 들어 물리 GPU가 4개 존재하고 `deviceSplitCount`가 10으로 설정되어 있으면 40개의 GPU가 전달되며, 하나의 물리 GPU를 최대 10개의 Container에 할당할 수 있다는 의미가 된다.
4. kubelet은 전달받은 가속기 개수를 Node의 Allocatable/Capacity에 등록한다.
5. Device Plugin은 Device Plugin 규격과 별도로 물리 가속기의 상세 정보를 Node Annotation에 기록한다. NVIDIA GPU는 `hami.io/node-nvidia-register` Annotation을 이용하며, 다른 가속기도 `hami.io/node-[가속기]-register` 계열의 Annotation을 이용한다.

kubelet의 Device Plugin 규격은 Device의 개수와 ID만 전달할 수 있기 때문에, 가속기의 Memory 크기 같은 상세 정보는 Device Plugin 규격으로는 전달할 수 없다. 따라서 Device Plugin은 상세 정보를 Node Annotation에 별도로 기록하며, 이후 Scheduler Extender가 이 Annotation을 참조하여 Scheduling을 수행한다. Annotation은 주기적으로 갱신되기 때문에 Node의 가속기 상태 변화도 Scheduler Extender에 반영된다. 한편 Cambricon MLU처럼 제조사의 Device Plugin을 그대로 이용하는 일부 가속기는, Annotation 대신 Node의 Capacity에 등록된 Resource 정보를 Scheduler Extender가 직접 참조한다.

### 1.2. Device Scheduling 과정

{{< figure caption="[Figure 3] Device Scheduling Process" src="images/hami-device-scheduling.png" width="650px" >}}

Device Plugin 방식에서는 Node 선택은 kube-scheduler가 수행하고 가속기 선택은 각 Node의 Device Plugin이 수행하지만, HAMi 환경에서는 hami-scheduler가 Node 선택뿐만 아니라 가속기 선택까지 수행한다. Memory 크기와 Core 사용률 조건을 만족하는 가속기를 선택하기 위해서는 Node 전체의 가속기 할당 상태를 알아야 하기 때문이다. [Figure 3]은 Device Scheduling 과정을 나타내고 있다.

1. Kubernetes Client는 Pod의 Resource에 가속기 Resource를 명시하여 Pod를 생성한다.
2. hami-scheduler의 Mutating Webhook은 등록된 모든 가속기 Resource를 검사하여 가속기를 요청하는 Pod를 감지하고, Pod의 `schedulerName`을 `hami-scheduler`로 변경하여 hami-scheduler가 해당 Pod의 Scheduling을 담당하도록 설정한다.
3. hami-scheduler 내부의 kube-scheduler는 Pod의 Scheduling을 시작하며, Filter/Score 단계에서 HTTP 기반의 Scheduler Extender를 호출한다.
4. Scheduler Extender는 각 Node의 Annotation에 기록된 가속기 정보와 기존 할당 내역을 기반으로, 요청 조건을 만족하는 가속기가 존재하는 Node를 선별하고 Scheduling 정책에 따라 점수를 계산한다.
5. Scheduler Extender는 선택된 가속기의 UUID와 Memory 크기, Core 사용률 제한 값을 Pod의 Annotation에 기록하고, Pod를 선택된 Node에 Bind한다. Annotation 이름은 `hami.io/[가속기]-devices-allocated` 패턴을 따르며, NVIDIA GPU는 초기 구현의 이름인 `hami.io/vgpu-devices-allocated`를 유지하고 있다.

Scheduling 정책은 Node를 선택하는 Node Scheduling 정책과 Node 안에서 가속기를 선택하는 Device Scheduling 정책으로 구분되며, 모든 가속기에 공통으로 적용된다. `binpack` 정책은 이미 할당량이 많은 Node나 가속기에 몰아서 할당하여 가속기 조각을 최소화하는 정책이고, `spread` 정책은 Node나 가속기에 고르게 분산하여 할당하는 정책이다. 기본 정책은 Helm 설정으로 지정하며 (Node는 `binpack`, Device는 `spread`가 기본값), Pod의 `hami.io/node-scheduler-policy`, `hami.io/gpu-scheduler-policy` Annotation을 통해서 Pod 단위로 변경할 수 있다.

### 1.3. Device 할당 과정

{{< figure caption="[Figure 4] Device Allocation Process" src="images/hami-device-allocation.png" width="650px" >}}

Device Plugin의 두 번째 역할은 hami-scheduler가 선택한 가속기를 실제로 Container에 할당하는 역할이다. [Figure 4]는 NVIDIA GPU를 예시로 Device 할당 과정을 나타내고 있다.

1. Pod가 Bind된 Node의 kubelet은 Device Plugin에게 `Allocate()` gRPC 요청을 전송한다.
2. Device Plugin은 kube-apiserver를 통해서 해당 Pod의 Annotation을 조회하여, hami-scheduler가 선택한 가속기의 UUID와 Memory 크기, Core 사용률 제한 값을 파악한다. 일반적인 Device Plugin은 `Allocate()` 요청에 포함된 Device ID만으로 동작하지만, HAMi의 Device Plugin은 hami-scheduler의 가속기 선택 결과를 그대로 따라야 하기 때문에 Pod의 Annotation을 참조한다.
3. Device Plugin은 `Allocate()` 응답으로 할당할 가속기 정보와 제한 값이 설정된 환경 변수, 격리 Library의 Mount 설정을 반환한다. NVIDIA GPU의 경우 `NVIDIA_VISIBLE_DEVICES`, `CUDA_DEVICE_MEMORY_LIMIT`, `CUDA_DEVICE_SM_LIMIT` 환경 변수와 `libvgpu.so`를 우선 Load하는 `LD_PRELOAD` 환경 변수가 반환된다.
4. kubelet은 반환받은 환경 변수와 Mount 설정을 반영하여 Container를 생성하고, Container 내부의 격리 Library가 환경 변수의 제한 값에 따라서 Memory 크기 제한과 Core 사용률 제한을 수행한다.

격리 Library의 제한 방식은 가속기마다 다르다. NVIDIA GPU의 HAMi-core는 CUDA Driver API 호출을 가로채는 Software Level의 제한을 수행하고, AMD GPU도 유사하게 `libamvgpu.so` Library를 이용한다. 반면 Ascend NPU는 제조사가 정의한 가상화 Template 단위의 분할을 이용하고, Cambricon MLU는 Driver 수준의 sMLU 기능을 이용하기 때문에 별도의 Library 주입이 필요하지 않다. 이처럼 HAMi는 Scheduling 계층은 공통으로 유지하면서 격리 계층은 가속기별 구현에 위임하는 구조를 갖는다.

## 2. 참조

* HAMi GitHub : [https://github.com/Project-HAMi/HAMi](https://github.com/Project-HAMi/HAMi)
* HAMi Docs : [https://project-hami.io/docs/](https://project-hami.io/docs/)
* HAMi 지원 Device 목록 : [https://project-hami.io/docs/userguide/device-supported](https://project-hami.io/docs/userguide/device-supported)
* CNCF HAMi : [https://www.cncf.io/projects/hami/](https://www.cncf.io/projects/hami/)
* Kubernetes NVIDIA Device Plugin : [https://ssup2.github.io/blog-software/docs/theory-analysis/kubernetes-nvidia-device-plugin/](https://ssup2.github.io/blog-software/docs/theory-analysis/kubernetes-nvidia-device-plugin/)

---
title: Kubernetes HAMi DRA
draft: true
---

## 1. Kubernetes HAMi DRA

{{< figure caption="[Figure 1] HAMi DRA Architecture" src="images/hami-dra-architecture.png" width="900px" >}}

**HAMi DRA**는 HAMi의 vGPU 기능을 Kubernetes의 **DRA** (Dynamic Resource Allocation) 표준 위에서 제공하는 구현이다. Device Plugin 방식의 HAMi는 GPU의 상세 정보를 Node Annotation에 기록하고 Scheduler Extender를 통해서 vGPU Scheduling을 수행하는 우회 구현을 이용하지만, HAMi DRA는 GPU의 Memory 크기와 SM (Streaming Multiprocessor) 사용률을 DRA의 **Consumable Capacity**로 표현하여 kube-scheduler가 표준 방식으로 vGPU를 할당한다. HAMi v2.8.0에서 도입되었고 v2.9.0부터 NVIDIA GPU 기준으로 이용 가능한 상태가 되었으며, v2.10.0부터는 HAMi 본체와 분리된 별도의 Helm Chart로 설치된다.

[Figure 1]은 HAMi DRA의 Architecture를 나타내고 있다. HAMi DRA는 다음의 Component로 구성된다.

* **hami-dra-driver** : DaemonSet을 통해서 GPU Node에서 동작하는 DRA Driver이다. 물리 GPU를 공유 가능한 Device로 ResourceSlice에 게시하고, kubelet의 요청에 따라서 HAMi-core 주입 설정을 포함한 CDI Spec을 생성한다.
* **hami-dra-webhook** : Device Plugin 방식의 vGPU Resource를 요청하는 Pod를 감지하여 해당 요청을 ResourceClaim으로 변환하는 Mutating Webhook이다. 기존 HAMi 사용자가 Pod Manifest의 수정 없이 DRA 방식으로 전환할 수 있도록 지원한다.
* **hami-dra-monitor** : Container 단위의 vGPU 할당 현황을 Metric으로 노출한다.
* **HAMi-core** : Container 내부에 주입되는 `libvgpu.so` Library이며, Device Plugin 방식과 동일하게 CUDA Driver API 호출을 가로채서 vGPU의 Memory 크기 제한과 SM 사용률 제한을 수행한다.

{{< table caption="[Table 1] HAMi DRA Device의 Consumable Capacity 종류" >}}
| Capacity | 용도 |
|---|---|
| `cores` | 각 vGPU가 이용할 수 있는 SM 사용률 (%). 물리 GPU마다 100의 총량을 가짐 |
| `memory` | 각 vGPU에 할당할 Memory의 크기. 물리 GPU마다 물리 Memory 크기만큼의 총량을 가짐 |
{{< /table >}}

[Table 1]은 HAMi DRA Driver가 각 GPU Device에 정의하는 Consumable Capacity의 종류를 나타내고 있다. Consumable Capacity는 하나의 Device를 다수의 ResourceClaim이 나누어 할당받을 수 있도록 Device의 용량을 소모 가능한 형태로 표현하는 DRA의 기능이며, `DRAConsumableCapacity` Feature Gate를 통해서 Kubernetes 1.34에 Alpha로 도입되었다. Device Plugin 방식에서 `nvidia.com/gpumem`, `nvidia.com/gpucores` Resource로 요청하던 값이 HAMi DRA에서는 Device Capacity에 대한 요청으로 표현된다.

```yaml {caption="[File 1] vGPU를 요청하는 ResourceClaim과 Pod 예제", linenos=table}
apiVersion: resource.k8s.io/v1
kind: ResourceClaim
metadata:
  name: vgpu-claim
  namespace: vgpu-namespace
spec:
  devices:
    requests:
    - name: vgpu
      exactly:
        deviceClassName: hami-core-gpu.project-hami.io
        allocationMode: ExactCount
        count: 1
        capacity:
          requests:
            cores: 30
            memory: 3000Mi
---
apiVersion: v1
kind: Pod
metadata:
  name: vgpu-pod
  namespace: vgpu-namespace
spec:
  containers:
  - name: cuda
    image: nvidia/cuda:12.4.0-base-ubuntu22.04
    command: ["sleep", "infinity"]
    resources:
      claims:
      - name: vgpu
  resourceClaims:
  - name: vgpu
    resourceClaimName: vgpu-claim
```

[File 1]은 3000MB의 Memory와 30%의 SM 사용률을 갖는 하나의 vGPU를 요청하는 ResourceClaim과 Pod의 예제를 나타내고 있다. `deviceClassName`에는 HAMi DRA Driver가 제공하는 DeviceClass인 `hami-core-gpu.project-hami.io`를 명시하고, `capacity.requests`에는 vGPU의 SM 사용률과 Memory 크기를 명시한다. Device Plugin 방식의 HAMi는 Pod의 Resource에 Extended Resource를 명시하여 vGPU를 요청하지만, HAMi DRA는 별도의 Resource 정의 없이 DRA의 표준 Resource API만으로 vGPU를 요청한다.

### 1.1. vGPU 등록 과정

{{< figure caption="[Figure 2] vGPU Registration Process" src="images/hami-dra-vgpu-registration.png" width="650px" >}}

hami-dra-driver의 첫 번째 역할은 Node에 존재하는 GPU를 공유 가능한 Device로 Kubernetes에 등록하는 역할이다. [Figure 2]는 vGPU 등록 과정을 나타내고 있다.

1. hami-dra-driver가 DaemonSet을 통해서 GPU Node에서 동작을 시작하며, NVML (NVIDIA Management Library)을 통해서 Node에 존재하는 GPU의 UUID, Memory 크기, 제품명 같은 속성을 파악한다.
2. hami-dra-driver는 kubelet의 Plugin Registration 경로에 Unix Domain Socket을 생성하여 자신을 kubelet의 Plugin으로 등록한다. 이후 kubelet은 이 Socket을 통해서 Device 준비를 요청한다.
3. hami-dra-driver는 물리 GPU마다 하나의 Device로 구성된 ResourceSlice를 kube-apiserver에 게시한다. 각 Device에는 다수의 ResourceClaim이 할당될 수 있도록 `allowMultipleAllocations`가 설정되며, Consumable Capacity로 `cores`와 `memory`가 함께 게시된다.

Device Plugin 방식의 HAMi는 공유를 표현하기 위해서 물리 GPU의 개수를 `deviceSplitCount` 설정의 배수만큼 부풀려서 등록하고 GPU의 상세 정보는 Node Annotation에 별도로 기록하지만, HAMi DRA는 하나의 물리 GPU를 하나의 Device로 게시한다. GPU의 공유 가능 여부와 남은 용량이 ResourceSlice를 통해서 표준 API로 노출되기 때문에, GPU 개수 부풀리기와 Node Annotation 같은 우회 구현이 필요하지 않다.

### 1.2. vGPU Scheduling 과정

{{< figure caption="[Figure 3] vGPU Scheduling Process" src="images/hami-dra-vgpu-scheduling.png" width="650px" >}}

Device Plugin 방식의 HAMi는 vGPU Scheduling을 위해서 전용 hami-scheduler를 이용하지만, HAMi DRA는 별도의 Scheduler 없이 기본 kube-scheduler가 vGPU Scheduling을 수행한다. [Figure 3]은 vGPU Scheduling 과정을 나타내고 있다.

1. Kubernetes Client는 ResourceClaim을 참조하는 Pod를 생성한다.
2. kube-scheduler의 DynamicResources Plugin은 각 Node의 ResourceSlice에 게시된 Device의 Capacity 총량에서 기존 ResourceClaim들이 할당받은 양을 차감하여 GPU별 잔여 Capacity를 계산하고, 요청한 `cores`와 `memory`를 수용할 수 있는 GPU가 존재하는 Node를 선별한다.
3. 선택된 GPU와 Capacity 할당량은 ResourceClaim의 `status.allocation`에 기록되고, Pod는 선택된 Node에 Bind된다.

Device Plugin 방식에서 Scheduler Extender가 Node Annotation을 참조하며 수행하던 GPU별 잔여 Memory 계산을, HAMi DRA에서는 kube-scheduler의 DynamicResources Plugin이 Consumable Capacity를 통해서 직접 수행한다. 따라서 Pod의 `schedulerName`을 변경하는 과정이 없으며, Volcano나 Kueue 같은 DRA를 지원하는 다른 Scheduler와도 별도의 연동 작업 없이 함께 이용할 수 있다.

```yaml {caption="[File 2] Device Plugin 방식의 vGPU Resource를 이용하는 Pod 예제", linenos=table}
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

hami-dra-webhook은 [File 2]와 같이 Device Plugin 방식의 vGPU Resource를 명시한 Pod가 생성되면, Pod가 생성되는 시점에 해당 요청을 ResourceClaim으로 변환한다. `nvidia.com/gpu`는 요청할 Device의 개수로, `nvidia.com/gpumem`은 `memory` Capacity 요청으로, `nvidia.com/gpucores`는 `cores` Capacity 요청으로 변환된다. 따라서 기존 HAMi 사용자는 Pod Manifest를 수정하지 않고 HAMi DRA로 전환할 수 있다.

한편 Device의 Capacity 관리 주체가 다르기 때문에 Device Plugin 방식의 HAMi와 HAMi DRA를 하나의 Kubernetes Cluster에서 함께 운용하면, 동일한 GPU의 용량을 Scheduler Extender와 kube-scheduler가 각각 관리하여 중복 할당이 발생할 수 있다. 또한 hami-scheduler가 제공하던 `binpack`, `spread` Scheduling 정책과 GPU Topology 기반의 배치는 kube-scheduler의 표준 동작에 존재하지 않기 때문에 HAMi DRA에서는 이용할 수 없다.

### 1.3. vGPU 할당 과정

{{< figure caption="[Figure 4] vGPU Allocation Process" src="images/hami-dra-vgpu-allocation.png" width="650px" >}}

hami-dra-driver의 두 번째 역할은 kube-scheduler가 할당한 vGPU를 Container에서 이용할 수 있도록 준비하는 역할이다. [Figure 4]는 vGPU 할당 과정을 나타내고 있다.

1. vGPU Pod가 Bind된 Node의 kubelet은 Pod를 생성하기 전에 hami-dra-driver에게 `NodePrepareResources()` gRPC 요청을 전송한다.
2. hami-dra-driver는 ResourceClaim의 `status.allocation`을 조회하여 할당된 GPU의 UUID와 Memory 크기, SM 사용률 요청량을 파악한다.
3. hami-dra-driver는 Memory 크기 제한이 설정된 `CUDA_DEVICE_MEMORY_LIMIT` 환경 변수와 SM 사용률 제한이 설정된 `CUDA_DEVICE_SM_LIMIT` 환경 변수, `libvgpu.so` 파일과 `/etc/ld.so.preload` 파일의 Mount 설정이 담긴 CDI Spec을 생성하고, kubelet에게 CDI Device ID를 반환한다.
4. kubelet은 CDI Device ID를 CRI를 통해서 Container Runtime에 전달하고, Container Runtime은 CDI Spec에 명시된 환경 변수와 Mount를 Container에 주입하여 Container를 생성한다.

Device Plugin 방식의 HAMi는 `Allocate()` 응답의 환경 변수와 `LD_PRELOAD` 환경 변수를 통해서 HAMi-core를 주입하지만, HAMi DRA는 CDI 표준을 통해서 주입하며 `LD_PRELOAD` 환경 변수 대신 `/etc/ld.so.preload` 파일을 Mount하여 `libvgpu.so`가 CUDA Library보다 먼저 Load되도록 한다. Container 내부에서 HAMi-core가 CUDA Driver API 호출을 가로채서 vGPU의 Memory 크기 제한과 SM 사용률 제한을 수행하는 동작은 Device Plugin 방식과 동일하다.

### 1.4. Device Plugin 방식 비교

{{< table caption="[Table 2] HAMi Device Plugin 방식, HAMi DRA 비교" >}}
| 구분 | HAMi (Device Plugin) | HAMi DRA |
|---|---|---|
| vGPU 표현 | 부풀려진 GPU 개수 + Node Annotation | ResourceSlice의 Device와 Consumable Capacity |
| vGPU 요청 | Extended Resource (`nvidia.com/gpumem` 등) | ResourceClaim의 Capacity 요청 |
| Scheduling | hami-scheduler의 Scheduler Extender | kube-scheduler의 DynamicResources Plugin |
| 할당 결과 전달 | Pod Annotation + `Allocate()` 환경 변수 | ResourceClaim의 `status.allocation` + CDI |
| Scheduling 정책 | `binpack`, `spread`, GPU Topology 기반 배치 | kube-scheduler의 표준 동작 |
| 요구 버전 | 제약 없음 | Kubernetes 1.34 이상 + `DRAConsumableCapacity` Feature Gate |
{{< /table >}}

[Table 2]는 Device Plugin 방식의 HAMi와 HAMi DRA의 주요 차이점을 나타내고 있다. Node Annotation과 Scheduler Extender를 통한 우회 구현이 DRA의 표준 기능으로 대체되는 반면, vGPU의 Memory 크기 제한과 SM 사용률 제한은 두 방식 모두 HAMi-core가 동일하게 수행한다. NVIDIA GPU 외에는 Ascend NPU용 DRA Driver가 제공되며, 그 외의 가속기는 아직 Device Plugin 방식만 지원하기 때문에 다양한 이기종 가속기를 함께 이용하는 환경에서는 Device Plugin 방식이 권장된다.

## 2. 참조

* HAMi DRA Driver GitHub : [https://github.com/Project-HAMi/k8s-dra-driver](https://github.com/Project-HAMi/k8s-dra-driver)
* HAMi-DRA GitHub : [https://github.com/Project-HAMi/HAMi-DRA](https://github.com/Project-HAMi/HAMi-DRA)
* HAMi DRA 설치 가이드 : [https://project-hami.io/docs/installation/how-to-use-hami-dra](https://project-hami.io/docs/installation/how-to-use-hami-dra)
* Does Kubernetes DRA Replace HAMi? : [https://project-hami.io/blog/does-kubernetes-dra-replace-hami](https://project-hami.io/blog/does-kubernetes-dra-replace-hami)
* Kubernetes DRA Consumable Capacity : [https://kubernetes.io/blog/2025/09/18/kubernetes-v1-34-dra-consumable-capacity/](https://kubernetes.io/blog/2025/09/18/kubernetes-v1-34-dra-consumable-capacity/)
* KEP-5075 DRA Consumable Capacity : [https://github.com/kubernetes/enhancements/tree/master/keps/sig-scheduling/5075-dra-consumable-capacity](https://github.com/kubernetes/enhancements/tree/master/keps/sig-scheduling/5075-dra-consumable-capacity)
* Kubernetes HAMi : [https://ssup2.github.io/blog-software/docs/theory-analysis/kubernetes-hami/](https://ssup2.github.io/blog-software/docs/theory-analysis/kubernetes-hami/)
* Kubernetes HAMi NVIDIA GPU : [https://ssup2.github.io/blog-software/docs/theory-analysis/kubernetes-hami-nvidia-gpu/](https://ssup2.github.io/blog-software/docs/theory-analysis/kubernetes-hami-nvidia-gpu/)
* Kubernetes DRA : [https://ssup2.github.io/blog-software/docs/theory-analysis/kubernetes-dra/](https://ssup2.github.io/blog-software/docs/theory-analysis/kubernetes-dra/)

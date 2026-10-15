---
title: Kubernetes NVIDIA DRA Driver
draft: true
---

## 1. Kubernetes NVIDIA DRA Driver

{{< figure caption="[Figure 1] NVIDIA DRA Driver Architecture" src="images/nvidia-dra-driver-architecture.png" width="900px" >}}

**NVIDIA DRA Driver**는 Kubernetes의 **DRA** (Dynamic Resource Allocation) 표준을 통해서 NVIDIA GPU를 Pod에 할당하는 DRA Driver이다. Device Plugin이 제공하지 못하는 속성 기반의 GPU 선택과 MIG Instance의 동적 생성을 제공하며, Node 간 NVLink 통신을 위한 ComputeDomain도 제공한다. NVIDIA가 개발하여 2026년에 CNCF에 기증했으며, 현재는 kubernetes-sigs의 dra-driver-nvidia-gpu Project로 개발되고 있다.

[Figure 1]은 NVIDIA DRA Driver의 Architecture를 나타내고 있다. NVIDIA DRA Driver는 하나의 Helm Chart로 설치되지만, 내부적으로는 독립적으로 활성화할 수 있는 두 개의 DRA Driver로 구성된다.

* **GPU Driver** (`gpu.nvidia.com`) : DaemonSet의 gpu-kubelet-plugin Container를 통해서 GPU Node에서 동작한다. GPU와 MIG Instance를 ResourceSlice로 게시하고, kubelet의 요청에 따라서 CDI Spec을 생성하여 GPU를 Container에 주입한다.
* **ComputeDomain Driver** (`compute-domain.nvidia.com`) : 같은 DaemonSet의 compute-domain-kubelet-plugin Container와, ComputeDomain Resource를 관리하는 compute-domain-controller Deployment로 구성된다. Node 간 NVLink 통신에 필요한 IMEX Channel을 Pod에 할당한다.

{{< table caption="[Table 1] NVIDIA DRA Driver가 제공하는 DeviceClass 종류" >}}
| DeviceClass | 용도 |
|---|---|
| `gpu.nvidia.com` | 물리 GPU 전체를 요청 |
| `mig.nvidia.com` | MIG Instance를 요청 |
| `vfio.gpu.nvidia.com` | VM Passthrough를 위한 VFIO Device를 요청 |
| `compute-domain-default-channel.nvidia.com` | ComputeDomain의 IMEX Channel을 요청 |
{{< /table >}}

[Table 1]은 NVIDIA DRA Driver가 생성하는 DeviceClass의 종류를 나타내고 있다. Device Plugin에서는 GPU 전체와 MIG Instance가 Extended Resource 이름(`nvidia.com/gpu`, `nvidia.com/gpu-[Profile]`)으로만 구분되지만, NVIDIA DRA Driver에서는 Device의 종류마다 별도의 DeviceClass가 제공되며 ResourceClaim의 CEL Selector를 통해서 세부 조건을 명시한다.

### 1.1. GPU 등록과 속성

{{< table caption="[Table 2] GPU Device의 주요 Attribute, Capacity" >}}
| 구분 | 종류 |
|---|---|
| Attribute | `uuid`, `productName`, `brand`, `architecture`, `cudaComputeCapability`, `driverVersion`, `cudaDriverVersion` |
| 표준 Attribute | `resource.kubernetes.io/pciBusID`, `resource.kubernetes.io/pcieRoot`, `resource.kubernetes.io/numaNode` |
| Capacity | `memory` (MIG를 지원하는 GPU는 `multiprocessors`, `copyEngines`, `decoders`, `encoders` 추가) |
{{< /table >}}

GPU Driver는 NVML (NVIDIA Management Library)을 통해서 파악한 GPU의 속성을 ResourceSlice의 Attribute와 Capacity로 게시한다. [Table 2]는 GPU Device에 게시되는 주요 Attribute와 Capacity를 나타내고 있다. PCI Bus와 NUMA 위치는 `resource.kubernetes.io` 접두어가 붙은 표준 Attribute로 게시되기 때문에, 다른 제조사의 DRA Driver와 공통 형식으로 Device의 Topology를 참조할 수 있다.

```yaml {caption="[File 1] GPU 속성 기반의 ResourceClaimTemplate 예제", linenos=table}
apiVersion: resource.k8s.io/v1
kind: ResourceClaimTemplate
metadata:
  name: a100-gpu
  namespace: gpu-namespace
spec:
  spec:
    devices:
      requests:
      - name: gpu
        exactly:
          deviceClassName: gpu.nvidia.com
          selectors:
          - cel:
              expression: >-
                device.attributes['gpu.nvidia.com'].productName.contains('A100') &&
                device.capacity['gpu.nvidia.com'].memory.isGreaterThan(quantity('40Gi'))
```

[File 1]은 40GB를 초과하는 Memory를 갖는 A100 GPU를 요청하는 ResourceClaimTemplate의 예제를 나타내고 있다. Device Plugin 환경에서는 GPU의 종류를 선택하기 위해서 Node Label과 Node Selector를 통한 Node 단위의 선택만 가능하지만, NVIDIA DRA Driver 환경에서는 ResourceSlice에 게시된 Attribute와 Capacity를 조건으로 GPU 단위의 선택이 가능하다.

### 1.2. GPU 공유

{{< figure caption="[Figure 2] GPU Sharing with Shared ResourceClaim" src="images/nvidia-dra-driver-gpu-sharing.png" width="700px" >}}

[Figure 2]와 같이 하나의 ResourceClaim을 다수의 Container나 Pod가 함께 참조하면 할당된 GPU를 공유한다. 공유 기법은 ResourceClaim의 Opaque Config를 통해서 설정하며, Device Plugin의 Time-slicing/MPS 설정이 ConfigMap과 Node Label을 통해서 Node 단위로 적용되는 것과 다르게 Workload 단위로 적용할 수 있다.

```yaml {caption="[File 2] MPS 공유를 설정하는 ResourceClaimTemplate 예제", linenos=table}
apiVersion: resource.k8s.io/v1
kind: ResourceClaimTemplate
metadata:
  name: shared-gpu
  namespace: gpu-namespace
spec:
  spec:
    devices:
      requests:
      - name: gpu
        exactly:
          deviceClassName: gpu.nvidia.com
      config:
      - requests: ["gpu"]
        opaque:
          driver: gpu.nvidia.com
          parameters:
            apiVersion: resource.nvidia.com/v1beta1
            kind: GpuConfig
            sharing:
              strategy: MPS
              mpsConfig:
                defaultActiveThreadPercentage: 50
```

[File 2]는 MPS 공유를 설정하는 ResourceClaimTemplate의 예제를 나타내고 있다. `opaque.parameters`에는 NVIDIA DRA Driver 전용의 `GpuConfig`를 명시하며, `sharing.strategy`에 `TimeSlicing` 또는 `MPS` 기법을 명시한다. TimeSlicing 기법은 `timeSlicingConfig`를 통해서 시분할 간격을 설정할 수 있고, MPS 기법은 `mpsConfig`를 통해서 Container별 SM 사용 비율과 Memory 크기 제한을 설정할 수 있다. 시분할 간격 설정은 `TimeSlicingSettings`, MPS 기법은 `MPSSupport` Feature Gate (Alpha) 활성화가 필요하다.

하나의 ResourceClaim을 참조하는 Workload 간의 공유와 별도로, 서로 다른 ResourceClaim이 하나의 GPU를 나누어 할당받는 공유는 DRA의 Consumable Capacity 기능을 이용하는 `ConsumableShares` Feature Gate (Alpha)를 통해서 지원된다.

### 1.3. MIG Instance 할당

{{< figure caption="[Figure 3] Dynamic MIG Allocation Process" src="images/nvidia-dra-driver-dynamic-mig.png" width="650px" >}}

MIG Instance는 `mig.nvidia.com` DeviceClass를 통해서 요청한다. 기본 동작은 Device Plugin과 동일하게 관리자가 미리 생성한 MIG Instance를 GPU Driver가 시작 시점에 파악하여 ResourceSlice로 게시하는 Static 방식이며, 각 MIG Device에는 Profile을 나타내는 `profile` Attribute (예: `1g.5gb`)와 부모 GPU를 나타내는 `parentUUID` Attribute가 게시된다.

`DynamicMIG` Feature Gate (Alpha)를 활성화하면 GPU Driver는 ResourceClaim의 요청에 따라서 MIG Instance를 동적으로 생성한다. [Figure 3]은 Dynamic MIG 방식의 MIG Instance 할당 과정을 나타내고 있다.

1. GPU Driver는 각 GPU에서 생성 가능한 모든 MIG Profile과 Placement 조합을 아직 존재하지 않는 Device로 ResourceSlice에 게시하고, GPU마다 SM과 Memory Slice의 공유 Counter를 함께 선언한다.
2. kube-scheduler는 MIG Device를 할당할 때마다 공유 Counter의 소비량을 계산하여, 물리적으로 겹치는 MIG Instance가 중복으로 할당되지 않도록 한다.
3. kubelet이 `NodePrepareResources()` gRPC 요청을 전송하면, GPU Driver는 할당된 Profile과 Placement에 맞는 GPU Instance와 Compute Instance를 실제로 생성한다.
4. ResourceClaim이 해제되면 GPU Driver는 생성했던 MIG Instance를 제거한다.

Dynamic MIG 방식은 존재하지 않는 Device의 할당을 표현하기 위해서 Kubernetes의 Partitionable Devices (KEP-4815) 기능을 이용하며, 해당 기능은 Kubernetes 1.36부터 기본 활성화된다. Device Plugin에서는 MIG Instance를 미리 생성해 놓아야 하기 때문에 Workload의 요구에 맞추어 MIG 구성을 변경하기 어렵지만, Dynamic MIG 방식에서는 ResourceClaim의 요청에 따라서 MIG 구성이 동적으로 변경된다. 단 Dynamic MIG가 활성화되면 GPU Driver가 시작하면서 Node에 존재하던 기존 MIG Instance를 제거하기 때문에 주의가 필요하다.

### 1.4. ComputeDomain

{{< figure caption="[Figure 4] ComputeDomain Process" src="images/nvidia-dra-driver-compute-domain.png" width="700px" >}}

**ComputeDomain**은 GB200 NVL72 같은 Multi-Node NVLink 환경에서 Node 간 GPU Memory 공유에 필요한 **IMEX** (Internode Memory Exchange) Daemon과 Channel을 Workload의 수명에 맞추어 관리하는 Resource이다. [Figure 4]는 ComputeDomain의 동작 과정을 나타내고 있다.

1. Kubernetes Client가 ComputeDomain을 생성하면, compute-domain-controller는 ComputeDomain 전용의 IMEX Daemon DaemonSet과 IMEX Channel을 요청하는 ResourceClaimTemplate을 생성한다.
2. Workload Pod는 생성된 ResourceClaimTemplate을 참조하여 IMEX Channel을 요청한다.
3. Workload Pod가 Scheduling된 Node에서 IMEX Daemon이 동작하며, IMEX Daemon들은 서로 연결되어 하나의 IMEX Domain을 구성한다.
4. compute-domain-kubelet-plugin은 IMEX Daemon의 준비 상태를 확인한 다음, IMEX Channel Device File (`/dev/nvidia-caps-imex-channels/channel[N]`)을 Container에 주입한다.

```yaml {caption="[File 3] ComputeDomain과 Workload Pod 예제", linenos=table}
apiVersion: resource.nvidia.com/v1beta1
kind: ComputeDomain
metadata:
  name: compute-domain
  namespace: gpu-namespace
spec:
  channel:
    resourceClaimTemplate:
      name: compute-domain-channel
---
apiVersion: v1
kind: Pod
metadata:
  name: workload-pod
  namespace: gpu-namespace
spec:
  containers:
  - name: cuda
    image: nvidia/cuda:12.4.0-base-ubuntu22.04
    command: ["sleep", "infinity"]
    resources:
      claims:
      - name: channel
  resourceClaims:
  - name: channel
    resourceClaimTemplateName: compute-domain-channel
```

[File 3]은 ComputeDomain과 IMEX Channel을 요청하는 Workload Pod의 예제를 나타내고 있다. ComputeDomain의 `channel.resourceClaimTemplate.name`에는 compute-domain-controller가 생성할 ResourceClaimTemplate의 이름을 명시하고, Workload Pod는 해당 ResourceClaimTemplate을 참조한다. IMEX Daemon은 Cluster 전체에 고정으로 배포되지 않고 Workload Pod가 배치된 Node에만 배치되며, Workload가 종료되면 함께 정리된다. 따라서 ComputeDomain은 Workload의 수명에 바인딩된 임시 NVLink Fabric 추상화로 동작한다.

### 1.5. Device Plugin 비교

{{< table caption="[Table 3] NVIDIA Device Plugin, NVIDIA DRA Driver 비교" >}}
| 구분 | NVIDIA Device Plugin | NVIDIA DRA Driver |
|---|---|---|
| GPU 선택 | 개수 기반 (`nvidia.com/gpu`) | DeviceClass와 CEL Selector 기반 |
| Time-slicing, MPS 설정 | Node 단위 (ConfigMap, Node Label) | Workload 단위 (ResourceClaim의 Opaque Config) |
| MIG Instance | 사전 생성된 Instance만 할당 | Dynamic MIG를 통한 동적 생성 (Alpha) |
| Multi-Node NVLink | 미지원 | ComputeDomain |
| GPU Operator 설치 | ClusterPolicy | GPUCluster |
{{< /table >}}

[Table 3]은 NVIDIA Device Plugin과 NVIDIA DRA Driver의 주요 차이점을 나타내고 있다. GPU Operator는 v26.7부터 GPUCluster Resource를 통해서 NVIDIA DRA Driver의 설치를 지원하며, Device Plugin을 설치하는 ClusterPolicy와는 하나의 Kubernetes Cluster에서 함께 존재할 수 없기 때문에 두 방식 중 하나를 선택해야 한다.

Kubernetes 1.36부터 기본 활성화되는 `DRAExtendedResource` 기능과 DeviceClass의 `extendedResourceName` 설정을 이용하면, 기존의 `nvidia.com/gpu` Extended Resource 요청도 NVIDIA DRA Driver가 처리할 수 있다. 따라서 Device Plugin을 제거해도 기존 Workload의 Manifest를 수정하지 않고 NVIDIA DRA Driver로 전환할 수 있다.

## 2. 참조

* NVIDIA DRA Driver GitHub : [https://github.com/kubernetes-sigs/dra-driver-nvidia-gpu](https://github.com/kubernetes-sigs/dra-driver-nvidia-gpu)
* NVIDIA DRA Driver Docs : [https://dra-driver-nvidia-gpu.sigs.k8s.io/docs/](https://dra-driver-nvidia-gpu.sigs.k8s.io/docs/)
* GPU Operator DRA Driver 설치 : [https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/dra-intro-install.html](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/dra-intro-install.html)
* KEP-4815 DRA Partitionable Devices : [https://github.com/kubernetes/enhancements/tree/master/keps/sig-scheduling/4815-dra-partitionable-devices](https://github.com/kubernetes/enhancements/tree/master/keps/sig-scheduling/4815-dra-partitionable-devices)
* Kubernetes DRA : [https://ssup2.github.io/blog-software/docs/theory-analysis/kubernetes-dra/](https://ssup2.github.io/blog-software/docs/theory-analysis/kubernetes-dra/)
* Kubernetes NVIDIA Device Plugin : [https://ssup2.github.io/blog-software/docs/theory-analysis/kubernetes-nvidia-device-plugin/](https://ssup2.github.io/blog-software/docs/theory-analysis/kubernetes-nvidia-device-plugin/)

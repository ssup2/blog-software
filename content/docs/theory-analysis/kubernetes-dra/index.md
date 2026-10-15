---
title: Kubernetes DRA
draft: true
---

## 1. Kubernetes DRA

{{< figure caption="[Figure 1] DRA Architecture" src="images/dra-architecture.png" width="900px" >}}

**DRA** (Dynamic Resource Allocation)는 GPU 같은 Device를 Pod에 할당하기 위한 Kubernetes의 새로운 표준이며, Kubernetes 1.34에서 GA가 되었다. 기존의 Device Plugin 방식은 Device를 개수로만 표현하기 때문에 Memory 크기 같은 속성 기반의 Device 선택이 불가능하고, Node 선택은 kube-scheduler가 수행하지만 Device 선택은 각 Node의 Device Plugin이 수행하기 때문에 Scheduler가 Device 단위의 배치를 제어할 수 없다. GPU 공유 Middleware인 HAMi가 Node Annotation과 Scheduler Extender를 통해서 이러한 한계를 우회하는 것처럼, Device Plugin 방식의 한계는 별도의 우회 구현을 필요로 했다. DRA는 Device의 속성을 표준 API로 노출하고 Device 할당을 Scheduling 과정에 통합하여 이러한 한계를 해결한다.

[Figure 1]은 DRA의 Architecture를 나타내고 있다. DRA는 다음의 세 가지 Component로 동작한다.

* **DRA Driver** : Device 제조사가 제공하는 Component로 DaemonSet을 통해서 Device가 존재하는 Node에서 동작한다. Node의 Device 목록과 속성을 ResourceSlice로 게시하고, kubelet의 요청에 따라서 Device를 준비하는 역할을 수행한다.
* **kube-scheduler의 DynamicResources Plugin** : ResourceSlice와 Pod가 참조하는 ResourceClaim을 기반으로 Node와 Device를 함께 선택하고, 할당 결과를 ResourceClaim에 기록한다.
* **kubelet** : Pod를 생성하기 전에 DRA Driver에게 Device 준비를 요청하고, 준비된 Device를 **CDI** (Container Device Interface)를 통해서 Container Runtime에 전달한다.

### 1.1. Resource API

{{< table caption="[Table 1] DRA Resource 종류" >}}
| Resource | 용도 |
|---|---|
| `DeviceClass` | Device의 종류를 정의하는 Cluster 범위의 Resource. DRA Driver가 제공 |
| `ResourceSlice` | Node에 존재하는 Device의 목록과 속성, 용량. DRA Driver가 게시 |
| `ResourceClaim` | Device 할당 요청과 할당 결과를 담는 Namespace 범위의 Resource |
| `ResourceClaimTemplate` | Pod마다 ResourceClaim을 자동으로 생성하기 위한 Template |
{{< /table >}}

[Table 1]은 DRA가 `resource.k8s.io` API Group으로 제공하는 Resource의 종류를 나타내고 있다. Device Plugin 방식에서는 Device가 Node의 Allocatable/Capacity에 개수로만 표현되지만, DRA에서는 각 Device의 속성과 용량이 ResourceSlice를 통해서 표준 형식으로 노출되며, Pod는 ResourceClaim을 통해서 원하는 Device의 조건을 명시한다.

```yaml {caption="[File 1] ResourceClaimTemplate을 이용하는 Pod 예제", linenos=table}
apiVersion: resource.k8s.io/v1
kind: ResourceClaimTemplate
metadata:
  name: single-gpu
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
              expression: device.capacity['gpu.nvidia.com'].memory.compareTo(quantity('40Gi')) >= 0
---
apiVersion: v1
kind: Pod
metadata:
  name: gpu-pod
  namespace: gpu-namespace
spec:
  containers:
  - name: cuda
    image: nvidia/cuda:12.4.0-base-ubuntu22.04
    command: ["sleep", "infinity"]
    resources:
      claims:
      - name: gpu
  resourceClaims:
  - name: gpu
    resourceClaimTemplateName: single-gpu
```

[File 1]은 40GB 이상의 Memory를 갖는 하나의 GPU를 요청하는 ResourceClaimTemplate과 Pod의 예제를 나타내고 있다. ResourceClaim의 `deviceClassName`에는 요청할 Device의 종류를 정의한 DeviceClass를 명시하고, `selectors`에는 Device의 속성과 용량을 조건으로 하는 **CEL** (Common Expression Language) 표현식을 명시한다. Pod의 `resourceClaims`에는 이용할 ResourceClaim 또는 ResourceClaimTemplate을 명시하며, Container의 `resources.claims`에는 해당 Container가 이용할 Claim의 이름을 명시한다. 하나의 ResourceClaim을 다수의 Container나 Pod가 함께 참조할 수 있기 때문에, Device Plugin 방식과 다르게 Device 공유도 표준 방식으로 표현할 수 있다.

### 1.2. Device 등록 과정

{{< figure caption="[Figure 2] Device Registration Process" src="images/dra-device-registration.png" width="650px" >}}

DRA Driver의 첫 번째 역할은 Node에 존재하는 Device를 Kubernetes에 등록하는 역할이다. [Figure 2]는 NVIDIA GPU를 기준으로 Device 등록 과정을 나타내고 있다.

1. DRA Driver가 DaemonSet을 통해서 GPU Node에서 동작을 시작하며, NVML (NVIDIA Management Library)을 통해서 Node에 존재하는 GPU의 UUID, Memory 크기, 제품명 같은 속성을 파악한다.
2. DRA Driver는 kubelet의 Plugin Registration 경로에 Unix Domain Socket을 생성하여 자신을 kubelet의 Plugin으로 등록한다. 이후 kubelet은 이 Socket을 통해서 Device 준비를 요청한다.
3. DRA Driver는 파악한 GPU의 목록과 속성, 용량이 담긴 ResourceSlice를 kube-apiserver에 직접 게시한다.

Device Plugin 방식에서는 Device 정보가 kubelet을 거쳐서 Node의 Allocatable/Capacity에 개수로 등록되지만, DRA에서는 DRA Driver가 kubelet을 거치지 않고 Device 단위의 상세 정보를 ResourceSlice로 직접 게시한다. 따라서 kube-scheduler를 포함한 모든 Component가 Device의 속성을 표준 API로 참조할 수 있다.

### 1.3. Device Scheduling 과정

{{< figure caption="[Figure 3] Device Scheduling Process" src="images/dra-device-scheduling.png" width="650px" >}}

DRA에서는 Device 선택이 kube-scheduler의 Scheduling 과정에 통합되어 있다. [Figure 3]은 Device Scheduling 과정을 나타내고 있다.

1. Kubernetes Client는 ResourceClaimTemplate을 참조하는 Pod를 생성한다.
2. kube-controller-manager의 ResourceClaim Controller는 ResourceClaimTemplate을 기반으로 Pod마다 ResourceClaim을 생성한다.
3. kube-scheduler는 Pod의 Scheduling을 시작하며, DynamicResources Plugin이 Scheduling Framework의 Extension Point에서 동작한다.
4. DynamicResources Plugin은 Filter 단계에서 각 Node의 ResourceSlice에 ResourceClaim의 CEL Selector를 평가하여, 요청 조건을 만족하는 Device가 존재하는 Node를 선별하고 할당할 Device를 결정한다.
5. 선택된 Device는 ResourceClaim의 `status.allocation`에 기록되고 Pod는 `status.reservedFor`에 등록되며, 이후 Pod가 Node에 Bind된다.

DRA의 초기 Alpha Version에서는 kube-scheduler가 DRA Driver의 Control Plane Controller와 협상하며 할당을 결정했지만, 할당 속도와 안정성 문제 때문에 GA에서는 Device 속성을 표준 형식으로 공개하는 **Structured Parameters** 방식만 이용된다. Device의 속성이 ResourceSlice에 모두 공개되어 있기 때문에, kube-scheduler는 DRA Driver와의 통신 없이 스스로 Device 할당을 결정할 수 있다.

### 1.4. Device 준비 과정

{{< figure caption="[Figure 4] Device Preparation Process" src="images/dra-device-preparation.png" width="700px" >}}

DRA Driver의 두 번째 역할은 kube-scheduler가 할당한 Device를 Container에서 이용할 수 있도록 준비하는 역할이다. [Figure 4]는 Device 준비 과정을 나타내고 있다.

1. Pod가 Bind된 Node의 kubelet은 Pod를 생성하기 전에 DRA Driver의 kubelet Plugin에게 `NodePrepareResources()` gRPC 요청을 전송한다.
2. DRA Driver는 ResourceClaim의 `status.allocation`을 조회하여 kube-scheduler가 할당한 Device를 파악한다.
3. DRA Driver는 Device 접근에 필요한 Device File, 환경 변수, Mount 정보가 담긴 CDI Spec을 생성하고, kubelet에게 CDI Device ID를 반환한다.
4. kubelet은 CDI Device ID를 CRI를 통해서 Container Runtime에 전달한다.
5. Container Runtime은 CDI Spec에 명시된 Device File, 환경 변수, Mount를 Container에 주입하여 Container를 생성한다.

Pod가 종료되면 kubelet은 `NodeUnprepareResources()` gRPC 요청을 전송하여 DRA Driver가 Device를 정리하도록 한다. Device Plugin 방식에서는 Device 주입 방법이 각 Driver의 구현에 의존하지만, DRA에서는 Container Runtime 표준인 CDI를 통해서 주입되기 때문에 Runtime 전용 설정 없이 일관된 방식으로 Device가 주입된다.

### 1.5. Device Plugin 비교

{{< table caption="[Table 2] Device Plugin, DRA 비교" >}}
| 구분 | Device Plugin | DRA |
|---|---|---|
| Device 표현 | Node Allocatable/Capacity의 개수 | 속성과 용량을 포함한 Device 단위 (ResourceSlice) |
| Device 요청 | Resource 개수 | ResourceClaim의 CEL Selector |
| Device 선택 | Node 선택은 kube-scheduler, Device 선택은 Device Plugin | kube-scheduler가 Node와 Device를 함께 선택 |
| Device 공유 | 불가 (하나의 Device는 하나의 Container 전용) | ResourceClaim 공유로 가능 |
| Device 주입 | Driver 구현에 의존 (환경 변수 등) | CDI 표준 |
{{< /table >}}

[Table 2]는 Device Plugin과 DRA의 주요 차이점을 나타내고 있다. Device Plugin 환경에서 HAMi가 Node Annotation과 Scheduler Extender로 우회 구현했던 속성 기반의 Device 선택과 Scheduler 주도의 Device 할당이, DRA에서는 표준 기능으로 제공되는 것을 확인할 수 있다. NVIDIA도 Device Plugin과 별도로 DRA Driver를 제공하며, MIG Instance의 동적 생성 같은 기능도 DRA Driver를 통해서 지원한다.

## 2. 참조

* Kubernetes Dynamic Resource Allocation : [https://kubernetes.io/docs/concepts/scheduling-eviction/dynamic-resource-allocation/](https://kubernetes.io/docs/concepts/scheduling-eviction/dynamic-resource-allocation/)
* Kubernetes DRA GA Blog : [https://kubernetes.io/blog/2025/08/27/kubernetes-v1-34-dra-updates/](https://kubernetes.io/blog/2025/08/27/kubernetes-v1-34-dra-updates/)
* NVIDIA DRA Driver GitHub : [https://github.com/kubernetes-sigs/dra-driver-nvidia-gpu](https://github.com/kubernetes-sigs/dra-driver-nvidia-gpu)
* Container Device Interface : [https://github.com/cncf-tags/container-device-interface](https://github.com/cncf-tags/container-device-interface)
* Kubernetes NVIDIA Device Plugin : [https://ssup2.github.io/blog-software/docs/theory-analysis/kubernetes-nvidia-device-plugin/](https://ssup2.github.io/blog-software/docs/theory-analysis/kubernetes-nvidia-device-plugin/)

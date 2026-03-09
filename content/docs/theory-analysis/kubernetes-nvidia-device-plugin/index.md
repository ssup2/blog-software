---
title: Kubernetes NVIDIA Device Plugin
draft: true
---

## 1. Kubernetes NVIDIA Device Plugin

{{< figure caption="[Figure 1] NVIDIA Device Plugin Architecture" src="images/nvidia-device-plugin-architecture.png" width="900px" >}}

**Kubernetes NVIDIA Device Plugin**은 Kubernetes 환경에서 NVIDIA GPU를 사용하기 위한 컴포넌트이다. Pod에게 GPU를 할당하기 위해서는 NVIDIA Device Plugin을 Kubernetes Cluster에 설치해야 한다. [Figure 1]은 NVIDIA Device Plugin의 Architecture를 나타내고 있다. NVIDIA Device Plugin은 DaemonSet을 통해서 GPU가 존재하는 Node에서 동작한다. NVIDIA Device Plugin은 GPU를 Kubernetes에 등록하는 역할, GPU를 Pod에 할당하는 역할, GPU의 상태를 확인하는 역할 3가지 역할을 수행한다.

기본적으로 하나의 GPU는 하나의 Container에만 할당되어 동작한다. [Figure 1]에서는 하나의 Host에 4장의 GPU가 존재하며, Pod A의 Container A에는 하나의 GPU가 할당되어 있고 Container B에는 두개의 GPU가 할당되어 있다. 또한 Pod B의 Container C에는 하나의 GPU가 할당되어 있다. 즉 각 GPU는 하나의 Container에만 할당되어 있는것을 확인할 수 있다.

각 Container는 자신에게 할당된 GPU 정보를 `NVIDIA_VISIBLE_DEVICES` 환경 변수를 통해서 파악할 수 있다. 단일 GPU가 Container에게 할당되어 있는 경우에는  `NVIDIA_VISIBLE_DEVICES=GPU-[UUID]` 형태로 환경변수에 할당되며 다수의 GPU가 Container에게 할당되어 있는 경우에는  `NVIDIA_VISIBLE_DEVICES=GPU-[UUID1],GPU-[UUID2],...` 형태로 환경변수에 할당된다. `NVIDIA_VISIBLE_DEVICES` 환경 변수는 CUDA Library/Tool에서 사용하는 환경 변수이기 때문에 App은 별도의 설정 없이 CUDA Library/Tool을 통해서 GPU를 사용할 수 있게 된다.

Pod에게 GPU를 할당하기 위해서는 Pod의 Resource의 Request와 Limit에 동일한 개수의 GPU를 `nvidia.com/gpu` Type으로 설정하면 된다. 반드시 정수값을 설정해야 하며, 소수점 이하 값은 허용되지 않는다. Container A, B, C의 Resource에도 `nvidia.com/gpu` Type으로 GPU 개수가 설정되어 있는것을 확인할 수 있다.

NVIDIA Device Plugin은 동작을 시작하면서 [NVIDIA Container Toolkit](https://github.com/NVIDIA/nvidia-container-toolkit)이 Node에 설치되어 있는지를 검사하며, 만약 설치되어 있지 않으면 NVIDIA Device Plugin은 동작하지 않는다. NVIDIA Container Toolkit은 Container에 GPU를 할당하기 위한 Container Runtime을 제공하는 역할을 수행한다. 이 의미는 GPU Node에 Device Plugin뿐만 아니라 NVIDIA Container Toolkit도 설치되어 있어야 하는것을 의미한다.

### 1.1. GPU Node 등록 과정

{{< figure caption="[Figure 2] GPU Node Registration Process" src="images/nvidia-gpu-registration-process.png" width="600px" >}}

NVIDIA Device Plugin의 첫번째 역할은 Node의 존재하는 GPU 정보 및 상태를 Kubernetes Node의 Allocatable/Capacity에 `nvidia.com/gpu` Type으로 등록하는 역할을 수행한다. [Figure 2]는 GPU Node 등록 과정을 나타내고 있다.

1. NVIDIA Device Plugin이 DaemonSet으로 배포되며 Node에서 동작을 시작하며, Unix Domain Socket(`/var/lib/kubelet/device-plugins/nvidia-gpu.sock`을 통해서 gRPC 서버를 동작시킨다.
2. NVIDIA Device Plugin은 Node의 GPU 정보 및 상태 정보를 파악하기 시작한다.
3. NVIDIA Device Plugin은 kubelet의 Device Plug-in Unix Domain Socket(`/var/lib/kubelet/device-plugins/kubelet.sock`)을 통해서 `Register()` gRPC 요청을 전송하여 자기 자신을 kubelet에 등록한다. 이 과정에서 자신의 Unix Domain Socket 경로(`/var/lib/kubelet/device-plugins/nvidia-gpu.sock`)를 kubelet에게 전달한다.
4. kubelet은 NVIDIA Device Plugin의 `Register()` gRPC 요청을 통해서 받은 Unix Domain Socket 경로(`/var/lib/kubelet/device-plugins/nvidia-gpu.sock`)에 `ListAndWatch()` gRPC 요청을 전송하여 GPU 정보를 요청한다.
5. kubelet은 NVIDIA Device Plugin으로부터 받은 GPU 정보를 바탕으로 Node의 Allocatable/Capacity에 `nvidia.com/gpu` Type으로 GPU 정보를 등록한다.

### 1.2. GPU Pod 할당 과정

{{< figure caption="[Figure 3] GPU Pod Allocation Process" src="images/nvidia-gpu-allocation-process.png" width="600px" >}}

NVIDIA Device Plugin의 두번째 역할은 어떤 GPU를 컨테이너에게 할당할지를 결정하는, GPU Scheduling 역할을 수행한다. [Figure 3]는 GPU Pod 할당 과정을 나타내고 있다.

1. Kubernetes Client는 Pod의 Resource에 `nvidia.com/gpu` Type으로 GPU의 개수를 명시하여 GPU Pod를 생성한다.
2. Kubernetes Scheduler는 GPU Pod가 요청한 수량의 GPU를 제공할 수 있는 Node를 선택하여 해당 Pod를 배치한다.
3. Kubernetes Scheduler로부터 선택된 Node의 kubelet은 GPU Pod에 명시된 GPU의 개수 정보를 수신한다.
4. kubelet은 GPU Pod에 명시된 GPU 개수만큼 NVIDIA Device Plugin에 Allocation() gRPC 요청을 보내 GPU를 할당받는다. 이때 kubelet이 전달받는 GPU 할당 정보는 GPU Pod의 NVIDIA_VISIBLE_DEVICES 환경 변수에 설정될 GPU UUID 배열 형태로 제공된다.
5. kubelet은 할당받은 GPU 정보를 Node에 설치된 NVIDIA Container Toolkit을 통해서 Pod/Container에게 주입한다.

### 1.3. GPU Health Check

### 1.4. GPU Sharing

기본적으로 하나의 GPU는 하나의 Container에만 할당되어 동작한다. 하지만 GPU Sharing 기법을 이용하면 하나의 GPU를 다수의 Container에 할당할 수 있다. NVIDIA GPU Sharing 기법은 Time-slicing, MPS, MIG 3가지 기법이 존재하며, NVIDIA Device Plugin은 이 3가지 기법을 모두 제공한다.

#### 1.4.1. with Time-slicing

{{< figure caption="[Figure 4]  NVIDIA Device Plugin Architecture with Time-slicing" src="images/nvidia-device-plugin-architecture-timeslicing.png" width="1000px" >}}

#### 1.4.2. with MPS (Multi-Process Service)

{{< figure caption="[Figure 5]  NVIDIA Device Plugin Architecture with MPS" src="images/nvidia-device-plugin-architecture-mps.png" width="1100px" >}}

#### 1.4.3. with MIG (Multi-Instance GPU)

{{< figure caption="[Figure 6]  NVIDIA Device Plugin Architecture with MIG" src="images/nvidia-device-plugin-architecture-mig.png" width="1100px" >}}

## 2. 참조

* NVIDIA MIG : [https://toss.tech/article/toss-securities-gpu-mig](https://toss.tech/article/toss-securities-gpu-mig)
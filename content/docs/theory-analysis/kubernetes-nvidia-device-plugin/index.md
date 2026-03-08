---
title: Kubernetes NVIDIA Device Plugin
draft: true
---

## 1. Kubernetes NVIDIA Device Plugin

{{< figure caption="[Figure 1] NVIDIA Device Plugin Architecture" src="images/nvidia-device-plugin-architecture.png" width="900px" >}}

**Kubernetes NVIDIA Device Plugin**은 Kubernetes 환경에서 NVIDIA GPU를 사용하기 위한 컴포넌트이다. Pod에게 GPU를 할당하기 위해서는 NVIDIA Device Plugin을 Kubernetes Cluster에 설치해야 한다. [Figure 1]은 NVIDIA Device Plugin의 Architecture를 나타내고 있다. NVIDIA Device Plugin은 DaemonSet을 통해서 GPU가 존재하는 Node에서 동작한다. NVIDIA Device Plugin은 GPU를 Kubernetes에 등록하는 역할, GPU를 Pod에 할당하는 역할, GPU의 상태를 확인하는 역할 3가지 역할을 수행한다.

기본적으로 하나의 GPU는 하나의 Container에만 할당되어 동작한다. [Figure 1]에서는 하나의 Host에 4장의 GPU가 존재하며, Pod A의 Container A에는 하나의 GPU가 할당되어 있고 Container B에는 두개의 GPU가 할당되어 있다. 또한 Pod B의 Container C에는 하나의 GPU가 할당되어 있다. 즉 각 GPU는 하나의 Container에만 할당되어 있는것을 확인할 수 있다. 

Pod에게 GPU를 할당하기 위해서는 Pod의 Resource의 Request와 Limit에 동일한 개수의 GPU를 `nvidia.com/gpu` Type으로 설정하면 된다. 반드시 정수값을 설정해야 하며, 소수점 이하 값은 허용되지 않는다. Container A, B, C의 Resource에도 `nvidia.com/gpu` Type으로 GPU 개수가 설정되어 있는것을 확인할 수 있다.

### 1.1. GPU Node 등록 과정

{{< figure caption="[Figure 2] GPU Node Registration Process" src="images/nvidia-gpu-registration-process.png" width="600px" >}}

### 1.2. GPU Pod 할당 과정

{{< figure caption="[Figure 3] GPU Pod Allocation Process" src="images/nvidia-gpu-allocation-process.png" width="600px" >}}

### 1.3. GPU Health Check

### 1.4. GPU Sharing

#### 1.4.1. with Time-slicing

{{< figure caption="[Figure 4]  NVIDIA Device Plugin Architecture with Time-slicing" src="images/nvidia-device-plugin-architecture-timeslicing.png" width="1000px" >}}

#### 1.4.2. with MPS (Multi-Process Service)

{{< figure caption="[Figure 5]  NVIDIA Device Plugin Architecture with MPS" src="images/nvidia-device-plugin-architecture-mps.png" width="1100px" >}}

#### 1.4.3. with MIG (Multi-Instance GPU)

{{< figure caption="[Figure 6]  NVIDIA Device Plugin Architecture with MIG" src="images/nvidia-device-plugin-architecture-mig.png" width="1100px" >}}

## 2. 참조

* NVIDIA MIG : [https://toss.tech/article/toss-securities-gpu-mig](https://toss.tech/article/toss-securities-gpu-mig)
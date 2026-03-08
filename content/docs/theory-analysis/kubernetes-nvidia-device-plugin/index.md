---
title: Kubernetes NVIDIA Device Plugin
draft: true
---

## 1. Kubernetes NVIDIA Device Plugin

{{< figure caption="[Figure 1] NVIDIA Device Plugin Architecture" src="images/nvidia-device-plugin-architecture.png" width="900px" >}}

**Kubernetes NVIDIA Device Plugin**은 Kubernetes 환경에서 NVIDIA GPU를 사용하기 위한 컴포넌트이다. Pod에게 GPU를 할당하기 위해서는 NVIDIA Device Plugin을 Kubernetes Cluster에 설치해야 한다. [Figure 1]은 NVIDIA Device Plugin의 Architecture를 나타내고 있다.

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
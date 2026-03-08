---
title: Kubernetes NVIDIA Device Plugin
draft: true
---

## 1. Kubernetes NVIDIA Device Plugin

{{< figure caption="[Figure 1] NVIDIA Device Plugin Architecture" src="images/nvidia-device-plugin-architecture.png" width="900px" >}}

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
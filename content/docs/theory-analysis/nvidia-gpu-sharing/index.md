---
title: NVIDIA GPU Sharing
draft: true
---

## 1. NVIDIA GPU Sharing

GPU Sharing 기법은 다수의 Process가 하나의 GPU를 공유하여 사용하는 기법을 의미한다. 크게 **Time-Slicing**, **MPS**, **MIG** 3가지 기법이 존재한다.

### 1.1. Time-Slicing

### 1.2. MPS (Multi Process Service)

### 1.3. MIG (Multi Instance GPU)

## 2. References

* Time-Slicing, MPS, MIG: [https://stackoverflow.com/questions/78653544/why-use-mps-time-slicing-or-mig-if-nvidias-defaults-have-better-performance](https://stackoverflow.com/questions/78653544/why-use-mps-time-slicing-or-mig-if-nvidias-defaults-have-better-performance)
* NVIDIA GPU Sharing: [https://www.youtube.com/watch?v=IA6u8Jgox5M](https://www.youtube.com/watch?v=IA6u8Jgox5M)
* NVIDIA GPU Sharing: [https://aws.amazon.com/blogs/containers/gpu-sharing-on-amazon-eks-with-nvidia-time-slicing-and-accelerated-ec2-instances/](https://aws.amazon.com/blogs/containers/gpu-sharing-on-amazon-eks-with-nvidia-time-slicing-and-accelerated-ec2-instances/)
* NVIDIA GPU Sharing Benchmark : [https://www.youtube.com/watch?v=nOgxv_R13Dg](https://www.youtube.com/watch?v=nOgxv_R13Dg)
* NVIDIA MPS : [https://docs.nvidia.com/deploy/mps/index.html](https://docs.nvidia.com/deploy/mps/index.html)
* NVIDIA MPS : [https://comsys-pim.tistory.com/10](https://comsys-pim.tistory.com/10)
* NVIDIA MPS : [https://www.databricks.com/kr/blog/scaling-small-llms-nvidia-mps](https://www.databricks.com/kr/blog/scaling-small-llms-nvidia-mps)
* NVIDIA MIG : [https://toss.tech/article/toss-securities-gpu-mig](https://toss.tech/article/toss-securities-gpu-mig)
* NVIDAA MIG Guide : [https://docs.nvidia.com/datacenter/tesla/pdf/MIG_User_Guide.pdf](https://docs.nvidia.com/datacenter/tesla/pdf/MIG_User_Guide.pdf)
* NVIDAA MIG A100 : [https://roychou121.github.io/2020/10/29/nvidia-A100-MIG/](https://roychou121.github.io/2020/10/29/nvidia-A100-MIG/)
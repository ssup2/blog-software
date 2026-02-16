---
title: NVIDIA GPU Sharing
draft: true
---

## 1. NVIDIA GPU Sharing

{{< figure caption="[Figure 1] Example Applications" src="images/example-apps.png" width="900px" >}}

GPU Sharing 기법은 다수의 Process가 하나의 GPU를 공유하여 사용하는 기법을 의미한다. 크게 **Time-Slicing**, **MPS**, **MIG** 3가지 기법이 존재한다. [Figure 1]은 GPU Sharing 기법을 살펴보기 위한 예제 Application들을 나타내고 있다.

### 1.1. Time-Slicing

{{< figure caption="[Figure 2] Time-Slicing Architecture" src="images/time-slicing-architecture.png" width="600px" >}}

{{< figure caption="[Figure 3] Time-Slicing Timeline" src="images/time-slicing-timeline.png" width="1100px" >}}

### 1.2. MPS (Multi Process Service)

{{< figure caption="[Figure 4] MPS before Volta Architecture" src="images/mps-before-volta-architecture.png" width="600px" >}}

{{< figure caption="[Figure 5] MPS before Volta Timeline" src="images/mps-before-volta-timeline.png" width="1100px" >}}

{{< figure caption="[Figure 6] MPS after Volta Architecture" src="images/mps-after-volta-architecture.png" width="600px" >}}

{{< figure caption="[Figure 7] MPS after Volta Timeline" src="images/mps-after-volta-timeline.png" width="1100px" >}}

### 1.3. MIG (Multi Instance GPU)

{{< figure caption="[Figure 8] MIG Architecture" src="images/mig-architecture.png" width="600px" >}}

{{< figure caption="[Figure 9] MIG A100 MIG Profile" src="images/mig-a100-profile.png" width="900px" >}}

{{< figure caption="[Figure 10] MIG Timeline" src="images/mig-timeline.png" width="1100px" >}}

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
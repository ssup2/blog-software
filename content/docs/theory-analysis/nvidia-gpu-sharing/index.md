---
title: NVIDIA GPU Sharing
draft: true
---

## 1. NVIDIA GPU Sharing

GPU Sharing 기법은 다수의 Process가 하나의 GPU를 공유하여 사용하는 기법을 의미한다. 크게 **Time-Slicing**, **MPS**, **MIG** 3가지 기법이 존재한다.

{{< figure caption="[Figure 1] Example Applications" src="images/example-apps.png" width="900px" >}}

[Figure 1]은 GPU Sharing 기법을 살펴보기 위한 예제 Application들을 나타내고 있다. CUDA App A, B, C 3가지의 Application이 존재하며 모두 2개의 CUDA Stream이 존재한다. 즉 최대 2개의 CUDA Kernel을 동시에 실행하도록 구성되어 있다.

CUDA App 내부에서 왼쪽에 위치한 Kernel은 오른쪽에 위치한 Kernel보다 먼저 제출된 Kernel을 의미하며, 길이가 긴 Kernel은 그만큼 더 오래 실행된 Kernel을 의미한다. 예를들어 App A의 경우에는 `A1`, `A2`, `A3` 3개의 Kernel이 먼저 제출되었으며, 이후에 `A4` Kernel이 제출되었다. 또한 `A1`, `A3` Kernel은 `A2`, `A4` Kernel 대비하여 2배정도 오래 실행된 Kernel을 의미한다.

### 1.1. Time-slicing

{{< figure caption="[Figure 2] Time-Slicing Architecture" src="images/time-slicing-architecture.png" width="600px" >}}

**Time-slicing** 기법은 이름에서도 알 수 있는것 처럼 GPU를 **GPU Context Switch**를 통한 시분활을 기반으로 다수의 CUDA Application이 GPU를 공유하여 사용하는 기법을 의미한다. CPU를 시분활하여 다수의 Application이 하나의 CPU를 공유하여 이용하는 것과 유사하다. [Figure 2]는 Time-slicing 기법의 구조를 나타내고 있다. Process의 Context를 Memory (Stack)에 저장하는 것처럼 GPU의 Context는 GPU Memory에 저장된다.

Time-slicing 기법은 가장 기본적인 GPU Sharing 기법이며, CUDA Application은 별도의 Time-slice을 위해서 별도의 Logic을 수정할 필요가 없다. 다수의 CUDA Application이 동시에 GPU에 접근하는 경우 GPU Device Driver와 GPU 내부에서 자동으로 Time-slicing 기법을 적용하여 다수의 CUDA Application이 GPU를 공유하여 사용하게 된다.

{{< figure caption="[Figure 3] Time-Slicing Timeline" src="images/time-slicing-timeline.png" width="1100px" >}}

[Figure 3]은 Time-slicing 기법의 동작 과정을 Timeline 형태로 나타내고 있다. GPU Context Switch 과정을 통해서 SM (Streaming Multiprocessor)가 차례대로 CUDA Application의 Kernel을 실행하는 것을 확인할 수 있다. GPU Context Switch 과정은 CPU Context Switch 과정과 다르게 비싼 비용이 소요되는 작업이다. GPU에 존재하는 수많은 Registry, Shared Memory 때문에 GPU Context의 크기는 일반적으로 수 MB 정도의 크기를 가진다. 따라서 Time-slicing 기법의 가장큰 단점은 GPU Context Switching이 발생하고 이로 인한 성능 저하가 발생한다는 점이다.

GPU Context Switching 과정을 최소화하기 위해서 GPU는 **비선점형 방식**으로 GPU Scheduling을 수행한다. 즉 제출된 Kernel이 모두 처리되기 전까지 다른 Kernel은 실행되지 않는 방식으로 동작한다. [Figure 3]에서도 CUDA App에서 제출한 Kernel이 모두 처리되기 전까지 다른 Kernel은 실행되지 않는 것을 확인할 수 있다. 또한 GPU Memory는 Context Switching과 관계없이 CUDA App이 종료되기 전까지 유지되는 것을 확인할 수 있다.

### 1.2. MPS (Multi Process Service)

{{< figure caption="[Figure 4] MPS before Volta Architecture" src="images/mps-before-volta-architecture.png" width="600px" >}}

**MPS (Multi Process Service)** 기법은 Time-slicing 기법의 Context Switching 비용을 최소화하기 위해서 도입된 기법이다. 시분활 기법이 아닌 공간 분활 기법을 통해서 다수의 CUDA Application이 GPU를 공유하여 사용하는 기법이다. [Figure 4]는 Volta Architecture 이전의 MPS 기법의 구조를 나타내고 있다. MPS 기법을 이용하기 위해서는 **MPS Control** (`nvidia-cuda-mps-control`)과 **MPS Server** (`nvidia-cuda-mps-server`)가 필요하다.

CUDA Application은 GPU에 직접 Kernel을 제출하지 않고, MPS Control을 통해서 MPS Server에 Kernel을 제출한다. MPS Server는 CUDA Application의 Kernel 요청을 모아서 GPU에게 제출한다. 즉 GPU 입장에서는 CUDA Application의 존재를 알지 못하며, MPS Server만 단독으로 GPU를 이용한다라고 생각한다. Volta Architecture 이전에는 다수의 CUDA Application을 대상으로 공간 분활 기법을 제공할수 없었기 때문에, MPS Server를 Proxy Server처럼 활용하여 이와같은 문제를 해결하였다.

{{< figure caption="[Figure 5] MPS before Volta Timeline" src="images/mps-before-volta-timeline.png" width="1100px" >}}

[Figure 5]는 Volta Architecture 이전의 MPS 기법의 동작 과정을 Timeline 형태로 나타내고 있다. 공간 분활 기법인 만큼 모든 Kernel이 동시에 실행되는 것을 확인할 수 있다. MPS 기법을 이용해도 SM의 완전한 격리를 보장할수 없으며, Volta Architecture 이전에는 Memory 격리도 제대로 제공하지 않았었다.

{{< figure caption="[Figure 6] MPS after Volta Architecture" src="images/mps-after-volta-architecture.png" width="600px" >}}

{{< figure caption="[Figure 7] MPS after Volta Timeline" src="images/mps-after-volta-timeline.png" width="1100px" >}}

#### 1.2.1. MPS Server, MPS Control

#### 1.2.2. with Multi GPU

### 1.3. MIG (Multi Instance GPU)

{{< figure caption="[Figure 8] MIG Architecture" src="images/mig-architecture.png" width="600px" >}}

{{< figure caption="[Figure 9] MIG Timeline" src="images/mig-timeline.png" width="1100px" >}}

{{< figure caption="[Figure 10] MIG A100 MIG Profile" src="images/mig-a100-profile.png" width="900px" >}}

#### 1.3.1. with Time-slicing and MPS

{{< figure caption="[Figure 11] MIG with Time-slicing and MPS Architecture" src="images/mig-time-slicing-mps-architecture.png" width="800px" >}}

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
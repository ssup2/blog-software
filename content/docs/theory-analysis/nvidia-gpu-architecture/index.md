---
title: NVIDIA GPU Architecture
draft: true
---

## 1. NVIDIA GPU Architecture

### 1.1. GPU Architecture

{{< figure caption="[Figure 1] NVIDIA H100 GPU Architecture" src="images/nvidia-h100-gpu-architecture.png" width="1100px" >}}

[Figure 1]은 H100 GPU의 Architecture를 나타내고 있다. H100 GPU Chipset 전체에서 시작하여, 주 연산을 담당하는 **SM** (Streaming Multiprocessor) 단계를 거쳐, SM 내부의 **Sub-core**까지 순차적으로 확대하며 Architecture를 단계적으로 보여 준다.

#### 1.1.1. GPU Chipset

* **PCI Express** : GPU는 PCI Express Interface를 통해서 CPU 또는 Network Card와 연결된다. H100 GPU의 경우에는 PCI Express 5.0 Interface를 이용한다.
* **GigaThread Engine** : 수천, 수백개의 GPU Thread를 동시에 생성하고 관리하는 역할을 담당한다. 생성한 GPU Thread를 다수의 SM에 분배하고, 유휴한 SM이 발생하지 않도록 관리한다. 다수의 App이 GPU를 이용하기 위해서 Time-slicing 기법을 이용하는 경우, GPU의 Context Switching을 담당하는 역할도 수행한다. A100 GPU부터 제공되는 MIG (Multi Instance GPU) 기능도 GigaThread Engine를 확장하여 구현되었다.
* **GPC (GPU Processing Cluster)** : SM을 묶는 가장 큰 단위이다. H100 GPU의 경우에는 8개의 GPC가 존재한다.
* **TPC (Texture Processing Clusters)** : GPC 다음으로 SM을 묶는 단위이며, Texture Sampling/Filtering, Vertex Fetch, Tessellation 연산을 담당한다. H100 GPU의 경우에는 하나의 GPC에 8개의 TPC가 존재한다. 또한 하나의 TPC에는 2개의 SM이 존재한다.
* **L2 Cache** : 모든 SM이 공유하여 이용하는 Data Cache의 역할을 수행하며, GPU가 Memory의 접근을 최소화하기 위해 사용된다. H100 GPU의 경우에는 L2 Cache가 2개의 Partition으로 구성되어 있으며, NUMA (Non-Uniform Memory Access) 기반으로 동작하며, 각 Partition당 60MB의 용량을 가진다.
* **Memory Controller** : Memory을 제어하는 역할을 수행한다. H100 GPU의 경우에는 12개의 Memory Controller가 존재하며, 2개의 Memory Controller가 한 쌍을 이루어 1024 Bit Bus를 구성하여 하나의 HBM3를 제어한다.
* **Memory** : GPU의 전역 (Global) 공유 메모리 역할을 수행한다. H100 GPU의 경우에는 HBM3를 이용하며, 최대 6개의 Memory를 가질 수 있다. 각 HBM3마다 16GB의 용량을 가지기 때문에 최대 96GB의 용량을 가질 수 있다.
* **High-speed Hub** : GPU 내부 Bus와 NVLink를 연결하는 Hub 역할을 수행한다.
* **NVLink** : GPU 사이의 데이터를 주고받기 위한 초고속 데이터 전송 채널을 제공한다. H100 GPU의 경우에는 NVLink 4.0를 이용한다.

#### 1.1.2. SM (Streaming Multiprocessor)

* **L1 Instruction Cache** : SM 내부에서 실행되는 GPU Thread의 Instruction을 Caching하는 역할을 수행한다. GPU는 SIMT (Single Instruction Multiple Threads) 구조, 즉 하나의 명령어를 동시에 여러 GPU Thread에서 수행하기 때문에 각 GPU Thread마다 Memory에 접근을 수행하는 경우에는 Memory의 병목이 발생한다. L1 Instruction Cache는 Instruction을 Caching하여 Memory 접근을 최소화하는 역할을 수행한다.
* **Sub-core** : 실제 연산을 수행하는 Core들을 묶는 단위이다. H100 GPU의 경우에는 4개의 Sub-core가 존재한다.
* **Tensor Memory Accelerator** : Memory와 Shared Memory 사이의 Data 전송을 관리하는 역할을 수행한다.
* **L1 Data Cache / Shared Memory** : SM 내부에서 처리되는 Data를 Caching하는 역할을 수행하거나, SM 내부에서 Data 공유를 위한 Shared Memory 역할을 수행한다. H100 GPU의 경우에는 256KB의 용량을 가진다.
* **Texture Units (Tex)** : Texture Sampling, Filtering 연산을 수행한다. H100 GPU의 경우에는 하나의 SM에 4개의 Tex가 존재한다.

#### 1.1.3. Sub-core

* **L0 Instruction Cache** : Sub-core 내부에서 실행되는 GPU Thread의 Instruction을 Cache하는 역할을 수행한다.
* **Warp Scheduler** : **Warp**은 32개의 GPU Thread로 구성된 가장 기본적인 실행 및 스케줄링 단위이며, Warp에 GPU Thread들은 서로 다른 Data를 가지지만 동일한 명령어를 실행한다. Wrap Scheduler는 실행 준비가 완료된 Warp을 선택하고 연산 유닛으로 전달한다. 만약 실행 상태의 Wrap이 중단되어야 하는 경우 다른 실행 준비 상태의 Wrap을 선택하여 연산 유닛에 전달하여, 연산 유닛이 놀지 않도록 관리하는 역할을 수행한다.
* **Dispatch Unit** : Warp Scheduler에서 선택된 Warp을 어느 연산 Unit에 전달할지 결정하는 역할을 수행한다.
* **Register File** : 모든 연산 유닛은 Register File에서 데이터를 읽고, 결과를 Register File에 저장한다.
* **INT32 Core** : 32 Bit Integer 연산을 수행하는 연산 Unit. H100 GPU의 경우에는 하나의 Sub-core에 16개의 INT32 Core가 존재한다.
* **FP32 Core** : 32 Bit Floating Point 연산을 수행하는 연산 Unit. H100 GPU의 경우에는 하나의 Sub-core에 32개의 FP32 Core가 존재한다.
* **FP64 Core** : 64 Bit Floating Point 연산을 수행하는 연산 Unit. H100 GPU의 경우에는 하나의 Sub-core에 16개의 FP64 Core가 존재한다.
* **Tensor Core** : 행렬 연산을 연산 Unit. H100 GPU의 경우에는 하나의 Sub-core에 하나의 Tensor Core가 존재한다.
* **LD/ST Unit** : Memory, Cache로부터 Register File에 Data를 Load하거나, Register File의 Data를 Memory, Cache에 Store하는 역할을 수행한다.
* **SFU (Special Function Unit)** : `exp()`, `sin()`, `cos()`과 같은 초월함수 연산을 수행한는 연산 Unit. H100 GPU의 경우에는 하나의 Sub-core에 4개의 SFU가 존재한다.

### 1.2. GPU Server Architectur의

{{< figure caption="[Figure 2] NVIDIA DGX H100 Server Architecture" src="images/nvidia-dgx-h100-server-architecture.png" width="1100px" >}}

* **Data Cache NVME** :
* **Storage Networking ConnectX-7** :
* **OS NVME** :
* **DGX Networking ConnectX-7** :
* **NVSwitch** :

## 2. 참조

* GPU Architecture: [https://medium.com/ai-insights-cobet/understanding-gpu-architecture-basics-and-key-concepts-40412432812b](https://medium.com/ai-insights-cobet/understanding-gpu-architecture-basics-and-key-concepts-40412432812b)
* NVIDIA GPU Architecture: [https://www.cantech.in/blog/gpu-architecture/](https://www.cantech.in/blog/gpu-architecture/)
* NVIDIA GPU Architecture: [https://www.samsungsds.com/kr/insights/nvidia-gpu-architecture.html](https://www.samsungsds.com/kr/insights/nvidia-gpu-architecture.html)
* NVIDIA Streaming Multiprocessor (SM) : [https://modal.com/gpu-glossary/device-hardware/streaming-multiprocessor](https://modal.com/gpu-glossary/device-hardware/streaming-multiprocessor)
* NVIDIA Warp : [https://secondspot.tistory.com/71](https://secondspot.tistory.com/71)
* NVIDIA NVLink : [https://www.fibermall.com/ko/blog/gpu-pcle-nvlink-nvswitch.htm?srsltid=AfmBOoq5TeDty7COMp_QFG4mxVOYMwSX2kmK5Qgn72xsPj2oAt_psYkT](https://www.fibermall.com/ko/blog/gpu-pcle-nvlink-nvswitch.htm?srsltid=AfmBOoq5TeDty7COMp_QFG4mxVOYMwSX2kmK5Qgn72xsPj2oAt_psYkT)
* NVIDIA NVLink : [https://www.fibermall.com/ko/blog/nvidia-ai-gpu-server-pcie-vs-sxm.htm?srsltid=AfmBOoomtefnOQbNbCA5NNRsbM12jn7Zj2vCSowDdTWkT6isv0IWP3gI](https://www.fibermall.com/ko/blog/nvidia-ai-gpu-server-pcie-vs-sxm.htm?srsltid=AfmBOoomtefnOQbNbCA5NNRsbM12jn7Zj2vCSowDdTWkT6isv0IWP3gI)
* NVIDIA H100 NVLink : [https://developer.nvidia.com/ko-kr/blog/ai-%EB%B0%8F-%EA%B3%A0%EC%84%B1%EB%8A%A5-%EC%BB%B4%ED%93%A8%ED%8C%85%EC%9D%84-%EC%9C%84%ED%95%9C-%EA%B0%80%EC%86%8D-%EC%84%9C%EB%B2%84-%ED%94%8C%EB%9E%AB%ED%8F%BC-nvidia-hgx-h100/](https://developer.nvidia.com/ko-kr/blog/ai-%EB%B0%8F-%EA%B3%A0%EC%84%B1%EB%8A%A5-%EC%BB%B4%ED%93%A8%ED%8C%85%EC%9D%84-%EC%9C%84%ED%95%9C-%EA%B0%80%EC%86%8D-%EC%84%9C%EB%B2%84-%ED%94%8C%EB%9E%AB%ED%8F%BC-nvidia-hgx-h100/)
* NVIDIA H100 Whitepaper : [https://modal-cdn.com/gpu-glossary/gtc22-whitepaper-hopper.pdf](https://modal-cdn.com/gpu-glossary/gtc22-whitepaper-hopper.pdf)
* NVIDIA CUDA Core vs Tensor Core : [https://dreamgonfly.github.io/blog/cuda-cores-vs-tensor-cores/](https://dreamgonfly.github.io/blog/cuda-cores-vs-tensor-cores/)
* NVIDIA DGX H100 Guide : [https://docs.nvidia.com/dgx/dgxh100-user-guide/introduction-to-dgxh100.html](https://docs.nvidia.com/dgx/dgxh100-user-guide/introduction-to-dgxh100.html)
* NVIDIA DGX H100 Guide : [https://www.xdnode.co.kr/product/?bmode=view&idx=167230117](https://www.xdnode.co.kr/product/?bmode=view&idx=167230117)
* NVIDIA DGX A100 Guide : [https://docs.nvidia.com/dgx/dgxa100-user-guide/introduction-to-dgxa100.html](https://docs.nvidia.com/dgx/dgxa100-user-guide/introduction-to-dgxa100.html)
* NVIDIA DGX H100 Architecture : [https://www.hardwarezone.com.sg/pc/components/tech-news-nvidia-h100-gpu-hopper-architecture-building-block-ai-infrastructure-dgx-h100-supercomputer](https://www.hardwarezone.com.sg/pc/components/tech-news-nvidia-h100-gpu-hopper-architecture-building-block-ai-infrastructure-dgx-h100-supercomputer)
* NVIDIA DGX H100 Architecture : [https://www.linkedin.com/pulse/network-computing-how-cluster-128-units-h100-fiberstamp-qkgrc/](https://www.linkedin.com/pulse/network-computing-how-cluster-128-units-h100-fiberstamp-qkgrc/)
* DDR vs GDDR : [https://blog.naver.com/siencia/223773981163](https://blog.naver.com/siencia/223773981163)
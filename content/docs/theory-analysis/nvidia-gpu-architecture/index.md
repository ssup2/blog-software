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
* **TPC (Texture Processing Clusters)** : GPC 다음으로 SM을 묶는 단위이며, Texture Sampling/Filtering, Vertex Fetch, Tessellation 연산을 담당한다. H100 GPU의 경우에는 하나의 GPC에 8개의 TPC가 존재한다.
* **L2 Cache** : 모든 SM이 공유하여 이용하는 Data Cache의 역할을 수행하며, GPU가 HBM (High-Bandwidth Memory)의 접근을 최소화하기 위해 사용된다. H100 GPU의 경우에는 L2 Cache가 2개의 Partition으로 구성되어 있으며, NUMA (Non-Uniform Memory Access) 기반으로 동작하며, 각 Partition당 60MB의 용량을 가진다.
* **Memory Controller** : HBM을 제어하는 Controller 역할을 수행한다.
* **HBM** :
* **High-speed Hub** :
* **NVLink** :

#### 1.1.2. SM (Streaming Multiprocessor)

* **L1 Instruction Cache** :
* **Sub-core** :
* **Tensor Memory Accelerator** :
* **L1 Data Cache** :
* **Tex** : 

#### 1.1.3. Sub-core

* **L0 Instruction Cache** :
* **Warp Scheduler** :
* **Dispatch Unit** :
* **Register File** :
* **INT32 Core** :
* **FP32 Core** :
* **FP64 Core** :
* **Tensor Core** :
* **LD/ST Unit** :
* **SFU (Special Function Unit)** :

### 1.2. GPU Server Architecture

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
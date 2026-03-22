---
title: NVIDIA GPU Architecture
---

## 1. NVIDIA GPU Architecture

### 1.1. GPU Architecture

{{< figure caption="[Figure 1] NVIDIA H100 GPU Architecture" src="images/nvidia-h100-gpu-architecture.png" width="1100px" >}}

[Figure 1] shows the architecture of the H100 GPU. Starting from the **H100 GPU chip** as a whole, it passes through the **SM (Streaming Multiprocessor)** stage that performs the main compute work, then zooms in sequentially to **Sub-cores** inside the SM, presenting the architecture step by step.

#### 1.1.1. GPU Chipset

* **PCI Express** : The GPU connects to the CPU or network card through the PCI Express interface. The H100 GPU uses the PCI Express 5.0 interface.
* **GigaThread Engine** : Responsible for creating and managing thousands or hundreds of GPU threads at the same time. It distributes created GPU threads across multiple SMs and manages them so that idle SMs do not occur. When multiple apps use the GPU via time-slicing, it also handles GPU context switching. The MIG (Multi-Instance GPU) feature available from the A100 GPU onward was also implemented by extending the GigaThread Engine.
* **GPC (GPU Processing Cluster)** : The largest unit that groups SMs. The H100 GPU has 8 GPCs.
* **TPC (Texture Processing Clusters)** : The unit below GPC that groups SMs; it handles texture sampling/filtering, vertex fetch, and tessellation. The H100 GPU has 8 TPCs per GPC. Each TPC contains 2 SMs.
* **L2 Cache** : Acts as a data cache shared by all SMs and is used to minimize GPU access to memory. On the H100 GPU, the L2 cache is split into 2 partitions, operates on a NUMA (Non-Uniform Memory Access) basis, and each partition has 60 MB of capacity.
* **Memory Controller** : Controls memory. The H100 GPU has 12 memory controllers; 2 controllers form a pair to build a 1024-bit bus and control one HBM3 stack.
* **Memory** : Serves as global (shared) GPU memory. The H100 GPU uses HBM3 and can have up to 6 memory stacks. Each HBM3 has 16 GB capacity, for up to 96 GB total.
* **High-speed Hub** : Acts as a hub connecting the internal GPU bus and NVLink.
* **NVLink** : Provides a very high-speed data path for exchanging data between GPUs. The H100 GPU uses NVLink 4.0.

#### 1.1.2. SM (Streaming Multiprocessor)

* **L1 Instruction Cache** : Caches instructions for GPU threads running inside the SM. Because the GPU uses a SIMT (Single Instruction, Multiple Threads) structure—one instruction executed by many GPU threads at once—per-thread memory access would create a memory bottleneck. The L1 instruction cache caches instructions to minimize memory access.
* **Sub-core** : The unit that groups the cores that actually perform computation. The H100 GPU has 4 Sub-cores.
* **Tensor Memory Accelerator** : Manages data movement between memory and shared memory.
* **L1 Data Cache / Shared Memory** : Caches data processed inside the SM or provides shared memory for data sharing inside the SM. On the H100 GPU, it has 256 KB capacity.
* **Texture Units (Tex)** : Perform texture sampling and filtering. The H100 GPU has 4 texture units per SM.

#### 1.1.3. Sub-core

* **L0 Instruction Cache** : Caches instructions for GPU threads running inside the Sub-core.
* **Warp Scheduler** : A **Warp** is the basic execution and scheduling unit made of 32 GPU threads; threads in a warp share the same instruction but operate on different data. The Warp Scheduler selects warps that are ready to run and sends them to execution units. If a running warp must stall, it selects another ready warp and forwards it to the execution units so that execution units stay busy.
* **Dispatch Unit** : Decides which execution unit receives the warp selected by the Warp Scheduler.
* **Register File** : All execution units read operands from the register file and write results back to it.
* **INT32 Core** : Execution unit for 32-bit integer operations. The H100 GPU has 16 INT32 cores per Sub-core.
* **FP32 Core** : Execution unit for 32-bit floating-point operations. The H100 GPU has 32 FP32 cores per Sub-core.
* **FP64 Core** : Execution unit for 64-bit floating-point operations. The H100 GPU has 16 FP64 cores per Sub-core.
* **Tensor Core** : Execution unit for matrix operations. The H100 GPU has one Tensor Core per Sub-core.
* **LD/ST Unit** : Loads data from memory/cache into the register file, or stores data from the register file to memory/cache.
* **SFU (Special Function Unit)** : Execution unit for transcendental functions such as `exp()`, `sin()`, and `cos()`. The H100 GPU has 4 SFUs per Sub-core.

### 1.2. GPU Server Architecture

{{< figure caption="[Figure 2] NVIDIA DGX H100 Server Architecture" src="images/nvidia-dgx-h100-server-architecture.png" width="1100px" >}}

[Figure 2] shows the architecture of the NVIDIA DGX H100 server. Most GPU servers use multiple GPUs configured as a cluster. The DGX H100 server is built in a NUMA (Non-Uniform Memory Access) configuration with 8 H100 GPUs and 2 CPUs.

* **CPU** : There are two Intel CPUs connected to each other via UPI (Ultra Path Interconnect). The CPUs connect directly to DGX Networking ConnectX-7 and the GPUs via PCI Express, and also connect to Data Cache NVME, Storage Networking ConnectX-7, and NVSwitch through a PCI Express switch.
* **Data Cache NVME** : Temporarily caches data fetched from external storage (NFS, Lustre). The DGX H100 server uses four 3.84 TB NVMe drives.
* **Storage Networking Interface** : Network interface for pulling data from external storage into Data Cache NVME. For the H100 GPU, ConnectX-7 is used. ConnectX-7 refers to NVIDIA’s SmartNIC and uses the InfiniBand protocol.
* **OS NVME** : NVMe drives where the operating system is installed. Connected to the first CPU via PCI Express. The DGX H100 server uses two 1.92 TB NVMe drives.
* **100Gbps Ethernet** : Network interface for management and monitoring of the GPU server. Connected to the second CPU via PCI Express.
* **DGX Networking Interface** : Network interface for the DGX network—that is, the data-plane network of the GPU cluster. For the H100 GPU, ConnectX-7 is used. DGX Networking Interface is connected not only to CPUs but also to GPUs via PCI Express so that, in a GPU server cluster, GPUs can access GPU memory on other GPU servers using GPUDirect RDMA (Remote Direct Memory Access) without CPU involvement.
* **NVSwitch** : Acts as a switch to fully (any-to-any) connect GPUs over NVLink. The CPU connects to NVSwitch via PCIe to control it.

## 2. References

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

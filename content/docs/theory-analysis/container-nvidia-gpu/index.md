---
title: Container NVIDIA GPU
---

Container에게 NVIDIA GPU를 할당하는 기법을 분석한다.

## 1. Container NVIDIA GPU

### 1.1. NVIDIA GPU Container Architecture

{{< figure caption="[Figure 1] NVIDIA GPU Container Architecture" src="images/gpu-container-architecture.png" width="900px" >}}

NVIDIA GPU을 Container에게 할당하여 Container가 NVIDIA GPU를 이용할 수 있는 환경을 구성할 수 있다. Docker 19.03 Version에서는 추가된 GPU Opiton (`--gpu`)을 이용하여 Container에게 NVIDIA GPU를 할당할 수 있다. [Figure 1]은 GPU Option을 통해서 NVIDIA GPU 설정이 완료된 Container들을 나타내고 있다. 각 Container는 하나의 GPU 뿐만 아니라 다수의 GPU를 이용할 수 있다. 또한 자신에게만 할당된 Dedicated GPU 뿐만 아니라, 다른 Container와 공유하는 Shared GPU를 이용할 수 있다. 

Container A는 0,1번째 NVIDIA GPU, Container B는 0,2,3번째 NVIDIA GPU, Container C는 3번째 NVIDIA GPU를 이용하고 있다. 0,1,3번째 GPU는 Shared GPU로 이용되고 있으며, 2번째 GPU는 Dedicated GPU로 이용되고 있다. 각 Container는 Docker 기준으로 다음의 명령어를 통해서 생성할 수 있다. 단일 GPU 번호 또는 다수의 GPU 번호를 `,`로 구분하여 `--gpu` Option에 전달하면 된다.

* Container A : `docker run --gpu 0,1 --name a nvidia/cuda:12.4-base-ubuntu22.04`
* Container B : `docker run --gpu 0,2,3 --name b nvidia/cuda:12.4-base-ubuntu22.04`
* Container C : `docker run --gpu 3 --name c nvidia/cuda:12.4-base-ubuntu22.04`

각 Container는 자신에게 할당된 GPU에 접근하기 위한 Device Node File을 갖는다. Shared GPU는 NVIDIA GPU에서 제공하는 **Time-Slicing** 또는 **MPS (Multi Process Service)** 기능을 활용하여 다수의 Container가 하나의 NVIDIA GPU를 공유하여 이용하게 된다.

### 1.2. NVIDIA GPU 할당 과정

Container에게 NVIDIA GPU를 할당하기 위해서 **OCI Runtime Spec의 Prestart Hook** 기능을 적극적으로 활용한다. Prestart Hook은 Container의 Entrypoint Command가 실행되기 전에 실행되는 Command를 의미한다.

{{< figure caption="[Figure 2] NVIDIA GPU Container OCI Runtime Spec" src="images/container-runtime-spec.png" width="900px" >}}

[Figure 2]은 Docker GPU Option을 이용하여 Container를 생성시 생성되는 OCI Runtime Spec을 나타내고 있다. Docker는 GPU Option을 발견하면 OCI Runtime Spec의 Prestart Hook에 `nvidia-container-runtime-hook` CLI를 실행하기 위한 설정 내용이 추가된다. `nvidia-container-runtime-hook` CLI의 Argument는 `prestart`로 고정되며, Container의 환경 변수에는 NVIDIA GPU, CUDA 관련 환경 변수가 추가된다. 예를 들어 `NVIDIA_VISIBLE_DEVICES` 환경 변수의 경우 Container에게 노출될 NVIDIA GPU의 지정하는 환경 변수이다. [Figure 2]의 경우에서는 Docker에서 모든 NVIDIA GPU를 이용하도록 `--gpu all` 설정을 수행하였기 때문에 `NVIDIA_VISIBLE_DEVICES` 환경 변수에도 `all`이 설정된다.

{{< figure caption="[Figure 3] NVIDIA GPU Container Init" src="images/container-init.png" width="900px" >}}

[Figure 3]은 [Figure 2]에 생성된 OCI Runtime Spec을 바탕으로 `runc` CLI가 Container를 생성하고 GPU를 설정하는 과정을 나타내고 있다.

1. `runc` CLI는 Container를 위한 Namespace 생성 및 rootfs을 설정하기 위해 `clone()` System Call을 통해서 Container Init Process를 생성하고, OverlayFS를 통해서 Container의 Root Filesystem을 설정한다.
2. `clone()` System Call을 통해서 생성된 Container Init Process는 FIFO Named Pipe를 통해서 `runc` CLI에게 Prestart Hook을 실행하도록 요청한다.
3. Container Init Process의 요청에 의해서 `runc` CLI는 OCI Runtime Spec의 Prestart Hook의 내용처럼 `nvidia-container-runtime-hook` CLI를 실행한다.
4. `nvidia-container-runtime-hook` CLI는 OCI Runtime Spec 파일의 내용을 바탕으로 Container, NVIDIA GPU 정보를 다시 `nvidia-container-cli` CLI의 Parameter로 넘겨 `nvidia-container-cli` CLI를 실행한다. `nvidia-container-cli` CLI가 Container의 NVIDIA GPU를 실제로 설정하는 주체이고, `nvidia-container-runtime-hook` CLI는 OCI Runtime Spec과 `nvidia-container-cli` CLI 사이를 연결해주는 **Interface 역할**만을 수행한다.
5. `nvidia-container-cli` CLI는 전달받은 정보를 바탕으로 Device Node 파일를 생성하고, 필요에 따라서 NVIDIA GPU 구동을 위한 Kernel Module도 Loading을 수행한다.
6. Prestart Hook 작업이 완료되면 `runc` CLI는 Container Init Process에게 FIFO Named Pipe를 통해서 Prestart Hook 작업 완료 응답을 전달한다.
7. Prestart Hook 작업이 완료를 전달받은 Container Init Process는 `pivot_root()` System Call을 통해서 Container의 Root Filesystem을 실제 Container Root Filesystem으로 변경하고, `exec()` System Call을 통해서 Container의 Entrypoint Command를 실행한다.

```shell {caption="[Shell 1] Device node file list in NVIDIA GPU container"}
$ ls -l /dev
...
crw-rw-rw- 1 root root 510,   0 Feb 11 15:41 nvidia-uvm
crw-rw-rw- 1 root root 510,   1 Feb 11 15:41 nvidia-uvm-tools
crw-rw-rw- 1 root root 195,   0 Feb 11 15:41 nvidia0
crw-rw-rw- 1 root root 195,   1 Feb 11 15:41 nvidia1
crw-rw-rw- 1 root root 195,   2 Feb 11 15:41 nvidia2
crw-rw-rw- 1 root root 195,   3 Feb 11 15:41 nvidia3
crw-rw-rw- 1 root root 195, 255 Feb 11 15:41 nvidiactl
...
```

`runc` CLI가 Prestart Hook 작업을 정상적으로 완료하면 Container 내부에는 NVIDIA GPU에 대한 Device Node 파일이 생성된다. [Shell 1]은 4개의 GPU가 이용 가능한 Container 내부에서의 Device Node 파일 목록을 나타내고 있다.

```shell {caption="[Shell 2] Cgroup device list in host"}
$ ls -l /sys/fs/cgroup/[container_id]/devices/
...
c 195:255 rw # /dev/nvidiactl
c 244:0 rw   # /dev/nvidia-uvm
c 244:1 rw   # /dev/nvidia-uvm-tools
c 195:3 rw   # /dev/nvidia3
c 195:2 rw   # /dev/nvidia2
c 195:1 rw   # /dev/nvidia1
c 195:0 rw   # /dev/nvidia0
...
```

또한 Container 내부에서 GPU 접근을 허용하기 위한 Cgroup도 같이 설정된다. [Shell 2]는 Container 내부에서 GPU 접근을 허용하기 위한 Cgroup의 Device List 예시를 나타내고 있다.

## 2. 참조

* [https://devblogs.nvidia.com/gpu-containers-runtime/](https://devblogs.nvidia.com/gpu-containers-runtime/)
* [https://gitlab.com/nvidia/container-toolkit/toolkit](https://gitlab.com/nvidia/container-toolkit/toolkit)
* [https://gitlab.com/nvidia/container-toolkit/libnvidia-container/](https://gitlab.com/nvidia/container-toolkit/libnvidia-container/)
* [https://github.com/opencontainers/runtime-spec/blob/master/config.md#posix-platform-hooks](https://github.com/opencontainers/runtime-spec/blob/master/config.md#posix-platform-hooks)
* [https://docs.nvidia.com/deploy/pdf/CUDA_Multi_Process_Service_Overview.pdf](https://docs.nvidia.com/deploy/pdf/CUDA_Multi_Process_Service_Overview.pdf)
---
title: NVIDIA GPU Sharing
draft: true
---

## 1. NVIDIA GPU Sharing

GPU Sharing 기법은 다수의 Process가 하나의 GPU를 공유하여 사용하는 기법을 의미한다. 크게 **Time-Slicing**, **MPS**, **MIG** 3가지 기법이 존재한다.

{{< figure caption="[Figure 1] Example Applications" src="images/example-apps.png" width="900px" >}}

[Figure 1]은 GPU Sharing 기법을 살펴보기 위한 예제 Application들을 나타내고 있다. CUDA App A, B, C 3가지의 App이 존재하며 모두 2개의 CUDA Stream이 존재한다. 즉 최대 2개의 CUDA Kernel을 동시에 실행하도록 구성되어 있다.

CUDA App 내부에서 왼쪽에 위치한 Kernel은 오른쪽에 위치한 Kernel보다 먼저 제출된 Kernel을 의미하며, 길이가 긴 Kernel은 그만큼 더 오래 실행된 Kernel을 의미한다. 예를들어 App A의 경우에는 `A1`, `A2`, `A3` 3개의 Kernel이 먼저 제출되었으며, 이후에 `A4` Kernel이 제출되었다. 또한 `A1`, `A3` Kernel은 `A2`, `A4` Kernel 대비하여 2배정도 오래 실행된 Kernel을 의미한다.

### 1.1. Time-slicing

{{< figure caption="[Figure 2] Time-Slicing Architecture" src="images/time-slicing-architecture.png" width="600px" >}}

**Time-slicing** 기법은 이름에서도 알 수 있는것 처럼 **GPU Context Switch**를 통한 **시간 분활**을 기반으로 다수의 CUDA App이 GPU를 공유하여 사용하는 기법을 의미한다. CPU를 시간 분활하여 다수의 App이 하나의 CPU를 공유하여 이용하는 것과 유사하다. [Figure 2]는 Time-slicing 기법의 구조를 나타내고 있다. Process의 Context를 Memory (Stack)에 저장하는 것처럼 GPU의 Context는 GPU Memory에 저장된다.

Time-slicing 기법은 가장 기본적인 GPU Sharing 기법이며, CUDA App은 별도의 Time-slice을 위해서 별도의 Logic을 수정할 필요가 없다. 다수의 CUDA App이 동시에 GPU에 접근하는 경우 GPU Device Driver와 GPU 내부에서 자동으로 Time-slicing 기법을 적용하여 다수의 CUDA App이 GPU를 공유하여 사용하게 된다.

{{< figure caption="[Figure 3] Time-Slicing Timeline" src="images/time-slicing-timeline.png" width="1100px" >}}

[Figure 3]은 Time-slicing 기법의 동작 과정을 Timeline 형태로 나타내고 있다. GPU Context Switch 과정을 통해서 SM (Streaming Multiprocessor)가 차례대로 CUDA App의 Kernel을 실행하는 것을 확인할 수 있다. GPU Context Switch 과정은 CPU Context Switch 과정과 다르게 비싼 비용이 소요되는 작업이다. GPU에 존재하는 수많은 Registry, Shared Memory 때문에 GPU Context의 크기는 일반적으로 수 MB 정도의 크기를 가진다. 따라서 Time-slicing 기법의 가장큰 단점은 GPU Context Switching이 발생하고 이로 인한 성능 저하가 발생한다는 점이다.

GPU Context Switching 과정을 최소화하기 위해서 GPU는 **비선점형 방식**으로 GPU Scheduling을 수행한다. 즉 제출된 Kernel이 모두 처리되기 전까지 다른 Kernel은 실행되지 않는 방식으로 동작한다. [Figure 3]에서도 CUDA App에서 제출한 Kernel이 모두 처리되기 전까지 다른 Kernel은 실행되지 않는 것을 확인할 수 있다. 또한 GPU Memory는 Context Switching과 관계없이 CUDA App이 종료되기 전까지 유지되는 것을 확인할 수 있다.

### 1.2. MPS (Multi Process Service)

**MPS (Multi Process Service)** 기법은 Time-slicing 기법의 Context Switching 비용을 최소화하기 위해서 도입된 기법이다. 시간 분활 기법이 아닌 **공간 분활** 기법을 통해서 다수의 CUDA App이 GPU를 공유하여 사용하는 기법이다. MPS Architecture는 Volta Architecture 이전과 이후로 나뉘어 진다. 또한 MPS 기법을 이용하기 위해서는 **MPS Control** (`nvidia-cuda-mps-control`)과 **MPS Server** (`nvidia-cuda-mps-server`) 두가지 Componant가 추가적으로 필요하다. MPS Control은 MPS Server를 제어하고 관리하기 위한 Componant이다. MPS Server는 Volta Architecture에 이전에는 CUDA Context를 관리하고, Volta Architecture 이후에는 GPU Resource를 중재하는 역할을 수행한다.

#### 1.2.1. MPS before Volta Architecture

{{< figure caption="[Figure 4] MPS before Volta Architecture" src="images/mps-before-volta-architecture.png" width="600px" >}}

[Figure 4]는 Volta Architecture 이전의 MPS 기법의 구조를 나타내고 있다. MPS Control과 MPS Server는 CUDA App 사이에서 별도의 CUDA Context를 생성하고 동기화 하는 역할을 수행한다. 따라서 CUDA App은 GPU에 직접 Kernel과 GPU 관련 설정을 제출하지 않고 MPS Control을 통해서 MPS Server에 제출한다. 단 Data를 GPU에게 전달하는 과정에서는 DMA를 통해서 GPU에 직접 전달한다. GPU 입장에서는 CUDA App의 존재를 알지 못하며, MPS Server만 단독으로 GPU를 이용한다라고 생각한다. Volta Architecture 이전에는 다수의 CUDA App을 대상으로 공간 분활 기법을 제공할수 없었기 때문에, MPS Server를 Proxy Server처럼 활용하여 이와 같은 문제를 해결하였다.

{{< figure caption="[Figure 5] MPS before Volta Timeline" src="images/mps-before-volta-timeline.png" width="1100px" >}}

[Figure 5]는 Volta Architecture 이전의 MPS 기법의 동작 과정을 Timeline 형태로 나타내고 있다. 공간 분활 기법인 만큼 모든 Kernel이 동시에 실행되는 것을 확인할 수 있다. Volta Architecture 이전에 MPS 기법에서는 CUDA App 사이의 SM과 Memory 격리 기능을 제공하지 않았었다. 따라서 특정 CUDA App이 Memory를 침범하는 경우 다른 CUDA App에게 영향을 줄 수 있다.

#### 1.2.2. MPS after Volta Architecture

{{< figure caption="[Figure 6] MPS after Volta Architecture" src="images/mps-after-volta-architecture.png" width="600px" >}}

[Figure 6]는 Volta Architecture 이후의 MPS 기법의 구조를 나타내고 있다. Volta Architecture 이후에는 CUDA App은 GPU에게 직접 Kernel을 제출하는 형태로 변경되었다. 따라서 MPS Control과 MPS Server는 더이상 CUDA App 사이에서 별도의 Context Context를 생성하고 동기화 하지 않는다. 다만 CUDA App은 GPU에 Kernel을 제출하기 전에 MPS Control, MPS Server에게 해당 제출이 다른 CUDA App이 이용하는 GPU Resource와 충돌이 발생하는지 확인하는 과정을 진행한다. 따라서 MPS Control, MPS Server는 CUDA App 사이의 GPU Resource 충돌을 방지하는 중재자 역할을 수행한다.

또한 Volta Architecture 이후에는 CUDA App별로 최대로 사용할 수 있는 SM과 Memory를 지정할 수 있는 기능이 추가되었다. 이로 인해서 CUDA App이 예상하지 못한 SM과 Memory 점유를 방지할 수 있게 되었다. 하지만 최대 사용량을 제한하는 기능만 제공하고, 최소 사용량을 보장하는 기능은 제공하지는 않는다. 따라서 Volta Architecture 이후의 MPS 기법에서도 완전한 Resource 격리를 제공하지는 않는다.

{{< figure caption="[Figure 7] MPS after Volta Timeline" src="images/mps-after-volta-timeline.png" width="1100px" >}}

[Figure 7]은 Volta Architecture 이후의 MPS 기법의 동작 과정을 Timeline 형태로 나타내고 있다. [Figure 5]와 유사하지만 GPU가 MPS의 Context를 관리하지 않고, 각각 CUDA App 단위로 Context를 괸리한다는 점이 다르다.

#### 1.2.3. MPS Control, MPS Server 동작 과정

```shell {caption="[Shell 1] Run MPS Control and MPS Server"}
# Run MPS Control
$ nvidia-cuda-mps-control -d

# Run CUDA App
$ CUDA_VISIBLE_DEVICES=0 python3 mps_worker.py &

# Check MPS Control and MPS Server
$ ps -ef | grep mps
root       21389       1  0 14:37 ?        00:00:00 nvidia-cuda-mps-control -d
root       60374   21389  0 15:00 ?        00:00:01 nvidia-cuda-mps-server
```

MPS Control은 `nvidia-cuda-mps-control` 이름의 Binary를 통해서 실행되며, MPS Control은 최대 동시에 하나의 MPS Server만 실행하며 관리한다. MPS Server는 `nvidia-cuda-mps-server` 이름의 Binary를 통해서 실행된다. MPS Server는 MPS Control이 실행되자마자 바로 생성되지 않으며, CUDA App이 처음 실행될때 MPS Control이 MPS Server를 생성하게 된다.  MPS Control은 최대 동시에 하나의 MPS Server만 실행하며 관리하며, MPS Control은 생성한 MPS Server는 CUDA App이 종료되어도 종료되지 않고 이후에 실행되는 CUDA App에서 재사용한다. [Shell 1]은 MPS Control를 실행하고 CUDA App을 제출하여 MPS Server 까지 실행하는 과정을 나타내고 있다.

MPS Server는 각 Linux User별로 독립적으로 실행되는 특징을 갖는다. 하지만 MPS Control은 최대 동시에 하나의 MPS Server만 관리하기 때문에 서로 다른 Linux User가 동시에 MPS를 통해서 CUDA App을 실행할수 없다. 만약 A Linux User가 MPS를 통해서 CUDA App을 실행하고 있는 경우에 B Linux User가 MPS를 통해서 CUDA App을 실행하려고 하면, A Linux User의 MPS Server는 강제 종료되고 B Linux User의 MPS Server가 생성된다.

MPS Control에 명령어를 전달하기 위해서는 `echo "[command]" | nvidia-cuda-mps-control` 형태로 파이프를 통해서 명령어를 전달하면 된다. 다양한 명령어들이 존재하지만 대표적이 명령어들은 다음과 같다.

* `get_server_list` : MPS Server List를 출력한다.
* `get_server_status <PID>` : 지정한 PID를 갖는 MPS Server의 상태를 출력한다.
* `get_client_list <PID>` : 지정한 PID를 갖는 MPS Server와 연결되어 있는 CUDA App의 PID List를 출력한다.
* `quit` : MPS Control을 종료한다.

Volta Architecture 이후에는 SM, Memory 최대 사용량을 제한하는 다음의 명령어들이 추가로 존재한다.

* `set_default_active_thread_percentage <percentage>` : Default Active Thread Percentage를 설정한다. 여기서 Active Thread Percentage는 CUDA App이 최대로 사용할 수 있는 SM의 대비 사용률을 의미한다. 이미 동작중인 MPS Server에는 영향을 주지 않으며 이후에 새로 실행되는 MPS Server에만 적용된다. 동작중인 MPS Server의 Active Thread Percentage를 변경하고 싶은 경우에는 `set_active_thread_percentage <PID> <percentage>` 명령어를 사용하면 된다.
* `get_default_active_thread_percentage` : Default Active Thread Percentage를 출력한다.
* `set_active_thread_percentage <PID> <percentage>` : 지정한 PID를 갖는 MPS Server의 Active Thread Percentage를 설정한다.
* `get_active_thread_percentage <PID>` : 지정한 PID를 갖는 MPS Server의 Active Thread Percentage를 출력한다.
* `set_default_device_pinned_mem_limit <dev> <value>` : Default Device Pinned Memory Limit를 설정한다. 여기서 Device Pinned Memory Limit는 CUDA App이 최대로 사용할 수 있는 GPU Memory의 크기를 의미한다. 이미 동작중인 MPS Server에는 영향을 주지 않으며 이후에 새로 실행되는 MPS Server에만 적용된다. 동작중인 MPS Server의 Device Pinned Memory Limit를 변경하고 싶은 경우에는 `set_device_pinned_mem_limit <PID> <value>` 명령어를 사용하면 된다.
* `get_default_device_pinned_mem_limit <dev>` : 지정한 Device의 Default Device Pinned Memory Limit를 출력한다.
* `set_device_pinned_mem_limit <PID> <value>` : 지정한 PID를 갖는 MPS Server의 Device Pinned Memory Limit를 설정한다.
* `get_device_pinned_mem_limit <PID>` : 지정한 PID를 갖는 MPS Server의 Device Pinned Memory Limit를 출력한다.

```shell {caption="[Shell 2] MPS Server Files"}
$ ls -l /tmp/nvidia-mps/
total 5
srw-rw-rw-.  1 root root   0 Feb 17 14:37 control
-rw-rw-rw-.  1 root root   0 Feb 17 14:37 control_lock
srwxr-xr-x.  1 root root   0 Feb 17 14:37 control_privileged
prwxrwxrwx.  1 root root   0 Feb 17 15:04 log
-rw-rw-rw-.  1 root root   5 Feb 17 14:37 nvidia-cuda-mps-control.pid

$ lsof +c 0 /tmp/nvidia-mps/*
COMMAND           PID USER   FD   TYPE             DEVICE SIZE/OFF  NODE NAME
nvidia-cuda-mps 17861 root   20wW  REG               0,32        0  4523 /tmp/nvidia-mps/control_lock
nvidia-cuda-mps 17861 root   26u  FIFO               0,32      0t0  4524 /tmp/nvidia-mps/log
nvidia-cuda-mps 17861 root   27w  FIFO               0,32      0t0  4524 /tmp/nvidia-mps/log
nvidia-cuda-mps 17861 root   28u  unix 0x0000000045d7a7b6      0t0 32191 /tmp/nvidia-mps/control_privileged type=SEQPACKET (LISTEN)
nvidia-cuda-mps 17861 root   29u  unix 0x00000000cec7e4ac      0t0 32192 /tmp/nvidia-mps/control type=SEQPACKET (LISTEN)
nvidia-cuda-mps 17861              0,32        0  4523 /tmp/nvidia-mps/control_lockroot   31u  unix 0x00000000a4b1b4c4      0t0 19294 /tmp/nvidia-mps/control type=SEQPACKET (CONNECTED)
nvidia-cuda-mps 21810 root    3w  FIFO               0,32      0t0  4524 /tmp/nvidia-mps/log
nvidia-cuda-mps 21810 root   20w   REG  

$ ps -fp 17861 21810
UID          PID    PPID  C STIME TTY      STAT   TIME CMD
root       17861       1  0 02:47 ?        Ssl    0:00 nvidia-cuda-mps-control -d
root       21810   17861  0 02:56 ?        Sl     0:01 nvidia-cuda-mps-server
```

[Shell 2]는 MPS Control과 MPS Server가 동작하면 생성되는 파일 목록들을 나타내고 있다. 파일 경로는 `CUDA_MPS_PIPE_DIRECTORY` 환경변수를 통해서 설정이 가능하며, 기본 경로는 `/tmp/nvidia-mps/`이다. 각 파일의 역할은 다음과 같다.

* `control` : 일반 사용자용 Unix Domain Socket. `echo "get_server_list" | nvidia-cuda-mps-control` 같은 명령이 이 소켓을 통해 전달됨.
* `control_lock` : `control` 소켓 접근 시 동시성 제어를 위한 Lock 파일.
* `control_privileged` : root/특권 사용자 전용 Unix Domain Socket. `set_default_active_thread_percentage` 같은 관리 명령은 이 소켓을 통해 처리됨.
* `log` : MPS Server의 로그 출력을 위한 Named Pipe. 출력된 Log는 MPS Control가 수신하여 `CUDA_MPS_LOG_DIRECTORY` 환경변수에 설정된 경로에 저장된다. 기본 경로는 `/var/log/nvidia-mps/`이다.
* `nvidia-cuda-mps-control.pid` : 일반 파일, MPS control daemon의 PID가 저장된 파일. 중복 실행 방지 및 프로세스 관리에 사용됨.

CUDA SDK는 기본적으로 `CUDA_MPS_PIPE_DIRECTORY` 환경변수를 통해 지정된 또는 기본 경로인 `/tmp/nvidia-mps/`에 `control` Unix Domain Socket이 존재하는지 확인하며, 확인할 경우에 MPS를 활용하여 CUDA App을 실행하게 된다. 따라서 MPS가 동작하고 있다면 기본적으로 CUDA App은 MPS를 활용하는 형태로 동작하게 된다.

### 1.3. MIG (Multi Instance GPU)

**MIG (Multi Instance GPU)** GPU에서 제공하는 Hardware Level GPU 격리 및 가상화 기법이다. MIG 기법은 GPU의 SM, Memory를 완전히 격리하여 vGPU(Virtual GPU)를 생성하고, 생성한 vGPU를 CUDA App에서 사용할수 있도록 제공한다. MIG 기능을 활성화 하면 Linux Kernel도 단일 GPU가 아니라 다수의 GPU 인스턴스가 존재하는것 처럼 인식하게 된다. Hardware Level 가상화 기법인 SR-IOV (Single Root I/O Virtualization)과 유사한 기법이다. Hardware Level의 가상화 기법이기 때문에 Ampere Architecture 이후의 GPU에서만 이용 가능하다.

{{< figure caption="[Figure 8] MIG Architecture" src="images/mig-architecture.png" width="600px" >}}

[Figure 8]은 MIG 기법의 구조를 나타내고 있다. MIG에서는 **GPU Instance**와 **Compute Instance** 두가지 단위로 GPU를 가상화 한다. GPU Instance는 GPU Memory를 격리하는 역할을 수행한다. Compute Instance는 GPU Instance 내부에서 다시 SM을 격리하는 역할을 수행한다. 따라서 일반적으로 GPU Instance와 Compute Instance는 일반적으로 1:1으로 구성하지만 1:N으로 구성도 가능하다. 1:N으로 구성한 경우에는 Compute Instance의 SM은 GPU Instance의 Memroy를 공유하여 이용한다. CUDA App은 Compute Instance를 vGPU라고 간주한다.

[Figure 8]에서는 CUDA App A가 이용하는 vGPU는 GPU Instance와 Compute Instance 1:1로 구성하여 완전히 격리된 vGPU를 이용하는 예시를 나타내고 있다. 또한 App B와 App C의 vGPU는 GPU Instance와 Compute Instance 1:N으로 구성하여 GPU Instance의 Memory를 공유하여 이용하는 예시를 나타내고 있다.

{{< figure caption="[Figure 9] MIG A100 MIG GPU Instance Profile" src="images/mig-a100-profile.png" width="900px" >}}

MIG 기법은 vGPU 사이의 완전한 격리성을 제공하지만 vGPU에 할당하는 SM과 Memory의 크기를 자유롭게 설정할수 없으며, Profile에 따라서만 제한된 크기로만 할당할 수 있다. [Figure 9]는 40GB의 용량을 가지고 있는  A100 GPU의 MIG GPU Instance Profile을 나타내고 있다. `[X]g.[XX]gb` 형태로 Profile 이름이 정의되어 있으며, `[X]g`는 GPU Instnace에 할당할 수 있는 최대 SM Slice 개수를 의미하고, `[XX]gb`는 GPU Instance에 할당할 수 있는 최대 Memory의 크기를 의미한다.

예를들어 `4g.20gb` Profile은 4개의 SM Slice을 이용할 수 있고 20GB의 Memory를 할당하여 구성하는 Profile을 의미한다. A100 GPU의 경우에는 `7g.40gb`, `4g.20gb`, `3g.20gb`, `2g.10gb`, `1g.5gb` 5가지 Profile이 존재하며, [Figure 9]의 조합으로만 Profile 구성이 가능하다. MIG 기법은 높은 격리성을 제공하지만 제한된 Profile 구성으로 인해서 각각의 vGPU의 사용률을 최적화하기 어렵다는 단점이 있다. 또한 높은 격리성으로 인해서 GPU 전체의 사용률을 높이기 어렵다라는 단점도 가지고 있다. Time-slicing 기법과 MPS 기법은 특정 CUDA App이 필요에 따라서는 GPU 전체를 활용할수 있지만, MIG 기법에서는 격리 기능만 제공할뿐 Over-committing 기능을 제공하지 않기 때문이다.

{{< figure caption="[Figure 10] MIG Timeline" src="images/mig-timeline.png" width="1100px" >}}

[Figure 10]은 MIG 기법의 동작 과정을 Timeline 형태로 나타내고 있다. Memory는 GPU Instance 단위로 격리되어 있으며, SM은 Compute Instance 단위로 격리되어 MPS 기법과 유사하게 다수의 Kernel이 동시에 실행되는 것을 확인할 수 있다.

#### 1.3.1. MIG 설정 방법

```shell {caption="[Shell 3] MIG 활성화 및 GPU Instance Profile 확인"}
# Enable MIG for GPU 0
$ nvidia-smi -i 0 -mig 1

# Check MIG mode for GPU 0
$ nvidia-smi -i 0 --query-gpu=mig.mode.current --format=csv,noheader

# Check MIG GPU instance profiles for GPU 0
$ nvidia-smi mig -i 0 -lgip
+-------------------------------------------------------------------------------+
| GPU instance profiles:                                                        |
| GPU   Name               ID    Instances   Memory     P2P    SM    DEC   ENC  |
|                                Free/Total   GiB              CE    JPEG  OFA  |
|===============================================================================|
|   0  MIG 1g.5gb          19     7/7        4.75       No     14     0     0   |
|                                                               1     0     0   |
+-------------------------------------------------------------------------------+
|   0  MIG 1g.5gb+me       20     1/1        4.75       No     14     1     0   |
|                                                               1     1     1   |
+-------------------------------------------------------------------------------+
|   0  MIG 1g.10gb         15     4/4        9.75       No     14     1     0   |
|                                                               1     0     0   |
+-------------------------------------------------------------------------------+
|   0  MIG 2g.10gb         14     3/3        9.75       No     28     1     0   |
|                                                               2     0     0   |
+-------------------------------------------------------------------------------+
|   0  MIG 3g.20gb          9     2/2        19.62      No     42     2     0   |
|                                                               3     0     0   |
+-------------------------------------------------------------------------------+
|   0  MIG 4g.20gb          5     1/1        19.62      No     56     2     0   |
|                                                               4     0     0   |
+-------------------------------------------------------------------------------+
|   0  MIG 7g.40gb          0     1/1        39.38      No     98     5     0   |
|                                                               7     1     1   |
+-------------------------------------------------------------------------------+
```

[Shell 3]은 MIG 기법을 활성화하고 GPU Instance Profile을 확인하는 과정을 나타내고 있다. 모든 과정은 `nvidia-smi` 명령어를 통해서 수행할 수 있다. `-i` Option은 특정 GPU를 지정하는 옵션이며 숫자로 GPU를 지정한다. `-mig 1` Option은 MIG 기법을 활성화하는 옵션이다. 다수의 GPU가 존재한다면 각 GPU별로 MIG 기법을 활성화 해야 한다.

```shell {caption="[Shell 3] MIG GPU Instance 생성"}
# Create GPU instance with profile 4g.20gb
$ nvidia-smi mig -i 0 -cgi 4g.20gb
Successfully created GPU instance ID  2 on GPU  0 using profile MIG 4g.20gb (ID  5)
$ nvidia-smi mig -i 0 -lgip
+-------------------------------------------------------------------------------+
| GPU instance profiles:                                                        |
| GPU   Name               ID    Instances   Memory     P2P    SM    DEC   ENC  |
|                                Free/Total   GiB              CE    JPEG  OFA  |
|===============================================================================|
|   0  MIG 1g.5gb          19     3/7        4.75       No     14     0     0   |
|                                                               1     0     0   |
+-------------------------------------------------------------------------------+
|   0  MIG 1g.5gb+me       20     1/1        4.75       No     14     1     0   |
|                                                               1     1     1   |
+-------------------------------------------------------------------------------+
|   0  MIG 1g.10gb         15     2/4        9.75       No     14     1     0   |
|                                                               1     0     0   |
+-------------------------------------------------------------------------------+
|   0  MIG 2g.10gb         14     1/3        9.75       No     28     1     0   |
|                                                               2     0     0   |
+-------------------------------------------------------------------------------+
|   0  MIG 3g.20gb          9     1/2        19.62      No     42     2     0   |
|                                                               3     0     0   |
+-------------------------------------------------------------------------------+
|   0  MIG 4g.20gb          5     0/1        19.62      No     56     2     0   |
|                                                               4     0     0   |
+-------------------------------------------------------------------------------+
|   0  MIG 7g.40gb          0     0/1        39.38      No     98     5     0   |
|                                                               7     1     1   |
+-------------------------------------------------------------------------------+

# Create GPU instance with profile 2g.10gb
$ nvidia-smi mig -i 0 -cgi 2g.10gb
Successfully created GPU instance ID  3 on GPU  0 using profile MIG 2g.10gb (ID 14)
$ nvidia-smi mig -i 0 -lgip
+-------------------------------------------------------------------------------+
| GPU instance profiles:                                                        |
| GPU   Name               ID    Instances   Memory     P2P    SM    DEC   ENC  |
|                                Free/Total   GiB              CE    JPEG  OFA  |
|===============================================================================|
|   0  MIG 1g.5gb          19     1/7        4.75       No     14     0     0   |
|                                                               1     0     0   |
+-------------------------------------------------------------------------------+
|   0  MIG 1g.5gb+me       20     1/1        4.75       No     14     1     0   |
|                                                               1     1     1   |
+-------------------------------------------------------------------------------+
|   0  MIG 1g.10gb         15     1/4        9.75       No     14     1     0   |
|                                                               1     0     0   |
+-------------------------------------------------------------------------------+
|   0  MIG 2g.10gb         14     0/3        9.75       No     28     1     0   |
|                                                               2     0     0   |
+-------------------------------------------------------------------------------+
|   0  MIG 3g.20gb          9     0/2        19.62      No     42     2     0   |
|                                                               3     0     0   |
+-------------------------------------------------------------------------------+
|   0  MIG 4g.20gb          5     0/1        19.62      No     56     2     0   |
|                                                               4     0     0   |
+-------------------------------------------------------------------------------+
|   0  MIG 7g.40gb          0     0/1        39.38      No     98     5     0   |
|                                                               7     1     1   |
+-------------------------------------------------------------------------------+

# Create GPU instance with profile 1g.5gb
$ nvidia-smi mig -i 0 -cgi 1g.5gb
Successfully created GPU instance ID  9 on GPU  0 using profile MIG 1g.5gb (ID 19)
$ nvidia-smi mig -i 0 -lgip
+-------------------------------------------------------------------------------+
| GPU instance profiles:                                                        |
| GPU   Name               ID    Instances   Memory     P2P    SM    DEC   ENC  |
|                                Free/Total   GiB              CE    JPEG  OFA  |
|===============================================================================|
|   0  MIG 1g.5gb          19     0/7        4.75       No     14     0     0   |
|                                                               1     0     0   |
+-------------------------------------------------------------------------------+
|   0  MIG 1g.5gb+me       20     0/1        4.75       No     14     1     0   |
|                                                               1     1     1   |
+-------------------------------------------------------------------------------+
|   0  MIG 1g.10gb         15     0/4        9.75       No     14     1     0   |
|                                                               1     0     0   |
+-------------------------------------------------------------------------------+
|   0  MIG 2g.10gb         14     0/3        9.75       No     28     1     0   |
|                                                               2     0     0   |
+-------------------------------------------------------------------------------+
|   0  MIG 3g.20gb          9     0/2        19.62      No     42     2     0   |
|                                                               3     0     0   |
+-------------------------------------------------------------------------------+
|   0  MIG 4g.20gb          5     0/1        19.62      No     56     2     0   |
|                                                               4     0     0   |
+-------------------------------------------------------------------------------+
|   0  MIG 7g.40gb          0     0/1        39.38      No     98     5     0   |
|                                                               7     1     1   |
+-------------------------------------------------------------------------------+

# Check MIG GPU instances
$ nvidia-smi mig -i 0 -lgi
+---------------------------------------------------------+
| GPU instances:                                          |
| GPU   Name               Profile  Instance   Placement  |
|                            ID       ID       Start:Size |
|=========================================================|
|   0  MIG 1g.5gb            19        9          6:1     |
+---------------------------------------------------------+
|   0  MIG 2g.10gb           14        3          4:2     |
+---------------------------------------------------------+
|   0  MIG 4g.20gb            5        2          0:4     |
+---------------------------------------------------------+
```

[Shell 4]는 MIG GPU Instance를 생성하고 확인하는 과정을 나타내고 있다. `4g.20gb`, `2g.10gb`, `1g.5gb` Profile을 하나씩 이용해 총 3개의 GPU Instance를 생성한 것을 확인할 수 있다. [Figure 9]의 두번째 Profile 조합인 것을 확인할 수 있다.  GPU Instance ID는 순서대로 `2`, `3`, `9`로 생성된 것도 확인할 수 있다. GPU Instance ID는 Compute Instance를 생성할 때 사용된다.

```shell {caption="[Shell 5] MIG Compute Instance 생성"}
# Check and create a compute instance profile for GPU instance ID 2 (4g.20gb GPU Instance)
$ nvidia-smi mig -i 0 -gi 2 -lcip
+--------------------------------------------------------------------------------------+
| Compute instance profiles:                                                           |
| GPU     GPU       Name             Profile  Instances   Exclusive       Shared       |
|       Instance                       ID     Free/Total     SM       DEC   ENC   OFA  |
|         ID                                                          CE    JPEG       |
|======================================================================================|
|   0      2       MIG 1c.4g.20gb       0      4/4           14        2     0     0   |
|                                                                      4     0         |
+--------------------------------------------------------------------------------------+
|   0      2       MIG 2c.4g.20gb       1      2/2           28        2     0     0   |
|                                                                      4     0         |
+--------------------------------------------------------------------------------------+
|   0      2       MIG 4g.20gb          3*     1/1           56        2     0     0   |
|                                                                      4     0         |
+--------------------------------------------------------------------------------------+

$ nvidia-smi mig -i 0 -gi 2 -cci 4g.20gb
Successfully created compute instance ID  0 on GPU  0 GPU instance ID  2 using profile MIG 4g.20gb (ID  3)
$ nvidia-smi mig -i 0 -gi 2 -lcip
+--------------------------------------------------------------------------------------+
| Compute instance profiles:                                                           |
| GPU     GPU       Name             Profile  Instances   Exclusive       Shared       |
|       Instance                       ID     Free/Total     SM       DEC   ENC   OFA  |
|         ID                                                          CE    JPEG       |
|======================================================================================|
|   0      2       MIG 1c.4g.20gb       0      0/4           14        2     0     0   |
|                                                                      4     0         |
+--------------------------------------------------------------------------------------+
|   0      2       MIG 2c.4g.20gb       1      0/2           28        2     0     0   |
|                                                                      4     0         |
+--------------------------------------------------------------------------------------+
|   0      2       MIG 4g.20gb          3*     0/1           56        2     0     0   |
|                                                                      4     0         |
+--------------------------------------------------------------------------------------+

# Check and create two compute instance profiles for GPU instance ID 3 (2g.10gb GPU Instance)
$ nvidia-smi mig -i 0 -gi 3 -lcip
+--------------------------------------------------------------------------------------+
| Compute instance profiles:                                                           |
| GPU     GPU       Name             Profile  Instances   Exclusive       Shared       |
|       Instance                       ID     Free/Total     SM       DEC   ENC   OFA  |
|         ID                                                          CE    JPEG       |
|======================================================================================|
|   0      3       MIG 1c.2g.10gb       0      2/2           14        1     0     0   |
|                                                                      2     0         |
+--------------------------------------------------------------------------------------+
|   0      3       MIG 2g.10gb          1*     1/1           28        1     0     0   |
|                                                                      2     0         |
+--------------------------------------------------------------------------------------+

$ nvidia-smi mig -i 0 -gi 3 -cci 1c.2g.10gb
Successfully created compute instance ID  0 on GPU  0 GPU instance ID  3 using profile MIG 1c.2g.10gb (ID  0)
$ nvidia-smi mig -i 0 -gi 3 -lcip
+--------------------------------------------------------------------------------------+
| Compute instance profiles:                                                           |
| GPU     GPU       Name             Profile  Instances   Exclusive       Shared       |
|       Instance                       ID     Free/Total     SM       DEC   ENC   OFA  |
|         ID                                                          CE    JPEG       |
|======================================================================================|
|   0      3       MIG 1c.2g.10gb       0      1/2           14        1     0     0   |
|                                                                      2     0         |
+--------------------------------------------------------------------------------------+
|   0      3       MIG 2g.10gb          1*     0/1           28        1     0     0   |
|                                                                      2     0         |
+--------------------------------------------------------------------------------------+

$ nvidia-smi mig -i 0 -gi 3 -cci 1c.2g.10gb
Successfully created compute instance ID  0 on GPU  0 GPU instance ID  3 using profile MIG 1c.2g.10gb (ID  0)
$ nvidia-smi mig -i 0 -gi 3 -lcip
+--------------------------------------------------------------------------------------+
| Compute instance profiles:                                                           |
| GPU     GPU       Name             Profile  Instances   Exclusive       Shared       |
|       Instance                       ID     Free/Total     SM       DEC   ENC   OFA  |
|         ID                                                          CE    JPEG       |
|======================================================================================|
|   0      3       MIG 1c.2g.10gb       0      0/2           14        1     0     0   |
|                                                                      2     0         |
+--------------------------------------------------------------------------------------+
|   0      3       MIG 2g.10gb          1*     0/1           28        1     0     0   |
|                                                                      2     0         |
+--------------------------------------------------------------------------------------+

# Check and create a compute instance profile for GPU instance ID 9 (1g.5gb GPU Instance)
$ nvidia-smi mig -i 0 -gi 9 -lcip
+--------------------------------------------------------------------------------------+
| Compute instance profiles:                                                           |
| GPU     GPU       Name             Profile  Instances   Exclusive       Shared       |
|       Instance                       ID     Free/Total     SM       DEC   ENC   OFA  |
|         ID                                                          CE    JPEG       |
|======================================================================================|
|   0      9       MIG 1g.5gb           0*     1/1           14        0     0     0   |
|                                                                      1     0         |
+--------------------------------------------------------------------------------------+

$ nvidia-smi mig -i 0 -gi 9 -cci 1g.5gb
Successfully created compute instance ID  0 on GPU  0 GPU instance ID  9 using profile MIG 1g.5gb (ID  0)
$ nvidia-smi mig -i 0 -gi 9 -lcip
+--------------------------------------------------------------------------------------+
| Compute instance profiles:                                                           |
| GPU     GPU       Name             Profile  Instances   Exclusive       Shared       |
|       Instance                       ID     Free/Total     SM       DEC   ENC   OFA  |
|         ID                                                          CE    JPEG       |
|======================================================================================|
|   0      9       MIG 1g.5gb           0*     0/1           14        0     0     0   |
|                                                                      1     0         |
+--------------------------------------------------------------------------------------+

# Check GPU instances and Compute instances
$ nvidia-smi mig -i 0 -lgi
+---------------------------------------------------------+
| GPU instances:                                          |
| GPU   Name               Profile  Instance   Placement  |
|                            ID       ID       Start:Size |
|=========================================================|
|   0  MIG 1g.5gb            19        9          6:1     |
+---------------------------------------------------------+
|   0  MIG 2g.10gb           14        3          4:2     |
+---------------------------------------------------------+
|   0  MIG 4g.20gb            5        2          0:4     |
+---------------------------------------------------------+

$ nvidia-smi mig -i 0 -lci
+--------------------------------------------------------------------+
| Compute instances:                                                 |
| GPU     GPU       Name             Profile   Instance   Placement  |
|       Instance                       ID        ID       Start:Size |
|         ID                                                         |
|====================================================================|
|   0      9       MIG 1g.5gb           0         0          0:1     |
+--------------------------------------------------------------------+
|   0      3       MIG 1c.2g.10gb       0         0          0:1     |
+--------------------------------------------------------------------+
|   0      3       MIG 1c.2g.10gb       0         1          1:1     |
+--------------------------------------------------------------------+
|   0      2       MIG 4g.20gb          3         0          0:4     |
+--------------------------------------------------------------------+
```

[Shell 5]는 Compute Instance를 생성하고 확인하는 과정을 나타내고 있다. GPU Instance가 생성된 이후에는 해당 GPU Instance에 생성할 수 있는 Compute Instance Profile을 확인할 수 있다. `4g.20gb` GPU Instance의 경우에는 `1c.4g.20gb`, `2c.4g.20gb`, `4g.20gb` 3가지 Profile이 존재하며, `2g.10gb` GPU Instance의 경우에는 `1c.2g.10gb`, `2g.10gb` 2가지 Profile이 존재하고, `1g.5gb` GPU Instance의 경우에는 `1g.5gb` 1가지 Profile이 존재한다.
의
`4g.20gb` GPU Instance에는 `4g.20gb` Profile을 이용해 하나의 Compute Instance를 생성하고, `2g.10gb` GPU Instance에는 `1c.2g.10gb` Profile을 이용해 두개의 Compute Instance를 생성하고, `1g.5gb` GPU Instance에는 `1g.5gb` Profile을 이용해 하나의 Compute Instance를 생성한 것을 확인할 수 있다.

```shell {caption="[Shell 6] MIG vGPU 확인"}
$ nvidia-smi -i 0
Tue Feb 17 16:58:38 2026
+-----------------------------------------------------------------------------------------+
| NVIDIA-SMI 580.126.09             Driver Version: 580.126.09     CUDA Version: 13.0     |
+-----------------------------------------+------------------------+----------------------+
| GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
| Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
|                                         |                        |               MIG M. |
|=========================================+========================+======================|
|   0  NVIDIA A100-SXM4-40GB          On  |   00000000:10:1C.0 Off |                   On |
| N/A   40C    P0             43W /  400W |     249MiB /  40960MiB |     N/A      Default |
|                                         |                        |              Enabled |
+-----------------------------------------+------------------------+----------------------+

+-----------------------------------------------------------------------------------------+
| MIG devices:                                                                            |
+------------------+----------------------------------+-----------+-----------------------+
| GPU  GI  CI  MIG |              Shared Memory-Usage |        Vol|        Shared         |
|      ID  ID  Dev |                Shared BAR1-Usage | SM     Unc| CE ENC  DEC  OFA  JPG |
|                  |                                  |        ECC|                       |
|==================+==================================+===========+=======================|
|  0    2   0   0  |             142MiB / 20096MiB    | 56      0 |  4   0    2    0    0 |
|                  |               0MiB / 12211MiB    |           |                       |
+------------------+----------------------------------+-----------+-----------------------+
|  0    3   0   1  |              71MiB /  9984MiB    | 14      0 |  2   0    1    0    0 |
|                  |               0MiB /  6105MiB    |           |                       |
+------------------+----------------------------------+-----------+-----------------------+
|  0    3   1   2  |              71MiB /  9984MiB    | 14      0 |  2   0    1    0    0 |
|                  |               0MiB /  6105MiB    |           |                       |
+------------------+----------------------------------+-----------+-----------------------+
|  0    9   0   3  |              36MiB /  4864MiB    | 14      0 |  1   0    0    0    0 |
|                  |               0MiB /  3052MiB    |           |                       |
+------------------+----------------------------------+-----------+-----------------------+

+-----------------------------------------------------------------------------------------+
| Processes:                                                                              |
|  GPU   GI   CI              PID   Type   Process name                        GPU Memory |
|        ID   ID                                                               Usage      |
|=========================================================================================|
|  No running processes found                                                             |
+-----------------------------------------------------------------------------------------+

$ nvidia-smi -i 0 -L
GPU 0: NVIDIA A100-SXM4-40GB (UUID: GPU-9e4aeb94-01c0-5173-4811-4ca60f77b3a9)
  MIG 4g.20gb     Device  0: (UUID: MIG-c42101f0-a1fa-5b68-8908-7c5c887f28bd)
  MIG 1c.2g.10gb  Device  1: (UUID: MIG-8970491e-16e0-5140-9f8f-d561baa3c186)
  MIG 1c.2g.10gb  Device  2: (UUID: MIG-239565ce-30e3-52d7-8197-5630d3ce21fa)
  MIG 1g.5gb      Device  3: (UUID: MIG-20301a31-77fa-59ec-b0b8-7ef543821f29)
```

[Shell 6]은 MIG vGPU를 확인하는 과정을 나타내고 있다. `nvidia-smi` 명령어를 통해서 GPU를 조회하면 MIG vGPU의 정보를 확인할 수 있다. 또한 `-L` 명령어를 통해서 vGPU의 UUID를 확인할 수 있다. UUID는 CUDA App에서 어떤 vGPU를 이용할지 결정하는데 사용된다.

```shell {caption="[Shell 7] MIG vGPU Device Files 확인"}
# Check MIG device files
$ ls -l /dev/nvidia-caps/
cr--------.  1 root root 242,  0 Feb 17 16:23 nvidia-cap0
cr--------.  1 root root 242,  1 Feb 17 16:23 nvidia-cap1
cr--r--r--.  1 root root 242,  2 Feb 17 16:23 nvidia-cap2
cr--r--r--.  1 root root 242, 21 Feb 17 16:24 nvidia-cap21
cr--r--r--.  1 root root 242, 22 Feb 17 16:32 nvidia-cap22
cr--r--r--.  1 root root 242, 30 Feb 17 16:25 nvidia-cap30
cr--r--r--.  1 root root 242, 31 Feb 17 16:45 nvidia-cap31
cr--r--r--.  1 root root 242, 32 Feb 17 16:45 nvidia-cap32
cr--r--r--.  1 root root 242, 84 Feb 17 16:26 nvidia-cap84
cr--r--r--.  1 root root 242, 85 Feb 17 16:54 nvidia-cap85

# Check what cap is what GI/CI
find /proc/driver/nvidia/capabilities/gpu0/mig/ -name access | sort | while read f; do
    minor=$(grep DeviceFileMinor "$f" | awk '{print $2}')
    echo "$f  →  /dev/nvidia-caps/nvidia-cap${minor}"
done
/proc/driver/nvidia/capabilities/gpu0/mig/gi2/access  →  /dev/nvidia-caps/nvidia-cap21
/proc/driver/nvidia/capabilities/gpu0/mig/gi2/ci0/access  →  /dev/nvidia-caps/nvidia-cap22
/proc/driver/nvidia/capabilities/gpu0/mig/gi3/access  →  /dev/nvidia-caps/nvidia-cap30
/proc/driver/nvidia/capabilities/gpu0/mig/gi3/ci0/access  →  /dev/nvidia-caps/nvidia-cap31
/proc/driver/nvidia/capabilities/gpu0/mig/gi3/ci1/access  →  /dev/nvidia-caps/nvidia-cap32
/proc/driver/nvidia/capabilities/gpu0/mig/gi9/access  →  /dev/nvidia-caps/nvidia-cap84
/proc/driver/nvidia/capabilities/gpu0/mig/gi9/ci0/access  →  /dev/nvidia-caps/nvidia-cap85
```

각 GPU Instance와 Compute Instance마다 Device File이 `/dev/nvidia-caps/nvidia-cap[Minor Number]` 형태로 생성된다. [Shell 7]은 GPU Instance와 Compute Instance의 Device File을 확인하는 과정을 나타내고 있으며, 어떤 Device File이 어떤 GPU Instance 또는 Compute Instance와 Mapping되는지 확인할 수 있다.

#### 1.3.2. MIG vGPU 이용 방법

```shell {caption="[Shell 8] MIG vGPU 이용 방법"}
# Run with MIG UUID
CUDA_VISIBLE_DEVICES=MIG-c42101f0-a1fa-5b68-8908-7c5c887f28bd   # 4g.20gb
CUDA_VISIBLE_DEVICES=MIG-8970491e-16e0-5140-9f8f-d561baa3c186   # 1c.2g.10gb first
CUDA_VISIBLE_DEVICES=MIG-239565ce-30e3-52d7-8197-5630d3ce21fa   # 1c.2g.10gb second
CUDA_VISIBLE_DEVICES=MIG-20301a31-77fa-59ec-b0b8-7ef543821f29   # 1g.5gb

# Run with MIG-GPU-<gpu-uuid>/<gi-id>/<ci-id>
CUDA_VISIBLE_DEVICES=MIG-GPU-9e4aeb94-01c0-5173-4811-4ca60f77b3a9/2/0   # 4g.20gb
CUDA_VISIBLE_DEVICES=MIG-GPU-9e4aeb94-01c0-5173-4811-4ca60f77b3a9/3/0   # 1c.2g.10gb first
CUDA_VISIBLE_DEVICES=MIG-GPU-9e4aeb94-01c0-5173-4811-4ca60f77b3a9/3/1   # 1c.2g.10gb second
CUDA_VISIBLE_DEVICES=MIG-GPU-9e4aeb94-01c0-5173-4811-4ca60f77b3a9/9/0   # 1g.5gb
```

[Shell 8]은 CUDA App에서 MIG vGPU 이용 방법을 나타내고 있다. CUDA SDK는 `CUDA_VISIBLE_DEVICES` 환경변수를 통해서 CUDA App이 이용할수 있는 GPU를 지정할 수 있으며, 따라서 동일하게 `CUDA_VISIBLE_DEVICES` 환경변수에 MIG vGPU를 지정하여 CUDA App이 MIG vGPU를 이용할 수 있도록 만들수 있다. `CUDA_VISIBLE_DEVICES` 환경변수에 MIG vGPU를 지정하는 방법은 MIG vGPU의 UUID를 통해서 지정하는 방법과 `MIG-GPU-<gpu-uuid>/<gi-id>/<ci-id>` 형태로 지정하는 방법이 있다. 다수의 MIG vGPU를 이용할 경우에는 `,`를 구분자로 사용하여 다수의 MIG vGPU를 지정하면 된다.

#### 1.3.3. with Time-slicing and MPS

{{< figure caption="[Figure 11] MIG with Time-slicing and MPS Architecture" src="images/mig-time-slicing-mps-architecture.png" width="800px" >}} 

MIG 기법을 통해서 생성된 vGPU에 다시 Time-slicing 기법 또는 MPS 기법을 적용하여 vGPU를 Sharing하는 구조가 가능하다. [Figure 11]은 MIG 기법을 통해서 생성된 vGPU에 다시 Time-slicing 기법을 적용하여 vGPU를 Sharing하는 구조를 나타내고 있다. 첫번째 vGPU에는 Time-slicing 기법을 적용하여 vGPU를 Sharing하고, 두번째 vGPU에는 MPS 기법을 적용하여 vGPU를 Sharing하고 있다.

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
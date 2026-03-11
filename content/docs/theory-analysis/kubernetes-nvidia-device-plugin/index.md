---
title: Kubernetes NVIDIA Device Plugin
draft: true
---

## 1. Kubernetes NVIDIA Device Plugin

{{< figure caption="[Figure 1] NVIDIA Device Plugin Architecture" src="images/nvidia-device-plugin-architecture.png" width="900px" >}}

**Kubernetes NVIDIA Device Plugin**은 Kubernetes 환경에서 NVIDIA GPU를 사용하기 위한 컴포넌트이다. Pod에게 GPU를 할당하기 위해서는 NVIDIA Device Plugin을 Kubernetes Cluster에 설치해야 한다. [Figure 1]은 NVIDIA Device Plugin의 Architecture를 나타내고 있다. NVIDIA Device Plugin은 DaemonSet을 통해서 GPU가 존재하는 Node에서 동작한다. NVIDIA Device Plugin은 GPU를 Kubernetes에 등록하는 역할, GPU를 Pod에 할당하는 역할, GPU의 상태를 확인하는 역할 3가지 역할을 수행한다.

기본적으로 하나의 GPU는 하나의 Container에만 할당되어 동작한다. [Figure 1]에서는 하나의 Host에 4장의 GPU가 존재하며, Pod A의 Container A에는 하나의 GPU가 할당되어 있고 Container B에는 두개의 GPU가 할당되어 있다. 또한 Pod B의 Container C에는 하나의 GPU가 할당되어 있다. 즉 각 GPU는 하나의 Container에만 할당되어 있는것을 확인할 수 있다.

각 Container는 자신에게 할당된 GPU 정보를 `NVIDIA_VISIBLE_DEVICES` 환경 변수를 통해서 파악할 수 있다. 단일 GPU가 Container에게 할당되어 있는 경우에는  `NVIDIA_VISIBLE_DEVICES=GPU-[UUID]` 형태로 환경변수에 할당되며 다수의 GPU가 Container에게 할당되어 있는 경우에는  `NVIDIA_VISIBLE_DEVICES=GPU-[UUID1],GPU-[UUID2],...` 형태로 환경변수에 할당된다. `NVIDIA_VISIBLE_DEVICES` 환경 변수는 CUDA Library/Tool에서 사용하는 환경 변수이기 때문에 App은 별도의 설정 없이 CUDA Library/Tool을 통해서 GPU를 사용할 수 있게 된다.

Pod에게 GPU를 할당하기 위해서는 Pod의 Resource의 Request와 Limit에 동일한 개수의 GPU를 `nvidia.com/gpu` Type으로 설정하면 된다. 반드시 정수값을 설정해야 하며, 소수점 이하 값은 허용되지 않는다. Container A, B, C의 Resource에도 `nvidia.com/gpu` Type으로 GPU 개수가 설정되어 있는것을 확인할 수 있다.

NVIDIA Device Plugin은 동작을 시작하면서 [NVIDIA Container Toolkit](https://github.com/NVIDIA/nvidia-container-toolkit)이 Node에 설치되어 있는지를 검사하며, 만약 설치되어 있지 않으면 NVIDIA Device Plugin은 동작하지 않는다. NVIDIA Container Toolkit은 Container에 GPU를 할당하기 위한 Container Runtime을 제공하는 역할을 수행한다. 이 의미는 GPU Node에 Device Plugin뿐만 아니라 NVIDIA Container Toolkit도 설치되어 있어야 하는것을 의미한다.

### 1.1. GPU Node 등록 과정

{{< figure caption="[Figure 2] GPU Node Registration Process" src="images/nvidia-gpu-registration-process.png" width="600px" >}}

NVIDIA Device Plugin의 첫번째 역할은 Node의 존재하는 GPU 정보 및 상태를 Kubernetes Node의 Allocatable/Capacity에 `nvidia.com/gpu` Type으로 등록하는 역할을 수행한다. [Figure 2]는 GPU Node 등록 과정을 나타내고 있다.

1. NVIDIA Device Plugin이 DaemonSet으로 배포되며 Node에서 동작을 시작하며, Unix Domain Socket(`/var/lib/kubelet/device-plugins/nvidia-gpu.sock`을 통해서 gRPC 서버를 동작시킨다.
2. NVIDIA Device Plugin은 Node의 GPU 정보 및 상태 정보를 파악하기 시작한다.
3. NVIDIA Device Plugin은 kubelet의 Device Plug-in Unix Domain Socket(`/var/lib/kubelet/device-plugins/kubelet.sock`)을 통해서 `Register()` gRPC 요청을 전송하여 자기 자신을 kubelet에 등록한다. 이 과정에서 자신의 Unix Domain Socket 경로(`/var/lib/kubelet/device-plugins/nvidia-gpu.sock`)를 kubelet에게 전달한다.
4. kubelet은 NVIDIA Device Plugin의 `Register()` gRPC 요청을 통해서 받은 Unix Domain Socket 경로(`/var/lib/kubelet/device-plugins/nvidia-gpu.sock`)에 `ListAndWatch()` gRPC 요청을 전송하여 GPU 정보를 요청한다.
5. kubelet은 NVIDIA Device Plugin으로부터 받은 GPU 정보를 바탕으로 Node의 Allocatable/Capacity에 `nvidia.com/gpu` Type으로 GPU 정보를 등록한다.

### 1.2. GPU Pod 할당 과정

{{< figure caption="[Figure 3] GPU Pod Allocation Process" src="images/nvidia-gpu-allocation-process.png" width="600px" >}}

NVIDIA Device Plugin의 두번째 역할은 어떤 GPU를 컨테이너에게 할당할지를 결정하는, GPU Scheduling 역할을 수행한다. [Figure 3]는 GPU Pod 할당 과정을 나타내고 있다.

1. Kubernetes Client는 Pod의 Resource에 `nvidia.com/gpu` Type으로 GPU의 개수를 명시하여 GPU Pod를 생성한다.
2. Kubernetes Scheduler는 GPU Pod가 요청한 수량의 GPU를 제공할 수 있는 Node를 선택하여 해당 Pod를 배치한다.
3. Kubernetes Scheduler로부터 선택된 Node의 kubelet은 GPU Pod에 명시된 GPU의 개수 정보를 수신한다.
4. kubelet은 GPU Pod에 명시된 GPU 개수만큼 NVIDIA Device Plugin에 Allocation() gRPC 요청을 보내 GPU를 할당받는다. 이때 kubelet이 전달받는 GPU 할당 정보는 GPU Pod의 NVIDIA_VISIBLE_DEVICES 환경 변수에 설정될 GPU UUID 배열 형태로 제공된다.
5. kubelet은 할당받은 GPU 정보를 Node에 설치된 NVIDIA Container Toolkit을 통해서 Pod/Container에게 주입한다.

### 1.3. GPU Health Check

NVIDIA Device Plugin의 세번째 역할은 GPU의 상태를 확인하는, GPU Health Check 역할을 수행한다. GPU Health Check는 NVIDIA의 **NVML** (NVIDIA Management Library)를 통해서 수행된다. NVIDIA의 NVML은 GPU의 상태를 확인하기 위한 다양한 함수를 제공하며, 주로 다음의 Event를 모니터링하여 GPU의 상태를 확인한다. 

* EventTypeXidCriticalError : XID (eXtended ID) Error Events. XID는 GPU의 오류를 나타내는 코드이다.
* EventTypeDoubleBitEccError : Double Bit ECC (Error Correcting Code) Error Events
* EventTypeSingleBitEccError : Single Bit ECC (Error Correcting Code) Error Events

만약 비정상 상태의 GPU가 발생하면, 비정상 상태의 GPU의 개수만큼 Node의 Allocatable GPU 개수가 감소한다. 예를 들어 Node에 4장의 GPU가 존재하고, 그 중 하나의 GPU가 비정상 상태가 되면, Node의 Allocatable GPU 개수는 최대 3개가 된다.

### 1.4. GPU Sharing

기본적으로 하나의 GPU는 하나의 Container에만 할당되어 동작한다. 하지만 GPU Sharing 기법을 이용하면 하나의 GPU를 다수의 Container에 할당할 수 있다. NVIDIA GPU Sharing 기법은 Time-slicing, MPS, MIG 3가지 기법이 존재하며, NVIDIA Device Plugin은 이 3가지 기법을 모두 제공한다.

#### 1.4.1. with Time-slicing

{{< figure caption="[Figure 4] NVIDIA Device Plugin Architecture with Time-slicing" src="images/nvidia-device-plugin-architecture-timeslicing.png" width="1000px" >}}

Time-slicing 기법은 GPU의 SM (Streaming Processor)를 **시분할**하여 다수의 App/Container가 GPU를 공유하여 사용하는 기법이다. Time-slicing 기법은 **하나의 Container가 다수의 GPU를 할당 받아** 이용할 수 있다. [Figure 4]는 Time-slicing 기법의 구조를 나타내고 있다. 두개의 GPU가 존재하며, Container A와 Container B가 첫번째 GPU를 공유하며 이용하고 있고, Container B와 Container C가 두번째 GPU를 공유하며 이용하고 있는것을 확인할 수 있다. 

GPU를 공유하여 Pod에게 할당하기 위해서 NVIDIA Device Plugin은 GPU의 개수를 배수로 늘려서 Kubelet에게 전달한다. 예를들어 GPU에 4개의 GPU 존재할 경우 4배수로 kubelet에게 전달할 경우, kubelet에게는 Node에 16개의 GPU가 있는것 전달한다. 이 의미는 하나의 GPU를 최대 4개의 Container에게 할당할 수 있다는걸 의미한다.

```yaml {caption="[Config 1] nvidia-device-plugin-configs ConfigMap Example for Time-slicing", linenos=table}
apiVersion: v1
data:
...
  timeslicing-4: |-
    version: v1
    sharing:
      timeSlicing:
        renameByDefault: true
        resources:
        - name: nvidia.com/gpu
          replicas: 4
```

배수는 NVIDIA Device Plugin이 존재하는 Namespace의 `nvidia-device-plugin-configs` ConfigMap에서 설정할 수 있다. [Config 1]은 4의 배수로 Time-slicing 기법을 적용하는 설정을 나타내고 있다. `timeslicing-4` 이라는 이름을 이용하고 있으며, 이 이름을 Time-slcing을 적용할 Node의 Label에 `nvidia.com/device-plugin.config: timeslicing-4` 형태로 설정하면 된다.

{{< figure caption="[Figure 5] NVIDIA Device Plugin GPU Scheduling" src="images/nvidia-device-plugin-gpu-scheduling.png" width="600px" >}}

GPU를 어떤 Container에게 할당할지 결정하는 스케줄링 역할은 [Figure 3]의 GPU 할당 과정에서 동일하게 NVIDIA Device Plugin이 수행한다. [Figure 5]는 4개의 GPU가 존재하고 2배수로 설정된 환경에서 NVIDIA Device Plugin의 GPU Scheduling 과정을 나타내고 있다. NVIDIA Device Plugin은 기본적으로 Container 할당이 적은 GPU를 우선적으로 할당하도록 스케줄링을 수행한다. Container A가 3개의 GPU를 할당받을 때는 모든 GPU에 Pod가 할당되어 있지 않기 때문에 NVIDIA Device Plugin은 임의의 3개의 GPU를 Container A에게 할당한다. [Figure 5]에서는 GPU 0, 1, 2가 Container A에게 할당되어 있다.

이후에 Container B가 3개의 GPU를 요청하는 경우에는 GPU 3에만 아직 할당된 Pod가 존재하지 않기 때문에 NVIDIA Device Plugin은 GPU 3를 Container B에게 할당한다. NVIDIA Device Plugin은 이후에 두개의 GPU는 임의의 GPU를 Container B에게 할당한다. [Figure 5]에서는 GPU 1, 3가 Container B에게 할당되어 있다. 마지막으로 Container C가 2개의 GPU를 요청하는 경우에는 NVIDIA Device Plugin은 남은 GPU 1, 2를 Container C에게 할당한다.

한가지 주목할 점은 Container B의 경우에는 3개의 GPU를 요청하였지만 GPU Scheduling에 의해서 실제로는 2개의 GPU만 할당되었다는 점이다. 즉 Pod가 요청한 GPU의 개수만큼 GPU를 할당받지 못하는 경우가 발생할 수 있다는 점이다. Time-slicing 기법은 각 App/Container의 GPU 사용률을 제한하는 기능을 제공하지 않는다. 따라서 특정 App/Container가 GPU를 과도하게 사용하는 경우에는 다른 App/Container가 GPU를 제대로 이용할 수 없는 문제가 발생할 수 있다.

#### 1.4.2. with MPS (Multi-Process Service)

{{< figure caption="[Figure 6] NVIDIA Device Plugin Architecture with MPS" src="images/nvidia-device-plugin-architecture-mps.png" width="1100px" >}}

MPS (Multi-Process Service) 기법은 GPU의 SM을 **공간 분할**하여 다수의 App/Container가 GPU를 공유하여 사용하는 기법이다. MPS 기법을 이용할 경우 **하나의 Container가 반드시 하나의 GPU**를 할당 받아 이용해야 한다. 또한 MPS 기법과 Time-slicing 기법은 동시에 사용할 수 없다. [Figure 5]는 MPS 기법의 구조를 나타내고 있다. 두개의 GPU가 존재하며, Container A와 Container B가 첫번째 GPU를 공유하며 이용하고 있고, Container C가 두번째 GPU를 공유하며 이용하고 있는것을 확인할 수 있다.

MPS 기법을 이용하기 위해서는 **MPS Control DaemonSet**을 추가로 배포해야 한다. MPS Control DaemonSet은 내부적으로 **MPS Control**(`nvidia-cuda-mps-control`)과 **MPS Server**(`nvidia-cuda-mps-server`)를 동작시킨다. MPS Control은 MPS Server를 관리하고 제어하는 역할을 수행하며, MPS Server는 각 App/Container별로 이용할 SM을 공간 분활하여 이용할 수 있도록 제어하는 역할을 수행한다.

```shell {caption="[Shell 1] MPS Control Files"}
$ ls -l /mps/
total 0
drwxr-xr-x. 3 root root 60 Mar  6 18:07 nvidia.com
drwxrwxrwt. 2 root root 40 Mar  6 18:07 shm

$ ls -l /mps/nvidia.com/gpu.shared/log/
total 4
-rw-r--r--. 1 root root 1256 Mar  6 18:17 control.log
-rw-r--r--. 1 root root    0 Mar  6 18:07 server.log

$ ls -l /mps/nvidia.com/gpu.shared/pipe/
total 4
srw-rw-rw-. 1 root root 0 Mar  6 18:07 control
-rw-rw-rw-. 1 root root 0 Mar  6 18:07 control_lock
srwxr-xr-x. 1 root root 0 Mar  6 18:07 control_privileged
prwxrwxrwx. 1 root root 0 Mar  6 18:17 log
-rw-rw-rw-. 1 root root 3 Mar  6 18:07 nvidia-cuda-mps-control.pid
```

App/Container는 MPS를 이용하기 위해서는 MPS Control과 통신을 수행해야 하며, 통신은 Unix Domain Socket을 통해서 수행된다. 따라서 App/Container는 MPS Control의 Unix Domain Socket에 접근할 수 있도록, NVIDIA Device Plugin은 Host의 `/run/nvidia/mps` 경로를 Bind Mount를 통해서 MPS Control Daemon Pod와 App/Container의 `/mps/nvidia.com/gpu.shared` 경로에 연결한다. 이후에 MPS Control은 Bind Mount된 경로에 Unix Domain Socket을 생성하여 App/Container에게 Unix Domain Socket을 노출시킨다. [Shell 1]은 MPS Control Daemon Pod에서 생성하여 App/Container에게 노출시키는 파일 목록을 나타내고 있다. 이중에 `control` 파일이 MPS Control의 Unix Domain Socket이다.

MPS를 이용하면 App/Container에는 `NVIDIA_VISIBLE_DEVICES` 환경 변수뿐만이 아니라 `CUDA_MPS_PIPE_DIRECTORY` 환경 변수도 같이 설정된다. `CUDA_MPS_PIPE_DIRECTORY` 환경 변수는 MPS Control의 Unix Domain Socket 경로를 명시하는 환경 변수이며, 따라서 

```yaml {caption="[Config 2] nvidia-device-plugin-configs ConfigMap Example for MPS", linenos=table}
apiVersion: v1
data:
...
  mps-4: |-
    version: v1
    sharing:
      mps:
        renameByDefault: true
        resources:
        - name: nvidia.com/gpu
          replicas: 4
```

* `nvidia.com/device-plugin.config` : Node에 적용할 GPU Sharing 설정을 명시한다. Ex) `nvidia.com/device-plugin.config: mps-4`
* `nvidia.com/mps.capable` : Node에 MPS 기능을 활성화 할지를 명시한다. Ex) `nvidia.com/mps.capable: "true"`

```yaml {caption="[Config 2] nvidia-device-plugin-configs ConfigMap Example for MPS", linenos=table}
apiVersion: v1
data:
...
  mps-4: |-
    version: v1
    sharing:
      mps:
        renameByDefault: true
        resources:
        - name: nvidia.com/gpu
          replicas: 4
```

* `nvidia.com/device-plugin.config` : Node에 적용할 GPU Sharing 설정을 명시한다. Ex) `nvidia.com/device-plugin.config: mps-4`
* `nvidia.com/mps.capable` : Node에 MPS 기능을 활성화 할지를 명시한다. Ex) `nvidia.com/mps.capable: "true"`

#### 1.4.3. with MIG (Multi-Instance GPU)

{{< figure caption="[Figure 6] NVIDIA Device Plugin Architecture with MIG" src="images/nvidia-device-plugin-architecture-mig.png" width="1100px" >}}

* `nvidia.com/mig.capable` : Node에 MIG 기능을 활성화 할지를 명시한다. Ex) `nvidia.com/mig.capable: "true"`

* `nvidia.com/mig.capable` : Node에 MIG 기능을 활성화 할지를 명시한다. Ex) `nvidia.com/mig.capable: "true"`

## 2. 참조

* NVIDIA MIG : [https://toss.tech/article/toss-securities-gpu-mig](https://toss.tech/article/toss-securities-gpu-mig)
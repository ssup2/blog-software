---
title: Container NVIDIA GPU
---

Container에게 NVIDIA GPU를 할당하는 기법을 분석한다.

## 1. Container NVIDIA GPU

### 1.1. NVIDIA GPU Container Architecture

{{< figure caption="[Figure 1] NVIDIA GPU Container Architecture" src="images/gpu-container-architecture.png" width="900px" >}}

NVIDIA GPU을 Container에게 할당하여 Container가 NVIDIA GPU를 이용할 수 있는 환경을 구성할 수 있다. Docker 19.03 Version에서는 추가된 GPU Option (`--gpu`)을 이용하여 Container에게 NVIDIA GPU를 할당할 수 있다. [Figure 1]은 GPU Option을 통해서 NVIDIA GPU 설정이 완료된 Container들을 나타내고 있다. 각 Container는 하나의 GPU 뿐만 아니라 다수의 GPU를 이용할 수 있다. 또한 자신에게만 할당된 Dedicated GPU 뿐만 아니라, 다른 Container와 공유하는 Shared GPU를 이용할 수 있다.

Container A는 0,1번째 NVIDIA GPU, Container B는 0,2,3번째 NVIDIA GPU, Container C는 3번째 NVIDIA GPU를 이용하고 있다. 0,1,3번째 GPU는 Shared GPU로 이용되고 있으며, 2번째 GPU는 Dedicated GPU로 이용되고 있다. 각 Container는 Docker 기준으로 다음의 명령어를 통해서 생성할 수 있다. 단일 GPU 번호 또는 다수의 GPU 번호를 `,`로 구분하여 `--gpu` Option에 전달하면 된다.

* Container A : `docker run --gpu 0,1 --name a nvidia/cuda:12.4-base-ubuntu22.04`
* Container B : `docker run --gpu 0,2,3 --name b nvidia/cuda:12.4-base-ubuntu22.04`
* Container C : `docker run --gpu 3 --name c nvidia/cuda:12.4-base-ubuntu22.04`

`--gpu all` 설정을 수행하면 Container는 모든 NVIDIA GPU를 이용할 수 있다. Shared GPU는 NVIDIA GPU에서 제공하는 **Time-Slicing** 또는 **MPS (Multi Process Service)** 기능을 활용하여 다수의 Container가 하나의 NVIDIA GPU를 공유하여 이용하게 된다.

Container에게 GPU를 할당하기 위해서는 **NVIDIA Container Toolkit**을 활용해야 한다. NVIDIA Container Toolkit은 `nvidia-container-runtime`, `nvidia-container-runtime-hook`, `nvidia-container-cli` CLI를 제공하며, Container Runtime은 제공된 CLI를 통해서 Container에 GPU를 할당한다. NVIDIA Container Toolkit은 다음과 같은 역할을 수행한다.

* Container에게 할당된 GPU를 Container 내부의 App이 접근할 수 있도록 Device File (`/dev/nvidiaX`, `/dev/nvidia-uvm`, `/dev/nvidia-uvm-tools`, `/dev/nvidiactl`)을 **Bind Mount**를 통해서 Container 내부에 주입한다.
* Container에게 할당된 GPU를 Container 내부의 App이 활용할수 있도록 CUDA Library/Tool을 **Bind Mount**를 통해서 Container 내부에 주입한다.
* Container에게 할당된 GPU를 Container 내부에서 접근할 수 있도록 Cgroup을 설정한다.
* Container에게 할당된 GPU 정보를 Container 내부의 App, CUDA Library/Tool이 인지할수 있도록 `NVIDIA_VISIBLE_DEVICES` 환경 변수를 설정한다.

### 1.2. NVIDIA GPU 할당 과정

Container에 GPU를 할당하기 위해서는 `containerd`가 `runc` CLI 대신에 `nvidia-container-runtime` CLI를 실행하도록 설정해야 한다. `nvidia-container-runtime` CLI는 `containerd`가 생성한 OCI Runtime Spec에 GPU 할당을 위한 추가적인 설정을 주입하고, 이후에 `runc` CLI를 실행하는 역할을 수행한다. 즉 `containerd`와 `runc` CLI 사이에서 Cotnainer에 GPU 할당을 위한 OCI Runtime Spec을 변경하는 역할을 수행한다. OCI Runtime Spec 변경 및 `run` CLI를 실행한 다음에 `nvidia-container-runtime` CL는 종료된다.

```toml {caption="[File 1] /etc/containerd/config.toml Example", linenos=table}
version = 3
root = "/var/lib/containerd"
state = "/run/containerd"

[plugins.'io.containerd.cri.v1.runtime']
enable_cdi = true

[plugins.'io.containerd.cri.v1.runtime'.containerd]
default_runtime_name = "nvidia"

[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.nvidia]
runtime_type = "io.containerd.runc.v2"
base_runtime_spec = "/etc/containerd/base-runtime-spec.json"

[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.nvidia.options]
BinaryName = "/usr/bin/nvidia-container-runtime"
SystemdCgroup = true
```

[File 1]은 `containerd`가 `nvidia-container-runtime` CLI를 실행하도록 설정하는 방법을 나타내고 있다. `default_runtime_name` 파라미터를 `nvidia`로 설정하고, `nvidia` Runtime에 필요한 Spec 파일과 `nvidia-container-runtime` CLI의 경로를 설정하고 있는것을 확인할 수 있다.

```toml {caption="[File 2] /etc/nvidia-container-runtime/config.toml Example", linenos=table}
[nvidia-container-runtime]
mode = "legacy | cdi | auto"

[nvidia-container-runtime.cdi]
spec-dirs = ["/etc/cdi", "/var/run/cdi"]
```

`nvidia-container-runtime` CLI는 **OCI Runtime Spec의 Prestart Hook** 기능을 활용하는 Legacy Mode과 **CDI** (Container Device Interface)를 활용하는 두 가지 Mode가 존재한다. [File 1]은 Mode를 설정하기 위한 `nvidia-container-runtime`의 설정 파일을 나타내고 있다. `mode`에 `legacy`, `cdi`, `auto` 중 하나를 설정할 수 있다. `legacy`는 OCI Runtime Spec의 Prestart Hook 기능을 활용하는 기존의 방법이고, `cdi`는 **CDI (Container Device Interface)**를 활용하는 최신 방법이다. `auto`는 시스템 설정에 따라서 `legacy` 또는 `cdi` 중 하나를 자동으로 선택하는 방법이며, `spec-dirs`에는 CDI Spec 파일이 존재하면 CDI Mode를 사용하고, 존재하지 않으면 Legacy Mode를 사용한다.

#### 1.2.1. Legacy Mode의 GPU 할당 과정

{{< figure caption="[Figure 3] NVIDIA GPU Container Init in Legacy Mode" src="images/gpu-container-init-legacy.png" width="900px" >}}

[Figure 3]은 Legacy GPU 할당 과정을 나타내고 있다. Legacy GPU 할당 과정은 **OCI Runtime Spec의 Prestart Hook** 기능을 적극적으로 활용하는 방법이다. Prestart Hook은 Container의 Entrypoint Command가 실행되기 전에 실행되는 Command를 의미한다. [Figure 3]은 다음과 같은 과정을 수행한다.

1. `ctr` CLI 또는 `dockerd`는 Container에게 할당할 GPU 정보를 `NVIDIA_VISIBLE_DEVICES` 환경 변수에 설정과 함께 `containerd`에게 Container 생성 요청을 전달한다.
2. `containerd`는 요청에 따라서 OCI Runtime Config 파일을 생성한다.
3. 이후에 `containerd`는 `containerd`의 Config에 따라서 `nvidia-container-runtime` CLI를 실행한다.
4. `nvidia-container-runtime` CLI는 OCI Runtime Config 파일의 Prestart Hook에 `nvidia-container-runtime-hook` CLI를 실행하기 위한 설정을 추가한다. 
5. 이후에 `nvidia-container-runtime` CLI는 Container 생성을 위해서 `runc` CLI를 실행한다.
6. `runc` CLI는 OCI Runtime Spec에 따라서 Container를 위한 Namespace와 Root Filesystem을 설정하기 위해 `clone()` System Call을 통해서 Container Init Process를 생성하고, OverlayFS를 이용하여 Root Filesystem을 준비한다.
7. `clone()` System Call을 통해서 생성된 Container Init Process는 FIFO Named Pipe를 통해서 `runc` CLI에게 Prestart Hook을 실행하도록 요청한다.
8. `runc` CLI는 OCI Runtime Spec에 따라서 `nvidia-container-runtime-hook` CLI를 실행한다.
9. `nvidia-container-runtime-hook` CLI는 OCI Runtime Spec 파일의 내용을 바탕으로 Container와 Container에 설정할 NVIDIA GPU 정보(`NVIDIA_VISIBLE_DEVICES` 환경 변수)를 다시 `nvidia-container-cli` CLI의 Parameter로 넘겨 `nvidia-container-cli` CLI를 실행한다. `nvidia-container-cli` CLI가 Container의 NVIDIA GPU를 실제로 설정하는 주체이고, `nvidia-container-runtime-hook` CLI는 OCI Runtime Spec과 `nvidia-container-cli` CLI 사이를 연결해주는 **Interface 역할**만을 수행한다.
10. `nvidia-container-cli` CLI는 전달받은 Container와 Container에 설정할 NVIDIA GPU 정보를 바탕으로 내부의 `libnvidia-container` Library를 통해서 Device File과 CUDA Library/Tool을 Bind Mount를 통해서 Container 내부에 주입한다. 또한 Cgroup을 설정하여 Container 내부에서 GPU 접근을 허용하도록 설정하며, 필요에 따라서 NVIDIA GPU 구동을 위한 Kernel Module도 Loading을 수행한다.
11. Prestart Hook 작업이 완료되면 `runc` CLI는 Container Init Process에게 FIFO Named Pipe를 통해서 Prestart Hook 작업 완료 응답을 전달한다.
12. Prestart Hook 작업이 완료를 전달받은 Container Init Process는 `pivot_root()` System Call을 통해서 Container의 Root Filesystem을 실제 Container Root Filesystem으로 변경하고, `exec()` System Call을 통해서 Container의 Entrypoint Command를 실행한다.

```json {caption="[File 3] OCI Runtime Spec in Legacy Mode Example", linenos=table}
{
    "hooks": {
        "poststart": [],
        "poststop": [],
        "prestart": [{  # Modified by nvidia-container-runtime CLI
            "args": ["/usr/bin/nvidia-container-runtime-hook", "prestart"],
            "path": "/usr/bin/nvidia-container-runtime-hook"
        }]
        ...
    },
    "process": {
        "env": [
            "NVIDIA_VISIBLE_DEVICES=all"  # Requested by ctr CLI or dockerd
        ]
    }
    ...
}
```

[File 3]은 OCI Runtime Spec의 예시를 나타내고 있다. `containerd`는 `ctr` CLI 또는 `dockerd`가 Container 생성 요청을 전달할 때, `NVIDIA_VISIBLE_DEVICES` 환경 변수를 설정하기 때문에, OCI Runtime Spec의 환경 변수에 `NVIDIA_VISIBLE_DEVICES` 환경 변수를 추가하여 생성한다. 이후에 `nvidia-container-runtime`에 의해서 OCI Runtime Spec의 Prestart Hook에 `nvidia-container-runtime-hook` CLI를 실행하기 위한 설정이 추가된다.

`nvidia-container-runtime` CLI는 OCI Runtime Spec의 Prestart Hook에 `nvidia-container-runtime-hook` CLI를 실행하기 위한 설정을 추가한다. `nvidia-container-runtime-hook` CLI의 Argument는 `prestart`로 고정되며, Container의 환경 변수에는 NVIDIA GPU, CUDA 관련 환경 변수가 추가된다. 예를 들어 `NVIDIA_VISIBLE_DEVICES` 환경 변수의 경우 Container에게 노출될 NVIDIA GPU의 지정하는 환경 변수이다. [Figure 2]의 경우에서는 Docker에서 모든 NVIDIA GPU를 이용하도록 `--gpu all` 설정을 수행하였기 때문에 `NVIDIA_VISIBLE_DEVICES` 환경 변수에도 `all`이 설정된다.

```shell {caption="[Shell 1] Check Bind Mount and Device File and Environment Variable in NVIDIA GPU Container"}
# Check bind mount
$ mount 
...
tmpfs on /proc/driver/nvidia type tmpfs (rw,nosuid,nodev,noexec,relatime,seclabel,mode=555)
/dev/nvme0n1p1 on /usr/bin/nvidia-smi type xfs (ro,nosuid,nodev,noatime,seclabel,attr2,inode64,logbufs=8,logbsize=32k,sunit=1024,swidth=1024,noquota)
/dev/nvme0n1p1 on /usr/bin/nvidia-debugdump type xfs (ro,nosuid,nodev,noatime,seclabel,attr2,inode64,logbufs=8,logbsize=32k,sunit=1024,swidth=1024,noquota)
/dev/nvme0n1p1 on /usr/bin/nvidia-persistenced type xfs (ro,nosuid,nodev,noatime,seclabel,attr2,inode64,logbufs=8,logbsize=32k,sunit=1024,swidth=1024,noquota)
/dev/nvme0n1p1 on /usr/bin/nv-fabricmanager type xfs (ro,nosuid,nodev,noatime,seclabel,attr2,inode64,logbufs=8,logbsize=32k,sunit=1024,swidth=1024,noquota)
/dev/nvme0n1p1 on /usr/bin/nvidia-cuda-mps-control type xfs (ro,nosuid,nodev,noatime,seclabel,attr2,inode64,logbufs=8,logbsize=32k,sunit=1024,swidth=1024,noquota)
/dev/nvme0n1p1 on /usr/bin/nvidia-cuda-mps-server type xfs (ro,nosuid,nodev,noatime,seclabel,attr2,inode64,logbufs=8,logbsize=32k,sunit=1024,swidth=1024,noquota)
/dev/nvme0n1p1 on /usr/lib64/libnvidia-ml.so.580.126.09 type xfs (ro,nosuid,nodev,noatime,seclabel,attr2,inode64,logbufs=8,logbsize=32k,sunit=1024,swidth=1024,noquota)
/dev/nvme0n1p1 on /usr/lib64/libnvidia-cfg.so.580.126.09 type xfs (ro,nosuid,nodev,noatime,seclabel,attr2,inode64,logbufs=8,logbsize=32k,sunit=1024,swidth=1024,noquota)
/dev/nvme0n1p1 on /usr/lib64/libcuda.so.580.126.09 type xfs (ro,nosuid,nodev,noatime,seclabel,attr2,inode64,logbufs=8,logbsize=32k,sunit=1024,swidth=1024,noquota)
/dev/nvme0n1p1 on /usr/lib64/libcudadebugger.so.580.126.09 type xfs (ro,nosuid,nodev,noatime,seclabel,attr2,inode64,logbufs=8,logbsize=32k,sunit=1024,swidth=1024,noquota)
/dev/nvme0n1p1 on /usr/lib64/libnvidia-opencl.so.580.126.09 type xfs (ro,nosuid,nodev,noatime,seclabel,attr2,inode64,logbufs=8,logbsize=32k,sunit=1024,swidth=1024,noquota)
/dev/nvme0n1p1 on /usr/lib64/libnvidia-gpucomp.so.580.126.09 type xfs (ro,nosuid,nodev,noatime,seclabel,attr2,inode64,logbufs=8,logbsize=32k,sunit=1024,swidth=1024,noquota)
/dev/nvme0n1p1 on /usr/lib64/libnvidia-ptxjitcompiler.so.580.126.09 type xfs (ro,nosuid,nodev,noatime,seclabel,attr2,inode64,logbufs=8,logbsize=32k,sunit=1024,swidth=1024,noquota)
/dev/nvme0n1p1 on /usr/lib64/libnvidia-allocator.so.580.126.09 type xfs (ro,nosuid,nodev,noatime,seclabel,attr2,inode64,logbufs=8,logbsize=32k,sunit=1024,swidth=1024,noquota)
/dev/nvme0n1p1 on /usr/lib64/libnvidia-pkcs11.so.580.126.09 type xfs (ro,nosuid,nodev,noatime,seclabel,attr2,inode64,logbufs=8,logbsize=32k,sunit=1024,swidth=1024,noquota)
/dev/nvme0n1p1 on /usr/lib64/libnvidia-pkcs11-openssl3.so.580.126.09 type xfs (ro,nosuid,nodev,noatime,seclabel,attr2,inode64,logbufs=8,logbsize=32k,sunit=1024,swidth=1024,noquota)
/dev/nvme0n1p1 on /usr/lib64/libnvidia-nvvm.so.580.126.09 type xfs (ro,nosuid,nodev,noatime,seclabel,attr2,inode64,logbufs=8,logbsize=32k,sunit=1024,swidth=1024,noquota)
/dev/nvme0n1p1 on /lib/firmware/nvidia/580.126.09/gsp_ga10x.bin type xfs (ro,nosuid,nodev,noatime,seclabel,attr2,inode64,logbufs=8,logbsize=32k,sunit=1024,swidth=1024,noquota)
/dev/nvme0n1p1 on /lib/firmware/nvidia/580.126.09/gsp_tu10x.bin type xfs (ro,nosuid,nodev,noatime,seclabel,attr2,inode64,logbufs=8,logbsize=32k,sunit=1024,swidth=1024,noquota)
tmpfs on /run/nvidia-persistenced/socket type tmpfs (rw,nosuid,nodev,noexec,seclabel,size=38119072k,nr_inodes=819200,mode=755)
devtmpfs on /dev/nvidiactl type devtmpfs (ro,nosuid,noexec,seclabel,size=4096k,nr_inodes=23820204,mode=755)
devtmpfs on /dev/nvidia-uvm type devtmpfs (ro,nosuid,noexec,seclabel,size=4096k,nr_inodes=23820204,mode=755)
devtmpfs on /dev/nvidia-uvm-tools type devtmpfs (ro,nosuid,noexec,seclabel,size=4096k,nr_inodes=23820204,mode=755)
devtmpfs on /dev/nvidia2 type devtmpfs (ro,nosuid,noexec,seclabel,size=4096k,nr_inodes=23820204,mode=755)
proc on /proc/driver/nvidia/gpus/0000:3c:00.0 type proc (ro,nosuid,nodev,noexec,relatime)
devtmpfs on /dev/nvidia3 type devtmpfs (ro,nosuid,noexec,seclabel,size=4096k,nr_inodes=23820204,mode=755)
proc on /proc/driver/nvidia/gpus/0000:3e:00.0 type proc (ro,nosuid,nodev,noexec,relatime)
devtmpfs on /dev/nvidia1 type devtmpfs (ro,nosuid,noexec,seclabel,size=4096k,nr_inodes=23820204,mode=755)
proc on /proc/driver/nvidia/gpus/0000:3a:00.0 type proc (ro,nosuid,nodev,noexec,relatime)
devtmpfs on /dev/nvidia0 type devtmpfs (ro,nosuid,noexec,seclabel,size=4096k,nr_inodes=23820204,mode=755)
proc on /proc/driver/nvidia/gpus/0000:38:00.0 type proc (ro,nosuid,nodev,noexec,relatime)
...

# Check device files
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

# Check environment variable
$ printenv | grep NVIDIA
NVIDIA_VISIBLE_DEVICES=all
...
```

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

[Shell 1]은 Container 내부에서 Bind Mount, Device File, 환경 변수를 확인하는 예시를 나타내고 있다. `mount` 명령어를 통해서 GPU Device File 및 CUDA Library/Tool을 Bind Mount를 통해서 Container 내부에 주입된걸 확인할 수 있다. 또한 `printenv` 명령어를 통해서 Container App에 `NVIDIA_VISIBLE_DEVICES` 환경 변수가 주입된 것도 확인할 수 있다. [Shell 2]는 Container 내부에서 GPU 접근을 허용하기 위한 Cgroup의 Device List 예시를 나타내고 있다.

#### 1.2.2. CDI Mode의 GPU 할당 과정

```yaml {caption="[File 4] /etc/cdi/nvidia.yaml Example", linenos=table}
cdiVersion: 0.5.0
kind: nvidia.com/gpu
devices:
  - name: "0"
    containerEdits:
      deviceNodes:
        - path: /dev/nvidia0
        - path: /dev/dri/card1
        - path: /dev/dri/renderD128
      hooks:
        - hookName: createContainer
          path: /usr/bin/nvidia-cdi-hook
          args:
            - nvidia-cdi-hook
            - create-symlinks
            - --link
            - ../card1::/dev/dri/by-path/pci-0000:38:00.0-card
            - --link
            - ../renderD128::/dev/dri/by-path/pci-0000:38:00.0-render
          env:
            - NVIDIA_CTK_DEBUG=false

  - name: "1"
    containerEdits:
      deviceNodes:
        - path: /dev/nvidia1
        - path: /dev/dri/card2
        - path: /dev/dri/renderD129
      hooks:
        - hookName: createContainer
          path: /usr/bin/nvidia-cdi-hook
          args:
            - nvidia-cdi-hook
            - create-symlinks
            - --link
            - ../card2::/dev/dri/by-path/pci-0000:3a:00.0-card
            - --link
            - ../renderD129::/dev/dri/by-path/pci-0000:3a:00.0-render
          env:
            - NVIDIA_CTK_DEBUG=false

  - name: "2"
    containerEdits:
      deviceNodes:
        - path: /dev/nvidia2
        - path: /dev/dri/card3
        - path: /dev/dri/renderD130
      hooks:
        - hookName: createContainer
          path: /usr/bin/nvidia-cdi-hook
          args:
            - nvidia-cdi-hook
            - create-symlinks
            - --link
            - ../card3::/dev/dri/by-path/pci-0000:3c:00.0-card
            - --link
            - ../renderD130::/dev/dri/by-path/pci-0000:3c:00.0-render
          env:
            - NVIDIA_CTK_DEBUG=false

  - name: "3"
    containerEdits:
      deviceNodes:
        - path: /dev/nvidia3
        - path: /dev/dri/card4
        - path: /dev/dri/renderD131
      hooks:
        - hookName: createContainer
          path: /usr/bin/nvidia-cdi-hook
          args:
            - nvidia-cdi-hook
            - create-symlinks
            - --link
            - ../card4::/dev/dri/by-path/pci-0000:3e:00.0-card
            - --link
            - ../renderD131::/dev/dri/by-path/pci-0000:3e:00.0-render
          env:
            - NVIDIA_CTK_DEBUG=false

  - name: GPU-3e953d37-558d-fb20-8eca-25de8b98f5a7
    containerEdits:
      deviceNodes:
        - path: /dev/nvidia0
        - path: /dev/dri/card1
        - path: /dev/dri/renderD128
      hooks:
        - hookName: createContainer
          path: /usr/bin/nvidia-cdi-hook
          args:
            - nvidia-cdi-hook
            - create-symlinks
            - --link
            - ../card1::/dev/dri/by-path/pci-0000:38:00.0-card
            - --link
            - ../renderD128::/dev/dri/by-path/pci-0000:38:00.0-render
          env:
            - NVIDIA_CTK_DEBUG=false

  - name: GPU-78744930-b3ce-0ddd-4a63-f730116fc653
    containerEdits:
      deviceNodes:
        - path: /dev/nvidia1
        - path: /dev/dri/card2
        - path: /dev/dri/renderD129
      hooks:
        - hookName: createContainer
          path: /usr/bin/nvidia-cdi-hook
          args:
            - nvidia-cdi-hook
            - create-symlinks
            - --link
            - ../card2::/dev/dri/by-path/pci-0000:3a:00.0-card
            - --link
            - ../renderD129::/dev/dri/by-path/pci-0000:3a:00.0-render
          env:
            - NVIDIA_CTK_DEBUG=false

  - name: GPU-7c33d7b8-8cc2-676e-7678-b9a86d12cd93
    containerEdits:
      deviceNodes:
        - path: /dev/nvidia3
        - path: /dev/dri/card4
        - path: /dev/dri/renderD131
      hooks:
        - hookName: createContainer
          path: /usr/bin/nvidia-cdi-hook
          args:
            - nvidia-cdi-hook
            - create-symlinks
            - --link
            - ../card4::/dev/dri/by-path/pci-0000:3e:00.0-card
            - --link
            - ../renderD131::/dev/dri/by-path/pci-0000:3e:00.0-render
          env:
            - NVIDIA_CTK_DEBUG=false

  - name: GPU-8a73f553-110d-eaae-45ef-751617ac723c
    containerEdits:
      deviceNodes:
        - path: /dev/nvidia2
        - path: /dev/dri/card3
        - path: /dev/dri/renderD130
      hooks:
        - hookName: createContainer
          path: /usr/bin/nvidia-cdi-hook
          args:
            - nvidia-cdi-hook
            - create-symlinks
            - --link
            - ../card3::/dev/dri/by-path/pci-0000:3c:00.0-card
            - --link
            - ../renderD130::/dev/dri/by-path/pci-0000:3c:00.0-render
          env:
            - NVIDIA_CTK_DEBUG=false
...
containerEdits:
  mounts:
    - hostPath: /usr/bin/nvidia-smi
      containerPath: /usr/bin/nvidia-smi
      options:
        - ro
        - nosuid
        - nodev
        - rbind
        - rprivate
    - hostPath: /usr/lib64/libcuda.so.580.126.09
      containerPath: /usr/lib64/libcuda.so.580.126.09
      options:
        - ro
        - nosuid
        - nodev
        - rbind
        - rprivate
    - hostPath: /usr/lib64/libnvidia-ml.so.580.126.09
      containerPath: /usr/lib64/libnvidia-ml.so.580.126.09
      options:
        - ro
        - nosuid
        - nodev
        - rbind
        - rprivate
...
```

CDI (Container Device Interface)는 GPU, NPU와 같은 특수 Device를 Container에게 할당하기 위한 Spec 파일을 위한 Interface이다. [File 4]는 NVIDIA GPU를 위한 CDI를 준수하는 Spec 파일 예시를 나타내고 있다. CDI Spec 파일은 YAML 형식으로 작성되며 Container에게 GPU를 할당하기 위한 Device 파일 및 CUDA Library/Tool을 Bind Mount 정보가 포함되어 있는것을 확인할 수 있다. NVIDIA CDI Spec 파일은 `nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml` 명령어를 통해서 생성할 수 있다.

{{< figure caption="[Figure 4] NVIDIA GPU Container Init in CDI Mode" src="images/gpu-container-init-cdi.png" width="900px" >}}

[Figure 4]는 CDI Mode의 GPU 할당 과정을 나타내고 있다. `nvidia-container-runtime` CLI는 CDI Mode로 동작하는 경우에 CDI Spec File을 읽어 GPU 정보를 확인하고, `NVIDIA_VISIBLE_DEVICES` 환경 변수에 따라서 OCI Runtime Spec에 GPU Device File 및 CUDA Library/Tool을 Bind Mount 정보를 주입하여 Container를 생성한다. `nvidia-container-runtime` CLI가 직접 GPU를 위한 OCI Runtiem Spec을 변경하는 방식이기 때문에, prestart hook 없이 Container를 생성할 수 있다.

```json {caption="[File 5] OCI Runtime Spec Example in CDI Mode", linenos=table}
{
    "linux": {
        "devices": [ # Injected by nvidia-container-runtime with CDI
            {
                "path": "/dev/nvidia0",
                "type": "c",
                "major": 195,
                "minor": 0,
                "fileMode": 438,
                "uid": 0,
                "gid": 0
            },
            {
                "path": "/dev/nvidia1",
                "type": "c",
                "major": 195,
                "minor": 1,
                "fileMode": 438,
                "uid": 0,
                "gid": 0
            },
            {
                "path": "/dev/nvidia2",
                "type": "c",
                "major": 195,
                "minor": 2,
                "fileMode": 438,
                "uid": 0,
                "gid": 0
            },
            {
                "path": "/dev/nvidia3",
                "type": "c",
                "major": 195,
                "minor": 3,
                "fileMode": 438,
                "uid": 0,
                "gid": 0
            },
            {
                "path": "/dev/nvidiactl",
                "type": "c",
                "major": 195,
                "minor": 255
            },
            {
                "path": "/dev/nvidia-uvm",
                "type": "c",
                "major": 510,
                "minor": 0
            }
            ...
        ],
    },
    "mounts": [ # Injected by nvidia-container-runtime with CDI
        {
            "source": "/usr/lib64/libcuda.so.580.126.09",
            "destination": "/usr/lib64/libcuda.so.580.126.09",
            "options": ["bind", "ro"]
        },
        {
            "source": "/usr/lib64/libnvidia-ml.so.580.126.09",
            "destination": "/usr/lib64/libnvidia-ml.so.580.126.09",
            "options": ["bind", "ro"]
        },
        {
            "source": "/usr/bin/nvidia-smi",
            "destination": "/usr/bin/nvidia-smi",
            "options": ["bind", "ro"]
        },
        ...
    ],
    "process": {
        "env": [
            "NVIDIA_VISIBLE_DEVICES=all"
        ]
    }
...
}
```

[File 5]는 `nvidia-container-runtime` CLI이 CDI Mode에서 GPU를 할당하기 위해 관련 설정을 주입한 OCI Runtime Spec의 예시를 나타내고 있다. GPU Device File 및 CUDA Library/Tool을 Bind Mount 정보가 주입된 것을 확인할 수 있다.

## 2. 참조

* [https://devblogs.nvidia.com/gpu-containers-runtime/](https://devblogs.nvidia.com/gpu-containers-runtime/)
* [https://gitlab.com/nvidia/container-toolkit/toolkit](https://gitlab.com/nvidia/container-toolkit/toolkit)
* [https://gitlab.com/nvidia/container-toolkit/libnvidia-container/](https://gitlab.com/nvidia/container-toolkit/libnvidia-container/)
* [https://github.com/opencontainers/runtime-spec/blob/master/config.md#posix-platform-hooks](https://github.com/opencontainers/runtime-spec/blob/master/config.md#posix-platform-hooks)
* [https://docs.nvidia.com/deploy/pdf/CUDA_Multi_Process_Service_Overview.pdf](https://docs.nvidia.com/deploy/pdf/CUDA_Multi_Process_Service_Overview.pdf)

---
title: Container NVIDIA GPU
---

This document analyzes techniques for allocating NVIDIA GPUs to containers.

## 1. Container NVIDIA GPU

### 1.1. NVIDIA GPU Container Architecture

{{< figure caption="[Figure 1] NVIDIA GPU Container Architecture" src="images/gpu-container-architecture.png" width="900px" >}}

NVIDIA GPUs can be allocated to containers to enable containers to use NVIDIA GPUs. Docker version 19.03 introduced the GPU option (`--gpu`) that can be used to allocate NVIDIA GPUs to containers. [Figure 1] shows containers with NVIDIA GPU configuration completed through the GPU option. Each container can use not only one GPU but also multiple GPUs. Additionally, containers can use not only dedicated GPUs allocated exclusively to them but also shared GPUs shared with other containers.

Container A uses NVIDIA GPUs 0 and 1, Container B uses NVIDIA GPUs 0, 2, and 3, and Container C uses NVIDIA GPU 3. GPUs 0, 1, and 3 are used as shared GPUs, while GPU 2 is used as a dedicated GPU. Each container can be created using the following Docker commands. You can pass a single GPU number or multiple GPU numbers separated by `,` to the `--gpu` option.

* Container A : `docker run --gpu 0,1 --name a nvidia/cuda:12.4-base-ubuntu22.04`
* Container B : `docker run --gpu 0,2,3 --name b nvidia/cuda:12.4-base-ubuntu22.04`
* Container C : `docker run --gpu 3 --name c nvidia/cuda:12.4-base-ubuntu22.04`

When `--gpu all` is configured, the container can use all NVIDIA GPUs. Shared GPUs utilize **Time-Slicing** or **MPS (Multi Process Service)** features provided by NVIDIA GPUs, allowing multiple containers to share and use a single NVIDIA GPU.

To allocate GPUs to containers, the **NVIDIA Container Toolkit** must be utilized. The NVIDIA Container Toolkit provides `nvidia-container-runtime`, `nvidia-container-runtime-hook`, and `nvidia-container-cli` CLIs, and the container runtime allocates GPUs to containers through the provided CLIs. The NVIDIA Container Toolkit performs the following roles:

* Injects device files (`/dev/nvidiaX`, `/dev/nvidia-uvm`, `/dev/nvidia-uvm-tools`, `/dev/nvidiactl`) into the container through **bind mount** so that applications inside the container can access the GPUs allocated to the container.
* Injects CUDA libraries/tools into the container through **bind mount** so that applications inside the container can utilize the GPUs allocated to the container.
* Configures cgroups so that GPUs allocated to the container can be accessed from inside the container.
* Sets the `NVIDIA_VISIBLE_DEVICES` environment variable so that applications and CUDA libraries/tools inside the container can recognize the GPUs allocated to the container.

### 1.2. NVIDIA GPU Allocation Process

To allocate GPUs to containers, `containerd` must be configured to execute the `nvidia-container-runtime` CLI instead of `containerd-shim`. The `nvidia-container-runtime` CLI not only performs the role of making the container's stdin/stdout/stderr accessible from other processes through named pipes and delivering the container init process's exit code to `containerd`, but also performs additional configuration to allocate GPUs to containers.

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

[File 1] shows how to configure `containerd` to execute the `nvidia-container-runtime` CLI. You can see that the `default_runtime_name` parameter is set to `nvidia`, and the spec file required for the `nvidia` runtime and the path to the `nvidia-container-runtime` CLI are configured.

```toml {caption="[File 2] /etc/nvidia-container-runtime/config.toml Example", linenos=table}
[nvidia-container-runtime]
mode = "legacy | cdi | auto"

[nvidia-container-runtime.cdi]
spec-dirs = ["/etc/cdi", "/var/run/cdi"]
```

The `nvidia-container-runtime` CLI has two modes: Legacy Mode, which utilizes the **OCI Runtime Spec's Prestart Hook** feature, and CDI Mode, which utilizes **CDI (Container Device Interface)**. [File 2] shows the configuration file for `nvidia-container-runtime` to set the mode. You can set `mode` to one of `legacy`, `cdi`, or `auto`. `legacy` is the existing method that utilizes the OCI Runtime Spec's Prestart Hook feature, and `cdi` is the latest method that utilizes **CDI (Container Device Interface)**. `auto` automatically selects one of `legacy` or `cdi` based on system configuration, and if CDI spec files exist in `spec-dirs`, it uses CDI mode; otherwise, it uses Legacy mode.

#### 1.2.1. GPU Allocation Process in Legacy Mode

{{< figure caption="[Figure 3] NVIDIA GPU Container Init in Legacy Mode" src="images/gpu-container-init-legacy.png" width="900px" >}}

[Figure 3] shows the Legacy GPU allocation process. The Legacy GPU allocation process is a method that actively utilizes the **OCI Runtime Spec's Prestart Hook** feature. Prestart Hook refers to a command that runs before the container's entrypoint command is executed. [Figure 3] performs the following process:

1. The `ctr` CLI or `dockerd` passes a container creation request to `containerd` along with GPU information to allocate to the container set in the `NVIDIA_VISIBLE_DEVICES` environment variable.
2. `containerd` creates an OCI Runtime Config file according to the request.
3. Subsequently, `containerd` executes the `nvidia-container-runtime` CLI according to `containerd`'s config.
4. The `nvidia-container-runtime` CLI adds settings to execute the `nvidia-container-runtime-hook` CLI in the Prestart Hook of the OCI Runtime Config file.
5. Subsequently, the `nvidia-container-runtime` CLI executes the `runc` CLI to create the container.
6. The `runc` CLI creates a Container Init Process through the `clone()` system call to set up namespaces and root filesystem for the container according to the OCI Runtime Spec, and prepares the root filesystem using OverlayFS.
7. The Container Init Process created through the `clone()` system call requests the `runc` CLI to execute the Prestart Hook through a FIFO named pipe.
8. The `runc` CLI executes the `nvidia-container-runtime-hook` CLI according to the OCI Runtime Spec.
9. The `nvidia-container-runtime-hook` CLI passes container information and NVIDIA GPU information (`NVIDIA_VISIBLE_DEVICES` environment variable) to configure in the container as parameters to the `nvidia-container-cli` CLI based on the OCI Runtime Spec file and executes the `nvidia-container-cli` CLI. The `nvidia-container-cli` CLI is the entity that actually configures the container's NVIDIA GPU, while the `nvidia-container-runtime-hook` CLI only performs the role of an **interface** connecting the OCI Runtime Spec and the `nvidia-container-cli` CLI.
10. The `nvidia-container-cli` CLI injects device files and CUDA libraries/tools into the container through bind mount via the internal `libnvidia-container` library based on the received container and NVIDIA GPU information to configure in the container. It also configures cgroups to allow GPU access from inside the container and, if necessary, loads kernel modules required for NVIDIA GPU operation.
11. When the Prestart Hook work is completed, the `runc` CLI sends a completion response to the Container Init Process through the FIFO named pipe.
12. The Container Init Process that received the Prestart Hook completion changes the container's root filesystem to the actual container root filesystem through the `pivot_root()` system call and executes the container's entrypoint command through the `exec()` system call.

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

[File 3] shows an example of the OCI Runtime Spec. When `containerd` receives a container creation request from the `ctr` CLI or `dockerd`, it sets the `NVIDIA_VISIBLE_DEVICES` environment variable, so it creates the OCI Runtime Spec with the `NVIDIA_VISIBLE_DEVICES` environment variable added to the environment variables. Subsequently, settings to execute the `nvidia-container-runtime-hook` CLI are added to the Prestart Hook of the OCI Runtime Spec by `nvidia-container-runtime`.

The `nvidia-container-runtime` CLI adds settings to execute the `nvidia-container-runtime-hook` CLI in the Prestart Hook of the OCI Runtime Spec. The argument for the `nvidia-container-runtime-hook` CLI is fixed to `prestart`, and NVIDIA GPU and CUDA-related environment variables are added to the container's environment variables. For example, the `NVIDIA_VISIBLE_DEVICES` environment variable specifies which NVIDIA GPUs will be exposed to the container. In [Figure 2], since Docker was configured to use all NVIDIA GPUs with `--gpu all`, the `NVIDIA_VISIBLE_DEVICES` environment variable is also set to `all`.

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
proc on /proc/driver/nvidia/gpus/0000:3a:00.0 type proc (ro,nosuid,noexec,seclabel,size=4096k,nr_inodes=23820204,mode=755)
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

[Shell 1] shows an example of checking bind mounts, device files, and environment variables inside a container. You can see that GPU device files and CUDA libraries/tools are injected into the container through bind mount via the `mount` command. You can also see that the `NVIDIA_VISIBLE_DEVICES` environment variable is injected into the container application through the `printenv` command. [Shell 2] shows an example of the device list in the cgroup for allowing GPU access from inside the container.

#### 1.2.2. GPU Allocation Process in CDI Mode

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

CDI (Container Device Interface) is an interface for spec files to allocate special devices such as GPUs and NPUs to containers. [File 4] shows an example of a CDI-compliant spec file for NVIDIA GPUs. CDI spec files are written in YAML format, and you can see that they include device files and bind mount information for CUDA libraries/tools to allocate GPUs to containers. NVIDIA CDI spec files can be generated using the `nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml` command.

{{< figure caption="[Figure 4] NVIDIA GPU Container Init in CDI Mode" src="images/gpu-container-init-cdi.png" width="900px" >}}

[Figure 4] shows the GPU allocation process in CDI Mode. When the `nvidia-container-runtime` CLI operates in CDI Mode, it reads CDI spec files to check GPU information and injects GPU device files and bind mount information for CUDA libraries/tools into the OCI Runtime Spec according to the `NVIDIA_VISIBLE_DEVICES` environment variable to create the container. Since the `nvidia-container-runtime` CLI directly modifies the OCI Runtime Spec for GPUs, containers can be created without prestart hooks.

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

[File 5] shows an example of the OCI Runtime Spec with related settings injected by the `nvidia-container-runtime` CLI in CDI Mode to allocate GPUs. You can see that GPU device files and bind mount information for CUDA libraries/tools have been injected.

## 2. References

* [https://devblogs.nvidia.com/gpu-containers-runtime/](https://devblogs.nvidia.com/gpu-containers-runtime/)
* [https://gitlab.com/nvidia/container-toolkit/toolkit](https://gitlab.com/nvidia/container-toolkit/toolkit)
* [https://gitlab.com/nvidia/container-toolkit/libnvidia-container/](https://gitlab.com/nvidia/container-toolkit/libnvidia-container/)
* [https://github.com/opencontainers/runtime-spec/blob/master/config.md#posix-platform-hooks](https://github.com/opencontainers/runtime-spec/blob/master/config.md#posix-platform-hooks)
* [https://docs.nvidia.com/deploy/pdf/CUDA_Multi_Process_Service_Overview.pdf](https://docs.nvidia.com/deploy/pdf/CUDA_Multi_Process_Service_Overview.pdf)

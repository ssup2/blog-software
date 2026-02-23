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

Each container has device node files to access the GPUs allocated to it. Shared GPUs utilize **Time-Slicing** or **MPS (Multi Process Service)** features provided by NVIDIA GPUs, allowing multiple containers to share and use a single NVIDIA GPU.

### 1.2. NVIDIA GPU Allocation Process

To allocate NVIDIA GPUs to containers, the **OCI Runtime Spec's Prestart Hook** feature is actively utilized. Prestart Hook refers to a command that runs before the container's entrypoint command is executed.

{{< figure caption="[Figure 2] NVIDIA GPU Container OCI Runtime Spec" src="images/gpu-container-runtime-spec.png" width="900px" >}}

[Figure 2] shows the OCI Runtime Spec generated when creating a container using Docker's GPU option. When Docker detects the GPU option, settings to execute the `nvidia-container-runtime-hook` CLI are added to the Prestart Hook of the OCI Runtime Spec. The argument for the `nvidia-container-runtime-hook` CLI is fixed to `prestart`, and NVIDIA GPU and CUDA-related environment variables are added to the container's environment variables. For example, the `NVIDIA_VISIBLE_DEVICES` environment variable specifies which NVIDIA GPUs will be exposed to the container. In [Figure 2], since Docker was configured to use all NVIDIA GPUs with `--gpu all`, the `NVIDIA_VISIBLE_DEVICES` environment variable is also set to `all`.

{{< figure caption="[Figure 3] NVIDIA GPU Container Init" src="images/gpu-container-init.png" width="900px" >}}

[Figure 3] shows the process where the `runc` CLI creates a container and configures the GPU based on the OCI Runtime Spec created in [Figure 2].

1. The `runc` CLI creates a Container Init Process through the `clone()` system call to create namespaces for the container and set up rootfs, and configures the container's root filesystem through OverlayFS.
2. The Container Init Process created through the `clone()` system call requests the `runc` CLI to execute the Prestart Hook through a FIFO named pipe.
3. In response to the Container Init Process's request, the `runc` CLI executes the `nvidia-container-runtime-hook` CLI as specified in the Prestart Hook of the OCI Runtime Spec.
4. The `nvidia-container-runtime-hook` CLI passes container and NVIDIA GPU information as parameters to the `nvidia-container-cli` CLI based on the OCI Runtime Spec file and executes the `nvidia-container-cli` CLI. The `nvidia-container-cli` CLI is the entity that actually configures the container's NVIDIA GPU, while the `nvidia-container-runtime-hook` CLI only performs the role of an **interface** connecting the OCI Runtime Spec and the `nvidia-container-cli` CLI.
5. The `nvidia-container-cli` CLI creates device node files based on the received information and, if necessary, also loads kernel modules required for NVIDIA GPU operation.
6. When the Prestart Hook work is completed, the `runc` CLI sends a completion response to the Container Init Process through the FIFO named pipe.
7. The Container Init Process that received the Prestart Hook completion changes the container's root filesystem to the actual container root filesystem through the `pivot_root()` system call and executes the container's entrypoint command through the `exec()` system call.

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

When the `runc` CLI successfully completes the Prestart Hook work, device node files for NVIDIA GPUs are created inside the container. [Shell 1] shows the list of device node files inside a container with 4 GPUs available.

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

Additionally, cgroups are configured to allow GPU access from inside the container. [Shell 2] shows an example of the device list in the cgroup for allowing GPU access from inside the container.

## 2. References

* [https://devblogs.nvidia.com/gpu-containers-runtime/](https://devblogs.nvidia.com/gpu-containers-runtime/)
* [https://gitlab.com/nvidia/container-toolkit/toolkit](https://gitlab.com/nvidia/container-toolkit/toolkit)
* [https://gitlab.com/nvidia/container-toolkit/libnvidia-container/](https://gitlab.com/nvidia/container-toolkit/libnvidia-container/)
* [https://github.com/opencontainers/runtime-spec/blob/master/config.md#posix-platform-hooks](https://github.com/opencontainers/runtime-spec/blob/master/config.md#posix-platform-hooks)
* [https://docs.nvidia.com/deploy/pdf/CUDA_Multi_Process_Service_Overview.pdf](https://docs.nvidia.com/deploy/pdf/CUDA_Multi_Process_Service_Overview.pdf)

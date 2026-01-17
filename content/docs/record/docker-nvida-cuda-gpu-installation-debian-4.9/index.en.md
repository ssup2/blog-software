---
title: Docker NVIDIA CUDA GPU Installation / Debian 9 Environment
---

## 1. Installation Environment

* GPU : GTX 1060 (Pascal Architecture)
* OS : Debian 9, 4.9.0 Kernel, root User
* Software
  * Docker 19.03
  * NVIDIA Driver 440.44

## 2. Docker Installation

```shell
$ apt-get update
$ apt-get install apt-transport-https ca-certificates curl gnupg2 software-properties-common
$ curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
$ apt-key fingerprint 0EBFCD88
$ add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb-release -cs) stable"
$ apt-get update
$ apt-get install docker-ce docker-ce-cli containerd.io
$ docker version
Client: Docker Engine - Community
 Version:           19.03.5
...
Server: Docker Engine - Community
 Engine:
  Version:          19.03.5
...
```

Install Docker. You must install Docker Version 19.03 or higher.

## 3. NVIDIA Driver Installation

```shell
$ apt-get install linux-headers-$(uname -r)
```

Install Linux Header Packages for NVIDIA Driver installation.

```
$ chmod +x NVIDIA-Linux-x86-64-440.44.run 
$ ./NVIDIA-Linux-x86-64-440.44.run
```

Download a Stable NVIDIA Driver from https://www.nvidia.com/en-us/drivers/unix/. Install the NVIDIA Driver using the downloaded file.

## 4. NVIDIA Container Toolkit Installation

```
$ distribution=$(. /etc/os-release;echo $ID$VERSION-ID)
$ curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | apt-key add -
$ curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | tee /etc/apt/sources.list.d/nvidia-docker.list
$ apt-get update && apt-get install -y nvidia-container-toolkit
```

Install the NVIDIA Container Toolkit Package to install nvidia-container-runtime-hook, nvidia-container-toolkit, and nvidia-container-cli.

```
$ systemctl restart docker
```

Restart Docker to configure Docker to use the NVIDIA Container Toolkit.

## 5. Operation Verification

```
$ docker run --gpus all nvidia/cuda:9.0-base nvidia-smi
Sat Dec 14 17:27:38 2019
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 390.116                Driver Version: 390.116                   |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|===============================+======================+======================|
|   0  P106-100            Off  | 00000000:01:00.0 Off |                  N/A |
| 47%   47C    P0    28W / 120W |      0MiB /  6080MiB |      0%      Default |
+-------------------------------+----------------------+----------------------+
|   1  P106-100            Off  | 00000000:02:00.0 Off |                  N/A |
| 46%   45C    P0    29W / 120W |      0MiB /  6080MiB |      0%      Default |
+-------------------------------+----------------------+----------------------+
|   2  P106-100            Off  | 00000000:03:00.0 Off |                  N/A |
| 45%   41C    P0    29W / 120W |      0MiB /  6080MiB |      0%      Default |
+-------------------------------+----------------------+----------------------+
|   3  P106-100            Off  | 00000000:04:00.0 Off |                  N/A |
|  0%   40C    P0    27W / 120W |      0MiB /  6080MiB |      3%      Default |
+-------------------------------+----------------------+----------------------+

+-----------------------------------------------------------------------------+
| Processes:                                                       GPU Memory |
|  GPU       PID   Type   Process name                             Usage      |
|=============================================================================|
|  No running processes found                                                 |
+-----------------------------------------------------------------------------+
```

Obtain GPU information available in the container through the nvidia-smi command inside the Container.

## 6. References

* [https://collabnix.com/introducing-new-docker-cli-api-support-for-nvidia-gpus-under-docker-engine-19-03-0-beta-release/](https://collabnix.com/introducing-new-docker-cli-api-support-for-nvidia-gpus-under-docker-engine-19-03-0-beta-release/)
* [https://en.wikipedia.org/wiki/Direct-Rendering-Manager](https://en.wikipedia.org/wiki/Direct-Rendering-Manager)


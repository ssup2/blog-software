---
title: Docker NVIDIA CUDA GPU 설치 / Debian 9 환경
---

## 1. 설치 환경

* GPU : GTX 1060 (Pascal Architecture)
* OS : Debian 9, 4.9.0 Kernel, root User
* Software
  * Docker 19.03
  * NVIDIA Drvier 440.44

## 2. Docker 설치

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

Docker를 설치한다. 19.03 Version 이상의 Docker를 설치해야 한다.

## 3. NVIDIA Driver 설치

```shell
$ apt-get install linux-headers-$(uname -r)
```

NVIDIA Driver 설치를 위한 Linux Header Package를 설치한다.

```
$ chmod +x NVIDIA-Linux-x86-64-440.44.run 
$ ./NVIDIA-Linux-x86-64-440.44.run
```

https://www.nvidia.com/en-us/drivers/unix/ 에서 Stable NVIDIA Driver를 Download 한다. Download한 파일을 이용하여 NVIDIA Driver를 설치한다.

## 4. NVIDIA Container Toolkit 설치

```
$ distribution=$(. /etc/os-release;echo $ID$VERSION-ID)
$ curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | apt-key add -
$ curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | tee /etc/apt/sources.list.d/nvidia-docker.list
$ apt-get update && apt-get install -y nvidia-container-toolkit
```

NVIDIA Container Toolkit Package를 설치하여 nvidia-container-runtime-hook, nvidia-container-toolkit, nvidia-container-cli를 설치한다.

```
$ systemctl restart docker
```

Docker를 재시작하여 Docker에서 Nvida Container Toolkit을 이용하도록 설정한다.

## 5. 동작 확인

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

Container 안에서 nvidia-smi 명령어를 통해서 container에서 이용가능한 GPU 정보를 얻는다.

## 6. 참조

* [https://collabnix.com/introducing-new-docker-cli-api-support-for-nvidia-gpus-under-docker-engine-19-03-0-beta-release/](https://collabnix.com/introducing-new-docker-cli-api-support-for-nvidia-gpus-under-docker-engine-19-03-0-beta-release/)
* [https://en.wikipedia.org/wiki/Direct-Rendering-Manager](https://en.wikipedia.org/wiki/Direct-Rendering-Manager)
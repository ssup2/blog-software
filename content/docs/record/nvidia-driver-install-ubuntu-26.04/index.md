---
title: Nvidia Driver, CUDA 설치 / Ubuntu 26.04 환경
draft: true
---

## 1. 설치 환경

설치 환경은 다음과 같다.
* Ubuntu 26.04 LTS 64bit, root user
* Nvidia RTX 5060 Ti GPU 16GB
  * GPU Driver : 610.10

## 2. Nvidia Driver 설치

```shell
$ sudo apt update
$ sudo apt install build-essential linux-headers-$(uname -r)
```

Nivdia Driver를 위한 Kernel Package를 설치한다.

```shell
$ sudo apt install nvidia-driver-610-open
```

Nvidia Driver를 설치한다.

## 3. CUDA 설치

```shell
$ sudo apt install nvidia-cuda-toolkit
```

CUDA를 설치한다.

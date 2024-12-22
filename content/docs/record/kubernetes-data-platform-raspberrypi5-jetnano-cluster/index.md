---
title : Kubernetes Data Platform 구축 / Raspberry Pi 5, Jetson Nano Cluster 환경
draft : true
---

## 1. 설치 환경

{{< figure caption="[Figure 1] Cluster Spec" src="images/cluster-spec.png" width="1000px" >}}

{{< figure caption="[Figure 2] Cluster 구성 요소" src="images/cluster-component.png" width="1000px" >}}

## 2. OS 설치

### 2.1. Raspberry Pi 5

{{< figure caption="[Figure 3] Raspberry Pi Imager" src="images/raspberry-pi-imager-ubuntu-server.png" width="700px" >}}

**Raspberry Pi Imager**를 활용하여 **Ubuntu Server 24.04**를 설치한다.

{{< figure caption="[Figure 4] Raspberry Pi Imager General" src="images/raspberry-pi-imager-general.png" width="500px" >}}

{{< figure caption="[Figure 5] Raspberry Pi Imager Services" src="images/raspberry-pi-imager-services.png" width="500px" >}}

Host 이름, Username, Password, Timezone, SSH Server를 설정하고 OS Image를 uSD Card에 복사한다.

* Host 이름 : [Figure 1] 참조
* Username/Password : `temp`/`temp`

### 2.2. Jetson Nano

* [https://developer.nvidia.com/embedded/learn/get-started-jetson-nano-devkit#write](https://developer.nvidia.com/embedded/learn/get-started-jetson-nano-devkit#write)

## 3. Kubernetes Cluster 구성
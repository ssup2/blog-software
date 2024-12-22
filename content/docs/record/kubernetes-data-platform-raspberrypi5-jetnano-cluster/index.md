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

* Host 이름 : [Figure 1]의 Host 이름 참조
* Username/Password : `temp`/`temp`

### 2.2. Jetson Nano

Install Guide에 따라서 uSD Card에 OS를 설치한다.

* Install Guide : [https://developer.nvidia.com/embedded/learn/get-started-jetson-nano-devkit#write](https://developer.nvidia.com/embedded/learn/get-started-jetson-nano-devkit#write)

## 3. Network 설정

### 3.1. Raspberry Pi 5

`root` User로 진입한다.

```shell
(Raspberry Pi)$ sudo -s
(Raspberry Pi)#
```

[Figure 1]의 Network를 참조하여 `/etc/netplan/50-cloud-init.yaml` 파일에 다음과 같이 고정 IP를 설정한다.

```yaml {caption="[File 1] /etc/netplan/50-cloud-init.yaml"}
network:
    ethernets:
        eth0:
          addresses:
            - [IP Address]/24
          nameservers:
            addresses:
              - 8.8.8.8
          routes:
            - to: default
              via: 192.168.1.1
    version: 2
```

### 3.2. Jetson Nano

`root` User로 진입한다.

```shell
(Jetson Nano)$ sudo -s
(Jetson Nano)#
```

[Figure 1]의 Network를 참조하여 고정 IP를 설정한다.

```shell
(Jetson Nano)# nmcli con mod "Wired connection 1" \
  ipv4.addresses "[IP Address]/24" \
  ipv4.gateway "192.168.1.1" \
  ipv4.dns "8.8.8.8" \
  ipv4.method "manual"
```

## 4. Docker, kubelet 설치

### 3.1. Raspberry Pi 5

```shell
# Disable Swap
(Raspberry Pi)# swapoff -a
(Raspberry Pi)# sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
```

```shell
# Load module
(Raspberry Pi)# cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

(Raspberry Pi)# modprobe overlay
(Raspberry Pi)# modprobe br_netfilter

# Set sysctl parameter
(Raspberry Pi)# cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl parameter
(Raspberry Pi)# sysctl --system
```

```shell
# Install containerd
(Raspberry Pi)# apt install -y containerd
(Raspberry Pi)# mkdir -p /etc/containerd
(Raspberry Pi)# containerd config default | tee /etc/containerd/config.toml
(Raspberry Pi)# sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
(Raspberry Pi)# systemctl restart containerd.service
```

```shell
# Install kubelet
(Raspberry Pi)# apt-get update
(Raspberry Pi)# apt-get install -y apt-transport-https ca-certificates curl gnupg
(Raspberry Pi)# curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
(Raspberry Pi)# chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
(Raspberry Pi)# echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
(Raspberry Pi)# sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list
(Raspberry Pi)# apt-get update
(Raspberry Pi)# apt-get install -y kubelet kubeadm kubectl
```

## 5. Kubernetes Cluster 구성
---
title: Kubernetes Installation / Using kubeadm / Ubuntu 16.04 Environment
---

## 1. Installation Environment

The installation environment is as follows.
* VirtualBox 5.0.14r
  * Master Node: Ubuntu Desktop 16.04.2 64bit * 1
  * Worker Node: Ubuntu Server 16.04.2 64bit * 2
* Kubernetes 1.7.1
  * Network Plugin: flannel
  * Dashboard Addon: Dashboard
* kubeadm
  * When building a cluster environment using VMs, Kubernetes can be easily installed using kubeadm.
* Docker 1.12.6
  * Kubernetes recommends version 1.12.x.
* Password
  * For easy installation, all passwords required for Kubernetes installation are unified to **root**.
* Installation proceeds as the root user on all nodes.

## 2. Node Configuration

{{< figure caption="[Figure 1] Node Configuration Diagram for Kubernetes Installation" src="images/node-setting.png" width="900px" >}}

Create virtual Master and Worker nodes (VMs) as shown in [Figure 1] using VirtualBox.
* Hostname: Master Node - ubuntu01, Worker Node1 - ubuntu02, Worker Node2 - ubuntu03
* NAT: Build a 10.0.0.0/24 network using the "NAT network" provided by VirtualBox.
* Router: Build a 192.168.77.0/24 network using a router. (NAT)

### 2.1. Master Node

```text {caption="[File 1] Master Node - /etc/network/interfaces", linenos=table}
source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto enp0s3
iface enp0s3 inet static
address 10.0.0.11
netmask 255.255.255.0
gateway 10.0.0.1
dns-nameservers 8.8.8.8

auto enp0s8
iface enp0s8 inet static
address 192.168.77.170
netmask 255.255.255.0
gateway 192.168.77.1
dns-nameservers 8.8.8.8
```

Modify /etc/network/interfaces as shown in [File 1].

### 2.2. Worker Nodes

```text {caption="[File 2] Worker Node 01 - /etc/network/interfaces", linenos=table}
source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto enp0s3
iface enp0s3 inet static
address 10.0.0.31
netmask 255.255.255.0
gateway 10.0.0.1
dns-nameservers 8.8.8.8
```

Modify Worker Node 01's /etc/network/interfaces as shown in [File 2].

```text {caption="[File 3] Worker Node 02 - /etc/network/interfaces", linenos=table}
source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto enp0s3
iface enp0s3 inet static
address 10.0.0.41
netmask 255.255.255.0
gateway 10.0.0.1
dns-nameservers 8.8.8.8
```

Modify Worker Node 02's /etc/network/interfaces as shown in [File 3].

## 3. Package Installation

### 3.1. All Nodes

```shell
(All)$ sudo apt-get update
(All)$ sudo apt-get install apt-transport-https ca-certificates curl software-properties-common
(All)$ curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
(All)$ sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb-release -cs) stable"
(All)$ sudo apt-get update
(All)$ sudo apt-get install docker.io=1.12.6-0ubuntu1~16.04.1
```

Install Docker.

```shell
(All)$ apt-get update && apt-get install -y apt-transport-https curl
(All)$ curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
(All)$ echo deb http://apt.kubernetes.io/ kubernetes-xenial main > /etc/apt/sources.list.d/kubernetes.list
(All)$ apt-get update
(All)$ apt-get install -y kubelet kubeadm
```

Install kubelet and kubeadm.

### 3.2. Master Node

```shell
(Master)$ sudo snap install kubectl --classic
```

Install kubectl.

## 4. Cluster Setup

### 4.1. Master Node

```shell
(Master)$ kubeadm init --apiserver-advertise-address=10.0.0.11 --pod-network-cidr=10.244.0.0/16
...
kubeadm join --token 76f75a.6fbcc5e0e6e74c89 10.0.0.11:6443
```

Proceed with kubeadm initialization. After execution, you can obtain the key value. 10.0.0.11 is the Master IP of the NAT Network.

```shell
(Master)$ mkdir -p $HOME/.kube
(Master)$ sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
(Master)$ sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

Configure kubectl config.

```text {caption="[File 4] Master Node - ~/.bashrc", linenos=table}
if [ -f /etc/bash-completion ] && ! shopt -oq posix; then
    . /etc/bash-completion
fi

source <(kubectl completion bash)
```

Configure kubectl autocomplete. Add the content from [File 4] to ~/.bashrc.

```shell
(Master)$ kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel-rbac.yml
(Master)$ kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```

Install the Network Addon (flannel).

```shell
(Master)$ kubectl create -f https://git.io/kube-dashboard
```

Install the Dashboard Addon (Dashboard).

### 4.2. Worker Nodes

```shell
(Worker)$ kubeadm join --token 76f75a.6fbcc5e0e6e74c89 10.0.0.11:6443
```

Configure the cluster. Execute the **kubeadm join ~~** command that appears as a result of kubeadm init on all worker nodes.

### 4.3. Verification

```shell
(Master)$ kubectl get nodes
NAME       STATUS     AGE       VERSION
ubuntu01   Ready      41m       v1.7.1
ubuntu02   Ready      49s       v1.7.1
ubuntu03   Ready      55s       v1.7.1
```

Check the cluster from the Master Node.

```shell
(Master)$ kubectl proxy
```

After executing the kubectl proxy command, access **http://localhost:8001/ui** from the Master Node via a web browser.

## 5. References

* Kubernetes Installation: [https://kubernetes.io/docs/setup/independent/install-kubeadm/](https://kubernetes.io/docs/setup/independent/install-kubeadm/)
* Docker Installation: [https://docs.docker.com/engine/installation/linux/docker-ce/ubuntu/](https://docs.docker.com/engine/installation/linux/docker-ce/ubuntu/)
* flannel Issue: [https://github.com/coreos/flannel/issues/671](https://github.com/coreos/flannel/issues/671)


---
title: Kubernetes Installation / Using kubeadm / Ubuntu 18.04, Jetson Nano Cluster Environment
---

## 1. Installation Environment

{{< figure caption="[Figure 1] Kubernetes Installation Environment (Jetson Nano Cluster)" src="images/environment.png" width="900px" >}}

[Figure 1] shows the Kubernetes installation environment based on Jetson Nano Cluster. Detailed environment information is as follows.

* Kubernetes 1.18.14
  * Network Plugin : using calico or flannel or cilium
  * Dashboard Addon : using Dashboard
* kubeadm 1.18.14
  * When building a Cluster environment using VMs, Kubernetes can be easily installed using kubeadm.
* CNI
  * flannel 0.13.0
* Docker 19.03
* Node
  * Jetson Nano
    * r32.3.1 (Ubuntu 18.04)
    * Node 01 : Master Node
    * Node 02, 03, 04 : Worker Node

## 2. Node Configuration

### 2.1. All Node

```shell
(All)$ apt-get remove docker docker.io containerd runc nvidia-docker2
(All)$ apt-get update
(All)$ apt-get install apt-transport-https ca-certificates curl gnupg-agent software-properties-common
(All)$ curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
(All)$ add-apt-repository "deb [arch=arm64] https://download.docker.com/linux/ubuntu $(lsb-release -cs) stable"
(All)$ apt-get update
(All)$ apt-get install docker-ce docker-ce-cli containerd.io
```

Install Docker 19.03 Version for GPU usage.

```shell
(All)$ apt-get update && apt-get install -y apt-transport-https curl
(All)$ curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
(All)$ echo deb http://apt.kubernetes.io/ kubernetes-xenial main > /etc/apt/sources.list.d/kubernetes.list
(All)$ apt-get update
(All)$ apt-get install -y kubelet=1.18.14-00 kubeadm=1.18.14-00
```

Install kubelet and kubeadm.

```shell
(All)$ swapoff -a
(All)$ rm /etc/systemd/nvzramconfig.sh
```

Disable zram.

### 2.2. Master Node

```shell
(Master)$ kubeadm init --apiserver-advertise-address=192.168.0.41 --pod-network-cidr=10.244.0.0/16 --kubernetes-version=v1.18.14
...
kubeadm join 192.168.0.41:6443 --token x7tk20.4hp9x2x43g46ara5 --discovery-token-ca-cert-hash sha256:cab2cc0a4912164f45f502ad31f5d038974cf98ed10a6064d6632a07097fad79
(Master)$ mkdir -p $HOME/.kube
(Master)$ cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
(Master)$ chown $(id -u):$(id -g) $HOME/.kube/config
```

Initialize the Cluster on the Master Node.

### 2.3. Worker Node

```shell
(Worker)$ kubeadm join 10.0.0.10:6443 --token x7tk20.4hp9x2x43g46ara5 --discovery-token-ca-cert-hash sha256:cab2cc0a4912164f45f502ad31f5d038974cf98ed10a6064d6632a07097fad79
```

Add Workers to the Cluster using the "kubeadm join" command output from the Master Node on the Worker Node.

### 2.4. Verification

```shell
(Master)$ kubectl get nodes
NAME       STATUS     ROLES    AGE    VERSION
jetson01   NotReady   master   7m2s   v1.18.14
jetson02   NotReady   <none>   72s    v1.18.14
jetson03   NotReady   <none>   62s    v1.18.14
jetson04   NotReady   <none>   59s    v1.18.14
```

Check the Cluster from the Master Node. All Nodes should appear in the list. They remain in NotReady state because Network configuration is not set. Ready state can be verified after Network Plugin installation.

## 3. Flannel Network Plugin Installation

```shell
(Master)$ kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/v0.13.0/Documentation/kube-flannel.yml
```

Install the flannel Network Plugin on the Master Node.

```shell
(Master) # kubectl get nodes
NAME       STATUS   ROLES    AGE   VERSION
jetson01   Ready    master   18m   v1.18.14
jetson02   Ready    <none>   12m   v1.18.14
jetson03   Ready    <none>   12m   v1.18.14
jetson04   Ready    <none>   12m   v1.18.14
```

All Nodes can be verified to be in Ready state.

## 4. References

* Docker Installation : [https://docs.docker.com/engine/installation/linux/docker-ce/ubuntu/](https://docs.docker.com/engine/installation/linux/docker-ce/ubuntu/)
* NVIDIA Toolkit Installation : [https://github.com/NVIDIA/nvidia-docker](https://github.com/NVIDIA/nvidia-docker)
* NVIDIA GPU Query : [https://github.com/NVIDIA/nvidia-docker/wiki/NVIDIA-Container-Runtime-on-Jetson](https://github.com/NVIDIA/nvidia-docker/wiki/NVIDIA-Container-Runtime-on-Jetson)


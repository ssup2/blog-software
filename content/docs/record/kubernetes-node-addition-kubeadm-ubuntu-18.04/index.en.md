---
title: Kubernetes Node Addition / Using kubeadm / Ubuntu 18.04 Environment
---

## 1. Installation Environment

The installation environment is as follows.
* HyperV
  * Master Node : Ubuntu Desktop 18.04.1 64bit : 1 node
  * Worker Node : Ubuntu Server 18.04.1 64bit : 2 nodes
* Docker : 19.03.1
* Kubernetes 1.15.3
  * Network Plugin : using calico or flannel or cilium
  * Dashboard Addon : using Dashboard
* kubeadm 1.15.3
  * When building a Cluster environment using VMs, Kubernetes can be easily installed using kubeadm.
* Password
  * For convenient installation, all Passwords required for Kubernetes installation are unified to **root**.
* Installation is performed as root User on all Nodes.

## 2. Package Installation

```shell
(Added Node)$ apt-get update && apt-get install apt-transport-https ca-certificates curl gnupg-agent software-properties-common
(Added Node)$ curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
(Added Node)$ add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb-release -cs) stable"
(Added Node)$ apt-get update && sudo apt-get install docker-ce=5:19.03.1~3-0~ubuntu-bionic docker-ce-cli containerd.io
```

Install Docker on the Node to be added.

```shell
(Added Node)$ apt-get update && apt-get install -y apt-transport-https curl
(Added Node)$ curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
(Added Node)$ echo deb http://apt.kubernetes.io/ kubernetes-xenial main > /etc/apt/sources.list.d/kubernetes.list
(Added Node)$ apt-get update && apt-get install -y kubeadm=1.15.3-00 kubelet=1.15.3-00
```

Install kubeadm and kubelet on the Node to be added.

## 3. Node Addition

### 3.1. Master Node

```shell
(Master Node)$ kubeadm token create
4n1agp.j97evoelu2k35dre
(Master Node)$ kubeadm token list
TOKEN                     TTL       EXPIRES                USAGES                   DESCRIPTION   EXTRA GROUPS
4n1agp.j97evoelu2k35dre   23h       2020-07-27T08:03:59Z   authentication,signing   <none>        system:bootstrappers:kubeadm:default-node-token
```

Create a Token using kubeadm.

```shell
(Master Node)$ openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'
060896fc4bfe949304b8c1af7b23bb5c4e60e6d242722ce5bd02fe4cbc94aabe
```

Obtain the Hash value of the CA certificate.

### 3.2. Added Worker Node

```shell
(Added Node)$ kubeadm join 30.0.0.34:6443 --token 4n1agp.j97evoelu2k35dre --discovery-token-ca-cert-hash sha256:060896fc4bfe949304b8c1af7b23bb5c4e60e6d242722ce5bd02fe4cbc94aabe
```

Join the Cluster using the Token created with kubeadm and the Hash value of the CA certificate. 30.0.0.34 is the IP of the Master Node.

## 4. Node Addition Verification

```shell
(Master Node)$ kubectl get nodes
NAME   STATUS   ROLES    AGE    VERSION
vm01   Ready    master   236d   v1.15.3
vm02   Ready    <none>   236d   v1.15.3
vm03   Ready    <none>   236d   v1.15.3
vm04   Ready    <none>   101s   v1.15.3
```

Verify the added Node from the Master Node. Node04 is the added Node.

## 5. References

* [https://sarc.io/index.php/cloud/1383-join-token](https://sarc.io/index.php/cloud/1383-join-token)


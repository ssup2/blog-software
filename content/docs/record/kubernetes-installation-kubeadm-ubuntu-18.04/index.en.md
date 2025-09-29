---
title: Kubernetes Installation / Using kubeadm / Ubuntu 18.04
---

## 1. Installation Environment

The installation environment is as follows:
* VirtualBox 5.0.14r
  * Master Node : Ubuntu Desktop 18.04.1 64bit : 1 unit
  * Worker Node : Ubuntu Server 18.04.1 64bit : 2 units
* Kubernetes 1.12.3
  * Network Plugin : Use calico or flannel or cilium
  * Dashboard Addon : Use Dashboard
* kubeadm 1.12.3
  * When building a Cluster environment using VMs, Kubernetes can be easily installed using kubeadm.
* Password
  * For easy installation, all passwords required for Kubernetes installation are unified to **root**.
* Installation is performed with root user on all nodes.

## 2. Node Configuration

{{< figure caption="[Figure 1] Node configuration diagram for Kubernetes installation" src="images/node-setting.png" width="900px" >}}

Create virtual Master and Worker Nodes (VMs) using VirtualBox as shown in [Figure 1].
* Hostname : Master Node - node1, Worker Node1 - node2, Worker Node2 - node3
* NAT : Build 10.0.0.0/24 Network using "NAT network" provided by Virtual Box.
* Router : Build 192.168.0.0/24 Network using router. (NAT)

### 2.1. Master Node

```yaml {caption="[File 1] Master Node - /etc/netplan/50-cloud-init.yaml", linenos=table}
network:
    version: 2
    ethernets:
        enp0s3:
            dhcp4: no
            addresses: [10.0.0.10/24]
            gateway4: 10.0.0.1
            nameservers:
                addresses: [8.8.8.8]
        enp0s8:
            dhcp4: no
            addresses: [192.168.0.150/24]
            nameservers:
                addresses: [8.8.8.8]
```

Configure the Master Node's /etc/netplan/50-cloud-init.yaml file as shown in [File 1].

### 2.2. Worker Node

```yaml {caption="[File 2] Worker Node 01 - /etc/netplan/50-cloud-init.yaml", linenos=table}
network:
    version: 2
    ethernets:
        enp0s3:
            dhcp4: no
            addresses: [10.0.0.20/24]
            gateway4: 10.0.0.1
            nameservers:
                addresses: [8.8.8.8]
```

Configure the Worker Node 01's /etc/netplan/50-cloud-init.yaml file as shown in [File 2].

```yaml {caption="[File 3] Worker Node 02 - /etc/netplan/50-cloud-init.yaml", linenos=table}
network:
    version: 2
    ethernets:
        enp0s3:
            dhcp4: no
            addresses: [10.0.0.30/24]
            gateway4: 10.0.0.1
            nameservers:
                addresses: [8.8.8.8]
```

Configure the Worker Node 02's /etc/netplan/50-cloud-init.yaml file as shown in [File 3].

## 3. Package Installation

Install packages required for Kubernetes on all nodes.

```shell
(All)$ apt-get update
(All)$ apt-get install -y docker.io
```

Install Docker.

```shell
(All)$ apt-get update && apt-get install -y apt-transport-https curl
(All)$ curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
(All)$ echo deb http://apt.kubernetes.io/ kubernetes-xenial main > /etc/apt/sources.list.d/kubernetes.list
(All)$ apt-get update && apt-get install -y kubeadm=1.12.3-00 kubelet=1.12.3-00
```

Install kubelet and kubeadm.

## 4. Cluster Setup

### 4.1. Master Node

The options for kubeadm commands for cluster setup vary depending on the network plugin to be used. Therefore, you must select one network plugin from among the three network plugins (Calico, Flannel, Cilium) before building the cluster. Build the cluster by executing the commands in the selected network plugin section and the common section commands.

#### 4.1.1. Calico-based Setup

```shell
(Master)$ swapoff -a
(Master)$ sed -i '/swap.img/s/^/#/' /etc/fstab
(Master)$ kubeadm init --apiserver-advertise-address=10.0.0.10 --pod-network-cidr=192.168.0.0/16 --kubernetes-version=v1.12.0
...
kubeadm join 10.0.0.10:6443 --token x7tk20.4hp9x2x43g46ara5 --discovery-token-ca-cert-hash sha256:cab2cc0a4912164f45f502ad31f5d038974cf98ed10a6064d6632a07097fad79
```

Initialize kubeadm. --pod-network-cidr must be set to **192.168.0.0/16**. If an error occurs due to Docker version, add '--ignore-preflight-errors=SystemVerification' at the end of kubeadm init.

#### 4.1.2. Flannel-based Setup

```shell
(Master)$ swapoff -a
(Master)$ sed -i '/swap.img/s/^/#/' /etc/fstab
(Master)$ kubeadm init --apiserver-advertise-address=10.0.0.10 --pod-network-cidr=10.244.0.0/16 --kubernetes-version=v1.12.0
...
kubeadm join 10.0.0.10:6443 --token x7tk20.4hp9x2x43g46ara5 --discovery-token-ca-cert-hash sha256:cab2cc0a4912164f45f502ad31f5d038974cf98ed10a6064d6632a07097fad79
```

Initialize kubeadm. --pod-network-cidr must be set to **10.244.0.0/16**. If an error occurs due to Docker version, add '--ignore-preflight-errors=SystemVerification' at the end of kubeadm init.

#### 4.1.3. Cilium-based Setup

```shell
(Master)$ swapoff -a
(Master)$ sed -i '/swap.img/s/^/#/' /etc/fstab
(Master)$ kubeadm init --apiserver-advertise-address=10.0.0.10 --pod-network-cidr=192.167.0.0/16 --kubernetes-version=v1.12.0
...
kubeadm join 10.0.0.10:6443 --token x7tk20.4hp9x2x43g46ara5 --discovery-token-ca-cert-hash sha256:cab2cc0a4912164f45f502ad31f5d038974cf98ed10a6064d6632a07097fad79
```

Initialize kubeadm. --pod-network-cidr just needs to not overlap with --pod-network-cidr. In the above, --pod-network-cidr is set to 192.167.0.0/16. If an error occurs due to Docker version, add '--ignore-preflight-errors=SystemVerification' at the end of kubeadm init.

#### 4.1.4. Common

```shell
(Master)$ mkdir -p $HOME/.kube
(Master)$ sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
(Master)$ sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

Configure kubectl config.

```shell
(Master)$ kubectl taint nodes --all node-role.kubernetes.io/master-
```

Configure so that pods can be created on the Master Node as well.

```text {caption="[File 4] Master Node - ~/.bashrc", linenos=table}
if [ -f /etc/bash-completion ] && ! shopt -oq posix; then
    . /etc/bash-completion
fi

source <(kubectl completion bash)
```

Configure kubectl autocomplete. Add the content of [File 4] to ~/.bashrc.

### 4.2. Worker Node

```shell
(Worker)$ swapoff -a
(Worker)$ sed -i.bak '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
(Worker)$ kubeadm join 10.0.0.10:6443 --token 46i2fg.yoidccf4k485z74u --discovery-token-ca-cert-hash sha256:cab2cc0a4912164f45f502ad31f5d038974cf98ed10a6064d6632a07097fad79
```

Configure the cluster. Execute the **kubeadm join ~~** command that appeared as a result of kubeadm init on all Worker Nodes. If an error occurs due to Docker version, add '--ignore-preflight-errors=SystemVerification' at the end of kubeadm join.

### 4.3. Verification

```shell
(Master)$ kubectl get nodes
NAME    STATUS     ROLES    AGE   VERSION
node1   NotReady   master   84s   v1.12.3
node2   NotReady   <none>   31s   v1.12.3
node3   NotReady   <none>   27s   v1.12.3
```

Check the cluster from the Master Node. All nodes should appear in the list. They remain in NotReady state because network configuration is not set. Ready state can be confirmed after network plugin installation.

## 5. Network Plugin Installation

Install only the network plugin selected when building the cluster.

### 5.1. Master Node

#### 5.1.1. Calico Installation

```shell
(Master)$ kubectl apply -f https://docs.projectcalico.org/v3.1/getting-started/kubernetes/installation/hosted/rbac-kdd.yaml
(Master)$ kubectl apply -f https://docs.projectcalico.org/v3.1/getting-started/kubernetes/installation/hosted/kubernetes-datastore/calico-networking/1.7/calico.yaml
```

Install Calico.

#### 5.1.2. Flannel Installation

```shell
(Master)$ kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/v0.10.0/Documentation/kube-flannel.yml
```

Install Flannel.

#### 5.1.3. Cilium Installation

```shell
(Master)$ mount bpffs /sys/fs/bpf -t bpf
(Master)$ echo "bpffs                      /sys/fs/bpf             bpf     defaults 0 0" >> /etc/fstab
```

Perform bpffs mount and configuration.

```shell
(Master)$ wget https://github.com/cilium/cilium/archive/v1.3.0.zip
(Master)$ unzip v1.3.0.zip
(Master)$ kubectl apply -f cilium-1.3.0/examples/kubernetes/addons/etcd/standalone-etcd.yaml
```

Download Cilium and install etcd required for Cilium operation.

```yaml {caption="[File 5] Master Node - cilium-1.3.0/examples/kubernetes/1.12/cilium.yaml", linenos=table}
...
      containers:
        - image: docker.io/cilium/cilium:v1.3.0
          imagePullPolicy: IfNotPresent
          name: cilium-agent
          command: ["cilium-agent"]
          args:
            - "--debug=$(CILIUM-DEBUG)"
            - "--kvstore=etcd"
            - "--kvstore-opt=etcd.config=/var/lib/etcd-config/etcd.config"
            - "--disable-ipv4=$(DISABLE-IPV4)"
            - "--prefilter-device=enp0s3"
            - "--prefilter-mode=generic"
...
```

Modify Cilium configuration to enable Prefilter functionality. The prefilter interface must specify the NIC interface that constitutes the Kubernetes Cluster Network. If the device driver of the NIC that constitutes the Kubernetes Cluster Network does not support XDP, --prefilter-mode must be set to generic. Modify the cilium-1.3.0/examples/kubernetes/1.12/cilium.yaml file as shown in [File 5].

```shell
(Master)$ kubectl apply -f cilium-1.3.0/examples/kubernetes/1.12/cilium.yaml
```

Install Cilium.

### 5.2. Worker Node

#### 5.2.1. Calico, Flannel Installation

No work is required on Worker Nodes.

#### 5.2.2. Cilium Installation

```shell
(Worker)$ mount bpffs /sys/fs/bpf -t bpf
(Worker)$ echo "bpffs                      /sys/fs/bpf             bpf     defaults 0 0" >> /etc/fstab
```

Perform bpffs mount and configuration.

## 6. Web UI (Dashboard) Installation

### 6.1 Master Node

```shell
(Master)$ kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml
```

Install Web UI.

```yaml {caption="[File 6] Master Node - /etc/kubernetes/manifests/kube-apiserver.yaml", linenos=table}
...
spec:
  containers:
  - command:
...
    - --insecure-bind-address=0.0.0.0
    - --insecure-port=8080
...
```

Configure Insecure Option for kube-apiserver. Modify the command in the /etc/kubernetes/manifests/kube-apiserver.yaml file as shown in [File 6].

```shell
(Master)$ service kubelet restart
```

Restart the kubelet service.

```yaml {caption="[File 7] Master Node - ~/dashboard-admin.yaml", linenos=table}
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: kubernetes-dashboard
  labels:
    k8s-app: kubernetes-dashboard
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: kubernetes-dashboard
  namespace: kube-system
```

Create a config file for Web UI privilege permissions. Create ~/dashboard-admin.yaml file with the content of [File 7].

```shell
(Master)$ kubectl create -f ~/dashboard-admin.yaml
(Master)$ rm ~/dashboard-admin.yaml
```

Apply privilege permissions to Web UI and access to verify. After accessing Web UI, click Skip.
* http://192.168.0.150:8080/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/#!/login

## 8. References

* Kubernetes Installation : [https://kubernetes.io/docs/setup/independent/install-kubeadm/](https://kubernetes.io/docs/setup/independent/install-kubeadm/)
* Docker Installation : [https://docs.docker.com/engine/installation/linux/docker-ce/ubuntu/](https://docs.docker.com/engine/installation/linux/docker-ce/ubuntu/)
* Calico, Flannel, Cilium Installation : [https://kubernetes.io/docs/setup/independent/create-cluster-kubeadm/#pod-network](https://kubernetes.io/docs/setup/independent/create-cluster-kubeadm/#pod-network)
* Web UI Installation : [https://github.com/kubernetes/dashboard/wiki/Access-control#basic](https://github.com/kubernetes/dashboard/wiki/Access-control#basic)

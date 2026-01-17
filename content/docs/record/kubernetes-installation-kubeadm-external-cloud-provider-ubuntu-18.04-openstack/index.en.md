---
title: Kubernetes Installation / Using kubeadm and External Cloud Provider / Ubuntu 18.04, OpenStack Environment
---

## 1. Installation Environment

{{< figure caption="[Figure 1] Kubernetes Installation Environment" src="images/environment.png" width="900px" >}}

[Figure 1] shows the Kubernetes installation environment. The installation environment is as follows.

* VM: Ubuntu 18.04 (Cloud Version), 4 vCPU, 4GB Memory
  * ETCD Node * 1
  * Master Node * 1
  * Slave Node * 3
* Network
  * NAT Network: 192.168.0.0/24
  * Octavia Network: 20.0.0.0/24
  * Tenant Network: 30.0.0.0/24
* OpenStack: Stein
  * API Server: 192.168.0.40:5000
  * Octavia
* Kubernetes: 1.15.3
  * CNI: Cilium 1.5.6 Plugin
* External Cloud Provider
  * OpenStack Cloud Controller Manager: v1.15.0
  * CSI Plugin: v1.16.0

## 2. Ubuntu Package Installation

### 2.1. All Nodes

Install packages for Kubernetes on all nodes.

```shell
(All)$ sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb-release -cs) stable"
(All)$ apt-get update
(All)$ apt-get install -y docker-ce
```

Install Docker.

```shell
(All)$ apt-get update && apt-get install -y apt-transport-https curl
(All)$ curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
(All)$ echo deb http://apt.kubernetes.io/ kubernetes-xenial main > /etc/apt/sources.list.d/kubernetes.list
(All)$ apt-get update
(All)$ apt-get install -y kubeadm=1.15.3-00 kubelet=1.15.3-00
```

Install kubelet and kubeadm.

## 3. Kubernetes Cluster Setup

### 3.1. All Nodes

```text {caption="[File 1] All Node - /etc/systemd/system/kubelet.service.d/10-kubeadm.conf", linenos=table}
...
[Service]
Environment="KUBELET-KUBECONFIG-ARGS=--cloud-provider=external --bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf"
...
```

Modify the /etc/systemd/system/kubelet.service.d/10-kubeadm.conf file on all nodes as shown in [File 1] to configure kubelet to use the External Cloud Provider.

### 3.2. Master Node

```shell
(Master)$ kubeadm init --apiserver-advertise-address=30.0.0.11 --pod-network-cidr=192.167.0.0/16 --kubernetes-version=v1.15.3
...
kubeadm join 30.0.0.11:6443 --token x7tk20.4hp9x2x43g46ara5 --discovery-token-ca-cert-hash sha256:cab2cc0a4912164f45f502ad31f5d038974cf98ed10a6064d6632a07097fad79
```

Initialize kubeadm. The --pod-network-cidr just needs to not overlap with other networks. Here, --pod-network-cidr is set to 192.167.0.0/16.

```shell
(Master)$ mkdir -p $HOME/.kube 
(Master)$ sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
(Master)$ sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

Configure the kubernetes config file.

### 3.3. Worker Nodes

```shell
(Worker)$ kubeadm join 30.0.0.11:6443 --token v40peg.uyrgkkmiu1rl6dmn --discovery-token-ca-cert-hash sha256:1474a36cdae4b45da503fd48b4a516e72040ad35fa8f0456edfcacf9cd954522
```

Execute the **kubeadm join ~~** command that appears as a result of kubeadm init on all worker nodes.

## 4. Cilium Installation

### 4.1. All Nodes

```shell
(All)$ mount bpffs /sys/fs/bpf -t bpf
(All)$ echo "bpffs                      /sys/fs/bpf             bpf     defaults 0 0" >> /etc/fstab
```

Configure bpffs to be mounted on all nodes.

### 4.2. Master Node

```shell
(Master)$ wget https://github.com/cilium/cilium/archive/v1.5.6.zip
(Master)$ unzip v1.5.6.zip
(Master)$ kubectl apply -f cilium-1.5.6/examples/kubernetes/1.15/cilium.yaml
```

Install Cilium. **All nodes have taints set until the External Cloud Provider (OpenStack CCM) is properly installed.** Therefore, Cilium will operate only after the External Cloud Provider is fully installed.

## 5. cloud-config File Creation

### 5.1. Master Node

```text {caption="[File 2] Master Node - /etc/kubernetes/cloud-config", linenos=table}
[Global]
auth-url="http://192.168.0.40:5000/v3"
username="admin"
password="admin"
region="RegionOne"
tenant-id="b21b68637237488bbb5f33ac8d86b848"
domain-name="Default"

[BlockStorage]
bs-version=v3

[LoadBalancer]
subnet-id=67ca5cfd-0c3f-434d-a16c-c709d1ab37fb
floating-network-id=00a8e738-c81e-45f6-9788-3e58186076b6
use-octavia=True
lb-method=ROUND-ROBIN

create-monitor=yes
monitor-delay=1m
monitor-timeout=30s
monitor-max-retries=3
```

Create the /etc/kubernetes/cloud-config file on all master nodes with the content from [File 2]. The Global section of [File 2] contains User ID/PW, Tenant, Region information, etc. for Kubernetes VMs. The LoadBalancer section contains Load Balancer-related configuration information. subnet-id refers to the Subnet ID of the Kubernetes Network. floating-network-id refers to the External Network ID. lb-method refers to the Load Balancing algorithm. Monitor-related settings determine the Octavia Member VM Monitoring policy.

```shell
(Master)$ kubectl create secret -n kube-system generic cloud-config --from-literal=cloud.conf="$(cat /etc/kubernetes/cloud-config)" --dry-run -o yaml > cloud-config-secret.yaml
(Master)$ kubectl -f cloud-config-secret.yaml apply
```

Create the cloud-config secret for use by the OpenStack Cloud Controller Manager and Cinder CSI Plugin.

## 6. Kubernetes Cluster Configuration

### 6.1. Master Node

```yaml {caption="[File 3] Master Node - /etc/kubernetes/manifests/kube-controller-manager.yaml", linenos=table}
...
    volumeMounts:
    - mountPath: /etc/kubernetes/cloud-config
      name: cloud-config
      readOnly: true
...
  volumes:
  - hostPath:
      path: /etc/kubernetes/cloud-config
      type: FileOrCreate
    name: cloud-config
...
```

Modify the /etc/kubernetes/manifests/kube-controller-manager.yaml file on all master nodes as shown in [File 3] to configure the Kubernetes Controller Manager to use the cloud-config file. When the kube-controller-manager.yaml file is modified, Kubernetes automatically restarts the Kubernetes Controller Manager.

```yaml {caption="[File 4] Master Node - /etc/kubernetes/manifests/kube-apiserver.yaml", linenos=table}
...
spec:
  containers:
  - command:
    - kube-apiserver
    - --advertise-address=30.0.0.11
    - --allow-privileged=true
...
    - --runtime-config=storage.k8s.io/v1=true
...
```

Modify the /etc/kubernetes/manifests/kube-apiserver.yaml file on all master nodes as shown in [File 4] to configure the Kubernetes API Server to provide the Storage API. When the kube-apiserver.yaml file is modified, Kubernetes automatically restarts the Kubernetes API Server.

## 7. OpenStack CCM (Cloud Controller Manager) Installation

### 7.1. Master Node

```shell
(Master)$ git clone https://github.com/kubernetes/cloud-provider-openstack.git
(Master)$ cd cloud-provider-openstack && git checkout v1.15.0
(Master)$ kubectl apply -f cluster/addons/rbac/cloud-controller-manager-roles.yaml
(Master)$ kubectl apply -f cluster/addons/rbac/cloud-controller-manager-role-bindings.yaml
(Master)$ kubectl apply -f manifests/controller-manager/openstack-cloud-controller-manager-ds.yaml
```

Install the OpenStack Cloud Controller Manager.

## 8. Cinder CSI Plugin Installation

### 8.1. Master Node

```shell
(Master)$ cd cloud-provider-openstack && git checkout v1.16.0
(Master)$ rm manifests/cinder-csi-plugin/csi-secret-cinderplugin.yaml
(Master)$ kubectl -f manifests/cinder-csi-plugin apply
(Master)$ kubectl get csidrivers.storage.k8s.io
NAME                       CREATED AT
cinder.csi.openstack.org   2019-10-16T15:36:27Z
```

Since csi-secret is replaced by cloud-config-secret, delete the unnecessary csi-secret-cinderplugin.yaml and install the Cinder CSI Plugin. Cinder CSI Plugin v1.15.0 does not work, so change to v1.16.0 and install. If the Cinder CSI Plugin is properly installed, the "cinder.csi.openstack.org" object can be queried.

```yaml {caption="[File 5] Master Node - ~/storageclass.yaml", linenos=table}
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: csi-sc-cinderplugin
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: cinder.csi.openstack.org
```

```shell
(Master)$ kubectl apply -f ~/storageclass.yaml
```

Create and configure a Storage Class with the content from [File 5].

## 9. References

* [https://kubernetes.io/docs/setup/independent/install-kubeadm/](https://kubernetes.io/docs/setup/independent/install-kubeadm/)
* [https://docs.docker.com/engine/installation/linux/docker-ce/ubuntu/](https://docs.docker.com/engine/installation/linux/docker-ce/ubuntu/)
* [https://kubernetes.io/docs/setup/independent/create-cluster-kubeadm/#pod-network](https://kubernetes.io/docs/setup/independent/create-cluster-kubeadm/#pod-network)
* [https://github.com/kubernetes/cloud-provider-openstack/blob/master/docs/openstack-kubernetes-integration-options.md](https://github.com/kubernetes/cloud-provider-openstack/blob/master/docs/openstack-kubernetes-integration-options.md)
* [https://github.com/kubernetes/cloud-provider-openstack/blob/master/docs/using-controller-manager-with-kubeadm.md](https://github.com/kubernetes/cloud-provider-openstack/blob/master/docs/using-controller-manager-with-kubeadm.md)
* [https://github.com/kubernetes/cloud-provider-openstack/blob/master/docs/using-cinder-csi-plugin.md](https://github.com/kubernetes/cloud-provider-openstack/blob/master/docs/using-cinder-csi-plugin.md)
* [https://github.com/kubernetes/cloud-provider-openstack/issues/758](https://github.com/kubernetes/cloud-provider-openstack/issues/758)
* [https://kubernetes.io/docs/tasks/administer-cluster/running-cloud-controller/](https://kubernetes.io/docs/tasks/administer-cluster/running-cloud-controller/)


---
title: Kubernetes Installation / Using kubeadm and IPv6 DualStack / Ubuntu 18.04 Environment
---

## 1. Installation Environment

{{< figure caption="[Figure 1] Node Configuration Diagram for Kubernetes Installation" src="images/node-setting.png" width="900px" >}}

[Figure 1] shows the node configuration diagram for Kubernetes installation. The installation environment is as follows.

* VM: 4 vCPU, 4GB Memory
  * Master Node * 1
  * Worker Node * 2
* Network
  * Node Network: 192.168.0.0/24, fdaa::/64
  * Pod Network: 192.167.0.0/16, fdbb::/64
  * Service Network: 10.96.0.0/12, fdcc::/112
* Kubernetes: 1.18.3
  * CNI: Calico 3.14 Plugin

## 2. Ubuntu Package Installation

### 2.1. All Nodes

Install packages for Kubernetes on all nodes.

```shell
(All)$ sudo apt-get install apt-transport-https ca-certificates curl gnupg-agent software-properties-common
(All)$ curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
(All)$ sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb-release -cs) stable"
(All)$ apt-get update
(All)$ apt-get install docker-ce docker-ce-cli containerd.io
```

Install Docker.

```shell
(All)$ apt-get update && apt-get install -y apt-transport-https curl
(All)$ curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
(All)$ echo deb http://apt.kubernetes.io/ kubernetes-xenial main > /etc/apt/sources.list.d/kubernetes.list
(All)$ apt-get update
(All)$ apt-get install -y kubeadm=1.18.3-00 kubelet=1.18.3-00
```

Install kubelet and kubeadm.

```
(ALL)$ sysctl -w net.ipv6.conf.all.forwarding=1
(ALL)$ echo net.ipv6.conf.all.forwarding=1 >> /etc/sysctl.conf
```

Configure IPv6 forwarding.

## 3. Kubernetes Cluster Setup

### 3.1. Master Node

```shell
(Master)$ kubeadm init --apiserver-advertise-address=192.168.0.61 --kubernetes-version=v1.18.3 --feature-gates=IPv6DualStack=true --pod-network-cidr=192.167.0.0/16,fdbb::0/64 --service-cidr=10.96.0.0/12,fdcc::0/112
...
kubeadm join 192.168.0.61:6443 --token 6gu1o3.dwhguhu651x137eq --discovery-token-ca-cert-hash sha256:2ab0fa9f6f8c3c49c263bc0a0edc19ddf973bf7fdf5e464c807df45e8bf49ab8
```

Initialize kubeadm. Set IPv6 CIDR for both --pod-network-cidr and --service-cidr.

```shell
(Master)$ mkdir -p $HOME/.kube 
(Master)$ sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
(Master)$ sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

Configure the kubernetes config file.

### 3.2. Worker Nodes

```shell
(Worker)$ kubeadm join 192.168.0.61:6443 --token 6gu1o3.dwhguhu651x137eq --discovery-token-ca-cert-hash sha256:2ab0fa9f6f8c3c49c263bc0a0edc19ddf973bf7fdf5e464c807df45e8bf49ab8
```

Execute the **kubeadm join ~~** command that appears as a result of kubeadm init on all worker nodes.

## 4. Calico Installation

```shell
(Master)$ wget https://docs.projectcalico.org/v3.14/manifests/calico.yaml
```

Download the Calico manifest file.

```text {caption="[File 1] calico.yaml", linenos=table}
...
          "mtu": --CNI-MTU--,
          "ipam": {
              "type": "calico-ipam",
              "assign-ipv4": "true",
              "assign-ipv6": "true"
          },
...
            # The default IPv4 pool to create on startup if none exists. Pod IPs will be
            # chosen from this range. Changing this value after installation will have
            # no effect. This should fall within `--cluster-cidr`.
            - name: CALICO-IPV4POOL-CIDR
              value: "192.167.0.0/16"
            - name: IP6
              value: "autodetect"
            - name: CALICO-IPV6POOL-CIDR
              value: "fdbb::0/64"
...
            - name: FELIX-DEFAULTENDPOINTTOHOSTACTION
              value: "ACCEPT"
            - name: FELIX-IPV6SUPPORT
              value: true
```

Modify the Calico manifest file as shown in [File 1].

```shell
(Master)$ kubectl apply -f calico.yaml
```

Install Calico.

## 5. References

* [https://medium.com/@elfakharany/how-to-enable-ipv6-on-kubernetes-aka-dual-stack-cluster-ac0fe294e4cf](https://medium.com/@elfakharany/how-to-enable-ipv6-on-kubernetes-aka-dual-stack-cluster-ac0fe294e4cf)
* [https://kubernetes.io/docs/concepts/services-networking/dual-stack/](https://kubernetes.io/docs/concepts/services-networking/dual-stack/)
* [https://docs.projectcalico.org/getting-started/kubernetes/self-managed-onprem/onpremises](https://docs.projectcalico.org/getting-started/kubernetes/self-managed-onprem/onpremises)
* [https://docs.projectcalico.org/networking/dual-stack](https://docs.projectcalico.org/networking/dual-stack)


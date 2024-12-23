---
title : Kubernetes Data Platform 구축 / Raspberry Pi 5, Jetson Nano Cluster 환경
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
sudo -s
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
sudo -s
```

[Figure 1]의 Network를 참조하여 고정 IP를 설정한다.

```shell
nmcli con mod "Wired connection 1" \
  ipv4.addresses "[IP Address]/24" \
  ipv4.gateway "192.168.1.1" \
  ipv4.dns "8.8.8.8" \
  ipv4.method "manual"
```

## 4. Docker, kubelet 설치

### 4.1. Raspberry Pi 5

Kernel Module을 로드한다.

```shell
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter
```

sysctl Parameter를 설정한다.

```shell
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system
```

containerd를 설치한다.

```shell
apt install -y containerd
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
systemctl restart containerd.service
```

kubelet, kubeadm을 설치한다.

```shell
apt-get update
apt-get install -y apt-transport-https ca-certificates curl gnupg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubelet=1.31.4-1.1 kubeadm=1.31.4-1.1
```

### 4.2. Jetson Nano

## 5. Kubernetes Cluster 구성

### 5.1. Master Node (Raspberry Pi 5)

kubectl을 설치한다.

```shell
apt-get install -y kubectl=1.31.4-1.1
```

Kubernetes Cluster를 구성한다.

```shell
cat <<EOF | tee kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
certificateValidityPeriod: 876000h
caCertificateValidityPeriod: 876000h
kubernetesVersion: "v1.31.4"
networking:
  podSubnet: "10.244.0.0/24"
EOF

kubeadm init --config kubeadm-config.yaml
# kubeadm join 192.168.1.71:6443 --token 6vj8jy.8i28zq7leqs0hru1 --discovery-token-ca-cert-hash sha256:00a4d45b7c715b99aa46ffd05d6e8bf2ba3423909a7725c16a98bbdcaf0cc1c4
```

kubectl config 파일을 복사한다.

```shell
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

flannel CNI Plugin을 설치한다.

```shell
kubectl apply -f https://github.com/flannel-io/flannel/releases/download/v0.26.2/kube-flannel.yml
```

### 5.2. Compute, Storage, GPU Nodes

## 6. Data Component 설치

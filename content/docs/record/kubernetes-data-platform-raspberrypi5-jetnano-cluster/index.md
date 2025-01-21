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
apt update
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
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubelet=1.30.8-1.1 kubeadm=1.30.8-1.1
```

### 4.2. Jetson Nano

Swap Memory를 제거한다.

```shell
swapoff -a
mv /etc/systemd/nvzramconfig.sh /etc/systemd/nvzramconfig.sh.back
```

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
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
apt-get update
apt-get install -y nvidia-container-toolkit containerd
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
nvidia-ctk runtime configure --runtime=containerd --set-as-default
systemctl restart containerd
```

kubelet, kubeadm을 설치한다.

```shell
apt-get update
mkdir -p /etc/apt/keyrings
apt-get install -y apt-transport-https ca-certificates curl gnupg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubelet=1.30.8-1.1 kubeadm=1.30.8-1.1
```

## 5. Kubernetes Cluster 구성

### 5.1. Master Node (Raspberry Pi 5)

kubectl을 설치한다.

```shell
apt-get install -y kubectl=1.30.8-1.1
```

Kubernetes Cluster를 구성한다.

```shell
cat <<EOF | tee kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
certificateValidityPeriod: 876000h
caCertificateValidityPeriod: 876000h
kubernetesVersion: "v1.30.8"
networking:
  podSubnet: "10.244.0.0/16"
EOF

kubeadm init --config kubeadm-config.yaml
```
```shell
kubeadm join 192.168.1.71:6443 --token e5t05s.1z4zbpm3oxdhskya --discovery-token-ca-cert-hash sha256:01c2bf6ead65ea0e9c39186d92a51baa9aa6dc6963b900cd825d7e14dcb08fba
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

각각의 Node에 SSH로 접근하여 Kubernetes Cluster에 Join 한다.

```shell
kubeadm join 192.168.1.71:6443 --token e5t05s.1z4zbpm3oxdhskya --discovery-token-ca-cert-hash sha256:01c2bf6ead65ea0e9c39186d92a51baa9aa6dc6963b900cd825d7e14dcb08fba
```

Master Node의 Master Label과 Taint를 제거한다.

```shell
kubectl taint node dp-master node-role.kubernetes.io/control-plane:NoSchedule-
kubectl label node dp-master node-role.kubernetes.io/control-plane-
```

각각의 Node에 Role을 부여한다.

```shell
kubectl label node dp-master node-role.kubernetes.io/master=""
kubectl label node dp-compute-01 node-role.kubernetes.io/compute=""
kubectl label node dp-compute-02 node-role.kubernetes.io/compute=""
kubectl label node dp-storage-01 node-role.kubernetes.io/storage=""
kubectl label node dp-storage-02 node-role.kubernetes.io/storage=""
kubectl label node dp-gpu-01 node-role.kubernetes.io/gpu=""
kubectl label node dp-gpu-02 node-role.kubernetes.io/gpu=""
kubectl label node dp-master node-group.dp.ssup2="master"
kubectl label node dp-compute-01 node-group.dp.ssup2="compute"
kubectl label node dp-compute-02 node-group.dp.ssup2="compute"
kubectl label node dp-storage-01 node-group.dp.ssup2="storage"
kubectl label node dp-storage-02 node-group.dp.ssup2="storage"
kubectl label node dp-gpu-01 node-group.dp.ssup2="gpu"
kubectl label node dp-gpu-02 node-group.dp.ssup2="gpu"
```

Node의 Role을 확인한다.

```shell
kubectl get nodes
```
```shell
NAME            STATUS   ROLES                  AGE   VERSION
dp-compute-01   Ready    compute                16d   v1.30.8
dp-compute-02   Ready    compute                16d   v1.30.8
dp-gpu-01       Ready    gpu                    16d   v1.30.8
dp-gpu-02       Ready    gpu                    16d   v1.30.8
dp-master       Ready    control-plane,master   16d   v1.30.8
dp-storage-01   Ready    storage                16d   v1.30.8
dp-storage-02   Ready    storage                16d   v1.30.8
```

## 6. Data Component 설치

```shell
# MetelLB
helm upgrade --install --create-namespace --namespace metallb metallb metallb -f metallb/values.yaml
kubectl apply -f metallb/ip-address-pool.yaml
kubectl apply -f metallb/l2-advertisement.yaml

# Cert Manager
helm upgrade --install --create-namespace --namespace cert-manager cert-manager cert-manager -f cert-manager/values.yaml

# Yunikorn
helm upgrade --install --create-namespace --namespace yunikorn yunikorn yunikorn -f yunikorn/values.yaml

# KEDA
helm upgrade --install --create-namespace --namespace keda keda keda -f keda/values.yaml

# Longhorn
helm upgrade --install --create-namespace --namespace longhorn longhorn longhorn -f longhorn/values.yaml

# MinIO (root ID/PW: root/root123!)
helm upgrade --install --create-namespace --namespace minio minio minio -f minio/values.yaml

# PostgreSQL (root ID/PW: posgres/root123!)
helm upgrade --install --create-namespace --namespace postgresql postgresql postgresql -f postgresql/values.yaml
kubectl -n postgresql exec -it postgresql-0 -- bash -c 'PGPASSWORD=root123! psql -U postgres -c "create database airflow;"'

# Nvidia Device Plugin
helm upgrade --install --create-namespace --namespace nvidia-device-plugin nvidia-device-plugin nvidia-device-plugin -f nvidia-device-plugin/values.yaml

# Nvidia Jetson Exporter

# Prometheus
helm upgrade --install --create-namespace --namespace prometheus prometheus prometheus -f prometheus/values.yaml

# Prometheus Node Exporter
helm upgrade --install --create-namespace --namespace prometheus-node-exporter prometheus-node-exporter prometheus-node-exporter -f prometheus-node-exporter/values.yaml

# kube-state-metrics
helm upgrade --install --create-namespace --namespace kube-state-metrics kube-state-metrics kube-state-metrics -f kube-state-metrics/values.yaml

# Loki
helm upgrade --install --create-namespace --namespace loki loki loki -f loki/values.yaml

# Promtail
helm upgrade --install --create-namespace --namespace promtail promtail promtail -f promtail/values.yaml

# Grafana (ID/PW: admin/root123!)
helm upgrade --install --create-namespace --namespace grafana grafana grafana -f grafana/values.yaml

# Airflow (admin/admin)
helm upgrade --install --create-namespace --namespace airflow airflow airflow -f airflow/values.yaml

# Spark Operator
helm upgrade --install --create-namespace --namespace spark-operator spark-operator spark-operator -f spark-operator/values.yaml

# Flink Kubernetes Operator
helm upgrade --install --create-namespace --namespace flink-kubernetes-operator flink-kubernetes-operator flink-kubernetes-operator -f flink-kubernetes-operator/values.yaml

# Trino
helm upgrade --install --create-namespace --namespace trino trino trino -f trino/values.yaml

# JupyterHub (ID/PW: root/root123!)
helm upgrade --install --create-namespace --namespace jupyterhub jupyterhub jupyterhub -f jupyterhub/values.yaml
```

## 참조

* Nvidia Containerd : [https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
* Airflow on Kubernetes : [https://zerohertz.github.io/k8s-airflow/](https://zerohertz.github.io/k8s-airflow/)

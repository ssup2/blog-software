---
title : Kubernetes Data Platform 구축 / Orange Pi 5 Max Cluster 환경
---

Kubernetes 기반의 Data Platform을 구축하기 위해서 OrangePi 5 Max 7대를 사용하여 클러스터를 구성한다.

## 1. 구축 환경

Kubernetes Cluster 구성에 이용되는 OrangePi 5 Max 7대의 사양과, 설치되는 Component는 다음과 같다.

{{< figure caption="[Figure 1] Cluster Spec" src="images/cluster-spec.png" width="1000px" >}}

{{< figure caption="[Figure 2] Cluster 구성 요소" src="images/cluster-component.png" width="1000px" >}}

## 2. OS 설치

[User Guide](documents/OrangePi_5_Max_RK3588_User%20Manual_v1.3.pdf)의 **2.6. Method for burning Linux images to SPIFlash+NVMeSSD** 부분을 따라서 OrangePi 5 Max에 OS를 설치한다.

* Install Guide : [https://developer.nvidia.com/embedded/learn/get-started-jetson-nano-devkit#write](https://developer.nvidia.com/embedded/learn/get-started-jetson-nano-devkit#write)
* Debian bookwoarm OS : [https://drive.google.com/drive/folders/1b6hqA6zdgiScWvohsUdopBrtmytF4-ma](https://drive.google.com/drive/folders/1b6hqA6zdgiScWvohsUdopBrtmytF4-ma)

## 3. Hostname, Network 설정

`root` User로 진입한다.

```shell
sudo -s
```

[Figure 1]를 참조하여 Hostname을 설정한다.

```shell
hostnamectl set-hostname dp-master
```

[Figure 1]를 참조하여 고정 IP를 설정한다.

```shell
nmcli con mod "Wired connection 1" \
  ipv4.addresses "[IP Address]/24" \
  ipv4.gateway "192.168.1.1" \
  ipv4.dns "8.8.8.8" \
  ipv4.method "manual"
```

## 4. contaienrd, kubelet 설치

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

swap Memory를 비활성화 한다.

```
swapoff -a
sed -i 's/^ENABLED=true/ENABLED=false/' "/etc/default/orangepi-zram-config"
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

## 5. Kubernetes Cluster 구성

### 5.1. Master Node

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
kubeadm join 192.168.1.71:6443 --token wweo8m.uyl4fgnc7j21orw5 --discovery-token-ca-cert-hash sha256:599058d317291ab64e0cc8166fe0f9cff5defcc606623fdb2c1aa1b2e2a93604
```

kubectl config 파일을 복사한다.

```shell
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

core-dns가 Master Node에만 동작하도록 설정한다.

```shell
kubectl patch deployment coredns -n kube-system -p '{"spec":{"template":{"spec":{"nodeSelector":{"node-group.dp.ssup2":"master"}}}}}'
```

flannel CNI Plugin을 설치한다.

```shell
kubectl apply -f https://github.com/flannel-io/flannel/releases/download/v0.26.2/kube-flannel.yml
```

NFS Server에서 이용할 Directory를 생성한다.

```shell
mkdir -p /srv/nfs
```

### 5.2. Worker Nodes

각각의 Node에 SSH로 접근하여 Kubernetes Cluster에 Join 한다.

```shell
kubeadm join 192.168.1.71:6443 --token wweo8m.uyl4fgnc7j21orw5 --discovery-token-ca-cert-hash sha256:599058d317291ab64e0cc8166fe0f9cff5defcc606623fdb2c1aa1b2e2a93604
```

## 6. Label 설정

Master Node의 Master Label과 Taint를 제거한다.

```shell
kubectl taint node dp-master node-role.kubernetes.io/control-plane:NoSchedule-
kubectl label node dp-master node-role.kubernetes.io/control-plane-
```

각각의 Node에 Role을 부여한다.

```shell
kubectl label node dp-master node-role.kubernetes.io/master=""
kubectl label node dp-worker-1 node-role.kubernetes.io/worker=""
kubectl label node dp-worker-2 node-role.kubernetes.io/worker=""
kubectl label node dp-worker-3 node-role.kubernetes.io/worker=""
kubectl label node dp-worker-4 node-role.kubernetes.io/worker=""
kubectl label node dp-worker-5 node-role.kubernetes.io/worker=""
kubectl label node dp-worker-6 node-role.kubernetes.io/worker=""

kubectl label node dp-master node-group.dp.ssup2="master"
kubectl label node dp-worker-1 node-group.dp.ssup2="worker"
kubectl label node dp-worker-2 node-group.dp.ssup2="worker"
kubectl label node dp-worker-3 node-group.dp.ssup2="worker"
kubectl label node dp-worker-4 node-group.dp.ssup2="worker"
kubectl label node dp-worker-5 node-group.dp.ssup2="worker"
kubectl label node dp-worker-6 node-group.dp.ssup2="worker"
```

Node의 Role을 확인한다.

```shell
kubectl get nodes
```
```shell
NAME          STATUS   ROLES    AGE     VERSION
dp-master     Ready    master   18m     v1.30.8
dp-worker-1   Ready    worker   13m     v1.30.8
dp-worker-2   Ready    worker   6m36s   v1.30.8
dp-worker-3   Ready    worker   4m29s   v1.30.8
dp-worker-4   Ready    worker   75s     v1.30.8
dp-worker-5   Ready    worker   73s     v1.30.8
dp-worker-6   Ready    worker   70s     v1.30.8
```

## 7. Data Component 설치

Helm Chart를 Download 한다.

```shell
git clone https://github.com/ssup2-playground/k8s-data-platform_helm-charts.git
cd k8s-data-platform_helm-charts
```

Helm Chart를 통해서 Data Component를 설치한다.

```shell
# Metrics Server
helm upgrade --install --create-namespace --namespace kube-system metrics-server metrics-server -f metrics-server/values.yaml

# MetelLB
helm upgrade --install --create-namespace --namespace metallb metallb metallb -f metallb/values.yaml
kubectl apply -f metallb/ip-address-pool.yaml
kubectl apply -f metallb/l2-advertisement.yaml

# Cert Manager
helm upgrade --install --create-namespace --namespace cert-manager cert-manager cert-manager -f cert-manager/values.yaml

# NFS Provdier
kubectl apply -f nfs-server-provisioner/pv.yaml
helm upgrade --install --create-namespace --namespace nfs-server-provisioner nfs-server-provisioner nfs-server-provisioner -f nfs-server-provisioner/values.yaml

# Prometheus
helm upgrade --install --create-namespace --namespace prometheus prometheus prometheus -f prometheus/values.yaml
helm upgrade --install --create-namespace --namespace prometheus prometheus-node-exporter prometheus-node-exporter -f prometheus-node-exporter/values.yaml
helm upgrade --install --create-namespace --namespace prometheus kube-state-metrics kube-state-metrics -f kube-state-metrics/values.yaml

# Loki
helm upgrade --install --create-namespace --namespace loki loki loki -f loki/values.yaml
helm upgrade --install --create-namespace --namespace loki promtail promtail -f promtail/values.yaml

# Grafana (ID/PW: admin/root123!)
helm upgrade --install --create-namespace --namespace grafana grafana grafana -f grafana/values.yaml

# PostgreSQL (ID/PW: postgres/root123!)
helm upgrade --install --create-namespace --namespace postgresql postgresql postgresql -f postgresql/values.yaml
kubectl -n postgresql exec -it postgresql-0 -- bash -c 'PGPASSWORD=root123! psql -U postgres -c "create database keycloak;"'
kubectl -n postgresql exec -it postgresql-0 -- bash -c 'PGPASSWORD=root123! psql -U postgres -c "create database dagster;"'
kubectl -n postgresql exec -it postgresql-0 -- bash -c 'PGPASSWORD=root123! psql -U postgres -c "create database metastore;"'
kubectl -n postgresql exec -it postgresql-0 -- bash -c 'PGPASSWORD=root123! psql -U postgres -c "create database ranger;"'
kubectl -n postgresql exec -it postgresql-0 -- bash -c 'PGPASSWORD=root123! psql -U postgres -c "create database mlflow;"'
kubectl -n postgresql exec -it postgresql-0 -- bash -c 'PGPASSWORD=root123! psql -U postgres -c "create database mlflow_auth;"'

# Redis (ID/PW: default/default)
helm upgrade --install --create-namespace --namespace redis redis redis -f redis/values.yaml

# Kafka (ID/PW: user/user)
helm upgrade --install --create-namespace --namespace kafka kafka kafka -f kafka/values.yaml
helm upgrade --install --create-namespace --namespace kafka kafka-ui kafka-ui -f kafka-ui/values.yaml

# OpenSearch (ID/PW: admin/Rootroot123!)
helm upgrade --install --create-namespace --namespace opensearch opensearch opensearch -f opensearch/values.yaml
helm upgrade --install --create-namespace --namespace opensearch opensearch-dashboards opensearch-dashboards -f opensearch-dashboards/values.yaml

# MinIO (ID/PW: root/root123!)
helm upgrade --install --create-namespace --namespace minio minio minio -f minio/values.yaml
brew install minio/stable/mc
mc alias set dp http://$(kubectl -n minio get service minio -o jsonpath="{.status.loadBalancer.ingress[0].ip}"):9000 root root123!
mc mb dp/dagster/io-manager
mc mb dp/dagster/compute-log
mc mb dp/spark/logs

# ArgoCD (ID/PW: default/default)
helm upgrade --install --create-namespace --namespace argo-cd argo-cd argo-cd -f argo-cd/values.yaml

# Yunikorn
helm upgrade --install --create-namespace --namespace yunikorn yunikorn yunikorn -f yunikorn/values.yaml

# KEDA
helm upgrade --install --create-namespace --namespace keda keda keda -f keda/values.yaml

# Airflow (ID/PW: admin/admin)
helm upgrade --install --create-namespace --namespace airflow airflow airflow -f airflow/values.yaml

# Dagster
helm upgrade --install --create-namespace --namespace dagster dagster dagster -f dagster/values.yaml

# Ranger
helm upgrade --install --create-namespace --namespace ranger ranger ranger -f ranger/values.yaml

# Hive Metastore
helm upgrade --install --create-namespace --namespace hive-metastore hive-metastore hive-metastore -f hive-metastore/values.yaml

# Spark Operator
helm upgrade --install --create-namespace --namespace spark-operator spark-operator spark-operator -f spark-operator/values.yaml

# Spark History Server
helm upgrade --install --create-namespace --namespace spark-history-server spark-history-server spark-history-server -f spark-history-server/values.yaml

# Flink Kubernetes Operator
helm upgrade --install --create-namespace --namespace flink-kubernetes-operator flink-kubernetes-operator flink-kubernetes-operator -f flink-kubernetes-operator/values.yaml

# Trino (ID: root)
helm upgrade --install --create-namespace --namespace trino trino trino -f trino/values.yaml

# Clickhouse
helm upgrade --install --create-namespace --namespace clickhouse clickhouse clickhouse -f clickhouse/values.yaml

# JupyterHub (ID/PW: root/root123!)
helm upgrade --install --create-namespace --namespace jupyterhub jupyterhub jupyterhub -f jupyterhub/values.yaml

# MLflow (ID/PW: root/root123!)
helm upgrade --install --create-namespace --namespace mlflow mlflow mlflow -f mlflow/values.yaml
```

## 8. 참조

* Nvidia Containerd : [https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
* Airflow on Kubernetes : [https://zerohertz.github.io/k8s-airflow/](https://zerohertz.github.io/k8s-airflow/)

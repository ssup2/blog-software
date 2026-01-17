---
title: Kubernetes Data Platform Setup / Orange Pi 5 Max Cluster Environment
---

A cluster is configured using 7 OrangePi 5 Max devices to build a Kubernetes-based Data Platform.

## 1. Setup Environment

The specifications of the 7 OrangePi 5 Max devices used for Kubernetes Cluster configuration and the components to be installed are as follows.

{{< figure caption="[Figure 1] Cluster Spec" src="images/cluster-spec.png" width="800px" >}}

{{< figure caption="[Figure 2] Cluster Components" src="images/cluster-component.png" width="1000px" >}}

## 2. OS Installation

Follow the **2.6. Method for burning Linux images to SPIFlash+NVMeSSD** section in the [User Guide](documents/OrangePi_5_Max_RK3588_User%20Manual_v1.3.pdf) to install the OS on OrangePi 5 Max.

* Install Guide: [https://developer.nvidia.com/embedded/learn/get-started-jetson-nano-devkit#write](https://developer.nvidia.com/embedded/learn/get-started-jetson-nano-devkit#write)
* Debian bookworm OS: [https://drive.google.com/drive/folders/1b6hqA6zdgiScWvohsUdopBrtmytF4-ma](https://drive.google.com/drive/folders/1b6hqA6zdgiScWvohsUdopBrtmytF4-ma)

## 3. Hostname and Network Configuration

```shell
sudo -s
```

Enter as the `root` user.

```shell
hostnamectl set-hostname dp-master
```

Set the hostname by referring to [Figure 1].

```shell
nmcli con mod "Wired connection 1" \
  ipv4.addresses "[IP Address]/24" \
  ipv4.gateway "192.168.1.1" \
  ipv4.dns "8.8.8.8" \
  ipv4.method "manual"
```

Set a static IP by referring to [Figure 1].

## 4. containerd and kubelet Installation

```shell
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter
```

Load the kernel modules.

```shell
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system
```

Set the sysctl parameters.

```
swapoff -a
sed -i 's/^ENABLED=true/ENABLED=false/' "/etc/default/orangepi-zram-config"
```

Disable swap memory.

```shell
apt update
apt install -y containerd
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
systemctl restart containerd.service
```

Install containerd.

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

Install kubelet and kubeadm.

## 5. Kubernetes Cluster Configuration

### 5.1. Master Node

```shell
apt-get install -y kubectl=1.30.8-1.1
```

Install kubectl.

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

Configure the Kubernetes cluster.

```shell
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

Copy the kubectl config file.

```shell
kubectl patch deployment coredns -n kube-system -p '{"spec":{"template":{"spec":{"nodeSelector":{"node-group.dp.ssup2":"master"}}}}}'
```

Configure core-dns to run only on the master node.

```shell
kubectl apply -f https://github.com/flannel-io/flannel/releases/download/v0.26.2/kube-flannel.yml
```

Install the flannel CNI plugin.

```shell
mkdir -p /srv/nfs
```

Create a directory for use by the NFS server.

### 5.2. Worker Nodes

```shell
kubeadm join 192.168.1.71:6443 --token wweo8m.uyl4fgnc7j21orw5 --discovery-token-ca-cert-hash sha256:599058d317291ab64e0cc8166fe0f9cff5defcc606623fdb2c1aa1b2e2a93604
```

SSH into each node and join the Kubernetes cluster.

## 6. Label Configuration

```shell
kubectl taint node dp-master node-role.kubernetes.io/control-plane:NoSchedule-
kubectl label node dp-master node-role.kubernetes.io/control-plane-
```

Remove the master label and taint from the master node.

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

Assign roles to each node.

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

Verify the node roles.

## 7. Data Component Installation

```shell
git clone https://github.com/ssup2-playground/k8s-data-platform_helm-charts.git
cd k8s-data-platform_helm-charts
```

Download the Helm charts.

```shell
# Metrics Server
helm upgrade --install --create-namespace --namespace kube-system metrics-server metrics-server -f metrics-server/values.yaml

# MetalLB
helm upgrade --install --create-namespace --namespace metallb metallb metallb -f metallb/values.yaml
kubectl apply -f metallb/ip-address-pool.yaml
kubectl apply -f metallb/l2-advertisement.yaml

# Cert Manager
helm upgrade --install --create-namespace --namespace cert-manager cert-manager cert-manager -f cert-manager/values.yaml

# NFS Provider
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
# helm upgrade --install --create-namespace --namespace kafka kafka kafka -f kafka/values.yaml
helm upgrade --install --create-namespace --namespace kafka strimzi-kafka-operator strimzi-kafka-operator -f strimzi-kafka-operator/values.yaml
kubectl apply -f strimzi-kafka-operator/kafka.yaml
helm upgrade --install --create-namespace --namespace kafka schema-registry schema-registry -f schema-registry/values.yaml
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

# Volcano
helm upgrade --install --create-namespace --namespace volcano volcano volcano -f volcano/values.yaml

# KEDA
helm upgrade --install --create-namespace --namespace keda keda keda -f keda/values.yaml

# Airflow (ID/PW: admin/admin)
helm upgrade --install --create-namespace --namespace airflow airflow airflow -f airflow/values.yaml

# Dagster
helm upgrade --install --create-namespace --namespace dagster dagster dagster -f dagster/values.yaml
helm upgrade --install --create-namespace --namespace dagster dagster-workflows dagster-user-deployments -f dagster-user-deployments/values-workflows.yaml

# Ranger
helm upgrade --install --create-namespace --namespace ranger ranger ranger -f ranger/values.yaml

# Hive Metastore
helm upgrade --install --create-namespace --namespace hive-metastore hive-metastore hive-metastore -f hive-metastore/values.yaml

# Spark
helm upgrade --install --create-namespace --namespace spark spark-operator spark-operator -f spark-operator/values.yaml
helm upgrade --install --create-namespace --namespace spark spark-history-server spark-history-server -f spark-history-server/values.yaml

# Flink Kubernetes Operator
helm upgrade --install --create-namespace --namespace flink flink-kubernetes-operator flink-kubernetes-operator -f flink-kubernetes-operator/values.yaml

# Trino (ID: root)
helm upgrade --install --create-namespace --namespace trino trino trino -f trino/values.yaml

# Clickhouse
helm upgrade --install --create-namespace --namespace clickhouse clickhouse clickhouse -f clickhouse/values.yaml

# StarRocks
helm upgrade --install --create-namespace --namespace kube-starrocks kube-starrocks kube-starrocks -f kube-starrocks/values.yaml

# JupyterHub (ID/PW: root/root123!)
helm upgrade --install --create-namespace --namespace jupyterhub jupyterhub jupyterhub -f jupyterhub/values.yaml

# MLflow (ID/PW: root/root123!)
helm upgrade --install --create-namespace --namespace mlflow mlflow mlflow -f mlflow/values.yaml
```

Install data components via Helm charts.

## 8. References

* Nvidia Containerd: [https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
* Airflow on Kubernetes: [https://zerohertz.github.io/k8s-airflow/](https://zerohertz.github.io/k8s-airflow/)


---
title: Kubernetes Kubeflow Installation / Ubuntu 18.04 Environment
---

## 1. Installation Environment

{{< figure caption="[Figure 1] Node configuration diagram for Kubeflow installation" src="images/node-setting.png" width="900px" >}}

The installation environment is as follows:
* Kubernetes 1.18.14
* Kubeflow 1.2.0
* Istio 1.3
* Helm 3.4.2
* NFS Server
  * 192.168.0.60:/nfs-root/ssup2-kubeflow

## 2. NFS Package Installation

```shell
(Worker/Master)# apt-get install nfs-common
```

Install nfs-common package on Master and Worker Nodes to use NFS Client Provisioner in Kubernetes Cluster.

## 3. NFS Client Provisioner Installation

```shell
(User)# helm repo add stable https://charts.helm.sh/stable
(User)# helm repo update
(User)# helm install nfs-client-provisioner --set nfs.server=192.168.0.60 --set nfs.path=/nfs-root/ssup2-kubeflow stable/nfs-client-provisioner
(User)# kubectl get sc
NAME         PROVISIONER                            AGE
nfs-client   cluster.local/nfs-client-provisioner   5m52s
```

Install NFS Client Provisioner using Helm.

```shell
(User)# kubectl patch storageclass nfs-client -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

Set nfs-client Storage Class as Default Storage Class.

## 4. Kubernetes API Server Configuration

```text {caption="[File 1] /etc/kubernetes/manifests/kube-apiserver.yaml", linenos=table}
...
spec:
  containers:
  - command:
    - kube-apiserver
    - --service-account-signing-key-file=/etc/kubernetes/pki/sa.key
    - --service-account-issuer=kubernetes.default.svc
...
```

Add service-account-signing-key-file and service-account-issuer settings to the Master Node's /etc/kubernetes/manifests/kube-apiserver.yaml file as shown in [File 1] for Istio installation.

## 5. kfctl Installation

```shell
(User)# mkdir ~/kubeflow
(User)# cd ~/kubeflow
(User)# curl -L -O -J https://github.com/kubeflow/kfctl/releases/download/v1.2.0/kfctl-v1.2.0-0-gbc038f9-linux.tar.gz
(User)# tar -xvf kfctl-v1.2.0-0-gbc038f9-linux.tar.gz
(User)# rm kfctl-v1.2.0-0-gbc038f9-linux.tar.gz
```

Install kfctl, the kubeflow management tool.

## 6. Kubeflow Installation

```text {caption="[File 2] ~/kubeflow/kfctl-env", linenos=table}
export PATH=$PATH:~/kubeflow
export KF-NAME=ssup2-kubeflow
export BASE-DIR=~/kubeflow/cluster
export KF-DIR=${BASE-DIR}/${KF-NAME}
export CONFIG-URI="https://raw.githubusercontent.com/kubeflow/manifests/v1.2-branch/kfdef/kfctl-k8s-istio.v1.2.0.yaml"
```

Create an env file for kfctl with the content of [File 2].

```shell
(User)# . ~/kubeflow/kfctl-env
(User)# mkdir -p ${KF-DIR}
(User)# cd ${KF-DIR}
(User)# kfctl apply -V -f ${CONFIG-URI}
```

Install Kubeflow. After installation is complete, access Kubeflow Dashboard using the NodePort of the istio-ingressgateway Service in the istio-system Namespace.
  * http://192.168.0.61:31380/

## 7. References

* kustomize Install : [https://kubectl.docs.kubernetes.io/installation/kustomize/binaries/](https://kubectl.docs.kubernetes.io/installation/kustomize/binaries/)
* Kubeflow Install : [https://www.kubeflow.org/docs/started/k8s/kfctl-k8s-istio/](https://www.kubeflow.org/docs/started/k8s/kfctl-k8s-istio/)
* Kubeflow kustomize : [https://www.kubeflow.org/docs/other-guides/kustomize/](https://www.kubeflow.org/docs/other-guides/kustomize/)

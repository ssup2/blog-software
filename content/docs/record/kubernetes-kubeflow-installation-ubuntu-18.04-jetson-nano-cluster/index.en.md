---
title: Kubernetes Kubeflow Installation (Not Working) / Ubuntu 18.04, Jetson Nano Cluster Environment
---

***

* TOC
{:toc}

***

## 1. Installation Environment

* Kubeflow 1.2.0
* Kubernetes 1.18.14
* Helm 3.0.2
* NFS Server
  * `192.168.0.60:/nfs-root`

## 2. kustomize Installation

```shell
$ curl -s "https://raw.githubusercontent.com/\
kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash
```

Install the latest kustomize and use it because the kustomize included in the kubectl command does not support the `resources` syntax.

## 3. kfctl Installation

```shell
$ mkdir ~/kubeflow
$ cd ~/kubeflow
$ curl -L -O -J https://github.com/kubeflow/kfctl/releases/download/v1.2.0/kfctl_v1.2.0-0-gbc038f9_linux.tar.gz
$ tar -xvf kfctl_v1.2.0-0-gbc038f9_linux.tar.gz
$ rm kfctl_v1.2.0-0-gbc038f9_linux.tar.gz
```

Install kfctl, a Kubeflow management tool.

## 4. NFS Client Provisioner Installation

```shell
$ helm repo add stable https://charts.helm.sh/stable
$ helm repo update
$ helm install nfs-client-provisioner --set nfs.server=192.168.0.60 --set nfs.path=/nfs-root stable/nfs-client-provisioner-arm
$ kubectl get sc
NAME         PROVISIONER                            AGE
nfs-client   cluster.local/nfs-client-provisioner   5m52s
```

Install the NFS Client Provisioner using Helm.

```shell
$ kubectl patch storageclass nfs-client -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

Set the `nfs-client` Storage Class as the default Storage Class.

## 5. Kubeflow Installation

### 5.1. Kubeflow kustomize File Creation

```text {caption="[File 1] ~/kubeflow/kfctl-env", linenos=table}
export PATH=$PATH:~/kubeflow
export KF_NAME=ssup2-kubeflow
export BASE_DIR=~/kubeflow
export KF_DIR=${BASE_DIR}/${KF_NAME}
export CONFIG_URI="https://raw.githubusercontent.com/kubeflow/manifests/v1.2-branch/kfdef/kfctl_k8s_istio.v1.2.0.yaml"
```

Create an env file for kfctl with the content from [File 1].

```shell
$ . ~/kubeflow/kfctl-env
$ mkdir -p ${KF_DIR}
$ cd ${KF_DIR}
$ kfctl build -V -f ${CONFIG_URI}
```

Generate kustomize files for Kubeflow.

### 5.2. cert-manager Installation

```
# kustomize build --load-restrictor none ssup2-kubeflow/kustomize/cert-manager-crds | kubectl apply -f -
# kustomize build --load-restrictor none ssup2-kubeflow/kustomize/cert-manager-kube-system-resources  | kubectl apply -f -

# sed -i 's/cert-manager-cainjector:/cert-manager-cainjector-arm64:/g' ~/kubeflow/ssup2-kubeflow/.cache/manifests/manifests-1.2.0/cert-manager/cert-manager/base/deployment.yaml
# sed -i 's/cert-manager-controller:/cert-manager-controller-arm64:/g' ~/kubeflow/ssup2-kubeflow/.cache/manifests/manifests-1.2.0/cert-manager/cert-manager/base/deployment.yaml
# sed -i 's/cert-manager-webhook:/cert-manager-webhook-arm64:/g' ~/kubeflow/ssup2-kubeflow/.cache/manifests/manifests-1.2.0/cert-manager/cert-manager/base/deployment.yaml
# kustomize build --load-restrictor none ssup2-kubeflow/kustomize/cert-manager | kubectl apply -f -
```

### 5.3. istio Installation

## 6. References

* kustomize Install: [https://kubectl.docs.kubernetes.io/installation/kustomize/binaries/](https://kubectl.docs.kubernetes.io/installation/kustomize/binaries/)
* Kubeflow Install: [https://www.kubeflow.org/docs/started/k8s/kfctl_k8s_istio/](https://www.kubeflow.org/docs/started/k8s/kfctl_k8s_istio/)
* Kubeflow kustomize: [https://www.kubeflow.org/docs/other-guides/kustomize/](https://www.kubeflow.org/docs/other-guides/kustomize/)
* Kubeflow ARM Support: [https://github.com/kubeflow/kfctl/pull/318](https://github.com/kubeflow/kfctl/pull/318)


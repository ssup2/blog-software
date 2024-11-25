---
title: Kubernetes Kubeflow 설치 (Not Working) / Ubuntu 18.04, Jetson Nano Cluster 환경
---

***

* TOC
{:toc}

***

## 1. 설치 환경

* Kubeflow 1.2.0
* Kubernetes 1.18.14
* Helm 3.0.2
* NFS Server
  * 192.168.0.60:/nfs-root

## 2. kustomize 설치

```shell
$ curl -s "https://raw.githubusercontent.com/\
kubernetes-sigs/kustomize/master/hack/install-kustomize.sh"  | bash
```

kubectl 명령어에 포함된 kustomize는 resouces 문법을 지원하지 않기 때문에, 최신 kustomize를 설치하여 이용한다.

## 3. kfctl 설치

```shell
$ mkdir ~/kubeflow
$ cd ~/kubeflow
$ curl -L -O -J https://github.com/kubeflow/kfctl/releases/download/v1.2.0/kfctl-v1.2.0-0-gbc038f9-linux.tar.gz
$ tar -xvf kfctl-v1.2.0-0-gbc038f9-linux.tar.gz
$ rm kfctl-v1.2.0-0-gbc038f9-linux.tar.gz
```

kubeflow 관리 도구인 kfctl을 설치한다.

## 4. NFS Client Provisioner 설치

```shell
$ helm repo add stable https://charts.helm.sh/stable
$ helm repo update
$ helm install nfs-client-provisioner --set nfs.server=192.168.0.60 --set nfs.path=/nfs-root stable/nfs-client-provisioner-arm
$ kubectl get sc
NAME         PROVISIONER                            AGE
nfs-client   cluster.local/nfs-client-provisioner   5m52s
```

Helm을 이용하여 NFS Client Provisioner를 설치한다.

```shell
$ kubectl patch storageclass nfs-client -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

nfs-client Storage Class를 Default Storage Class로 설정한다.

## 5. Kubeflow 설치

### 5.1. Kubeflow kustomize 파일 생성

```text {caption="[File 1] ~/kubeflow/kfctl-env", linenos=table}
export PATH=$PATH:~/kubeflow
export KF-NAME=ssup2-kubeflow
export BASE-DIR=~/kubeflow
export KF-DIR=${BASE-DIR}/${KF-NAME}
export CONFIG-URI="https://raw.githubusercontent.com/kubeflow/manifests/v1.2-branch/kfdef/kfctl-k8s-istio.v1.2.0.yaml"
```

[File 1]의 내용으로 kfctl을 위한 env 파일을 생성한다.

```shell
$ . ~/kubeflow/kfctl-env
$ mkdir -p ${KF-DIR}
$ cd ${KF-DIR}
$ kfctl build -V -f ${CONFIG-URI}
```

Kubeflow를 kustomize 파일을 생성한다.

### 5.2. cert-manager 설치

```
# kustomize build --load-restrictor none ssup2-kubeflow/kustomize/cert-manager-crds | kubectl apply -f -
# kustomize build --load-restrictor none ssup2-kubeflow/kustomize/cert-manager-kube-system-resources  | kubectl apply -f -

# sed -i 's/cert-manager-cainjector:/cert-manager-cainjector-arm64:/g' ~/kubeflow/ssup2-kubeflow/.cache/manifests/manifests-1.2.0/cert-manager/cert-manager/base/deployment.yaml
# sed -i 's/cert-manager-controller:/cert-manager-controller-arm64:/g' ~/kubeflow/ssup2-kubeflow/.cache/manifests/manifests-1.2.0/cert-manager/cert-manager/base/deployment.yaml
# sed -i 's/cert-manager-webhook:/cert-manager-webhook-arm64:/g' ~/kubeflow/ssup2-kubeflow/.cache/manifests/manifests-1.2.0/cert-manager/cert-manager/base/deployment.yaml
# kustomize build --load-restrictor none ssup2-kubeflow/kustomize/cert-manager | kubectl apply -f -
```

### 5.3. isito 설치

## 6. 참조

* kustomize Install : [https://kubectl.docs.kubernetes.io/installation/kustomize/binaries/](https://kubectl.docs.kubernetes.io/installation/kustomize/binaries/)
* Kubeflow Install : [https://www.kubeflow.org/docs/started/k8s/kfctl-k8s-istio/](https://www.kubeflow.org/docs/started/k8s/kfctl-k8s-istio/)
* Kubeflow kustomize : [https://www.kubeflow.org/docs/other-guides/kustomize/](https://www.kubeflow.org/docs/other-guides/kustomize/)
* Kubeflow ARM Support : [https://github.com/kubeflow/kfctl/pull/318](https://github.com/kubeflow/kfctl/pull/318)
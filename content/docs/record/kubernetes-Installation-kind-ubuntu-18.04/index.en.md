---
title: Kubernetes Installation / Using kind / Ubuntu 18.04 Environment
---

## 1. Installation Environment

* Ubuntu 18.04.5
* kind v0.10.0
* kubernetes v1.20.2

## 2. kind Installation

```shell
$ curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.10.0/kind-linux-amd64
$ chmod +x ./kind
$ mv ./kind /usr/bin/kind
```

Install kind.

## 3. Cluster Creation

```text {caption="[File 1] kind-config.yaml", linenos=table}
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
```

Create a kind-config.yaml file with the contents shown in [File 1] to configure kind to create a Kubernetes cluster with 1 Master and 2 Workers.

```shell
$ kind create cluster --config kind-config.yaml
```

Create a Kubernetes cluster using the created kind-config.yaml file.

## 4. Cluster Verification

```shell
$ # kubectl get nodes -o wide
NAME                 STATUS   ROLES                  AGE   VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE       KERNEL-VERSION     CONTAINER-RUNTIME
kind-control-plane   Ready    control-plane,master   20h   v1.20.2   172.18.0.3    <none>        Ubuntu 20.10   5.4.0-52-generic   containerd://1.4.0-106-gce4439a8
kind-worker          Ready    <none>                 20h   v1.20.2   172.18.0.2    <none>        Ubuntu 20.10   5.4.0-52-generic   containerd://1.4.0-106-gce4439a8
kind-worker2         Ready    <none>                 20h   v1.20.2   172.18.0.4    <none>        Ubuntu 20.10   5.4.0-52-generic   containerd://1.4.0-106-gce4439a8

$ kubectl -n kube-system get pod -o wide
NAME                                         READY   STATUS    RESTARTS   AGE   IP           NODE                 NOMINATED NODE   READINESS GATES
coredns-74ff55c5b-8p8wc                      1/1     Running   0          19h   10.244.0.2   kind-control-plane   <none>           <none>
coredns-74ff55c5b-nsh6c                      1/1     Running   0          19h   10.244.0.4   kind-control-plane   <none>           <none>
etcd-kind-control-plane                      1/1     Running   0          20h   172.18.0.3   kind-control-plane   <none>           <none>
kindnet-dbbwm                                1/1     Running   0          19h   172.18.0.2   kind-worker          <none>           <none>
kindnet-kmkbq                                1/1     Running   0          19h   172.18.0.4   kind-worker2         <none>           <none>
kindnet-ncfz5                                1/1     Running   0          19h   172.18.0.3   kind-control-plane   <none>           <none>
kube-apiserver-kind-control-plane            1/1     Running   0          20h   172.18.0.3   kind-control-plane   <none>           <none>
kube-controller-manager-kind-control-plane   1/1     Running   0          20h   172.18.0.3   kind-control-plane   <none>           <none>
kube-proxy-6n8pv                             1/1     Running   0          19h   172.18.0.2   kind-worker          <none>           <none>
kube-proxy-kvnxq                             1/1     Running   0          19h   172.18.0.3   kind-control-plane   <none>           <none>
kube-proxy-ttpxl                             1/1     Running   0          19h   172.18.0.4   kind-worker2         <none>           <none>
kube-scheduler-kind-control-plane            1/1     Running   0          20h   172.18.0.3   kind-control-plane   <none>           <none>
```

Verify the created Kubernetes cluster.

```shell
$ docker ps
CONTAINER ID        IMAGE                  COMMAND                  CREATED             STATUS              PORTS                       NAMES
e822ea854922        kindest/node:v1.20.2   "/usr/local/bin/entr…"   8 minutes ago       Up 8 minutes                                    kind-worker
5d1428f8c37c        kindest/node:v1.20.2   "/usr/local/bin/entr…"   8 minutes ago       Up 8 minutes        127.0.0.1:41593->6443/tcp   kind-control-plane
21da173648df        kindest/node:v1.20.2   "/usr/local/bin/entr…"   8 minutes ago       Up 8 minutes                                    kind-worker2
```

Since it is configured with 1 Master and 2 Worker nodes, you can see that 3 Docker containers are running.

## 5. References

* [https://kind.sigs.k8s.io/docs/user/quick-start/](https://kind.sigs.k8s.io/docs/user/quick-start/)


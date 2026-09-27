---
title: Kubernetes PKI
---

This article analyzes the Kubernetes PKI (Public Key Infrastructure).

## 1. Kubernetes PKI

{{< figure caption="[Figure 1] Kubernetes Certificate, Key with kubeadm" src="images/kubernetes-cert-key.png" width="1000px" >}}

Kubernetes Components encrypt communication between each other using TLS. [Figure 1] shows the Certificates and Keys that Kubernetes uses for TLS when a Kubernetes Cluster is configured using `kubeadm`. All Certificates are generated using a Private CA (Certificate Authority). The Certificates and Keys in the Tree relationship in [Figure 1] represent the Chain of Trust. `sa.pub,key` does not mean a certificate; it means a Private/Public Key pair, and no CA exists for it.

{{< figure caption="[Figure 2] Kubernetes PKI with kubeadm" src="images/kubernetes-pki.png" width="800px" >}}

[Figure 2] shows the Kubernetes PKI configured using `kubeadm` based on the Certificates and Keys of [Figure 1]. Certificates and Keys marked in Non-bold mean the same Certificate and Key throughout the Cluster. For example, in [Figure 2], the `etcd/ca.crt` of the Kubernetes API Server and the `etcd/ca.crt` of the etcd Server represent the same Certificate. Certificates and Keys marked in Bold mean Certificates and Keys that are different for each Instance/File. For example, in [Figure 2], the `etcd/peer.crt,key` of the etcd Server means that it is different for each etcd Server.

The etcd Server uses `etcd/peer.crt,key` and `etcd/server.crt,key`. `etcd/peer.crt,key` is used for communication between the etcd Servers in the Cluster. `etcd/server.crt,key` serves as the Certificate and Key of the etcd Server, and is used for communication with `etcdctl`, the Client of etcd, or the Kubernetes API Server. `etcdctl` uses `etcd/healthcheck-client.crt,key` when connecting to the etcd Server.

The remaining Kubernetes Components except the etcd Server use `client.crt,key`, generated based on `ca.crt`, to communicate with the Kubernetes API Server, which uses `apiserver.crt,key`. The Kubernetes API Server uses `apiserver-kubelet-client.crt,key` when connecting to kubelet, and uses the `front-proxy-client.crt,key` file when connecting to a Kubernetes Extension API Server defined by a Kubernetes user. kubelet performs the Server role using `kubelet.crt,key` that it generates by itself. The Kubernetes Scheduler and Controller Manager also perform the Server role using Certificates and Keys that they generate by themselves in Memory.

`sa.pub,key` is used to encrypt/decrypt the Service Account Token of Kubernetes. The Service Account Token is encrypted in the Kubernetes Controller Manager and decrypted in the Kubernetes API Server.

## 2. References

* PKI Certificates and Requirements : [https://kubernetes.cn/docs/setup/best-practices/certificates/](https://kubernetes.cn/docs/setup/best-practices/certificates/)
* Set up a High Availability etcd Cluster with kubeadm : [https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/setup-ha-etcd-with-kubeadm/](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/setup-ha-etcd-with-kubeadm/)
* Configure the Aggregation Layer : [https://kubernetes.io/docs/tasks/access-kubernetes-api/configure-aggregation-layer/](https://kubernetes.io/docs/tasks/access-kubernetes-api/configure-aggregation-layer/)
* kubernetes-sigs/apiserver-builder-alpha : [https://github.com/kubernetes-sigs/apiserver-builder-alpha](https://github.com/kubernetes-sigs/apiserver-builder-alpha)

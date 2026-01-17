---
title: Kubernetes etcd State Query
---

## 1. Execution Environment

The execution environment is as follows.

* Kubernetes 1.15
* etcd 3.3.10

## 2. etcd Key Query

```shell
(Node)$ kubectl -n kube-system exec -it etcd-vm01 sh
(Container)$ ETCDCTL-API=3 etcdctl --endpoints 127.0.0.1:2379 --cacert /etc/kubernetes/pki/etcd/ca.crt --cert /etc/kubernetes/pki/etcd/server.crt --key /etc/kubernetes/pki/etcd/server.key get / --prefix --keys-only
/registry/apiextensions.k8s.io/customresourcedefinitions/adapters.config.istio.io

/registry/apiextensions.k8s.io/customresourcedefinitions/apikeys.config.istio.io

/registry/apiextensions.k8s.io/customresourcedefinitions/attributemanifests.config.istio.io

/registry/apiextensions.k8s.io/customresourcedefinitions/authorizations.config.istio.io

/registry/apiextensions.k8s.io/customresourcedefinitions/bypasses.config.istio.io

/registry/apiextensions.k8s.io/customresourcedefinitions/checknothings.config.istio.io
...
```

After entering the etcd container using kubectl, execute the etcdctl key query command. The API version must be explicitly specified using the ETCDCTL-API environment variable, and certificate-related files must also be specified via options. Since the query was performed on the **/ (root)** path, all keys held by etcd are queried.

## 3. References

* [https://stackoverflow.com/questions/47807892/how-to-access-kubernetes-keys-in-etcd](https://stackoverflow.com/questions/47807892/how-to-access-kubernetes-keys-in-etcd)


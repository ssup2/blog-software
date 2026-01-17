---
title: Kubernetes etcd Snapshot, Restoring
---

## 1. Execution Environment

The execution environment is as follows.

* Kubernetes 1.15
* etcd 3.3.10

## 2. etcd Snapshot

```shell
(Node)$ kubectl -n kube-system exec -it etcd-vm01 sh
(Container)$ ETCDCTL-API=3 etcdctl --endpoints 127.0.0.1:2379 --cacert /etc/kubernetes/pki/etcd/ca.crt --cert /etc/kubernetes/pki/etcd/server.crt --key /etc/kubernetes/pki/etcd/server.key snapshot save snap
Snapshot saved at snap
```

After entering the etcd Container using kubectl, perform a Snapshot using etcdctl. The Snapshot File name is set to snap. The API Version must be explicitly specified using the ETCDCTL-API environment variable, and certificate-related files must also be specified through Options.

```shell
(Container)$ ETCDCTL-API=3 etcdctl --endpoints 127.0.0.1:2379 --cacert /etc/kubernetes/pki/etcd/ca.crt --cert /etc/kubernetes/pki/etcd/server.crt --key /etc/kubernetes/pki/etcd/server.key snapshot status snap
57da4498, 1915062, 2013, 9.3 MB
```

Check the status of the Snapshot File using etcdctl.

## 3. etcd Restore

```shell
(Node)$ kubectl -n kube-system exec -it etcd-vm01 sh
(Container)$ ETCDCTL-API=3 etcdctl --endpoints 127.0.0.1:2379 --cacert /etc/kubernetes/pki/etcd/ca.crt --cert /etc/kubernetes/pki/etcd/server.crt --key /etc/kubernetes/pki/etcd/server.key snapshot restore snap --data-dir="/var/lib/etcd"
```

Restore etcd through the Snapshot File.

## 4. References

* [https://stackoverflow.com/questions/47807892/how-to-access-kubernetes-keys-in-etcd](https://stackoverflow.com/questions/47807892/how-to-access-kubernetes-keys-in-etcd)


---
title: Kubernetes Ceph RBD Integration / Ubuntu 18.04 Environment
---

## 1. Configuration Environment

The configuration environment is as follows.
* Kubernetes 1.12
* Ceph
  * Monitor IP : 10.0.0.10:6789
  * Pool Name : kube

## 2. Ceph RDB Integration

```shell
$ ceph auth get client.admin 2>&1 |grep "key = " |awk '{print  $3'} |xargs echo -n > /tmp/secret
$ kubectl create secret generic ceph-admin-secret --from-file=/tmp/secret --namespace=kube-system
```

Create a Ceph Admin secret.

```shell
$ ceph osd pool create kube 8 8
$ ceph auth add client.kube mon 'allow r' osd 'allow rwx pool=kube'
$ ceph auth get-key client.kube > /tmp/secret
$ kubectl create secret generic ceph-secret --from-file=/tmp/secret --namespace=kube-system
```

Create a Ceph Pool and User secret.

```shell
$ git clone https://github.com/kubernetes-incubator/external-storage.git
$ cd external-storage/ceph/rbd/deploy
```

Download rbd-provisioner, role, and cluster role yaml files.

```yaml {caption="[File 1] rbac/clusterrole.yaml", linenos=table}
...
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "create", "delete"]
```

Add the contents of [File 1] to the rbac/clusterrole.yaml file. (Secret Role)

```shell
$ NAMESPACE=default
$ sed -r -i "s/namespace: [^ ]+/namespace: $NAMESPACE/g" ./rbac/clusterrolebinding.yaml ./rbac/rolebinding.yaml
$ kubectl -n $NAMESPACE apply -f ./rbac 
```

Configure rbd-provisioner, role, and cluster role.

```yaml {caption="[File 2] storage-class.yaml", linenos=table}
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: kube
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ceph.com/rbd
parameters:
  monitors: 10.0.0.10:6789
  pool: kube
  adminId: admin
  adminSecretNamespace: kube-system
  adminSecretName: ceph-admin-secret
  userId: kube
  userSecretNamespace: kube-system
  userSecretName: ceph-secret
  imageFormat: "2"
  imageFeatures: layering
```

Create the storage-class.yaml file and save it with the contents of [File 2].

```shell
$ kubectl create -f ./storage-class.yaml
$ kubectl get storageclasses.storage.k8s.io
NAME            PROVISIONER    AGE
rbd (default)   ceph.com/rbd   19m
```

Create and verify the Storage Class.

## 3. References

* [https://github.com/kubernetes-incubator/external-storage/tree/master/ceph/rbd](https://github.com/kubernetes-incubator/external-storage/tree/master/ceph/rbd)
* [http://blog.51cto.com/ygqygq2/2163656](http://blog.51cto.com/ygqygq2/2163656)


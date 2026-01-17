---
title: Kubernetes netshoot Shell Pod Execution
---

## 1. Execution Environment

The execution environment is as follows.

* Kubernetes 1.18

## 2. netshoot Shell Pod Execution

```shell
$ kubectl run my-shell --rm -i --tty --image nicolaka/netshoot -- bash
```

Create a netshoot Pod and enter Bash.

### 2.1. With Host Network Namespace

```yaml {caption="[File 1] Master Node - /etc/netplan/50-cloud-init.yaml", linenos=table}
apiVersion: v1
kind: Pod
metadata:
  name: my-shell-hostnet
  namespace: default
spec:
  hostNetwork: true
  dnsPolicy: ClusterFirstWithHostNet
  containers:
  - name: my-shell-hostnet
    image: nicolaka/netshoot
    args:
    - sleep
    - infinity
```

Create a netshoot Pod using the Host Network Namespace with [File 1].

```shell
$ kubectl exec -it my-shell-hostnet -- bash
```

Enter the netshoot Pod.


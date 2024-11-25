---
title: Kubernetes netshoot Shell Pod 실행
---

## 1. 실행 환경

실행 환경은 다음과 같다.

* Kubernetes 1.18

## 2. netshoot Shell Pod 실행

```shell
$ kubectl run my-shell --rm -i --tty --image nicolaka/netshoot -- bash
```

netshoot Pod을 생성하고 Bash로 진입한다.

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

[File 1]을 이용하여 Host Network Namespace를 이용하는 netshoot Pod을 생성한다.

```shell
$ kubectl exec -it my-shell-hostnet -- bash
```

netshoot Pod에 진입한다.


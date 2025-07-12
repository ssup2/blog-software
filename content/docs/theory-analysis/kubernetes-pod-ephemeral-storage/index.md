---
title: Kubernetes Pod Ephemeral Storage
---

## 1. Kubernetes Pod Ephemeral Storage

Kubernetes Pod는 동작에 필요한 Node의 Storage를 Ephemeral Storage로 정의하여 이용하며, 필요에 따라서는 제한도 가능하다. 다음의 목적으로 Ephemeral Storage를 이용한다.

* Container Image Writable Layer
* Container Log
* `emptyDir` Volume, 단 `tmpfs` medium이 `memory`인 경우에는 해당되지 않는다.

```yaml {caption="[File 1] Ephemeral Storage Pod Example", linenos=table}
apiVersion: v1
kind: Pod
metadata:
  name: my-shell
spec:
  containers:
  - name: my-shell
    image: nicolaka/netshoot:v0.14
    resources:
      requests:
        ephemeral-storage: "1Gi"
      limits:
        ephemeral-storage: "2Gi"
    volumeMounts:
    - name: emptydir-storage
      mountPath: "/tmp"
  volumes:
    - name: emptydir-storage
      emptyDir:
        sizeLimit: 500Mi
```

[File 1]은 Ephemeral Storage를 설정하는 `my-shell` Pod의 예제를 나타낸다. `my-shell` Container는 Request로 `1Gi`를 설정하고, Limit으로 `2Gi`를 설정하였다. `emptydir-storage` 이름의 `emptyDir` Volume도 설정되어 있으며 크기는 `500Mi`로 제한되어 있다.

Request의 Ephemeral Storage는 Scheduler가 Pod를 스케줄링할 때만 참조되며, Limit의 Ephemeral Storage는 Container가 실제 사용할 수 있는 최대 크기를 의미한다. 따라서 `my-shell` Container의 Container Image Writable Layer, Container Log, `emptyDir` Volume를 Ephemeral Storage의 크기의 합이 `4Gi`를 초과하는 경우에는 Evicted 된다. 또한 `emptydir-storage` Volume의 크기가 `500Mi`를 초과하는 경우에도 Evicted 된다.

## 2. 참조

* Ephemeral Storage : [https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#local-ephemeral-storage](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#local-ephemeral-storage)
* Kubernetes Shared Memory : [https://ykarma1996.tistory.com/106](https://ykarma1996.tistory.com/106)
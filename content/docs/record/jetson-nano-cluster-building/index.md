---
title: Jetson Nano Cluster 구축
---

Kubernetes 설치를 위한 Jetson Nano Cluster를 구축한다.

## 1. Jetson Nano Cluster

{{< figure caption="[사진 1] Jetson Nano Cluster 구성 사진" src="images/cluster-photo.png" width="900px" >}}

{{< figure caption="[Figure 1] Jetson Nano Cluster 구성" src="images/cluster.png" width="900px" >}}

[사진 1]은 Jetson Nano Cluster의 실제 모습을 보여주고 있다. [Figure 1]은 Jetson Nano Cluster를 나타내고 있다. 모든 Jetson Nano의 Spec은 동일하다. Jetson Nano Cluster의 주요 사양은 아래와 같다.

* Jetson Nano * 4
  * CPU : 4Core ARM Cortex-A57
  * Memory : 4GB * LPDDR4
  * Root Storage : 64GB, MicroSD
* Network
  * NAT Network : 192.168.0.0/24

### 1.1. Kubernetes

{{< figure caption="[Figure 2] Ceph 구성 on Jetson Nano Cluster" src="images/k8s.png" width="900px" >}}

[Figure 2]는 Kubernetes Cluster 구성시 각 Node의 역할을 나타내고 있다. 첫번째 Jetson Nano만 Master로 동작하고 나머지 Jetson Nano는 Slave로 동작한다.

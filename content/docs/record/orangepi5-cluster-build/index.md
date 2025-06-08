---
title: Orange Pi 5 Max Cluster 구축
---

## 1. Orange Pi 5 Cluster

{{< figure caption="[Photo 1] Cluster 구성 사진" src="images/cluster-photo.png" width="700px" >}}

{{< figure caption="[Figure 1] Cluster 구성" src="images/cluster.png" width="900px" >}}

[Photo 1]은 Orange Pi 5 Max Cluster의 실제 모습을 보여주고 있다. [Figure 1]은 Orange Pi 5 Max Cluster의 구성도를 나타내고 있다. Master Node와 Worker Node로 구성되어 있다.

* Master Node : Kubernetes Cluster의 Control Plane 역할을 수행하는 Master Node의 역활을 수행하며, NFS 기반의 Volume을 제공하기 위한 Storage Server 역할도 수행한다.
* Worker Node : 대부분의 Application이 동작하는 Worker Node의 역할을 수행한다.
---
title: Raspberry Pi 5, Jetson Nano Cluster 구축
---

## 1. Raspberry Pi 5, Jetson Nano Cluster

{{< figure caption="[Photo 1] ODROID-H2 Cluster 구성 사진" src="images/cluster-photo.png" width="700px" >}}

{{< figure caption="[Figure 1] ODROID-H2 Cluster 구성" src="images/cluster.png" width="900px" >}}

[Photo 1]은 Raspberry Pi 5, Jetson Nano Cluster의 실제 모습을 보여주고 있다. [Figure 1]은 Raspberry Pi 5, Jetson Nano Cluster의 구성도를 나타내고 있다. 4가지 Type의 Node 또는 Node Group으로 구성되어 있다. 

* Master Node : Kubernetes Cluster의 Control Plane 역할을 수행하는 Master Node이다. Raspberry Pi 5로 구성되어 있다.
* Worker Node Group : Computing 관련 Workload가 동작하는 Node Group이다. 2대의 Raspberry Pi 5로 구성되어 있다.
* Storage Node Group : Storage 관련 Workload가 동작하는 Node Group이다. 2대의 Raspberry Pi 5로 구성되어 있으며, 256 Micro USD 카드를 이용한다.
* GPU Node Group : GPU 관련 Workload가 동작하는 Node Group이다. 2대의 Jetson Nano로 구성되어 있다.
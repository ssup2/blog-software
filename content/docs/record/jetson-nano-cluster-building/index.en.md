---
title: Jetson Nano Cluster Setup
---

Set up a Jetson Nano cluster for Kubernetes installation.

## 1. Jetson Nano Cluster

{{< figure caption="[Photo 1] Jetson Nano Cluster Setup Photo" src="images/cluster-photo.png" width="900px" >}}

{{< figure caption="[Figure 1] Jetson Nano Cluster Configuration" src="images/cluster.png" width="900px" >}}

[Photo 1] shows the actual appearance of the Jetson Nano cluster. [Figure 1] shows the Jetson Nano cluster configuration. All Jetson Nano devices have the same specifications. The main specifications of the Jetson Nano cluster are as follows.

* Jetson Nano * 4
  * CPU : 4Core ARM Cortex-A57
  * Memory : 4GB * LPDDR4
  * Root Storage : 64GB, MicroSD
* Network
  * NAT Network : 192.168.0.0/24

### 1.1. Kubernetes

{{< figure caption="[Figure 2] Ceph Configuration on Jetson Nano Cluster" src="images/k8s.png" width="900px" >}}

[Figure 2] shows the role of each node when configuring a Kubernetes cluster. Only the first Jetson Nano operates as Master, and the remaining Jetson Nano devices operate as Slaves.


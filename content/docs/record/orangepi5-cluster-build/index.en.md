---
title: Orange Pi 5 Max Cluster Construction
---

## 1. Orange Pi 5 Cluster

{{< figure caption="[Photo 1] Cluster Configuration Photo" src="images/cluster-photo.png" width="700px" >}}

{{< figure caption="[Figure 1] Cluster Configuration" src="images/cluster.png" width="900px" >}}

[Photo 1] shows the actual appearance of the Orange Pi 5 Max Cluster. [Figure 1] represents the configuration diagram of the Orange Pi 5 Max Cluster. It consists of Master Node and Worker Node.

* Master Node : Performs the role of a Master Node that serves as the Control Plane of the Kubernetes Cluster, and also performs the role of a Storage Server to provide NFS-based volumes.
* Worker Node : Performs the role of a Worker Node where most applications run.

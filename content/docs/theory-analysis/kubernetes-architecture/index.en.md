---
title: Kubernetes Architecture
---

Analyzes Kubernetes Architecture.

## 1. Kubernetes Architecture

{{< figure caption="[Figure 1] Kubernetes Architecture" src="images/kubernetes-architecture.png" width="700px" >}}

[Figure 1] shows the Kubernetes Architecture. Kubernetes consists of Master Nodes that manage Kubernetes and Worker Nodes where deployed applications run. Depending on Kubernetes configuration, Master Nodes can also perform the role of Worker Nodes.

### 1.1. All Node

kubelet operates as a daemon on the node, like a Systemd service, and runs on all nodes that make up the Kubernetes cluster. Both kube-proxy and Network Daemon operate as Pods in DaemonSet and run on all nodes that make up the Kubernetes cluster, like kubelet.

* kubelet : Receives commands from kube-apiserver and controls Pods through a Container Runtime that complies with the OCI Runtime Spec. containerd is a representative Container Runtime. kubelet also configures the network of created Pods through CNI Plugins. The kubelet on Master Nodes also manages kube-apiserver, kube-controller-manager, and kube-scheduler Pods.

* kube-proxy : Performs the role of a Proxy Server to expose Kubernetes Services inside or outside the Kubernetes cluster, or controls iptables or IPVS according to Kubernetes Services.

* Network Daemon : Obtains information from kube-apiserver and configures the Node (Host) network to enable communication between Pods. Since Network Daemon operates in the Host Network Namespace and has permissions to change network settings, it can freely change the Node's network settings. The Network Daemon is determined by which CNI Plugin is used. flannel's flanneld, calico's calico-felix, and cilium's cilium-agent can be considered Network Daemons.

### 1.2. Master Node

Master Node is a node that manages the Kubernetes cluster. Generally, multiple odd-numbered Master Nodes are used for HA (High Availability). Only etcd, kube-apiserver, kube-scheduler, and kube-controller-manager run on Master Nodes.

* etcd : etcd is a distributed key-value storage that **stores Kubernetes Cluster-related data**. When multiple Master Nodes are running, etcd instances form an etcd cluster and operate, and data consistency between etcd instances in the etcd cluster is maintained through the Raft algorithm. etcd provides a Watcher feature that delivers data change events to clients monitoring the data when data changes. Kubernetes clusters use the etcd cluster as an **Event Bus** using this Watcher feature.

* kube-apiserver : A server that provides REST APIs for controlling Kubernetes. It is also the only component that communicates with etcd. Therefore, kube-apiserver must be used to store Kubernetes cluster-related data in etcd or receive data change events from etcd. [Figure 1] shows that most Kubernetes components communicate with kube-apiserver.

* kube-controller-manager : In Kubernetes, objects created through yaml syntax defined by Kubernetes are called **Objects**. Pods, Deployments, StatefulSets, ConfigMaps, etc. are examples of Objects. Components that control these Objects are called **Controllers**. kube-controller-manager manages these Controllers. Controllers obtain state information of Objects they want to control through kube-apiserver, and control Objects through kube-apiserver again based on the obtained state information.

* kube-scheduler : Handles Pod scheduling. kube-scheduler obtains Pod state and resource state information of each Worker Node through kube-apiserver, and performs Pod scheduling through kube-apiserver again based on the obtained state information.

### 1.3. Worker Node

Worker Node is a node where applications deployed by Kubernetes users run.

* coredns : Since Pod IPs can always change, it is better to obtain Pod IPs through DNS rather than using Pod IPs directly when communicating with Pods. coredns performs the DNS role of finding other Pod IPs from within Pods. Similarly, since Kubernetes Service IPs can also change at any time, coredns also performs the DNS role of finding Service IPs from within Pods.

* CNI Plugin : Used when configuring Pod networks. It is called a CNI Plugin because it complies with CNI (Container Network Interface). Although not shown in [Figure 1], when applications also run on Master Nodes, CNI Plugins can also be installed on Master Nodes to configure App Pod networks.

## 2. References

* [https://www.aquasec.com/wiki/display/containers/Kubernetes+Architecture+101](https://www.aquasec.com/wiki/display/containers/Kubernetes+Architecture+101)
* [https://www.slideshare.net/harryzhang735/kubernetes-beyond-a-black-box-part-1](https://www.slideshare.net/harryzhang735/kubernetes-beyond-a-black-box-part-1)
* [https://www.slideshare.net/harryzhang735/kubernetes-beyond-a-black-box-part-2](https://www.slideshare.net/harryzhang735/kubernetes-beyond-a-black-box-part-2)


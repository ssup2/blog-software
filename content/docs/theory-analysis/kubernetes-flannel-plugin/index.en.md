---
title: Kubernetes flannel Plugin
---

This post analyzes flannel, a Kubernetes Network Plugin.

## 1. flannel

{{< figure caption="[Figure 1] flannel Components" src="images/flannel-components.png" width="400px" >}}

**flannel** is a Plugin that builds an L3 Network for Kubernetes. [Figure 1] shows the components of flannel. It largely consists of two components: **etcd and flanneld**. etcd runs in the Kubernete Cluster. flanneld runs inside the flanneld Pod that runs on every Kubernetes Host. Since the flanneld Pod uses the Network Namespace of the Host (Node), the App running inside the calico-node Pod can query or control the Network settings of the Host.

* **etcd** : etcd is a distributed Key-Value store. It stores various information such as the Network configuration/settings information required to run Flannel and Calico configuration information. It also performs the role of a Communication Bus that delivers change information to flanneld when a stored key-value is changed.
* **flanneld** : flanneld is a Daemon that configures the Network of the Host. Based on the Network configuration information stored in etcd, it configures the Network Inteface, Route Table, and iptables of the Host so that Packets are routed to the correct Pod.

### 1.1. Pod Network with host-gw

{{< figure caption="[Figure 2] flannel host-gw Pod Network" src="images/flannel-network-host-gw.png" width="900px" >}}

flannel provides the `host-gw` technique as one technique for building the Pod Network. The `host-gw` technique is, as the name suggests, a technique that uses the host as a gateway. [Figure 2] shows the Network configured by flannel using the `host-gw` technique. The Host Network is 10.0.0.0/24, and the Pod Network is 10.244.0.0/16.

flanneld allocates a Pod Network to each Host based on the information stored in etcd. In the figure, the 10.244.1.0/24 Network is allocated to Host1. Therefore, Pod A created on Host 1 uses 10.244.1.2, an IP belonging to the 10.244.1.0/24 Network. Since the 10.244.2.0/24 Network is allocated to Host 2, Pod B created on Host 2 uses 10.244.2.2, an IP belonging to the 10.244.2.0/24 Network. On Host 1, the IP of Host 2 is set as the Default GW of Host 2's Pod Network. Conversely, on Host 2, the IP of Host 1 is set as the Default GW of Host 1's Pod Network.

When Pod A sends a Packet whose Dest IP is 10.244.2.2, the Packet passes through `vethxxx` and the cni Bridge and is then routed again according to the Routing Table of the Host. Since the Dest IP of the Packet belongs to the 10.244.2.0/24 Network, the Packet is forwarded to Host 2. That is, only the Dest MAC of the Packet is changed to the Mac Address of Host 2 and the Packet is delivered to Host 2. After that, the Packet is delivered to `cni0` according to the Routing Table of Host 2 and then delivered to Pod B.

Since the `host-gw` technique only replaces the Dest MAC of the Packet, it shows higher performance than the VXLAN technique. However, the `host-gw` technique works only when all Hosts (Host) are on the same Network. This is because only the Dest MAC of the Packet sent by the Pod is changed by the Routing Table of the Host, while the Dest IP of the Packet, the Pod Network IP, remains unchanged.

In [Figure 2], the Dest IP 10.244.2.2 of the Packet is delivered to the Pod without being changed. If the Hosts are on different Networks and the Packet is delivered to the Router that connects the Host Networks, the Packet is dropped because the Router has no Routing Rule for the Pod Network. To apply the `host-gw` technique to Hosts on different Networks, Routing Rules for the Pod Network must be manually added to and managed on the Router.

### 1.2. Pod Network with VXLAN

{{< figure caption="[Figure 3] flannel VXLAN Pod Network" src="images/flannel-network-vxlan.png" width="900px" >}}

flannel provides the VXLAN technique as one technique for building the Pod Network. The VXLAN technique is, as the name suggests, a technique that uses VXLAN. [Figure 3] shows the Network configured by flannel using the VXLAN technique. The Host Network and Pod Network, the Pod Network allocated to each Host, the Host IPs, and the Pod IPs are the same as in the example of the `host-gw` technique.

The difference from the `host-gw` technique is that each Host has a VXLAN Interface called `flannel.1`. On Host 1, the `flannel.1` Interface of Host 2 is set as the Default GW of Host 2's Pod Network. Conversely, on Host 2, the `flannel.1` Interface of Host 1 is set as the Default GW of Host 1's Pod Network. When a Packet leaves the Host, it is encapsulated with VXLAN according to the configuration of the `flannel.1` Inteface, and when it enters the Host, it is decapsulated. `flannel.1` is configured to use 1 as the VNI and uses 8472, the VXLAN Default UDP Port of the Kernel.

Since the VXLAN technique is an Encapsulation technique, the Dest IP of the Packet is set to an IP of the Host Network when the Packet leaves the Host. Therefore, even if the Hosts are on different Networks, the VXLAN technique can be applied as long as the Hosts can communicate with each other. However, its performance is lower than the `host-gw` technique because of the Encapsulation/Decapsulation Overhead.

## 2. References

* flannel - a network fabric for containers : [https://github.com/coreos/flannel](https://github.com/coreos/flannel)
* Flannel Backends : [https://github.com/coreos/flannel/blob/master/Documentation/backends.md](https://github.com/coreos/flannel/blob/master/Documentation/backends.md)
* Flannel Backends : [https://github.com/coreos/flannel/blob/master/Documentation/backends.md](https://github.com/coreos/flannel/blob/master/Documentation/backends.md)
* OpenShift Container Platform - Flannel : [https://docs.openshift.com/container-platform/3.4/architecture/additional-concepts/flannel.html](https://docs.openshift.com/container-platform/3.4/architecture/additional-concepts/flannel.html)
* Why host-gw of flannel requires direct layer2 connectivity between hosts : [https://stackoverflow.com/questions/45293321/why-host-gw-of-flannel-requires-direct-layer2-connectivity-between-hosts](https://stackoverflow.com/questions/45293321/why-host-gw-of-flannel-requires-direct-layer2-connectivity-between-hosts)
* How VXLAN works on Linux : [https://www.slideshare.net/enakai/how-vxlan-works-on-linux](https://www.slideshare.net/enakai/how-vxlan-works-on-linux)

---
title: Kubernetes Calico Plugin
---

This post analyzes Calico, a Kubernetes Network Plugin.

## 1. Calico

**Calico** is a Tool that helps build an **L3-based** Virtual Network in Container and VM environments. Since Calico supports **CNI** (Container Network Interface), it can operate as a Network Plugin in Kubernetes or Mesos.

{{< figure caption="[Figure 1] Calico Components" src="images/calico-components.png" width="700px" >}}

[Figure 1] shows the components of Calico. It largely consists of 4 components: **etcd, felix, bird, and confd**. etcd runs in the Kubernetes Cluster. felix, confd, and bird run inside the `calico-node` Pod that runs on every Kubernetes Host. Since the `calico-node` Pod uses the Network Namespace of the Host (Node), the Apps running inside the `calico-node` Pod can query or control the Host's Network configuration.

* **etcd** : etcd is a distributed Key-Value store. It stores various information such as the Network composition/configuration information required to run Calico and Calico configuration information. It also serves as a Communication Bus that delivers change information to felix or bird when a stored key-value changes.
* **felix** : felix is a Daemon that configures the Host's Network. Based on the Network configuration information stored in etcd, it configures the Host's Network Interface, Route Table, and iptables so that Packets are routed to the correct Pod, or blocks invalid Packets from being delivered. felix also collects Network state information. The Network configuration information set by felix and the collected Network state information are stored in etcd so that the configuration is delivered to felix or confd on other Hosts.
* **bird** : bird acts as a **BGP (Border Gateway Protocol)** Client. BGP is a Routing Protocol between Routers that decides which Router a Packet is routed to. Therefore, each Router must know the list of IPs it can deliver. bird delivers the IPs of all Pods running on the Host to the Route Reflector. The Router then receives the Pods' IPs from the Route Reflector and changes its Routing Table so that Packets are routed to the Pods. bird can act not only as a BGP Client but also as a BGP Route Reflector.
* **confd** : confd detects Key-Value changes in etcd, dynamically generates the bird Conf file, and wakes up bird.

### 1.1 Pod Network with IP-in-IP

{{< figure caption="[Figure 2] Calico IP-in-IP Pod Network" src="images/calico-network-ipip.png" width="800px" >}}

[Figure 2] shows the Pod Network configured by Calico using the IP-in-IP Tunneling technique. The Host Network is 10.0.0.0/24, and the Pod Network is 192.168.0.0/24. felix allocates a Pod Network to each Host based on the information stored in etcd. In the figure, the 192.168.2.0/24 Network is allocated to Host 1. Therefore, Pod A created on Host 1 uses 192.168.2.10, an IP belonging to the 192.168.2.0/24 Network. Since the 192.168.3.0/24 Network is allocated to Host 2, Pod B created on Host 2 uses 192.168.3.10, an IP belonging to the 192.168.3.0/24 Network.

After allocating a Pod Network to each Host, felix creates an IP-in-IP Tunnel Interface and adds Routing Table entries so that Packets are delivered to the Pod Networks allocated to other Hosts. In the figure, the `tunl0` Interface of each Host is configured to point to the other's Pod Network. felix also adds the IPs allocated to Pods to the Routing Table so that Packets are delivered to the Pods.

When Pod A sends a Packet whose Dest IP is 192.168.3.10, the Packet comes out through the `calixxx` Interface and is routed again according to the Routing Table rules of Host 1. Since the Packet's Dest IP belongs to the 192.168.3.0/24 Network, the Packet is delivered to the `tunl0` Interface and then to Host 2. After that, the Packet is delivered to the `caliyyy` Interface according to Host 2's Routing Table and then to Pod B.

Although this method builds a virtual Pod Network using IP-in-IP, the Host can also deliver Packets to Pods because the Pod IP information exists in the Host's Routing Table. bird also identifies Pod IPs based on the Host's Routing Table and delivers them to the Route Reflector.

## 2. References

* Calico Architecture : [https://docs.projectcalico.org/master/reference/architecture/](https://docs.projectcalico.org/master/reference/architecture/)
* Kubernetes Networking: Achieving High Performance with Calico : [https://platform9.com/blog/kubernetes-networking-achieving-high-performance-with-calico/](https://platform9.com/blog/kubernetes-networking-achieving-high-performance-with-calico/)
* Kubernetes Networking: Part 2 - Calico : [http://leebriggs.co.uk/blog/2017/02/18/kubernetes-networking-calico.html](http://leebriggs.co.uk/blog/2017/02/18/kubernetes-networking-calico.html)

---
title: Kubernetes Cilium Plugin
---

This post analyzes Cilium, a Kubernetes Network Plugin.

## 1. Cilium

{{< figure caption="[Figure 1] Cilium Components" src="images/cilium-components.png" width="800px" >}}

**Cilium** is a CNI Plugin that builds the Pod Network based on **BPF** (Berkeley Packet Filter). It is widely used as a Network Plugin for Kubernetes. [Figure 1] shows the components of Cilium operating as a Kubernetes Plugin.

* **Kubernetes API Server** : Cilium obtains information needed for Network configuration, such as Pods, Services, and Network Policies, from the Kubernetes API Server.
* **Key-value Store** : Cilium stores and uses the information that Cilium Components must share in a separate Key-value Store. The Policy Identity managed inside Cilium and the VTEP (VXLAN Tunnel End Point) information needed when using VXLAN are stored in the Key-value Store. Generally, etcd is used as the Key-value Store.
* **cilium-agent** : cilium-agent runs on every Host (Node) through a DaemonSet and performs each Host's Network configuration and Network Monitoring. It runs in the Host Network Namespace. It obtains the necessary information from the Kubernetes API Server or the Key-value Store and configures the Host's Network. As needed, it dynamically Compiles BPF Programs and inserts the results into BPF to run them.
* `cilium` : cilium serves as the CLI of cilium-agent. It communicates with cilium-agent and performs the role of controlling cilium-agent or printing the information that cilium-agent holds.
* **BPF** : BPF executes the Programs Compiled by cilium-agent to perform Packet Routing and Filtering at the Linux Kernel Level. Cilium raises Network performance by minimizing the use of the Netfilter Framework and the Routing Table through the use of BPF.
* **cilium-operator** : cilium-operator runs through a Deployment, and cilium-operator performs all operations that require an Action only once in the Cluster. For example, when a Host (Node) is removed from the Cluster, cilium-operator performs the GC role of removing the information related to the removed Host from the Key-value Store. When multiple cilium-operators run, they operate in Active-standby form to perform HA.

### 1.1. Pod Network

Cilium provides two techniques for building the Pod Network: a VXLAN-based technique and a technique that uses the Host Network as-is.

#### 1.1.1. with VXLAN

{{< figure caption="[Figure 2] Cilium VXLAN Pod Network" src="images/`cilium-net`work-vxlan.png" width="900px" >}}

[Figure 2] shows the Default Pod Network built using Cilium and VXLAN. The Host Network is 10.0.0.0/24, and the Pod Network is 10.244.0.0/16. Cilium allocates a Pod Network to each Host based on the information stored in etcd. In the figure, Host 1 is allocated the 192.167.2.0/24 Network. Therefore, Pod A created on Host 1 uses 192.167.2.10, an IP belonging to the 192.167.2.0/24 Network. Since Host 2 is allocated the 192.167.3.0/24 Network, Pod C created on Host 2 uses 192.167.3.10, an IP belonging to the 192.167.3.0/24 Network.

Three main BPFs are used when building the Pod Network: the SCHED-CLS Ingress BPF attached to the VXLAN Interface, the SCHED-CLS Ingress BPF attached to the Pod's veth Interface, and the SCHED-CLS Egress BPF attached to `cilium-host`, the veth Interface created on the Host for Cilium. The veth Interface paired with the `cilium-host` Interface is the `cilium-net` Interface. Therefore, if a Packet delivered to the `cilium-host` Interface is not Routed by the SCHED-CLS Egress BPF attached to `cilium-host`, it comes out through the `cilium-net` Interface and is delivered to a Pod using the Host Network Namespace.

When Pods using the Pod Network Namespace exchange Packets with each other, the Packets are Routed without using the Host's Routing Table and the `cilium-host`/`cilium-net` Interfaces. In [Figure 2], when Pod A sends a Packet to Pod B, the Packet is sent directly to Pod B by the SCHED-CLS Ingress BPF attached to Pod A's veth Interface. When Pod A sends a Packet to Pod F, the SCHED-CLS Ingress BPF attached to Pod A's veth Interface sends the Packet directly to the `cilium-vxlan` Interface, sending the Packet to Host 2's `cilium-vxlan` Interface. Afterward, the Packet is sent directly to Pod F by the SCHED-CLS Ingress BPF attached to the `cilium-vxlan` Interface.

When a Pod using the Pod Network Namespace and a Pod using the Host Network Namespace exchange Packets, the Host's Routing Table and the `cilium-host`/`cilium-net` Interfaces are used. In [Figure 2], when Pod A sends a Packet to Pod C, the Packet is delivered to Host 1's Routing Table and then delivered to the `cilium-host` Interface according to Host 1's Routing Table. Afterward, the Packet comes out through the `cilium-net` Interface and is delivered to Pod C. When Pod A sends a Packet to Pod F, the Packet comes out through Host 1's `cilium-vxlan` Interface to Host 2's `cilium-vxlan` Interface, and by Host 2's Routing Table it is delivered to Pod F through the `cilium-host`/`cilium-net` Interfaces.

When Pod C sends a Packet to Pod A, the Packet is delivered to the `cilium-host` Interface according to Host 1's Routing Table, at which point the Packet is delivered directly to Pod A by the SCHED-CLS Egress BPF attached to `cilium-host`. When Pod C sends a Packet to Pod D, the Packet is delivered to the `cilium-host` Interface according to Host 1's Routing Table, at which point the Packet is sent through Host 1's `cilium-vxlan` Interface to Host 2's `cilium-vxlan` Interface by the SCHED-CLS Egress BPF attached to `cilium-host`. Afterward, the Packet is sent directly to Pod D by the SCHED-CLS Ingress BPF attached to the `cilium-vxlan` Interface.

Regardless of the Network Namespace the Pod uses, when a Packet sent from a Pod goes not to a Pod but to the outside of the Cluster, the Packet is Routed by the Host's Routing Table and sent out of the Host. In [Figure 2], since the Default Gateway is `eth0`, the Packet is sent outside the Cluster through `eth0`. Depending on Cilium's configuration, a Pod Network different from [Figure 2] may be created. For example, if Cilium is configured to use IPsec, the SCHED-CLS Ingress BPF attached to the Pod's veth Interface is configured to unconditionally send Packets through the Host's Routing Table regardless of the Packet's destination.

```text {caption="[Shell 1] Cilium Endpoint", linenos=table}
# cilium map get cilium-lxc
Key               Value                                                                               State   Error
30.0.0.160:0      (localhost)                                                                         sync
192.167.1.138:0   (localhost)                                                                         sync
192.167.1.235:0   id=829   flags=0x0000 ifindex=8   mac=F2:EC:03:FC:7A:BF nodemac=FA:7D:9E:AF:1E:01   sync
192.167.1.139:0   id=53    flags=0x0000 ifindex=10  mac=DE:B8:9A:BA:37:5E nodemac=D6:EB:D8:44:E9:AD   sync    
# cilium endpoint list
ENDPOINT   POLICY (ingress)   POLICY (egress)   IDENTITY   LABELS (source:key[=value])                       IPv6   IPv4            STATUS
           ENFORCEMENT        ENFORCEMENT
691        Disabled           Disabled          32535      k8s:io.cilium.k8s.policy.cluster=default                 192.167.2.176   ready
                                                           k8s:io.cilium.k8s.policy.serviceaccount=default
                                                           k8s:io.kubernetes.pod.namespace=default
                                                           k8s:run=my-nginx
2296       Disabled           Disabled          104        k8s:io.cilium.k8s.policy.cluster=default                 192.167.2.194   ready
                                                           k8s:io.cilium.k8s.policy.serviceaccount=coredns
                                                           k8s:io.kubernetes.pod.namespace=kube-system
                                                           k8s:k8s-app=kube-dns
3424       Disabled           Disabled          104        k8s:io.cilium.k8s.policy.cluster=default                 192.167.2.32    ready
                                                           k8s:io.cilium.k8s.policy.serviceaccount=coredns
                                                           k8s:io.kubernetes.pod.namespace=kube-system
                                                           k8s:k8s-app=kube-dns
3787       Disabled           Disabled          4          reserved:health                                          192.167.2.88    ready 
```

Cilium stores and manages the IPs and MACs of all Pods managed by Cilium under the name **Endpoint** in the etcd that Cilium uses. cilium-agent delivers the Endpoint information to BPF through BPF Maps so that BPF can perform Routing. [Shell 1] shows a Shell querying the IPs of all Pods on a specific Host using the `cilium map get cilium-lxc` or `cilium endpoint list` commands.

#### 1.1.2. with Host L3

{{< figure caption="[Figure 3] Cilium Host L3 Pod Network" src="images/`cilium-net`work-host.png" width="900px" >}}

[Figure 3] shows the Pod Network built using Cilium and the Host L3 Network. The Pod Network allocated to each Host, the Host IPs, and the Pod IPs are the same as the example in [Figure 2]. The difference from using VXLAN is that the VXLAN Interface and the SCHED-CLS Ingress BPF attached to the VXLAN Interface do not exist. The Routing Table is also different from when using VXLAN. It can be seen that the Host's Routing Table only has Rules related to the Pod Network allocated to each Host.

In [Figure 3], it can be seen that Host 1's Routing Table only has Rules related to 192.167.2.0/24, the Pod Network allocated to Host 1, and has no Rules related to 192.167.3.0/24, the Pod Network allocated to Host 2. Therefore, Packets sent between Pods located on different Hosts are sent according to the Host Network's configuration. In [Figure 3], since the Host Network is composed through the `eth0` Interface and the `eth0` Interface is set as the Default GW, both Host 1 and 2 exchange Pod Packets through the `eth0` Interface.

Another difference from using VXLAN is that regardless of the Network Namespace the Pod uses, Packets sent from a Pod are sent through the Host's Routing Table. Other than that, it is not much different from using VXLAN. Depending on Cilium's configuration, a Pod Network different from [Figure 3] may be created.

### 1.2. Connection Tracking

```text {caption="[Shell 2] Cilium Connection Info", linenos=table}
# cilium bpf ct list global
TCP IN 192.167.0.113:58044 -> 192.167.0.175:8080 expires=247809 RxPackets=6 RxBytes=525 RxFlagsSeen=0x1b LastRxReport=247799 TxPackets=4 TxBytes=409 TxFlagsSeen=0x1b LastTxReport=247799 Flags=0x0013 [ RxClosing TxClosing SeenNonSyn ] RevNAT=0 SourceSecurityID=1
TCP OUT 30.0.0.34:59050 -> 192.168.0.40:8774 expires=246703 RxPackets=4 RxBytes=2436 RxFlagsSeen=0x13 LastRxReport=246693 TxPackets=5 TxBytes=761 TxFlagsSeen=0x1b LastTxReport=246693 Flags=0x0013 [ RxClosing TxClosing SeenNonSyn ] RevNAT=0 SourceSecurityID=0
ICMP OUT 30.0.0.34:49527 -> 30.0.0.79:0 expires=258603 RxPackets=1 RxBytes=50 RxFlagsSeen=0x00 LastRxReport=258543 TxPackets=1 TxBytes=50 TxFlagsSeen=0x00 LastTxReport=258543 Flags=0x0000 [ ] RevNAT=0 SourceSecurityID=0
ICMP IN 192.167.1.109:25170 -> 192.167.0.76:0 expires=256931 RxPackets=1 RxBytes=50 RxFlagsSeen=0x00 LastRxReport=256871 TxPackets=1 TxBytes=50 TxFlagsSeen=0x00 LastTxReport=256871 Flags=0x0000 [ ] RevNAT=0 SourceSecurityID=1
ICMP IN 30.0.0.160:0 -> 30.0.0.34:58168 expires=250323 RxPackets=1 RxBytes=50 RxFlagsSeen=0x00 LastRxReport=250263 TxPackets=0 TxBytes=0 TxFlagsSeen=0x00 LastTxReport=0 Flags=0x0000 [ ] RevNAT=0 SourceSecurityID=0
```

Cilium manages Pod Connection information directly using BPF and BPF MAP instead of using Linux conntrack. [Shell 2] shows a Shell printing the Connection information stored in the BPF Map using the `cilium bpf ct list global` command.

### 1.3. Service Load Balancing

```text {caption="[Shell 3] Cilium Service", linenos=table}
# cilium service list
ID   Frontend           Backend
1    10.96.0.10:53      1 => 192.167.2.194:53
                        2 => 192.167.2.32:53
2    10.96.0.10:9153    1 => 192.167.2.194:9153
                        2 => 192.167.2.32:9153
3    10.96.0.1:443      1 => 30.0.0.34:6443
4    10.97.188.211:80   1 => 192.167.1.139:80
                        2 => 192.167.2.176:80
5    10.109.68.251:80   1 => 30.0.0.160:80
                        2 => 30.0.0.79:80  
6    30.0.0.160:30381   1 => 192.167.2.32:80
                        2 => 192.167.2.194:80
7    192.168.0.101:80   1 => 192.167.2.32:80
                        2 => 192.167.2.194:80
```

One of the additional features Cilium provides is Service Load Balancing support. Cilium obtains Service information from the Kubernetes API Server and stores it in the etcd that Cilium uses. [Shell 3] shows a Shell printing the Service information stored in Cilium's etcd using the `cilium service list` command. `Frontend` means the Cluster IP of the Kubernetes Service, and `Backend` means the IPs of the Pods belonging to that Service. Based on the Service information in the BPF Map, when the Dest IP of a received Packet is a Service's Cluster IP, Cilium's BPF performs Load Balancing by applying **DNAT** to change the Packet's Dest IP to the IP of a Pod connected to the Service.

The Load Balancing Algorithm mixes a **Random method** and an **Affinity method** based on the Connection information Cilium stores. When a Pod sends to a Service, Cilium checks whether the BPF Map has Connection information between the source Pod and some Pod belonging to the destination Service. If there is no related Connection information, Cilium selects an arbitrary Pod belonging to the destination Service, sends the Packet, and adds the related Connection information to the BPF MAP. If related Connection information exists, the Packet is sent again to the Pod to which the Packet was previously sent, according to the Connection information.

For Versions before Cilium 17.XX, Cilium supported Load Balancing only for `ClusterIP` Type Services, but Versions after Cilium 17.XX also support Load Balancing for `NodePort` and `LoadBalancer` Type Services.

#### 1.3.1. with VXLAN

{{< figure caption="[Figure 3] Cilium Service Load Balancing with VXLAN" src="images/cilium-service-vxlan.png" width="900px" >}}

[Figure 3] shows the Service Load Balancing process when using VXLAN. When a Pod using the Pod Network Namespace sends a Packet to a Service's Cluster IP, the sent Packet is DNATed by the SCHED-CLS Ingress BPF attached to the Pod's veth Interface. SNAT is performed by the SCHED-CLS Ingress BPF of the veth Interface or the SCHED-CLS Ingress BPF of `cilium-vxlan`, depending on the location of the Pod that sent the response Packet.

When a Pod using the Host Network Namespace sends a Packet to a Service's Cluster IP, DNAT is basically performed using the iptables or IPVS configured by kube-proxy. However, for Versions after cilium 16.xx, a feature was added that can perform DNAT using the CGROUP-SOCK-ADDR BPF. Of course, it can only be used on Kernel Versions that support the CGROUP-SOCK-ADDR BPF. SNAT is performed by the SCHED-CLS Ingress BPF of the veth Interface or the SCHED-CLS Egress BPF of `cilium-host`, depending on the location of the Pod that sent the response Packet.

#### 1.3.2. with Host L3

{{< figure caption="[Figure 4] Cilium Service Load Balancing with Host L3" src="images/cilium-service-host.png" width="900px" >}}

[Figure 4] shows the Service Load Balancing process when using the Host L3 Network. When a Pod using the Pod Network Namespace sends a Packet to a Service's Cluster IP, if the Pod connected to the Service is outside, it is not much different from using VXLAN except that SNAT is performed by the SCHED-CLS Egress BPF of `cilium-host`.

### 1.4. Filtering

One of the additional features Cilium provides is Packet Filtering. There are two Filtering techniques in Cilium: the Network Policy technique defined through the CiliumNetworkPolicy CRD provided by Cilium, and the Prefilter technique using XDP.

#### 1.4.1. Network Policy

```text {caption="[Shell 4] Cilium Network Policy", linenos=table}
# cilium policy get
[
  {
    "endpointSelector": {
      "matchLabels": {
        "any:org": "ssup2",
        "k8s:io.kubernetes.pod.namespace": "default"
      }
    },
    "ingress": [
      {
        "fromEndpoints": [
          {
            "matchLabels": {
              "any:org": "ssup2",
              "k8s:io.kubernetes.pod.namespace": "default"
            }
          }
        ],
        "toPorts": [
          {
            "ports": [
              {
                "port": "80",
                "protocol": "TCP"
...  
]
```

Once Cilium is installed, Network Policies can be defined using the **CiliumNetworkPolicy** CRD. Through Network Policies, L3, L4, and L7 Level Packet Filtering Rules can be defined. [Shell 4] shows a Shell checking the defined Network Policies through the `cilium policy get` command. The defined Network Policies are applied when Packets are sent by all the BPFs shown in [Figure 1] or [Figure 2].

#### 1.4.2. Prefilter

{{< figure caption="[Figure 5] Cilium Prefilter" src="images/cilium-prefilter.png" width="900px" >}}

Cilium also provides a Packet Filtering feature using XDP (eXpress Data Path). In Cilium it is called Prefilter. It operates by inserting an XDP BPF into the Interface of the NIC that composes the Kubernetes Cluster Network. Both Generic XDP and Native XDP methods are provided. Through the prefilter, it can be configured to receive only Packets of a specific Network set by CIDR. The prefilter configuration can be done through the cilium-agent's Config.

## 2. References

* cilium: initial prefilter work for ddos mitigation : [https://github.com/cilium/cilium/commit/5e3e420f7927647b780c01d986ecaeff1bf32846#diff-9c45a228401ffc83c5c6ad50c7cc825b](https://github.com/cilium/cilium/commit/5e3e420f7927647b780c01d986ecaeff1bf32846#diff-9c45a228401ffc83c5c6ad50c7cc825b)
* cilium: make services available for host applications : [https://github.com/cilium/cilium/commit/b52130c55ee68a3de08125d29a91953de092338f#diff-01a7217c02bf211c22c4c232517f2dfb](https://github.com/cilium/cilium/commit/b52130c55ee68a3de08125d29a91953de092338f#diff-01a7217c02bf211c22c4c232517f2dfb)
* Understanding and Troubleshooting the eBPF Datapath in Cilium (KubeCon NA 2019) : [https://kccncna19.sched.com/event/Uae7](https://kccncna19.sched.com/event/Uae7)
* Host-Reachable Services (beta) - Cilium Documentation : [https://docs.cilium.io/en/v1.6/gettingstarted/host-services/](https://docs.cilium.io/en/v1.6/gettingstarted/host-services/)

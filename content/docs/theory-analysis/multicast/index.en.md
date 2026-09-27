---
title: Multicast
---

This post analyzes Network Multicast.

## 1. Multicast

Network Packet transmission methods largely take three forms: Unicast, Broadcast, and Multicast. Unicast is a method of delivering a Packet to a single Node. It is the method most commonly used in general communication. Broadcast is a method of delivering a Packet to all Nodes in the same network. ARP (Address Resolution Protocol) is a representative example. Finally, there is **Multicast**, which delivers Packets only to Nodes belonging to a specific Group rather than to all Nodes. It is used in Multimedia Streaming, where large Packets must be transmitted only to specific Nodes.

### 1.1. Multicast Address

{{< figure caption="[Figure 1] Multicast Address" src="images/multicast-address.png" width="600px" >}}

Multicast generally uses IP for L3 and UDP for L4. [Figure 1] shows the IP Address and Ethernet Address of a Multicast Packet. Multicast uses **Class D** as its IP Address. Class D refers to addresses whose first 4 bits start with **1110**. A Multicast IP represents one **Multicast Group**. If the Dest IP of a Packet is the Multicast IP `224.0.0.1`, only the Nodes belonging to the `224.0.0.1` Group receive that Packet.

The Ethernet Address is generated based on the IP Address. The Ethernet Address starts with **0000 0001 0000 0000 0101 1110 0**, and the remaining 23 bits are filled with the last 23 bits of the IP Address. Since 5 bits are not used to create the Ethernet Address, as shown in the red part of [Figure 1], one Ethernet Address can represent multiple IP Addresses.

## 2. IGMP (Internet Group Management Protocol)

IGMP is a Protocol for exchanging Multicast Group information between a Router and a Subnet. Through the IGMP Protocol, the Router determines which Subnet Multicast Packets should be sent to.

### 2.1. IGMP Report

{{< figure caption="[Figure 2] IGMP Report" src="images/igmp-report.png" width="900px" >}}

[Figure 2] shows the Report process of the IGMP Protocol. If a specific Node belonging to a Subnet wants to join the `224.0.0.1` Multicast Group, the Node sends an IGMP Report Packet to the Router. When the Router receives a Multicast Packet whose Dest IP is `224.0.0.1`, it transmits the Multicast Packet to the Subnet where the Node that sent the IGMP Report Packet is located.

### 2.2. IGMP Query, Leave

{{< figure caption="[Figure 3] IGMP Query, Leave" src="images/igmp-query-leave.png" width="900px" >}}

[Figure 3] shows the IGMP Query Packet and the IGMP Leave process. The Router periodically sends IGMP Query Packets to the Nodes belonging to each Multicast Group. A Node that receives an IGMP Query Packet sends an IGMP Report Packet to the Router if it wants to continue receiving Multicast Packets. Conversely, if it no longer wants to receive Packets of that Multicast Group, it sends an IGMP Leave Packet to the Router.

### 2.3. IGMP Snooping

{{< figure caption="[Figure 4] IGMP Snooping" src="images/igmp-snooping.png" width="900px" >}}

For Multicast to operate efficiently, not only the Router's Multicast Routing but also the Multicast Routing of the Switches composing the Subnet is important. IGMP Snooping is a technique that operates on Switches for Multicast Routing. [Figure 4] shows IGMP Snooping.

A Switch can tell whether a Packet is a Multicast Packet by looking at the Packet's Ethernet Address. When a Switch receives a Packet with a Multicast Ethernet Address, it records which Port of the Switch the Packet came from. Based on the record, it routes Multicast Packets to the appropriate Ports. If the Switch does not support the IGMP Snooping feature, the Switch must broadcast Multicast Packets and deliver them to all Ports.

## 3. References

* Ryu Book - IGMP Snooping : [https://osrg.github.io/ryu-book/ko/html/igmp_snooping.html](https://osrg.github.io/ryu-book/ko/html/igmp_snooping.html)
* IP Multicast Technology Overview : [http://www.cisco.com/c/en/us/td/docs/ios/solutions-docs/ip-multicast/White-papers/mcst-ovr.html](http://www.cisco.com/c/en/us/td/docs/ios/solutions-docs/ip-multicast/White-papers/mcst-ovr.html)

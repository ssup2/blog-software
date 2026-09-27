---
title: Overlay Network, VXLAN
---

This post analyzes the Overlay Network used for Network virtualization in Cloud environments, and the VXLAN technology that makes the implementation of Overlay Networks possible.

## 1. Overlay Network

{{< figure caption="[Figure 1] Overlay Network" src="images/overlay.png" width="500px" >}}

**Overlay Network** refers to a technique for building virtual Networks on top of an actual physical Network. Each virtual Network is managed in complete isolation from the others. [Figure 1] shows virtual Networks built on top of a physical Network. In general, Cloud environments use Overlay Networks to build the Network of each Tenant.

## 2. VXLAN (Virtual Extensible LAN)

{{< figure caption="[Figure 2] VXLAN Overview" src="images/vxlan-overview.png" width="650px" >}}

VXLAN (Virtual Extensible LAN) is one of the Network Protocols for building Overlay Networks. [Figure 2] briefly shows an overview of VXLAN. VXLAN is a technique based on **Tunneling**. A Packet generated inside a virtual Network is Encapsulated, passes through the physical Network, and is then Decapsulated and delivered back to the virtual Network. The point where this Packet Encapsulation/Decapsulation occurs is called a **VTEP** (VXLAN Tunnel End Point) in VXLAN. A VTEP can be a virtual Software device, or a physical device that supports VXLAN. In [Figure 2], the VM (Virtual Machine) uses a Software VTEP provided by the Hypervisor, and the PM (Physical Machine) uses a physical VTEP.

An Encapsulated Packet is distinguished and isolated by which virtual Network it belongs to through the **VNI** (VXLAN ID) in the VXLAN Header. Therefore, one VNI corresponds to one virtual Network. The VNI can be said to play the same role as the VLAN ID in VLAN. [Figure 2] shows two virtual Networks using VNI 1000 and VNI 2000.

### 2.1. VXLAN Packet

{{< figure caption="[Figure 3] VXLAN Packet" src="images/vxlan-packet.png" width="900px" >}}

[Figure 3] shows the Packet structure of VXLAN. VXLAN performs Tunneling using IP/UDP. On the outside of the Packet are the Outer Ethernet Header, Outer IP Header, and Outer UDP Header for Packet delivery on the physical Network used by the Host. On the inside are the VXLAN Header and the L2 Packet of the VM generated inside the virtual Network. The VNI is stored in the VXLAN Header. The VNI consists of 24 bits, so about 16,000,000 VNIs can be used.

### 2.2. VXLAN Broadcast, VTEP MAC Address Learning

VXLAN handles Broadcast Packets generated inside a virtual Network as **IP Multicast** on the physical Network, using the Network efficiently. The reason for Tunneling with IP/UDP is also to use IP Multicast on the physical Network. The fact that a Broadcast Packet generated inside a virtual Network is handled as IP Multicast on the physical Network means that a specific VNI is Mapped to a Multicast Group. This Mapping information is configured on the VTEP. Since there are about 16,000,000 VNIs but only about 1000 Multicast Groups, VNIs and Multicast Groups actually have an N:1 relationship.

Since the VTEP is the point where virtual Network Packets are Encapsulated, it must also know the information needed for Encapsulation. Therefore, the VTEP must decide which VNI to use when Encapsulating a virtual Network Packet that arrives at it. In general, the Mapping information between the VLAN ID of the virtual Network Packet and the VNI is configured on the VTEP. Alternatively, the VTEP can be configured to Map the Dst Subnet IP of the virtual Network Packet to a VNI.

{{< figure caption="[Figure 4] VXLAN Address Learning Process" src="images/vxlan-address-learning.png" width="900px" >}}

[Figure 4] shows the MAC Address Learning process of VTEPs following an ARP Packet generated inside a virtual Network. Through the ARP Packet handling process, the VXLAN Broadcast handling process can be understood. All VTEPs in [Figure 4] are configured to Map VNI 10 to the `239.1.1.1` Multicast Group, and also configured to Map VNI 10 to VLAN 1.

1. Machine A sends an ARP Request Packet together with VLAN ID 1 to learn the MAC Address of IP B.

1. VTEP 1 checks that the VLAN ID of the virtual Network Packet is 1. Since VLAN 1 is Mapped to VNI 10 on the VTEP, and VNI 10 is Mapped to Multicast `239.1.1.1`, the virtual Network Packet is Encapsulated with VNI 10 and then sent to the `239.1.1.1` Multicast Group.

1. The Encapsulated Packet is delivered to VTEP 2 and VTEP 3, which have joined the `239.1.1.1` Multicast Group. VTEP 2 and VTEP 3 create a **Src MAC/VNI/Outer Src IP** Mapping Table based on the information of the Encapsulated Packet.

1. VTEP 2 and VTEP 3 Decapsulate the Encapsulated Packet and convert it back to the original ARP Packet. Then they deliver it to Machine B and Machine C, respectively.

1. Since IP B is the IP of Machine B, only Machine B Unicasts an ARP Response to Machine A.

1. Based on the Src MAC/VNI/Outer Src IP Mapping Table stored in VTEP 2, the ARP Response Packet is Unicast to VTEP 1.

1. VTEP 1, which received the Encapsulated ARP Response Packet, creates a Src MAC/VNI/Outer Src IP Table.

1. VTEP 1 delivers the ARP Response Packet to Machine A through Decapsulation.

Through the ARP Packet handling process, it can be seen how efficiently VXLAN handles Broadcast and Unicast.

### 2.3. VXLAN Unicast

{{< figure caption="[Figure 5] VXLAN Unicast Process" src="images/vxlan-unicast.png" width="900px" >}}

[Figure 5] shows the VXLAN Unicast process. It is similar to the process in which the ARP Response Packet is handled. Unicast is handled efficiently based on the Src MAC/VNI/Outer Src IP Table held by each VTEP.

## 3. vs VLAN

Virtual Networks can also be built with VLAN. However, VLAN has several limitations for use in Cloud environments. First, since the VLAN ID of VLAN consists of 12 bits, only about 4000 VLAN IDs can be used. This means that building virtual Networks using only VLAN can accommodate at most 4000 Tenants.

VLAN is an L2 Layer technology. Even when building virtual Networks using VLAN, physical switches must Learn not only the MAC Addresses of Hosts but also the MAC Addresses of VMs, and maintain the MAC Address Table. The problem is that in Cloud environments where multiple VMs run on a single Host, the number of VMs is far greater than the number of Hosts. Therefore, the fact that physical switches must also manage the MAC Addresses of VMs can be a heavy burden.

Since about 16,000,000 VNIs can be used in VXLAN, a large number of Tenants can be accommodated. In addition, since VXLAN is a technique based on Tunneling, intermediate physical switches do not need to manage the MAC Addresses of VMs inside the virtual Network. The MAC Addresses of VMs are managed only by VTEPs. In Cloud environments, a virtual VTEP provided by the Hypervisor can be used as the VTEP, so VXLAN can be easily applied even in existing Legacy environments.

## 4. References

* Network Overlay - VXLAN를 말한다 #1 : [http://youngmind.tistory.com/entry/Network-Overlay-VXLAN-%EB%B6%84%EC%84%9D-1](http://youngmind.tistory.com/entry/Network-Overlay-VXLAN-%EB%B6%84%EC%84%9D-1)
* VXLAN Deep Dive Session (SlideShare) : [https://www.slideshare.net/KwonSunBae/vxlan-deep-dive-session-rev05-final](https://www.slideshare.net/KwonSunBae/vxlan-deep-dive-session-rev05-final)
* How VXLAN Works on Linux (SlideShare) : [https://www.slideshare.net/enakai/how-vxlan-works-on-linux](https://www.slideshare.net/enakai/how-vxlan-works-on-linux)

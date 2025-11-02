---
title: ARP
---

## 1. ARP (Address Resolution Protocol)

ARP is literally a protocol for discovering addresses. In most cases when network programming, only the IP address of the destination to which data is to be sent is used, and MAC addresses are not used. IP is a logical address for flexibly managing network address systems, and MAC address is a physical address recognized by actual NIC cards. Therefore, network communication is not possible with only an IP address. **ARP is a protocol for discovering physical addresses like MAC using logical addresses like IP.**

### 1.1. Flow

{{< figure caption="[Figure 1] ARP Flow" src="images/arp-flow.png" width="900px" >}}

[Figure 1] shows the flow of ARP packets. When sending an **ARP Request**, it fills Source Hardware Address and Source Protocol Address with its own physical address and logical address respectively. And it fills Target Protocol Address with the logical address of the Target whose physical address needs to be discovered. Then it broadcasts the ARP packet.

When a Host receives an ARP packet, if its logical address is identical to the Target Protocol Address, it sends an **ARP Reply**. It fills Source Hardware Address and Source Protocol Address with its own physical address and logical address respectively. And it fills Target Hardware Address and Target Protocol Address with the Source Hardware Address and Source Protocol Address from the ARP Request packet respectively, and unicasts it.

### 1.2. ARP Packet

{{< figure caption="[Figure 2] ARP Packet" src="images/arp-packet.png" width="900px" >}}

[Figure 2] shows an ARP packet in an Ethernet environment. Operation Code becomes 1 when it is an ARP Request and becomes 2 when it is an ARP Reply. Since ARP Request packets must be broadcast, the **Destination Address in the Ethernet Header becomes FF:FF:FF:FF:FF:FF**.

### 1.3. ARP Caching, Table

```shell {caption="[Shell 1] Check ARP Table"}
$ arp
Address                  HWtype  HWaddress           Flags Mask            Iface
192.168.0.1              ether   90:9f:33:b2:ef:08   C                     eth0
192.168.0.4              ether   1c:23:2c:8c:6c:99   C                     eth0
```

If addresses are discovered using ARP every time data is transmitted, numerous ARP packets will occur on the network and significant transmission overhead will also occur. Therefore, each Host caches and manages MAC addresses discovered through ARP. In Linux, you can view the ARP table managed by Linux through the arp command. [Shell 1] shows the process of checking the ARP table using the arp command. In the ARP table of [Shell 1], you can see that 192.168.0.1 is mapped to 90:9f:33:b2:ef:08, and 192.168.0.4 is mapped to 1c:23:2c:8c:6c:99.

## 2. References

* [https://www.slideshare.net/naveenarvinth/arp-36193303](https://www.slideshare.net/naveenarvinth/arp-36193303)


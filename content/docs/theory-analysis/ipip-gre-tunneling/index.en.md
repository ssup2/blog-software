---
title: IP-in-IP, GRE Tunneling
---

This post analyzes the IP-in-IP and GRE techniques, which are Network Tunneling techniques.

## 1. IP-in-IP

{{< figure caption="[Figure 1] IP-in-IP Header" src="images/ipip-header.png" width="450px" >}}

**IP-in-IP** is an IP-based Tunneling technique. [Figure 1] shows the Header of IP-in-IP. It works by attaching an **Outer IP Header** on top of the original IP Header to pass through the network.

{{< figure caption="[Figure 2] IP-in-IP Process" src="images/ipip-process.png" width="800px" >}}

[Figure 2] shows the process of IP-in-IP handling. A Packet sent from a PC is delivered to the source Tunnel according to the Routing rules. The Tunnel finds out the IP of the destination Tunnel by referring to the Packet's Dst IP and the Mapping Table configured in the Tunnel. Then it encapsulates the Packet by attaching an Outer IP Header on top of the original IP Header, where the Dst IP is the IP of the destination Tunnel and the Src IP is the IP of the source Tunnel. When the destination Tunnel receives the encapsulated Packet, it removes the Outer IP Header and delivers the Packet to the destination.

## 2. GRE (Generic Routing Encapsulation)

{{< figure caption="[Figure 3] GRE Header" src="images/gre-header.png" width="600px" >}}

GRE (Generic Routing Encapsulation) is a Tunneling Protocol similar to IP-in-IP. Like IP-in-IP, it performs Tunneling by attaching an Outer IP Header to the original Packet. The difference from IP-in-IP is that a **GRE Header** is added between the original IP Header and the Outer IP Header. [Figure 3] shows the GRE Header.

* **C** : The Checksum Bit. When set to 1, the Checksum is used.
* **K** : The Key Bit. When set to 1, the Key is used.
* **S** : The Sequence Number Bit. When set to 1, the Sequence Number is used.
* **Checksum** : Indicates the Checksum.
* **Version** : Indicates the GRE Version.
* **Protocol Type** : Indicates the Ether Type of the encapsulated Packet.
* **Key** : Stores custom information as needed.
* **Sequence Number** : Indicates the Sequence number.

Based on the GRE Header, it supports more features than IP-in-IP. Even if the original Packet uses UDP, the integrity of the Packet can be checked using the Sequence Number and Checksum. In addition, the security of the Packet can be improved using the Key value. It also supports Multicast, which IP-in-IP does not support.

## 3. References

* IPIP : [http://cizz.net/lartc/lartc.tunnel.ip-ip.html](http://cizz.net/lartc/lartc.tunnel.ip-ip.html)
* GRE : [http://cizz.net/lartc/lartc.tunnel.gre.html](http://cizz.net/lartc/lartc.tunnel.gre.html)
* GRE : [https://en.wikipedia.org/wiki/Generic_Routing_Encapsulation](https://en.wikipedia.org/wiki/Generic_Routing_Encapsulation)

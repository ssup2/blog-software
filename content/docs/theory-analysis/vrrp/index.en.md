---
title: VRRP
---

## 1. VRRP (Virtual Router Redundancy Protocol)

{{< figure caption="[Figure 1] VRRP Application" src="images/problem.png" width="700px" >}}

VRRP (Virtual Router Redundancy Protocol) is a technique to prevent Single Point of Failure of Gateway Router. The left figure in [Figure 1] shows when there is one Gateway Router. If Router stops operating, Host A and Host B are disconnected from External Network. An intuitive solution that comes to mind is to add a spare Router. However, simply adding a Router cannot solve the Single Point of Failure problem.

The right figure in [Figure 1] shows when Router B with IP 10.0.0.2 is simply added. Even though Router is added, since Default Gateway of Host A and Host B is set to 10.0.0.1, Packets from Host A and Host B going to External Network are not delivered to Router B. To solve this problem, VRRP must be introduced.

{{< figure caption="[Figure 2] VRRP Operation Process" src="images/vrrp.png" width="700px" >}}

[Figure 2] shows VRRP's operation when there are 2 Routers. Through VRRP, multiple Routers can be made to appear as one **Virtual Router** to Hosts. Network administrators set **VRID** and **Priority** for each Router. In [Figure 2], VRID is set to 1 for both Routers so that 2 Routers operate as one Virtual Router. Priority must be set to different values for each Router. Router with higher Priority becomes Master Router and Router with lower Priority becomes Backup Router.

Also, Network administrators set **Virtual IP** that Virtual Router will use when configuring VRRP. In [Figure 2], it is set to 10.0.0.1. Virtual Router's Virtual MAC uses 0000.5e00.0101 according to the rule of **0000.5e00.01{VRID}**. When ARP Request comes from Host, Master Router delivers ARP Response to Host so that Switch constituting Internal Network delivers Packets with Virtual MAC as Dest MAC to Master Router. Also, Master Router periodically sends **VRRP Advertisement Packet** to Backup Router to inform Backup Router that Master Router is operating normally. VRRP Advertisement Packet transmission period can be configured in Router.

If Master Router stops operating due to failure, VRRP Advertisement Packet is not delivered to Backup Router, so Backup Router identifies Master Router's failure and becomes Master Router itself. After Backup Router becomes Master Router, it sends **GARP (Gratuitous ARP)** to Internal Network so that Switch constituting Internal Network delivers Packets with Virtual MAC as Dest MAC to the new Master Router.

## 2. References

* [https://www.slideshare.net/netmanias-ko/netmanias20080324-vrrp-protocoloverview](https://www.slideshare.net/netmanias-ko/netmanias20080324-vrrp-protocoloverview)
* [http://www.rfwireless-world.com/Terminology/Virtual-MAC-Address-vs-Physical-MAC-Address.html](http://www.rfwireless-world.com/Terminology/Virtual-MAC-Address-vs-Physical-MAC-Address.html)


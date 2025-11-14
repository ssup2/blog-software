---
title: BGP
---

Analyzes BGP (Border Gateway Protocol).

### 1. BGP (Border Gateway Protocol)

{{< figure caption="[Figure 1] BGP" src="images/bgp.png" width="1000px" >}}

BGP is a Protocol used for managing the Routing Table of External Routers (Gateways) of AS (Autonomous System). [Figure 1] shows BGP. AS refers to a Network managed by a Network administrator of a specific Group. ISPs (Internet Service Providers) that provide Internet correspond to AS. DMZ literally means a neutral Network and refers to a Network that connects multiple ASs.

BGP can be classified into two types: eBGP (external BGP) and iBGP (internal BGP). eBGP is a Protocol for exchanging Routing information between External Routers belonging to different ASs. iBGP is a Protocol for exchanging Routing information between External Routers belonging to the same AS. BGP is a Path Vector type Protocol. Each External Router has Path information to reach other ASs. For example, in [Figure 1], Router A2 belonging to AS 100 has Path information 'AS100 - AS200 - AS300' to reach AS 300.

Packets with a destination of an external AS delivered to Internal Router are delivered to External Router by IGP (Interior Gateway Protocol), and then delivered to the external AS by BGP again.

### 2. References

* [https://www.slideshare.net/apnic/bgp-techniques-for-network-operators](https://www.slideshare.net/apnic/bgp-techniques-for-network-operators)
* [https://www.nanog.org/meetings/nanog53/presentations/Sunday/bgp-101-NANOG53.pdf](https://www.nanog.org/meetings/nanog53/presentations/Sunday/bgp-101-NANOG53.pdf)
* [http://luk.kis.p.lodz.pl/ZTIP/BGP.pdf](http://luk.kis.p.lodz.pl/ZTIP/BGP.pdf)
* [https://www.netmanias.com/ko/?m=view&id=techdocs&no=5128](https://www.netmanias.com/ko/?m=view&id=techdocs&no=5128)


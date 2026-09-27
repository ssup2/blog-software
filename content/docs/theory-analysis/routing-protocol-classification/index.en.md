---
title: Routing Protocol Classification
---

This article classifies Routing Protocols into Link State, Distance Vector, and Path Vector, and analyzes them.

## 1. Link State

{{< figure caption="[Figure 1] Link State" src="images/link-state.png" width="400px" >}}

[Figure 1] shows the Link State Protocol. In the Link State Protocol, **every Router has complete Network Topology information.** Based on the Network Topology information, each Router finds the shortest path to every other Router using the **Dijkstra Algorithm** and configures its Routing Table.

To build the Network Topology, each Router identifies its adjacent Routers and calculates a Cost for each Router considering the Router's Latency and the Bandwidth of the Links connected to the Router. The Router then transmits the list of Routers it has identified and the Cost information of each Router to all Routers connected to it, sharing the information. Each Router figures out the Network Topology based on the shared information. If a failure occurs in a Link or Router and Packet transmission becomes impossible, the Router that discovers the failure removes the failed Link or Router from the Network Topology and delivers the changed Network Topology information to the other Routers. Each Router modifies its Routing Table according to the changed Network Topology.

In the Link State Protocol, each Router can prevent Packet Looping based on the complete Network Topology information, and sophisticated Routing such as Packet Load Balancing becomes possible. However, the large amount of information exchange between Routers required for each Router to know the complete Network Topology is the biggest drawback of the Link State Protocol. OSPF and IS-IS are Link State based Protocols.

## 2. Distance Vector

{{< figure caption="[Figure 2] Distance Vector" src="images/distance-vector.png" width="700px" >}}

[Figure 2] shows the Distance Vector Protocol. In the Distance Vector Protocol, **each Router only has a Table of the distances to adjacent Routers and the transit Router information for sending a Packet to a destination Router.** It does not have the complete Network Topology information. In [Figure 2], Router A must send a Packet through Router C and Router D to reach Router E. Therefore, Router A's Routing Table records that a Packet destined for Router E must be sent to Router C. The distance increases by 1 every time a Packet passes through one Router. When a Packet is delivered from Router A to Router E, the distance becomes 3 because it passes through two Routers, Router C and Router D.

Since each Router does not know the complete Network Topology information, it cannot use the Dijkstra Algorithm, which computes the shortest paths between Routers sequentially according to the Network Topology. Instead, it uses the **Bellman-Ford Algorithm**, which computes the shortest paths between Routers using only the distance information of each Router and its adjacent Routers. Each Router records its adjacent Routers and distance information and exchanges them with other Routers to complete the Routing Table. Since each Router only needs to know the list of adjacent Routers and the distances, the amount of information exchanged between Routers is small.

However, because each Router does not know the complete Network Topology and the algorithm **relies on the information of adjacent Routers**, Packet Looping can occur frequently, and even when it occurs, it is not easy to detect. The Count to Infinity phenomenon, which occurs frequently in Distance Vector, is also Packet Looping. RIP and EIGRP are Distance Vector based Protocols.

### 2.1. Count to Infinity

{{< figure caption="[Figure 3] Count to Infinity Phenomenon" src="images/count-to-infinity.png" width="700px" >}}

Count to Infinity is a Packet Looping phenomenon that can occur frequently in the Distance Vector Protocol. [Figure 3] shows the Count to Infinity phenomenon. Router A, which discovers the failure of Router C, modifies its Routing Table to prevent Packets from being delivered to Router C. It then delivers the modified Routing Table information to Router B. Based on the Routing Table information received from Router A, Router B increases the distance to Router C by 1. Since Router B's Routing Table has changed, Router B delivers the changed Routing Table information back to Router A. Router A increases the distance to Router C by 1 based on Router B's Routing Table information. The distance value of Router C in the Routing Tables of Router A and Router B keeps increasing. The easiest way to solve the Count to Infinity problem is to set a limit so that the distance value cannot rise above a certain value.

## 3. Path Vector

{{< figure caption="[Figure 4] Path Vector" src="images/path-vector.png" width="700px" >}}

[Figure 4] shows the Path Vector Protocol. In the Path Vector Protocol, each Router stores Path information by recording all the Routers a Packet passes through when sending the Packet to a specific Router. Each Router records the Path information of itself and its adjacent Routers and exchanges it with other Routers to complete the Routing Table. Since Path information is exchanged, a larger amount of information must be exchanged between Routers than in Distance Vector, but Packet Looping can be easily prevented and detected based on the Path information. BGP is a Path Vector based Protocol.

## 4. References

* IT6601 Mobile Computing (SlideShare) : [https://www.slideshare.net/ayyakathir/it6601-mobile-computing-55359646](https://www.slideshare.net/ayyakathir/it6601-mobile-computing-55359646)
* Network Layer: Delivery, Forwarding, and Routing (SlideShare) : [https://www.slideshare.net/WayneJonesJnr/ch22-3361678](https://www.slideshare.net/WayneJonesJnr/ch22-3361678)
* Internet Routing Protocols: Distance-Vector and Link-State Routing (SlideShare) : [https://www.slideshare.net/vsharma87/internet-routing-protocols-fundamental-concepts-of-distancevector-and-linkstate-routing](https://www.slideshare.net/vsharma87/internet-routing-protocols-fundamental-concepts-of-distancevector-and-linkstate-routing)
* Why is Dijkstra used for link-state routing and Bellman-Ford for distance-vector routing (Quora) : [https://www.quora.com/Why-is-Dijkstra-used-for-link-state-routing-and-Bellman-Ford-for-distance-vector-routing-Why-not-use-the-same](https://www.quora.com/Why-is-Dijkstra-used-for-link-state-routing-and-Bellman-Ford-for-distance-vector-routing-Why-not-use-the-same)
* CSE461 Section 6: Routing Slides (PDF) : [https://courses.cs.washington.edu/courses/cse461/18sp/slides/sections/section-6.pdf](https://courses.cs.washington.edu/courses/cse461/18sp/slides/sections/section-6.pdf)

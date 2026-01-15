---
title: Server Load Balancing (SLB)
---

This document analyzes Server Load Balancing (SLB) techniques.

## 1. Server Load Balancing (SLB)

{{< figure caption="[Figure 1] SLB" src="images/slb.png" width="450px" >}}

SLB means techniques for adjusting server load, as the name suggests. SLB consists of **LB (Load Balancer)** and **VIP (Virtual IP)**. LB receives client requests that should be delivered to servers and delivers them to appropriate servers. VIP (Virtual IP) is a single virtual IP that represents multiple servers that are targets of Load Balancing. Clients make requests to VIP (Virtual IP) that LB has, not to each server's IP. Therefore, clients do not know about the existence of multiple servers and think they are communicating with a single server.

The core of SLB is the role of LB. LB must decide how to perform Load Balancing. Load Balancing techniques include the following:

* Round Robin : Selects servers based on Round Robin algorithm.
* Least Connection : Selects the server with the least number of current connections.
* RTT : Selects the server with the smallest RTT (Round Trip Time).
* Priority : Selects servers with higher priority. If a server with higher priority is in an abnormal state, the next highest priority server is selected.

One important factor to consider during Load Balancing is Session. If multiple connections occurring under the same Session are delivered to different servers, the Session cannot be maintained. For LB to identify Sessions, it must be able to identify that received packets are sent from the same client. Generally, if Source IP Address and Source Port number of packets are the same, they are considered packets from the same client. Therefore, LB must recognize at least L4 Layer Stack. Finally, LB must periodically check the status of servers to prevent client requests from being delivered to servers in abnormal states during Load Balancing.

### 1.1. Proxy

{{< figure caption="[Figure 2] SLB Proxy" src="images/slb-proxy.png" width="700px" >}}

Both Inbound Packets received by servers from clients and Outbound Packets delivered by servers to clients pass through LB. In LB, Source IP of Inbound Packets is changed to LB's VIP through SNAT (Src NAT), and Destination IP is changed to actual server's IP through DNAT (Dst NAT). Then Inbound Packets are delivered to actual servers. Actual servers think LB is the client and send response packets to LB by swapping Src IP and Dst IP of received packets. LB performs SNAT and DNAT again to change back to original IPs and delivers responses to clients.

Since all Inbound and Outbound Packets pass through Proxy, it is advantageous not only for LB performance but also for Packet Filtering. Also, Proxy technique can be implemented without separate network configuration. Therefore, Software LB is implemented using Proxy technique. Proxy technique is unsuitable when servers need to use actual client IPs because actual client IPs are not delivered to servers.

### 1.2. Inline (Transparent)

{{< figure caption="[Figure 3] SLB Inline" src="images/slb-inline.png" width="700px" >}}

Like Proxy technique, both Inbound Packets and Outbound Packets pass through LB. In LB, Inbound Packets are delivered to actual servers after performing only DNAT (Dst NAT) to deliver to actual servers. Since servers' Default Gateway is set to LB, Outbound Packets are delivered to LB. Outbound Packets convert Src IP to LB's VIP through SNAT (Src NAT) again in LB.

Unlike Proxy technique, client's IP is delivered to servers. However, since LB is used as actual servers' Gateway, LB and servers must be on the same network.

### 1.3. DSR (Direct Server Routing)

Proxy and Inline techniques must process all Inbound and Outbound Packets, causing high load on LB. DSR technique can reduce this LB load. Most services have more Outbound Packets than Inbound Packets. DSR technique makes Outbound Packets delivered directly to clients without passing through LB, reducing LB load.

#### 1.3.1. L2DSR

{{< figure caption="[Figure 4] SLB L2DSR" src="images/slb-l2dsr.png" width="700px" >}}

L2DSR is a technique that changes Dst Mac of Inbound Packets. LB converts Mac Address of Inbound Packets to server's Mac Address and delivers them to actual servers. Then actual servers convert Src IP through Loopback Interface that has VIP address and deliver Outbound Packets directly to clients. Since only Mac Address of Inbound Packets is changed, LB and servers must belong to the same network.

#### 1.3.2. L3DSR

{{< figure caption="[Figure 5] SLB L3DSR DSCP" src="images/slb-l3dsr-dscp.png" width="700px" >}}

L3DSR is a technique developed to overcome the limitation of L2DSR that LB and servers must belong to the same network. L3DSR is a technique that changes Dst IP of Inbound Packets. In addition, it changes DSCP Field of Inbound Packets or tunnels Inbound Packets so servers can know VIP information. [Figure 5] shows L3DSR using DSCP Field. LB and all servers know DSCP/VIP Mapping Table. LB converts Dst IP of Inbound Packets to actual server's IP and also changes DSCP value based on Dst IP information of packets and Mapping Table information. Then it delivers to actual servers. Servers that receive packets change Src IP through Mapping Table and Loopback Interface and set DSCP value to 0 to deliver directly to clients.

{{< figure caption="[Figure 6] SLB L3DSR Tunnel" src="images/slb-l3dsr-tunnel.png" width="700px" >}}

The technique of tunneling packets is similar to DSCP technique. LB and servers have Tunnel/VIP Mapping information. Based on this Mapping Table, LB and each server perform L3DSR technique.

## 2. GSLB (Global Server Load Balancing)

{{< figure caption="[Figure 7] GSLB" src="images/gslb.png" width="600px" >}}

GSLB has a similar name to SLB but is a Load Balancing technique based on **DNS**, not VIP. It is used when servers providing services are separated in multiple regions and operated in completely different networks. Therefore, Load Balancing can be performed in GSLB + SLB form. While general DNS does not consider server or network status at all, GSLB selects servers in the following order, so it can be easily understood as intelligent DNS.

* Server Health
* SLB Session / Network Capacity Threshold
* Network Proximity
* Geographic Proximity
* SLB Connection Load
* Site Preference
* Least Selected
* Static Load Balancing

## 3. References

* SLB : [https://www.slideshare.net/ryuichitakashima3/ss-72343772](https://www.slideshare.net/ryuichitakashima3/ss-72343772)
* SLB : [https://vzealand.com/2016/10/04/vcap6-nv-3v0-643-study-guide-part-8/](https://vzealand.com/2016/10/04/vcap6-nv-3v0-643-study-guide-part-8/)
* GSLB : [https://www.netmanias.com/ko/post/blog/5620/dns-data-center-gslb-network-protocol/global-server-load-balancing-for-enterprise-part-1-concept-workflow](https://www.netmanias.com/ko/post/blog/5620/dns-data-center-gslb-network-protocol/global-server-load-balancing-for-enterprise-part-1-concept-workflow)


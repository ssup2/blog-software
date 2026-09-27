---
title: Linux LVS, IPVS
---

This article analyzes LVS (Linux Virtual Server), a technique that performs Load Balancing at the Linux Kernel Level, and IPVS (IP Virtual Server), the core element of LVS.

## 1. LVS (Linux Virtual Server)

{{< figure caption="[Figure 1] Linux LVS" src="images/lvs.png" width="400px" >}}

**LVS** is an L4 Load Balancer solution provided by Linux. [Figure 1] shows the LVS configuration. LVS is largely composed of the Load Balancer, which performs Packet Load Balancing, and the Real Servers, which are the actual destinations of Packets. To prevent SPOF (Single Pointer Of Failure), the Load Balancer is generally configured by binding two or more Load Balancers with VRRP. The Keepalived feature provided by the Network Stack of the Linux Kernel is used to bind them with VRRP. Each Load Balancer performs Packet Load Balancing using the Linux Kernel's IPVS, which is described below.

## 2. IPVS (IP Virtual Server)

IPVS is an L4 Load Balancer that operates on top of Linux's Netfilter. Since it operates at the Linux Kernel Level, it operates with faster performance than User Level Load Balancers such as HAProxy. IPVS can perform DR (Direct Routing), NAT, and IPIP Tunneling on received Packets. IPVS can be controlled through the `ipvsadm` command.

An L4 Load Balancer can be sufficiently implemented with iptables alone without IPVS, but there is a limit to the performance of netfilter, which operates in a Chain manner that processes Packets while following Rules. In addition, IPVS provides commonly used Load Balancing algorithms such as `rr` (Round Robin) and `dh` (Destination Hash) so that they can be used easily. Therefore, it is advantageous to use IPVS when performing L4 Load Balancing at the Linux Kernel Level.

### 2.1. Netfilter Hook Function

{{< figure caption="[Figure 2] IPVS Netfilter Hook Function" src="images/ipvs-netfilter-hook-function.png" width="900px" >}}

[Figure 2] shows the Netfilter Hook Functions of IPVS. The Netfilter Hook Functions of IPVS are organized so that there is no problem not only when the Real Server/Client using IPVS runs on an external Node, but also when it runs on the Node where IPVS is applied. IPVS uses the following six Netfilter Hook Functions.

#### 2.1.1. ip-vs-remote-request()

`ip-vs-remote-request()` is a Netfilter Hook Function called at the `LOCAL-IN` Hook. **When the Client is on an external Node**, `ip-vs-remote-request()` is called through the `LOCAL-IN` Hook. It performs Load Balancing and, as needed, **DR, DNAT, or IPIP Tunneling** on the request Packet and delivers it to a Real Server. `ip-vs-remote-request()` is called after `ip-vs-reply()` between the Input nat Table and the Input security Table of iptables. The actual implementation of `ip-vs-remote-request()` simply calls `ip-vs-in()`. A Packet whose processing is completed through `ip-vs-in()` is not delivered to a Local Process but is delivered directly to the `POSTROUTING` Table.

#### 2.1.2. ip-vs-local-request()

`ip-vs-local-request()` is a Netfilter Hook Function called at the `LOCAL-OUT` Hook. **When the Client is on the Node where IPVS is applied**, if the Dest IP of the request Packet received from the Client is the IP of IPVS, `ip-vs-local-request()` is called through the `LOCAL-OUT` Hook. Like `ip-vs-remote-request()`, it performs Load Balancing and, as needed, **DR, DNAT, or IPIP Tunneling** on the request Packet and delivers it to a Real Server. `ip-vs-local-request()` is called after `ip-vs-local-reply()` between the Output nat Table and the Output filter Table of iptables. The actual implementation of `ip-vs-local-request()`, like `ip-vs-remote-request()`, simply calls `ip-vs-in()`. A Packet whose processing is completed through `ip-vs-in()` is delivered directly to the `POSTROUTING` Table.

#### 2.1.3. ip-vs-reply()

`ip-vs-reply()` is a Netfilter Hook Function called at the `LOCAL-IN` Hook and the `FORWARD` Hook. When a request Packet received from a Client through IPVS is load balanced and DNATed to a Real Server IP and delivered to the Real Server, IPVS must SNAT the response Packet received from the Real Server to the IP of IPVS and send it to the Client. `ip-vs-reply()` is the Netfilter Hook Function that performs **SNAT** on the response Packet received from the Real Server to the IP of IPVS.

**When the Real Server is on an external Node and the Client is on the Node where IPVS is applied**, SNAT is performed through `ip-vs-reply()` of the `LOCAL-IN` Hook. `ip-vs-reply()` of the `LOCAL-IN` Hook is called before `ip-vs-remote-request()` between the Input nat Table and the Input security Table of iptables. **When the Real Server and the Client are on external Nodes**, SNAT is performed through `ip-vs-reply()` of the `FORWARD` Hook. `ip-vs-reply()` of the `FORWARD` Hook is called after the Forward security Table of iptables and `ip-vs-forward-icmp()`. The actual implementation of `ip-vs-reply()` simply calls `ip-vs-out()`.

#### 2.1.4. ip-vs-local-reply()

`ip-vs-local-reply()` is a Hook Function called at the `LOCAL-OUT` Hook. Like `ip-vs-reply()`, it is a Netfilter Hook Function that performs **SNAT** on the response Packet received from the Real Server to the IP of IPVS. Regardless of the location of the Client, **when the Real Server is on the Node where IPVS is applied**, SNAT is performed through `ip-vs-local-reply()`. `ip-vs-local-reply()` is called before `ip-vs-local-request()` between the Output nat Table and the Output filter Table of iptables. The actual implementation, like `ip-vs-reply()`, simply calls `ip-vs-out()`.

#### 2.1.5. ip-vs-forward-icmp()

`ip-vs-forward-icmp()` is a Hook Function called at the `FORWARD` Hook. An ICMP Packet whose Dest is `0.0.0.0/0` (all IPs) is delivered not to the `LOCAL-IN` Table but to the `FORWARD` Table, and this function performs the role of receiving such ICMP Packets and delivering them to Real Servers. `ip-vs-forward-icmp()` is called between the Forward security Table of iptables and `ip-vs-reply()`. The actual implementation of `ip-vs-forward-icmp()` calls `ip-vs-in-icmp()`.

### 2.2 IPVS Dummy Interface

```shell {caption="[Shell 1] IPVS List"}
$ ipvsadm -ln
...
TCP  10.100.15.169:80 rr
  -> 192.167.1.93:80              Masq    1      0          0
  -> 192.167.2.88:80              Masq    1      0          0
  -> 192.167.2.215:80             Masq    1      0          0    
TCP  10.103.1.234:80 rr
  -> 192.167.1.93:80              Masq    1      0          0
  -> 192.167.2.88:80              Masq    1      0          0
  -> 192.167.2.215:80             Masq    1      0          0   
...
```

```shell {caption="[Shell 2] IPVS Dummy Interface"}
$ ip a
...
4: ipvs0: <BROADCAST,NOARP> mtu 1500 qdisc noop state DOWN group default
    link/ether 72:35:cc:0c:19:b3 brd ff:ff:ff:ff:ff:ff
    inet 10.100.15.169/32 brd 10.100.15.169 scope global kube-ipvs0
       valid-lft forever preferred-lft forever
    inet 10.103.1.234/32 brd 10.103.1.234 scope global kube-ipvs0
       valid-lft forever preferred-lft forever
...
```

The `LOCAL-IN` Hook is a Hook that is called before a Packet is delivered to a Process when the Dest IP of the Packet is the IP of the Node itself. Therefore, if the Dest IP of a Packet is the IP of IPVS, not the IP of the Node, the Packet should be processed at the `FORWARD` Hook, not the `LOCAL-IN` Hook. However, the reason the Packet is processed at the `LOCAL-IN` Hook is that the IP of IPVS is assigned to the Dummy Interface, which must be configured together with the IPVS configuration.

[Shell 1] shows the IPVS List information using the `ipvsadm` command. It is configured so that Packets whose Dest IP and Dest Port are `10.100.15.169:80` or `10.103.1.234:80` are load balanced by the Round Robin algorithm. [Shell 2] shows the Dummy Interface of IPVS. It can be seen that `10.100.15.169` and `10.103.1.234`, the IPs of IPVS, are configured on the `ipvs0` Interface.

## 3. References

* LVS : [https://access.redhat.com/documentation/ko-kr/red-hat-enterprise-linux/5/html/cluster-suite-overview/s1-lvs-overview-cso](https://access.redhat.com/documentation/ko-kr/red-hat-enterprise-linux/5/html/cluster-suite-overview/s1-lvs-overview-cso)
* LVS : [http://www.austintek.com/LVS/LVS-HOWTO/HOWTO/LVS-HOWTO.fwmark.html](http://www.austintek.com/LVS/LVS-HOWTO/HOWTO/LVS-HOWTO.fwmark.html)
* ipvs : [http://www.austintek.com/LVS/LVS-HOWTO/HOWTO/LVS-HOWTO.filter-rules.html](http://www.austintek.com/LVS/LVS-HOWTO/HOWTO/LVS-HOWTO.filter-rules.html)
* ipvs : [https://www.valinux.co.jp/technologylibrary/document/load-balancing/lvs0001/](https://www.valinux.co.jp/technologylibrary/document/load-balancing/lvs0001/)
* ipvs : [https://github.com/torvalds/linux/blob/master/net/netfilter/ipvs/ip-vs-core.c](https://github.com/torvalds/linux/blob/master/net/netfilter/ipvs/ip-vs-core.c)
* ipvs : [http://helloweishi.github.io/network/stack/2015/06/27/L3-IP-stack/](http://helloweishi.github.io/network/stack/2015/06/27/L3-IP-stack/)
* ipvs : [http://www.linuxvirtualserver.org/VS-NAT.html](http://www.linuxvirtualserver.org/VS-NAT.html)

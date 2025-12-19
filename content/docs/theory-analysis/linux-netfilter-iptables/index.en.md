---
title: Linux Netfilter, iptables
---

Analyze the Netfilter Framework in Linux and the iptables tool that uses Netfilter.

## 1. Netfilter

Netfilter is a Network Packet Filtering Framework for Linux. Linux Applications can transform and manipulate Packets delivered to the Linux Kernel through Netfilter.

### 1.1. Hooks

Netfilter provides 5 Hook Points.

* `NF-IP-PRE-ROUTING` : A Hook that occurs before Packets from outside pass through the Linux Kernel's Network Stack. It occurs before Routing Packets.
* `NF-IP-LOCAL-IN` : A Hook that occurs before delivering Packets to Processes when the destination is itself after Packets are Routed.
* `NF-IP-FORWARD` : A Hook that occurs when forwarding Packets elsewhere when the destination is not itself after Packets are Routed.
* `NF-IP-LOCAL-OUT` : A Hook that occurs before Packets from Processes pass through the Network Stack.
* `NF-IP-POST-ROUTING` : A Hook that occurs before sending Packets outside after they pass through the Network Stack.

### 1.2. Packet Process

{{< figure caption="[Figure 1] Netfilter Packet Path" src="images/netfilter-packet-routine.png" width="700px" >}}

[Figure 1] shows the Packet path of Netfilter. Routing1 represents the process of Routing by distinguishing whether Packets received from Network Interfaces are Packets that should be received by itself or Packets that should be received by other Hosts. Routing2 represents the process of re-Routing when Packets sent from Processes are DNATed at NF-IP-LOCAL-OUT. Packet paths can be divided into the following 3 types:

* When the destination of Packets from outside is itself: `NF-IP-PRE-ROUTING` -> `NF-IP-LOCAL-IN` -> Process
* When the destination of Packets from outside is not itself: `NF-IP-PRE-ROUTING` -> `NF-IP-FORWARD` -> `NF-IP-POST-ROUTING` -> Network Interface
* When Packets are sent from Process: `NF-IP-LOCAL-OUT` -> `NF-IP-POST-ROUTING` -> Network Interface

## 2. iptables

{{< figure caption="[Figure 2] iptables Packet Path" src="images/iptables-packet-traversal.png" width="800px" >}}

iptables is a representative Tool that uses the Netfilter Framework. You can control or manipulate Packets using iptables. [Figure 2] shows the Packet path of iptables using Netfilter. In the figure, `PREROUTING`, `FORWARD`, `INPUT`, `OUTPUT`, and `POSTROUTING` represent Netfilter's `NF-IP-PRE-ROUTING`, `NF-IP-LOCAL-IN`, `NF-IP-FORWARD`, `NF-IP-LOCAL-OUT`, and `NF-IP-POST-ROUTING` Hooks respectively.

### 2.1. Tables

iptables provides a total of 5 Tables: Filter Table, NAT Table, Mangle Table, Raw Table, and Security Table.

* **Filter** Table : A Table for Packet Filtering. It determines whether to deliver Packets to their destination or Drop Packets. Firewall functionality can be built through the Filter Table.
* **NAT** Table : A Table for Packet NAT (Network Address Translation). It changes Packet Source Addresses or Destination Addresses.
* **Mangle** Table : Changes Packet IP Headers. It changes Packet TTL (Time to Live) or Marks Packets so that Packets can be distinguished in other iptables Tables or Network Tools.
* **Raw** Table : The Netfilter Framework provides not only Hooks but also Connection Tracking functionality. It tracks Connections of Packets that just arrived based on previously arrived Packets. The Raw Table sets specific Packets to be excluded from Connection Tracking.
* **Security** Table : A Table for determining how SELinux processes Packets.

### 2.2. Packet flow

As shown in [Figure 2], Packets are processed while passing through multiple Tables at each Hook. Black squares inside Hook dotted lines represent iptables tables that process Packets, and blue squares outside Hook dotted lines represent Packet processing processes unrelated to iptables. Connection Tracking refers to the part where the Netfilter Framework starts tracking Connections based on Packet information.

### 2.3. Chain, Rule

Each Table consists of a combination of Chains. In [Figure 2], you can see that the NAT Table is included in 4 hooks: `PREROUTING`, `INPUT`, `OUTPUT`, and `POSTROUTING`, which means the NAT Table consists of 4 or more Chains. Also, each Chain consists of a combination of multiple Rules.

```shell {caption="[Shell 1] iptables Example", linenos=table}
$ iptables -t nat -vL
Chain PREROUTING (policy ACCEPT 1103 packets, 118K bytes)
 pkts bytes target     prot opt in     out     source               destination         
  412 26287 DOCKER     all  --  any    any     anywhere             anywhere             ADDRTYPE match dst-type LOCAL

Chain INPUT (policy ACCEPT 1069 packets, 112K bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain OUTPUT (policy ACCEPT 278 packets, 22606 bytes)
 pkts bytes target     prot opt in     out     source               destination         
   60  3536 DOCKER     all  --  any    any     anywhere            !127.0.0.0/8          ADDRTYPE match dst-type LOCAL

Chain POSTROUTING (policy ACCEPT 285 packets, 21020 bytes)
 pkts bytes target     prot opt in     out     source               destination         
   93  6016 MASQUERADE  all  --  any    !docker0  172.17.0.0/16        anywhere            
    0     0 MASQUERADE  tcp  --  any    any     172.17.0.2           172.17.0.2           tcp dpt:9736
    0     0 MASQUERADE  tcp  --  any    any     172.17.0.2           172.17.0.2           tcp dpt:9008
    0     0 MASQUERADE  tcp  --  any    any     172.17.0.2           172.17.0.2           tcp dpt:http-alt
    0     0 MASQUERADE  tcp  --  any    any     172.17.0.2           172.17.0.2           tcp dpt:6776

Chain DOCKER (2 references)
 pkts bytes target     prot opt in     out     source               destination         
  137  8220 RETURN     all  --  docker0 any     anywhere             anywhere            
    0     0 DNAT       tcp  --  !docker0 any     anywhere             anywhere             tcp dpt:9736 to:172.17.0.2:9736
    0     0 DNAT       tcp  --  !docker0 any     anywhere             anywhere             tcp dpt:9008 to:172.17.0.2:9008
   43  2356 DNAT       tcp  --  !docker0 any     anywhere             anywhere             tcp dpt:http-alt to:172.17.0.2:8080
    0     0 DNAT       tcp  --  !docker0 any     anywhere             anywhere             tcp dpt:6776 to:172.17.0.2:6776
```

[Shell 1] shows an iptables example and displays the NAT Table of a Docker Host. There are 4 Default Chains: `PREROUTING`, `INPUT`, `OUTPUT`, and `POSTROUTING`, and you can see the `DOCKER` Chain used by Docker. If Docker Containers have set Port Forwarding, the Docker Daemon registers Port Forwarding Rules in the `DOCKER` Chain.

All Packets entering the Docker Host move from the `PREROUTING` CHAIN to the `DOCKER` CHAIN. When multiple Rules are registered in a Chain, they are compared sequentially from top to bottom. Therefore, Packets that come to the `DOCKER` CHAIN check in order whether the Destination Port number in the TCP Header is `9736`, `9008`, `8080`, or `6776`, and if it matches, change the Destination IP to `172.17.0.2`. Packets with changed Destination IP are Routed to Docker Containers during the Routing (Interface) process.

## 3. References

* iptables, Netfilter : [https://www.digitalocean.com/community/tutorials/a-deep-dive-into-iptables-and-netfilter-architecture](https://www.digitalocean.com/community/tutorials/a-deep-dive-into-iptables-and-netfilter-architecture)
* iptable process : [http://stuffphilwrites.com/2014/09/iptables-processing-flowchart/](http://stuffphilwrites.com/2014/09/iptables-processing-flowchart/)
* Netfilter Packet Traversal : [http://linux-ip.net/](http://linux-ip.net/)


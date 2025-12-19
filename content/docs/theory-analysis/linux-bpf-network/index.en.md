---
title: Linux BPF Network Program Type
---

Analyze BPF of Network BPF Program Type.

## 1. Network BPF Program Type

{{< figure caption="[Figure 1] Network BPF Program Type" src="images/bpf-net-type.png" width="450px" >}}

[Figure 1] shows Network-related Types among BPF Program Types provided by Linux along with the Kernel's Network Stack. Various Types of BPF Programs exist for each Network Stack, and more will continue to be added in the future. [Figure 1] is based on **Kernel Version v5.13**.

### 1.1. Device Driver, BPF-PROG-TYPE-XDP

The BPF Program Type that operates inside Device Drivers is only the `BPF-PROG-TYPE-XDP` Type. It is commonly called **XDP** (Express Data Path). It is the Type that runs at the lowest Level among Network BPF Program Types. Therefore, it is the Type that processes the most Packets per hour based on Ingress. It only supports eBPF.

Since the `BPF-PROG-TYPE-XDP` Type is performed before Socket Buffer is allocated, the Input Type of XDP eBPF Programs uses the `xdp-md` structure that can only know the Data of incoming Packets. Available Kernel Helper Functions are also limited. XDP eBPF Programs are eBPF Programs whose main purpose is Packet Drop and Routing rather than Packet processing operations. XDP eBPF Program execution results support only the following 5 types.

* `XDP-DROP` : Drops the Packet.
* `XDP-ABORTED` : Drops the Packet and raises `trace-xdp-exception`.
* `XDP-PASS` : Passes the Packet to the upper Network Stack.
* `XDP-TX` : Sends the Packet externally through the Network Device it came in from.
* `XDP-REDIRECT` : Passes the Packet to another Network Device.

Since the `BPF-PROG-TYPE-XDP` Type is loaded and run in eBPF operating in Network Device Drivers, XDP eBPF Programs cannot be run in Network Device Drivers that do not support XDP. The limited runtime environment of XDP eBPF Programs makes development and Debugging of `BPF-PROG-TYPE-XDP` Type Programs difficult.

The XDP Type that emerged to solve this problem is a technique called **Generic XDP**. Generic XDP is a technique that places eBPF between Network Device Drivers and tc and loads `BPF-PROG-TYPE-XDP` type Programs. Through Generic XDP, XDP eBPF Programs can be run on any Network Device, including virtual Network Devices. After Generic XDP emerged, the technique of running Programs in existing Network Device Drivers is called **Native XDP**.

Generic XDP is a technique for XDP development and Debugging as mentioned above. Since Generic XDP runs at a higher Network Stack compared to Native XDP, it has lower Packet throughput compared to Native XDP based on Ingress. Also, it does not allow using more Helper Functions. However, since it runs before BPF Programs operating in the tc Layer, it is more advantageous to use Generic XDP rather than BPF Programs operating in the tc Layer when performing simple operations such as dropping Ingress Packets.

### 1.2. tc (Traffic Control)

tc BPF Program Types are Types that operate in BPF existing in the tc Layer. All tc BPF Program Types receive Socket Buffer (\-\-sk-buff) as Input. Through Socket Buffer and Helper Functions utilizing Socket Buffer, more diverse Packet processing is possible compared to the `BPF-PROG-TYPE-XDP` Type. `BPF-PROG-TYPE-SCHED-ACT` and `BPF-PROG-TYPE-SCHED-CLS` Types exist.

#### 1.2.1. BPF-PROG-TYPE-SCHED-ACT

The `BPF-PROG-TYPE-SCHED-ACT` Type performs Packet processing roles such as Packet Drop and Forwarding. Both Ingress/Egress processing is possible, and both eBPF/cBPF are supported. It returns values defined in the Linux Kernel starting with `TC-ACT-`.

* `TC-ACT-OK` : In Ingress, it passes the Packet to the Network Stack, and in Egress, it passes the Packet to the Network Device.
* `TC-ACT-SHOT` : Drops Packets coming through Ingress and releases Socket Buffer. Therefore, Packets cannot be delivered to the upper Network Stack.
* `TC-ACT-STOLEN` : Consumes or Queues Packets coming through Ingress. Therefore, Packets cannot be delivered to the upper Network Stack.
* `TC-ACT-REDIRECT` : Delivers the Packet to Ingress or Egress of the same or different Network Device.

#### 1.2.2. BPF-PROG-TYPE-SCHED-CLS

The `BPF-PROG-TYPE-SCHED-CLS` Type performs the role of setting classid on Packets. Therefore, it returns classid. Both Ingress/Egress processing is possible, and both eBPF/cBPF are supported. The `BPF-PROG-TYPE-SCHED-CLS` Type can use a technique called **direct-action**. When using the direct-action technique, the `BPF-PROG-TYPE-SCHED-CLS` Type can also process Packets like the `BPF-PROG-TYPE-SCHED-ACT` Type. That is, it can return values defined in the Linux Kernel starting with `TC-ACT-` like `BPF-PROG-TYPE-SCHED-ACT`.

Since the `BPF-PROG-TYPE-SCHED-CLS` Type runs before the `BPF-PROG-TYPE-SCHED-ACT` Type, performing Packet processing in the `BPF-PROG-TYPE-SCHED-CLS` Type using the direct-action technique can provide performance benefits.

### 1.3. cgroup

cgroup BPF Program Types are Types that operate in BPF existing for each Cgroup. cgroup BPF Program Types only process Packets of Processes included in that cgroup. They do not process Packets of Processes not included in that cgroup. Therefore, if you want to apply BPF Programs only to specific Process Groups, you can use cgroup BPF Program Types and cgroups. `BPF-PROG-TYPE-CGROUP-SKB`, `BPF-PROG-TYPE-CGROUP-SOCK`, `BPF-PROG-TYPE-CGROUP-SOCK-ADDR`, and `BPF-PROG-TYPE-CGROUP-SOCKOPT` Types exist.

#### 1.3.1. BPF-PROG-TYPE-CGROUP-SKB 

The `BPF-PROG-TYPE-CGROUP-SKB` Type performs the role of Filtering Ingress/Egress Packets of Processes included in the cgroup. It only supports eBPF.

#### 1.3.2. BPF-PROG-TYPE-CGROUP-SOCK

The `BPF-PROG-TYPE-CGROUP-SOCK` Type performs the role of being called when Processes included in the cgroup create, delete, or bind Sockets to determine whether to allow the operation. It can also be used to obtain Socket-related statistics. It only supports eBPF.

#### 1.3.3. BPF-PROG-TYPE-CGROUP-SOCK-ADDR

The `BPF-PROG-TYPE-CGROUP-SOCK-ADDR` Type performs the role of being called when Processes included in the cgroup call `connect()`, `bind()`, `sendto()`, or `recvmsg()` System Calls to change the Socket's IP and Port. It only supports eBPF.

#### 1.3.4. BPF-PROG-TYPE-CGROUP-SOCKOPT

The `BPF-PROG-TYPE-CGROUP-SOCKOPT` Type performs the role of being called when Processes included in the cgroup call `setsockopt()` or `getsockopt()` System Calls to change Socket Options to change Socket Options. It only supports eBPF.

### 1.4. Socket

Socket BPF Program Types are Types that operate in eBPF existing for each Socket. `BPF-PROG-TYPE-SOCKET-FILTER`, `BPF-PROG-TYPE-SOCK-OPS`, `BPF-PROG-TYPE-SK-SKB`, `BPF-PROG-TYPE-SK-MSG`, `BPF-PROG-TYPE-SK-REUSEPORT`, and `BPF-PROG-TYPE-SK-LOOKUP` Types exist.

#### 1.4.1. BPF-PROG-TYPE-SOCKET-FILTER

The `BPF-PROG-TYPE-SOCKET-FILTER` Type performs the role of Filtering Ingress/Egress Packets of Sockets. Both cBPF (`SO-ATTACH-FILTER`) and eBPF (`SO-ATTACH-BPF`) are supported.

#### 1.4.2. BPF-PROG-TYPE-SOCK-OPS

The `BPF-PROG-TYPE-SOCK-OPS` Type performs the role of being called multiple times during the process of Processes controlling Sockets to control Sockets. It only supports eBPF.

#### 1.4.3. BPF-PROG-TYPE-SK-SKB

The `BPF-PROG-TYPE-SK-SKB` Type performs the role of dropping each Packet received by Sockets or sending them to other Sockets.

#### 1.4.4. BPF-PROG-TYPE-SK-MSG

The `BPF-PROG-TYPE-SK-MSG` Type performs the role of determining allow/deny for each Packet sent by Sockets.

#### 1.4.5. BPF-PROG-TYPE-SK-REUSEPORT

The `BPF-PROG-TYPE-SK-REUSEPORT` Type is called when Processes bind Sockets through the `bind()` System Call. Through the `BPF-PROG-TYPE-SK-REUSEPORT` Type, multiple Processes can bind and use a single Port.

#### 1.4.6. BPF-PROG-TYPE-SK-LOOKUP

The `BPF-PROG-TYPE-SK-LOOKUP` Type performs the role of determining which Socket should receive received Packets.

## 2. References

* [https://blogs.oracle.com/linux/post/bpf-a-tour-of-program-types](https://blogs.oracle.com/linux/post/bpf-a-tour-of-program-types)
* [https://access.redhat.com/documentation/en-us/red-hat-enterprise-linux/8/html/configuring-and-managing-networking/assembly-understanding-the-ebpf-features-in-rhel-configuring-and-managing-networking](https://access.redhat.com/documentation/en-us/red-hat-enterprise-linux/8/html/configuring-and-managing-networking/assembly-understanding-the-ebpf-features-in-rhel-configuring-and-managing-networking)
* [https://elixir.bootlin.com/linux/latest/source/include/uapi/linux/bpf.h](https://elixir.bootlin.com/linux/latest/source/include/uapi/linux/bpf.h)
* [https://qmonnet.github.io/whirl-offload/2020/04/11/tc-bpf-direct-action/](https://qmonnet.github.io/whirl-offload/2020/04/11/tc-bpf-direct-action/)
* [https://cilium.readthedocs.io/en/v1.0/bpf/?fbclid=IwAR38RyvJXSsuzWk1jaTOGR7OhlgvQezoIHRLuiUA4rG2fc-AA70yyQTvxOg#bpf-guide](https://cilium.readthedocs.io/en/v1.0/bpf/?fbclid=IwAR38RyvJXSsuzWk1jaTOGR7OhlgvQezoIHRLuiUA4rG2fc-AA70yyQTvxOg#bpf-guide)
* [http://man7.org/linux/man-pages/man2/bpf.2.html](http://man7.org/linux/man-pages/man2/bpf.2.html)
* [https://kccncna19.sched.com/event/Uae7](https://kccncna19.sched.com/event/Uae7)


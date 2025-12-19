---
title: Linux macvlan, macvtap
---

Analyze Linux's Virtual Network Devices macvlan and macvtap.

## 1. macvlan

{{< figure caption="[Figure 1] macvlan Components" src="images/macvlan-component.png" width="400px" >}}

macvlan is a Network Device Driver that allows one Network Interface to be separated into **multiple virtual Network Interfaces** for use. [Figure 1] briefly shows the components of macvlan. macvlan creates multiple Child Interfaces using a Parent Interface. Child Interfaces can each have separate **MAC Addresses** and **macvlan Modes**. Modes can be set when creating Child Interfaces, and Packet transmission policies of macvlan differ according to Mode. Communication between Child Interfaces is possible depending on Mode, but one of macvlan's characteristics is that Parent Interface and Child Interface absolutely cannot communicate with each other regardless of Mode.

{{< figure caption="[Figure 2] macvlan Example" src="images/macvlan-example.png" width="600px" >}}

[Figure 2] shows a configuration diagram where vlan Interfaces are set as macvlan's Parent Interface and multiple Child Interfaces are created. macvlan can use not only physical Ethernet Interfaces but also virtual Interfaces such as vlan Interfaces and bridge Interfaces as Parent Interfaces.

```shell {caption="[Shell 1] Add macvlan"}
# ip li add link <parent> <child> type macvlan mode <mode (private, vepa, bridge, passthru)>
$ ip li add link enp0s3 mac0 type macvlan mode private
$ ip a
mac0@enp0s3: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN group default qlen 1
link/ether 4e:a4:2f:dc:75:8d brd ff:ff:ff:ff:ff:ff
```

[Shell 1] shows the `ip` command to add macvlan.

### 1.1 Mac Address Management

{{< figure caption="[Figure 3] macvlan MAC Address Management" src="images/macvlan-address-manage.png" width="700px" >}}

[Figure 3] shows how macvlan Child MAC Addresses are managed. macvlan basically manages Child MAC Addresses using a Hash Table of size 256 and a Linked List. And such Hash Tables are created as many as the number of macvlan Parent Interfaces. As shown in [Figure 3], if there are 3 vlan Interfaces, 3 Hash Tables exist in the Linux Kernel. In other words, macvlan Objects exist as many as Parent Interfaces, and each macvlan Object has one Hash Table. Child Interface MAC Addresses are registered in the Hash Table when the Child Interface is Up, and registered MAC Addresses in the Hash Table are deleted when the Child Interface is Down.

### 1.2. macvlan Mode

macvlan can set different macvlan Modes for each Child when creating Children. Packet transmission policies differ according to Mode. macvlan Modes include Private Mode, VEPA Mode, Bridge Mode, and Passthru Mode.

#### 1.2.1. Private Mode

{{< figure caption="[Figure 4] macvlan Private Mode" src="images/macvlan-private-mode.png" width="400px" >}}

[Figure 4] shows when all Children are in Private Mode. When a Packet goes from Child to Parent, if the Child is in Private Mode, the Packet is unconditionally delivered to Parent. When a Packet comes from Parent to Child, if the Child's Mode is Private Mode, it checks whether the Packet's Src MAC Address exists in the macvlan Hash Table. If the Src MAC Address is not in the Hash Table, the Packet is delivered to Child, but if it exists, the Packet is Dropped. Private Mode is used when you do not want to receive Packets from Children of the same macvlan.

#### 1.2.2. VEPA (Virtual Ethernet Port Aggregator) Mode

{{< figure caption="[Figure 5] macvlan VEPA Mode" src="images/macvlan-vepa-mode.png" width="400px" >}}

[Figure 5] shows when all Children are in VEPA Mode. When a Packet goes from Child to Parent, if the Child is in VEPA Mode, the Packet is unconditionally delivered to Parent. When a Packet comes from Parent to Child, if the Child's Mode is VEPA Mode, the Packet is unconditionally delivered to Child. VEPA Mode allows communication between Children but has the characteristic that Packets sent from Children are unconditionally delivered outside through Parent. It is used when Packets delivered from Children must be unconditionally delivered to external switches.

#### 1.2.3. Bridge Mode

{{< figure caption="[Figure 6] macvlan Bridge Mode" src="images/macvlan-bridge-mode.png" width="400px" >}}

[Figure 6] shows when all Children are in Bridge Mode. When a Packet goes out from Child, if the Packet's Dst MAC Address exists in the Hash Table, macvlan immediately delivers the Packet to Child instead of Parent. When a Packet comes from Parent to Child, if the Child's Mode is Bridge Mode, the Packet is unconditionally delivered to Child. Since it performs the same operation as Linux Bridge, it is often used as a replacement for Linux Bridge.

#### 1.2.4. Passthru Mode

{{< figure caption="[Figure 7] macvlan Passthru Mode" src="images/macvlan-passthru-mode.png" width="200px" >}}

[Figure 7] shows when Child is in Passthru Mode. Passthru Mode Children unconditionally maintain a 1:1 relationship with Parent. Therefore, when Child is in Passthru Mode, macvlan does not use Hash Tables. Passthru Mode is generally not used in macvlan but is used when providing Virtual NICs to virtual machines through macvtap.

### 1.3. vs Linux Bridge

macvlan's Bridge Mode can replace Linux Bridge. Linux Bridge manages MAC Tables through MAC Learning like general physical Bridges. It also performs STP (Spanning Tree Protocol) to prevent Loops in Network paths. On the other hand, macvlan does not perform MAC Learning and simply registers/deletes Child MAC Addresses in Hash Tables when Children are Up/Down. It also does not perform STP. Therefore, it has less CPU Overhead compared to Linux Bridge, and this lower Overhead leads to improved Packet processing rates. Therefore, when communication between Parent and Child is unnecessary and building a simple L2 Level Network, it is good to build the network using macvlan.

## 2. macvtap

macvtap not only creates Child Interfaces based on macvlan but also creates Device files in the form of /dev/tap*. User Applications can directly receive or send Packets through /dev/tap* files.

```shell {caption="[Shell 2] Add macvtap"}
# ip li add link <parent> <child> type macvtap mode <mode (private, vepa, bridge, passthru)>
$ ip li add link enp0s3 mac1 type macvtap mode private
$ ip a
mac1@enp0s3: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN group default qlen 500
link/ether ee:38:97:8c:5d:5c brd ff:ff:ff:ff:ff:ff
$ ls /dev/tap*
/dev/tap142
```

[Shell 2] shows the `ip` command to add macvtap.

## 3. References

* macvlan code : [https://github.com/torvalds/linux/blob/80cee03bf1d626db0278271b505d7f5febb37bba/drivers/net/macvlan.c](https://github.com/torvalds/linux/blob/80cee03bf1d626db0278271b505d7f5febb37bba/drivers/net/macvlan.c)
* macvtap code : [https://github.com/torvalds/linux/blob/80cee03bf1d626db0278271b505d7f5febb37bba/drivers/net/macvtap.c](https://github.com/torvalds/linux/blob/80cee03bf1d626db0278271b505d7f5febb37bba/drivers/net/macvtap.c)
* macvlan : [https://hicu.be/bridge-vs-macvlan](https://hicu.be/bridge-vs-macvlan)


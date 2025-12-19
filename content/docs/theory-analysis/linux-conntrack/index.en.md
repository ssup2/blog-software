---
title: Linux conntrack
---

Analyze conntrack, a Module of the Netfilter Framework that manages Network Connections in Linux.

## 1. Linux conntrack Module

The conntrack Module is a Stateful Module of the Netfilter Framework that **manages and tracks Network Connections** in the Linux Kernel. Network Connection-related functions provided by Netfilter Filter Framework-based Applications such as iptables are all based on the conntrack Module.

### 1.1. Connection Status, conntrack Command

```shell {caption="[Shell 1] conntrack Table"}
$ conntrack -L conntrack
tcp      6 431899 ESTABLISHED src=127.0.0.1 dst=127.0.0.1 sport=49236 dport=53191 src=127.0.0.1 dst=127.0.0.1 sport=53191 dport=49236 [ASSURED] mark=0 use=1
tcp      6 49 TIME-WAIT src=10.0.0.19 dst=10.0.0.11 sport=55120 dport=9283 src=10.0.0.11 dst=10.0.0.19 sport=9283 dport=55120 [ASSURED] mark=0 use=1
tcp      6 7 CLOSE src=10.0.0.11 dst=10.0.0.19 sport=36892 dport=9093 src=10.0.0.19 dst=10.0.0.11 sport=9093 dport=36892 mark=0 use=1
tcp      6 28 TIME-WAIT src=10.0.0.19 dst=10.0.0.19 sport=34306 dport=18080 src=10.0.0.19 dst=10.0.0.19 sport=18080 dport=34306 [ASSURED] mark=0 use=1
```

Connection information managed by the conntrack Module can be checked through the conntrack command. conntrack manages 4 Tables: conntrack, expect, dying, and unconfirmed. The Table where Connection information is stored is determined according to Connection Status.

* **conntrack** : Stores most Connection information. [Shell 1] shows the conntrack Table.
* **expect** : Stores Connection information classified as Related Connections by Connection Tracking Helper.
* **dying** : Stores Connection information that is expired or being deleted through the conntrack command.
* **unconfirmed** : Refers to Connection information that Packets stored in the Kernel's Socket Buffer have, but have not yet been confirmed and therefore not stored in the conntrack Table. Connection information that Packets have is Confirmed when the Packet reaches the Postrouting Hook.

### 1.2. Connection Tracking Helper

Connection Tracking Helper performs the role of identifying Stateful Application Layer Protocols and classifying separate independent Connections as **Related Connections**. Supported Stateful Application Layer Protocols include FTP, TFTP, SNMP, SIP, etc. For example, FTP uses two types of Connections: Control Connection and Data Connection. When a Data Connection is created in a state where a Control Connection exists but no Data Connection exists, the created Data Connection is classified as a Related Connection state, not a New Connection state.

```shell {caption="[Shell 2] conntrack Modules"}
$ lsmod | grep nf-conntrack
nf-conntrack-tftp      16384  0
nf-conntrack-sip       28672  0
nf-conntrack-snmp      16384  0
nf-conntrack-broadcast    16384  1 nf-conntrack-snmp
nf-conntrack-ftp       20480  0
nf-conntrack-netlink    40960  0
nf-conntrack-ipv6      20480  1
nf-conntrack-ipv4      16384  5
nf-conntrack          131072  16 xt-conntrack,nf-nat-masquerade-ipv4,nf-conntrack-ipv6,nf-conntrack-ipv4,nf-nat,nf-conntrack-tftp,nf-nat-ipv6,ipt-MASQUERADE,nf-nat-ipv4,xt-nat,nf-conntrack-sip,openvswitch,nf-conntrack-broadcast,nf-conntrack-netlink,nf-conntrack-ftp,nf-conntrack-snmp
```

Connection Tracking Helper is composed of separate Modules. [Shell 2] shows conntrack-related Modules. In [Shell 2], Modules in the form of `nf-conntrack-[Protocol]` are Modules of Connection Tracking Helper. Stateless Application Layer Protocols such as HTTP are not supported.

### 1.3. Connection Option in iptables

```shell {caption="[Shell 3] Connection State in iptables"}
$ iptables -A INPUT -p tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT
```

iptables provides Connection State condition functions based on the conntrack Module. Connection State conditions supported in iptables are as follows.

* `NEW` : Refers to a state attempting to create a new Connection.
* `ESTABLISHED` : Refers to an existing Connection.
* `RELATED` : Refers to a state attempting to create a new Connection expected by Connection Tracking Helper.
* `INVALID` : Refers to a state not belonging to any Connection.
* `UNTRACKED` : Refers to a state where Connections are not tracked.

[Shell 3] shows the process of setting a Rule through the iptables command that allows Packets coming in through Port 22 when they attempt to create a new Connection or communicate through an existing Connection. iptables also uses the conntrack Module when performing NAT. When NAT Rules are set in iptables, Reverse NAT in the opposite direction is automatically performed even if there is no Reverse NAT Rule in iptables, because iptables performs Reverse NAT **implicitly** based on Connection information from the conntrack Module.

### 1.4. Max Connection Count

Since the conntrack Module stores Connection information in Kernel Memory, the number of Connections that can be stored is limited. You can set the maximum number of Connections that the conntrack Module can store by setting the `/proc/sys/net/nf-conntrack-max` or `/proc/sys/net/ipv4/netfilter/ip-conntrack-max` value. Generally, the default value is `262144`. When the space for storing Connection information is full and new Packets with Connection information are received in a state where Connection information can no longer be stored, those Packets are Dropped.

## 2. References

* [https://manpages.debian.org/testing/conntrack/conntrack.8.en.html](https://manpages.debian.org/testing/conntrack/conntrack.8.en.html)
* [https://en.wikipedia.org/wiki/Netfilter](https://en.wikipedia.org/wiki/Netfilter)
* [http://people.netfilter.org/pablo/docs/login.pdf](http://people.netfilter.org/pablo/docs/login.pdf)
* [https://tech.kakao.com/2016/04/21/closewait-timewait/](https://tech.kakao.com/2016/04/21/closewait-timewait/)
* [https://access.redhat.com/documentation/en-us/red-hat-enterprise-linux/6/html/security-guide/sect-security-guide-firewalls-iptables-and-connection-tracking](https://access.redhat.com/documentation/en-us/red-hat-enterprise-linux/6/html/security-guide/sect-security-guide-firewalls-iptables-and-connection-tracking)
* [https://unix.stackexchange.com/questions/57423/how-to-understand-why-the-packet-was-considered-invalid-by-the-iptables](https://unix.stackexchange.com/questions/57423/how-to-understand-why-the-packet-was-considered-invalid-by-the-iptables)
* [https://www.frozentux.net/iptables-tutorial/chunkyhtml/x1555.html](https://www.frozentux.net/iptables-tutorial/chunkyhtml/x1555.html)


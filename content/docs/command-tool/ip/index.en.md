---
title: ip
---

This document summarizes the usage of `ip` for controlling and querying networks in Linux.

## 1. ip

### 1.1. Address (L2, L3)

* ip addr : Display address information for all interfaces
* ip addr show [Interface] : Display address information for the interface named [Interface]
* ip addr add [IP/CIDR] dev [Interface] : Add IP/CIDR configuration to the interface named [Interface]
* ip addr del [IP/CIDR] dev [Interface] : Delete IP/CIDR configuration from the interface named [Interface]

### 1.2. Link (L2)

* ip link : Display link information for all interfaces
* ip link show (dev) [Interface] : Display link information for the interface named [Interface]
* ip link set (dev) [Interface] up : Change the interface named [Interface] to online state
* ip link set (dev) [Interface] down : Change the interface named [Interface] to offline state

### 1.3. Route

* ip route : Display routing table information
* ip route add default via [IP] dev [Interface] : Set local default gateway IP address to [IP] and use interface [Interface]

### 1.4. Neighbour (ARP)

* ip neigh : Display interface information of external hosts on the same network as this host
* ip neigh show dev [Interface] : Display interface information of external hosts on the network connected through [Interface]

## 2. References

* [https://access.redhat.com/sites/default/files/attachments/rh_ip_command_cheatsheet_1214_jcs_print.pdf](https://access.redhat.com/sites/default/files/attachments/rh_ip_command_cheatsheet_1214_jcs_print.pdf)


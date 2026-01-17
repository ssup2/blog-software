---
title: tcpdump
---

This document summarizes the usage of `tcpdump` for dumping packets.

## 1. tcpdump

### 1.1. tcpdump -i [Interface] tcp port [Port]

Dumps packets using TCP protocol with source/destination port [Port] among packets sent/received through [Interface].

### 1.2. tcpdump -i [Interface] src port [Port]

Dumps packets with source port [Port] among packets sent/received through [Interface].

### 1.3. tcpdump -i [Interface] dst port [Port]

Dumps packets with destination port [Port] among packets sent/received through [Interface].

### 1.4. tcpdump -i [Interface] -Q in

Dumps packets received through [Interface].

### 1.5. tcpdump -i [Interface] -Q out

Dumps packets sent through [Interface].


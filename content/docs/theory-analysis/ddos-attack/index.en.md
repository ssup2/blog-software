---
title: DDoS Attack
---

This document summarizes DDoS (Distributed Denial-of-Service) attacks.

## 1. DDoS (Distributed Denial-of-Service) Attack

A DDoS attack refers to any attack that sends abnormal traffic to a specific server or service to cause a failure of that server or service. Many DDoS attack techniques exist, and most share the characteristic that the attackers can be an unspecified large number of parties who can access the server or service. Therefore, servers or services exposed on a public network must be prepared for DDoS attacks.

## 2. DDoS Attack Type

DDoS attacks can be classified by characteristic into Volumetric Attack, Protocol Attack, and Application Layer Attack types, and a single DDoS attack technique may fall under multiple types.

#### 2.1. Volumetric Attack

A Volumetric Attack is a type that sends a large volume of traffic to a specific server or service to cause a failure. It causes network failures due to traffic load, or server failures by imposing server load. Most DDoS attack techniques fall under the Volumetric type. The following Volumetric-type techniques exist.

* HTTP Flood
* DNS Flood
* DNS Amplification
* Smurf Attack

#### 2.2. Protocol Attack

A Protocol Attack uses protocols to put a server into a resource shortage state and cause a failure. The following Protocol Attacks exist.

* SYN Flood
* DNS Flood
* DNS Amplification
* Smurf Attack

#### 2.3. Application Layer Attack

An Application Layer Attack uses application layer protocols to impose load on a specific server or service and cause a failure.

* HTTP Flood

## 3. DDoS Attack Techniques

#### 3.1. SYN Flood

SYN Flood is an attack technique that exploits SYN packets used during the TCP protocol's 3-way handshake. According to the TCP 3-way handshake, after a server receives a SYN packet, it sends a SYN+ACK packet to the client and then waits for an ACK packet from the client. This waiting state, where the TCP connection is only half established, is called a **half-open connection**.

A server consumes resources related to TCP connections to maintain half-open connections. Therefore, when too many half-open TCP connections accumulate on a server, the server can no longer establish new TCP connections.

SYN Flood is an attack technique that exploits this weakness. The attacker sends SYN packets to the server with the source IP changed to an invalid IP. After receiving the SYN packet, the server sends a SYN+ACK packet to the source IP in the SYN packet, but because the IP is invalid, the server does not receive an ACK packet and remains waiting for an ACK. If the attacker sends many SYN packets with varied source IPs, the server's TCP connection-related resources are exhausted, and the server fails because it can no longer establish new TCP connections.

Because TCP is an L4 protocol, an L4-based firewall can block SYN packets to protect against SYN Flood attacks. There are also methods to prepare for SYN Flood by changing or adding server settings to increase the maximum number of TCP connection-related resources, or to configure reuse of old half-open TCP connections, thereby preventing exhaustion of the server's TCP connection-related resources.

#### 3.2. HTTP Flood

HTTP Flood is an attack technique that uses the HTTP protocol to send many requests to a specific server or service. In general, an L7-based firewall that can detect each HTTP protocol request can be used to protect against the attack. Because the HTTP Keep-Alive protocol makes it possible to send many requests within a single TCP connection, an L4-based firewall cannot block HTTP Flood.

#### 3.3. DNS Flood

DNS Flood is an attack technique that sends excessive requests to a specific DNS server to cause a DNS server failure. Because most IP communication uses a DNS server, a DNS server failure has a very wide impact.

#### 3.4. DNS Amplification

DNS Amplification is an attack technique that exploits vulnerabilities in the DNS query protocol. The attacker uses spoofing to send DNS queries with the attack target server's IP as the source IP to many DNS servers. DNS servers that receive the DNS query send DNS replies to the attack target server based on the source IP set in the DNS query to the attack target server's IP. The attacker sends many DNS queries to DNS servers so that the attack target server receives many DNS replies from DNS servers and fails.

When performing DNS Amplification, attackers generally send ANY-type DNS queries to DNS servers. ANY-type DNS queries cause the DNS server to return all records for a specific domain, so DNS replies are generally very large. Although the DNS query size is not large, DNS reply size becomes much larger when ANY type is used, which is why the name DNS Amplification is used.

When performing a DNS query, DNS does not perform a separate authentication or authorization process, so from the DNS server's perspective it is difficult to distinguish whether a received DNS query is legitimate or intended for an attack. Also, because DNS queries can be requested over UDP, IP spoofing is easy to perform.

#### 3.5. Smurf Attack

Smurf Attack is an attack technique that exploits vulnerabilities in the ICMP protocol. In the ICMP protocol, when a client sends an Echo Request to a server, the server immediately responds with an Echo Reply. Because there is no separate handshake in this Echo Request/Reply process, Smurf Attack exploits this weakness.

The attacker uses IP spoofing to send an ICMP Echo Request packet to a router with the attack target server's IP as the source IP and a broadcast IP as the destination IP. Because the destination is a broadcast IP, the router sends the ICMP Echo Request packet to all PCs on a specific network. All PCs that receive the Echo Request packet with the attack target server's IP as the source IP send a Reply packet to the attack target server according to the ICMP protocol. Therefore, the attack target server receives Echo Reply responses from an unspecified large number of PCs even though it did not request them, causing a failure.

Because the ICMP protocol is an L3 protocol, an L3-based firewall can be used to protect against the attack. There is also a method to prevent Smurf Attack by disabling the router's broadcasting feature.

## 4. References

* [https://www.akamai.com/ko/our-thinking/ddos](https://www.akamai.com/ko/our-thinking/ddos)
* [https://www.imperva.com/learn/ddos/ddos-attacks/](https://www.imperva.com/learn/ddos/ddos-attacks/)
* [https://www.onelogin.com/learn/ddos-attack](https://www.onelogin.com/learn/ddos-attack)
* [https://cybersecurity.att.com/blogs/security-essentials/types-of-ddos-attacks-explained](https://cybersecurity.att.com/blogs/security-essentials/types-of-ddos-attacks-explained)
* SYN Flood : [https://www.cloudflare.com/learning/ddos/syn-flood-ddos-attack/](https://www.cloudflare.com/learning/ddos/syn-flood-ddos-attack/)
* DNS Flood : [https://www.cloudflare.com/learning/ddos/dns-flood-ddos-attack/](https://www.cloudflare.com/learning/ddos/dns-flood-ddos-attack/)
* DNS Amplification : [https://www.cloudflare.com/learning/ddos/dns-amplification-ddos-attack/](https://www.cloudflare.com/learning/ddos/dns-amplification-ddos-attack/)
* DNS Amplification : [https://www.geeksforgeeks.org/what-is-a-dns-amplification-attack/](https://www.geeksforgeeks.org/what-is-a-dns-amplification-attack/)
* Smurf Attack : [https://www.cloudflare.com/learning/ddos/smurf-ddos-attack/](https://www.cloudflare.com/learning/ddos/smurf-ddos-attack/)

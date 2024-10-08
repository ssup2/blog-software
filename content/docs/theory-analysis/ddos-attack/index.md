---
title: DDoS Attack
---

DDoS (Distributed Denial-of-Service) Attack을 정리한다.

## 1. DDoS (Distributed Denial-of-Service) Attack

DDoS Attack은 특정 Server/Service에 비정상적인 Traffic을 전송하여 Server/Service의 장애를 유발하는 모든 공격을 의미한다. 여러 기법의 DDoS Attack이 존재하며, 대부분의 DDoS Attack 기법의 공격자는 Server/Service에 접근 가능한 불특정 다수가 될수 있다는 특징을 가지고 있다. 따라서 Public Network로 노출되는 Server/Service의 경우에는 반드시 DDoS Attack에 대비해야 한다.

## 2. DDoS Attack Type

DDoS Attack은 특성에 따라서 Volumetric Attack, Protocol Attack, Application Layer Attack Type으로 구분할 수 있으며, 하나의 DDoS Attack 기법이 여러 Type에 포함될 수도 있다.

#### 2.1. Volumetric Attack

Volumetric Attack은 대용량의 Traffic을 특정 Server/Service에게 전송하여 특정 Server/Service의 장애를 유발하는 Type을 의미한다. Traffic 부하로 인해서 Network 장애를 유발시키거나, Server 부하를 발생시켜 Server 장애를 유발시킨다. 대부분의 DDoS Attack 기법이 Volumetric Type에 해당한다. 다음과 같은 Volumetric Type 기법들이 존재한다.

* HTTP Flood
* DNS Flood
* DNS Amplification
* Smurf Attack

#### 2.2. Protocol Attack

Procotol Attack은 Protocol을 활용하여 Server를 Resource 부족 상태로 만들어 장애를 유발시킨다. 다음과 같은 Procotol Attack이 존재한다.

* Sync Flood
* DNS Flood
* DNS Amplification
* Smurf Attack

#### 2.3. Application Layer Attack

Application Layer Attack은 Application Layer Protocol을 활용하여 특정 Server/Service의 부하를 발생시켜 장애를 유발시킨다.

* HTTP Flood

## 3. DDoS Attack 기법

#### 3.1. Sync Flood

Sync Flood는 TCP Protocol의 3-Way Handshake시 이용하는 Sync Packet을 활용한 공격 기법이다. TCP 3-Way Handshake에 의해서 Sync Packet을 받은 Server는 Sync + ACK Packet을 Client에 전송한 이후에 Client로부터 전송되는 ACK Packet을 대기하게 된다. 이러한 대기 상태를 TCP Connection이 반만 맺어었다고 하여 **Half-open Connection** 상태라고 지칭한다.

Server는 Half-open Connection 상태의 TCP Connection을 유지하기 위해서 TCP Connection 관련 자원을 소비한다. 따라서 Half-open Connection 상태의 TCP Connection이 Server에 너무 많이 누적되는 경우 Server는 더이상 새로운 TCP Connection을 맺을 수 없게된다.

Sync Flood는 이러한 약점을 이용하는 공격 기법이다. 공격자는 Server에게 전송하는 Sync Packet의 Source IP를 유효하지 않는 IP로 변경하여 전송한다. Server는 Sync Packet 수신한 이후에 Sync Packet의 Source IP를 대상으로 Sync + ACK Packet을 전송하지만 유효하지 않는 IP이기 때문에 Server는 ACK Packet을 받지 못하고 ACK Packet을 계속 대기하는 상태가 된다. 공격자가 다수의 Source IP가 변경된 Sync Packet을 보낸다면 Server의 TCP Connection 관련 자원은 고갈되고, Server는 새로운 TCP Connection을 맺을수 없으면서 장애가 발생한다.

TCP는 L4 Protocol이기 때문에 L4 기반의 Firewall을 통해서 Sync Packet을 차단하여 Sync Flood 공격으로부터 보호할 수 있다. 또한 Server의 설정을 변경/추가하여 최대 TCP Connection 관련 자원의 개수를 늘리거나 오래된 Half-open 상태의 TCP Connection을 재활용 할 수 있도록 설정하여, Server의 TCP Connection 관련 자원의 고갈을 막아 Sync Flood 공격을 대비하는 방법도 존재한다.

#### 3.2. HTTP Flood

HTTP Flood는 HTTP Procotol을 활용하여 특정 Server/Service에게 다수의 요청을 전송하는 공격 기법이다. 일반적으로 HTTP Protocol의 각 요청을 탐지할 수 있는 L7 기반의 Firewall을 활용하여 공격으로부터 보호할 수 있다. HTTP Keepalived Protocol을 이용하면 하나의 TCP Connection 내부에서 다수의 요청을 전송하는 것이 가능하기 때문에, L4 기반의 Firewall을 활용해서는 HTTP Flood를 막을 수 없다.

#### 3.3. DNS Flood

DNS Flood는 특정 DNS Server에게 과도한 요청을 전송하여 DNS Server 장애를 유발시키는 공격 기법이다. IP 통신을 이용하는 대부분의 경우에는 DNS Server를 이용하기 때문에, DNS Server 장애는 장애 영향의 범위가 매우 넓은 장애이다.

#### 3.4. DNS Amplification

DNS Amplification은 DNS Query Protocol의 취약점을 이용한 공격 기법이다. 공격자는 Spoofing을 통해서 공격 대상 Server의 IP를 Source IP로 갖는 DNS Query를 다수의 DNS Server로 전송한다. DNS Query를 받은 DNS Server는 DNS Query의 공격 대상 Server의 IP로 설정된 Source IP를 보고 공격 대상 Server에게 DNS Reply를 전송한다. 공격자는 다수의 DNS Query를 DNS Server에 전송하여 공격 대상 Server는 DNS Server로부터 많은 DNS Reply를 받게 만들어 장애를 유발시킨다.

DNS Amplification 수행시 공격자는 일반적으로 ANY Type의 DNS Query를 DNS Server에게 전송한다. ANY Type의 DNS Query는 DNS Server가 가지고 있는 특정 Domain의 모든 Record를 전송하기 때문에 DNS Reply의 크기는 일반적으로 매우 큰 크기를 갖기 때문이다. DNS Query의 크기는 크지 않지만 ANY Type을 활용한 DNS Reply의 크기는 훨씬 커지기 때문에 DNS Amplification이라는 명칭이 붙었다.

DNS Query 수행시 DNS는 별도의 인증/인가 과정을 수행하지 않기 때문에 DNS Server 입장에서는 수신한 DNS Query가 정상적인 Query인지 공격을 위한 Query인지 구분하기 어렵다. 또한 DNS Query를 UDP로도 요청할 수 있기 때문에 IP Spoofing도 쉽게 수행이 가능하다.

#### 3.5. Smurf Attack

Smurf Attack은 ICMP Protocol의 취약점을 이용한 공격 기법이다. ICMP Protocol에서 Client가 Echo Request 요청을 Server에게 전송하면 Server는 Echo Reply로 바로 응답한다. 이러한 Echo Request/Reply 과정에 별도의 Handshake 과정이 없기 때문에 Smurf Attack은 이러한 위약점을 이용하여 공격한다.

공격자는 IP Spoofing을 통해서 공격 대상 Server의 IP를 Source IP로 갖고 Broadcast IP를 Destination IP로 갖는 ICMP Echo Request Packet을 Router에게 전송한다. Router는 Destination이 Broadcast IP이기 때문에 특정 Network의 모든 PC에게 ICMP Echo Request Packet을 전송한다. Source IP가 공격 대상 Server인 Echo Request Packet을 받은 모든 PC는 ICMP Protocol에 의해서 Replay Packet을 공격 대상 Server로 전송한다. 따라서 공격 대상 Server는 자신이 요청하지도 않은 Echo Reply 응답을 불특정 다수의 PC로부터 받게되며 장애를 유발하게 된다.

ICMP Protocol은 L3 Protocol이기 때문에 L3 기반의 Firewall을 활용하여 공격으로부터 보호할 수 있다. Router의 Broadcasting 기능을 꺼서 Smurf Attack을 방지하는 방법도 존재한다.

## 4. 참조

* [https://www.akamai.com/ko/our-thinking/ddos](https://www.akamai.com/ko/our-thinking/ddos)
* [https://www.imperva.com/learn/ddos/ddos-attacks/](https://www.imperva.com/learn/ddos/ddos-attacks/]
* [https://www.onelogin.com/learn/ddos-attack](https://www.onelogin.com/learn/ddos-attack)
* [https://cybersecurity.att.com/blogs/security-essentials/types-of-ddos-attacks-explained](https://cybersecurity.att.com/blogs/security-essentials/types-of-ddos-attacks-explained)
* Sync Flood : [https://www.cloudflare.com/learning/ddos/syn-flood-ddos-attack/](https://www.cloudflare.com/learning/ddos/syn-flood-ddos-attack/)
* DNS Flood : [https://www.cloudflare.com/learning/ddos/dns-flood-ddos-attack/](https://www.cloudflare.com/learning/ddos/dns-flood-ddos-attack/)
* DNS Amplification : [https://www.cloudflare.com/learning/ddos/dns-amplification-ddos-attack/](https://www.cloudflare.com/learning/ddos/dns-amplification-ddos-attack/)
* DNS Amplification : [https://www.geeksforgeeks.org/what-is-a-dns-amplification-attack/](https://www.geeksforgeeks.org/what-is-a-dns-amplification-attack/)
* Smurf Attack : [https://www.cloudflare.com/learning/ddos/smurf-ddos-attack/](https://www.cloudflare.com/learning/ddos/smurf-ddos-attack/)
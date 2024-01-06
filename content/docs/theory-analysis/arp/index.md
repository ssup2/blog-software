---
title: Address Resolution Protocol (ARP)
---

## 1. Address Resolution Protocol (ARP)

ARP는 뜻 그대로 주소를 알아내기 위한 Protocol이다. 네트워크 프로그래밍시 대부분의 경우 Data를 보내려는 목적지의 IP 주소만을 이용할뿐 MAC 주소를 이용하지 않는다. IP는 네트워크 주소 체계를 유연하게 관리하기 위한 논리적 주소이고, MAC 주소는 실제 NIC 카드가 인지하는 물리적 주소이다. 따라서 IP 주소만 가지고는 네트워크 통신을 할 수 없다. **ARP는 IP같은 논리 주소를 가지고 MAC같은 물리 주소를 알아내기 위한 Protocol이다.**

### 1.1. Flow

{{< figure caption="[Figure 1] ARP Flow" src="images/arp-flow.png" width="900px" >}}

[Figure 1]은 ARP Packet의 흐름을 나타내고 있다. **ARP Request**시 자신의 물리적 주소와 논리적 주소를 각각 Source Hardware Address, Source Protocol Address에 채운다. 그리고 물리적 주소를 알아내기 위한 Target의 논리적 주소를 Target Protocol Address에 채운다. 그 후 ARP Packet를 Broadcasting한다.

ARP Packet을 받은 Host는 자신의 논리적 주소가 Target protocol address와 동일한 경우 **ARP Replay**를 전송한다. 자신의 물리적 주소와 논리적 주소를 각각 Source Hardware Address, Source Protocol Address에 채운다. 그리고 ARP Request Packet의 Source Hardware Address, Source Protocol Address를 각각 Target Hardware Address, Target Protocol Address에 채워 Unicast한다.

### 1.2. ARP Packet

{{< figure caption="[Figure 2] ARP Packet" src="images/arp-packet.png" width="900px" >}}

[Figure 2]는 Ethernet 환경에서의 ARP Packet을 나타내고 있다. Operation Code는 ARP Request시 1이 되고 ARP Reply의 경우 2가 된다. ARP Request Packet은 Broadcast되야 하기 때문에 Ethernet Header의 **Destination Address는 FF:FF:FF:FF:FF:FF**가 된다.

### 1.3. ARP Caching, Table

```shell {caption="[Shell 1] ARP Table 확인"}
$ arp
Address                  HWtype  HWaddress           Flags Mask            Iface
192.168.0.1              ether   90:9f:33:b2:ef:08   C                     eth0
192.168.0.4              ether   1c:23:2c:8c:6c:99   C                     eth0
```

Data를 전송할때마다 ARP를 이용하여 주소를 알아낸다면 네트워크에는 수많은 ARP Packet이 발생하고 많은 전송 Overhead도 발생하게 된다. 따라서 각 Host는 ARP로 알아낸 MAC 주소를 Caching하여 관리한다. 리눅스에서는 arp 명령어를 통해서 리눅스가 관리하는 ARP Table을 볼 수 있다. [Shell 1]에서는 arp 명령어로 ARP Table을 확인하는 과정을 있다. [Shell 1]의 ARP Table에서는 192.168.0.1은 90:9f:33:b2:ef:08에 Mapping되어 있고, 192.168.0.4는 1c:23:2c:8c:6c:99에 Mapping되어 있는걸 확인 할 수 있다.

## 2. 참조

* [https://www.slideshare.net/naveenarvinth/arp-36193303](https://www.slideshare.net/naveenarvinth/arp-36193303)

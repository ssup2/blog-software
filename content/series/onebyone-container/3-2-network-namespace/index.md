---
title: 3.2. Network Namespace
---

## Network Namespace

```console {caption="[Shell 1] netshoot-a Container Network", linenos=table}
# netshoot-a Container를 Daemon으로 실행하고 exec을 통해서 netshoot-a Container에 bash Process를 실행
(host)# docker run -d --rm --privileged --name netshoot-a nicolaka/netshoot sleep infinity
(host)# docker exec -it netshoot-a bash

# netshoot-a Container의 Interface 확인
(netshoot-a)# ip a
1: lo: <LOOPBACK,UP,LOWER-UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid-lft forever preferred-lft forever
13: eth0@if14: <BROADCAST,MULTICAST,UP,LOWER-UP> mtu 1500 qdisc noqueue state UP group default
    link/ether 02:42:ac:11:00:04 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 172.17.0.4/16 brd 172.17.255.255 scope global eth0
       valid-lft forever preferred-lft forever

# netshoot-a Container에 임의의 Routing Rule을 추가한 다음 Routing Table 확인
(netshoot-a)# route add -host 8.8.8.8 dev eth0
(netshoot-a)# route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         172.17.0.1      0.0.0.0         UG    0      0        0 eth0
8.8.8.8         0.0.0.0         255.255.255.255 UH    0      0        0 eth0
172.17.0.0      0.0.0.0         255.255.0.0     U     0      0        0 eth0
```

```console {caption="[Shell 2] netshoot-b Container Network", linenos=table}
# netshoot-b Container를 Daemon으로 실행하고 exec을 통해서 netshoot-b Container에 bash Process를 실행
(host)# docker run -d --rm --privileged --name netshoot-b nicolaka/netshoot sleep infinity
(host)# docker exec -it netshoot-b bash

# netshoot-b Container의 Interface 확인
(netshoot-b)# ip a
1: lo: <LOOPBACK,UP,LOWER-UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid-lft forever preferred-lft forever
15: eth0@if16: <BROADCAST,MULTICAST,UP,LOWER-UP> mtu 1500 qdisc noqueue state UP group default
    link/ether 02:42:ac:11:00:03 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 172.17.0.3/16 brd 172.17.255.255 scope global eth0
       valid-lft forever preferred-lft forever

# netshoot-b Container의 Routing Table 확인
(netshoot-b)# route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         172.17.0.1      0.0.0.0         UG    0      0        0 eth0
172.17.0.0      0.0.0.0         255.255.0.0     U     0      0        0 eth0
```

Network 격리를 담당하는 Network Namespace를 알아본다. [Shell 1,2]는 각 Netshoot Container 내부에서 Network Interface 조회 및 Routing Table 조작 및 조회를 하는 과정을 나타내고 있다. Netshoot은 대부분의 Network Tool이 포함된 Container Image이다. netshoot-a Container와 netshoot-b Container가 다른 IP를 갖고 있는것을 확인할 수 있다. 또한 netshoot-a Container에서 IP "8.8.8.8" 관련 Routing Rule을 추가하였지만 netshoot-b Container에서는 관련 Routing Rule을 확인할 수 없는것을 알 수 있다.

```console {caption="[Shell 3] Host Network", linenos=table}
# Host의 Interface 확인
(netshoot-b)# ip a
...
2: eth0: <BROADCAST,MULTICAST,UP,LOWER-UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether 00:15:5d:00:05:14 brd ff:ff:ff:ff:ff:ff
    inet 192.168.0.39/24 brd 192.168.0.255 scope global eth0
       valid-lft forever preferred-lft forever
    inet6 fe80::215:5dff:fe00:514/64 scope link
       valid-lft forever preferred-lft forever
...
14: veth08fe05e@if13: <BROADCAST,MULTICAST,UP,LOWER-UP> mtu 1500 qdisc noqueue master docker0 state UP group default
    link/ether 02:3f:d4:ad:44:d4 brd ff:ff:ff:ff:ff:ff link-netnsid 2
    inet6 fe80::3f:d4ff:fead:44d4/64 scope link
       valid-lft forever preferred-lft forever
16: veth24ee3c6@if15: <BROADCAST,MULTICAST,UP,LOWER-UP> mtu 1500 qdisc noqueue master docker0 state UP group default
    link/ether 1a:fa:71:c8:7b:a1 brd ff:ff:ff:ff:ff:ff link-netnsid 1
    inet6 fe80::18fa:71ff:fec8:7ba1/64 scope link
       valid-lft forever preferred-lft forever

# Host의 Routing Table 확인
(netshoot-b)# route -n        
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         192.168.0.1     0.0.0.0         UG    0      0        0 eth0
192.168.0.0     0.0.0.0         255.255.255.0   U     0      0        0 eth0
```

[Shell 3]은 netshoot-a, netshoot-b Container를 생성한 다음 Host에서 보이는 Network Interface 조회 및 Routing Table 조회를 하는 과정을 나타내고 있다. IP가 완전히 다른 eth0 Interface가 있는것을 확인할 수 있으며, Netshoot Container들과는 완전히 다른 Routing Table을 갖고 있는것을 확인할 수 있다. 각 Container와 Host가 각각 다른 Network 정보를 갖을수 있는 이유는 Network Namespace 때문이다.

{{< figure caption="[Figure 1] Network Namespace" src="images/network-namespace.png" width="700px" >}}

Network Namespace는 의미 그대로 Network 관련 설정, 상태를 격리하는 Namespace이다. [Figure 1]은 Host가 이용하는 Host Network Namespace, netshoot-a Container가 이용하는 netshoot-a Network Namespace, netshoot-b Container가 이용하는 netshoot-b Network Namespace, 3개의 Network Namespace를 나타내고 있다.

각 Network Namespace는 독립적으로 Routing Table, Socket, Netfilter 등 Network 관련 설정을 갖을수 있다. 따라서 각 Container 및 Host는 [Shell 1~3]에서 확인 했던것 처럼 별도의 Routing Table을 갖을수 있다. 또한 Socket도 격리되어 있기 때문에 각 Container 및 Host안에서 동일한 Port를 이용하는 Server도 동시에 구동할 수 있다. Netfilter도 격리 되어있기 때문에 Netfilter 기반으로 동작하는 iptables, IPVS 설정도 Container별로 다르게 설정할 수 있다.

Network Namespace 사이는 기본적으로 격리되어 있지만, 필요에 따라서 Network Namespace 사이의 통신이 필요한 경우가 있다. 이런경우 **veth** Device라고 불리는 Virtual Network Device를 이용하여 Network Namespace 사이를 연결한다. [Figure 1]에서 Host Network Namespace와 Container Network Namespace 사이에 veth Device를 통해서 연결할 것을 확인할 수 있다. veth Device는 생성시 반드시 2개의 Interface가 생성되며 각 Interface를 연결할 Network Namespace에 각각 설정하면 된다.

```console {caption="[Shell 4] nginx Container와 Host 사이에서 veth Device 설정 및 통신 확인", linenos=table}
# Network 설정없이 특권 권한으로 nginx Container 생성
(host)# docker run -d --privileged --network none --rm --name nginx nginx:1.16.1

# veth Device 생성 및 확인
(host)# ip link add veth-host type veth peer name veth-cont
(host)# ip a
...
19: veth-cont@veth-host: <BROADCAST,MULTICAST,M-DOWN> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether 72:24:b2:1a:9b:94 brd ff:ff:ff:ff:ff:ff
20: veth-host@veth-cont: <BROADCAST,MULTICAST,M-DOWN> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether 3a:7d:9a:79:9a:51 brd ff:ff:ff:ff:ff:ff

# veth-cont Interface를 nginx container로 전달
(host)# ip link set veth-cont netns $(docker inspect -f '{% raw %}{{.State.Pid}}{% endraw %}' nginx)

# nginx Container에서 veth-cont Interface 확인
(host)# docker exec -it nginx bash
(nginx)# apt-get update && apt-get install procps iproute2 -y
(nginx)# ip a
...
19: veth-cont@if20: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether 72:24:b2:1a:9b:94 brd ff:ff:ff:ff:ff:ff link-netnsid 0

# nginx Container에서 veth-cont Interface 및 Routing Table 설정
(nginx)# ip link set dev veth-cont up
(nginx)# ip addr add 193.168.0.101/24 dev veth-cont
(nginx)# ip a
...
19: veth-cont@if20: <BROADCAST,MULTICAST,UP,LOWER-UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether 72:24:b2:1a:9b:94 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 193.168.0.101/24 scope global veth-cont
       valid-lft forever preferred-lft forever
(nginx)# ip route
...
193.168.0.0/24 dev veth-cont proto kernel scope link src 193.168.0.101
(nginx)# exit

# Host에서 veth-host Interface 및 Routing Table 설정
(host)# ip link set dev veth-host up
(host)# ip addr add 193.168.0.100/24 dev veth-host
(host)# ip a
...
20: veth-host@if19: <BROADCAST,MULTICAST,UP,LOWER-UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether 3a:7d:9a:79:9a:51 brd ff:ff:ff:ff:ff:ff link-netnsid 3
    inet 193.168.0.100/24 scope global veth-host
       valid-lft forever preferred-lft forever
    inet6 fe80::387d:9aff:fe79:9a51/64 scope link
       valid-lft forever preferred-lft forever
(host)# ip route
...
193.168.0.0/24 dev veth-host proto kernel scope link src 193.168.0.100

# Host에서 설정한 veth Device를 통해서 nginx Container에게 요청 및 응답 확인
(host)# curl 193.168.0.101
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
```

{{< figure caption="[Figure 2] veth Device Setting" src="images/veth-device-setting.png" width="600px" >}}

[Shell 4]는 ip 명령어를 이용하여 veth Device를 생성하고, 생성한 veth Device를 이용하여 Host Network Namespace와 nginx Container Network Namespace 사이를 연결하고, 마지막으로 연결된 veth를 통해서 Host에서 Container로 직접 통신하는 과정을 나타내고 있다. [Shell 3]을 통해서 Host와 nginx Container는 193.168.0.0/24 Network로 연결되며 서로 통신할 수 있게 된다. [Figure 2]는 [Shell 4]를 통해서 설정된 veth Device 및 Routing Table을 나타내고 있다.

## Network Namespace 공유

```console {caption="[Shell 5] Host Network Namespace를 이용하는 netshoot Container에서 Interface 확인", linenos=table}
# Host에서 Interface 확인
(host)# ip a
1: lo: <LOOPBACK,UP,LOWER-UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid-lft forever preferred-lft forever
    inet6 ::1/128 scope host
       valid-lft forever preferred-lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER-UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether 00:15:5d:00:05:14 brd ff:ff:ff:ff:ff:ff
    inet 192.168.0.39/24 brd 192.168.0.255 scope global eth0
       valid-lft forever preferred-lft forever
    inet6 fe80::215:5dff:fe00:514/64 scope link
       valid-lft forever preferred-lft forever
...

# Host Network Namespace를 이용하는 netshoot Container를 생성
(host)# docker run -d --net host --rm --name netshoot nicolaka/netshoot bash

# netshoot Container에서 Interface 확인
(netshoot)# ip a
1: lo: <LOOPBACK,UP,LOWER-UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid-lft forever preferred-lft forever
    inet6 ::1/128 scope host
       valid-lft forever preferred-lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER-UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether 00:15:5d:00:05:14 brd ff:ff:ff:ff:ff:ff
    inet 192.168.0.39/24 brd 192.168.0.255 scope global eth0
       valid-lft forever preferred-lft forever
    inet6 fe80::215:5dff:fe00:514/64 scope link
       valid-lft forever preferred-lft forever
...
```

하나의 Network Namespace를 다수의 Container 또는 Container와 Host가 공유하여 이용할 수도 있다. [Shell 5]는 netshoot Container를 Host Network Namespace를 이용하도록 설정하는 방법을 나타내고 있다. netshoot Container는 Host Network Namespace를 이용하기 때문에 Host에서 보이는 Network Interface 정보와 netshoot Container에서 보이는 Network Interface 정보가 동일할 것을 확인할 수 있다. Container가 자신의 전용 Network Namespace가 아닌 Host의 Network Namespace를 이용하면 Container Packet은 veth Device를 통과하지 않고 바로 Host 외부로 전송이 가능하기 때문에 Network 성능 이점을 얻을 수 있다.

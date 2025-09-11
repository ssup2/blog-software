---
title: 3.2. Network Namespace
---

## Network Namespace

```console {caption="[Shell 1] netshoot-a Container Network", linenos=table}
# Run netshoot-a Container as Daemon and execute bash Process in netshoot-a Container through exec
(host)# docker run -d --rm --privileged --name netshoot-a nicolaka/netshoot sleep infinity
(host)# docker exec -it netshoot-a bash

# Check netshoot-a Container Interface
(netshoot-a)# ip a
1: lo: <LOOPBACK,UP,LOWER-UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid-lft forever preferred-lft forever
13: eth0@if14: <BROADCAST,MULTICAST,UP,LOWER-UP> mtu 1500 qdisc noqueue state UP group default
    link/ether 02:42:ac:11:00:04 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 172.17.0.4/16 brd 172.17.255.255 scope global eth0
       valid-lft forever preferred-lft forever

# Add arbitrary Routing Rule to netshoot-a Container and check Routing Table
(netshoot-a)# route add -host 8.8.8.8 dev eth0
(netshoot-a)# route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         172.17.0.1      0.0.0.0         UG    0      0        0 eth0
8.8.8.8         0.0.0.0         255.255.255.255 UH    0      0        0 eth0
172.17.0.0      0.0.0.0         255.255.0.0     U     0      0        0 eth0
```

```console {caption="[Shell 2] netshoot-b Container Network", linenos=table}
# Run netshoot-b Container as Daemon and execute bash Process in netshoot-b Container through exec
(host)# docker run -d --rm --privileged --name netshoot-b nicolaka/netshoot sleep infinity
(host)# docker exec -it netshoot-b bash

# Check netshoot-b Container Interface
(netshoot-b)# ip a
1: lo: <LOOPBACK,UP,LOWER-UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid-lft forever preferred-lft forever
15: eth0@if16: <BROADCAST,MULTICAST,UP,LOWER-UP> mtu 1500 qdisc noqueue state UP group default
    link/ether 02:42:ac:11:00:03 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 172.17.0.3/16 brd 172.17.255.255 scope global eth0
       valid-lft forever preferred-lft forever

# Check netshoot-b Container Routing Table
(netshoot-b)# route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         172.17.0.1      0.0.0.0         UG    0      0        0 eth0
172.17.0.0      0.0.0.0         255.255.0.0     U     0      0        0 eth0
```

Let's look at Network Namespace, which is responsible for network isolation. [Shell 1,2] show the process of querying network interfaces and manipulating and querying routing tables inside each Netshoot Container. Netshoot is a container image that includes most network tools. You can see that netshoot-a Container and netshoot-b Container have different IPs. Also, you can see that while a routing rule related to IP "8.8.8.8" was added in netshoot-a Container, no related routing rule can be found in netshoot-b Container.

```console {caption="[Shell 3] Host Network", linenos=table}
# Check Host Interface
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

# Check Host Routing Table
(netshoot-b)# route -n        
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         192.168.0.1     0.0.0.0         UG    0      0        0 eth0
192.168.0.0     0.0.0.0         255.255.255.0   U     0      0        0 eth0
```

[Shell 3] shows the process of creating netshoot-a and netshoot-b Containers and then querying network interfaces and routing tables visible from the Host. You can see that there is an eth0 interface with a completely different IP, and you can see that it has a completely different routing table from the Netshoot Containers. The reason why each container and host can have different network information is because of Network Namespace.

{{< figure caption="[Figure 1] Network Namespace" src="images/network-namespace.png" width="700px" >}}

Network Namespace literally means a Namespace that isolates network-related settings and states. [Figure 1] shows three Network Namespaces: the Host Network Namespace used by the Host, the netshoot-a Network Namespace used by netshoot-a Container, and the netshoot-b Network Namespace used by netshoot-b Container.

Each Network Namespace can independently have network-related settings such as routing tables, sockets, and netfilter. Therefore, each container and host can have separate routing tables as confirmed in [Shell 1~3]. Also, since sockets are isolated, servers using the same port can run simultaneously inside each container and host. Since netfilter is also isolated, iptables and IPVS settings that operate based on netfilter can also be set differently for each container.

Network Namespaces are basically isolated from each other, but there are cases where communication between Network Namespaces is necessary. In such cases, Network Namespaces are connected using a Virtual Network Device called **veth** Device. In [Figure 1], you can see that the Host Network Namespace and Container Network Namespace are connected through veth Device. When creating a veth Device, two interfaces must be created, and each interface should be set to the Network Namespace to which it will be connected.

```console {caption="[Shell 4] veth Device Setup and Communication Check between nginx Container and Host", linenos=table}
# Create nginx Container with privileged permissions without network setup
(host)# docker run -d --privileged --network none --rm --name nginx nginx:1.16.1

# Create and check veth Device
(host)# ip link add veth-host type veth peer name veth-cont
(host)# ip a
...
19: veth-cont@veth-host: <BROADCAST,MULTICAST,M-DOWN> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether 72:24:b2:1a:9b:94 brd ff:ff:ff:ff:ff:ff
20: veth-host@veth-cont: <BROADCAST,MULTICAST,M-DOWN> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether 3a:7d:9a:79:9a:51 brd ff:ff:ff:ff:ff:ff

# Pass veth-cont Interface to nginx container
(host)# ip link set veth-cont netns $(docker inspect -f '{% raw %}{{.State.Pid}}{% endraw %}' nginx)

# Check veth-cont Interface in nginx Container
(host)# docker exec -it nginx bash
(nginx)# apt-get update && apt-get install procps iproute2 -y
(nginx)# ip a
...
19: veth-cont@if20: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether 72:24:b2:1a:9b:94 brd ff:ff:ff:ff:ff:ff link-netnsid 0

# Set veth-cont Interface and Routing Table in nginx Container
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

# Set veth-host Interface and Routing Table in Host
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

# Check request and response to nginx Container through veth Device set in Host
(host)# curl 193.168.0.101
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
```

{{< figure caption="[Figure 2] veth Device Setting" src="images/veth-device-setting.png" width="600px" >}}

[Shell 4] shows the process of creating a veth Device using the ip command, connecting the Host Network Namespace and nginx Container Network Namespace using the created veth Device, and finally communicating directly from Host to Container through the connected veth. Through [Shell 3], the Host and nginx Container are connected to the 193.168.0.0/24 network and can communicate with each other. [Figure 2] shows the veth Device and routing table set up through [Shell 4].

## Network Namespace Sharing

```console {caption="[Shell 5] Interface Check in netshoot Container using Host Network Namespace", linenos=table}
# Check Interface in Host
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

# Create netshoot Container using Host Network Namespace
(host)# docker run -d --net host --rm --name netshoot nicolaka/netshoot bash

# Check Interface in netshoot Container
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

One Network Namespace can also be shared and used by multiple containers or containers and hosts. [Shell 5] shows how to set up a netshoot Container to use the Host Network Namespace. Since the netshoot Container uses the Host Network Namespace, you can see that the network interface information visible from the Host and the network interface information visible from the netshoot Container are identical. When a container uses the Host's Network Namespace instead of its own dedicated Network Namespace, container packets can be sent directly to the outside of the Host without passing through veth Device, so network performance benefits can be obtained.

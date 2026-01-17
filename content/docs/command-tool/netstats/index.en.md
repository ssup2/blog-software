---
title: netstat
---

This document summarizes the usage of `netstat`, which displays network statistics.

## 1. netstat

### 1.1. netstat

```shell {caption="[Shell 1] netstat"}
$ netstat 
Active Internet connections (w/o servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State
tcp        0      0 node09:9100             node09:50588            TIME_WAIT
tcp        0      0 node09:9198             node09:56430            TIME_WAIT
tcp        0      0 node09:54584            10.0.0.20:mysql         ESTABLISHED
tcp        0      0 node09:41364            192.168.0.40:8776       TIME_WAIT
tcp        0      0 node09:ssh              10.0.0.10:6791          ESTABLISHED
tcp        0      0 node09:54360            10.0.0.20:mysql         ESTABLISHED
tcp        0      0 node09:9091             node09:60262            TIME_WAIT
tcp        0    164 node09:ssh              10.0.0.10:9385          ESTABLISHED
tcp6       0      0 node09:18080            node09:49642            TIME_WAIT
Active UNIX domain sockets (w/o servers)
Proto RefCnt Flags       Type       State         I-Node   Path
unix  2      [ ]         DGRAM                    32031    /run/chrony/chronyd.sock
unix  3      [ ]         DGRAM                    14031    /run/systemd/notify
unix  2      [ ]         DGRAM                    14048    /run/systemd/journal/syslog
unix  9      [ ]         DGRAM                    14054    /run/systemd/journal/socket
unix  8      [ ]         DGRAM                    14464    /run/systemd/journal/dev-log
unix  3      [ ]         STREAM     CONNECTED     20158
unix  3      [ ]         STREAM     CONNECTED     21786    /var/run/dbus/system_bus_socket
unix  3      [ ]         STREAM     CONNECTED     20999
unix  2      [ ]         DGRAM                    683751
unix  3      [ ]         STREAM     CONNECTED     27046
unix  3      [ ]         STREAM     CONNECTED     31101    /run/systemd/journal/stdout
unix  2      [ ]         DGRAM                    21526
```

Displays information for all currently open sockets. [Shell 1] shows the output of `netstat` displaying all open socket information. You can check IPv4 socket information and Unix domain socket information.

### 1.2. netstat -i

```shell {caption="[Shell 2] netstat -i"}
$ netstat -i
Kernel Interface table
Iface      MTU    RX-OK RX-ERR RX-DRP RX-OVR    TX-OK TX-ERR TX-DRP TX-OVR Flg
docker0   1500        0      0      0 0            52      0      0      0 BMRU
eth0      1500   312536      0      0 0        127530      0      0      0 BMRU
lo       65536   126777      0      0 0        126777      0      0      0 LRU
```

Displays packet information sent/received by each network interface. [Shell 2] shows the output of `netstat -i` displaying packet information sent/received by each network interface. Each column has the following meaning:

* `RX-OK` : Number of correctly received packets
* `RX-ERR` : Number of received packets that were successfully received but not processed due to errors
* `RX-DRP` : Number of received packets dropped due to full receive buffer
* `RX-OVR` : Number of packets that failed to receive because the kernel was too busy
* `TX-OK` : Number of correctly sent packets
* `TX-ERR` : Number of packets not sent due to errors before transmission
* `TX-DRP` : Number of sent packets dropped due to full send buffer
* `TX-OVR` : Number of packets that failed to send because the kernel was too busy

### 1.3. netstat -nr

```shell {caption="[Shell 3] netstat -nr"}
$ netstat -nr
Kernel IP routing table
Destination     Gateway         Genmask         Flags   MSS Window  irtt Iface
0.0.0.0         192.168.0.1     0.0.0.0         UG        0 0          0 eth0
10.0.0.0        0.0.0.0         255.255.255.0   U         0 0          0 eth1
172.17.0.0      0.0.0.0         255.255.0.0     U         0 0          0 docker0
```

Displays routing table information. [Shell 3] shows the output of `netstat -nr` displaying the routing table.

### 1.4. netstat -plnt

```shell {caption="[Shell 4] netstat -pln"}
$ netstat -plnt
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name
tcp        0      0 10.0.0.19:9100          0.0.0.0:*               LISTEN      3080/node_exporter
tcp        0      0 10.0.0.19:9198          0.0.0.0:*               LISTEN      2253/openstack-expo
tcp        0      0 127.0.0.53:53           0.0.0.0:*               LISTEN      23825/systemd-resol
tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN      1618/sshd
tcp        0      0 10.0.0.19:3000          0.0.0.0:*               LISTEN      27860/grafana-serve
tcp        0      0 10.0.0.19:9091          0.0.0.0:*               LISTEN      2912/prometheus
tcp        0      0 10.0.0.19:9093          0.0.0.0:*               LISTEN      3361/alertmanager
tcp6       0      0 :::22                   :::*                    LISTEN      1618/sshd
tcp6       0      0 :::18080                :::*                    LISTEN      3335/cadvisor
tcp6       0      0 :::9094                 :::*                    LISTEN      3361/alertmanager
tcp6       0      0 :::5000                 :::*                    LISTEN      3057/docker-proxy
```

Displays port and process information in LISTEN state. [Shell 4] shows the output of `netstat -plnt` displaying port and process information in LISTEN state.

## 2. References

* [https://linuxacademy.com/blog/linux/netstat-network-analysis-and-troubleshooting-explained/](https://linuxacademy.com/blog/linux/netstat-network-analysis-and-troubleshooting-explained/)


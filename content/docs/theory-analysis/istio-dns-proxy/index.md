---
title: Istio DNS Proxy
draft: true
---

## 1. Istio DNS Proxy

```shell {caption="[Shell 1] Listen State Ports without DNS Proxy", linenos=table}
$ netstat -plnt
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name
tcp        0      0 0.0.0.0:15090           0.0.0.0:*               LISTEN      16/envoy
tcp        0      0 0.0.0.0:15090           0.0.0.0:*               LISTEN      16/envoy
tcp        0      0 0.0.0.0:15021           0.0.0.0:*               LISTEN      16/envoy
tcp        0      0 0.0.0.0:15021           0.0.0.0:*               LISTEN      16/envoy
tcp        0      0 0.0.0.0:15001           0.0.0.0:*               LISTEN      16/envoy
tcp        0      0 0.0.0.0:15001           0.0.0.0:*               LISTEN      16/envoy
tcp        0      0 0.0.0.0:15006           0.0.0.0:*               LISTEN      16/envoy
tcp        0      0 0.0.0.0:15006           0.0.0.0:*               LISTEN      16/envoy
tcp        0      0 127.0.0.1:15000         0.0.0.0:*               LISTEN      16/envoy
tcp        0      0 127.0.0.1:15004         0.0.0.0:*               LISTEN      1/pilot-agent
tcp        0      0 0.0.0.0:9080            0.0.0.0:*               LISTEN      -
tcp6       0      0 :::15020                :::*                    LISTEN      1/pilot-agent
tcp6       0      0 :::9080                 :::*                    LISTEN      -
```

```shell {caption="[Shell 2] Listen State Ports with DNS Proxy", linenos=table}
$ netstat -plnt
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name
tcp        0      0 0.0.0.0:15021           0.0.0.0:*               LISTEN      16/envoy
tcp        0      0 0.0.0.0:15021           0.0.0.0:*               LISTEN      16/envoy
tcp        0      0 0.0.0.0:15001           0.0.0.0:*               LISTEN      16/envoy
tcp        0      0 0.0.0.0:15001           0.0.0.0:*               LISTEN      16/envoy
tcp        0      0 0.0.0.0:15006           0.0.0.0:*               LISTEN      16/envoy
tcp        0      0 0.0.0.0:15006           0.0.0.0:*               LISTEN      16/envoy
tcp        0      0 0.0.0.0:15090           0.0.0.0:*               LISTEN      16/envoy
tcp        0      0 0.0.0.0:15090           0.0.0.0:*               LISTEN      16/envoy
tcp        0      0 0.0.0.0:9080            0.0.0.0:*               LISTEN      -
tcp        0      0 127.0.0.1:15000         0.0.0.0:*               LISTEN      16/envoy
tcp        0      0 127.0.0.1:15004         0.0.0.0:*               LISTEN      1/pilot-agent
tcp        0      0 127.0.0.1:15053         0.0.0.0:*               LISTEN      1/pilot-agent
tcp6       0      0 :::15020                :::*                    LISTEN      1/pilot-agent
tcp6       0      0 :::9080                 :::*                    LISTEN      -
```

```console {caption="[Shell 3] Pod iptables NAT Table without DNS Proxy", linenos=table}
$ iptables -t nat -nvL
Chain PREROUTING (policy ACCEPT 39 packets, 2340 bytes)
 pkts bytes target     prot opt in     out     source               destination
   39  2340 ISTIO_INBOUND  tcp  --  *      *       0.0.0.0/0            0.0.0.0/0

Chain INPUT (policy ACCEPT 39 packets, 2340 bytes)
 pkts bytes target     prot opt in     out     source               destination

Chain OUTPUT (policy ACCEPT 22 packets, 1834 bytes)
 pkts bytes target     prot opt in     out     source               destination
    8   480 ISTIO_OUTPUT  tcp  --  *      *       0.0.0.0/0            0.0.0.0/0

Chain POSTROUTING (policy ACCEPT 22 packets, 1834 bytes)
 pkts bytes target     prot opt in     out     source               destination

Chain ISTIO_INBOUND (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 RETURN     tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            tcp dpt:15008
    0     0 RETURN     tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            tcp dpt:15090
   39  2340 RETURN     tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            tcp dpt:15021
    0     0 RETURN     tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            tcp dpt:15020
    0     0 ISTIO_IN_REDIRECT  tcp  --  *      *       0.0.0.0/0            0.0.0.0/0

Chain ISTIO_IN_REDIRECT (3 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 REDIRECT   tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            redir ports 15006

Chain ISTIO_OUTPUT (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 RETURN     all  --  *      lo      127.0.0.6            0.0.0.0/0
    0     0 ISTIO_IN_REDIRECT  tcp  --  *      lo      0.0.0.0/0           !127.0.0.1            tcp dpt:!15008 owner UID match 1337
    0     0 RETURN     all  --  *      lo      0.0.0.0/0            0.0.0.0/0            ! owner UID match 1337
    8   480 RETURN     all  --  *      *       0.0.0.0/0            0.0.0.0/0            owner UID match 1337
    0     0 ISTIO_IN_REDIRECT  tcp  --  *      lo      0.0.0.0/0           !127.0.0.1            tcp dpt:!15008 owner GID match 1337
    0     0 RETURN     all  --  *      lo      0.0.0.0/0            0.0.0.0/0            ! owner GID match 1337
    0     0 RETURN     all  --  *      *       0.0.0.0/0            0.0.0.0/0            owner GID match 1337
    0     0 RETURN     all  --  *      *       0.0.0.0/0            127.0.0.1
    0     0 ISTIO_REDIRECT  all  --  *      *       0.0.0.0/0            0.0.0.0/0

Chain ISTIO_REDIRECT (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 REDIRECT   tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            redir ports 15001
```

```console {caption="[Shell 4] Pod iptables NAT Table with DNS Proxy", linenos=table}
$ iptables -t nat -nvL
Chain PREROUTING (policy ACCEPT 53 packets, 3180 bytes)
 pkts bytes target     prot opt in     out     source               destination
   53  3180 ISTIO_INBOUND  tcp  --  *      *       0.0.0.0/0            0.0.0.0/0

Chain INPUT (policy ACCEPT 53 packets, 3180 bytes)
 pkts bytes target     prot opt in     out     source               destination

Chain OUTPUT (policy ACCEPT 22 packets, 1834 bytes)
 pkts bytes target     prot opt in     out     source               destination
    8   480 ISTIO_OUTPUT  tcp  --  *      *       0.0.0.0/0            0.0.0.0/0
   14  1354 ISTIO_OUTPUT  udp  --  *      *       0.0.0.0/0            0.0.0.0/0

Chain POSTROUTING (policy ACCEPT 22 packets, 1834 bytes)
 pkts bytes target     prot opt in     out     source               destination

Chain ISTIO_INBOUND (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 RETURN     tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            tcp dpt:15008
    0     0 RETURN     tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            tcp dpt:15090
   53  3180 RETURN     tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            tcp dpt:15021
    0     0 RETURN     tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            tcp dpt:15020
    0     0 ISTIO_IN_REDIRECT  tcp  --  *      *       0.0.0.0/0            0.0.0.0/0

Chain ISTIO_IN_REDIRECT (3 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 REDIRECT   tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            redir ports 15006

Chain ISTIO_OUTPUT (2 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 RETURN     all  --  *      lo      127.0.0.6            0.0.0.0/0
    0     0 ISTIO_IN_REDIRECT  tcp  --  *      lo      0.0.0.0/0           !127.0.0.1            multiport dports  !53,15008 owner UID match 1337
    0     0 RETURN     tcp  --  *      lo      0.0.0.0/0            0.0.0.0/0            tcp dpt:!53 ! owner UID match 1337
   22  1834 RETURN     all  --  *      *       0.0.0.0/0            0.0.0.0/0            owner UID match 1337
    0     0 ISTIO_IN_REDIRECT  tcp  --  *      lo      0.0.0.0/0           !127.0.0.1            tcp dpt:!15008 owner GID match 1337
    0     0 RETURN     tcp  --  *      lo      0.0.0.0/0            0.0.0.0/0            tcp dpt:!53 ! owner GID match 1337
    0     0 RETURN     all  --  *      *       0.0.0.0/0            0.0.0.0/0            owner GID match 1337
    0     0 REDIRECT   tcp  --  *      *       0.0.0.0/0            10.96.0.10           tcp dpt:53 redir ports 15053
    0     0 RETURN     all  --  *      *       0.0.0.0/0            127.0.0.1
    0     0 ISTIO_REDIRECT  all  --  *      *       0.0.0.0/0            0.0.0.0/0
    0     0 RETURN     udp  --  *      *       0.0.0.0/0            0.0.0.0/0            udp dpt:53 owner UID match 1337
    0     0 RETURN     udp  --  *      *       0.0.0.0/0            0.0.0.0/0            udp dpt:53 owner GID match 1337
    0     0 REDIRECT   udp  --  *      *       0.0.0.0/0            10.96.0.10           udp dpt:53 redir ports 15053

Chain ISTIO_REDIRECT (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 REDIRECT   tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            redir ports 15001
```

## 2. 참조

* [https://istio.io/latest/docs/ops/configuration/traffic-management/dns-proxy/](https://istio.io/latest/docs/ops/configuration/traffic-management/dns-proxy/)
* [https://istio.io/latest/blog/2020/dns-proxy/](https://istio.io/latest/blog/2020/dns-proxy/)
* [https://www.anyflow.net/sw-engineer/istio-dns-proxying](https://www.anyflow.net/sw-engineer/istio-dns-proxying)
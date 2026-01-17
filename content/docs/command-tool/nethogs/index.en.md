---
title: nethogs
---

This document summarizes the usage of `nethogs`, which displays processes sorted by network bandwidth usage in descending order.

## 1. nethogs

### 1.1. # nethogs

```shell {caption="[Shell 1] nethogs"}
$ nethogs
NetHogs version 0.8.5-2

    PID USER     PROGRAM DEV SENT      RECEIVED
      ? root     10.0.0.19:9093-10.0.0.11:37344                             0.058       0.109 KB/sec
      ? root     10.0.0.19:3000-10.0.0.11:53954                             0.058       0.109 KB/sec
      ? root     10.0.0.19:9091-10.0.0.11:53762                             0.029       0.055 KB/sec
  28303 root     sshd: root@pts/0                               eth1        0.180       0.042 KB/sec
  27860 42417    /usr/sbin/grafana-server                       eth1        0.013       0.013 KB/sec
   2912 42472    /opt/prometheus/prometheus                     eth1        0.000       0.000 KB/sec
  29277 root     curl                                           eth0        0.000       0.000 KB/sec
  29270 root     curl                                           eth0        0.000       0.000 KB/sec
      ? root     unknown TCP                                                0.000       0.000 KB/sec

  TOTAL 0.000 0.000 KB/sec                                                  0.337       0.329
```

Displays processes sorted by network bandwidth usage in descending order. [Shell 1] shows the output of `nethogs` displaying network bandwidth usage per process. When PID is "?" and DEV interface is blank, it means packets are being processed by kernel threads that are unknown at the user level.

### 1.2. nethogs [Interface]

Displays only processes using [Interface].

## 2. References

* [https://unix.stackexchange.com/questions/91055/how-to-tell-if-mysterious-programs-in-nethogs-listing-are-malware](https://unix.stackexchange.com/questions/91055/how-to-tell-if-mysterious-programs-in-nethogs-listing-are-malware)



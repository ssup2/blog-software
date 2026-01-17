---
title: nicstat
---

This document summarizes the usage of `nicstat`, which displays NIC statistics.

## 1. nicstat

### 1.1. nicstat

```shell {caption="[Shell 1] nicstat"}
$ nicstat
    Time      Int   rKB/s   wKB/s   rPk/s   wPk/s    rAvs    wAvs %Util    Sat
15:13:34  docker0    0.00    0.00    0.00    0.00    0.00   71.78  0.00   0.00
15:13:34     eth0    2.18    0.08    2.22    0.91  1007.5   86.86  0.00   0.00
15:13:34       lo    0.83    0.83    0.90    0.90   937.9   937.9  0.00   0.00
```

Displays statistics for all NICs. [Shell 1] shows the output of `nicstat` displaying statistics for all NICs. Each column has the following meaning:

* `rKB/s` : Amount of data received per second in KB
* `wKB/s` : Amount of data sent per second in KB
* `rPk/s` : Number of packets received per second
* `wPk/s` : Number of packets sent per second
* `rAvs` : Average size of received packets
* `wAvs` : Average size of sent packets
* `%Util` : Send/receive bandwidth utilization
* `Sat` : Number of errors occurred per second. Can be checked in detail with -x option

### 1.2. nicstat -U

```shell {caption="[Shell 2] nicstat -U"}
$ nicstat -U
    Time      Int   rKB/s   wKB/s   rPk/s   wPk/s    rAvs    wAvs %rUtil %wUtil
12:23:34  docker0    0.00    0.00    0.00    0.00    0.00   71.78   0.00   0.00
12:23:34     eth0    2.64    0.09    2.53    1.04  1067.3   84.93   0.00   0.00
12:23:34       lo    0.83    0.83    0.90    0.90   940.4   940.4   0.00   0.00
```

Separates `%Util` into `%rUtil` (receive util, read util) and `%wUtil` (send util, write util) for output. [Shell 2] shows the output of `nicstat -U` displaying `%rUtil` and `%wUtil` separately. The rest is the same as [Shell 1].

### 1.3. nicstat -x

```shell {caption="[Shell 3] nicstat -x"}
$ nicstat -x  
12:25:57      RdKB    WrKB   RdPkt   WrPkt   IErr  OErr  Coll  NoCP Defer  %Util
docker0       0.00    0.00    0.00    0.00   0.00  0.00  0.00  0.00  0.00   0.00
eth0          2.63    0.09    2.53    1.04   0.00  0.00  0.00  0.00  0.00   0.00
lo            0.83    0.83    0.90    0.90   0.00  0.00  0.00  0.00  0.00   0.00
```

Displays extended statistics for all NICs. [Shell 3] shows the output of `nicstat -x` displaying extended statistics for all NICs. Each column has the following meaning:

* `RdKB` : Amount of data received per second in KB
* `WrKB` : Amount of data sent per second in KB
* `RdPkt` : Number of packets received per second
* `WrPkt` : Number of packets sent per second
* `IErr` : Number of packets not processed due to errors in received packets
* `OErr` : Number of packets not sent due to errors before transmission
* `Coll` : Number of Ethernet collisions occurred
* `NoCP` : Number of times received packets were not delivered to the process because the process that should receive packets was too busy to process them
* `Defer` : Number of times transmission was delayed because the transmission medium was busy
* `%Util` : Send/receive bandwidth utilization

### 1.4. nicstat -i [Interface]

Displays statistics only for [Interface] NIC.

### 1.5. nicstat -i [Interface] [Interval] [Count]

Repeats statistics for [Interface] NIC [Count] times at [Interval] intervals.


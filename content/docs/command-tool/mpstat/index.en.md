---
title: mpstat
---

This document summarizes the usage of `mpstat`, which displays CPU usage.

## 1. mpstat

### 1.1. mpstat -P ALL

```shell {caption="[Shell 1] mpstat -P ALL"}
$ mpstat -P ALL
Linux 4.15.0-60-generic (node09)        10/09/19        _x86_64_        (2 CPU)

13:00:37     CPU    %usr   %nice    %sys %iowait    %irq   %soft  %steal  %guest  %gnice   %idle
13:00:37     all    8.45    0.04    2.07   24.08    0.00    0.07    0.00    0.00    0.00   65.29
13:00:37       0    8.47    0.03    2.07   24.25    0.00    0.12    0.00    0.00    0.00   65.06
13:00:37       1    8.42    0.04    2.08   23.92    0.00    0.03    0.00    0.00    0.00   65.51
```

Displays average CPU core usage and per-core CPU usage. [Shell 1] shows the output of `mpstat -P ALL` displaying average CPU core usage and per-core CPU usage. Each column has the following meaning:

* `%usr` : CPU usage rate for running user code of processes without nice value applied. Represents usage rate of most user processes
* `%nice` : CPU usage rate for running user code of processes with nice value applied
* `%sys` : CPU usage rate for running kernel code, excluding usage/idle rates of id, wa, hi, si
* `%iowait` : CPU idle rate due to I/O Wait
* `%irq` : CPU usage rate used for pure hardware interrupt processing. Represents CPU usage rate for processing the top halves part that only sets interrupt flags in the kernel
* `%soft` : CPU usage rate of bottom halves that actually process interrupts according to interrupt flags set by top halves
* `%steal` : CPU usage rate stolen by the hypervisor or other virtual machines when the kernel runs inside a virtual machine controlled by a hypervisor
* `%guest` : CPU usage rate for running vCPU of virtual machines without nice value applied when running virtual machines through a hypervisor
* `%gnice` : CPU usage rate for running vCPU of virtual machines with nice value applied when running virtual machines through a hypervisor
* `%idle` : CPU idle rate excluding I/O Wait

### 1.2. mpstat -P ALL [Interval] [Count]

Outputs CPU usage [Count] times at [Interval] intervals.

## 2. References

* [https://linux.die.net/man/1/free](https://linux.die.net/man/1/free)
* [https://serverfault.com/questions/23433/in-linux-what-is-the-difference-between-buffers-and-cache-reported-by-the-f](https://serverfault.com/questions/23433/in-linux-what-is-the-difference-between-buffers-and-cache-reported-by-the-f)



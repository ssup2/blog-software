---
title: top
---

This document summarizes the usage of `top`, which displays processes sorted by CPU usage or memory usage.

## 1. top

### 1.1. top

```shell {caption="[Shell 1] top"} 
$ top
top - 10:27:27 up 36 min,  3 users,  load average: 0.00, 0.01, 0.05
Tasks: 238 total,   1 running, 237 sleeping,   0 stopped,   0 zombie
%Cpu(s):  0.2 us,  0.1 sy,  0.0 ni, 99.7 id,  0.1 wa,  0.0 hi,  0.0 si,  0.0 st
KiB Mem:   8052812 total,  1053584 used,  6999228 free,    49428 buffers
KiB Swap:  8265724 total,        0 used,  8265724 free.   541164 cached Mem

  PID USER      PR  NI    VIRT    RES    SHR S  %CPU %MEM     TIME+ COMMAND
 1848 root      20   0 1175416 103756  61724 S   0.7  1.3   0:12.55 compiz
 1349 root      20   0  601840  69188  53208 S   0.3  0.9   0:05.81 Xorg
 2824 root      20   0   30372   3544   2976 R   0.3  0.0   0:00.06 top
    1 root      20   0   34024   4464   2616 S   0.0  0.1   0:00.80 init
    2 root      20   0       0      0      0 S   0.0  0.0   0:00.00 kthreadd
    3 root      20   0       0      0      0 S   0.0  0.0   0:00.52 ksoftirqd/0
    5 root       0 -20       0      0      0 S   0.0  0.0   0:00.00 kworker/0:+
    7 root      20   0       0      0      0 S   0.0  0.0   0:00.33 rcu_preempt
    8 root      20   0       0      0      0 S   0.0  0.0   0:00.00 rcu_sched
    9 root      20   0       0      0      0 S   0.0  0.0   0:00.00 rcu_bh
   10 root      rt   0       0      0      0 S   0.0  0.0   0:00.00 migration/0
   11 root      rt   0       0      0      0 S   0.0  0.0   0:00.01 watchdog/0
   12 root      rt   0       0      0      0 S   0.0  0.0   0:00.01 watchdog/1
   13 root      rt   0       0      0      0 S   0.0  0.0   0:00.00 migration/1
   14 root      20   0       0      0      0 S   0.0  0.0   0:00.44 ksoftirqd/1
   16 root       0 -20       0      0      0 S   0.0  0.0   0:00.00 kworker/1:+
   17 root      rt   0       0      0      0 S   0.0  0.0   0:00.00 watchdog/2
```

[Shell 1] shows what can be checked through `top`. The upper part outputs CPU and memory information, and the lower part outputs process information sorted in descending order by CPU usage.

#### 1.1.1. CPU Information

The %Cpu(s) part in the upper part of [Shell 1] represents the average CPU usage of all CPU cores. Each column has the following meaning:

* `us (user)` : CPU usage rate for running user code of processes without nice value applied (un-niced, nice = 0). Represents usage rate of most user processes
* `sy (system)` : CPU usage rate for running kernel code, excluding usage/idle rates of id, wa, hi, si
* `ni (nice)` : CPU usage rate for running user code of processes with nice value applied (niced)
* `id (idle)` : CPU idle rate excluding I/O Wait
* `wa (wait)` : CPU idle rate due to I/O Wait
* `hi (hardware interrupt)` : CPU usage rate used for pure hardware interrupt processing. Represents CPU usage rate for processing the top halves part that only sets interrupt flags in the kernel
* `si (sotware interrupt)` : CPU usage rate of bottom halves that actually process interrupts according to interrupt flags set by top halves
* `st (steal)` : CPU usage rate stolen by the hypervisor or other virtual machines when the kernel runs inside a virtual machine controlled by a hypervisor

#### 1.1.2. Memory Information

Between the CPU information and process information in [Shell 1], memory usage is displayed. Each item has the following meaning:

* `Mem total` : Total memory capacity
* `Mem used` : Memory capacity in use
* `Mem free` : Memory capacity not in use
* `Swap total` : Total swap capacity
* `Swap used` : Swap capacity in use
* `Swap free` : Swap capacity not in use
* `buffers` : Memory capacity used as kernel buffer
* `cached Mem` : Memory capacity used as kernel cache

#### 1.1.3. Process Information

The lower part of [Shell 1] outputs process information. Each column has the following meaning:

* `PID` : Process ID
* `USER` : Process owner
* `PR` : Scheduling priority actually used during kernel scheduling. Can have values "0 ~ 39, rt", and in the case of numbers, lower values have higher priority. rt means Real Time Scheduling Priority and has higher priority than priority 0
* `NI` : nice value. Can have values "-20 ~ 19", and lower numbers have higher priority. "20 + NI" becomes PR
* `VIRT` : Virtual memory capacity. Means the sum of all memory capacity and swap capacity allocated for the process, even if not currently in use
* `RES` : Actual memory capacity currently in use. Part of VIRT
* `SHR` : Shared memory capacity. Part of RES
* `S` : Process state
* `%CPU` : CPU usage rate
* `%MEM` : Memory usage rate
* `TIME+` : Process runtime
* `COMMAND` : Process command

#### 1.1.4. Shortcuts

* 1 : Outputs usage per CPU core
* SHIFT + M : Sorts by memory usage
* SHIFT + P : Sorts by CPU usage
* SHIFT + T : Sorts by runtime

## 2. References

* [https://kldp.org/node/65018](https://kldp.org/node/65018)
* [http://serverfault.com/questions/230495/what-does-st-mean-in-top](http://serverfault.com/questions/230495/what-does-st-mean-in-top)
* [https://www.tecmint.com/set-linux-process-priority-using-nice-and-renice-commands/](https://www.tecmint.com/set-linux-process-priority-using-nice-and-renice-commands/)


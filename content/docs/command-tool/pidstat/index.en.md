---
title: pidstat
---

This document summarizes the usage of `pidstat`, which displays resource usage per process.

## 1. pidstat

### 1.1. pidstat (-u)

```shell {caption="[Shell 1] pidstat"}
$ pidstat
Linux 4.15.0-60-generic (node09)        10/02/19        _x86_64_        (2 CPU)

15:23:24      UID       PID    %usr %system  %guest   %wait    %CPU   CPU  Command
15:23:24        0         1    0.02    0.01    0.00    0.00    0.03     1  systemd
15:23:24        0         2    0.00    0.00    0.00    0.00    0.00     1  kthreadd
15:23:24        0         7    0.00    0.02    0.00    0.01    0.02     0  ksoftirqd/0
15:23:24        0         8    0.00    0.17    0.00    0.15    0.17     0  rcu_sched
15:23:24        0        10    0.00    0.00    0.00    0.00    0.00     0  migration/0
15:23:24        0        11    0.00    0.00    0.00    0.00    0.00     0  watchdog/0
15:23:24        0        14    0.00    0.00    0.00    0.00    0.00     1  watchdog/1
```

Displays CPU usage per process. [Shell 1] shows the output of `pidstat` displaying usage per process. Each column has the following meaning:

* %usr : CPU usage rate for running application code of the process
* %system : CPU usage rate for running kernel code of the process
* %guest : CPU usage rate for running vCPU if the process is a hypervisor
* %wait : CPU idle rate for running the process
* %CPU : Total CPU usage rate of the process
* CPU : CPU core on which the process runs

### 1.2. pidstat -t

```shell {caption="[Shell 2] pidstat -t"}
# pidstat -t
Linux 4.15.0-60-generic (node09)        10/02/19        _x86_64_        (2 CPU)

15:12:35    42472      3361         -    0.03    0.06    0.00    0.01    0.09     0  alertmanager
15:12:35    42472         -      3361    0.00    0.01    0.00    0.01    0.01     0  |__alertmanager
15:12:35    42472         -      3554    0.01    0.02    0.00    0.04    0.02     0  |__alertmanager
15:12:35    42472         -      3581    0.01    0.01    0.00    0.01    0.01     1  |__alertmanager
15:12:35    42472         -      3651    0.01    0.01    0.00    0.01    0.01     0  |__alertmanager
15:12:35    42472         -      3652    0.00    0.01    0.00    0.01    0.01     0  |__alertmanager
15:12:35    42472         -     24745    0.00    0.01    0.00    0.01    0.01     0  |__alertmanager
15:12:35    42472         -     26621    0.00    0.01    0.00    0.01    0.01     1  |__alertmanager 
15:12:35        0      3373         -    0.00    0.00    0.00    0.00    0.00     1  containerd-shim
15:12:35        0         -      3374    0.00    0.00    0.00    0.00    0.00     1  |__containerd-shim
15:12:35        0         -      3376    0.00    0.00    0.00    0.00    0.00     1  |__containerd-shim
15:12:35        0         -      3381    0.00    0.00    0.00    0.00    0.00     0  |__containerd-shim
15:12:35        0         -      3431    0.00    0.00    0.00    0.00    0.00     1  |__containerd-shim
15:12:35        0         -      4355    0.00    0.00    0.00    0.00    0.00     0  |__containerd-shim 
```

Displays CPU usage per process and thread. [Shell 2] shows the output of `pidstat -t` displaying usage per process and thread. You can see that process usage is displayed, followed by usage per thread below.

### 1.3. pidstat [Interval] [Count]

Outputs CPU usage [Count] times at [Interval] intervals.

### 1.4. pidstat -p [PID] [Interval]

Outputs CPU usage of [PID] process at [Interval] intervals.

### 1.5. pidstat -d

```shell {caption="[Shell 3] pidstat -d"}
$ pidstat -d
Linux 4.15.0-60-generic (node09)        10/02/19        _x86_64_        (2 CPU)

15:43:32      UID       PID   kB_rd/s   kB_wr/s kB_ccwr/s iodelay  Command
15:43:32        0         1     10.55     39.65      6.66     962  systemd
15:43:32        0        27      0.00      0.00      0.00      45  writeback
15:43:32        0       355      0.00     26.71      0.00 7489695  jbd2/sda2-8
15:43:32        0       436      0.00      0.00      0.00      28  lvmetad
15:43:32        0       522      0.07      0.00      0.00     452  loop0
```

Displays disk I/O usage per process. [Shell 3] shows the output of `pidstat -d` displaying disk I/O usage per process. Each column has the following meaning:

* kB_rd/s : Amount of data read per second by the process in KB
* kB_wr/s : Amount of data written per second by the process in KB
* kB_ccwr/s : Amount of data for which write was cancelled due to dirty page cache of the process in KB
* iodelay : Disk delay of the process. Delay includes time until disk sync is completed

### 1.6. pidstat -r

```shell {caption="[Shell 4] pidstat -r"}
$ pidstat -r
Linux 4.15.0-60-generic (node09)        10/02/19        _x86_64_        (2 CPU)

15:44:13      UID       PID  minflt/s  majflt/s     VSZ     RSS   %MEM  Command
15:44:13        0         1      0.22      0.00  160180    9652   0.12  systemd
15:44:13        0       436      0.00      0.00  105904    1720   0.02  lvmetad
15:44:13        0       925      0.02      0.00   30028    3268   0.04  cron
15:44:13        0       934      0.00      0.00   62132    5540   0.07  systemd-logind
15:44:13        0       960      0.00      0.00  310152    2720   0.03  lxcfs 
```

Displays memory usage per process. [Shell 4] shows the output of `pidstat -r` displaying memory usage per process. Each column has the following meaning:

* minflt/s : Number of minor faults occurred per second by the process
* majflt/s : Number of major faults occurred per second by the process
* VSZ : Virtual memory usage of the process
* RSS : Non-swapped memory usage among memory used by the process

### 1.7. pidstat -s

```shell {caption="[Shell 5] pidstat -s"}
$ pidstat -s
Linux 4.15.0-60-generic (node09)        10/02/19        _x86_64_        (2 CPU)

15:45:02      UID       PID StkSize  StkRef  Command
15:45:02        0         1     132      56  systemd
15:45:02        0       436     132      12  lvmetad
15:45:02        0       925     132      28  cron
15:45:02        0       934     132      16  systemd-logind
15:45:02        0       960     132      24  lxcfs 
```

Displays stack usage per process. [Shell 5] shows the output of `pidstat -s` displaying stack usage per process. Each column has the following meaning:

* StkSize : Size of memory reserved for use as stack by the process
* StkRef : Size of memory used as stack by the process

### 1.8. pidstat -v

```shell {caption="[Shell 6] pidstat -v"}
$ pidstat -v
Linux 4.15.0-60-generic (node09)        10/02/19        _x86_64_        (2 CPU)

15:45:34      UID       PID threads   fd-nr  Command
15:45:34        0         1       1      82  systemd
15:45:34        0         2       1       0  kthreadd
15:45:34        0         4       1       0  kworker/0:0H
15:45:34        0         6       1       0  mm_percpu_wq
15:45:34        0         7       1       0  ksoftirqd/0 
```

Displays thread count and FD (File Descriptor) count information per process. [Shell 6] shows the output of `pidstat -v` displaying thread count and FD count information per process. Each column has the following meaning:

* threads : Number of threads of the process
* fd-nr : Number of FDs (File Descriptors) currently used by the process

### 1.9. pidstat -w

```shell {caption="[Shell 7] pidstat -w"}
$ pidstat -w
Linux 4.15.0-60-generic (node09)        10/02/19        _x86_64_        (2 CPU)

15:47:23      UID       PID   cswch/s nvcswch/s  Command
15:47:23        0         1      0.25      0.05  systemd
15:47:23        0         2      0.01      0.00  kthreadd
15:47:23        0         4      0.00      0.00  kworker/0:0H
15:47:23        0         6      0.00      0.00  mm_percpu_wq
15:47:23        0         7      5.16      1.68  ksoftirqd/0 
```

Displays context switch information per process. [Shell 7] shows the output of `pidstat -w` displaying context switch information per process. Each column has the following meaning:

* cswch/s : Number of voluntary context switches occurred per second
* nvcswch/s : Number of involuntary context switches occurred per second


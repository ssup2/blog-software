---
title: iostat
---

This document summarizes the usage of `iostat`, which displays Block Device I/O statistics and CPU statistics.

## 1. iostat

### 1.1. iostat

```shell {caption="[Shell 1] iostat"}
$ iostat
Linux 4.15.0-60-generic (node09)        09/28/19        _x86_64_        (2 CPU)

avg-cpu:  %user   %nice %system %iowait  %steal   %idle
           9.34    0.05    2.41   32.10    0.00   56.10

Device             tps    kB_read/s    kB_wrtn/s    kB_read    kB_wrtn
loop0             0.09         0.11         0.00       9424          0
loop1             0.00         0.01         0.00       1076          0
sda              40.71        43.81      7572.20    3903569  674772928
sdb               0.01         0.29         0.00      25400          0
```

Displays Block Device I/O statistics and CPU statistics. [Shell 1] shows the output of `iostat` displaying Block Device I/O statistics and CPU statistics. The upper part shows CPU statistics. The output is as follows:

* user : User level usage rate of processes without nice value applied
* nice : User level usage rate of processes with nice value applied
* system : Kernel level usage rate of processes
* iowait : CPU idle rate due to I/O Wait
* steal : CPU usage rate stolen by the hypervisor or other virtual machines when the kernel runs inside a virtual machine controlled by a hypervisor
* idle : CPU idle rate excluding I/O Wait

The lower part shows Block Device I/O information. The output is as follows:

* tps : Number of I/O requests per second
* kB_read/s : Amount of data read per second in kB. Unit can be changed via options
* kB_wrtn/s : Amount of data written per second in kB. Unit can be changed via options
* kB_read : Number of blocks read per second
* kB_wrtn : Number of blocks written per second

### 1.2. iostat -x

```shell {caption="[Shell 2] iostat -x"}
$ iostat -x
Linux 4.15.0-60-generic (node09)        09/28/19        _x86_64_        (2 CPU)

avg-cpu:  %user   %nice %system %iowait  %steal   %idle
           9.34    0.05    2.41   32.09    0.00   56.11

Device            r/s     w/s     rkB/s     wkB/s   rrqm/s   wrqm/s  %rrqm  %wrqm r_await w_await aqu-sz rareq-sz wareq-sz  svctm  %util
loop0            0.09    0.00      0.11      0.00     0.00     0.00   0.00   0.00   12.98    0.00   0.00     1.12     0.00   0.47   0.00
loop1            0.00    0.00      0.01      0.00     0.00     0.00   0.00   0.00   23.47    0.00   0.00    20.30     0.00   7.47   0.00
loop2            0.12    0.00      0.13      0.00     0.00     0.00   0.00   0.00    0.04    0.00   0.00     1.10     0.00   0.00   0.00
sda              4.83   35.87     43.79   7568.11     0.49    64.44   9.14  64.24   24.46   72.31   2.71     9.06   211.00  16.16  65.76
sdb              0.01    0.00      0.28      0.00     0.00     0.00   0.00   0.00   22.65    0.00   0.00    28.86     0.00  16.74   0.02
```

Displays extended Block Device I/O statistics and CPU statistics. [Shell 2] shows the output of `iostat -x` displaying extended Block Device I/O statistics and CPU statistics. CPU statistics are the same as [Shell 1], and Block Device I/O statistics are as follows:

* r/s : Number of completed read requests per second
* w/s : Number of completed write requests per second
* rkB/s : Amount of data read per second in kB. Unit can be changed via options
* wkB/s : Amount of data written per second in kB. Unit can be changed via options
* rrqm/s : Number of read requests merged in Block Device queue per second
* wrqm/s : Number of write requests merged in Block Device queue per second
* %rrqm : Percentage of read requests merged before being sent to Block Device
* %wrqm : Percentage of write requests merged before being sent to Block Device
* r_await : Average time from sending read request to Block Device until data is actually read from Block Device. Includes time waiting in queue
* w_await : Average time from sending write request to Block Device until data is actually written to Block Device. Includes time waiting in queue
* aqu-sz : Average queue length
* rareq-sz : Average size of read requests
* wareq-sz : Average size of write requests
* %util : Block Device bandwidth utilization

### 1.2. iostat [Interval] [Count]

Outputs I/O statistics [Count] times at [Interval] intervals.

### 1.3. iostat -c

Outputs only CPU statistics.

### 1.4. iostat -d 

Outputs only disk device information.

### 1.5. iostat -k

Outputs in kB per second instead of blocks per second.

### 1.6. iostat -m

Outputs in MB per second instead of blocks per second.


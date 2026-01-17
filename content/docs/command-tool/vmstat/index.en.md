---
title: vmstat
---

This document summarizes the usage of `vmstat`, which displays memory statistics.

## 1. vmstat

### 1.1. vmstat

```shell {caption="[Shell 1] vmstat"}
$ vmstat
procs -----------memory---------- ---swap-- -----io---- -system-- ------cpu-----
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
 1  1    268 782960 849224 3488324    0    0    14  1733   77   78  6  2 68 24  0
 ```

Displays current memory statistics. [Shell 1] shows the output of `vmstat` displaying memory statistics. Each column has the following meaning:

* procs
  * `r` : Number of Runnable Processes (Running state / waiting in Run Queue)
  * `b` : Number of Processes in Uninterruptible Sleep state
* memory
  * `swpd` : Virtual memory capacity provided by Swap in bytes
  * `free` : Unused memory capacity in bytes
  * `buff` : Memory capacity used as Kernel Buffer in bytes
  * `cache` : Memory capacity used as Kernel Cache in bytes
* swap :
  * `si` : Memory capacity swapped in from Swap Disk to Memory per second in bytes
  * `so` : Memory capacity swapped out from Memory to Swap Disk per second in bytes
* io
  * `bi` : Number of blocks received from Block Device per second
  * `bo` : Number of blocks sent to Block Device per second
* system
  * `in` : Number of interrupts received per second, including clock
  * `cs` : Number of Context Switches occurred per second
* cpu
  * `us` : CPU usage rate for running application code
  * `sy` : CPU usage rate for running kernel code
  * `id` : CPU idle rate excluding I/O Wait
  * `wa` : CPU idle rate due to I/O Wait
  * `st` : CPU usage rate stolen by the hypervisor or other virtual machines when the kernel runs inside a virtual machine controlled by a hypervisor

### 1.2. vmstat [Interval] [Count]

Outputs system-wide information [Count] times at [Interval] intervals.

### 1.3. vmstat -d

```shell {caption="[Shell 2] vmstat -d"}
$ vmstat -d
disk- ------------reads------------ ------------writes----------- -----IO------
       total merged sectors      ms  total merged sectors      ms    cur    sec
loop0   8669      0   21324  109832      0      0       0       0      0      4
loop1     53      0    2152    1244      0      0       0       0      0      0
loop2  11152      0   25952     712      0      0       0       0      0      0
loop3      2      0      10       0      0      0       0       0      0      0
loop4      0      0       0       0      0      0       0       0      0      0
loop5      0      0       0       0      0      0       0       0      0      0
loop6      0      0       0       0      0      0       0       0      0      0
loop7      0      0       0       0      0      0       0       0      0      0
sr0        0      0       0       0      0      0       0       0      0      0
fd0       25      0     200    1164      0      0       0       0      0      1
sda   613771  66065 10319473 12671488 4981677 7462940 1628317680 348232712      0  94326
sdb      959      0   53207   20628      0      0       0       0      0     15
```

Displays disk statistics. [Shell 2] shows the output of `vmstat -d` displaying disk statistics. Each column has the following meaning:

* reads
  * `total` : Total number of successful read operations
  * `merged` : Total number of read operations merged by I/O Scheduler
  * `sectors` : Total number of sectors successfully read
  * `ms` : Total time taken for reads
* writes
  * `total` : Total number of successful write operations
  * `merged` : Total number of write operations merged by I/O Scheduler
  * `sectors` : Total number of sectors successfully written
  * `ms` : Total time taken for writes
* IO
  * `cur` : Number of I/O operations currently being processed
  * `sec` : Total time taken for I/O processing in seconds

### 1.4. vmstat -p [Partition]

```shell {caption="[Shell 3] vmstat -p [Partition]"}
# vmstat -p /dev/sda2
sda2          reads   read sectors  writes    requested writes
              612711   10283732    4783736 1628860584
```

[Shell 3] shows the output of `vmstat -p` displaying partition statistics. Each column has the following meaning:

* `reads` : Number of read requests issued for the partition
* `read sectors` : Number of sectors read for the partition
* `writes` : Number of write requests issued for the partition
* `requested writes` : Number of sectors written for the partition

### 1.5. vmstat -m

```shell {caption="[Shell 4] vmstat -m"}
$ vmstat -m
Cache                       Num  Total   Size  Pages
SCTPv6                       22     22   1472     22
SCTP                          0      0   1344     12
au_finfo                      0      0    192     21
au_icntnr                     0      0    768     21
au_dinfo                      0      0    128     32
ovl_inode                 14122  14122    688     23
sw_flow                       0      0   1648     19
nf_conntrack                 94    168    320     12
ext4_groupinfo_4k          1624   1624    144     28
btrfs_delayed_ref_head        0      0    152     26
btrfs_delayed_node            0      0    296     13
btrfs_ordered_extent          0      0    416     19
btrfs_extent_map              0      0    144     28
btrfs_extent_buffer           0      0    280     14
btrfs_path                    0      0    112     36
btrfs_trans_handle            0      0    120     34
btrfs_inode                   0      0   1144     14 
```

[Shell 4] shows the output of `vmstat -m` displaying slab statistics. Each column has the following meaning:

* `Cache` : Cache name
* `Num` : Number of currently active Slab Objects
* `Total` : Total number of Slab Objects
* `Size` : Size of Slab Object
* `Pages` : Number of Pages (Slabs) with one or more active Slab Objects

## 2. References

* [http://www.linfo.org/runnable_process.html](http://www.linfo.org/runnable_process.html)
* [https://hotpotato.tistory.com/280](https://hotpotato.tistory.com/280)
* [https://medium.com/@damianmyerscough/vmstat-explained-83b3e87493b3](https://medium.com/@damianmyerscough/vmstat-explained-83b3e87493b3)


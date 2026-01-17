---
title: sysdig
---

This document summarizes the usage of `sysdig`, which displays various operations of the Linux kernel and can also perform performance measurements.

### 1. lsof

#### 1.1. sysdig

```shell {caption="[Shell 1] sysdig"}
$ sysdig
8464 01:23:53.859656137 1 sshd (30637) < read res=2 data=..
8465 01:23:53.859656937 1 sshd (30637) > getpid
8466 01:23:53.859657037 1 sshd (30637) < getpid
8467 01:23:53.859658137 1 sshd (30637) > clock_gettime
8468 01:23:53.859658337 1 sshd (30637) < clock_gettime
8469 01:23:53.859658837 1 sshd (30637) > select
8470 01:23:53.859659637 1 sshd (30637) < select res=1
8471 01:23:53.859660037 1 sshd (30637) > clock_gettime
8472 01:23:53.859660237 1 sshd (30637) < clock_gettime
8473 01:23:53.859660737 1 sshd (30637) > rt_sigprocmask
8474 01:23:53.859660937 1 sshd (30637) < rt_sigprocmask
8475 01:23:53.859661337 1 sshd (30637) > rt_sigprocmask
8476 01:23:53.859661537 1 sshd (30637) < rt_sigprocmask
8477 01:23:53.859662037 1 sshd (30637) > clock_gettime
8478 01:23:53.859662237 1 sshd (30637) < clock_gettime
8479 01:23:53.859662737 1 sshd (30637) > write fd=3(<4t>10.0.0.10:12403->10.0.0.19:22) size=36
8480 01:23:53.859663337 1 sshd (30637) < write res=36 data=.)r...GId....mG.e..._.~..h}....K.{..
8481 01:23:53.859663937 1 sshd (30637) > clock_gettime
8482 01:23:53.859664137 1 sshd (30637) < clock_gettime
8483 01:23:53.859664737 1 sshd (30637) > select
8484 01:23:53.859665937 1 sshd (30637) > switch next=3591(sysdig) pgft_maj=3 pgft_min=452 vm_size=72356 vm_rss=6396 vm_swap=0
```

Outputs all kernel operations that sysdig can detect. [Shell 1] shows the output of `sysdig` displaying kernel operations.

### 1.2. sysdig -c topprocs_cpu

```shell {caption="[Shell 2] sysdig -c topprocs_cpu"}
$ sysdig -c topprocs_cpu
CPU%                Process             PID
--------------------------------------------------------------------------------
5.03%               cadvisor            2521
2.01%               prometheus          2397
1.01%               sysdig              4327
0.00%               dbus-daemon         920
0.00%               grafana-server      2398
```

Displays processes sorted by CPU usage in descending order. [Shell 2] shows the output of `sysdig -c topprocs_cpu` displaying processes sorted by CPU usage.

### 1.3. sysdig -c topprocs_net

```shell {caption="[Shell 3] sysdig -c topprocs_net"}
$ sysdig -c topprocs_net
Bytes               Process             PID
--------------------------------------------------------------------------------
1.70KB              openstack-expor     3228
314B                prometheus          2258
236B                sshd                3026      
212B                dbus-daemon         920
124%                grafana-server      2398                       
```

Displays processes sorted by network bandwidth usage in descending order. [Shell 3] shows the output of `sysdig -c topprocs_net` displaying processes sorted by network bandwidth usage.

### 1.4. sysdig -c topprocs_file

```shell {caption="[Shell 4] sysdig -c topprocs_file"}
$ sysdig -c topprocs_file
Bytes               Process             PID
--------------------------------------------------------------------------------
38.40M              prometheus          2574
32.55KB             cadvisor            2643
292B                sshd                2135
254B                chronyd             2540
```

Displays processes sorted by disk bandwidth usage in descending order. [Shell 4] shows the output of `sysdig -c topprocs_net` displaying processes sorted by disk bandwidth usage.

### 1.5. sysdig -c topfiles_bytes

```shell {caption="[Shell 5] sysdig -c topprocs_bytes"}
$ sysdig -c topfiles_bytes
Bytes               Filename
--------------------------------------------------------------------------------
1.12KB              /proc/stat
1.05KB              /dev/ptmx
832B                /lib/x86_64-linux-gnu/libnsl.so.1
832B                /lib/x86_64-linux-gnu/libnss_compat.so.2
832B                /lib/x86_64-linux-gnu/libnss_nis.so.2
832B                /lib/x86_64-linux-gnu/libnss_files.so.2
832B                /lib/x86_64-linux-gnu/libm.so.6
832B                /lib/x86_64-linux-gnu/libc.so.6
497B                /etc/nsswitch.conf
```

Displays files sorted by disk bandwidth usage in descending order. [Shell 4] shows the output of `sysdig -c topfiles_bytes` displaying files sorted by disk bandwidth usage.

## 2. References

* [https://github.com/draios/sysdig/wiki/Sysdig-Examples#containers](https://github.com/draios/sysdig/wiki/Sysdig-Examples#containers)


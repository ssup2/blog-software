---
title: Linux OOM Killer
---

Analyze Linux OOM (Out of Memory) Killer.

## 1. Linux OOM Killer

Linux creates more virtual Memory space than actual physical Memory and allocates it to Processes. This Memory management policy is called Memory Overcommit. Therefore, when multiple Processes simultaneously use large amounts of Memory, physical Memory space shortages can occur. Linux's Swap technique is a method that uses part of Disk space as Memory when physical Memory space is insufficient. However, if the Swap Space, which is the Disk area used by the Swap technique, is also full, Linux can no longer allocate Memory. **At this time, Linux uses OOM (Out of Memory) Killer to forcibly kill existing running Processes to secure Memory.**

```shell {caption="[Shell 1] Check Badness Score"}
# Create Child Process using 512MB, 1024MB using stress command
(node)$ stress --vm 1 --vm-bytes 512M --vm-hang 0 &
[1] 2447
stress: info: [2447] dispatching hogs: 0 cpu, 0 io, 1 vm, 0 hdd
(node)$ ps -ef | grep 2447
root      2447  2009  0 15:46 pts/1    00:00:00 stress --vm 1 --vm-bytes 512M --vm-hang 0
root      2449  2447  0 15:46 pts/1    00:00:00 stress --vm 1 --vm-bytes 512M --vm-hang 0
(node)$ stress --vm 1 --vm-bytes 1024M --vm-hang 0 &
[2] 2476
stress: info: [2476] dispatching hogs: 0 cpu, 0 io, 1 vm, 0 hdd
(node)$ ps -ef | grep 2476
root      2476  2009  0 15:47 pts/1    00:00:00 stress --vm 1 --vm-bytes 1024M --vm-hang 0
root      2478  2476  0 15:47 pts/1    00:00:00 stress --vm 1 --vm-bytes 1024M --vm-hang 0

# Check Badness Score of stress command's Child Process
(node)$ cat /proc/2449/oom-score
76
(node)$ cat /proc/2478/oom-score
152
```

OOM Killer does not kill arbitrary Processes when killing Processes, but kills Processes with high scores called Badness Scores first. Badness Score increases as Memory usage increases. Each Process's Badness Score can be checked in the `/proc/[PID]/oom-score` file. [Shell 1] shows the process of checking Badness Score according to Memory usage using the stress command. The first stress command creates a Child Process using 512MB of Memory, and the second stress command creates a Child Process using 1024MB of Memory. Since the second stress command's Child Process uses twice as much Memory as the first stress command's Child Process, you can see that the Badness Score also differs by 2 times.

Not only Memory usage but also factors that affect Badness Score exist. The following factors are factors that reduce Badness Score:

* Privileged Process (root User Process)
* Process that has been running for a long time
* Process that directly accesses Hardware

The following factors are factors that increase Badness Score:

* Process that creates many Child Processes
* Process with low nice value

```shell {caption="[Shell 2] Adjust Badness Score"}
# Decrease Badness Score
(node)$ cat /proc/2449/oom-score
76
(node)$ echo -50 > /proc/2449/oom-score-adj
(node)$ cat /proc/2449/oom-score
26
(node)$ echo -100 > /proc/2449/oom-score-adj
(node)$ cat /proc/2449/oom-score
0

# Increase Badness Score
(node)$ cat /proc/2478/oom-score
152
(node)$ echo 500 > /proc/2478/oom-score-adj
(node)$ cat /proc/2478/oom-score
652
(node)$ echo 900 > /proc/2478/oom-score-adj
(node)$ cat /proc/2478/oom-score
1052
```

Process Badness Score can be adjusted by system administrators. To adjust Process Badness Score, write the adjustment value in the `/proc/[PID]/oom-score-adj` file. [Shell 2] shows the process of adjusting Badness Score. To decrease Badness Score, write a negative number in the `/proc/[PID]/oom-score-adj` file as much as you want to decrease. In the Badness Score decrease example in [Shell 2], the Badness Score was initially 76, but you can see that it decreases by the amount of the negative number written in the `/proc/[PID]/oom-score-adj` file. Since the minimum value of Badness Score is 0, you can also see that it does not go below 0.

Conversely, to increase Badness Score, write a positive number in the `/proc/[PID]/oom-score-adj` file as much as you want to increase. In the Badness Score increase example in [Shell 2], the Badness Score was initially 152, but you can see that it increases by the amount of the positive number written in the `/proc/[PID]/oom-score-adj` file.

```text {caption="[Formula 1] Badness Score Formula"}
Final Badness Score = Original Badness Score + Adjust Score
Original Badness Score : 0 <= Value <= 1000
Adjust Score : -1000 <= Value <= 1000
Final Badness Score : 0 <= Value <= 2000 <br/>
```

[Formula 1] shows the process of calculating Badness Score. Badness Score before adjustment can have a value from minimum 0 to maximum 1000. Adjustment value can have a value from -1000 to 1000. Therefore, Final Badness Score can have a maximum of 2000, and the minimum value can be 0 by policy. **If Final Badness Score is 0, it is excluded from OOM Killer's removal targets. If adjustment value is set to -1000, Final Badness Score is always 0, so it is excluded from OOM Killer's removal targets. If Final adjustment value is 1000 or more, it is always removed by OOM Killer when OOM occurs.**

```shell {caption="[Shell 3] OOM Killer Log"}
$ System Out of Memory
[ 2826.282883] Out of memory: Kill process 4070 (stress) score 972 or sacrifice child
[ 2826.289059] Killed process 4070 (stress) total-vm:8192780kB, anon-rss:7231748kB, file-rss:0kB, shmem-rss:0kB
[ 2826.635944] oom-reaper: reaped process 4070 (stress), now anon-rss:0kB, file-rss:0kB, shmem-rss:0kB
```

When OOM Killer kills a Process, information about the killed Process is recorded in Kernel Log. Kernel Log can be checked with the `dmesg` command or `/var/log/syslog` file. [Shell 3] shows OOM Killer's Log.

### 1.1. with Cgroup

Cgroup is a Linux function that limits and monitors Resource usage of Process Groups to which multiple Processes belong. It is mainly used to limit Resource usage of Container Processes. Memory usage of Process Groups can be limited through Cgroup. When the total Memory usage of Process Groups belonging to Cgroup exceeds the allowed Memory capacity of Cgroup, OOM Killer kills Processes starting from the Process using the most Memory (highest Badness Score) in that Process Group to secure Memory.

```shell {caption="[Shell 4] OOM Killer Log"}
$ Cgroup Out of Memory
[ 1869.151779] Memory cgroup out of memory: Kill process 27881 (stress) score 1100 or sacrifice child
[ 1869.155654] Killed process 27881 (stress) total-vm:8192780kB, anon-rss:7152284kB, file-rss:4kB, shmem-rss:0kB
[ 1869.434078] oom-reaper: reaped process 27881 (stress), now anon-rss:0kB, file-rss:0kB, shmem-rss:0kB
```

[Shell 4] shows Kernel Log that occurs when OOM Killer kills a Process because Processes belonging to Cgroup use more Memory than Cgroup's allowed Memory usage. In Kernel Log, you can see that OOM Killer killed the Process due to Cgroup's Memory limit settings. OOM Killer can also be configured not to be applied per Cgroup unit. From Linux Kernel Versions that can use Cgroup v2, OOM Killer that recognizes Cgroup can be used. OOM Killer that recognizes Cgroup finds Process Groups with the highest total Memory usage and can kill all Processes in Process Groups.

## 2. References

* [https://man7.org/linux/man-pages/man5/proc.5.html](https://man7.org/linux/man-pages/man5/proc.5.html)
* [https://www.kernel.org/doc/Documentation/cgroup-v1/memory.txt](https://www.kernel.org/doc/Documentation/cgroup-v1/memory.txt)
* [https://lwn.net/Articles/761118/](https://lwn.net/Articles/761118/)
* [https://lwn.net/Articles/317814/](https://lwn.net/Articles/317814/)
* [https://dev.to/rrampage/surviving-the-linux-oom-killer-2ki9](https://dev.to/rrampage/surviving-the-linux-oom-killer-2ki9)
* [https://www.scrivano.org/posts/2020-08-14-oom-group/](https://www.scrivano.org/posts/2020-08-14-oom-group/)


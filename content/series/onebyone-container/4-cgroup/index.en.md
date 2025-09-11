---
title: 4. Cgroup
---

## Cgroup

Cgroup is a Linux kernel function used to **limit** container resource usage and **monitor** current resource usage. Here, resources refer to CPU, Memory, Network Device, and Block Device. Cgroup has various types, and each Cgroup type is responsible for specific resources. Representative Cgroup types are as follows:

* cpuset : Limits the CPU cores that containers can use.
* cpu, cpuacct : Limits the CPU usage rate that containers can use and monitors the container's CPU usage rate.
* memory : Limits the memory usage that containers can use and monitors the container's memory usage.
* net-cls, net-prio : Limits the bandwidth usage rate of network devices that containers can use.
* blkio : Limits the bandwidth usage rate of block devices that containers can use and monitors the container's block device usage rate.
* device : Limits the devices (Character, Block, GPU) that containers can use.

{{< figure caption="[Figure 1] Host, Container Cgroup" src="images/cgroup.png" width="900px" >}}

[Figure 1] shows the relationship between Host and Container processes from a Cgroup perspective. **Each process must belong to all Cgroup types.** All Cgroup types form a hierarchy, and Host processes use the highest level Cgroup. The Cgroup hierarchy relationship will be explained together when explaining the Cgroup control process. Among Cgroup types, only the cpuset, cpu, cpuacct, and memory Cgroup types, which are mainly used CPU and memory-related Cgroup types, will be explained later.

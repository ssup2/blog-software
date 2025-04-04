---
title: 4. Cgroup
---

## Cgroup

Cgroup은 Container의 Resource 사용을 **제한**하고 현재의 Resource 사용을 **Monitoring** 하는데는 이용되는 Linux Kernel의 기능이다. 여기서 Resource는 CPU, Memory, Network Device, Block Device를 의미한다. Cgroup은 여러 Type이 존재하며 각 Cgroup Type은 특정 Resource를 담당한다. 대표적인 Cgroup Type들은 다음과 같다.

* cpuset : Container가 이용할 수 있는 CPU Core를 제한한다.
* cpu, cpuacct : Container가 이용할 수 있는 CPU 사용률을 제한하고, Container의 CPU 사용률을 Monitoring 한다.
* memory : Container가 이용할 수 있는 Memory 사용량을 제한하고, Container의 Memory 사용량을 Monitoring 한다.
* net-cls, net-prio : Container가 이용할 수 있는 Network Device의 Bandwidth 사용률을 제한한다.
* blkio : Container가 이용할 수 있는 Block Device의 Bandwidth 사용률을 제한하고, Container의 Block Device의 사용률을 Monitoring 한다.
* device : Container가 이용할 수 있는 Device(Character, Block, GPU)를 제한한다.

{{< figure caption="[Figure 1] Host, Container Cgroup" src="images/cgroup.png" width="900px" >}}

[Figure 1]은 Cgroup 관점에서의 Host와 Container의 Process들의 관계를 나타내고 있다. **각 Process는 반드시 모든 Cgroup의 Type에 소속되어야 한다.** 모든 Cgroup Type들의 Cgroup은 계층을 이루며, Host Process는 가장 높은 계층의 Cgroup을 이용한다. Cgroup 계층 관계는 Cgroup 제어과정을 설명할때 같이 설명할 예정이다. Cgroup Type 중에서 주로 이용되는 CPU, Memory 관련 Cgroup Type인 cpuset, cpu, cpuacct, memory Cgroup Type에 대해서만 뒤에서 설명할 예정이다.

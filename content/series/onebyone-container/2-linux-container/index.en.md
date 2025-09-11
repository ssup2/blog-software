---
title: 2. Linux Container
---

## Linux Container Components

{{< figure caption="[Figure 1] Linux Kernel Features Used to Build Containers" src="images/linux-kernel-features-for-container.png" width="500px" >}}

Containers are built by combining various Linux kernel features. [Figure 1] is a diagram that categorizes the Linux kernel features used to build containers by topic. One of the basic characteristics of containers is isolation between containers. When two containers run on one host, each container does not know about the existence of the other. This characteristic is expressed as isolation and is implemented through a feature called Namespace.

Namespace can prevent containers from knowing about each other's existence, but it cannot control the resource usage of containers. The action of limiting the resources that each container can use is implemented through a feature called Cgroup. Cgroup also performs monitoring functions that measure the resource usage rate of each container. Image refers to a collection of files necessary for running applications inside containers. Images are generally configured using special file systems such as AUFS and OverlayFS so that applications inside containers can use them.

Security refers to methods for restricting the behavior of applications inside containers. Security uses Linux's capability, seccomp, and LSM (Linux Security Module) functions that were commonly used to restrict the behavior of applications (processes) in existing Linux. This article is structured to help understand containers by introducing the Linux kernel features listed in [Figure 1] one by one.

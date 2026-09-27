---
title: Virtual Machine, Linux Container
---

## 1. Virtual Machine

{{< figure caption="[Figure 1] Virtual Machine" src="images/virtual-machine.png" width="500px" >}}

A **Virtual Machine** means a machine that uses **virtual resources** rather than actual physical resources. The program that provides virtual resources to the Virtual Machine so that it can operate, and manages the Virtual Machine, is called a Hypervisor (beyond a Supervisor) or a VMM (Virtual Machine Monitor). The Hypervisor provides the Virtual Machine with three kinds of virtual resources: virtual CPU, virtual Memory, and virtual Device. A Virtual Machine running on top of virtual resources in this way has flexibility because it is not tied to a specific physical machine. Based on this flexibility, the Virtual Machine has established itself as the foundational technology of IaaS.

The x86 Architecture CPUs used in most servers do not satisfy the Architecture conditions under which a Hypervisor can run (the conditions of the paper Formal Requirements for Virtualizable Third Generation Architectures). To solve this problem, Intel provides the Vt-x Extension feature. Using the Vt-x Extension, the Hypervisor provides virtual CPU and virtual Memory to the Virtual Machine without significant Overhead. The ARM Architecture also provides the ARM Hypervisor Extension feature to solve a similar problem.

The problem is the virtual Device. A typical Device is designed to be used exclusively by a single System. Therefore, the Hypervisor controls the actual Device, and provides the Virtual Machine with a virtual Device that the Hypervisor emulates. In the KVM + QEMU Hypervisor combination used in Linux, QEMU is in charge of this Device Emulation part. Because the Device must be emulated, the I/O performance of the Virtual Machine is greatly degraded compared to the physical machine. To reduce this Device Emulation Overhead, technologies such as Para-virtualized Device Drivers (VirtIO/Xen Split Device Driver Model), IOMMU, and SR-IOV are used.

## 2. Linux Container

{{< figure caption="[Figure 2] Linux Container" src="images/linux-container.png" width="500px" >}}

**Linux Container** is a virtualization technology provided by the Linux Kernel. A Container is created using two features provided by Linux: Namespace and Cgroup. Strictly speaking, a Container is an **Isolation technology** rather than a virtualization technology. Each Container runs Applications in an isolated space. The Containers and the Host share the same Kernel. Therefore, each Container can only use the physical CPU, physical Memory, and physical Device that the Host Kernel uses. In addition, a Container can only use Linux-based operating systems such as Ubuntu and CentOS.

A Linux Container has a structure that uses the physical CPU, physical Memory, and physical Device that the actual Host uses, instead of the virtual CPU, virtual Memory, and virtual Device provided by the Hypervisor. Therefore, a Linux Container incurs almost no Overhead for running virtual resources. This is the main reason why Linux Containers are Light-weight compared to Virtual Machines. However, because the Isolation between the Linux Container and the Host is not perfect, current Clouds protect the Host by running Linux Containers on top of Virtual Machines.

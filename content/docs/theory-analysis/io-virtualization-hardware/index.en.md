---
title: I/O Virtualization Hardware
---

This post analyzes the Hardware I/O virtualization technique among the I/O virtualization techniques of the Hypervisor.

## 1. Hardware I/O Virtualization

The **Hardware I/O Virtualization** technique is, as the name suggests, a technique that virtualizes the I/O Device used by a virtual machine with the help of Hardware features. The Software I/O virtualization technique shows a large I/O performance degradation compared to a physical machine due to the Overhead caused by the Device Emulation process and the I/O Data delivery process. The Hardware I/O Virtualization technique performs Device Emulation and I/O Data delivery using Hardware features, so it has the advantage that there is almost no I/O performance degradation for the virtual machine.

I/O Data delivery is performed through the **IOMMU** feature of the CPU. The Device Emulation process is performed through the **SR-IOV (Single Root IO Virtualization)** feature of the I/O Device. Most CPUs released today include the IOMMU feature. However, the price of an I/O Device with SR-IOV applied is currently much higher than that of a regular I/O Device.

## 2. IOMMU

{{< figure caption="[Figure 1] IOMMU Role" src="images/iommu.png" width="650px" >}}

Through the CPU's IOMMU, a virtual machine can directly exchange I/O Data with an I/O Device without the Hypervisor's intervention. [Figure 1] briefly shows the role of the IOMMU. Intel's Vt-d is a technique based on the IOMMU.

{{< figure caption="[Figure 2] IOMMU Flow" src="images/iommu-mmu-flow.png" width="650px" >}}

The IOMMU performs a different role from the MMU. The MMU is a device that translates the Memory address seen by the CPU. The IOMMU is a device that translates the Memory address seen by the I/O Device. [Figure 2] shows the process in which the Memory addresses seen by the CPU and the I/O Device are translated through the MMU and the IOMMU. The MMU is located in the CPU Core and translates Memory addresses. In contrast, the IOMMU is located in the CPU's North-Bridge and translates the Memory address seen by the I/O Device.

{{< figure caption="[Figure 3] IOMMU Page Walk" src="images/iommu-page-walk.png" width="900px" >}}

[Figure 3] shows the Memory address translation process of the IOMMU. A PCI Device has two identifiers: a Device Number and a Function Number. One PCI Device can have multiple Functions. From the perspective of a general User, one Function is recognized as one PCI Device. Looking at the IOMMU address translation process, it uses a **two-stage Page Walk** that performs one Page Walk with the Device Number + Function Number, and one more Page Walk with the Memory address. This means that although there is only one IOMMU in the CPU, it can actually be configured so that each PCI Device Function sees a different Memory address.

The Memory used by a virtual machine uses a virtual Memory address provided by the Hypervisor, not an actual physical Memory address. This is the same principle as the operating system making each Process use a virtual Memory address instead of a physical Memory address through the CPU's MMU. Generally, in an environment where a Hypervisor is used, the actual physical Memory address used by the Hypervisor is called the Host Address, the virtual Memory address used by the virtual machine is called the Physical Address, and the Memory address used by a Process of the virtual machine is called the Virtual Address.

A virtual machine does not recognize that the Memory address it uses is a virtualized Memory address. Therefore, when configuring the DMA (Direct Access Memory) Controller of an I/O Device, the virtual machine sets the DMA address based on the Physical Address that the virtual machine sees. The problem is that the DMA Controller of the I/O Device basically performs DMA based on the Host Address, which is the actual physical address. The IOMMU is used to solve this problem. The Hypervisor uses the IOMMU to configure the DMA Controller of the I/O Device to see the Physical Address that the virtual machine sees.

When the DMA Controller of the I/O Device sees the virtual machine's Physical Address through the IOMMU, the I/O Device Data is delivered directly to the virtual machine through DMA, so the Hypervisor cannot intervene in the I/O Device Data delivery. In other words, this IOMMU configuration process can be described as the process of **assigning** an I/O Device so that only a specific virtual machine can use it. Since the IOMMU can be configured so that each PCI Device Function sees a different Memory address, the PCI Device Functions that the Hypervisor can recognize can be assigned to different virtual machines.

Although the IOMMU makes it possible to perform I/O Data delivery between a virtual machine and an I/O Device without the Hypervisor's intervention, in the case of an I/O Interrupt, the Hypervisor must receive it first and then deliver it again to the vCPU of the corresponding virtual machine. There is a technique that delivers the I/O Interrupt directly to the corresponding virtual machine, but it has many restrictions, so most Hypervisors do not use it.

## 3. SR-IOV (Single Root IO Virtualization)

{{< figure caption="[Figure 4] SR-IOV" src="images/sr-iov.png" width="450px" >}}

It is a virtualization technique that makes one I/O Device appear to the Host as **multiple I/O Devices**. [Figure 4] briefly shows the structure of an SR-IOV Device. An SR-IOV Device consists of one PF (Physical Function) and multiple VFs (Virtual Functions). In the case of a general Device, only the PF exists and no VF exists. From the Hypervisor's perspective, each VF can be used like a single I/O Device.

## 4. IOMMU + SR-IOV Device

{{< figure caption="[Figure 5] IOMMU + SR-IOV" src="images/sr-iov+iommu.png" width="650px" >}}

[Figure 5] shows the Hardware I/O virtualization technique using IOMMU + SR-IOV. Through SR-IOV, the Hypervisor can use one I/O Device as if it were multiple I/O Devices. The I/O Device (VF) virtualized through SR-IOV is assigned to each VM through the IOMMU. When a virtual machine performs I/O, the Hypervisor only needs to deliver the I/O Device's Interrupt to the virtual machine. It is also possible to provide the PF and VFs of an SR-IOV Device to virtual machines by virtualizing them once more using the Software I/O virtualization technique, without applying the IOMMU.

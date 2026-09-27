---
title: I/O Virtualization Software
---

This post analyzes Software I/O virtualization techniques among the I/O virtualization techniques of the Hypervisor.

## 1. Software I/O Virtualization

{{< figure caption="[Figure 1] Software IO Virtualization" src="images/software-io-virtualization.png" width="650px" >}}

**Software I/O Virtualization** is a technique based on **Emulation**. Using the hardware features of the CPU (Intel VT-x, ARM Hypervisor Extension), the Hypervisor configures the system so that an Exception is raised and the Hypervisor is executed the moment the Device Driver of a virtual machine issues an I/O request. When the Exception occurs and the Hypervisor runs, the Hypervisor figures out which I/O operation the virtual machine was trying to perform, performs I/O Device Emulation, and returns the result to the virtual machine. Since virtual machine I/O incurs two major Overheads, Exception and Emulation, it becomes a cause of significantly lowering the I/O performance of the virtual machine. To solve this problem, there is a technique that uses a Device Driver dedicated to virtual machines instead of the Device Driver originally running on the physical machine. The technique that uses the Device Driver of the physical machine as-is is called I/O Full-virtualization, and the technique that uses a virtual machine dedicated Device Driver is called I/O Para-virtualization.

## 2. I/O Full-virtualization

I/O Full-virtualization refers to the technique of using the Device Driver of the physical machine as-is. In the KVM+QEMU combination widely used on Linux, QEMU performs the Device Emulation role.

{{< figure caption="[Figure 2] I/O Process of KVM + QEMU" src="images/kvm-qemu-io-process.png" width="650px" >}}

[Figure 2] shows the I/O Full-virtualization process in KVM+QEMU. The figure shows that QEMU uses two Threads: vCPU and Main Loop. When the vCPU Thread, while executing the Device Driver of the Guest (virtual machine), requests an I/O operation, an Exception occurs and the KVM Module of the Host (physical machine) is executed. The KVM Module delivers to QEMU the reason why the Exception occurred. Based on the delivered content, QEMU issues the I/O request to the actual I/O Device. When the processing is finished, QEMU commands the KVM Module through `irqfd` to Inject a Virtual IRQ into the Guest. The virtual machine that receives the Virtual IRQ considers that the I/O it requested has been completed.

On a physical machine, I/O processing proceeds in the order of Application -> Device Driver -> Device -> request completion IRQ raised -> Device Driver -> Application. In I/O processing on a virtual machine, KVM+QEMU intervenes between the Device Driver and the request completion IRQ to perform Device Emulation. Therefore, the virtual machine does not recognize that the Device it uses is a virtual Device.

{{< figure caption="[Figure 3] I/O Devices Seen by a KVM + QEMU Virtual Machine" src="images/kvm-qemu-device.png" width="900px" >}}

[Figure 3] shows the PCI devices and SCSI devices visible inside an x86 virtual machine of QEMU+KVM. QEMU emulates not only devices such as NICs and HDDs but also all the Devices essential for running an x86 virtual machine, such as the PCI Bridge and IDE Controller.

## 3. I/O Para-virtualization

I/O Para-virtualization is a technique in which the virtual machine uses a **virtual machine dedicated Device Driver** instead of the Device Driver of the physical machine. Looking at the process of I/O Full-virtualization, it can be seen that all I/O of the virtual machine passes through the Device Emulation Layer (QEMU). This means that the Device Emulation process and the I/O Data transfer process between the virtual machine and the Device Emulation Layer become the major Overheads of virtual machine I/O. The virtual machine dedicated Device Driver is a technique that reduces these Overheads and improves the I/O performance of the virtual machine. KVM's VirtIO and Xen's Split Device Driver correspond to I/O Para-virtualization techniques.

The virtual machine dedicated Device Driver is a Device Driver specialized for I/O Data communication between the virtual machine and the Device Emulation Layer. Compared to when the virtual machine uses the physical machine Device Driver, the Emulation Overhead is reduced and fewer Exceptions of the virtual machine occur. Therefore, the I/O Para-virtualization technique not only improves the I/O performance of the virtual machine but also has the effect of reducing the CPU utilization of the Host caused by Emulation.

#### 3.1. VirtIO

{{< figure caption="[Figure 4] Virtio Architecture" src="images/virtio-architecture.png" width="600px" >}}

[Figure 4] briefly shows the Architecture of VirtIO. VirtIO largely consists of three parts: the VirtIO Driver as the Frontend part, the VirtIO Device Emulator as the Backend part, and the Virtqueue connecting the Frontend and the Backend. The VirtIO Driver is a Device Driver loaded into the Kernel of the virtual machine. There are various VirtIO Device Drivers; representative ones are `virtio-net` for Network and `virtio-blk`, `virtio-scsi` for Block devices. QEMU is in charge of the VirtIO Device Emulator. The Virtqueue is located in the shared memory of the virtual machine and QEMU and performs the role of delivering the I/O Data of the virtual machine between the Frontend and the Backend.

{{< figure caption="[Figure 5] I/O Process of KVM + QEMU + VirtIO" src="images/kvm-qemu-virtio-process.png" width="650px" >}}

[Figure 5] shows the I/O Para-virtualization process in KVM+QEMU+VirtIO. The virtual machine requests I/O through the VirtIO Device Driver. The VirtIO Device Driver raises an Exception through an operation called Kick and wakes up KVM. KVM in turn wakes up QEMU's Main Loop using `ioeventfd`. The awakened QEMU writes the I/O Data in the VirtIO Queue to the actual I/O Device and writes the response back to the Virtqueue. After that, QEMU commands the KVM Module through `irqfd` to Inject a Virtual IRQ into the Guest, finishing the I/O processing of the virtual machine.

{{< figure caption="[Figure 6] Block Device Seen by a KVM + QEMU + VirtIO Virtual Machine" src="images/kvm-qemu-virtio-device-blk.png" width="900px" >}}

{{< figure caption="[Figure 7] SCSI Device Seen by a KVM + QEMU + VirtIO Virtual Machine" src="images/kvm-qemu-virtio-device-scsi.png" width="900px" >}}

[Figure 6] and [Figure 7] show the PCI devices and SCSI devices visible inside an x86 virtual machine of QEMU+KVM+Virtio. It can be seen that there are VirtIO devices among the PCI devices. In the case of `virtio-scsi`, it can be seen that it is also recognized as a SCSI device.

#### 3.2. vhost

vhost is a **Kernel Module** that performs the Virtio Device Emulation role of QEMU. Looking at the I/O processing of the virtual machine described so far, it can be seen that not only the Exceptions of the virtual machine but also many CPU Mode Switches occur between KVM <-> QEMU and QEMU <-> Host Device Driver. To reduce this Mode Switch Overhead, vhost performs Virtio Device Emulation in a Kernel Module.

In addition, since QEMU serializes the Device Emulation process through a Global Mutex, it has the disadvantage that I/O performance drops significantly when the virtual machine performs many I/O requests at the same time. Using vhost also brings a performance improvement of VirtIO because VirtIO Device Emulation is performed outside QEMU's Global Mutex.

{{< figure caption="[Figure 8] I/O Process of KVM + QEMU + VirtIO + vhostnet" src="images/kvm-qemu-virtio-vhostnet-progress.png" width="650px" >}}

{{< figure caption="[Figure 9] I/O Process of KVM + QEMU + VirtIO + vhostscsi" src="images/kvm-qemu-virtio-vhostscsi-progress.png" width="650px" >}}

[Figure 8] and [Figure 9] show the I/O Para-virtualization process in KVM+QEMU+VirtIO+vhost. It can be seen that vhost performs the VirtIO Device Emulation role instead of QEMU. The rest of the process is the same as when using only VirtIO. `vhost-net` performs the Emulation role of `virtio-net`, and `vhost-scsi`+LIO performs the Emulation role of `virtio-scsi`.

{{< figure caption="[Figure 10] Devices Seen by a KVM + QEMU + VirtIO + vhost Virtual Machine" src="images/kvm-qemu-virtio-vhost-device.png" width="900px" >}}

[Figure 10] shows the PCI devices and SCSI devices visible inside an x86 virtual machine of QEMU+KVM+Virtio+vhost. It can be seen that LIO is recognized among the SCSI devices.

## 4. References
* QEMU : [http://blog.vmsplice.net/2011/03/qemu-internals-overall-architecture-and.html](http://blog.vmsplice.net/2011/03/qemu-internals-overall-architecture-and.html)

---
title: KVM, QEMU
---

Overview of KVM and QEMU as hypervisors on Linux.

## 1. KVM (Kernel-based Virtual Machine)

KVM is a Type 1 hypervisor provided by Linux. You can use it when Linux is installed on the host and the physical CPU supports hardware virtualization. Most x86 CPUs used in desktops and servers support features such as VT-x and VT-d, so with Linux installed you can install and use KVM easily. KVM alone cannot run a full virtual machine, because it only provides the guest’s **vCPU (virtual CPU)** and **memory**. A VM also needs peripherals such as disks and display output, and buses such as PCI to connect them to the CPU. **QEMU** is what supplies those virtual peripherals and PCI buses to the VM.

## 2. QEMU

QEMU is an **emulator**. It emulates devices from the vCPU through peripherals. **KVM** hands the PCI bus and devices that QEMU models to the VM so the guest can run. **Xen** does the same: it assigns QEMU’s PCI bus and devices to the VM. QEMU can emulate vCPUs as well, so it can run VMs without KVM or Xen. Because of vCPU emulation overhead and QEMU’s design, a QEMU-only VM is usually very slow. Running **KVM + QEMU** together is therefore preferable.

### 2.1. QEMU Architecture

QEMU uses a **hybrid** design that combines parallel and event-driven styles. In a **parallel** architecture, each request may spawn a thread for concurrent work. That improves responsiveness, but more threads mean more context-switch overhead and lower overall throughput. An **event-driven** architecture uses one main loop that polls for events and dispatches them to handlers. A single thread reduces context switching, but if a handler runs too long, overall event responsiveness suffers.

QEMU handles most events and related work on one **main loop** thread and offloads CPU-intensive work to **worker** threads. The main loop uses file descriptors to wait on and process events. When a worker finishes, it notifies the main loop and exits. For guest vCPUs, QEMU can either run them on the main loop or on dedicated threads—the former is called **non-iothread** mode, the latter uses **iothreads**.

#### 2.1.1. QEMU with non-iothread

{{< figure caption="[Figure 1] QEMU structure using non-iothread" src="images/qemu-non-iothread.png" width="900px" >}}

In **non-iothread** mode, the main loop handles both vCPU work and device events—one thread multiplexes vCPU execution and most device emulation. **TCG** is QEMU’s module that emulates the vCPU. As in [Figure 1], even with two vCPUs the main loop time-slices them on a single thread, so multiple vCPUs do not truly run in parallel. Non-iothread guests can therefore be quite slow. This was QEMU’s early architecture.

#### 2.1.2. QEMU with iothread

{{< figure caption="[Figure 2] QEMU structure using iothread" src="images/qemu-iothread.png" width="900px" >}}

In **iothread** mode, the main loop focuses on events while each vCPU gets its own thread. Device emulation can run from the main loop or from vCPU threads. With many threads, device emulation *appears* more parallel, but much of QEMU’s device code is not thread-safe and is serialized behind a **global mutex**, so it does not scale in parallel. That serialization is a major reason guest I/O performance can be limited.

The situation for vCPUs is similar: separate threads suggest parallelism, but **TCG**’s design keeps effective parallel vCPU execution low. Iothread-only TCG is still not enough for high-performance VMs.

#### 2.1.3. QEMU with iothread and KVM

{{< figure caption="[Figure 3] QEMU structure using iothread and KVM" src="images/qemu-kvm.png" width="900px" >}}

Here, **KVM** runs the guest vCPUs instead of **TCG**, while iothreads (and the main loop) still handle QEMU’s device model. Device emulation may still be serialized as above, but **each vCPU is executed in parallel by the host** via KVM. That is why **QEMU + KVM** is needed for a proper SMP guest.

## 3. References

QEMU : [http://blog.vmsplice.net/2011/03/qemu-internals-overall-architecture-and.html](http://blog.vmsplice.net/2011/03/qemu-internals-overall-architecture-and.html)

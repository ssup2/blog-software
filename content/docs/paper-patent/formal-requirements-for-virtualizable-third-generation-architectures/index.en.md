---
title: Formal Requirements for Virtualizable Third Generation Architectures
---

## 1. Summary

This is the first paper that defines virtual machines (VM) and hypervisors (Hypervisor, VMM). It classifies instructions and explains the conditions of CPU architecture required for hypervisors to run.

## 2. Hypervisor Configuration

Hypervisors basically operate in a **trap-and-emulation** method. When a virtual machine tries to perform operations related to specific resources, a trap occurs and the hypervisor is executed. The hypervisor identifies the cause of the trap and then makes the virtual machine feel as if it is running on an actual physical machine through appropriate emulation. Therefore, hypervisors can be divided into the following three modules.

* Dispatcher : A module that runs when a hardware trap occurs. Executes Allocator or Interpreter.
* Allocator : Performs the role of allocating/releasing resources according to virtual machine requests.
* Interpreter : Emulates instructions that cause traps.

## 3. Types of Instructions

* Privileged Instruction : Instructions that cause traps when executed in User Mode and execute without traps when executed in System Mode.
* Control Sensitive Instruction : Instructions that change resource settings.
* Behavior Sensitive Instruction : Instructions that depend on resource settings.

## 4. Types of CPU Architecture Required to Run Hypervisors

All sensitive instructions that set resources or depend on resources must be included in Privileged Instructions. If some sensitive instructions are not Privileged Instructions, hardware traps that jump to the hypervisor will not occur when virtual machines modify resources through those Privileged Instructions or perform resource-dependent instructions. If hardware traps do not occur, hypervisors are not executed, so they cannot perform appropriate emulation for virtual machines.

Since some sensitive instructions in x86 and ARM architectures are not Privileged Instructions, x86 and ARM architectures are not suitable for running hypervisors. To solve this problem, Intel added an extension called Intel-VTx, and ARM added a Hypervisor Extension. Both extensions added a Hypervisor Mode for hypervisors below the Supervisor Mode level, and were designed so that traps occur in Hypervisor Mode where hypervisors run when virtual machines perform problematic sensitive instructions.

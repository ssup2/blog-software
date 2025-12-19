---
title: Linux BPF
---

Analyze Linux BPF (Berkeley Packet Filter).

## 1. BPF

BPF (Berkeley Packet Filter) is a lightweight **VM (Virtual Machine)** that operates according to Bytecode at the **Kernel Level** of Unix-like OS. BPF was literally a VM for running Programs that filter Network Packets initially. However, BPF has steadily developed due to its advantage of being able to run Programs that perform functions desired by users at the Kernel Level at any time, and it has now become a VM that performs various functions. Currently, Linux also supports BPF.

### 1.1. cBPF (Classic BPF), eBPF (Extended BPF)

{{< figure caption="[Figure 1] cBPF, eBPF" src="images/cbpf-ebpf.png" width="900px" >}}

[Figure 1] shows cBPF (Classic BPF) and eBPF (Extended BPF). As BPF performed various functions, BPF's very limited Resources became a major obstacle. To solve BPF's Resource problems, Linux defined **eBPF** (Extended BPF), which can use more Resources and functions. When eBPF was defined, the existing BPF is called **cBPF** (Classic BPF).

In cBPF, only 2 32-bit Registers and 16 32-bit Scratch Pads that serve as memory could be used. However, in eBPF, 11 64-bit Registers, 512 8-bit Stacks, and unlimited Maps that can store Key-Value pairs can be used. Also, additional Bytecode that can be executed was added, so in eBPF, **Kernel Helper Functions** provided by the Kernel for eBPF support can be called or other eBPF Programs can be called. As eBPF can use more resources and functions than cBPF, it can run Programs with more diverse functions than cBPF.

Currently, Linux uses both cBPF and eBPF, and which BPF is used is determined according to the **Hook**, which is the point where BPF runs, and the Kernel Version. The Kernel Version where the `bpf()` System Call was added is 3.18, and all BPF before Version 3.18 is cBPF. For example, BPF used through the SO-ATTACH-FILTER Option of the Socket() System Call or the SECCOMP-SET-MODE-FILTER Option of the Seccomp() System Call were all cBPF. BPF added after Version 3.18 is all eBPF. With the introduction of eBPF, cBPF is currently only used in some areas, and eBPF is expected to completely replace cBPF in the future.

Currently, in Linux, for the Socket() System Call, the SO-ATTACH-BPF Option that uses eBPF has been added. Of course, the SO-ATTACH-FILTER Option is still provided for backward compatibility. However, even when using the SO-ATTACH-FILTER Option, internally, the `bpf()` System Call is used to convert cBPF Bytecode to eBPF Bytecode and then load it into eBPF. For the Seccomp() System Call, only cBPF is still supported, but development for eBPF support is currently in progress.

### 1.2. eBPF Program Compile, bpf() System Call

{{< figure caption="[Figure 2] eBPF Program Compile, `bpf()` System Call" src="images/compile-bpf-syscall.png" width="650px" >}}

[Figure 2] shows the Compile process of eBPF Programs and the operation of the `bpf()` System Call. LLVM/clang supports eBPF as a Backend. eBPF Source Code written by developers is compiled into eBPF Bytecode through LLVM/clang. Then, eBPF Bytecode is loaded into the Kernel's eBPF using eBPF management Apps (Tools) such as tc or iproute2. eBPF management Apps internally use the `bpf()` System Call to load eBPF Bytecode into eBPF.

Since eBPF Bytecode operates at the Kernel Level, incorrectly written eBPF Bytecode can have a significant impact on the entire System. Therefore, the Kernel checks whether eBPF Bytecode is normal through a Verifier before loading eBPF Bytecode. The Verifier checks whether eBPF Bytecode references unauthorized Memory areas and whether infinite Loops occur. It also checks whether unauthorized Kernel Helper Functions are called. eBPF Bytecode that fails the check fails to load. eBPF Bytecode that passes the check is loaded into eBPF and operates. If necessary, parts of eBPF Bytecode are converted to Native Code through a JIT (Just-in-time) Compiler and operate in the Kernel.

The `bpf()` System Call not only loads eBPF Bytecode but also allows Apps to access Maps used by eBPF. Therefore, Apps and eBPF can communicate using Maps. Communication between eBPF and Apps enables eBPF to perform more diverse functions.

### 1.3. BPF Program Type, BPF Attach Type

{{< figure caption="[Figure 3] eBPF Program Type" src="images/ebpf-program-type.png" width="600px" >}}

**BPF Program Type** determines the Hook where BPF Programs can run. Therefore, BPF Program Type determines BPF Program's Input Type and Input Data. Also, BPF Program Type determines Kernel Helper Functions that BPF Programs can call. Hook is also called **BPF Attach Type**. [Figure 3] shows eBPF Program Types. As more Hooks are added to the Kernel in the future, eBPF Program Types are also expected to be added.

## 2. References

* [https://www.netronome.com/blog/bpf-ebpf-xdp-and-bpfilter-what-are-these-things-and-what-do-they-mean-enterprise/](https://www.netronome.com/blog/bpf-ebpf-xdp-and-bpfilter-what-are-these-things-and-what-do-they-mean-enterprise/)
* [https://wariua.github.io/facility/extended-bpf.html](https://wariua.github.io/facility/extended-bpf.html)
* [https://cilium.readthedocs.io/en/v1.0/bpf/?fbclid=IwAR38RyvJXSsuzWk1jaTOGR7OhlgvQezoIHRLuiUA4rG2fc-AA70yyQTvxOg#bpf-guide](https://cilium.readthedocs.io/en/v1.0/bpf/?fbclid=IwAR38RyvJXSsuzWk1jaTOGR7OhlgvQezoIHRLuiUA4rG2fc-AA70yyQTvxOg#bpf-guide)
* [https://github.com/iovisor/bcc/blob/master/docs/kernel-versions.md](https://github.com/iovisor/bcc/blob/master/docs/kernel-versions.md)
* [https://www.slideshare.net/lcplcp1/xdp-and-ebpfmaps](https://www.slideshare.net/lcplcp1/xdp-and-ebpfmaps)
* [https://www.slideshare.net/lcplcp1/introduction-to-ebpf-and-xdp](https://www.slideshare.net/lcplcp1/introduction-to-ebpf-and-xdp)
* [https://prototype-kernel.readthedocs.io/en/latest/blogposts/xdp25-eval-generic-xdp-tx.html](https://prototype-kernel.readthedocs.io/en/latest/blogposts/xdp25-eval-generic-xdp-tx.html)
* [https://www.slideshare.net/TaeungSong/bpf-xdp-8-kosslab](https://www.slideshare.net/TaeungSong/bpf-xdp-8-kosslab)
* [http://media.frnog.org/FRnOG-28/FRnOG-28-3.pdf](http://media.frnog.org/FRnOG-28/FRnOG-28-3.pdf)
* [http://man7.org/linux/man-pages/man2/bpf.2.html](http://man7.org/linux/man-pages/man2/bpf.2.html)
* [https://lwn.net/Articles/701162/](https://lwn.net/Articles/701162/)
* [https://kccncna19.sched.com/event/Uae7](https://kccncna19.sched.com/event/Uae7)
* [https://docs.cilium.io/en/v1.6/gettingstarted/host-services/](https://docs.cilium.io/en/v1.6/gettingstarted/host-services/)


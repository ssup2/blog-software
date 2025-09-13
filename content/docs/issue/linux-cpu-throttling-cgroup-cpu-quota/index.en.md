---
title: Linux CPU Throttling with CGroup CPU Quota
---

This content is organized based on the presentation at https://sched.co/Uae1.

## 1. Issue

There is an issue where processes with CPU usage limited through CGroup CPU Quota on multi-core machines are throttled and cannot properly use CPU even when CPU usage has not reached the quota. CGroup CPU Quota is used to limit container CPU usage. Therefore, this issue can apply to all environments using containers.

## 2. Solution

Since it is a problem with the Linux kernel's process scheduler, you need to use a Linux kernel with the following 3 patches applied.

* sched/fair: Fix bandwidth timer clock drift condition
  * [https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=512ac999](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=512ac999)
* sched/fair: Fix low cpu usage with high throttling by removing expiration of cpu-local slices
  * [https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=de53fd7aedb](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=de53fd7aedb)
* sched/fair: Fix -Wunused-but-set-variable warnings
  * [https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=763a9ec06c4](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=763a9ec06c4)

The kernel versions with patches applied are as follows.

* Linux Stable
  * 5.4+
* Linux Longterm
  * 4.14.154+, 4.19.84+, 5.4+
* Distro Linux Kernel
  * Ubuntu : 4.15.0-67+
  * Centos7 : 3.10.0-1062.8.1.el7+

If kernel upgrade is difficult, you can bypass the CPU throttling issue by setting the CPU Quota value higher than the desired value or not using the CPU Quota function.

## 3. References

* [https://sched.co/Uae1](https://sched.co/Uae1)
* [https://github.com/kubernetes/kubernetes/issues/70585](https://github.com/kubernetes/kubernetes/issues/70585)

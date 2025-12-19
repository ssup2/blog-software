---
title: Linux LSM
---

Analyze LSM (Linux Security Module), Linux's Security Framework.

## 1. LSM(Linux Security Module)

{{< figure caption="[Figure 1] Linux LSM Framework" src="images/linux-lsm-framework.png" width="300px" >}}

LSM is a Security Framework that provides a runtime environment for various Security Modules in Linux. Currently, techniques such as Capability, SELinux, AppArmor, and smack in Linux all use LSM. Linux Documentation describes LSM as a Framework, but actually LSM only performs the role of an **Interface** that places **Hooks** throughout Linux Kernel Code to enable the Linux Kernel to call Security Module functions. Therefore, LSM entirely depends on Security Modules for Security policies.

{{< figure caption="[Figure 2] Linux LSM Operation Process" src="images/linux-lsm-query.png" width="500px" >}}

[Figure 2] briefly shows the actual operation of LSM. The Linux Kernel encounters LSM Hooks while processing various requests from Applications or Devices. The Linux Kernel executes Security Module Hook Functions while passing through Hooks. The execution result is received only as YES/No. If Yes is received, it continues processing the request, and if No is received, it stops processing the request.

Security Modules that run on top of LSM are not Loadable Modules that can be checked with the lsmod command. Therefore, Security Modules must be compiled together during Kernel Compilation. Some Security Modules can be configured for use through Boot settings even if they are compiled together.

### 1.1. LSM with System Call

{{< figure caption="[Figure 3] Position of LSM Hook during System Call Processing" src="images/linux-lsm-system-call.png" width="900px" >}}

LSM Hooks are encountered most frequently while processing System Calls. [Figure 3] shows the processing position of LSM Hooks during the Linux Kernel's System Call processing. LSM Hooks are located inside System Call functions. Also, DAC (Discretionary Access Control), which checks file Owner and Group like `open()`, `read()`, and `write()` System Calls, is performed before LSM Hooks.

### 1.2. LSM Module Stack, Hook Head

{{< figure caption="[Figure 4] LSM Module Stack" src="images/linux-lsm-stack.png" width="250px" >}}

Various Security Modules can be placed on LSM simultaneously. This technique is called Module Stacking. [Figure 4] shows Capability Module, Yama Module, and AppArmor Module placed on LSM in order.

{{< figure caption="[Figure 5] LSM security-hook-heads structure" src="images/linux-lsm-function-pointer.png" width="900px" >}}

[Figure 5] shows how multiple Security Modules are actually placed on LSM. LSM has a Struct called **security-hook-heads**. `security-hook-heads` has Heads (Hook Heads) of Linked Lists connected to each Security Module's Hook Functions. The figure shows only a few Hook Heads such as `task-ptr`, `task-free`, and `ptrace-access-check`, but actually `security-hook-heads` has as many Hook Heads as the number of LSM Hooks.

Security Module Hook Functions are connected to Hook Heads in the order that Security Modules are placed on LSM. Since Capability Module, Yama Module, and AppArmor Module were placed on LSM in that order, Capability's, Yama's, and AppArmor's `ptrace-access-check` Hook Functions are connected to the `ptrace-access-check` Hook Head in that order. Only Capability's and Yama's Hook Functions are connected to the `task-ptr` Hook Head because AppArmor did not implement the `task-ptr` Hook Function.

The Hook Function of the Security Module placed first on LSM is executed first, and if the result of an intermediate Hook Function is No, it stops immediately without executing the next Hook Function. When the `ptrace-access-check` hook occurs in a state where Security Modules are configured as shown in [Figure 5], Capability's `ptrace-access-check` Hook Function is executed first. If the result of Capability's `ptrace-access-check` Hook Function is Yes, Yama's `ptrace-access-check` Hook Function is executed. If the result is No, it immediately exits LSM without executing Yama's next Hook Function.

```c linenos {caption="[Code 1] security-init() function", linenos=table}
/**
 * security-init - initializes the security framework
 *
 * This should be called early in the kernel initialization sequence.
 */
int --init security-init(void)
{
	int i;
	struct list-head *list = (struct list-head *) &security-hook-heads;

	for (i = 0; i < sizeof(security-hook-heads) / sizeof(struct list-head);
	     i++)
		INIT-LIST-HEAD(&list[i]);
	pr-info("Security Framework initialized\n");

	/*
	 * Load minor LSMs, with the capability module always first.
	 */
	capability-add-hooks();
	yama-add-hooks();
	loadpin-add-hooks();

	/*
	 * Load all the remaining security modules.
	 */
	do-security-initcalls();

	return 0;
}
```

[Code 1] is the initialization function of Linux Kernel's LSM. You can see that Capability and Yama are placed on LSM in that order in lines 19 ~ 21. The remaining Security Modules are placed on LSM in line 26.

## 2. References

* Linux Document : [https://www.kernel.org/doc/Documentation/security/LSM.txt](https://www.kernel.org/doc/Documentation/security/LSM.txt)
* Linux Security Module Framework : [http://www.kroah.com/linux/talks/ols-2002-lsm-paper/lsm.pdf](http://www.kroah.com/linux/talks/ols-2002-lsm-paper/lsm.pdf)
* Linux Security Modules:
General Security Support for the Linux Kernel : [http://www.kroah.com/linux/talks/usenix-security-2002-lsm-paper/lsm.pdf](http://www.kroah.com/linux/talks/usenix-security-2002-lsm-paper/lsm.pdf)


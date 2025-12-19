---
title: Linux seccomp
---

Analyze seccomp, Linux's Process Sandboxing technique.

## 1. seccomp (secure computing)

{{< figure caption="[Figure 1] seccomp Hook" src="images/seccomp-hook.png" width="700px" >}}

seccomp is a process sandboxing technique applied since Linux kernel 2.6.12. However, when actually analyzing seccomp, you can see that it is simply a **System Call Filtering** technique. [Figure 1] shows when seccomp is applied during System Call execution. seccomp filters System Calls in the Software Interrupt Handler before each system call function is actually executed. seccomp can be configured through `prctl()` System Call invocation, and after Linux Kernel version 3.17, it can also be configured using the `seccomp()` System Call.

## 2. seccomp Mode

seccomp supports 2 Modes: Strict and Filter.

### 2.1. Strict Mode

Only 4 System Calls can be used: `exit()`, `sigreturn()`, `read()`, and `write()`. If any System Call other than these 4 is called, the Process receives a `SIGKILL` Signal and terminates immediately.

```c {caption="[Code 1] seccomp Strict Mode", linenos=table}
#include <stdio.h>
#include <sys/prctl.h>
#include <linux/seccomp.h>
#include <unistd.h>

int main() {
  // Strict Mode
  prctl(PR-SET-SECCOMP, SECCOMP-MODE-STRICT);

  // Redirect stderr to stdout
  dup2(1, 2);

  // Not reached here
  printf("STRICT\n")

  return 0;
}
```

[Code 1] is Code that applies seccomp strict mode using libseccomp and calls the `dup2()` System Call. Since `dup2()` System Call is not allowed in strict mode, [Code 1] terminates without printing the STRICT string.

### 2.2. Filter Mode

Actions can be set for each System Call. The following 5 actions can be set for each System Call:

* `SECCOMP-RET-KILL` : Does not perform the System Call and immediately terminates the Process. The termination value of the Process will be `SIGSYS`. (Not `SIGKILL`)
* `SECCOMP-RET-TRAP` : Does not perform the System Call and sends a `SIGSYS` Signal to the Process. Processes that receive the `SIGSYS` Signal can Emulate System Calls.
* `SECCOMP-RET-ERRNO` : Does not perform the System Call and sets the errno value of the Thread.
* `SECCOMP-RET-TRACE` : Delivers System Call events to tracer. If tracer does not exist, returns `-ENOSYS` and does not perform the System Call.
* `SECCOMP-RET-ALLOW` : Performs the System Call.

```c {caption="[Code 2] seccomp Filter Mode", linenos=table}
#include <stdio.h>
#include <unistd.h>
#include <seccomp.h>

int main() {
  printf("step 1: unrestricted\n");

  // Init the filter
  scmp-filter-ctx ctx;
  ctx = seccomp-init(SCMP-ACT-KILL); // default action: kill

  // setup basic whitelist
  seccomp-rule-add(ctx, SCMP-ACT-ALLOW, SCMP-SYS(rt-sigreturn), 0);
  seccomp-rule-add(ctx, SCMP-ACT-ALLOW, SCMP-SYS(exit), 0);
  seccomp-rule-add(ctx, SCMP-ACT-ALLOW, SCMP-SYS(read), 0);
  seccomp-rule-add(ctx, SCMP-ACT-ALLOW, SCMP-SYS(write), 0);
  seccomp-rule-add(ctx, SCMP-ACT-ALLOW, SCMP-SYS(dup2), 0);

  // build and load the filter
  seccomp-load(ctx);

  // Redirect stderr to stdout
  dup2(1, 2);

  // Open /dev/zero
  open("/dev/zero", O-WRONLY)

  // Not reached here
  printf("FILTER\n")

  // Success (well, not so in this case...)
  return 0;
}
```

[Code 2] is Code that operates seccomp in Filter Mode using libseccomp. `SCMP-ACT-KILL` is seccomp's default policy, meaning that Processes calling unauthorized System Calls are killed. Since `dup2()` System Call is allowed, `dup2()` System Call is performed. Since `open()` System Call is not allowed, [Code 2] terminates at the `open()` System Call.

## 3. References

* seccomp Example : [https://blog.yadutaf.fr/2014/05/29/introduction-to-seccomp-bpf-linux-syscall-filter/](https://blog.yadutaf.fr/2014/05/29/introduction-to-seccomp-bpf-linux-syscall-filter/)
* seccomp Man : [http://man7.org/linux/man-pages/man2/seccomp.2.html](http://man7.org/linux/man-pages/man2/seccomp.2.html)
* Linux Document : [https://www.kernel.org/doc/Documentation/prctl/seccomp-filter.txt](https://www.kernel.org/doc/Documentation/prctl/seccomp-filter.txt)
* libseccomp Man : [http://man7.org/linux/man-pages/man3/seccomp-rule-add.3.html](http://man7.org/linux/man-pages/man3/seccomp-rule-add.3.html)


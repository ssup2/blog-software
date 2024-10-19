---
title: Linux seccomp
---

Linux의 Process Sandboxing 기법인 seccomp을 분석한다.

## 1. seccomp (secure computing)

{{< figure caption="[Figure 1] seccomp Hook" src="images/seccomp-hook.png" width="700px" >}}

seccomp은 Linux kernel 2.6.12부터 적용된 process sandboxing 기법이다. 하지만 실제로 seccomp을 분석하면 단순한 **System Call Filtering** 기법이란걸 알 수 있다. [Figure 1]은 System Call 수행시 seccomp이 적용되는 시점을 나타내고 있다. seccomp은 실제 각 system call function이 수행되기 전 Software Interrupt Handler에서 System Call을 filtering한다. seccomp은 prctl() System Call 호출을 통해 설정할 수 있으며, Linux Kernel 3.17 버전 이후에는 seccomp() System Call을 이용해서도 설정 할 수 있다.

## 2. seccomp Mode

seccomp은 Strict, Filter 2가지 Mode를 지원한다.

### 2.1. Strict Mode

exit(), sigreturn(), read(), write() 4가지의 System Call만을 이용 할 수 있다. 만약 4가지 이외의 System Call을 호출하는 경우 해당 Process는 SIGKILL Signal을 받고 바로 종료된다.

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

[Code 1]은 libseccomp을 이용하여 seccomp strick mode를 적용하고, dup2() System Call을 호출하는 Code이다. strick mode에서 dup2() System call은 허용되지 않기 때문에 [Code 1]은 STRICT 문자열을 출력하지 못하고 종료된다.

### 2.2. Filter Mode

각 System Call별로 수행 동작을 설정할 수 있다. 다음과 같이 5개의 동작을 System Call별로 설정 할 수 있다.

* SECCOMP-RET-KILL : System Call을 수행하지 않고 해당 Process를 즉시 종료 시킨다. 해당 Process의 종료 값은 SIGSYS을 갖게된다. (Not SIGKILL)
* SECCOMP-RET-TRAP : System Call을 수행하지 않고 해당 Process에게 SIGSYS Signal을 전송한다. SIGSYS Singal을 받은 Process는 System Call을 Emulation 할 수 있다.
* SECCOMP-RET-ERRNO : System Call을 수행하지 않고 해당 Thread의 errno 값을 설정한다.
* SECCOMP-RET-TRACE : tracer에게 System Call 이벤트를 전달한다. 만약 tracer가 존재하지 않으면 -ENOSYS를 Return하고 System Call을 수행하지 않는다.
* SECCOMP-RET-ALLOW : System Call을 수행한다.

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

[Code 2]는 libseccomp을 이용하여 seccomp을 Filter Mode로 동작시키는 Code이다. SCMP-ACT-KILL은 seccomp의 기본 정책으로써, 허용되지 않은 System Call을 호출하는 Process는 죽인다는 의미이다. dup2() System Call은 허용되었기 때문에 dup2() System Call을 수행된다. open() System Call은 허용되지 않았기 때문에 [Code 2]는 open() System Call에서 종료된다.

## 3. 참조

* seccomp Example : [https://blog.yadutaf.fr/2014/05/29/introduction-to-seccomp-bpf-linux-syscall-filter/](https://blog.yadutaf.fr/2014/05/29/introduction-to-seccomp-bpf-linux-syscall-filter/)
* seccomp Man : [http://man7.org/linux/man-pages/man2/seccomp.2.html](http://man7.org/linux/man-pages/man2/seccomp.2.html)
* Linux Document : [https://www.kernel.org/doc/Documentation/prctl/seccomp-filter.txt](https://www.kernel.org/doc/Documentation/prctl/seccomp-filter.txt)
* libseccomp Man : [http://man7.org/linux/man-pages/man3/seccomp-rule-add.3.html](http://man7.org/linux/man-pages/man3/seccomp-rule-add.3.html)

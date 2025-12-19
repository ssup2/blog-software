---
title: Linux Audit
---

Analyze Linux Audit.

## 1. Audit

{{< figure caption="[Figure 1] Linux Audit" src="images/linux-audit-architecture.png" width="900px" >}}

Linux Audit is a Linux Framework that records various security-related Events occurring in the Linux Kernel as Logs and delivers them to User Apps. It can detect Events such as Binary execution, File Access, System Calls, and Network configuration manipulation. In Audit, these security-related Events are called **Audit Events**. Audit Events occur according to **Audit Rules** registered and managed by system administrators. [Figure 1] shows the Architecture of Audit. Audit components can be largely divided into Kernel Level and User Level.

### 1.1. Kernel Level

Audit uses **System Call Hooking** by default to collect Audit Events. When an App calls a System Call, the Kernel writes **Audit Logs** for Audit Events during System Call processing and stores Audit Logs in a Queue.

```c {caption="[Code 1] Audit Context", linenos=table}
#include <iostream>
using namespace std;

template <class T>
struct audit-context {
	int		    dummy;	/* must be the first element */
	int		    in-syscall;	/* 1 if task is in a syscall */
	enum audit-state    state, current-state;
	unsigned int	    serial;     /* serial number for record */
	int		    major;      /* syscall number */
	struct timespec64   ctime;      /* time of syscall entry */
	unsigned long	    argv[4];    /* syscall arguments */
	long		    return-code;/* syscall return code */
	u64		    prio;
	int		    return-valid; /* return code is valid */
    ...
}

struct task-struct{
    ...
    struct audit-context		*audit-context;
    ...
}
```

When the Kernel writes Audit Logs, it uses **Audit Context**. Audit Context exists as the `audit-context` Structure in Linux Kernel Code and stores various information such as System Call Parameters, System Call Return Code, System Call Entry Time, Thread ID, and Thread Working Directory needed for System Call processing analysis and Audit Log writing. Since Audit Context must be maintained for each Thread, the `task-struct` Structure that stores each Thread's information has a Pointer to `audit-context`. Each Audit Context is initialized by the Kernel with System Call and Thread information before System Call processing and is cleaned up after the System Call ends.

`kauditd` is a Kernel Process that collects Audit Logs stored in the Queue and delivers them to `auditd` as Audit Events. It also receives Audit Rule-related commands through `auditctl` to configure Audit. `kauditd` communicates with `auditd` and `auditctl` using netlink (`NETLINK-AUDIT` Option). `kauditd` directly manages the netlink Connection with `auditd` and connects with only one `auditd`. That is, even if multiple `auditd` processes are running, it only delivers Audit Events to one `auditd`.

### 1.2. User Level

Multiple User Level Tools/Processes related to Audit exist. `auditd` records Audit Events received from `kauditd` in the `audit.log` file and delivers them to `audispd`. `auditctl` is used for Audit control such as adding/deleting Audit Rules by communicating with `kauditd`. `aureport` shows summary information of Audit Events that have occurred so far based on the `audit.log` file. `ausearch` searches and shows specific Audit Events based on the `audit.log` file.

`audispd` is a Child Process of `auditd` that multiplexes Audit Events received from `auditd` to `audisp` Plugin Processes, which are Child Processes of `audispd`. `audisp` Plugin refers to Binaries/Processes that receive Audit Events from `audispd`. `audispd` basically uses `af-unix` Plugin and `syslog` Plugin, but separate Plugins can also be created. The `af-unix` Plugin creates a Unix Socket file and delivers Audit Events received from `audispd` through the created Unix Socket file. The `syslog` Plugin delivers Audit Events to `syslogd` so that `syslogd` can log Audit Events. In addition, various other User Level Tools/Processes and `audisp` plugins exist.

### 1.3. Example

```shell {caption="[Shell 1] Audit Example", linenos=table}
$ auditctl -w /usr/bin/passwd -p x
$ auditctl -w /etc/shadow -p r
$ passwd root
$ ausearch -i -f /usr/bin/passwd
type=PROCTITLE msg=audit(2018년 02월 14일 15:00:53.542:312) : proctitle=passwd
type=PATH msg=audit(2018년 02월 14일 15:00:53.542:312) : item=1 name=/lib64/ld-linux-x86-64.so.2 inode=3967622 dev=08:01 mode=file,755 ouid=root ogid=root rdev=00:00 nametype=NORMAL
type=PATH msg=audit(2018년 02월 14일 15:00:53.542:312) : item=0 name=/usr/bin/passwd inode=5248751 dev=08:01 mode=file,suid,755 ouid=root ogid=root rdev=00:00 nametype=NORMAL
type=CWD msg=audit(2018년 02월 14일 15:00:53.542:312) :  cwd=/root/linux
type=EXECVE msg=audit(2018년 02월 14일 15:00:53.542:312) : argc=1 a0=passwd
type=SYSCALL msg=audit(2018년 02월 14일 15:00:53.542:312) : arch=x86-64 syscall=execve success=yes exit=0 a0=0x94e1e8 a1=0x94d4a8 a2=0x8fe008 a3=0x598 items=2 ppid=12206 pid=12403 auid=unset uid=root gid=root euid=root suid=root fsuid=root egid=root sgid=root fsgid=root tty=pts13 ses=unset comm=passwd exe=/usr/bin/passwd key=(null)

$ ausearch -i -f /etc/shadow
type=PROCTITLE msg=audit(2018년 02월 14일 15:33:57.911:363) : proctitle=passwd
type=PATH msg=audit(2018년 02월 14일 15:33:57.911:363) : item=0 name=/etc/shadow inode=1594340 dev=08:01 mode=file,640 ouid=root ogid=shadow rdev=00:00 nametype=NORMAL
type=CWD msg=audit(2018년 02월 14일 15:33:57.911:363) :  cwd=/root/linux
type=SYSCALL msg=audit(2018년 02월 14일 15:33:57.911:363) : arch=x86-64 syscall=open success=yes exit=3 a0=0x7f995dee6c9d a1=O-RDONLY|O-CLOEXEC a2=0x1b6 a3=0x80000 items=1 ppid=12206 pid=14541 auid=unset uid=root gid=root euid=root suid=root fsuid=root egid=root sgid=root fsgid=root tty=pts13 ses=unset comm=passwd exe=/usr/bin/passwd key=(null)
```

[Shell 1] is an example of setting Audit Rules on the passwd Binary that changes Linux User passwords and the /etc/shadow file that records passwords. It shows the process of setting Rules so that Audit Events occur when the passwd Binary is executed and when the /etc/shadow file is Read, and then checking the Logs left by auditd.

## 2. References

* [https://access.redhat.com/documentation/en-us/red-hat-enterprise-linux/6/html/security-guide/chap-system-auditing](https://access.redhat.com/documentation/en-us/red-hat-enterprise-linux/6/html/security-guide/chap-system-auditing)
* [https://blog.selectel.com/auditing-system-events-linux/](https://blog.selectel.com/auditing-system-events-linux/)


---
title: Linux Audit
---

Linux Audit을 분석한다.

## 1. Audit

{{< figure caption="[Figure 1] Linux Audit" src="images/linux-audit-architecture.png" width="900px" >}}

Linux Audit은 Linux Kernel에서 발생하는 다양한 보안 관련 Event를 Log로 기록하고 User App에 전달해주는 Linux Framework이다. Binary 수행, File Access, System Call, Network 설정 조작 Event들을 감지 할 수 있다. Audit에서는 이러한 보안 관련 Event를 **Audit Event**라고 명칭한다. Audit Event는 System의 관리자가 등록하고 관리하는 **Audit Rule**에 의해서 발생한다. [Figure 1]은 Audit의 Architecture를 나타내고 있다. Audit의 구성 요소는 크게 Kernel Level와 User Level로 나눌 수 있다.

### 1.1. Kernel Level

Audit은 Audit Event를 수집하기 위해서 기본적으로 **System Call Hooking**을 이용한다. App이 System Call을 호출하면 Kernel은 System Call 처리 중간 중간에 Audit Event를 위한 **Audit Log**를 작성하고 Queue에 Audit Log를 저장한다.

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

Kernel이 Audit Log를 작성할때는 **Audit Context**를 이용한다. Audit Context는 Linux Kernel Code에 `audit-context` Structure로 존재하고 있으며, System Call 처리 분석 및 Audit Log 작성에 필요한 System Call Parameter, System Call Return Code, System Call Entry Time, Thread ID, Thread Working Directory등의 다양한 정보를 저장한다. 각 Thread마다 Audit Context가 유지 되야하기 때문에 각 Thread의 정보를 저장하는 `task-struct` Structure가 `audit-context`의 Pointer를 갖는다. 각각의 Audit Context는 Kernel에 의해서 System Call 처리전 System Call 및 Thread 정보로 초기화 되고, System Call이 끝나면 정리된다.

`kauditd`는 Kernel Process로 Queue에 저장된 Audit Log들을 모아서 `auditd`에게 Audit Event로 전달하는 역할을 수행한다. 또한 `auditctl`을 통해 Audit Rule 관련 명령을 전달 받아 Audit을 설정한다. `kauditd`는 netlink(`NETLINK-AUDIT` Option)를 이용하여 `auditd`와 `auditctl`과 통신한다. `kauditd`는 `auditd`와의 netlink Connection을 직접 관리하며 오직 하나의 `auditd`와 Connection을 맺는다. 즉 여러개의 `auditd`가 동작하여도 하나의 `auditd`에게만 Audit Event를 전달한다.

### 1.2. User Level

Audit과 관련된 여러개의 User Level Tool/Process가 존재한다. `auditd`는 `kauditd`로부터 받은 Audit Event를 `audit.log`파일에 기록하고 `audispd`에게 전달한다. `auditctl`은 `kauditd`와 통신하여 Audit Rule 추가/삭제 같은 Audit 제어에 이용된다. `aureport`는 `audit.log` 파일을 기반으로 지금까지 발생한 Audit Event 요약 정보를 보여준다. `ausearch`는 `audit.log` 파일을 기반으로 특정 Audit Event를 검색하여 보여준다.

`audispd`는 `auditd`의 Child Process로써 `auditd`로부터 전달 받은 Audit Event를 `audispd`의 Child Process인 `audisp` Plugin Process들에게 Multiplexing한다. `audisp` Plugin은 `audispd`에게 Audit Event를 받는 Binary/Process를 의미한다. `audispd`는 기본적으로 `af-unix` Plugin과 `syslog` Plugin을 이용하지만 별도의 Plugin을 제작할 수도 있다. `af-unix` Plugin은 Unix Socket 파일을 생성하고 생성한 Unix Socket 파일로 `audispd`에게 받은 Audit Event를 전달한다. `syslog` Plugin은 Audit Event를 `syslogd`에게 전달하여 `syslogd`가 Audit Event를 Logging 할 수 있도록 만든다. 이 밖의 다양한 User Level Tool/Process들과 `audisp` plugin들이 존재한다.

### 1.3. Example

```shell {caption="[Shell 1] Audit 예제", linenos=table}
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

[Shell 1]은 Linux User의 Password를 변경하는 passwd Binary와 Password를 기록하는 /etc/shadow 파일에 Audit Rule을 내리는 예제이다. passwd Binary가 실행될 때와 /etc/shadow 파일이 Read될때 Audit Event가 발생하도록 Rule을 설정한 다음 auditd가 남긴 Log를 확인하는 과정을 나타내고 있다.

## 2. 참조

* [https://access.redhat.com/documentation/en-us/red-hat-enterprise-linux/6/html/security-guide/chap-system-auditing](https://access.redhat.com/documentation/en-us/red-hat-enterprise-linux/6/html/security-guide/chap-system-auditing)
* [https://blog.selectel.com/auditing-system-events-linux/](https://blog.selectel.com/auditing-system-events-linux/)

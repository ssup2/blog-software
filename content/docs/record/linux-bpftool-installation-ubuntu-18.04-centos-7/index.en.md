---
title: Linux bpftool Installation / Ubuntu 18.04, CentOS 7 Environment
---

## 1. Installation Environment

The installation environment is as follows.

### 1.1. Ubuntu

* Ubuntu 18.04.1 LTS
* Linux 4.15.0-45-generic

### 1.2. CentOS

* CentOS 7
* Linux 4.19.4-1.el7.elrepo.x86-64

## 2. Package Installation

### 2.1. Ubuntu

```shell
$ apt-get install build-essential 
$ apt-get install binutils-dev
$ apt-get install libelf-dev
```

Install libraries required for bpftool building.

### 2.2. CentOS

```shell
$ yum groupinstall "Development Tools"
$ yum install binutils-devel
$ yum install elfutils-libelf-devel
```

Install libraries required for bpftool building.

## 3. bpftool Build & Installation

```shell
$ git clone https://github.com/torvalds/linux.git
$ cd linux
$ git checkout v4.20
```

Since it is not currently provided as a package for Ubuntu and CentOS, download the kernel code and build bpftool directly. **Kernel version v4.20 or higher** is required to use bpftool's net and perf options.

```shell
$ make -C tools/bpf/bpftool/
$ cp tools/bpf/bpftool/bpftool /usr/sbin
```

Build bpftool.

### 3.1. Compile Error Resolution

```shell
$ make -C tools/bpf/bpftool/
...
/usr/include/linux/if.h:76:2: error: redeclaration of enumerator [01mIFF-NOTRAILERS
  IFF-NOTRAILERS   = 1<<5,  /* sysfs */
  ^
/usr/include/net/if.h:54:5: note: previous definition of [01mIFF-NOTRAILERSwas here
     IFF-NOTRAILERS = 0x20, /* Avoid use of trailers.  */
     ^
/usr/include/linux/if.h:77:2: error: redeclaration of enumerator [01mIFF-RUNNING
  IFF-RUNNING   = 1<<6,  /* --volatile-- */
  ^
/usr/include/net/if.h:56:5: note: previous definition of [01mIFF-RUNNINGwas here
     IFF-RUNNING = 0x40,  /* Resources allocated.  */
...
```

When a compile error occurs due to conflicts between linux/if.h and net/if.h, the above symptoms appear.

```c {caption="[File 1] tools/bpf/bpftool/net.c", linenos=table}
...
#include <libbpf.h>
//#include <net/if.h>
#include <linux/if.h>
...
```

Modify the tools/bpf/bpftool/net.c file as shown in [File 1].

## 4. References

* [https://github.com/Netronome/bpf-tool](https://github.com/Netronome/bpf-tool)
* [https://wiki.ubuntu.com/Kernel/BuildYourOwnKernel](https://wiki.ubuntu.com/Kernel/BuildYourOwnKernel)
* [https://lore.kernel.org/patchwork/patch/866970/](https://lore.kernel.org/patchwork/patch/866970/)


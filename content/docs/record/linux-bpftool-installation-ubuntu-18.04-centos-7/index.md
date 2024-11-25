---
title: Linux bpftool 설치 / Ubuntu 18.04, CentOS 7 환경
---

## 1. 설치 환경

설치 환경은 다음과 같다.

### 1.1. Ubuntu

* Ubuntu 18.04.1 LTS
* Linux 4.15.0-45-generic

### 1.2. CentOS

* CentOS 7
* Linux 4.19.4-1.el7.elrepo.x86-64

## 2. Package 설치

### 2.1. Ubuntu

```shell
$ apt-get install build-essential 
$ apt-get install binutils-dev
$ apt-get install libelf-dev
```

bpftool Build시 필요한 Library를 설치한다.

### 2.2. CentOS

```shell
$ yum groupinstall "Development Tools"
$ yum install binutils-devel
$ yum install elfutils-libelf-devel
```

bpftool Build시 필요한 Library를 설치한다.

## 3. bpftool Build & 설치

```shell
$ git clone https://github.com/torvalds/linux.git
$ cd linux
$ git checkout v4.20
```

현재 Ubuntu, CentOS의 Package로 제공되지 않고 있기 때문에 Kernel Code를 받아 직접 bpftool Build 수행한다. bfptool의 net, perf Opiton 이용을 위해서 **v4.20 이상의 Kernel Version**이 필요하다.

```shell
$ make -C tools/bpf/bpftool/
$ cp tools/bpf/bpftool/bpftool /usr/sbin
```

bpftool를 Build 한다.

### 3.1. Compile Error 해결

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

linux/if.h와 net/if.h의 충돌로 인한 Compile Error 발생시 위와 같은 증상이 나타난다.

```c {caption="[File 1] tools/bpf/bpftool/net.c", linenos=table}
...
#include <libbpf.h>
//#include <net/if.h>
#include <linux/if.h>
...
```

tools/bpf/bpftool/net.c 파일을 [File 1]과 같이 수정한다.

## 4. 참조

* [https://github.com/Netronome/bpf-tool](https://github.com/Netronome/bpf-tool)
* [https://wiki.ubuntu.com/Kernel/BuildYourOwnKernel](https://wiki.ubuntu.com/Kernel/BuildYourOwnKernel)
* [https://lore.kernel.org/patchwork/patch/866970/](https://lore.kernel.org/patchwork/patch/866970/)
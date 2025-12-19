---
title: Linux Fuse
---

Linux의 FUSE를 분석한다.

## 1. Linux FUSE (Filesystem in Userspace)

{{< figure caption="[Figure 1] Linux FUSE Architecture" src="images/linux-fuse-architecture.png" width="500px" >}}

Linux FUSE는 Filesystem in Userspace의 약자로, User Level에서 쉽게 Filesystem을 제작 할 수 있도록 도와주는 Linux 기법이다. [Figure 1]은 Linux FUSE의 전체 Architecture를 나타내고 있다. Application이 FUSE가 Mount된 폴더를 대상으로 `read(2)`, `write(2)` 같은 System Call을 호출하면, System Call은 Linux의 VFS(Virutal File System)을 지나서 Linux Kernel에 있는 **FUSE Module**에 전달된다. Fuse Module은 전달 받은 System Call의 대상 폴더와 FUSE Mount 정보를 바탕으로 해당 FUSE Daemon Process에게 System Call을 전달한다.

Fuse Daemon Process는 전달 받은 System Call을 처리 한 후 처리 결과를 Application Process에게 전달한다. Application에서 한번의 System Call이 발생 할 때 마다 2번의 IPC가 발생하기 때문에, FUSE의 성능은 일반 Filesystem에 비해서 많이 느릴 수 밖에 없다.

{{< figure caption="[Figure 2] Application과 Linux FUSE Daemon 사이의 통신과정" src="images/linux-fuse-communication.png" width="600px" >}}

[Figure 2]는 Application Process와 FUSE Daemon Process의 통신 과정을 간략하게 나타낸 그림이다. FUSE Daemon은 초기화 과정을 거친후 `/dev/fuse` Device 파일을 대상으로 `read(2)` System Call을 호출 한 뒤 Blocking 된다. 그 후 Application Process가 System Call을 호출하여 System Call이 FUSE Module로 전달 되면, FUSE Module은 Blocking된 FUSE Daemon Process를 깨우고, System Call 정보를 FUSE Daemon Process에게 전달한다.

FUSE Daemon Process는 System Call 처리 후 `/dev/fuse` Device 파일을 대상으로 `write(2)` System Call을 통해, 처리 결과를 Fuse Module을 통해 Application Process에게 전달한다. 그 후 다시 `/dev/fuse` Device 파일을 대상으로 `read(2)` System Call을 호출 하여 Application Process의 System Call을 대기한다.

FUSE Daemon을 작성하기 위해서는 FUSE Module과 FUSE Module을 조작하는 `/dev/fuse` Device 파일의 이용법을 이해해야 한다. 이러한 불편함을 없애기 위해 나온것이 `libfuse` Libraray이다. `libfuse`를 이용하면 FUSE Daemon 개발자는 FUSE Module을 이해할 필요없이 각 System Call 별로 호출되는 함수들만 작성하면 된다.

```c {caption="[Code 1] fuse-operation 구조체", linenos=table}
struct fuse-operations fuse-oper = {
  .getattr = fuse-getattr,
  .readlink = fuse-readlink,
  .open = fuse-open,
  .read = fuse-read,
  ...
};
```

[Code 1]은 libfuse에서 제공하는 fuse-operations 구조체를 나타내고 있다. FUSE Daemon 개발자는 각 System Call에 대응하는 함수들을 작성한 후 fuse-operations 구조체를 통해 작성한 함수들을 실제 System Call과 Mapping만 하면 된다.

## 2. 참조

* Linux FUSE Documentation : [https://www.kernel.org/doc/Documentation/filesystems/fuse.txt](https://www.kernel.org/doc/Documentation/filesystems/fuse.txt)
* libfuse : [https://github.com/libfuse/libfuse](https://github.com/libfuse/libfuse)
* [https://www.slideshare.net/danny00076/fuse-filesystem-in-user-space](https://www.slideshare.net/danny00076/fuse-filesystem-in-user-space)

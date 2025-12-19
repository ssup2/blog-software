---
title: Linux BPF Lifetime
---

Analyze the Lifetime of Linux BPF Programs and BPF Maps.

## 1. Linux BPF Lifetime

```c {caption="[Code 1] bpf() System Call"}
int bpf(int cmd, union bpf-attr *attr, unsigned int size)
```

Linux BPF Programs and BPF Maps are created and controlled through the `bpf()` System Call. [Code 1] shows the `bpf()` System Call. When called with the cmd Parameter set to "BPF-PROG-LOAD", it loads a BPF Program, and when called with the cmd Parameter set to "BPF-MAP-CREATE", it creates a BPF Map. The `bpf()` System Call returns a File Descriptor. Therefore, the App (Process) that called the `bpf()` System Call controls the loaded BPF Program or created BPF Map through the File Descriptor returned by the `bpf()` System Call.

BPF Programs loaded and BPF Maps created by an App (Process) through `bpf()` System Call invocations are removed together when the App terminates. There are exceptions to this, with a representative example being BPF Programs loaded through the `tc` command. The `tc` command provides functionality to Load/Unload BPF Programs of `SCHED-CLS` and `SCHED-ACT` Types, and BPF Programs loaded through the `tc` command are not removed even when the `tc` command (Process) terminates. The reason is that the tc Subsystem inside the Linux Kernel maintains references to BPF Programs loaded through the `tc` command so they are not removed.

To prevent BPF Programs loaded and BPF Maps created by an App through `bpf()` System Call invocations from being removed together when the App terminates, you can use BPFFS (BPF Filesystem) to **Pin** them. Set the cmd Parameter to `BPF-OBJ-PIN`, put the File Descriptor of the BPF Program and BPF Map to be pinned and the Path (location) where it will be pinned in the attr Parameter, and call the `bpf()` System Call. Here, the Path must be a Path included in BPFFS. File Descriptors of pinned BPF Programs and BPF Maps can be obtained by setting the cmd Parameter to `BPF-OBJ-GET`, putting the Path in the attr Parameter, and calling the `bpf()` System Call.

```shell {caption="[Shell 1] bpffs mount", linenos=table}
$ mount -t bpf bpf /sys/fs/bpf
$ mount | grep bpf
none on /sys/fs/bpf type bpf (rw,relatime)
```

BPFFS is a special Filesystem for Pinning BPF Programs and BPF Maps, and in environments using systemd, it can generally be configured to be mounted by default at the `/sys/fs/bpf` Path through settings. You can also perform the mount directly through the command in [Shell 1].

## 2. References

* BPF System Call : [https://man7.org/linux/man-pages/man2/bpf.2.html](https://man7.org/linux/man-pages/man2/bpf.2.html)
* BPFFS : [https://facebookmicrosites.github.io/bpf/blog/2018/08/31/object-lifetime.html](https://facebookmicrosites.github.io/bpf/blog/2018/08/31/object-lifetime.html)
* BPFFS : [https://github.com/cilium/cilium/blob/v1.7.12/bpf/init.sh](https://github.com/cilium/cilium/blob/v1.7.12/bpf/init.sh)
* BPFFS : [https://github.com/cilium/cilium/blob/v1.7.12/pkg/bpf/bpf-linux.go#L291](https://github.com/cilium/cilium/blob/v1.7.12/pkg/bpf/bpf-linux.go#L291)
* BPFFS : [https://www.ferrisellis.com/content/ebpf-syscall-and-maps/](https://www.ferrisellis.com/content/ebpf-syscall-and-maps/)


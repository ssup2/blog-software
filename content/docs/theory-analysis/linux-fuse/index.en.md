---
title: Linux Fuse
---

Analyze Linux FUSE.

## 1. Linux FUSE (Filesystem in Userspace)

{{< figure caption="[Figure 1] Linux FUSE Architecture" src="images/linux-fuse-architecture.png" width="500px" >}}

Linux FUSE is an abbreviation for Filesystem in Userspace, a Linux technique that helps easily create Filesystems at the User Level. [Figure 1] shows the overall Architecture of Linux FUSE. When an Application calls System Calls such as `read(2)` and `write(2)` targeting a folder mounted with FUSE, the System Calls pass through Linux's VFS (Virtual File System) and are delivered to the **FUSE Module** in the Linux Kernel. The FUSE Module delivers the System Calls to the corresponding FUSE Daemon Process based on the target folder of the received System Calls and FUSE Mount information.

The FUSE Daemon Process processes the received System Calls and then delivers the processing results to the Application Process. Since 2 IPC operations occur for each System Call from the Application, FUSE's performance is inevitably much slower compared to general Filesystems.

{{< figure caption="[Figure 2] Communication Process between Application and Linux FUSE Daemon" src="images/linux-fuse-communication.png" width="600px" >}}

[Figure 2] is a diagram that briefly shows the communication process between the Application Process and FUSE Daemon Process. After going through the initialization process, the FUSE Daemon calls the `read(2)` System Call targeting the `/dev/fuse` Device file and then Blocks. After that, when the Application Process calls a System Call and the System Call is delivered to the FUSE Module, the FUSE Module wakes up the Blocked FUSE Daemon Process and delivers System Call information to the FUSE Daemon Process.

The FUSE Daemon Process delivers processing results to the Application Process through the FUSE Module via the `write(2)` System Call targeting the `/dev/fuse` Device file after processing System Calls. Then, it calls the `read(2)` System Call targeting the `/dev/fuse` Device file again to wait for System Calls from the Application Process.

To write a FUSE Daemon, you must understand how to use the FUSE Module and the `/dev/fuse` Device file that manipulates the FUSE Module. The `libfuse` Library emerged to eliminate this inconvenience. Using `libfuse`, FUSE Daemon developers can write functions called for each System Call without needing to understand the FUSE Module.

```c {caption="[Code 1] fuse-operations structure", linenos=table}
struct fuse-operations fuse-oper = {
  .getattr = fuse-getattr,
  .readlink = fuse-readlink,
  .open = fuse-open,
  .read = fuse-read,
  ...
};
```

[Code 1] shows the fuse-operations structure provided by libfuse. FUSE Daemon developers write functions corresponding to each System Call and then only need to map the written functions to actual System Calls through the fuse-operations structure.

## 2. References

* Linux FUSE Documentation : [https://www.kernel.org/doc/Documentation/filesystems/fuse.txt](https://www.kernel.org/doc/Documentation/filesystems/fuse.txt)
* libfuse : [https://github.com/libfuse/libfuse](https://github.com/libfuse/libfuse)
* [https://www.slideshare.net/danny00076/fuse-filesystem-in-user-space](https://www.slideshare.net/danny00076/fuse-filesystem-in-user-space)


---
title: Linux Mount Propagation
---

Analyze Linux Mount Propagation.

## 1. Linux Mount Propagation

Mount Propagation is a technique that emerged to solve the inconvenience of management caused by Linux Kernel's Mount NS (Namespace). Without using Mount Propagation, in a state where multiple Mount NS exist, to use Block Devices that are not Mounted by all Processes, Block Device Mount must be performed as many times as the number of Mount NS. However, by appropriately using Mount Propagation, Block Device Mount can be performed in all Mount NS with a single Block Device Mount.

### 1.1. Shared Subtree

{{< figure caption="[Figure 1] Mount Namespace Clone" src="images/mount-ns-clone.png" width="700px" >}}

To understand Mount Propagation, you need to know the concept of Shared Subtree. Here, Subtree refers to a Filesystem that constitutes part of the Filesystem Tree. In [Figure 1], the left Filesystem Tree shows a Filesystem composed of 2 Subtrees: a Filesystem Mounted at Root and a Filesystem Mounted at /A Directory. When such Subtrees are Shared, they become Shared Subtrees.

There are 2 methods to share Subtrees: cloning Mount NS and using Bind Mount. [Figure 1] shows a method of creating Shared Subtrees by cloning Mount NS. When Mount NS is cloned using the `clone()` System Call, Mount information stored in Mount NS is also cloned as is. Since Subtrees are also cloned as is, Subtrees are shared between Mount NS. In [Figure 1], since there are 2 Subtrees, 2 Subtrees are cloned as shown. The Subtree of the original Mount NS is called Master, and the Subtree of the cloned Mount NS is called Slave.

{{< figure caption="[Figure 2] Bind Mount" src="images/bind-mount.png" width="700px" >}}

[Figure 2] shows a method of creating Shared Subtrees using Bind Mount. Using Bind Mount, Subtrees can be attached to other Directories for sharing. The original Subtree is called Master, and the Subtree shared by Bind Mount is expressed as Slave.

### 1.2. Mount Propagation

Mount Propagation literally means a technique that propagates changed Mount information. Here, the propagation range is limited to Shared Subtrees. Without using Mount Propagation, even if it is a Shared Subtree, Mount information is managed for each Subtree. Propagation of changed Mount information from Master to Slave is called Forward Propagation. Conversely, propagation of changed Mount information from Slave to Master is called Receive Propagation.

{{< figure caption="[Figure 3] Forward Propagation" src="images/forward-propagation.png" width="700px" >}}

[Figure 3] shows the process of Forward Propagation occurring in Shared Subtrees between Mount NS. The order is as follows:

* The Subtree of the original Mount NS becomes shared through the `clone()` System Call.
* The sdb Block Device was Mounted on the `/A` Directory of the Master Subtree.
* Forward Propagation occurs and the sdb Block Device is also Mounted on the `/A` Directory of the Slave Subtree.

{{< figure caption="[Figure 4] Receive Propagation" src="images/receive-propagation.png" width="700px" >}}

[Figure 4] shows the process of Receive Propagation occurring in Shared Subtrees between Mount NS. The order is as follows:

* The Subtree of the original Mount NS becomes shared through the `clone()` System Call.
* The sdb Block Device was Mounted on the `/A` Directory of the Slave Subtree.
* Receive Propagation occurs and the sdb Block Device is also Mounted on the `/A` Directory of the Master Subtree.

### 1.3. Mount Option

```shell {caption="[Shell 1] Shared Mount - Mount NS Clone"}
# Prepare Test
(Shell 1)$ mkdir ~/A
(Shell 1)$ mount --make-shared /dev/sdb ~/A
(Shell 1)$ ls ~/A
B  C
(Shell 2)$ unshare -m --propagation unchanged bash
(Shell 2)$ ls ~/A
B  C

# Forward Propagation O
(Shell 1)$ mount /dev/sdc ~/A/B
(Shell 1)$ ls ~/A/B
b
(Shell 2)$ ls ~/A/B
b

# Receive Propagation O
(Shell 2)$ mount /dev/sdd ~/A/C
(Shell 2)$ ls ~/A/C
c
(Shell 1)$ ls ~/A/C
c
```

```shell {caption="[Shell 2] Shared Mount - Bind Mount"}
# Prepare Test
$ mkdir -p ~/A/B ~/A/C
$ mount --make-shared /dev/sdb ~/A/B
$ mkdir -p ~/A/B/D ~/A/B/E
$ mount --bind ~/A/B ~/A/C
$ ls ~/A/B
D  E
$ ls ~/A/C
D  E

# Forward Propagation O
$ mount /dev/sdc ~/A/B/D
$ ls ~/A/B/D
b
$ ls ~/A/C/D
b

# Forward Propagation O
$ mount /dev/sdd ~/A/C/E
$ ls ~/A/C/E
c
$ ls ~/A/B/E
c
```

To control Forward/Receive Propagation, you must use 4 Propagation Mount Options: **Shared Mount, Slave Mount, Private Mount, and Unbindable Mount**. Shared Mount is an Option that allows both Forward and Receive Propagation. You can check the Forward/Receive Propagation behavior of Shared Mount through [Shell 1] and [Shell 2].

```shell {caption="[Shell 3] Slave Mount - Mount NS Clone"}
# Prepare Test
(Shell 1)$ mkdir ~/A
(Shell 1)$ mount --make-shared /dev/sdb ~/A
(Shell 1)$ ls ~/A
B  C
(Shell 2)$ unshare -m --propagation unchanged bash
(Shell 2)$ mount --make-slave ~/A
(Shell 2)$ ls ~/A
B  C
(Shell 2)$ make ~/

# Forward Propagation O
(Shell 1)$ mount /dev/sdc ~/A/B
(Shell 1)$ ls ~/A/B
b
(Shell 2)$ ls ~/A/B
b

# Receive Propagation X
(Shell 2)$ mount /dev/sdd ~/A/C
(Shell 2)$ ls ~/A/C
c
(Shell 1)$ ls ~/A/C
```

```shell {caption="[Shell 4] Slave Mount - Bind Mount"}
# Prepare Test
$ mkdir -p ~/A/B ~/A/C
$ mount --make-shared /dev/sdb ~/A/B
$ mkdir -p ~/A/B/D ~/A/B/E
$ mount --bind ~/A/B ~/A/C
$ mount --make-slave ~/A/C
$ ls ~/A/B
D  E
$ ls ~/A/C
D  E

# Forward Propagation O
$ mount /dev/sdc ~/A/B/D
$ ls ~/A/B/D
b
$ ls ~/A/C/D
b

# Forward Propagation X
$ mount /dev/sdd ~/A/C/E
$ ls ~/A/C/E
c
$ ls ~/A/B/E
```

Slave Mount is an Option that only allows Forward Propagation and does not allow Receive Propagation. You can check that Slave Mount only applies Forward Propagation through [Shell 3] and [Shell 4]. Slave Mount applies by changing the Master Subtree, which is a Shared Mount, to Slave Mount. You can see in [Shell 3] and [Shell 4] that Shared Subtrees are created with Shared Mount first, and then Slave Mount is applied.

```shell {caption="[Shell 5] Private Mount - Mount NS Clone"}
# Prepare Test
(Shell 1)$ mkdir ~/A
(Shell 1)$ mount --make-private /dev/sdb ~/A
(Shell 1)$ ls ~/A
B  C
(Shell 2)$ unshare -m --propagation unchanged bash
(Shell 2)$ ls ~/A
B  C

# Forward Propagation X
(Shell 1)$ mount /dev/sdc ~/A/B
(Shell 1)$ ls ~/A/B
b
(Shell 2)$ ls ~/A/B

# Receive Propagation X
(Shell 2)$ mount /dev/sdd ~/A/C
(Shell 2)$ ls ~/A/C
c
(Shell 1)$ ls ~/A/C
```

```shell {caption="[Shell 6] Private Mount - Bind Mount", linenos=table}
# Prepare Test
$ mkdir -p ~/A/B ~/A/C
$ mount --make-private /dev/sdb ~/A/B
$ mkdir -p ~/A/B/D ~/A/B/E
$ mount --bind ~/A/B ~/A/C
$ ls ~/A/B
D  E
$ ls ~/A/C
D  E

# Forward Propagation X
$ mount /dev/sdc ~/A/B/D
$ ls ~/A/B/D
b
$ ls ~/A/C/D

# Forward Propagation X
$ mount /dev/sdd ~/A/C/E
$ ls ~/A/C/E
c
$ ls ~/A/B/E
```

Private Mount is an Option that does not allow both Forward and Receive Propagation. If Propagation Mount Option is not specified during Mount, Private Mount is the Default Option. You can check through [Shell 5] and [Shell 6] that Private Mount does not allow both Forward and Receive Propagation.

```shell {caption="[Shell 7] Unbindable Mount - Mount NS Clone", linenos=table}
# Prepare Test
(Shell 1)$ mkdir ~/A
(Shell 1)$ mount --make-unbindable /dev/sdb ~/A
(Shell 1)$ ls ~/A
B  C
(Shell 2)$ unshare -m --propagation unchanged bash
(Shell 2)$ ls ~/A
B  C

# Forward Propagation X
(Shell 1)$ mount /dev/sdc ~/A/B
(Shell 1)$ ls ~/A/B
b
(Shell 2)$ ls ~/A/B

# Receive Propagation X
(Shell 2)$ mount /dev/sdd ~/A/C
(Shell 2)$ ls ~/A/C
c
(Shell 1)$ ls ~/A/C
```

```shell {caption="[Shell 8] Unbindable Mount - Bind Mount", linenos=table}
# Prepare Test
$ mkdir -p ~/A/B ~/A/C
$ mount --make-unbindable /dev/sdb ~/A/B
$ mkdir -p ~/A/B/D ~/A/B/E
$ mount --bind ~/A/B ~/A/C
mount: /root/A/C: wrong fs type, bad option, bad superblock on /root/A/B, missing codepage or helper program, or other error.
```

Unbindable Mount not only does not allow both Forward and Receive Propagation like Private Mount but also does not allow Bind Mount. Through [Shell 7] and [Shell 8], you can check that Unbindable Mount does not allow both Forward and Receive Propagation, and when Bind Mount is performed, an Error occurs to prevent Mount from being performed.

## 2. References

* [http://man7.org/linux/man-pages/man7/mount-namespaces.7.html](http://man7.org/linux/man-pages/man7/mount-namespaces.7.html)
* [https://www.kernel.org/doc/Documentation/filesystems/sharedsubtree.txt](https://www.kernel.org/doc/Documentation/filesystems/sharedsubtree.txt)
* [https://docs.docker.com/storage/bind-mounts/](https://docs.docker.com/storage/bind-mounts/)
* [https://lwn.net/Articles/689856/](https://lwn.net/Articles/689856/)


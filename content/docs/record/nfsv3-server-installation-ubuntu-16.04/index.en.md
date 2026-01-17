---
title: NFSv3 Server and Client Installation / Ubuntu 16.04 Environment
---

## 1. Installation Environment

The installation environment is as follows.
* Ubuntu 16.04 LTS 64bit, root user
* NFS Root: Refers to the absolute path of the root directory of the NFSv3 Server.
  * Use /nfs-root as NFS Root.
* NFS share: Refers to the absolute path of the directory to be actually shared through the NFSv3 Server.
  * Use /root/nfs-share as NFS share.

## 2. NFSv3 Server Configuration

### 2.1. Ubuntu Package Installation

```shell
$ sudo apt-get install nfs-kernel-server nfs-common rpcbind
```

Install the NFSv3 Server package.

### 2.2. Shared Folder Creation and Bind Mount Configuration

```shell
$ mkdir -p /nfs-root
$ mkdir -p /root/nfs-share
$ chmod 777 /root/nfs-share
$ mount --bind /root/nfs-share /nfs-root
```

Create shared folders and perform bind mount.

```text {caption="[File 1] /etc/fstab", linenos=table}
...
/root/nfs-share /nfs-root none bind  0  0
```s

Add the content from [File 1] to /etc/fstab to ensure bind mount after reboot.

### 2.3. Configuration

```text {caption="[File 2] /etc/exports", linenos=table}
/nfs-root      *(rw,nohide,insecure,no-subtree-check,async,no-root-squash)
```

Add the content from [File 2] to the /etc/exports file.

### 2.4. Restart

```shell
$ /etc/init.d/nfs-kernel-server restart
```

Restart the NFSv3 Server.

## 3. NFSv3 Client Configuration

```shell
$ apt-get install nfs-common
```

Install the NFSv3 Client package.

```shell
$ mount -t nfs localhost:/nfs-root /mnt
```

Perform NFSv3 mount.


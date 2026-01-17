---
title: NFSv4 Server, Client Installation / Ubuntu 16.04 Environment
---

## 1. Installation Environment

The installation environment is as follows.
* Ubuntu 16.04 LTS 64bit, root user
* NFS Root : Refers to the absolute path of the Root Directory of the NFSv4 Server.
  * Use /export/nfs-root as the NFS Root.
* NFS share : Refers to the absolute path of the Directory to be actually shared through the NFSv4 Server.
  * Use /root/nfs-share as the NFS share.

## 2. NFSv4 Server Configuration

### 2.1. Ubuntu Package Installation

```shell
$ sudo apt-get install nfs-kernel-server nfs-common rpcbind
```

Install the NFSv4 Server Package.

### 2.2. Shared Folder Creation and Bind Mount Configuration

```shell
$ mkdir -p /export/nfs-root
$ mkdir -p /root/nfs-share
$ chmod 777 /root/nfs-share
$ mount --bind /root/nfs-share /export/nfs-root
```

Create shared folders and perform Bind Mount.

```text {caption="[File 1] /etc/fstab", linenos=table}
...
/root/nfs-share /export/nfs-root none bind  0  0
```

Add the contents of [File 1] to /etc/fstab to ensure Bind Mount persists after reboot.

### 2.3. Configuration

```text {caption="[File 2] /etc/exports", linenos=table}
/export               *(rw,fsid=0,insecure,no-subtree-check,async,no-root-squash)
/export/nfs-root      *(rw,nohide,insecure,no-subtree-check,async,no-root-squash)
```

Add the contents of [File 2] to the /etc/exports file.

### 2.4. Restart

```shell
$ /etc/init.d/nfs-kernel-server restart
```

Restart the NFSv4 Server.

## 3. NFSv4 Client Configuration

```shell
$ apt-get install nfs-common
```

Install the NFSv4 Client Package.

```shell
$ mount -t nfs4 localhost:/nfs-root /mnt
```

Perform NFSv4 Mount.


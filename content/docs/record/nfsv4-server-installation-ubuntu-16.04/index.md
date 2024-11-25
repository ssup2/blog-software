---
title: NFSv4 Server, Client 설치 / Ubuntu 16.04 환경
---

## 1. 설치 환경

설치 환경은 다음과 같다.
* Ubuntu 16.04 LTS 64bit, root user
* NFS Root : NFSv4 Server의 Root Directory 절대 경로를 의미한다.
  * NFS Root로 /export/nfs-root를 이용한다.
* NFS share : NFSv4 Server를 통해 실제 공유할 Directory의 절대 경로를 의미한다.
  * NFS share로 /root/nfs-share를 이용한다.

## 2. NFSv4 Server 설정

### 2.1. Ubuntu Package 설치

```shell
$ sudo apt-get install nfs-kernel-server nfs-common rpcbind
```

NFSv4 Server Package를 설치한다.

### 2.2. 공유 폴더 생성 및 Bind Mount 설정

```shell
$ mkdir -p /export/nfs-root
$ mkdir -p /root/nfs-share
$ chmod 777 /root/nfs-share
$ mount --bind /root/nfs-share /export/nfs-root
```

공유 폴더 생성 및 Bind Mount를 수행한다.

```text {caption="[File 1] /etc/fstab", linenos=table}
...
/root/nfs-share /export/nfs-root none bind  0  0
```

/etc/fstab에 다음 [File 1]의 내용을 추가하여 재부팅 후에도 Bind Mount 되도록 설정한다.

### 2.3. 설정

```text {caption="[File 2] /etc/exports", linenos=table}
/export               *(rw,fsid=0,insecure,no-subtree-check,async,no-root-squash)
/export/nfs-root      *(rw,nohide,insecure,no-subtree-check,async,no-root-squash)
```

/etc/exports 파일에 [File 2]의 내용을 추가한다.

### 2.4. Restart

```shell
$ /etc/init.d/nfs-kernel-server restart
```

NFSv4 Server를 재시작한다.

## 3. NFSv4 Client 설정

```shell
$ apt-get install nfs-common
```

NFSv4 Client Package를 설치한다.

```shell
$ mount -t nfs4 localhost:/nfs-root /mnt
```

NFSv4 Mount를 수행한다.

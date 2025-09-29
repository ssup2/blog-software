---
title: Auto Root User Login Configuration / Ubuntu 14.04 Environment
---

## 1. Configuration Environment

The configuration environment is as follows:
* Ubuntu 14.04 LTS 64bit, root user

## 2. root Password Configuration

```shell
$ sudo passwd root
Enter new UNIX password:
Retype new UNIX password:
```

Set root's password using passwd tool.

## 3. Auto Login Configuration

```text {caption="[File 1] /etc/lightdm/lightdm.conf", linenos=table}
[SeatDefaults]
autologin-user=root
autologin-user-timeout=0
user-session=ubuntu
greeter-session=unity-greeter
```

Create /etc/lightdm/lightdm.conf file with the content of [File 1]. (If the file already exists, modify it.)

## 4. Remove /root/.profile Error

```text {caption="[File 2] /root/.profile", linenos=table}
...

tty -s && mesg n
```

After rebooting, change the content of /root/.profile file to the content of [File 2].

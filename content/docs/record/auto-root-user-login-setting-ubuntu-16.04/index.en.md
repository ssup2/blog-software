---
title: Auto Root User Login Setting / Ubuntu 16.04 Environment
---

## 1. Setting Environment

The setting environment is as follows.
* Ubuntu 16.04 LTS 64bit, root user

## 2. root Password Setting

```shell
$ sudo passwd root
Enter new UNIX password:
Retype new UNIX password:
```

Set the root Password using the passwd tool.

## 3. Auto Login Setting

```text {caption="[File 1] /etc/lightdm/lightdm.conf", linenos=table}
[Seat:*]
autologin-guest=false
autologin-user=root
autologin-user-timeout=0
```

Create the /etc/lightdm/lightdm.conf file with the contents of [File 1]. (If the file already exists, modify it.)

## 4. Remove /root/.profile Error

```text {caption="[File 2] /root/.profile", linenos=table}
...

tty -s && mesg n
```

After rebooting, change the contents of the /root/.profile file to the contents of [File 2].


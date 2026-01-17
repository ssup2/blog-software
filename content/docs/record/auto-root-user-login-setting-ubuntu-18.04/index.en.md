---
title: Auto Root User Login Setting / Ubuntu 18.04 Environment
---

## 1. Setting Environment

The setting environment is as follows.
* Ubuntu 18.04 LTS 64bit, root user

## 2. root Password Setting

```shell
$ sudo passwd root
Enter new UNIX password:
Retype new UNIX password:
```

Set the root Password using the passwd tool.

## 3. Auto Login Setting

```text {caption="[File 1] /etc/pam.d/gdm-password", linenos=table}
#%PAM-1.0
auth    requisite       pam-nologin.so
#auth   required        pam-succeed-if.so user != root quiet-success
...
```

Change the /etc/pam.d/gdm-password file to the contents of [File 1].

```text {caption="[File 2] /etc/pam.d/gdm-autologin", linenos=table}
#%PAM-1.0
auth    requisite       pam-nologin.so
#auth   required        pam-succeed-if.so user != root quiet-success
...
```

Change the /etc/pam.d/gdm-autologin file to the contents of [File 2].

```text {caption="[File 3] /etc/gdm3/custom.conf", linenos=table}
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=root
...
[security]
AllowRoot=true
```

Create the /etc/lightdm/lightdm.conf file with the contents of [File 3]. (If the file already exists, modify it.)

## 4. Remove /root/.profile Error

```text {caption="[File 4] /root/.profile", linenos=table}
...

tty -s && mesg n
```

After rebooting, modify the contents of the /root/.profile file to the contents of [File 4].


---
title: 자동 Root User Login 설정 / Ubuntu 18.04 환경
---

## 1. 설정 환경

설정 환경은 다음과 같다.
* Ubuntu 18.04 LTS 64bit, root user

## 2. root Password 설정

```shell
$ sudo passwd root
Enter new UNIX password:
Retype new UNIX password:
```

passwd tool을 이용하여 root의 Password를 설정한다.

## 3. Auto Login 설정

```text {caption="[File 1] /etc/pam.d/gdm-password", linenos=table}
#%PAM-1.0
auth    requisite       pam-nologin.so
#auth   required        pam-succeed-if.so user != root quiet-success
...
```

/etc/pam.d/gdm-password 파일을 [File 1]의 내용으로 변경한다.

```text {caption="[File 2] /etc/pam.d/gdm-autologin", linenos=table}
#%PAM-1.0
auth    requisite       pam-nologin.so
#auth   required        pam-succeed-if.so user != root quiet-success
...
```

/etc/pam.d/gdm-autologin 파일을 [File 2]의 내용으로 변경한다.

```text {caption="[File 3] /etc/gdm3/custom.conf", linenos=table}
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=root
...
[security]
AllowRoot=true
```

/etc/lightdm/lightdm.conf 파일을 [File 3]의 내용으로 생성한다. (이미 파일이 있으면 변경한다.)

## 4. /root/.profile Error 제거

```text {caption="[File 4] /root/.profile", linenos=table}
...

tty -s && mesg n
```

재부팅 후 /root/.profile 파일의 내용을 [File 4]의 내용으로 수정한다.

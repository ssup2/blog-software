---
title: 자동 Root User Login 설정 / Ubuntu 14.04 환경
---

## 1. 설정 환경

설정 환경은 다음과 같다.
* Ubuntu 14.04 LTS 64bit, root user

## 2. root Password 설정

```shell
$ sudo passwd root
Enter new UNIX password:
Retype new UNIX password:
```

passwd tool을 이용하여 root의 Password를 설정한다.

## 3. Auto Login 설정

```text {caption="[File 1] /etc/lightdm/lightdm.conf", linenos=table}
[SeatDefaults]
autologin-user=root
autologin-user-timeout=0
user-session=ubuntu
greeter-session=unity-greeter
```

/etc/lightdm/lightdm.conf 파일을 [File 1]의 내용으로 생성한다.  (이미 파일이 있으면 변경한다.)

## 4. /root/.profile Error 제거

```text {caption="[File 2] /root/.profile", linenos=table}
...

tty -s && mesg n
```

재부팅 후 /root/.profile 파일의 내용을 [File 2]의 내용으로 변경한다.

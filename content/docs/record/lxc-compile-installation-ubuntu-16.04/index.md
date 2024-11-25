---
title: LXC Compile, 설치 / Ubuntu 18.04 환경
---

## 1. Compile, 설치 환경

Compile, 설치 환경은 다음과 같다.
* Ubuntu 16.04 LTS 64bit, root user
* Install Path : /root/lxc-install

## 2. Package 설치

```shell
$ apt-get install libtool m4 automake
$ apt-get install libcap-dev
$ apt-get install pkgconf
$ apt-get install docbook
```

LXC Build에 필요한 Package를 설치한다.

## 3. Compile, 설치

```shell
$ git clone https://github.com/lxc/lxc.git
$ cd lxc
$ ./autogen.sh
$ ./configure --prefix /root/lxc-install
$ make
$ make install
$ ldconfig
```

LXC를 Build 및 설치한다.

## 4. 참조

* [https://github.com/lxc/lxc/blob/master/INSTALL](https://github.com/lxc/lxc/blob/master/INSTALL)

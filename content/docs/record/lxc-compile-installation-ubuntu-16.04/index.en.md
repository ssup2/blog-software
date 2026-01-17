---
title: LXC Compile and Installation / Ubuntu 18.04 Environment
---

## 1. Compile and Installation Environment

The compile and installation environment is as follows.
* Ubuntu 16.04 LTS 64bit, root user
* Install Path: /root/lxc-install

## 2. Package Installation

```shell
$ apt-get install libtool m4 automake
$ apt-get install libcap-dev
$ apt-get install pkgconf
$ apt-get install docbook
```

Install packages required for LXC building.

## 3. Compile and Installation

```shell
$ git clone https://github.com/lxc/lxc.git
$ cd lxc
$ ./autogen.sh
$ ./configure --prefix /root/lxc-install
$ make
$ make install
$ ldconfig
```

Build and install LXC.

## 4. References

* [https://github.com/lxc/lxc/blob/master/INSTALL](https://github.com/lxc/lxc/blob/master/INSTALL)


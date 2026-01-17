---
title: iptables Build, Installation / Ubuntu 18.04 Environment
---

Ubuntu 18.04 only provides iptables up to Version 1.6.1 as an Ubuntu Package. To use versions above that, you must build and install iptables yourself.

## 1. Ubuntu Package Installation

```shell
$ apt install build-essential
```

Install Ubuntu Packages required for building iptables.

## 2. iptables Build & Installation

```shell
$ curl -O http://www.netfilter.org/projects/iptables/files/iptables-1.6.2.tar.bz2
$ tar -xvf iptables-1.6.2.tar.bz2
$ cd iptables-1.6.2
```

Download iptables v1.6.2 Version Code.

```shell
$ ./configure --disable-nftables
$ make && make install
```

Build and install iptables.

## 3. References

* [http://www.linuxfromscratch.org/blfs/view/8.2/postlfs/iptables.html](http://www.linuxfromscratch.org/blfs/view/8.2/postlfs/iptables.html)


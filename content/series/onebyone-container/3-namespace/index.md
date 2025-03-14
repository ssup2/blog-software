---
title: 3. Namespace
---

## Namespace

각 Container는 같은 Host에서 동작하는 다른 Container들의 존재를 알지 못하고 독립된 공간에서 동작하는데, 이러한 성질을 **격리**되었다 라고 표현한다. 이러한 Container의 격리 특성은 Linux Kernel의 Namespace 기능을 이용하여 구현한다. Namespace는 Process가 소속되는 **격리된 공간**을 의미한다.

```console {caption="[Shell 1] Host", linenos=table}
# Host의 Process 확인
(host)# ps -ef
 # ps -ef                                                                                                                      [14:24:56]
UID          PID    PPID  C STIME TTY          TIME CMD
root           1       0  0 Nov27 ?        00:00:13 /sbin/init maybe-ubiquity
root           2       0  0 Nov27 ?        00:00:00 [kthreadd]
root           3       2  0 Nov27 ?        00:00:00 [rcu-gp]
root           4       2  0 Nov27 ?        00:00:00 [rcu-par-gp]
root           6       2  0 Nov27 ?        00:00:00 [kworker/0:0H-kb]
root           9       2  0 Nov27 ?        00:00:00 [mm-percpu-wq]
...

# Host의 Network 정보 확인
(host)# ip a
1: lo: <LOOPBACK,UP,LOWER-UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid-lft forever preferred-lft forever
    inet6 ::1/128 scope host
       valid-lft forever preferred-lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER-UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether 00:15:5d:00:05:07 brd ff:ff:ff:ff:ff:ff
    inet 192.168.0.60/24 brd 192.168.0.255 scope global eth0
       valid-lft forever preferred-lft forever
    inet6 fe80::215:5dff:fe00:507/64 scope link
       valid-lft forever preferred-lft forever

# Host Hostname 확인
(host)# hostname
host

# Host의 Mount 정보 확인
(host)# mount
sysfs on /sys type sysfs (rw,nosuid,nodev,noexec,relatime)
proc on /proc type proc (rw,nosuid,nodev,noexec,relatime)
udev on /dev type devtmpfs (rw,nosuid,relatime,size=1997768k,nr-inodes=499442,mode=755)
devpts on /dev/pts type devpts (rw,nosuid,noexec,relatime,gid=5,mode=620,ptmxmode=000)
tmpfs on /run type tmpfs (rw,nosuid,noexec,relatime,size=403028k,mode=755)
/dev/sda2 on / type ext4 (rw,relatime)
...
```

```console {caption="[Shell 2] nginx Container", linenos=table}
# nginx Container를 Daemon으로 실행하고 exec을 통해서 nginx Container에 bash Process 실행
(host)# docker run -d --rm --name nginx nginx:1.16.1
(host)# docker exec -it nginx bash

# nginx Container의 Process 확인
(nginx)# ps -ef
UID        PID  PPID  C STIME TTY          TIME CMD
root         1     0  0 13:58 ?        00:00:00 nginx: master process nginx -g daemon off;
nginx        6     1  0 13:58 ?        00:00:00 nginx: worker process
root         7     0  0 14:00 pts/0    00:00:00 bash
root       333     7  0 14:07 pts/0    00:00:00 ps -ef

# nginx Container의 Network 정보를 확인하기 ip 명령어를 설치하고 Network 정보 확인
(nginx)# apt-get update && apt-get install procps iproute2 -y
(nginx)# ip a
1: lo: <LOOPBACK,UP,LOWER-UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid-lft forever preferred-lft forever
15: eth0@if16: <BROADCAST,MULTICAST,UP,LOWER-UP> mtu 1500 qdisc noqueue state UP group default
    link/ether 02:42:ac:11:00:03 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 172.17.0.3/16 brd 172.17.255.255 scope global eth0
       valid-lft forever preferred-lft forever

# nginx Container의 Hostname 확인
(nginx)# hostname
e7be60e98500

# nginx Container의 Mount 정보 확인
(nginx)# mount
overlay on / type overlay (rw,relatime,lowerdir=/var/lib/docker/overlay2/l/UKEEN547MUO7AKZE74MR4CQSH6:/var/lib/docker/overlay2/l/42OTIQ6YNKBDVIPRRPMWUJUFJU:/var/lib/docker/overlay2/l/L5EUFYZJGX4AOOMNPLVOFWK74D:/var/lib/docker/overlay2/l/LUKFVFAM3CX4HXFG4WFWLWUN67:/var/lib/docker/overlay2/l/TW3MKSPXR2SUCQRAPS4T27HEUB:/var/lib/docker/overlay2/l/SIYVDXCEC4PJCY3QEY6KHWIYTT,upperdir=/var/lib/docker/overlay2/d229127edfad9cd9ad54475d941ebc612dd4d8ab8cc25c9d11d24d87beb0956f/diff,workdir=/var/lib/docker/overlay2/d229127edfad9cd9ad54475d941ebc612dd4d8ab8cc25c9d11d24d87beb0956f/work)
...
```

```console {caption="[Shell 3] httpd Container", linenos=table}
# httpd Container를 Daemon으로 실행하고 exec을 통해서 httpd Container에 bash Process 실행
(host)# docker run -d --rm --name httpd httpd:2.4.43
(host)# docker exec -it httpd bash

# httpd Container의 Process 확인
(httpd)# ps -ef
UID        PID  PPID  C STIME TTY          TIME CMD
root         1     0  0 14:22 ?        00:00:00 httpd -DFOREGROUND
daemon       7     1  0 14:22 ?        00:00:00 httpd -DFOREGROUND
daemon       8     1  0 14:22 ?        00:00:00 httpd -DFOREGROUND
daemon       9     1  0 14:22 ?        00:00:00 httpd -DFOREGROUND
root        91     0  0 14:22 pts/0    00:00:00 bash
root       505    91  0 14:23 pts/0    00:00:00 ps -ef

# httpd Container의 Network 정보를 확인하기 ip 명령어를 설치하고 Network 정보 확인
(httpd)# apt-get update && apt-get install procps iproute2 -y
(httpd)# ip a
1: lo: <LOOPBACK,UP,LOWER-UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid-lft forever preferred-lft forever
17: eth0@if18: <BROADCAST,MULTICAST,UP,LOWER-UP> mtu 1500 qdisc noqueue state UP group default
    link/ether 02:42:ac:11:00:04 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 172.17.0.4/16 brd 172.17.255.255 scope global eth0
       valid-lft forever preferred-lft forever

# httpd Container의 Hostname 확인
(httpd)# hostname
41981ab27966

# httpd Container의 Mount 정보 확인
(httpd)# mount
overlay on / type overlay (rw,relatime,lowerdir=/var/lib/docker/overlay2/l/BAAGB4VNPW5L5OLLIVNW4PUM4B:/var/lib/docker/overlay2/l/QET7RFTW5Q7DKT6DVKS3W7ZJKT:/var/lib/docker/overlay2/l/WWIQKNFHFRBTOVRM7EJ3JOAJ6P:/var/lib/docker/overlay2/l/SIYVDXCEC4PJCY3QEY6KHWIYTT,upperdir=/var/lib/docker/overlay2/bbc23b396889938987edcc526eba58794b41afa26cf259b5cb38617c3eee46e7/diff,workdir=/var/lib/docker/overlay2/bbc23b396889938987edcc526eba58794b41afa26cf259b5cb38617c3eee46e7/work)
...
```

[Shell 1~3]은 Container를 통해서 Namespace의 격리 특성을 실험하기 위해서 하나의 Host안에서 nginx Container와 httpd Container를 구동한 다음, Host 및 각 Container 내부에서 Process, Network, Hostname, Mount 정보를 확인하는 과정을 나타내고 있다. nginx Container와 httpd Container는 동일한 Host안에서 동작하고 있지만 서로 다른 Process, Network, Hostname, Mount 정보를 갖고 있는걸 확인 할 수 있다. 이러한 현상이 나타나는 이유는 Host, nginx Container, httpd Container가 서로 다른 Namespace를 이용하고 있기 때문이다. 좀더 구체적으로 말하면 Host, nginx Container, httpd Container의 Process가 서로 다른 Namespace에 소속되어 있기 때문이다.

## Namespace Type

Namespace는 격리하는 대상에 따라 여러가지 Type이 존재한다. 대표적인 Namespace Type들은 다음과 같다.

* PID Namespace : PID (Process ID)를 격리한다.
* Network Namespace : Network를 격리한다.
* Mount Namespace : Mount 정보를 격리한다.
* UTS Namespace : Hostname을 격리한다.
* IPC Namespace : IPC (Interprocess Communication)을 격리한다.
* UID Namespace : UID (User ID)를 격리한다.

{{< figure caption="[Figure 1] Host, Container Namespace" src="images/namespace.png" width="900px" >}}

**각 Process는 반드시 모든 Namespace Type의 Namespace에 소속되어야 한다.** 따라서 [Shell 1~3]에서 예시로든 Host 및 nginx, httpd Container의 Namespace와 Process의 관계는 [Figure 1]과 같아진다. PID Namespace를 제외하고는 Host의 Process는 Host가 소유하는 각 Namespace에 소속되어 있고, nginx 및 httpd Container의 Process는 nginx 및 httpd Container가 소유하는 각 Namespace에 소속되어 있는것을 확인할 수 있다. PID Namespace와 Process의 관계는 PID Namespace를 설명할때 좀더 자세히 설명할 예정이다. 이외에 반드시 알고 넘어가야 하는 Network Namespace, Mount Namespace도 뒤에서 자세히 설명할 예정이다.
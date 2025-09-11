---
title: 3. Namespace
---

## Namespace

Each container operates in an independent space without knowing the existence of other containers running on the same host, and this property is expressed as being **isolated**. This isolation characteristic of containers is implemented using the Namespace function of the Linux kernel. Namespace refers to the **isolated space** to which a process belongs.

```console {caption="[Shell 1] Host", linenos=table}
# Check Host Process
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

# Check Host Network Information
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

# Check Host Hostname
(host)# hostname
host

# Check Host Mount Information
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
# Run nginx Container as Daemon and execute bash Process in nginx Container through exec
(host)# docker run -d --rm --name nginx nginx:1.16.1
(host)# docker exec -it nginx bash

# Check nginx Container Process
(nginx)# ps -ef
UID        PID  PPID  C STIME TTY          TIME CMD
root         1     0  0 13:58 ?        00:00:00 nginx: master process nginx -g daemon off;
nginx        6     1  0 13:58 ?        00:00:00 nginx: worker process
root         7     0  0 14:00 pts/0    00:00:00 bash
root       333     7  0 14:07 pts/0    00:00:00 ps -ef

# Install ip command to check nginx Container Network information and check Network information
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

# Check nginx Container Hostname
(nginx)# hostname
e7be60e98500

# Check nginx Container Mount Information
(nginx)# mount
overlay on / type overlay (rw,relatime,lowerdir=/var/lib/docker/overlay2/l/UKEEN547MUO7AKZE74MR4CQSH6:/var/lib/docker/overlay2/l/42OTIQ6YNKBDVIPRRPMWUJUFJU:/var/lib/docker/overlay2/l/L5EUFYZJGX4AOOMNPLVOFWK74D:/var/lib/docker/overlay2/l/LUKFVFAM3CX4HXFG4WFWLWUN67:/var/lib/docker/overlay2/l/TW3MKSPXR2SUCQRAPS4T27HEUB:/var/lib/docker/overlay2/l/SIYVDXCEC4PJCY3QEY6KHWIYTT,upperdir=/var/lib/docker/overlay2/d229127edfad9cd9ad54475d941ebc612dd4d8ab8cc25c9d11d24d87beb0956f/diff,workdir=/var/lib/docker/overlay2/d229127edfad9cd9ad54475d941ebc612dd4d8ab8cc25c9d11d24d87beb0956f/work)
...
```

```console {caption="[Shell 3] httpd Container", linenos=table}
# Run httpd Container as Daemon and execute bash Process in httpd Container through exec
(host)# docker run -d --rm --name httpd httpd:2.4.43
(host)# docker exec -it httpd bash

# Check httpd Container Process
(httpd)# ps -ef
UID        PID  PPID  C STIME TTY          TIME CMD
root         1     0  0 14:22 ?        00:00:00 httpd -DFOREGROUND
daemon       7     1  0 14:22 ?        00:00:00 httpd -DFOREGROUND
daemon       8     1  0 14:22 ?        00:00:00 httpd -DFOREGROUND
daemon       9     1  0 14:22 ?        00:00:00 httpd -DFOREGROUND
root        91     0  0 14:22 pts/0    00:00:00 bash
root       505    91  0 14:23 pts/0    00:00:00 ps -ef

# Install ip command to check httpd Container Network information and check Network information
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

# Check httpd Container Hostname
(httpd)# hostname
41981ab27966

# Check httpd Container Mount Information
(httpd)# mount
overlay on / type overlay (rw,relatime,lowerdir=/var/lib/docker/overlay2/l/BAAGB4VNPW5L5OLLIVNW4PUM4B:/var/lib/docker/overlay2/l/QET7RFTW5Q7DKT6DVKS3W7ZJKT:/var/lib/docker/overlay2/l/WWIQKNFHFRBTOVRM7EJ3JOAJ6P:/var/lib/docker/overlay2/l/SIYVDXCEC4PJCY3QEY6KHWIYTT,upperdir=/var/lib/docker/overlay2/bbc23b396889938987edcc526eba58794b41afa26cf259b5cb38617c3eee46e7/diff,workdir=/var/lib/docker/overlay2/bbc23b396889938987edcc526eba58794b41afa26cf259b5cb38617c3eee46e7/work)
...
```

[Shell 1~3] shows the process of running nginx Container and httpd Container inside one Host to experiment with the isolation characteristics of Namespace through containers, then checking Process, Network, Hostname, and Mount information inside the Host and each Container. Although nginx Container and httpd Container are running inside the same Host, you can see that they have different Process, Network, Hostname, and Mount information. This phenomenon occurs because Host, nginx Container, and httpd Container are using different Namespaces. More specifically, it is because the processes of Host, nginx Container, and httpd Container belong to different Namespaces.

## Namespace Type

There are various types of Namespaces depending on what they isolate. Representative Namespace types are as follows:

* PID Namespace : Isolates PID (Process ID).
* Network Namespace : Isolates Network.
* Mount Namespace : Isolates Mount information.
* UTS Namespace : Isolates Hostname.
* IPC Namespace : Isolates IPC (Interprocess Communication).
* UID Namespace : Isolates UID (User ID).

{{< figure caption="[Figure 1] Host, Container Namespace" src="images/namespace.png" width="900px" >}}

**Each process must belong to a Namespace of all Namespace types.** Therefore, the relationship between the Namespace and Process of Host and nginx, httpd Container used as examples in [Shell 1~3] becomes as shown in [Figure 1]. Except for PID Namespace, you can see that the Host's processes belong to each Namespace owned by the Host, and the processes of nginx and httpd Container belong to each Namespace owned by nginx and httpd Container. The relationship between PID Namespace and Process will be explained in more detail when explaining PID Namespace. In addition, Network Namespace and Mount Namespace, which must be understood, will also be explained in detail later.

---
title: Linux Status Analysis Tool
---

This document summarizes Linux status analysis tools.

## 1. Linux Status Analysis Tool

### 1.1. netstat

```shell {caption="[Shell 1] uptime"}
$ netstat -plnt
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name
tcp        0      0 10.0.0.19:9100          0.0.0.0:*               LISTEN      3080/node_exporter
tcp        0      0 127.0.0.53:53           0.0.0.0:*               LISTEN      23825/systemd-resol
tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN      1618/sshd
tcp        0      0 10.0.0.19:9091          0.0.0.0:*               LISTEN      2912/prometheus
tcp        0      0 10.0.0.19:9093          0.0.0.0:*               LISTEN      3361/alertmanager
```

netstat is a tool that outputs most network information held by the Linux kernel. [Shell 1] shows the output of `netstat -plnt` displaying server processes and ports currently in LISTEN state. netstat is also a tool that can be used when measuring network interface performance.

### 1.2. nmap

```shell {caption="[Shell 2] nmap"}
#  nmap -p 1-65535 localhost
Starting Nmap 7.60 ( https://nmap.org ) at 2020-05-12 22:22 KST
Nmap scan report for localhost (127.0.0.1)
Host is up (0.0000030s latency).
Other addresses for localhost (not scanned): ::1
Not shown: 65531 closed ports
PORT      STATE SERVICE
22/tcp    open  ssh
5000/tcp  open  upnp
9094/tcp  open  unknown
18080/tcp open  unknown
```

nmap is a tool that performs network exploration on external hosts and outputs network status information of external hosts. [Shell 2] shows the output of `nmap -p 1-65535 localhost` performing TCP port scanning from port 1 to port 65536 on localhost. You can see that ports 22, 5000, 9094, and 18080 are in TCP LISTEN state.

### 1.3. nc (netcat)

```shell {caption="[Shell 3] netcat"}
# nc 10.0.0.10 80
GET /
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

nc (netcat) is a tool for sending and receiving data from network connections. It supports TCP and UDP. [shell 3] shows the output of `nc 10.0.0.10 80` connecting to nginx and receiving the / (root) page from nginx.

### 1.4. tcpdump

```shell {caption="[Shell 4] tcpdump"}
#  tcpdump -i eth0 tcp port 80
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), capture size 262144 bytes
13:30:19.335743 IP node09.55226 > a184-28-153-161.deploy.static.akamaitechnologies.com.http: Flags [S], seq 3863811539, win 29200, options [mss 1460,sackOK,TS val 2368590441 ecr 0,nop,wscale 7], length 0
13:30:19.339342 IP a184-28-153-161.deploy.static.akamaitechnologies.com.http > node09.55226: Flags [S.], seq 1883939558, ack 3863811540, win 28960, options [mss 1460,sackOK,TS val 2709703628 ecr 2368590441,nop,wscale 7], length 0
13:30:19.339369 IP node09.55226 > a184-28-153-161.deploy.static.akamaitechnologies.com.http: Flags [.], ack 1, win 229, options [nop,nop,TS val 2368590444 ecr 2709703628], length 0
13:30:19.339409 IP node09.55226 > a184-28-153-161.deploy.static.akamaitechnologies.com.http: Flags [P.], seq 1:78, ack 1, win 229, options [nop,nop,TS val 2368590444 ecr 2709703628], length 77: HTTP: GET / HTTP/1.1
13:30:19.342916 IP a184-28-153-161.deploy.static.akamaitechnologies.com.http > node09.55226: Flags [.], ack 78, win227, options [nop,nop,TS val 2709703632 ecr 2368590444], length 0
13:30:19.355650 IP a184-28-153-161.deploy.static.akamaitechnologies.com.http > node09.55226: Flags [P.], seq 1:301,ack 78, win 227, options [nop,nop,TS val 2709703644 ecr 2368590444], length 300: HTTP: HTTP/1.1 302 Moved Temporarily
13:30:19.355673 IP node09.55226 > a184-28-153-161.deploy.static.akamaitechnologies.com.http: Flags [.], ack 301, win 237, options [nop,nop,TS val 2368590461 ecr 2709703644], length 0
```

tcpdump is a tool that outputs inbound/outbound packet information of a specific network interface. [Shell 3] shows the output of `tcpdump -i eth0 tcp port 80` displaying inbound/outbound packet information with source/destination port 80 on eth0 interface.

### 1.5. lsof

```shell {caption="[Shell 5] lsof"}
# lsof -u root
COMMAND     PID USER   FD      TYPE             DEVICE SIZE/OFF       NODE NAME
systemd       1 root  cwd       DIR                8,2     4096          2 /
systemd       1 root  rtd       DIR                8,2     4096          2 /
systemd       1 root  txt       REG                8,2  1595792   11535295 /lib/systemd/systemd
systemd       1 root  mem       REG                8,2  1700792   11535141 /lib/x86_64-linux-gnu/libm-2.27.so
systemd       1 root  mem       REG                8,2   121016   11534693 /lib/x86_64-linux-gnu/libudev.so.1.6.9
systemd       1 root  mem       REG                8,2    84032   11535128 /lib/x86_64-linux-gnu/libgpg-error.so.0.22.0
systemd       1 root  mem       REG                8,2    43304   11535134 /lib/x86_64-linux-gnu/libjson-c.so.3.0.1
systemd       1 root  mem       REG                8,2    34872    2103003 /usr/lib/x86_64-linux-gnu/libargon2.so.0
systemd       1 root  mem       REG                8,2   432640   11534609 /lib/x86_64-linux-gnu/libdevmapper.so.1.02.1
```

lsof is a tool that outputs lists of open files. [Shell 4] shows the output of `lsof -u root` displaying a list of files opened by root user. Filtering is possible not only by user but also by directory and binary. It is also possible to find processes using specific TCP or UDP ports using lsof.

### 1.6. sysdig

```shell {caption="[Shell 6] sysdig"}
8464 01:23:53.859656137 1 sshd (30637) < read res=2 data=..
8465 01:23:53.859656937 1 sshd (30637) > getpid
8466 01:23:53.859657037 1 sshd (30637) < getpid
8467 01:23:53.859658137 1 sshd (30637) > clock_gettime
8468 01:23:53.859658337 1 sshd (30637) < clock_gettime
8469 01:23:53.859658837 1 sshd (30637) > select
8470 01:23:53.859659637 1 sshd (30637) < select res=1
8471 01:23:53.859660037 1 sshd (30637) > clock_gettime
8472 01:23:53.859660237 1 sshd (30637) < clock_gettime
8473 01:23:53.859660737 1 sshd (30637) > rt_sigprocmask
8474 01:23:53.859660937 1 sshd (30637) < rt_sigprocmask
8475 01:23:53.859661337 1 sshd (30637) > rt_sigprocmask
8476 01:23:53.859661537 1 sshd (30637) < rt_sigprocmask
8477 01:23:53.859662037 1 sshd (30637) > clock_gettime
8478 01:23:53.859662237 1 sshd (30637) < clock_gettime
8479 01:23:53.859662737 1 sshd (30637) > write fd=3(<4t>10.0.0.10:12403->10.0.0.19:22) size=36
8480 01:23:53.859663337 1 sshd (30637) < write res=36 data=.)r...GId....mG.e..._.~..h}....K.{..
8481 01:23:53.859663937 1 sshd (30637) > clock_gettime
8482 01:23:53.859664137 1 sshd (30637) < clock_gettime
8483 01:23:53.859664737 1 sshd (30637) > select
8484 01:23:53.859665937 1 sshd (30637) > switch next=3591(sysdig) pgft_maj=3 pgft_min=452 vm_size=72356 vm_rss=6396 vm_swap=0
```

sysdig is a tool that shows various kernel operation states related to processes, CPU, disk, network, etc. [Shell 5] shows the output of `sysdig` displaying kernel operations. Kernel operation states can also be viewed per container. It is also possible to measure performance of CPU, memory, network, and disk based on operation state information.

## 2. References

* [https://github.com/nicolaka/netshoot](https://github.com/nicolaka/netshoot)



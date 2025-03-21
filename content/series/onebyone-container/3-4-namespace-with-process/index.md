---
title: 3.4. Namespace와 Process의 상관관계
---

## Process와 관련된 Namespace의 특징

Namespace와 Process는 밀접한 관계를 가지고 있다. 먼져 Process와 관련된 Namespace의 특징을 알아본다. Namespace는 Namespace에 소속되어 있는 Process가 존재하지 않는 경우 Linux Kernel에 의해서 자동으로 제거된다는 특징을 갖고 있다. 즉 Namespace가 생성되기 위해서는 Namespace에 소속되어 있는 Process가 반드시 존재해야 한다는 의미이기도 하다. 이러한 이유 때문에 Namespace와 관련된 System Call들은 모두 Process와 연관되어 있다. 

아래는 Namespace과 관련된 System Call들 관련 설명이다. 새로운 Namespace를 생성하는 clone(), unshare() System Call은 Namespace를 생성할 뿐만 아니라, Process를 생성된 Namespace에 소속시키는 동작도 같이 수행하는것을 확인할 수 있다.

* clone() : Process를 생성하는 fork() System Call의 확장판이다. CLONE-NEW* Option으로 Namespace 관련 설정을 진행하고 clone() System Call을 호출하면 (Child) Process뿐만 아니라 Process가 소속되는 새로운 Namespace도 같이 생성된다. Docker와 같은 Container Runtime은 새로운 Container를 생성할때 clone() System Call을 이용하여 Container가 이용하는 Namespace와 Container의 Init Process를 동시에 생성한다.

* unshare() : unshare() System Call을 호출하면 새로운 Namespace가 생성되고, unshare() System Call을 호출한 Process는 새로 생성된 Namespace에 소속된다. unshare 명령어를 통해서 unshare() System Call을 이용할 수 있다.

* setns() : setns() System Call을 호출하는 Process는 setns() System Call Parameter를 통해서 지정하는 다른 Namespace에 소속된다. Host에서 Docker Container 내부에서 명령어를 실행할때 이용하는 docker exec 명령어는, setns() System Call을 이용하여 Process를 Docker Container의 Namespace에서 동작시킨다. nsenter 명령어를 통해서도 setns() System Call을 이용할 수 있다.

## Namespace와 관련된 Process의 특징

Namespace와 관련된 Process의 특징을 알아본다. 모든 Process들은 반드시 모든 Namespace Type의 특정 Namespace에 소속되어야 한다는 특징을 갖고 있다. 따라서 Container의 Process뿐만 아니라 Host의 Process들도 Host의 Namespace에 소속되어 동작한다. 또한 fork() 또는 clone() System Call을 이용하여 Child Process를 생성하는 경우, Namespace 관련 설정을 적용하지 않는 이상 기본적으로 Child Process는 Parent Process가 이용하는 Namespace를 상속받아 그대로 이용한다는 특징도 갖고 있다. 이러한 상속 특성 때문에 기본적으로 Host의 Process들은 Host의 Namespace에 소속되고, 각 Container의 Process들은 각 Container의 Namespace에 소속되어 동작한다.

```console {caption="[Shell 1] Host Process와 Container Process의 Namespace 확인", linenos=table}
# Host의 Init (systemd) Process의 Namespace 확인
(host)# ls -l /proc/1/ns
lrwxrwxrwx 1 root root 0 Oct 10 15:07 ipc -> 'ipc:[4026531839]'
lrwxrwxrwx 1 root root 0 Oct 10 15:07 mnt -> 'mnt:[4026531840]'
lrwxrwxrwx 1 root root 0 Oct 10 15:07 net -> 'net:[4026531993]'
lrwxrwxrwx 1 root root 0 Oct 10 15:07 pid -> 'pid:[4026531836]'
lrwxrwxrwx 1 root root 0 Oct 10 15:07 user -> 'user:[4026531837]'
lrwxrwxrwx 1 root root 0 Oct 10 15:07 uts -> 'uts:[4026531838]'

# Host에서 SSH Daemon Process의 Namespace 확인
(host)# ps -ef | grep sshd
root      1328     1  0 Oct05 ?        00:00:00 /usr/sbin/sshd -D
(host)# ls -l /proc/1328/ns
lrwxrwxrwx 1 root root 0 Oct 10 15:07 ipc -> 'ipc:[4026531839]'
lrwxrwxrwx 1 root root 0 Oct 10 15:07 mnt -> 'mnt:[4026531840]'
lrwxrwxrwx 1 root root 0 Oct 10 15:07 net -> 'net:[4026531993]'
lrwxrwxrwx 1 root root 0 Oct 10 15:07 pid -> 'pid:[4026531836]'
lrwxrwxrwx 1 root root 0 Oct 10 15:07 user -> 'user:[4026531837]'
lrwxrwxrwx 1 root root 0 Oct 10 15:07 uts -> 'uts:[4026531838]'

# nginx Container를 Daemon으로 실행하고 Host에서 보이는 nginx Container의 Init Process의 PID 확인
(host)# docker run -d --rm --name nginx nginx:1.16.1
(host)# docker inspect -f '{% raw %}{{.State.Pid}}{% endraw %}' nginx
1000

# Host에서 nginx Container의 Init Process의 Namespace 확인
(host)# ls -l /proc/1000/ns
lrwxrwxrwx 1 root root 0 Oct 10 15:42 ipc -> 'ipc:[4026532161]'
lrwxrwxrwx 1 root root 0 Oct 10 15:42 mnt -> 'mnt:[4026532159]'
lrwxrwxrwx 1 root root 0 Oct 10 15:40 net -> 'net:[4026532164]'
lrwxrwxrwx 1 root root 0 Oct 10 15:42 pid -> 'pid:[4026532162]'
lrwxrwxrwx 1 root root 0 Oct 10 15:42 user -> 'user:[4026531837]'
lrwxrwxrwx 1 root root 0 Oct 10 15:42 uts -> 'uts:[4026532160]'
```

[Shell 1]에서는 Host Process와 Container Process의 Namespace를 확인하는 과정을 나타내고 있다. [Shell 1]의 내용을 통해서 위해서 언급한 Process의 Namespace 관련 특징들을 확인할 수 있다. Process가 소속되어 있는 Namespace는 /proc/[PID]/ns Directory에 Symbolic Link로 존재한다. 각 Namespace별로 Symbolic Link가 존재하며 숫자는 Symbolic Link의 inode 숫자를 의미한다. [Shell 1]에서는 /proc/[PID]/ns Directory에 IPC, Mount, Network, PID, User UTS Namespace를 확인할 수 있다.

[Shell 1]에서 /proc/1/ns의 Symbolic Link와 /proc/1328/ns의 Symbolic Link가 동일한 inode 숫자를 갖고 있는걸 확인할 수 있다. Host의 Init Process와 Host의 SSH Daemon Process가 동일한 Namespace를 이용한다는 의미이다. Host의 Init Process인 systemd의 Child Process가 SSH Daemon Process이기 때문이고, 별다른 Namespace 관련 설정을 적용하지 않았기 때문에 SSH Daemon Process는 systemd Process와 동일한 Namespace를 이용하고 있는 것이다.

[Shell 1]에서 /proc/1/ns의 Symbolic Link와 /proc/1000/ns의 Symbolic Link가 다른것을 확인할 수 있다. PID 1000은 Host PID Namespace에서 보이는 nginx Container의 Init Process의 PID이다. 즉 Host의 Namespace와 nginx Container의 Namespace가 다르다는 것을 알 수 있다.

## Host Namespace와 Container Namespace 교차 이용

Process는 일부의 Namespace는 Host의 Namespace를 이용하고, 나머지 Namespace는 Container의 Namespace도 이용할 수 있다. 즉 Namespace를 교차로 선택하여 이용할 수 있다. 예를 들어 Network Namespace는 Host의 Network Namespace를 이용하지만, PID Namespace는 Container의 PID Namespace를 이용하도록 설정할 수 있다.

```console {caption="[Shell 2] netshoot Container의 Network Namespace만 이용하여 bash Process 실행", linenos=table}
# netshoot Container를 Daemon으로 실행하고 Host에서 보이는 netshoot Container의 Init Process의 PID와 nginx Container의 IP 확인
(host-1)# docker run -d --rm --name netshoot nicolaka/netshoot sleep infinity
(host-1)# docker inspect -f '{% raw %}{{.State.Pid}}{% endraw %}' netshoot
1000
(host-1)# docker inspect -f '{% raw %}{{.NetworkSettings.IPAddress}}{% endraw %}' netshoot
172.17.0.2
(host-1)# docker exec -it netshoot ps
PID   USER     TIME  COMMAND
    1 root      0:00 sleep infinity
    6 root      0:00 ps

# netshoot Container의 Network Namespace에 bash Process를 실행하고 IP 및 Process 정보 확인
(host-2)# nsenter -n -t 1000 bash
(host-2)# ip a
1: lo: <LOOPBACK,UP,LOWER-UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid-lft forever preferred-lft forever
4: eth0@if5: <BROADCAST,MULTICAST,UP,LOWER-UP> mtu 1500 qdisc noqueue state UP group default
    link/ether 02:42:ac:11:00:02 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 172.17.0.2/16 brd 172.17.255.255 scope global eth0
       valid-lft forever preferred-lft forever

# netshoot Container의 Process 정보가 아닌 Host의 Process 정보 노출
(host-2)# ps -ef
root         1     0  0 Oct09 ?        00:00:13 /sbin/init maybe-ubiquity
root         2     0  0 Oct09 ?        00:00:00 [kthreadd]
...
```

[Shell 2]는 nsenter 명령어를 이용하여 bash Process를 netshoot Container의 Network Namespace 및 Host의 나머지 Namespace에 배치시키고 IP 및 Process 정보를 확인하는 과정을 나타내고 있다. bash Process에서 "ip" 명령어를 수행하면 Host의 IP 정보가 아닌 Container의 IP 정보를 확인할 수 있다. 하지만 bash Process에서 "ps" 명령어를 통해서 Process의 정보를 확인하면 PID 1번 Process가 netshoot Container의 PID 1번 Process가 아닌, Host의 PID 1번 Process인걸 확인할 수 있다. bash Process는 Network Namespace는 netshoot Container의 것을 이용하지만, PID, Mount Namespace는 Host의 것을 이용하기 때문이다.
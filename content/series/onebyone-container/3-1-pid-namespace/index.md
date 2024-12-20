---
title: 3.1. PID Namespace
---

## Linux Process 관리

{{< figure caption="[Figure 1] Linux의 Process Tree" src="images/linux-process-tree.png" width="400px" >}}

PID Namespace는 Process의 격리를 담당하는 Namespace이다. PID Namespace를 완전히 이해하기 위해서는 Linux의 Process Tree를 이해할 필요가 있다. [Figure 1]은 Linux의 Process Tree를 나타내고 있다. 네모는 하나의 Process를 나타내며 각 Process에는 Process에는 이름과, PID (Process ID)가 기제되어 있다. Process Tree의 Root에 존재하는 Process는 반드시 PID 1번을 갖으며 **Init Process**라고 불린다.

Process는 fork() System Call을 호출하여 자식 Process를 생성할 수 있다. fork() System Call을 호출한 Process는 부모 Process가 된다. 예를들어 [Figure 1]에서 B Process는 fork() System Call을 2번 호출하여 통해서 C Process와 D Process를 생성하였다. B Process는 C Process와 D Process의 부모 Process가 되며, C Process와 D Process는 B Process의 자식 Process가 된다. 모든 Process는 fork() System Call을 통해서 자유롭게 자식 Process를 생성할 수 있다. 따라서 [Figure 1]처럼 Linux의 Process는 Init Process를 Root로하는 Tree를 구성하게 된다.

{{< figure caption="[Figure 2] Linux의 고아 Process 처리" src="images/orphan-process.png" width="400px" >}}

PID Namespace를 완전히 이해하기 위해서 또하나 알고 있어야 하는 배경지식은 고아 Process와 Zombie Process의 정의와, Linux에서 고아 Process와 Zombie Process의 처리하는 방법이다. 고아 Process는 의미 그대로 부모 Process가 죽어 고아가된 Process를 의미한다.
Linux는 고아 Process가 발생하면 고아 Process의 부모를 Init Process로 설정한다. [Figure 2]에서는 B Process가 종료되어 C Process와 D Process가 고아 Process가 되었기 때문에, Init Process인 A Process가 C Process와 D Process의 새로운 부모 Process가 되는 과정을 나타내고 있다.

Zombie Process는 죽지 않는 Process를 의미한다. Zombie Process가 죽지 않는 이유는 Process는 실제로 죽어 종료된 상태이지만 Process의 Meta 정보가 Kernel에 남아 있어 Process가 존재하는것 처럼 보이는 상태이기 때문이다. Zombie Process를 제거하기 위해서는 Kernel에서 Zombie Process의 Meta 정보를 제거하는 방법밖에 존재하지 않는다. Linux에서 Zombie Process의 Meta 정보를 제거하는 방법은 부모 Process가 wait() System Call을 호출하여 Zombie Process의 Meta 정보를 회수해야 제거된다.

따라서 부모 Process는 fork() System Call을 통해서 생성한 자식 Process를 wait() System Call을 통해서 회수해야 한다. 하지만 만약 부모 Process가 wait() System Call을 호출하지 않는다면, 종료된 자식 Process는 Zombie Process가 된다. 이러한 Zombie Process는 부모 Process가 죽어야 Init Process에 의해서 제거된다.

{{< figure caption="[Figure 3] Linux의 Zombie Process 처리" src="images/zombie-process.png" width="400px" >}}

[Figure 3]은 Linux에서 부모 Process가 wait() System Call을 호출하지 않았을 경우 Zombie Process의 처리 과정을 나타내고 있다. C Process가 종료되었지만 B Process가 wait() System Call을 호출하지 않았기 때문에 C Process는 Zombie Process가 된다. 이후 B Process가 종료되면 C Process의 부모 Process는 Init Process가 되기 때문에 Init Process는 wait() System Call을 호출하여 C Process를 제거한다. 이와 같은 이유 때문에 Init Process는 반드시 wait() System Call을 호출하여 Zombie Process를 제거하는 역할을 수행해야 한다. 가장 많이 이용되는 Init Process인 systemd는 Zombie Process 제거 역할을 수행한다.

```console {caption="[Shell 1] Linux Host에서 고아 Process 확인", linenos=table}
# sleep process을 생성하는 bash Process를 생성
(host)# bash -c "(bash -c 'sleep 60')" &
(host)# ps -ef
root         1     0  0 Apr22 ?        00:00:03 /sbin/init
...
root     29756 28207  0 22:06 pts/24   00:00:00 bash -c (bash -c 'sleep 60')
root     29758 29756  0 22:06 pts/24   00:00:00 sleep 60
root     29764 28207  0 22:06 pts/24   00:00:00 ps -ef

# bash Process를 종료시킨 다음 sleep Process의 부모 Process가 Init Process가 되는것을 확인
(host)# kill -9 29756
(host)# ps -ef
root         1     0  0 Apr22 ?        00:00:03 /sbin/init
...
root     29758     1  0 22:06 pts/24   00:00:00 sleep 60
root     29779 28207  0 22:07 pts/24   00:00:00 ps -ef

# 60초 뒤에 sleep Process가 종료가 된다음 sleep Process가 Zombie Process가 되지 않고 제거되는것을 확인
(host)# ps -ef
root         1     0  0 Apr22 ?        00:00:03 /sbin/init
...
root     29779 28207  0 22:07 pts/24   00:00:00 ps -ef
```

[Shell 1]은 Linux Host에서 고아 Process 생성 및 상태를 확인하는 과정을 나타내고 있다. [Shell 1]에서 sleep Process는 Bash Process가 부모 Process인데, Bash Process가 종료된 다음 sleep Process의 새로운 부모 Process는 init Process가 되는것을 확인할 수 있다. 60초 후에 sleep Process가 종료된 다음 /sbin/init Process는 자식 Process인 sleep Process의 Meta 정보를 회수하여 sleep Process가 Zombie Process가 되는것을 방지하여 sleep Process를 제거한다.

## PID Namespace

```console {caption="[Shell 1] nginx Container Process", linenos=table}
# nginx Container를 Daemon으로 실행하고 exec을 통해서 nginx Container에 bash Process를 실행
(host)# docker run -d --rm --name nginx nginx:1.16.1
(host)# docker exec -it nginx bash

# nginx Container의 Process를 확인한다.
(nginx)# ps -ef
UID        PID  PPID  C STIME TTY          TIME CMD
root         1     0  0 Apr10 ?        00:00:00 nginx: master process nginx -g daemon off;
nginx        6     1  0 Apr10 ?        00:00:00 nginx: worker process
```

```console {caption="[Shell 2] httpd Container Process", linenos=table}
# httpd Container를 Daemon으로 실행하고 exec을 통해서 httpd Container에 bash Process를 실행
(host)# docker run -d --rm --name httpd httpd:2.4.43
(host)# docker exec -it httpd bash

# httpd Container의 Process를 확인한다.
(httpd)# ps -ef
UID        PID  PPID  C STIME TTY          TIME CMD
root         1     0  0 Apr10 ?        00:00:05 httpd -DFOREGROUND
daemon       7     1  0 Apr10 ?        00:00:00 httpd -DFOREGROUND
daemon       8     1  0 Apr10 ?        00:00:00 httpd -DFOREGROUND
daemon       9     1  0 Apr10 ?        00:00:00 httpd -DFOREGROUND
```

```console {caption="[Shell 3] Host Process", linenos=table}
# host에서 nginx Container와 httpd Container의 Process를 확인
(host)# ps -ef
UID        PID  PPID  C STIME TTY          TIME CMD
...
root     20997 20969  0 Apr10 ?        00:00:00 nginx: master process nginx -g daemon off;
systemd+ 21042 20997  0 Apr10 ?        00:00:00 nginx: worker process
...
root     25759 25739  0 Apr10 ?        00:00:05 httpd -DFOREGROUND
daemon   25816 25759  0 Apr10 ?        00:00:00 httpd -DFOREGROUND
daemon   25817 25759  0 Apr10 ?        00:00:00 httpd -DFOREGROUND
daemon   25818 25759  0 Apr10 ?        00:00:00 httpd -DFOREGROUND
...
```

[Shell 1]은 nginx Container 내부에서 본 Process를 나타내고 있고 [Shell 2]는 httpd Container 내부에서 본 Process를 나타내고 있다. 마지막으로 [Shell 3]은 nginx Container와 httpd Container를 구동한 Host에서 본 Process를 나타내고 있다. NGNIX Container와 httpd Container는 서로의 Process를 확인할 수 없지만, Host는 두 Container의 Proces를 모두 확인할 수 있다. 이러한 현상은 PID Namespace의 특징 때문에 발생한다.

{{< figure caption="[Figure 4] Container PID Namespace" src="images/container-pid-namespace.png" width="900px" >}}

PID Namespace는 의미 그대로 PID를 격리하는 Namespace이다. PID를 격리한다는 의미는 좀더 확장되면 Process를 격리한다는 의미와 동일하다. [Figure 4]는 Host가 이용하는 Host PID Namespace, Container A가 이용하는 Container A PID Namespace, Container B가 이용하는 Container B PID Namespace, 3개의 PID Namespace를 나타내고 있다. 또한 [Figure 4]의 왼쪽에는 PID Namespace 사이의 관계도 나타내고 있다. PID Namespace는 **계층**을 갖는 Namespace이다. 가장 상위에 존재하는 PID Namespace는 **Init PID Namespace**라고 명칭한다. Host PID Namespace는 Init PID Namespace이며, 자식 PID Namespace로 Container A와 Container B의 PID Namespace를 갖는다.

각 Namespace에서 Process Tree의 가장 높이 위치하는 Proess는 **Namespace의 Init Process**라고 명칭한다. [Figure 4]에서 A Process는 Host PID Namespace의 Init Process이고, D Process는 Container B PID Namespace의 Init Process이다. 각 Process는 오직 자신이 소속되어 있는 PID Namespace의 Process들 및 자신이 소속되어 있는 PID Namespace의 하위 PID Namespace들에게 소속되어 있는 Process들에게만 접근할 수 있다. 따라서 Host PID Namespace에 소속되어 있는 Process는 Container A와 Container B의 Process에 접근할 수 있지만, Container에 소속되어 있는 Process들은 Container의 Process에게만 접근할 수 있다.

동일한 Process라도 각 PID Namespace마다 다른 PID를 갖는다. 각 Namespace의 Init Procesess는 해당 Namespace에서 1번 PID를 갖는다. [Figure 4]에서는 PID Namespace마다 다르게 보이는 PID도 나타내고 있다. E Process는 A Namespace에서는 5번 PID로 보이지만 B Namespace에서는 6번 PID로 보인다. B Process는 B Namespace의 Init Process이기 때문에 1번 B Namespace에서는 1번 PID로 보인다. Container A를 nginx Container라고 간주하고 Container B를 httpd Container라고 간주한다면 [Shell 1~3]의 동작 과정을 이해할 수 있게 된다.

{{< figure caption="[Figure 5] Nested Container PID Namespace" src="images/nested-container-pid-namespace.png" width="900px" >}}

그렇다면 Container 내부에서 PID Namespace를 생성하면 어떻게 될까? [Figure 5]는 Container B PID Namespace에서 Container를 생성하여 Nested Container PID Namespace가 생겼을때를 표현하고 있다. Container B PID Namespace 하위에 Nested Container PID Namespace가 생성된다. Docker Contaier 안에서 Docker Container를 구동하는 (Docker in Docker)의 경우에 [Figure 5]와 같은 PID Namespace의 관계가 생성된다.

{{< figure caption="[Figure 6] Init-Process-Killed" src="images/init-process-killed.png" width="550px" >}}

마지막으로 PID Namespace의 중요한 특성은 바로 PID Namespace의 Init Process가 죽으면, Linux Kernel에 의해서 PID Namespace의 나머지 Process도 SIGKIll Signal을 받고 강제로 죽는다는 점이다. 따라서 Container의 Init Process가 죽으면 Container의 모든 Process가 죽고, Container는 사라지게 된다. [Figure 6]은 PID Namespace의 Init Process가 죽었을때의 과정을 나타내고 있다. Container PID Namespace의 Init Process인 C Process가 죽으면, D Process 및 E Process도 죽게된다. D Process와 E Process는 Container PID Namespace의 부모 Namespace인 Host Namespace의 Init Process인 A Process의 자식 Process가 된다. 이후에 A Process는 D Process, E Process의 Meta 정보를 회수하여 Zombie Process가 되는것을 방지하고 D Process, E Process를 제거한다.

## Container Process 관리

{{< figure caption="[Figure 7] PID Namespace까지 고려된 고아 Process, Zombie Process 처리" src="images/orphan-zombie-process-with-pid-namespace.png" width="600px" >}}

Container Process중에서 고아 Process 및 Zombie Process가 발생하면 어떻게 될까? [Figure 6]은 PID Namespace까지 고려된 상태에서 고아 Process와 Zombie Process의 처리 과정을 나타내고 있다. Host PID Namespace에서의 고아 Process 및 Zombie Process의 처리 과정은 Host의 Init Process와 Host PID Namespace의 Init Process가 동일하다고 간주하면 쉽게 이해할 수 있다. B Process가 종료될 경우 고아 Process가 된 D Process와 E Process의 새로운 부모 Process는 Host PID Namespace의 Init Process인 A Process가 된다. D Process가 종료될 경우 A Process는 D Process의 Meta 정보를 회수하여 D Process가 Zombie Process가 되는것을 방지한다.

하지만 Container PID Namespace에서 고아 Process가 발생한다면 고아 Process의 새로운 부모 Process는 Host PID Namespace의 Init Process가 아닌 **Container PID Namespace의 Init Process가 새로운 부모 Process가 된다.** [Figure 6]에서 F Process가 종료된 다음 고아 Process가된 G Process, H Process의 새로운 부모 Process는 C Process가 된다. 따라서 Container PID Namespace의 Init Process인 C Process도 Host PID Namespace의 Init Process인 A Process 처럼 wait() System Call을 호출하여 Zombie Process를 제거하는 역할을 수행해야 한다.

C Process는 Container PID Namespace의 Init Process이기 때문에, 이후 C Process가 죽으면 Container PID Namespace의 G Process, H Process도 죽게된다. C Process가 존재하지 않기 때문에 A Process는 고아가된 G Process, H Process의 새로운 부모 Process가 된다. A Process는 G Process, H Process의 Meta 정보를 회수하여 G Process, H Process를 제거한다. 만약 C Process가 Zombie Process를 제거하는 역할을 수행하지 않아 F Process가 Zombie Process 상태였어도, C Process가 죽으면 A Process가 F Process의 새로운 부모 Process가 되기 때문에, A Process가 F Process의 Meta 정보를 회수하여 F Process는 제거된다.

즉 Container의 Zombie Process가 Container의 Init Process에 의해서 제거되지 않더라도, Container가 죽으면 Host의 systemd와 같은 Init Process에 의해서 Container의 Zombie Proces는 제거된다는 의미이다. Container의 Init Process로 많이 이용되는 supervisord, dumb-init, tini 같은 명령어들은 모두 Child Process의 Meta 정보를 회수하는 기능을 갖고 있기 때문에 Container의 Zombie Process를 예방하는 역할을 수행한다.

```console {caption="[Shell 5] Container의 고아 Process, Zombie Process 확인", linenos=table}
# Init Process가 sleep infinity인 ubuntu Container를 Daemon으로 실행하고 exec을 통해서 ubuntu Container에 bash Process를 실행한다.
(host)# docker run -d --rm --name ubuntu ubuntu sleep infinity
(host)# docker exec -it ubuntu bash

# ubuntu Container에서 bash Process를 부모 Process로 갖는 sleep 60 Process를 생성
(ubuntu)# bash -c "(bash -c 'sleep 60')" &
(ubuntu)# ps -ef
UID        PID  PPID  C STIME TTY          TIME CMD
root         1     0  0 13:33 ?        00:00:00 sleep infinity
root         6     0  1 13:45 pts/0    00:00:00 bash
root        15     6  0 13:46 pts/0    00:00:00 bash -c (bash -c 'sleep 60')
root        16    15  0 13:46 pts/0    00:00:00 sleep 60
root        17     6  0 13:46 pts/0    00:00:00 ps -ef

# sleep 60 Process의 부모 Process인 bash Process를 강제로 종료시킨다음 sleep 60 Process의 부모 Process를 확인
(ubuntu)# kill -9 15
(ubuntu)# ps -ef
UID        PID  PPID  C STIME TTY          TIME CMD
root         1     0  0 13:33 ?        00:00:00 sleep infinity
root         6     0  0 13:45 pts/0    00:00:00 bash
root        16     1  0 13:46 pts/0    00:00:00 sleep 60
root        18     6  0 13:46 pts/0    00:00:00 ps -ef

# 60초가 지난후에 sleep 60 process가 종료되면서 Zombie Process가 되는것을 확인
(ubuntu)# ps -ef
UID        PID  PPID  C STIME TTY          TIME CMD
root         1     0  0 13:33 ?        00:00:00 sleep infinity
root         6     0  0 13:45 pts/0    00:00:00 bash
root        16     1  0 13:46 pts/0    00:00:00 [sleep] <defunct>
root        19     6  0 13:47 pts/0    00:00:00 ps -ef
```

[Shell 5]는 Container에서 고아 Process와 Zombie Process를 확인하는 과정을 나타내고 있다. [Shell 5]에서 ubuntu Container의 Init Process는 sleep infinity Process로 설정하였다. 그 후 ubuntu Container에 bash Process를 생성하여 sleep 60 Process를 고아 Process로 만들었다. sleep 60 Process의 Parant는 Container의 Init Process인 sleep inifinity가 되는것을 확인할 수 있다. sleep infinity Process는 wait() System Call 호출하지 않기 때문에 죽은 Child Process의 Meta 정보를 회수하는 기능을 수행하지 못한다. 따라서 60초 후에 sleep 60 Process가 종료되면 sleep 60 Process는 Zombie Process가 된다. defunt는 Zombie Process가 되었다는걸 의미한다.

```console {caption="[Shell 6] Container Zombie Process 확인 및 제거", linenos=table}
# Host에서 ubuntu Container의 Zombie Process 확인
(host)# ps -ef
root     12552 12526  0 22:33 ?        00:00:00 sleep infinity
root     18319 12526  0 22:45 pts/0    00:00:00 bash
root     18461 12552  0 22:46 pts/0    00:00:00 [sleep] <defunct>
root     20908 28207  0 22:51 pts/24   00:00:00 ps -ef

# ubuntu Container를 제거한 다음 ubuntu Container의 Zombie Process가 제거된것을 확인
(host)# docker rm -f ubuntu
(host)# ps -ef
root     22783 28207  0 22:55 pts/24   00:00:00 ps -ef
```

[Shell 6]은 Host에서 ubuntu Container의 Zombie Process를 확인하고, ubuntu Container를 제거하여 Container의 Zombie Process도 제거된것을 확인하는 과정을 나타내고 있다. Host에서는 Container의 모든 Process를 볼수 있기 때문에 ubuntu Container의 Zombie Process는 Host Process에서도 확인할 수 있다. ubuntu Container를 제거한 다음 ubuntu Container의 Zombie Process도 제거된것을 확인할 수 있다.
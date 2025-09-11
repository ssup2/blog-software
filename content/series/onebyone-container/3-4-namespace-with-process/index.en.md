---
title: 3.4. Correlation between Namespace and Process
---

## Characteristics of Namespace Related to Process

Namespace and Process have a close relationship. First, let's look at the characteristics of Namespace related to Process. Namespace has the characteristic that it is automatically removed by the Linux kernel when there are no processes belonging to the Namespace. In other words, it also means that a process belonging to the Namespace must exist for the Namespace to be created. For this reason, all system calls related to Namespace are associated with processes.

Below is an explanation of system calls related to Namespace. You can see that clone() and unshare() system calls, which create new Namespaces, not only create Namespaces but also perform the action of assigning processes to the created Namespace.

* clone() : This is an extended version of the fork() system call that creates processes. When you proceed with Namespace-related settings with CLONE-NEW* options and call the clone() system call, not only the (Child) process but also a new Namespace to which the process belongs is created. Container runtimes like Docker use the clone() system call to simultaneously create the Namespace used by the container and the container's Init Process when creating a new container.

* unshare() : When the unshare() system call is called, a new Namespace is created, and the process that called the unshare() system call belongs to the newly created Namespace. You can use the unshare() system call through the unshare command.

* setns() : The process that calls the setns() system call belongs to another Namespace specified through the setns() system call parameter. The docker exec command used when executing commands inside Docker containers from the Host uses the setns() system call to run processes in the Docker container's Namespace. You can also use the setns() system call through the nsenter command.

## Characteristics of Process Related to Namespace

Let's look at the characteristics of processes related to Namespace. All processes have the characteristic that they must belong to a specific Namespace of all Namespace types. Therefore, not only container processes but also host processes operate by belonging to the host's Namespace. Also, when creating child processes using fork() or clone() system calls, unless Namespace-related settings are applied, child processes basically inherit and use the Namespace used by the parent process. Due to this inheritance characteristic, host processes basically belong to the host's Namespace, and each container's processes operate by belonging to each container's Namespace.

```console {caption="[Shell 1] Check Namespace of Host Process and Container Process", linenos=table}
# Check Host Init (systemd) Process Namespace
(host)# ls -l /proc/1/ns
lrwxrwxrwx 1 root root 0 Oct 10 15:07 ipc -> 'ipc:[4026531839]'
lrwxrwxrwx 1 root root 0 Oct 10 15:07 mnt -> 'mnt:[4026531840]'
lrwxrwxrwx 1 root root 0 Oct 10 15:07 net -> 'net:[4026531993]'
lrwxrwxrwx 1 root root 0 Oct 10 15:07 pid -> 'pid:[4026531836]'
lrwxrwxrwx 1 root root 0 Oct 10 15:07 user -> 'user:[4026531837]'
lrwxrwxrwx 1 root root 0 Oct 10 15:07 uts -> 'uts:[4026531838]'

# Check Host SSH Daemon Process Namespace
(host)# ps -ef | grep sshd
root      1328     1  0 Oct05 ?        00:00:00 /usr/sbin/sshd -D
(host)# ls -l /proc/1328/ns
lrwxrwxrwx 1 root root 0 Oct 10 15:07 ipc -> 'ipc:[4026531839]'
lrwxrwxrwx 1 root root 0 Oct 10 15:07 mnt -> 'mnt:[4026531840]'
lrwxrwxrwx 1 root root 0 Oct 10 15:07 net -> 'net:[4026531993]'
lrwxrwxrwx 1 root root 0 Oct 10 15:07 pid -> 'pid:[4026531836]'
lrwxrwxrwx 1 root root 0 Oct 10 15:07 user -> 'user:[4026531837]'
lrwxrwxrwx 1 root root 0 Oct 10 15:07 uts -> 'uts:[4026531838]'

# Run nginx Container as Daemon and check PID of nginx Container's Init Process visible from Host
(host)# docker run -d --rm --name nginx nginx:1.16.1
(host)# docker inspect -f '{% raw %}{{.State.Pid}}{% endraw %}' nginx
1000

# Check nginx Container's Init Process Namespace from Host
(host)# ls -l /proc/1000/ns
lrwxrwxrwx 1 root root 0 Oct 10 15:42 ipc -> 'ipc:[4026532161]'
lrwxrwxrwx 1 root root 0 Oct 10 15:42 mnt -> 'mnt:[4026532159]'
lrwxrwxrwx 1 root root 0 Oct 10 15:40 net -> 'net:[4026532164]'
lrwxrwxrwx 1 root root 0 Oct 10 15:42 pid -> 'pid:[4026532162]'
lrwxrwxrwx 1 root root 0 Oct 10 15:42 user -> 'user:[4026531837]'
lrwxrwxrwx 1 root root 0 Oct 10 15:42 uts -> 'uts:[4026532160]'
```

[Shell 1] shows the process of checking the Namespace of Host Process and Container Process. Through the content of [Shell 1], you can confirm the Namespace-related characteristics of processes mentioned above. The Namespace to which a process belongs exists as a symbolic link in the /proc/[PID]/ns directory. There is a symbolic link for each Namespace, and the number means the inode number of the symbolic link. In [Shell 1], you can see IPC, Mount, Network, PID, User, and UTS Namespaces in the /proc/[PID]/ns directory.

In [Shell 1], you can see that the symbolic links of /proc/1/ns and /proc/1328/ns have the same inode number. This means that the Host's Init Process and the Host's SSH Daemon Process use the same Namespace. This is because the SSH Daemon Process is a child process of systemd, which is the Host's Init Process, and since no special Namespace-related settings were applied, the SSH Daemon Process uses the same Namespace as the systemd Process.

In [Shell 1], you can see that the symbolic links of /proc/1/ns and /proc/1000/ns are different. PID 1000 is the PID of the nginx Container's Init Process as seen from the Host PID Namespace. In other words, you can see that the Host's Namespace and the nginx Container's Namespace are different.

## Cross-Use of Host Namespace and Container Namespace

A process can use some Namespaces from the Host's Namespace and use the remaining Namespaces from the Container's Namespace. In other words, Namespaces can be selected and used crosswise. For example, you can set it to use the Host's Network Namespace but use the Container's PID Namespace.

```console {caption="[Shell 2] Execute bash Process using only netshoot Container's Network Namespace", linenos=table}
# Run netshoot Container as Daemon and check PID of netshoot Container's Init Process visible from Host and nginx Container's IP
(host-1)# docker run -d --rm --name netshoot nicolaka/netshoot sleep infinity
(host-1)# docker inspect -f '{% raw %}{{.State.Pid}}{% endraw %}' netshoot
1000
(host-1)# docker inspect -f '{% raw %}{{.NetworkSettings.IPAddress}}{% endraw %}' netshoot
172.17.0.2
(host-1)# docker exec -it netshoot ps
PID   USER     TIME  COMMAND
    1 root      0:00 sleep infinity
    6 root      0:00 ps

# Execute bash Process in netshoot Container's Network Namespace and check IP and Process information
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

# Host's Process information is exposed, not netshoot Container's Process information
(host-2)# ps -ef
root         1     0  0 Oct09 ?        00:00:13 /sbin/init maybe-ubiquity
root         2     0  0 Oct09 ?        00:00:00 [kthreadd]
...
```

[Shell 2] shows the process of placing a bash Process in the netshoot Container's Network Namespace and the Host's remaining Namespaces using the nsenter command, and checking IP and Process information. When the "ip" command is executed in the bash Process, you can see the Container's IP information, not the Host's IP information. However, when you check the process information through the "ps" command in the bash Process, you can see that the PID 1 process is not the netshoot Container's PID 1 process, but the Host's PID 1 process. This is because the bash Process uses the netshoot Container's Network Namespace, but uses the Host's PID and Mount Namespaces.

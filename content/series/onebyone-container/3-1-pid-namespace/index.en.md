---
title: 3.1. PID Namespace
---

## Linux Process Management

{{< figure caption="[Figure 1] Linux Process Tree" src="images/linux-process-tree.png" width="400px" >}}

PID Namespace is a Namespace responsible for process isolation. To fully understand PID Namespace, it is necessary to understand Linux's Process Tree. [Figure 1] shows Linux's Process Tree. The squares represent individual processes, and each process has a name and PID (Process ID) recorded. The process at the root of the Process Tree must have PID 1 and is called the **Init Process**.

Processes can create child processes by calling the fork() system call. The process that calls the fork() system call becomes the parent process. For example, in [Figure 1], Process B called the fork() system call twice to create Process C and Process D. Process B becomes the parent process of Process C and Process D, and Process C and Process D become child processes of Process B. All processes can freely create child processes through the fork() system call. Therefore, Linux processes form a tree with the Init Process as the root, as shown in [Figure 1].

{{< figure caption="[Figure 2] Linux Orphan Process Handling" src="images/orphan-process.png" width="400px" >}}

Another background knowledge needed to fully understand PID Namespace is the definition of orphan processes and zombie processes, and how Linux handles orphan processes and zombie processes. An orphan process literally means a process that has become an orphan because its parent process has died.
When an orphan process occurs in Linux, the parent of the orphan process is set to the Init Process. [Figure 2] shows the process where Process A, which is the Init Process, becomes the new parent process of Process C and Process D because Process B has terminated and Process C and Process D have become orphan processes.

A zombie process means a process that does not die. The reason zombie processes do not die is that the process is actually dead and terminated, but the process's meta information remains in the kernel, making it appear as if the process exists. To remove zombie processes, there is no other way than to remove the zombie process's meta information from the kernel. In Linux, the way to remove zombie process meta information is that the parent process must call the wait() system call to retrieve the zombie process's meta information.

Therefore, parent processes must retrieve child processes created through the fork() system call through the wait() system call. However, if the parent process does not call the wait() system call, the terminated child process becomes a zombie process. These zombie processes are removed by the Init Process only when the parent process dies.

{{< figure caption="[Figure 3] Linux Zombie Process Handling" src="images/zombie-process.png" width="400px" >}}

[Figure 3] shows the zombie process handling process when the parent process does not call the wait() system call in Linux. Process C has terminated, but because Process B did not call the wait() system call, Process C becomes a zombie process. Later, when Process B terminates, Process C's parent process becomes the Init Process, so the Init Process calls the wait() system call to remove Process C. For this reason, the Init Process must perform the role of removing zombie processes by calling the wait() system call. systemd, the most commonly used Init Process, performs the role of removing zombie processes.

```console {caption="[Shell 1] Checking Orphan Process in Linux Host", linenos=table}
# Create bash Process that creates sleep process
(host)# bash -c "(bash -c 'sleep 60')" &
(host)# ps -ef
root         1     0  0 Apr22 ?        00:00:03 /sbin/init
...
root     29756 28207  0 22:06 pts/24   00:00:00 bash -c (bash -c 'sleep 60')
root     29758 29756  0 22:06 pts/24   00:00:00 sleep 60
root     29764 28207  0 22:06 pts/24   00:00:00 ps -ef

# Kill bash Process and check that sleep Process's parent process becomes Init Process
(host)# kill -9 29756
(host)# ps -ef
root         1     0  0 Apr22 ?        00:00:03 /sbin/init
...
root     29758     1  0 22:06 pts/24   00:00:00 sleep 60
root     29779 28207  0 22:07 pts/24   00:00:00 ps -ef

# After 60 seconds, check that sleep Process terminates and is removed without becoming Zombie Process
(host)# ps -ef
root         1     0  0 Apr22 ?        00:00:03 /sbin/init
...
root     29779 28207  0 22:07 pts/24   00:00:00 ps -ef
```

[Shell 1] shows the process of creating and checking the status of orphan processes in a Linux Host. In [Shell 1], the sleep process has a Bash process as its parent process, and after the Bash process terminates, you can see that the sleep process's new parent process becomes the init process. After 60 seconds, when the sleep process terminates, the /sbin/init process retrieves the meta information of the child process sleep process to prevent the sleep process from becoming a zombie process and removes the sleep process.

## PID Namespace

```console {caption="[Shell 1] nginx Container Process", linenos=table}
# Run nginx Container as Daemon and execute bash Process in nginx Container through exec
(host)# docker run -d --rm --name nginx nginx:1.16.1
(host)# docker exec -it nginx bash

# Check nginx Container Process
(nginx)# ps -ef
UID        PID  PPID  C STIME TTY          TIME CMD
root         1     0  0 Apr10 ?        00:00:00 nginx: master process nginx -g daemon off;
nginx        6     1  0 Apr10 ?        00:00:00 nginx: worker process
```

```console {caption="[Shell 2] httpd Container Process", linenos=table}
# Run httpd Container as Daemon and execute bash Process in httpd Container through exec
(host)# docker run -d --rm --name httpd httpd:2.4.43
(host)# docker exec -it httpd bash

# Check httpd Container Process
(httpd)# ps -ef
UID        PID  PPID  C STIME TTY          TIME CMD
root         1     0  0 Apr10 ?        00:00:05 httpd -DFOREGROUND
daemon       7     1  0 Apr10 ?        00:00:00 httpd -DFOREGROUND
daemon       8     1  0 Apr10 ?        00:00:00 httpd -DFOREGROUND
daemon       9     1  0 Apr10 ?        00:00:00 httpd -DFOREGROUND
```

```console {caption="[Shell 3] Host Process", linenos=table}
# Check nginx Container and httpd Container Process from host
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

[Shell 1] shows the process seen from inside the nginx Container, [Shell 2] shows the process seen from inside the httpd Container, and finally [Shell 3] shows the process seen from the Host that runs the nginx Container and httpd Container. Although nginx Container and httpd Container cannot see each other's processes, the Host can see all processes of both containers. This phenomenon occurs due to the characteristics of PID Namespace.

{{< figure caption="[Figure 4] Container PID Namespace" src="images/container-pid-namespace.png" width="900px" >}}

PID Namespace literally means a Namespace that isolates PIDs. The meaning of isolating PIDs, when expanded, is the same as isolating processes. [Figure 4] shows three PID Namespaces: the Host PID Namespace used by the Host, the Container A PID Namespace used by Container A, and the Container B PID Namespace used by Container B. Also, the left side of [Figure 4] shows the relationship between PID Namespaces. PID Namespace is a Namespace with **hierarchy**. The PID Namespace at the top level is called **Init PID Namespace**. The Host PID Namespace is the Init PID Namespace and has Container A and Container B's PID Namespaces as child PID Namespaces.

The process at the highest position in the Process Tree in each Namespace is called the **Init Process of the Namespace**. In [Figure 4], Process A is the Init Process of the Host PID Namespace, and Process D is the Init Process of the Container B PID Namespace. Each process can only access processes belonging to the PID Namespace to which it belongs and processes belonging to child PID Namespaces of the PID Namespace to which it belongs. Therefore, processes belonging to the Host PID Namespace can access processes of Container A and Container B, but processes belonging to containers can only access processes of the container.

Even the same process has different PIDs for each PID Namespace. The Init Process of each Namespace has PID 1 in that Namespace. [Figure 4] also shows PIDs that appear differently for each PID Namespace. Process E appears as PID 5 in Namespace A but as PID 6 in Namespace B. Process B appears as PID 1 in Namespace B because it is the Init Process of Namespace B. If we consider Container A as nginx Container and Container B as httpd Container, we can understand the operation process of [Shell 1~3].

{{< figure caption="[Figure 5] Nested Container PID Namespace" src="images/nested-container-pid-namespace.png" width="900px" >}}

What happens if we create a PID Namespace inside a container? [Figure 5] shows when a Nested Container PID Namespace is created by creating a container in the Container B PID Namespace. A Nested Container PID Namespace is created under the Container B PID Namespace. In the case of running a Docker Container inside a Docker Container (Docker in Docker), the PID Namespace relationship shown in [Figure 5] is created.

{{< figure caption="[Figure 6] Init-Process-Killed" src="images/init-process-killed.png" width="550px" >}}

Finally, an important characteristic of PID Namespace is that when the Init Process of the PID Namespace dies, the remaining processes of the PID Namespace also receive a SIGKILL signal and are forcibly killed by the Linux kernel. Therefore, when the Init Process of a container dies, all processes of the container die, and the container disappears. [Figure 6] shows the process when the Init Process of the PID Namespace dies. When Process C, which is the Init Process of the Container PID Namespace, dies, Process D and Process E also die. Process D and Process E become child processes of Process A, which is the Init Process of the Host Namespace, the parent namespace of the Container PID Namespace. Later, Process A retrieves the meta information of Process D and Process E to prevent them from becoming zombie processes and removes Process D and Process E.

## Container Process Management

{{< figure caption="[Figure 7] Orphan Process, Zombie Process Handling Considering PID Namespace" src="images/orphan-zombie-process-with-pid-namespace.png" width="600px" >}}

What happens when orphan processes and zombie processes occur among container processes? [Figure 6] shows the handling process of orphan processes and zombie processes in a state considering PID Namespace. The handling process of orphan processes and zombie processes in the Host PID Namespace can be easily understood by considering that the Host's Init Process and the Host PID Namespace's Init Process are the same. When Process B terminates, the new parent process of Process D and Process E, which have become orphan processes, becomes Process A, which is the Init Process of the Host PID Namespace. When Process D terminates, Process A retrieves Process D's meta information to prevent Process D from becoming a zombie process.

However, if an orphan process occurs in the Container PID Namespace, the new parent process of the orphan process is not the Init Process of the Host PID Namespace, but **the Init Process of the Container PID Namespace becomes the new parent process.** In [Figure 6], after Process F terminates, Process C becomes the new parent process of Process G and Process H, which have become orphan processes. Therefore, Process C, which is the Init Process of the Container PID Namespace, must also perform the role of removing zombie processes by calling the wait() system call, like Process A, which is the Init Process of the Host PID Namespace.

Since Process C is the Init Process of the Container PID Namespace, when Process C dies later, Process G and Process H of the Container PID Namespace also die. Since Process C does not exist, Process A becomes the new parent process of Process G and Process H, which have become orphans. Process A retrieves the meta information of Process G and Process H to remove Process G and Process H. Even if Process F was in a zombie process state because Process C did not perform the role of removing zombie processes, when Process C dies, Process A becomes the new parent process of Process F, so Process A retrieves Process F's meta information and Process F is removed.

In other words, even if the container's zombie processes are not removed by the container's Init Process, when the container dies, the container's zombie processes are removed by the Init Process such as the Host's systemd. Commands such as supervisord, dumb-init, and tini, which are commonly used as the Init Process of containers, all have the function of retrieving child process meta information, so they perform the role of preventing the container's zombie processes.

```console {caption="[Shell 5] Checking Container's Orphan Process, Zombie Process", linenos=table}
# Run ubuntu Container with Init Process as sleep infinity as Daemon and execute bash Process in ubuntu Container through exec
(host)# docker run -d --rm --name ubuntu ubuntu sleep infinity
(host)# docker exec -it ubuntu bash

# Create sleep 60 Process with bash Process as parent in ubuntu Container
(ubuntu)# bash -c "(bash -c 'sleep 60')" &
(ubuntu)# ps -ef
UID        PID  PPID  C STIME TTY          TIME CMD
root         1     0  0 13:33 ?        00:00:00 sleep infinity
root         6     0  1 13:45 pts/0    00:00:00 bash
root        15     6  0 13:46 pts/0    00:00:00 bash -c (bash -c 'sleep 60')
root        16    15  0 13:46 pts/0    00:00:00 sleep 60
root        17     6  0 13:46 pts/0    00:00:00 ps -ef

# Force kill the bash Process that is the parent Process of sleep 60 Process and check the parent Process of sleep 60 Process
(ubuntu)# kill -9 15
(ubuntu)# ps -ef
UID        PID  PPID  C STIME TTY          TIME CMD
root         1     0  0 13:33 ?        00:00:00 sleep infinity
root         6     0  0 13:45 pts/0    00:00:00 bash
root        16     1  0 13:46 pts/0    00:00:00 sleep 60
root        18     6  0 13:46 pts/0    00:00:00 ps -ef

# After 60 seconds, check that sleep 60 process becomes Zombie Process when it terminates
(ubuntu)# ps -ef
UID        PID  PPID  C STIME TTY          TIME CMD
root         1     0  0 13:33 ?        00:00:00 sleep infinity
root         6     0  0 13:45 pts/0    00:00:00 bash
root        16     1  0 13:46 pts/0    00:00:00 [sleep] <defunct>
root        19     6  0 13:47 pts/0    00:00:00 ps -ef
```

[Shell 5] shows the process of checking orphan processes and zombie processes in a container. In [Shell 5], the Init Process of the ubuntu Container was set to the sleep infinity Process. Then, a bash process was created in the ubuntu Container to make the sleep 60 Process an orphan process. You can see that the parent of the sleep 60 Process becomes sleep infinity, which is the Init Process of the container. The sleep infinity Process does not call the wait() system call, so it cannot perform the function of retrieving dead child process meta information. Therefore, when the sleep 60 Process terminates after 60 seconds, the sleep 60 Process becomes a zombie process. defunct means that it has become a zombie process.

```console {caption="[Shell 6] Container Zombie Process Check and Removal", linenos=table}
# Check ubuntu Container's Zombie Process from Host
(host)# ps -ef
root     12552 12526  0 22:33 ?        00:00:00 sleep infinity
root     18319 12526  0 22:45 pts/0    00:00:00 bash
root     18461 12552  0 22:46 pts/0    00:00:00 [sleep] <defunct>
root     20908 28207  0 22:51 pts/24   00:00:00 ps -ef

# Remove ubuntu Container and check that ubuntu Container's Zombie Process is also removed
(host)# docker rm -f ubuntu
(host)# ps -ef
root     22783 28207  0 22:55 pts/24   00:00:00 ps -ef
```

[Shell 6] shows the process of checking the ubuntu Container's zombie process from the Host and confirming that the container's zombie process is also removed by removing the ubuntu Container. Since the Host can see all processes of the container, the ubuntu Container's zombie process can also be seen in the Host process. After removing the ubuntu Container, you can see that the ubuntu Container's zombie process is also removed.

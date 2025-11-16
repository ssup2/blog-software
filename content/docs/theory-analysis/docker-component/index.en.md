---
title: Docker Component
---

Analyzes the components of Docker.

## 1. Docker Component

{{< figure caption="[Figure 1] Docker Component" src="images/docker-component.png" width="1000px" >}}

[Figure 1] shows the components of Docker version 19.02. The components consist of docker, dockerd, docker-proxy, containerd, containerd-shim, and runc. The roles of each component are as follows.

#### 1.1. docker (Docker Client)

docker performs the role of Docker Client that controls Containers using the HTTP-based REST API provided by Docker Daemon.

#### 1.2. dockerd (Docker Daemon)

Docker Daemon performs the role of Docker Daemon that provides HTTP-based REST API so that Docker Client can control and use Containers. Most requests received from Docker Client are delegated to containerd started by dockerd, and only some requests are processed directly. dockerd performs roles such as starting containerd, Docker Image Build (Dockerfile), Container Network configuration (Bridge, iptables), Container Log recording, and starting docker-proxy.

Docker Daemon's REST API is basically provided through the Unix Domain Socket of the "/var/run/docker.sock" file, and it can also be changed to use TCP Socket by modifying Docker Daemon's options.

#### 1.3. docker-proxy (Docker Proxy)

docker-proxy performs the role of a Proxy Server that forwards Packets from outside the Node into Containers. docker-proxy is not necessarily a required component when running Containers. This is because dockerd running on Linux uses iptables, which operates based on Linux Netfilter Framework, to forward Packets to Containers. However, since iptables cannot be used in all environments where dockerd runs, the use of docker-proxy should be selected according to the environment. Whether docker-proxy is used is determined by dockerd's configuration that runs docker-proxy.

dockerd runs an additional docker-proxy responsible for that Port each time a Port Forwarding Option is added to a Container. For example, if Port Forwarding is set for Ports 10 and 20 on Container A, and Port Forwarding is set for Ports 30 and 40 on Container B, a total of 4 docker-proxy processes will run. Since running multiple docker-proxy processes can burden the Node, it is good to configure dockerd not to use docker-proxy if dockerd is in an environment where Linux's iptables can be used.

#### 1.4. containerd

containerd performs the role of a Daemon that creates config.json (Container Config) files according to dockerd's requests that comply with OCI (Open Container Initiative) Runtime Spec, and creates containers using containerd-shim and runc. containerd also performs the role of pulling Container Images from Container Image Server based on OCI Image Spec if the Container Images necessary for running Containers do not exist on the Node. Container Snapshot functionality is also performed by containerd.

containerd basically provides gRPC-based REST API through the Unix Domain Socket of "/run/containerd/containerd.sock". containerd also provides a dedicated CLI Client called ctr for containerd. containerd provides Namespace functionality, and Docker creates all Containers in a Namespace named "moby".

#### 1.5. runc

runc performs the role of actually creating Containers through config.json (Container Config) files created by containerd. config.json is written based on OCI Runtime Spec. runc is executed by containerd-shim, not containerd, and runc's stdin/out/err uses the stdin/out/err of the Process that executed runc as-is. Therefore, runc's stdin/out/err is the same as containerd-shim's. runc has the characteristic that it does not wait until the Container terminates after creating the Container, but terminates immediately.

#### 1.6. containerd-shim

containerd-shim operates one per Container between containerd and runc, making Container's stdin/out/err accessible from other Processes through Named Pipe, and performs the role of delivering the ExitCode of Container Init Process (Container's Process 1) to containerd through containerd's "/run/containerd/containerd.sock" Unix Domain Socket when it terminates. containerd-shim is needed because containerd can be restarted at any time and runc only creates Containers and terminates, so a Process is needed to handle Container's stdin/out/err and Container Init Process's Exit Code.

containerd-shim also performs operations such as checking the status of Container Init Process and fork() & exec() operations to launch separate Processes inside Containers according to containerd's commands transmitted through the Unix Domain Socket named "@/containerd-shim/moby/[containerID]/shim.sock@". containerd-shim's Unix Domain Socket basically operates in a form where no separate file exists, and can also operate in a form that creates a Unix Domain Socket at a specific path through containerd-shim's options.

Since runc's stdin/stdout/stderr creates Containers in a state set as Named Pipe by containerd-shim, the created Container's stdin/out/err is set as Named Pipe. Named Pipe's path is located at "/run/docker/containerd/[containerID]/init-[stdin/out/err]" and is created by containerd-shim receiving the path requested by dockerd to containerd again. dockerd collects Container's stdout/stderr (Log) through Named Pipe, and also uses Named Pipe when connecting Container's stdin/out to Terminal according to Container execution options.

```shell {caption="[Shell 1] Docker Components pstree "}
# pstree
systemd-+-containerd-+-containerd-shim-+-bash
        |            |                 `-9*[{containerd-shim}]
...
        |-dockerd-+-docker-proxy---6*[{docker-proxy}]
        |         `-29*[{dockerd}]
...
```

Linux basically sets the Node's Process 1, Node Init Process, as the new parent Process of orphan Processes when orphan Processes occur. When creating a Container through runc, the parent Process of Container Init Process becomes runc. After runc terminates, the parent Process of Container Init Process should originally become Node Init Process, but as can be seen in [Shell 1], containerd-shim Process becomes the new parent Process. This is because containerd-shim sets itself as a **Subreaper** Process using the prctl() System Call before executing runc.

Subreaper Process means that when an orphan Process occurs among all its child Processes, instead of Node Init Process becoming the new parent, it itself adopts the orphan Process and becomes the new parent Process. Since Container Init Process's parent Process is containerd-shim, when Container Init Process terminates, containerd-shim receives a SIGCHLD Signal and can obtain Container Init Process's ExitCode.

## 2. References

* [https://iximiuz.com/en/posts/implementing-container-runtime-shim/?utm-medium=reddit&utm-source=r-kubernetes](https://iximiuz.com/en/posts/implementing-container-runtime-shim/?utm-medium=reddit&utm-source=r-kubernetes)
* [http://alexander.holbreich.org/docker-components-explained/](http://alexander.holbreich.org/docker-components-explained/)
* [http://cloudrain21.com/examination-of-docker-process-binary](http://cloudrain21.com/examination-of-docker-process-binary)
* [https://unix.stackexchange.com/questions/206386/what-does-the-symbol-denote-in-the-beginning-of-a-unix-domain-socket-path-in-l](https://unix.stackexchange.com/questions/206386/what-does-the-symbol-denote-in-the-beginning-of-a-unix-domain-socket-path-in-l)
* [https://github.com/containerd/containerd/pull/2631](https://github.com/containerd/containerd/pull/2631)
* [https://windsock.io/the-docker-proxy/](https://windsock.io/the-docker-proxy/)


---
title: Docker Installation, Configuration / WSL1 Environment / Windows 10 Environment
---

## 1. Installation, Configuration Environment

The installation and configuration environment is as follows:
* Windows 10 Pro 64bit
  * Virtualization feature ON in BIOS

## 2. Docker for Windows Installation

Install Docker for Windows for using Docker from Visual Studio Code Terminal.
* [https://docs.docker.com/docker-for-windows](https://docs.docker.com/docker-for-windows)

{{< figure caption="[Figure 1] Docker for Windows Installation" src="images/docker-install-01.png" width="700px" >}}

After installation completion as shown in [Figure 1], run Docker for Windows to activate Hyper-V. Docker for Windows runs Docker in a VM created with Hyper-V.

{{< figure caption="[Figure 2] Docker Port Configuration" src="images/docker-install-02.png" width="800px" >}}

As shown in [Figure 2], open Docker Daemon on port 2375 so that WSL Ubuntu can access Docker.

```shell
> route add 172.17.0.0 MASK 255.255.0.0 10.0.75.2
```

Add routing rules so that Windows can directly access Container IPs. Add routing rules related to the default Docker Network 172.17.0.0/24 Network. Run PowerShell as administrator and enter the above command.

## 3. Docker Installation, Configuration in WSL1

```shell
$ apt update
$ apt install docker.io
$ apt install docker-compose
$ echo "export DOCKER-HOST=tcp://localhost:2375" >> ~/.bashrc && source ~/.bashrc
```

Install and configure Docker and Docker Compose. Run WSL Ubuntu and install Docker packages for Docker Client. Specify Docker Host in Bash to connect with Docker for Windows Docker. Enter the above command in WSL Ubuntu.

## 4. References

* [https://nickjanetakis.com/blog/setting-up-docker-for-windows-and-wsl-to-work-flawlessly](https://nickjanetakis.com/blog/setting-up-docker-for-windows-and-wsl-to-work-flawlessly)
* [https://forums.docker.com/t/connecting-to-containers-ip-address/18817](https://forums.docker.com/t/connecting-to-containers-ip-address/18817)
* [https://webdir.tistory.com/543](https://webdir.tistory.com/543)

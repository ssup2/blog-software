---
title: Docker Installation and Setting / WSL1 Environment / Windows 10 Environment
---

## 1. Installation and Setting Environment

The installation and setting environment is as follows.
* Windows 10 Pro 64bit
  * Virtualization feature ON in Bios

## 2. Docker for Windows Installation

Install Docker for Windows for using Docker in Visual Studio Code's Terminal.
* [https://docs.docker.com/docker-for-windows](https://docs.docker.com/docker-for-windows)

{{< figure caption="[Figure 1] Docker for Windows Installation" src="images/docker-install-01.png" width="700px" >}}

After installation is complete as in [Figure 1], run Docker for Windows to activate Hyper-V. Docker for Windows has a structure that runs Docker in VMs created with Hyper-V.

{{< figure caption="[Figure 2] Docker Port Setting" src="images/docker-install-02.png" width="800px" >}}

Open Docker Daemon to port 2375 as in [Figure 2] so that Docker can be accessed from WSL Ubuntu.

```shell
> route add 172.17.0.0 MASK 255.255.0.0 10.0.75.2
```

Add Routing Rules so that Container IPs can be directly accessed from Windows. Add Routing Rules related to the 172.17.0.0/24 Network, which is the Default Docker Network. Run PowerShell with administrator privileges and enter the above command.

## 3. Docker Installation and Setting in WSL1

```shell
$ apt update
$ apt install docker.io
$ apt install docker-compose
$ echo "export DOCKER-HOST=tcp://localhost:2375" >> ~/.bashrc && source ~/.bashrc
```

Install and set up Docker and Docker Compose. Run WSL Ubuntu and install Docker Package for Docker Client. Specify Docker Host in Bash to connect with Docker from Docker for Windows. Enter the above command in WSL Ubuntu.

## 4. References

* [https://nickjanetakis.com/blog/setting-up-docker-for-windows-and-wsl-to-work-flawlessly](https://nickjanetakis.com/blog/setting-up-docker-for-windows-and-wsl-to-work-flawlessly)
* [https://forums.docker.com/t/connecting-to-containers-ip-address/18817](https://forums.docker.com/t/connecting-to-containers-ip-address/18817)
* [https://webdir.tistory.com/543](https://webdir.tistory.com/543)

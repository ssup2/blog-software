---
title: Docker 설치, 설정 / WSL1 환경 / Windows 10 환경
---

## 1. 설치, 설정 환경

설치, 설정 환경은 다음과 같다.
* Windows 10 Pro 64bit
  * Bios에서 Virtualization 기능 ON

## 2. Docker for Windows 설치

Visual Studio Code의 Terminal에서 Docker 이용을 위한 Docker for Windows를 설치한다.
* [https://docs.docker.com/docker-for-windows](https://docs.docker.com/docker-for-windows)

{{< figure caption="[Figure 1] Docker for Windows 설치" src="images/docker-install-01.png" width="700px" >}}

[Figure 1]과 같이 설치 완료후 Docker for Windows를 실행하여 Hyper-V를 활성화한다. Docker for Windows는 Hyper-V로 생성한 VM에서 Docker를 실행하는 구조이다.

{{< figure caption="[Figure 2] Docker Port 설정" src="images/docker-install-02.png" width="800px" >}}

[Figure 2]와 같이 WSL Ubuntu에서 Docker에 접근할 수 있도록 Docker Daemon을 2375 Port로 개방한다.

```shell
> route add 172.17.0.0 MASK 255.255.0.0 10.0.75.2
```

Windows에서 Container의 IP에 바로 접근할 수 있도록 Routing Rule을 추가한다. Default Docker Network인 172.17.0.0/24 Network 관련 Routing Rule을 추가한다. PowerShell을 관리자 권한으로 실행하여 위의 명령어를 입력한다.

## 3. WSL1에서 Docker 설치, 설정

```shell
$ apt update
$ apt install docker.io
$ apt install docker-compose
$ echo "export DOCKER-HOST=tcp://localhost:2375" >> ~/.bashrc && source ~/.bashrc
```

Docker, Docker Compose 설치 및 설정한다. WSL Ubuntu를 실행하여 Docker Client를 위해서 Docker Package를 설치한다. Docker for Windows의 Docker와 연결하기 위해서 Bash에 Docker Host를 지정한다. WSL Ubuntu에서 위의 명령어를 입력한다.

## 4. 참조

* [https://nickjanetakis.com/blog/setting-up-docker-for-windows-and-wsl-to-work-flawlessly](https://nickjanetakis.com/blog/setting-up-docker-for-windows-and-wsl-to-work-flawlessly)
* [https://forums.docker.com/t/connecting-to-containers-ip-address/18817](https://forums.docker.com/t/connecting-to-containers-ip-address/18817)
* [https://webdir.tistory.com/543](https://webdir.tistory.com/543)
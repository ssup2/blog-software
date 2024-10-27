---
title: WSL 설치 / Windows 10 환경
---

## 1. 설치 환경

설치, 설정 환경은 다음과 같다.

* Windows 10 Pro 64bit

## 2. WSL Ubuntu 설치

{{< figure caption="[Figure 1] 개발자 모드 설정" src="images/developer-mode.png" width="600px" >}}

WSL (Windows Subsystem for Linux) Bash를 활성화한다. 개발자 기능 사용을 검색하여 실행한다. [그림 1]과 같이 **개발자 모드**로 변경한다.

{{< figure caption="[Figure 2] WSL 기능 활성화" src="images/wsl-enable.png" width="500px" >}}

[그림 2]와 같이 Windows 기능에서 WSL을 활성화 한다.

{{< figure caption="[Figure 3] WSL Ubuntu 설치" src="images/ubuntu-install.png" width="600px" >}}

WSL Ubuntu 설치한다. [그림 3]과 같이 Store에서 Ubuntu를 검색하여 설치하고 재부팅한다.

## 3. WSL Ubuntu root 설정

```shell
$ sudo passwd root
Enter new UNIX password:
Retype new UNIX password:
passwd: password updated successfully
```

WSL Ubuntu의 root 계정을 생성한다. WSL Ubuntu를 설치 후 처음으로 실행하면 WSL Ubuntu에서 이용할 User와 Password를 입력 받는다. WSL Ubuntu에서 위의 명령를 실행한다.

```shell
$ ubuntu config --default-user root
```

WSL Ubuntu가 Default 계정으로 root를 이용하도록 설정한다. WSL Ubuntu를 종료한 다음, PowerShell을 관리자 권한으로 실행하여 위의 명령어를 실행한다.

## 4. WSLtty 설치, 설정

* [https://github.com/mintty/wsltty/releases](https://github.com/mintty/wsltty/releases)

위의 링크에서 Installer를 받아 설치한다.

``` {caption="[File 1] WSLtty grubbox Theme", linenos=table}
ForegroundColour=235,219,178
BackgroundColour=29,32,33
CursorColour=253,157,79
Black=40,40,40
BoldBlack=146,131,116
Red=204,36,29
BoldRed=251,73,52
Green=152,151,26
BoldGreen=184,187,38
Yellow=215,153,33
BoldYellow=250,189,47
Blue=69,133,136
BoldBlue=131,165,152
Magenta=177,98,134
BoldMagenta=211,134,155
Cyan=104,157,106
BoldCyan=142,192,124
White=168,153,132
BoldWhite=235,219,178
```

%APPDATA%\wsltty\themes\grubbox 파일을 생성하고 [File 1]의 내용으로 저장하여 wsltty에서 이용할 grubbox Theme를 설정한다.

``` {caption="[File 2] WSLtty Config", linenos=table}
# To use common configuration in %APPDATA%\mintty, simply remove this file
ThemeFile=gruvbox
Term=xterm-256color
FontHeight=10
AllowSetSelection=yes
```

%APPDATA%\wsltty\config 파일을 [File 2]의 내용으로 수정한다.

## 5. 참고

* [https://github.com/mintty/wsltty](https://github.com/mintty/wsltty)
---
title: WSL Installation / Windows 10 Environment
---

## 1. Installation Environment

The installation and configuration environment is as follows.

* Windows 10 Pro 64bit

## 2. WSL Ubuntu Installation

{{< figure caption="[Figure 1] Developer Mode Configuration" src="images/developer-mode.png" width="600px" >}}

Enable WSL (Windows Subsystem for Linux) Bash. Search for and run "Use developer features". Change to **Developer Mode** as shown in [Figure 1].

{{< figure caption="[Figure 2] WSL Feature Enable" src="images/wsl-enable.png" width="500px" >}}

Enable WSL in Windows features as shown in [Figure 2].

{{< figure caption="[Figure 3] WSL Ubuntu Installation" src="images/ubuntu-install.png" width="600px" >}}

Install WSL Ubuntu. Search for Ubuntu in the Store as shown in [Figure 3], install it, and reboot.

## 3. WSL Ubuntu root Configuration

```shell
$ sudo passwd root
Enter new UNIX password:
Retype new UNIX password:
passwd: password updated successfully
```

Create a root account for WSL Ubuntu. When you run WSL Ubuntu for the first time after installation, you will be prompted to enter a user and password for WSL Ubuntu. Execute the above command in WSL Ubuntu.

```shell
$ ubuntu config --default-user root
```

Configure WSL Ubuntu to use root as the default account. Exit WSL Ubuntu, then run PowerShell as administrator and execute the above command.

## 4. WSLtty Installation and Configuration

* [https://github.com/mintty/wsltty/releases](https://github.com/mintty/wsltty/releases)

Download and install the installer from the link above.

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

Create the %APPDATA%\wsltty\themes\grubbox file and save it with the content from [File 1] to configure the grubbox theme for use in wsltty.

``` {caption="[File 2] WSLtty Config", linenos=table}
# To use common configuration in %APPDATA%\mintty, simply remove this file
ThemeFile=gruvbox
Term=xterm-256color
FontHeight=10
AllowSetSelection=yes
```

Modify the %APPDATA%\wsltty\config file with the content from [File 2].

## 5. References

* [https://github.com/mintty/wsltty](https://github.com/mintty/wsltty)


---
title: WSL2 Samba Installation / Windows 10 Environment
---

## 1. Installation Background

WSL2 VMs have a problem where I/O performance does not appear for directories under /mnt shared with Windows OS. This document summarizes a method to work around this issue by installing and using a Samba Server inside the WSL2 VM.

## 2. Installation Environment

The installation and configuration environment is as follows.
* Windows 10 Pro 64bit
* WSL2 Ubuntu 20.04, root User

## 3. Samba Server Installation on Ubuntu

```shell
(WSL2 Ubuntu)$ apt update
(WSL2 Ubuntu)$ apt install samba
(WSL2 Ubuntu)$ smbpasswd -a root
New SMB password:
Retype new SMB password:
Added user root.
```

Install the Samba Server inside the WSL2 VM and add a root user for the Samba Server.

```text {caption="[File 1] /etc/samba/smb.conf", linenos=table}
{% highlight text %}
[homes]
  comment = home directories
  valid users = %S
  browseable = no
  read only = no
{% endhighlight %}
```

Add the content from [File 1] to the /etc/samba/smb.conf file.

```shell
(WSL2 Ubuntu)# service smbd restart
```

Restart the Samba Server.

## 4. Add Port Forwarding Rule to WSL2 VM

WSL2 VM IP changes every time it reboots. Therefore, configure a Port Forwarding Rule on Windows OS so that when a Samba connection occurs to localhost, the connection is forwarded to the WSL2 VM.

```shell {caption="[File 2] C:\route_ssh_to_wsl.ps1"}
wsl -d ubuntu -u root service smbd restart
wsl -d ubuntu -u root ip addr add 192.168.10.100/24 broadcast 192.168.10.255 dev eth0 label eth0:1
netsh interface ip add address "vEthernet (WSL)" 192.168.10.50 255.255.255.0
```

Create the script from [File 2]. The script makes connections to 192.168.10.100 connect to the Samba Server.

## 5. Register Script as Startup Script

```shell
(Windows)$ $trigger= New-JobTrigger -AtStartup -RandomDelay 00:00:15
(Windows)$ Register-ScheduledJob -Trigger $trigger -FilePath C:\route_ssh_to_wsl.ps1 -Name RouteSSHtoWSL
```

## 6. Samba Server Access

After rebooting Windows OS, access the following address from File Browser.
* \\\\192.168.10.100\root

## 7. References

* [https://embeddedaroma.tistory.com/64](https://embeddedaroma.tistory.com/64)
* [https://www.python2.net/questions-1217707.htm](https://www.python2.net/questions-1217707.htm)


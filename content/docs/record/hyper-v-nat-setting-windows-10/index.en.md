---
title: Hyper-V NAT Configuration / Windows 10 Environment
---

## 1. Configuration Environment

The configuration environment is as follows.
* NAT Network
  * Network : 172.35.0.0/24
  * Gateway : 172.35.0.1
  * Switch Name : NAT-Switch
  * Network Name : NAT-Network
* VM
  * Address : 172.35.0.100

## 2. Switch Creation and NAT Configuration

```powershell
> New-VMSwitch -SwitchName "NAT-Switch" -SwitchType Internal
> $AdapterName=(Get-NetAdapter -Name "vEthernet (NAT-Switch)").Name
> New-NetIPAddress -IPAddress 172.35.0.1 -PrefixLength 24 -InterfaceAlias $AdapterName
> New-NetNat -Name NAT-Network -InternalIPInterfaceAddressPrefix 172.35.0.0/24
```

Execute the above commands in PowerShell with administrator privileges.

## 3. VM

```yaml {caption="[File 1] /etc/netplan/50-cloud-init.yaml", linenos=table}
# This file is generated from information provided by
# the datasource.  Changes to it will not persist across an instance.
# To disable cloud-init's network configuration capabilities, write a file
# /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg with the following:
# network: {config: disabled}
network:
    ethernets:
        eth0:
            addresses:
                - 172.35.0.100/24
            dhcp4: false
            gateway4: 172.35.0.1
            nameservers:
                addresses:
                    - 8.8.8.8
                search: []
    version: 2
```

Configure the /etc/netplan/50-cloud-init.yaml file as shown in [File 1]. Since there is no DHCP Server in the Network configured with NAT, manual IP configuration is required.

```shell
$ netplan apply
```

Apply the changed Network configuration.

## 4. References
* [https://deploywindows.com/2017/06/01/missing-nat-in-windows-10-hyper-v/](https://deploywindows.com/2017/06/01/missing-nat-in-windows-10-hyper-v/)


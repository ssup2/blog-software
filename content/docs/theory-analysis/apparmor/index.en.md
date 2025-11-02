---
title: AppArmor
---

Analyze AppArmor, one of the Security Modules of the Linux LSM (Linux Security Module) Framework.

## 1. AppArmor

AppArmor is a MAC (Mandatory Access Control) based Security Module that operates on the Linux LSM Framework. AppArmor restricts the operation of programs (binaries) through **System Call** restrictions. The operation restrictions for each program are delivered to AppArmor through **AppArmor Profile** files.

AppArmor operates in two modes: Enforcement and Complain.
* Enforcement : Restricts unauthorized operations of programs and logs them. This mode is used when actually operating programs and restricting their operations.
* Complain : Does not restrict unauthorized operations of programs but only logs them. This mode is used when writing AppArmor Profiles for specific programs. Logs can help with writing AppArmor Profiles.

```shell {caption="[Shell 1] Check AppArmor Status"}
$ aa-status
apparmor module is loaded.
29 profiles are loaded.
29 profiles are in enforce mode.
   /sbin/dhclient
   /usr/bin/evince
   /usr/bin/evince-previewer
   /usr/bin/evince-previewer//sanitized_helper
   /usr/bin/evince-thumbnailer
   /usr/bin/evince-thumbnailer//sanitized_helper
   /usr/bin/evince//sanitized_helper
   /usr/bin/lxc-start
   /usr/bin/ubuntu-core-launcher
   /usr/lib/NetworkManager/nm-dhcp-client.action
   /usr/lib/NetworkManager/nm-dhcp-helper
   /usr/lib/connman/scripts/dhclient-script
   /usr/lib/cups/backend/cups-pdf
   /usr/lib/lightdm/lightdm-guest-session
   /usr/lib/lightdm/lightdm-guest-session//chromium
   /usr/lib/lxd/lxd-bridge-proxy
   /usr/sbin/cups-browsed
   /usr/sbin/cupsd
   /usr/sbin/cupsd//third_party
   /usr/sbin/ippusbxd
   /usr/sbin/mysqld
   /usr/sbin/tcpdump
   docker-default
   lxc-container-default
   lxc-container-default-cgns
   lxc-container-default-with-mounting
   lxc-container-default-with-nesting
   webbrowser-app
   webbrowser-app//oxide_helper
0 profiles are in complain mode.
14 processes have profiles defined.
14 processes are in enforce mode.
   /usr/bin/lxc-start (12311)
   /usr/sbin/cups-browsed (1944)
   docker-default (17235)
   docker-default (17259)
   docker-default (17270)
   docker-default (17350)
   docker-default (17351)
   lxc-container-default-cgns (12320)
   lxc-container-default-cgns (12462)
   lxc-container-default-cgns (12501)
   lxc-container-default-cgns (12502)
   lxc-container-default-cgns (12503)
   lxc-container-default-cgns (12504)
   lxc-container-default-cgns (12505)
0 processes are in complain mode.
0 processes are unconfined but have a profile defined.
```

[Shell 1] shows the result of querying AppArmor's status using the aa-status command. You can check the Profiles available to AppArmor and Processes that have Profiles applied. AppArmor's information is located in the /sys/kernel/security/apparmor folder, and the aa-status command organizes and displays the contents of the /sys/kernel/security/apparmor folder.

### 1.1. AppArmor Profile

AppArmor Profile names can be classified into names starting with `/` and names that do not start with `/`. For Profiles starting with `/`, the Profile name represents the program to which the Profile will be applied. Among the Profile list queried in [Shell 1], you can see the /usr/sbin/tcpdump Profile, and when the /usr/sbin/tcpdump program is executed, the /usr/sbin/tcpdump Profile is automatically applied. For Profiles that do not start with `/`, the Profile must be manually applied using the aa-exec command when executing a specific program. Of course, Profiles starting with `/` can also be applied to specific programs using the aa-exec command. Profiles are located in **/etc/apparmor.d**.

```text {caption="[File 1] /etc/apparmor.d/test/apparmor-example AppArmor Profile", linenos=table}
#include <tunables/global>

profile apparmor-example {
  #include <abstractions/base>

  capability net_admin,
  capability setuid,
  capability setgid,

  mount fstype=proc -> /mnt/proc/**,

  /etc/hosts.allow rw,
  /root/test.sh rwix,
  /root/test_file w,

  network tcp,
}
```

[File 1] shows an example AppArmor Profile called apparmor-example. It has the following meanings.

* Can use net_admin, setuid, setgid Capabilities.
* Can mount proc File System only under the /mnt/proc path.
* Can read and write the /etc/hosts.allow file.
* Can read, write, and execute the /root/test.sh file.
* Can only write the /root/test_file file.
* Can only use tcp protocol.

```shell {caption="[Shell 2] Register and Check AppArmor Profile"}
$ apparmor_parser /etc/apparmor.d/test/apparmor-example
$ aa-status
apparmor module is loaded.
30 profiles are loaded.
30 profiles are in enforce mode.
...
   /usr/sbin/tcpdump
   apparmor-example
   docker-default
   lxc-container-default
   lxc-container-default-cgns
...
```

[Shell 2] shows the process of registering the written Profile to AppArmor using the apparmor_parser command and checking Profile registration using the aa-status command. After registration is complete, you can check the apparmor-example Profile through the aa-status command.

```shell {caption="[Shell 3] Apply AppArmor to cat, echo Commands"}
$ echo test > /root/test_file
$ aa-exec -p apparmor-example cat /root/test_file
cat: /root/test_file: Permission denied
$ aa-exec -p apparmor-example echo apparmor > /root/test_file
$ cat /root/test_file
apparmor
```

[Shell 3] shows an example of applying the apparmor-example Profile using the aa-exec command and executing read/write operations on the "/root/test_file" file. Since only write permission is applied to the `/root/test_file` file in the Profile, you can see that write operations are performed but read operations are not performed.

## 2. References

* [http://wiki.apparmor.net](http://wiki.apparmor.net)
* [https://wiki.ubuntu.com/AppArmor](https://wiki.ubuntu.com/AppArmor)


---
title: Linux Log
---

Analyze Linux Log-related components and roles.

## 1. Linux Log

{{< figure caption="[Figure 1] Linux Log Components" src="images/linux-log-component.png" width="800px" >}}

[Figure 1] shows Linux Log-related components. Logs can be classified into Kernel Logs and User Logs.

### 1.1. Kernel Log

Kernel Log literally means Logs left by the Kernel. Ring Buffer is a Kernel Memory space that temporarily stores Kernel Logs. Since it is Memory, previous Kernel Log contents disappear when rebooting. Also, since it is a Ring Buffer, when Kernel Logs exceed the Ring Buffer capacity, older Kernel Logs are overwritten first. Ring Buffer can be accessed and controlled through the Kernel's `do-syslog()` function. The `printk()` function used in the Kernel to leave Kernel Logs actually performs the operation of writing Kernel Logs to the Ring Buffer through the `do-syslog()` function.

The `syslog(2)` function (System Call) or `/proc/kmsg` file used to obtain Kernel Logs at the User Level accesses the Ring Buffer through the `do-syslog()` function to obtain Kernel Logs. `dmesg` allows users to view Kernel Logs through the `syslog(2)` function. Also, `rsyslogd` or `systemd-journald` records Kernel Logs obtained through `syslog(2)` or `/proc/kmsg` as files in the `/var/log` folder for storage.

### 1.2. User Log

User Log means Logs left by Apps. Apps can leave App Logs using the `syslog(3)` function. The `syslog(3)` function delivers App Logs to `rsyslogd` or `systemd-journald` through the `/dev/log` Domain Socket. `rsyslogd` or `systemd-journald` records the received App Logs as files in the `/var/log` folder.

## 2. References

* [https://www.ibm.com/developerworks/library/l-kernel-logging-apis/](https://www.ibm.com/developerworks/library/l-kernel-logging-apis/)
* [https://unix.stackexchange.com/questions/205883/understand-logging-in-linux/294206#294206](https://unix.stackexchange.com/questions/205883/understand-logging-in-linux/294206#294206)
* [https://unix.stackexchange.com/questions/35851/whats-the-difference-of-dmesg-output-and-var-log-messages](https://unix.stackexchange.com/questions/35851/whats-the-difference-of-dmesg-output-and-var-log-messages)


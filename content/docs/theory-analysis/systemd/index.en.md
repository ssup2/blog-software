---
title: systemd
---

This document analyzes systemd, which is used as the Init Process in most Linux OS today.

## 1. systemd

systemd is a System and Service Manager that manages the OS comprehensively through cooperation with the Linux Kernel. Initially, it was developed to replace the poor Service (Daemon) management functionality of SysVinit, which was commonly used as the Init Process. Over time, systemd has added functionality to manage System Resources such as Log, User Session, Network, Device, Mount, in addition to Service management functionality, and now performs the role of managing the overall System.

SysVinit provided only limited Service functionality such as executing Service Scripts written by System administrators and managing Service Processes. systemd can control Services in detail through Service Config files and also provides Service Log management functionality. It also provides an environment where communication between Services can be easily implemented through D-BUS, a Message BUS between Processes.

SysVinit performed Services sequentially, but systemd executes and initializes multiple Services in parallel. Therefore, systemd enables faster Booting and System initialization compared to SysVinit. For backward compatibility, it also supports SysVinit's Init Script and LSB (Linux Standard Base) Script.

### 1.1. journald

journald is a Daemon that stores and manages major Logs in Linux. journald leaves the following contents as Logs under the **/var/log/journal** folder.

* Records Kernel Logs transmitted through /proc/kmsg.
* Records Logs left by Apps through the syslog(3) function. Logs are transmitted to journald through the /dev/log (/run/systemd/journal/dev-log) Domain Socket.
* Records Logs transmitted through APIs provided by journald such as the sd-journal-sendv() function. Logs are transmitted to journald through the /run/systemd/journal/socket Domain Socket.
* Records stdout and stderr of systemd Services as Logs. Logs are transmitted to journald through /run/systemd/journal/stdout.
* Records Audit Logs.

The /dev/log Domain Socket is a Domain Socket that was used when rsyslogd received logs and left Logs under the /var/log folder before journald appeared. Therefore, when rsyslogd operates together with journald, it can receive Logs through the following 2 methods:

* Logs can be transmitted to rsyslogd through the /run/systemd/journal/syslog Domain Socket.
* The imjournal Module transmits Logs recorded by journald to rsyslogd.

journald uses Structure instead of Plain Text like rsyslogd when recording Logs, storing not only Logs but also Meta information of Logs together. Through Structure, journald can quickly search or filter Logs. Since journald is a Structure structure, it is difficult to check Logs with Standard UNIX Tools like cat. Logs can be checked with the **journalctl** command provided by journald.

## 2. References

* [https://en.wikipedia.org/wiki/Systemd](https://en.wikipedia.org/wiki/Systemd)
* [https://www.maketecheasier.com/systemd-what-you-need-to-know-linux/](https://www.maketecheasier.com/systemd-what-you-need-to-know-linux/)
* journald : [https://unix.stackexchange.com/questions/205883/understand-logging-in-linux/](https://unix.stackexchange.com/questions/205883/understand-logging-in-linux/)
* journald : [https://askubuntu.com/questions/925440/relationship-of-rsyslog-and-journald-on-ubuntu-16-04](https://askubuntu.com/questions/925440/relationship-of-rsyslog-and-journald-on-ubuntu-16-04)
* jorunald : [https://www.loggly.com/blog/why-journald/](https://www.loggly.com/blog/why-journald/)



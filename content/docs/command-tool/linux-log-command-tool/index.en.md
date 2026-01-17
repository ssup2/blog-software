---
title: Linux Log Command, Tool
---

This document summarizes Linux log-related commands and tools.

## 1. Linux Log Command, Tool

### 1.1. dmesg

```shell {caption="[Shell 1] dmesg"}
$ dmesg -H
[Sep23 00:14] Linux version 4.15.0-60-generic (buildd@lgw01-amd64-030) (gcc version 7.4.0 (Ubuntu 7.4.0-1ubuntu1~18.04.1)) #67-Ubuntu SMP Thu Aug 22 16:55:30 UTC 2019 (Ubuntu 4.15.0-60.67-generic 4.15.18)
[  +0.000000] Command line: BOOT_IMAGE=/boot/vmlinuz-4.15.0-60-generic root=UUID=c30770af-2d12-43ce-8bf2-1480721d056e ro
[  +0.000000] KERNEL supported cpus:
[  +0.000000]   Intel GenuineIntel
[  +0.000000]   AMD AuthenticAMD
[  +0.000000]   Centaur CentaurHauls
[  +0.000000] x86/fpu: Supporting XSAVE feature 0x001: 'x87 floating point registers'
[  +0.000000] x86/fpu: Supporting XSAVE feature 0x002: 'SSE registers'
[  +0.000000] x86/fpu: Supporting XSAVE feature 0x004: 'AVX registers'
[  +0.000000] x86/fpu: Supporting XSAVE feature 0x008: 'MPX bounds registers'
[  +0.000000] x86/fpu: Supporting XSAVE feature 0x010: 'MPX CSR'
```

dmesg is a tool that shows the contents of kernel logs stored in the Linux kernel's log ring buffer. [Shell 1] shows the output of `dmesg -H` displaying kernel logs. Content output by the printk() function in the Linux kernel is stored in the log ring buffer. Since the log ring buffer is located in kernel memory space, it disappears upon reboot. Also, if more logs than the size of the log ring buffer are stored, previous log content is overwritten and disappears.

### 1.2. /var/log/kern.log

```shell {caption="[Shell 2] /var/log/kern.log"}
$ cat /var/log/kern.log
Sep 20 14:33:10 vm kernel: [    0.000000] Linux version 4.15.0-60-generic (buildd@lgw01-amd64-030) (gcc version 7.4.0 (Ubuntu 7.4.0-1ubuntu1~18.04.1)) #67-Ubuntu SMP Thu Aug 22 16:55:30 UTC 2019 (Ubuntu 4.15.0-60.67-generic 4.15.18)
Sep 20 14:33:10 vm kernel: [    0.000000] Command line: BOOT_IMAGE=/boot/vmlinuz-4.15.0-60-generic root=UUID=c30770af-2d12-43ce-8bf2-1480721d056e ro
Sep 20 14:33:10 vm kernel: [    0.000000] KERNEL supported cpus:
Sep 20 14:33:10 vm kernel: [    0.000000]   Intel GenuineIntel
Sep 20 14:33:10 vm kernel: [    0.000000]   AMD AuthenticAMD
Sep 20 14:33:10 vm kernel: [    0.000000]   Centaur CentaurHauls
Sep 20 14:33:10 vm kernel: [    0.000000] x86/fpu: Supporting XSAVE feature 0x001: 'x87 floating point registers'
Sep 20 14:33:10 vm kernel: [    0.000000] x86/fpu: Supporting XSAVE feature 0x002: 'SSE registers'
Sep 20 14:33:10 vm kernel: [    0.000000] x86/fpu: Supporting XSAVE feature 0x004: 'AVX registers'
Sep 20 14:33:10 vm kernel: [    0.000000] x86/fpu: Supporting XSAVE feature 0x008: 'MPX bounds registers'
Sep 20 14:33:10 vm kernel: [    0.000000] x86/fpu: Supporting XSAVE feature 0x010: 'MPX CSR' 
```

rsyslogd or systemd-journald copies and stores kernel logs stored in the Linux kernel's log ring buffer to `/var/log/kern.log`. [Shell 2] shows the output of `/var/log/kern.log`. Since `/var/log/kern.log` is a file, kernel log content remains in `/var/log/kern.log` even after reboot, and previous log content is not overwritten.

### 1.3. /var/log/syslog

```shell {caption="[Shell 3] /var/log/syslog"}
$ cat /var/log/syslog
Aug  1 06:25:59 node09 dockerd[1772]: time="2019-08-01T06:25:59.815896062Z" level=info msg="shim reaped" id=5c16c868b50c0a938a2ac2ae4c1aeb9924114b8a278d8d30f9527ca36f1d00cb
Aug  1 06:25:59 node09 dockerd[1772]: time="2019-08-01T06:25:59.825852795Z" level=info msg="ignoring event" module=libcontainerd namespace=moby topic=/tasks/delete type="*events.TaskDelete"
Aug  1 06:26:03 node09 dockerd[1772]: time="2019-08-01T06:26:03.088304486Z" level=info msg="shim containerd-shim started" address="/containerd-shim/moby/
```

rsyslogd or systemd-journald stores service (daemon) logs in `/var/log/syslog`. [Shell 3] shows the output of service logs stored in `/var/log/syslog`.

### 1.4. journalctl

```shell {caption="[Shell 4] /var/log/kern.log"}
$ journalctl -xu ssh
-- Logs begin at Sat 2019-07-13 18:32:30 UTC, end at Wed 2019-09-25 14:27:04 UTC. --
Jul 13 19:06:29 node09 systemd[1]: Starting OpenBSD Secure Shell server...
-- Subject: Unit ssh.service has begun start-up
-- Defined-By: systemd
-- Support: http://www.ubuntu.com/support
--
-- Unit ssh.service has begun starting up.
Jul 13 19:06:29 node09 sshd[2675]: Server listening on 0.0.0.0 port 22.
Jul 13 19:06:29 node09 sshd[2675]: Server listening on :: port 22.
```

journalctl is a tool that outputs the contents of various logs recorded by systemd-journald. Logs include kernel logs, service (daemon) logs, application logs, etc., and are stored in `/var/log/journal`. [Shell 4] shows the output of `journalctl -xu ssh` displaying ssh service log contents.

## 2. References

* [https://github.com/nicolaka/netshoot](https://github.com/nicolaka/netshoot)


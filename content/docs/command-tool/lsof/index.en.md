---
title: lsof
---

This document summarizes the usage of `lsof`, which displays open file lists.

## 1. lsof

### 1.1. lsof

```shell {caption="[Shell 1] lsof"}
$ lsof
COMMAND     PID   TID             USER   FD      TYPE             DEVICE SIZE/OFF       NODE NAME
systemd       1                   root  cwd       DIR                8,2     4096          2 /
systemd       1                   root  rtd       DIR                8,2     4096          2 /
systemd       1                   root  txt       REG                8,2  1595792   11535295 /lib/systemd/systemd
cron        925                   root    1u     unix 0xffff8c5def961c00      0t0      19491 type=STREAM
sshd       1618                   root    3u     IPv4              23680      0t0        TCP *:ssh (LISTEN) 
```

Displays all open file lists. [Shell 1] shows the output of `lsof` displaying all open file systems. You can check various file-related information such as process information that opened the file, file type, and file size. Since Unix sockets and IPv4 sockets are also considered files, you can check related information through lsof.

### 1.2. lsof -u [User]

Displays the file list opened by [User].

### 1.3. lsof +D [Dir]

Displays only open file lists under [Directory].

### 1.4. lsof [File]

Displays process information that opened [File].

### 1.5. lsof -c [Binary, Tool]

Displays the file list opened by [Binary, Tool].

### 1.6. lsof -i TCP

Displays process information using TCP.

### 1.7. lsof -i TCP:[Port]

Displays process information using TCP and [Port].

### 1.8. lsof -i TCP:[Port Start]-[Port End]

Displays process information using ports between [Port Start] and [Port End] for TCP.

### 1.9 lsof -i UDP

Displays process information using UDP.


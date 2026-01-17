---
title: Cassandra Installation, Execution / Ubuntu 18.04 Environment
---

## 1. Installation, Execution Environment

The configuration and execution environment is as follows.
* Ubuntu 18.04 LTS 64bit, root user

## 2. Java Installation

```shell
$ add-apt-repository -y ppa:webupd8team/java
$ apt update
$ apt install -y oracle-java8-installer
```

Install Java 8.

## 3. Cassandra Installation

```shell
$ echo "deb http://www.apache.org/dist/cassandra/debian 39x main" |  tee /etc/apt/sources.list.d/cassandra.list
$ curl https://www.apache.org/dist/cassandra/KEYS | sudo apt-key add -
$ apt update
$ apt install cassandra
```

Install the Cassandra Package.

```shell
$ systemctl enable cassandra
$ systemctl start cassandra
$ systemctl -l status cassandra
● cassandra.service - LSB: distributed storage system for structured data
   Loaded: loaded (/etc/init.d/cassandra; generated)
   Active: active (running) since Tue 2018-10-23 13:59:47 UTC; 19min ago
     Docs: man:systemd-sysv-generator(8)
  Process: 6375 ExecStop=/etc/init.d/cassandra stop (code=exited, status=0/SUCCESS)
  Process: 6392 ExecStart=/etc/init.d/cassandra start (code=exited, status=0/SUCCESS)
    Tasks: 43 (limit: 4915)
   CGroup: /system.slice/cassandra.service
           └─6545 java -Xloggc:/var/log/cassandra/gc.log -ea -XX:+UseThreadPriorities -XX:ThreadPriorityPolicy=42 -XX:+HeapDumpOnOutOfMemoryError -Xss256k -X

Oct 23 13:59:47 ubuntu-1804-server-01 systemd[1]: Stopped LSB: distributed storage system for structured data.
Oct 23 13:59:47 ubuntu-1804-server-01 systemd[1]: Starting LSB: distributed storage system for structured data...
Oct 23 13:59:47 ubuntu-1804-server-01 systemd[1]: Started LSB: distributed storage system for structured data.
```

Start Cassandra and verify it is running.

## 4. References

* [http://cassandra.apache.org/download/](http://cassandra.apache.org/download/)
* [https://hostadvice.com/how-to/how-to-install-apache-cassandra-on-an-ubuntu-18-04-vps/](https://hostadvice.com/how-to/how-to-install-apache-cassandra-on-an-ubuntu-18-04-vps/)


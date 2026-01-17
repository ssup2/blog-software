---
title: Grafana Installation, Execution / Ubuntu 18.04 Environment
---

## 1. Installation, Execution Environment

The installation and execution environment is as follows.
* Ubuntu 18.04 LTS 64bit, root user
* Node IP : 192.168.0.150

## 2. Grafana Installation

```text {caption="[File 1] /etc/apt/sources.list", linenos=table}
deb https://packagecloud.io/grafana/stable/debian/ stretch main
```

Add the contents of [File 1] to /etc/apt/sources.list.

```shell
$ curl https://packagecloud.io/gpg.key | sudo apt-key add -
$ apt-get update
$ apt-get install grafana
```

Install Grafana.

```shell
$ systemctl daemon-reload
$ systemctl start grafana-server
$ systemctl status grafana-server
$ systemctl enable grafana-server.service
```

Start Grafana and verify access.
* http://192.168.0.150:3000/login
* ID, PW : admin/admin

## 3. References

* [http://docs.grafana.org/installation/debian/](http://docs.grafana.org/installation/debian/)


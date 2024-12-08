---
title: Grafana 설치, 실행 / Ubuntu 18.04 환경
---

## 1. 설치, 실행 환경

설치, 실행 환경은 다음과 같다.
* Ubuntu 18.04 LTS 64bit, root user
* Node IP : 192.168.0.150

## 2. Grafana 설치

```text {caption="[File 1] /etc/apt/sources.list", linenos=table}
deb https://packagecloud.io/grafana/stable/debian/ stretch main
```

/etc/apt/sources.list에 다음의 [File 1]의 내용을 추가한다.

```shell
$ curl https://packagecloud.io/gpg.key | sudo apt-key add -
$ apt-get update
$ apt-get install grafana
```

Grafana를 설치한다.

```shell
$ systemctl daemon-reload
$ systemctl start grafana-server
$ systemctl status grafana-server
$ systemctl enable grafana-server.service
```

Grafana를 실행하고 접속을 확인한다.
* http://192.168.0.150:3000/login
* ID, PW : admin/admin

## 3. 참조

* [http://docs.grafana.org/installation/debian/](http://docs.grafana.org/installation/debian/)

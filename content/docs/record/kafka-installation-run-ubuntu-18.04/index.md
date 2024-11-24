---
title: Kafka 설치, 설정 / Ubuntu 18.04 환경
---

## 1. 설치, 실행 환경

설치, 실행 환경은 다음과 같다.
* Ubuntu 18.04 LTS 64bit, root user

## 2. Java, Zookeeper 설치

```shell
$ apt install openjdk-8-jdk -y
$ apt install zookeeperd -y
```

Java, Zookeeper Package를 설치한다.

## 3. Kafka 설치

```shell
$ useradd -d /opt/kafka -s /bin/bash kafka
$ passwd kafka
Enter new UNIX password: kafka
Retype new UNIX password: kafka
```

kafka 계정을 생성한다.
* Password : kafka

```shell
$ cd /opt
$ wget http://www-eu.apache.org/dist/kafka/2.0.0/kafka-2.11-2.0.0.tgz
$ mkdir -p /opt/kafka
$ tar -xf kafka-2.11-2.0.0.tgz -C /opt/kafka --strip-components=1
$ chown -R kafka:kafka /opt/kafka
```

Kafka Download 및 압축을 푼다.

```text {caption="[File 1] /opt/kafka/config/server.properties", linenos=table}
...
delete.topic.enable = true
```

/opt/kafka/config/server.properties 파일의 마지막에 [File 1]의 내용을 추가한다.

```text {caption="[File 2] /lib/systemd/system/zookeeper.service", linenos=table}
...

[Unit]
Requires=network.target remote-fs.target
After=network.target remote-fs.target

[Service]
Type=simple
User=kafka
ExecStart=/opt/kafka/bin/zookeeper-server-start.sh /opt/kafka/config/zookeeper.properties
ExecStop=/opt/kafka/bin/zookeeper-server-stop.sh
Restart=on-abnormal

[Install]
WantedBy=multi-user.target
```

/lib/systemd/system/zookeeper.service에 [File 2]의 내용을 저장한다.

```text {caption="[File 3] /lib/systemd/system/kafka.service", linenos=table}
[Unit]
Requires=zookeeper.service
After=zookeeper.service

[Service]
Type=simple
User=kafka
ExecStart=/bin/sh -c '/opt/kafka/bin/kafka-server-start.sh /opt/kafka/config/server.properties'
ExecStop=/opt/kafka/bin/kafka-server-stop.sh
Restart=on-abnormal

[Install]
WantedBy=multi-user.target
```

/lib/systemd/system/kafka.service에 [File 3]의 내용을 저장한다.

```shell
$ systemctl daemon-reload
$ systemctl start zookeeper
$ systemctl enable zookeeper
$ systemctl start kafka
$ systemctl enable kafka
```

Zookeeper, Kafka를 시작한다.

```shell
$ netstat -plntu
...
tcp6       0      0 :::9092                 :::*                    LISTEN      3005/java
tcp6       0      0 :::2181                 :::*                    LISTEN      2372/java
```

Zookeeper, Kafka 구동을 확인한다.
* Zookeeper : 2181 Port
* Kafka : 9092 Port

## 4. Kafka Test

```shell
$ su - kafka
$ cd bin/
$ ./kafka-topics.sh --create --zookeeper localhost:2181 \
--replication-factor 1 --partitions 1 \
--topic HakaseTesting
```

HakaseTesting Topic을 생성한다.

```shell
$ su - kafka
$ cd bin/
$ ./kafka-console-producer.sh --broker-list localhost:9092 \
--topic HakaseTesting
> test 123
```

새로운 Terminal을 띄워 Producer를 실행한다.

```shell
$ su - kafka
$ cd bin/
$ ./kafka-console-consumer.sh --bootstrap-server localhost:9092 \
--topic HakaseTesting --from-beginning
> test 123
```

새로운 Terminal을 띄워 Consumer를 실행한다.

## 5. 참조

* [https://www.howtoforge.com/tutorial/ubuntu-apache-kafka-installation/](https://www.howtoforge.com/tutorial/ubuntu-apache-kafka-installation/)
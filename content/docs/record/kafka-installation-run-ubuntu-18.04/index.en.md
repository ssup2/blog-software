---
title: Kafka Installation, Configuration / Ubuntu 18.04 Environment
---

## 1. Installation, Execution Environment

The installation and execution environment is as follows.
* Ubuntu 18.04 LTS 64bit, root user

## 2. Java, Zookeeper Installation

```shell
$ apt install openjdk-8-jdk -y
$ apt install zookeeperd -y
```

Install Java and Zookeeper Packages.

## 3. Kafka Installation

```shell
$ useradd -d /opt/kafka -s /bin/bash kafka
$ passwd kafka
Enter new UNIX password: kafka
Retype new UNIX password: kafka
```

Create a kafka account.
* Password : kafka

```shell
$ cd /opt
$ wget http://www-eu.apache.org/dist/kafka/2.0.0/kafka-2.11-2.0.0.tgz
$ mkdir -p /opt/kafka
$ tar -xf kafka-2.11-2.0.0.tgz -C /opt/kafka --strip-components=1
$ chown -R kafka:kafka /opt/kafka
```

Download Kafka and extract it.

```text {caption="[File 1] /opt/kafka/config/server.properties", linenos=table}
...
delete.topic.enable = true
```

Add the contents of [File 1] to the end of the /opt/kafka/config/server.properties file.

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

Save the contents of [File 2] to /lib/systemd/system/zookeeper.service.

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

Save the contents of [File 3] to /lib/systemd/system/kafka.service.

```shell
$ systemctl daemon-reload
$ systemctl start zookeeper
$ systemctl enable zookeeper
$ systemctl start kafka
$ systemctl enable kafka
```

Start Zookeeper and Kafka.

```shell
$ netstat -plntu
...
tcp6       0      0 :::9092                 :::*                    LISTEN      3005/java
tcp6       0      0 :::2181                 :::*                    LISTEN      2372/java
```

Verify that Zookeeper and Kafka are running.
* Zookeeper : Port 2181
* Kafka : Port 9092

## 4. Kafka Test

```shell
$ su - kafka
$ cd bin/
$ ./kafka-topics.sh --create --zookeeper localhost:2181 \
--replication-factor 1 --partitions 1 \
--topic HakaseTesting
```

Create the HakaseTesting Topic.

```shell
$ su - kafka
$ cd bin/
$ ./kafka-console-producer.sh --broker-list localhost:9092 \
--topic HakaseTesting
> test 123
```

Open a new Terminal and run the Producer.

```shell
$ su - kafka
$ cd bin/
$ ./kafka-console-consumer.sh --bootstrap-server localhost:9092 \
--topic HakaseTesting --from-beginning
> test 123
```

Open a new Terminal and run the Consumer.

## 5. References

* [https://www.howtoforge.com/tutorial/ubuntu-apache-kafka-installation/](https://www.howtoforge.com/tutorial/ubuntu-apache-kafka-installation/)


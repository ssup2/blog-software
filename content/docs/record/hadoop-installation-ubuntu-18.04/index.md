---
title: Hadoop 설치 / Ubuntu 18.04 환경
---

## 1. 설치 환경

설치, 실행환경은 다음과 같다.
* Ubuntu 18.04 LTS 64bit, root user
* Java openjdk version "1.8.0-171"
* Hadoop 3.0.3

## 2. sshd 설치, 설정

```shell
$ apt update
$ apt install -y openssh-server
$ apt install -y pdsh
```

sshd를 설치한다.

```text {caption="[File 1] /etc/ssh/sshd-config", linenos=table}
...
#LoginGraceTime 2m
PermitRootLogin yes
#StrictModes yes
...
```

/etc/ssh/sshd-config 파일을 [File 1]의 내용으로 수정한다.

```shell
$ service sshd restart
$ ssh-keygen -t rsa -P '' -f ~/.ssh/id-rsa
$ cat ~/.ssh/id-rsa.pub >> ~/.ssh/authorized-keys
$ chmod 0600 ~/.ssh/authorized-keys
$ echo "ssh" > /etc/pdsh/rcmd-default
$ ssh localhost

...
Are you sure you want to continue connecting (yes/no)? yes
```

sshd 재시작 및 ssh 접속시 password가 불필요하도록 설정한다.

## 3. Java 설치 

```shell
$ apt update
$ apt install -y openjdk-8-jdk
```

Java Package를 설치한다.

## 4. Hadoop 설치, 설정

```shell
$ cd ~
$ wget http://mirror.navercorp.com/apache/hadoop/common/hadoop-3.0.3/hadoop-3.0.3.tar.gz
$ tar zxvf hadoop-3.0.3.tar.gz
```

Hadoop Binary를 Download 한다.

```text {caption="[File 2] ~/hadoop-3.0.3/etc/hadoop/hadoop-env.sh", linenos=table}
# The java implementation to use. By default, this environment
# variable is REQUIRED on ALL platforms except OS X!
export JAVA-HOME=/usr/lib/jvm/java-1.8.0-openjdk-amd64
```

~/hadoop-3.0.3/etc/hadoop/hadoop-env.sh 파일을 [File 2]와 같이 수정한다.

```xml {caption="[File 3] ~/hadoop-3.0.3/etc/hadoop/core-site.xml", linenos=table}
<configuration>
	<property>
        <name>fs.defaultFS</name>
        <value>hdfs://localhost:9000</value>
    </property>
</configuration>
```

~/hadoop-3.0.3/etc/hadoop/core-site.xml 파일을 [File 3]과 같이 수정한다.

```xml {caption="[File 4] ~/hadoop-3.0.3/etc/hadoop/core-site.xml", linenos=table}
<configuration>
	<property>
        <name>dfs.replication</name>
        <value>1</value>
    </property>
</configuration>
```

~/hadoop-3.0.3/etc/hadoop/core-site.xml 파일을 [File 4]와 같이 수정한다.

```text {caption="[File 5] ~/.bashrc", linenos=table}
...
export HADOOP-HOME="/root/hadoop-3.0.3"
export PATH=$PATH:$HADOOP-HOME/bin
export PATH=$PATH:$HADOOP-HOME/sbin
export HADOOP-MAPRED-HOME=$HADOOP-HOME
export HADOOP-COMMON-HOME=$HADOOP-HOME
export HADOOP-HDFS-HOME=$HADOOP-HOME
export YARN-HOME=$HADOOP-HOME

export HDFS-NAMENODE-USER="root"
export HDFS-DATANODE-USER="root"
export HDFS-SECONDARYNAMENODE-USER="root"
export YARN-RESOURCEMANAGER-USER="root"
export YARN-NODEMANAGER-USER="root"
```

~/.bashrc 파일에 [File 5]의 내용을 추가한다.

```shell
$ hdfs namenode -format
$ start-dfs.sh
```

HDFS Format 및 HDFS을 시작하고 HDFS 동작을 확인한다.
* Web Browser에서 http://localhost:9870 접속한다.

## 5. YARN 설치, 설정

```shell
$ cd ~/hadoop-3.0.
$ bin/hdfs dfs -mkdir /user
$ bin/hdfs dfs -mkdir /user/root
```

root user 폴더를 생성한다.

```xml {caption="[File 6] ~/hadoop-3.0.3/etc/hadoop/mapred-site.xml", linenos=table}
<configuration>
	<property>
		<name>mapreduce.framework.name</name>
		<value>yarn</value>
	</property>
	<property>
		<name>yarn.app.mapreduce.am.env</name>
		<value>HADOOP-MAPRED-HOME=/root/hadoop-3.0.3</value>
	</property>
	<property>
		<name>mapreduce.map.env</name>
		<value>HADOOP-MAPRED-HOME=/root/hadoop-3.0.3</value>
	</property>
	<property>
		<name>mapreduce.reduce.env</name>
		<value>HADOOP-MAPRED-HOME=/root/hadoop-3.0.3</value>
	</property>
</configuration>
```

~/hadoop-3.0.3/etc/hadoop/mapred-site.xml 파일을 [File 6]과 같이 수정한다.

```xml {caption="[File 7] ~/hadoop-3.0.3/etc/hadoop/yarn-site.xml", linenos=table}
<configuration>
	<property>
		<name>yarn.nodemanager.aux-services</name>
		<value>mapreduce-shuffle</value>
	</property>
	<property>
		<name>yarn.nodemanager.vmem-check-enabled</name>
		<value>false</value>
	</property>
</configuration>
```

~/hadoop-3.0.3/etc/hadoop/yarn-site.xml 파일을 [File 7]과 같이 수정한다.

```shell
$ start-yarn.sh
```

YARN을 시작하고 YARN의 동작을 확인한다.
* http://localhost:8088

## 6. 동작 확인

```shell
$ jps
3988 NameNode
5707 Jps
5355 NodeManager
4203 DataNode
4492 SecondaryNameNode
5133 ResourceManager
```

6개의 JVM 동작을 확인한다.

```shell
$ cd ~/hadoop-3.0.3
$ yarn jar share/hadoop/mapreduce/hadoop-mapreduce-examples-3.0.3.jar pi 16 1000
...
Estimated value of Pi is 3.14250000000000000000
```

Example을 구동한다.

## 7. Issue 해결

```shell
$ stop-yarn.sh
$ stop-dfs.sh
$ rm -rf /tmp/*
$ start-dfs.sh
$ start-yarn.sh
```

There are 0 datanode(s) Error 발생시 위와 같이 수행한다.

## 8. 참조

* [http://www.admintome.com/blog/installing-hadoop-on-ubuntu-17-10/](http://www.admintome.com/blog/installing-hadoop-on-ubuntu-17-10/)
* [https://data-flair.training/blogs/installation-of-hadoop-3-x-on-ubuntu/](https://data-flair.training/blogs/installation-of-hadoop-3-x-on-ubuntu/)

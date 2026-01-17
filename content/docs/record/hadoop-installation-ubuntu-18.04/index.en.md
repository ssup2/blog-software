---
title: Hadoop Installation / Ubuntu 18.04 Environment
---

## 1. Installation Environment

The installation and execution environment is as follows.
* Ubuntu 18.04 LTS 64bit, root user
* Java openjdk version "1.8.0-171"
* Hadoop 3.0.3

## 2. sshd Installation, Configuration

```shell
$ apt update
$ apt install -y openssh-server
$ apt install -y pdsh
```

Install sshd.

```text {caption="[File 1] /etc/ssh/sshd-config", linenos=table}
...
#LoginGraceTime 2m
PermitRootLogin yes
#StrictModes yes
...
```

Modify the /etc/ssh/sshd-config file with the contents of [File 1].

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

Restart sshd and configure it so that a password is not required for ssh access.

## 3. Java Installation

```shell
$ apt update
$ apt install -y openjdk-8-jdk
```

Install the Java Package.

## 4. Hadoop Installation, Configuration

```shell
$ cd ~
$ wget http://mirror.navercorp.com/apache/hadoop/common/hadoop-3.0.3/hadoop-3.0.3.tar.gz
$ tar zxvf hadoop-3.0.3.tar.gz
```

Download the Hadoop Binary.

```text {caption="[File 2] ~/hadoop-3.0.3/etc/hadoop/hadoop-env.sh", linenos=table}
# The java implementation to use. By default, this environment
# variable is REQUIRED on ALL platforms except OS X!
export JAVA-HOME=/usr/lib/jvm/java-1.8.0-openjdk-amd64
```

Modify the ~/hadoop-3.0.3/etc/hadoop/hadoop-env.sh file as shown in [File 2].

```xml {caption="[File 3] ~/hadoop-3.0.3/etc/hadoop/core-site.xml", linenos=table}
<configuration>
	<property>
        <name>fs.defaultFS</name>
        <value>hdfs://localhost:9000</value>
    </property>
</configuration>
```

Modify the ~/hadoop-3.0.3/etc/hadoop/core-site.xml file as shown in [File 3].

```xml {caption="[File 4] ~/hadoop-3.0.3/etc/hadoop/core-site.xml", linenos=table}
<configuration>
	<property>
        <name>dfs.replication</name>
        <value>1</value>
    </property>
</configuration>
```

Modify the ~/hadoop-3.0.3/etc/hadoop/core-site.xml file as shown in [File 4].

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

Add the contents of [File 5] to the ~/.bashrc file.

```shell
$ hdfs namenode -format
$ start-dfs.sh
```

Format HDFS and start HDFS, then verify HDFS operation.
* Access http://localhost:9870 in a Web Browser.

## 5. YARN Installation, Configuration

```shell
$ cd ~/hadoop-3.0.
$ bin/hdfs dfs -mkdir /user
$ bin/hdfs dfs -mkdir /user/root
```

Create a root user folder.

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

Modify the ~/hadoop-3.0.3/etc/hadoop/mapred-site.xml file as shown in [File 6].

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

Modify the ~/hadoop-3.0.3/etc/hadoop/yarn-site.xml file as shown in [File 7].

```shell
$ start-yarn.sh
```

Start YARN and verify YARN operation.
* http://localhost:8088

## 6. Operation Verification

```shell
$ jps
3988 NameNode
5707 Jps
5355 NodeManager
4203 DataNode
4492 SecondaryNameNode
5133 ResourceManager
```

Verify that 6 JVMs are running.

```shell
$ cd ~/hadoop-3.0.3
$ yarn jar share/hadoop/mapreduce/hadoop-mapreduce-examples-3.0.3.jar pi 16 1000
...
Estimated value of Pi is 3.14250000000000000000
```

Run an Example.

## 7. Issue Resolution

```shell
$ stop-yarn.sh
$ stop-dfs.sh
$ rm -rf /tmp/*
$ start-dfs.sh
$ start-yarn.sh
```

If a "There are 0 datanode(s)" Error occurs, perform the above steps.

## 8. References

* [http://www.admintome.com/blog/installing-hadoop-on-ubuntu-17-10/](http://www.admintome.com/blog/installing-hadoop-on-ubuntu-17-10/)
* [https://data-flair.training/blogs/installation-of-hadoop-3-x-on-ubuntu/](https://data-flair.training/blogs/installation-of-hadoop-3-x-on-ubuntu/)


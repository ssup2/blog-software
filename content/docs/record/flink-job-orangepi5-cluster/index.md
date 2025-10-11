---
title: Flink Job 수행 / Orange Pi 5 Max Cluster 환경
draft: true
---

Flink를 활용해서 Kafka에 저장되어 있는 데이터를 처리한다.

## 1. 실습 환경 구성

### 1.1. 전체 실습 환경

### 1.2. Flink Local 설치

Java 17 Version을 설치한다.

```shell
brew install openjdk@17
sudo ln -sfn /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-17.jdk

echo 'export JAVA_HOME="/opt/homebrew/opt/openjdk@17"' >> ~/.zshrc
echo 'export PATH="$JAVA_HOME/bin:$PATH"' >> ~/.zshrc
export JAVA_HOME="/opt/homebrew/opt/openjdk@17"
export PATH="$JAVA_HOME/bin:$PATH"
```

Flink 1.20.2 Version을 설치한다.

```shell
curl -O "https://dlcdn.apache.org/flink/flink-1.20.2/flink-1.20.2-bin-scala_2.12.tgz"
tar -xvzf "flink-1.20.2-bin-scala_2.12.tgz"
mv "flink-1.20.2" ~/flink

echo 'export FLINK_HOME=~/flink' >> ~/.zshrc
echo 'export PATH="$FLINK_HOME/bin:$PATH"' >> ~/.zshrc
export FLINK_HOME=~/flink
export PATH="$FLINK_HOME/bin:$PATH"
```

S3에 Flink Checkpoint를 저장하기 위해서 Flink S3 FS Hadoop Plugin을 설치한다.

```shell
cd $FLINK_HOME/plugins
mkdir flink-s3-fs-hadoop
cd flink-s3-fs-hadoop
wget https://repo.maven.apache.org/maven2/org/apache/flink/flink-s3-fs-hadoop/1.20.2/flink-s3-fs-hadoop-1.20.2.jar
```

Flink Config 파일을 생성한다.

```shell
cat > $FLINK_HOME/conf/flink-conf.yaml << 'EOF'
# Java Config
env.java.opts: --add-opens java.base/java.util=ALL-UNNAMED

# Flink Config
## JobManager Config
jobmanager.rpc.address: localhost
jobmanager.rpc.port: 6123
jobmanager.memory.process.size: 2048m

## TaskManager Config
taskmanager.memory.process.size: 2048m
taskmanager.numberOfTaskSlots: 2

## Parallelism Config
parallelism.default: 1

## Rest Config
rest.address: localhost
rest.port: 8081

# S3 Config
s3.endpoint: http://192.168.1.85:9000
s3.access-key: root
s3.secret-key: root123!
s3.path.style.access: true
EOF
```

### 1.3. Flink Checkpoint Bucket 생성

```shell
mc mb dp/flink
```

```sql
CREATE DATABASE IF NOT EXISTS wikimedia;

USE wikimedia;

CREATE TABLE IF NOT EXISTS page_create_counter_1m (
    window_end DATETIME NOT NULL COMMENT 'Window end time',
    create_count BIGINT NOT NULL COMMENT 'Page create count'
)
DUPLICATE KEY(window_end)
DISTRIBUTED BY HASH(window_end) BUCKETS 10
PROPERTIES (
    "replication_num" = "1"
);
```

## 2. Local 환경에서 실행

### 2.1. Flink Application Download

Spark Application을 Download 하고, Python 패키지를 설치한다.

```shell
git clone https://github.com/ssup2-playground/k8s-data-platform_spark-jobs.git
cd k8s-data-platform_spark-jobs
uv sync
```

### 2.2. Flink Cluster 실행

Local에서 Flink Cluster를 실행한다.

```shell
$ start-cluster.sh 
Starting cluster.
Starting standalonesession daemon on host ssupui-MacBookPro.local.
Starting taskexecutor daemon on host ssupui-MacBookPro.local.
```

### 2.3. Flink Job 실행

Flink Job을 실행한다.

```shell
$ flink run wikimedia-page-create-counter/build/libs/wikimedia-page-create-counter-1.0-all.jar
```

## 3. Kubernetes 환경에서 실행

## 4. 참고

* Spark Local 환경 설정 : [https://bluehorn07.github.io/2024/08/18/run-spark-on-local-2/](https://bluehorn07.github.io/2024/08/18/run-spark-on-local-2/)
* Volcano Scheduler 설정 : [https://docs.aws.amazon.com/emr/latest/EMR-on-EKS-DevelopmentGuide/tutorial-volcano.html](https://docs.aws.amazon.com/emr/latest/EMR-on-EKS-DevelopmentGuide/tutorial-volcano.html)

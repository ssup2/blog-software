---
title: Flink Job 수행 / Orange Pi 5 Max Cluster 환경
draft: true
---

Flink를 활용해서 Kafka에 저장되어 있는 데이터를 처리한다.

## 1. 실습 환경 구성

### 1.1. 전체 실습 환경

### 1.2. Flink 설치

Java 11를 설치한다.

```shell
brew install openjdk@17
sudo ln -sfn /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-17.jdk

echo 'export JAVA_HOME="/opt/homebrew/opt/openjdk@17"' >> ~/.zshrc
echo 'export PATH="$JAVA_HOME/bin:$PATH"' >> ~/.zshrc
export JAVA_HOME="/opt/homebrew/opt/openjdk@17"
export PATH="$JAVA_HOME/bin:$PATH"
```

## 2. Local 환경에서 실행

## 3. Kubernetes 환경에서 실행

## 4. 참고

* Spark Local 환경 설정 : [https://bluehorn07.github.io/2024/08/18/run-spark-on-local-2/](https://bluehorn07.github.io/2024/08/18/run-spark-on-local-2/)
* Volcano Scheduler 설정 : [https://docs.aws.amazon.com/emr/latest/EMR-on-EKS-DevelopmentGuide/tutorial-volcano.html](https://docs.aws.amazon.com/emr/latest/EMR-on-EKS-DevelopmentGuide/tutorial-volcano.html)

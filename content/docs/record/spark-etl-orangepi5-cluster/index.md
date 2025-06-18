---
title: Spark ETL 수행 / Orange Pi 5 Max Cluster 환경
draft: true
---

## 1. 실습 환경 구습

Java 11를 설치한다.

```shell
brew install openjdk@17
sudo ln -sfn /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-17.jdk

echo 'export JAVA_HOME="/opt/homebrew/opt/openjdk@17"' >> ~/.zshrc
echo 'export PATH="$JAVA_HOME/bin:$PATH"' >> ~/.zshrc
export JAVA_HOME="/opt/homebrew/opt/openjdk@17"
export PATH="$JAVA_HOME/bin:$PATH"
```

Spark를 설치한다.

```shell
SPARK_VERSION="3.5.1"
HADOOP_VERSION="3"

curl -O "https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz"
tar -xvzf "spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz"
mv "spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}" ~/spark

echo 'export SPARK_HOME=~/spark' >> ~/.zshrc
echo 'export PATH="$SPARK_HOME/bin:$PATH"' >> ~/.zshrc
export SPARK_HOME=~/spark
export PATH="$SPARK_HOME/bin:$PATH"
```

Spark Application을 Download 한다.

```shell
uv sync
```

## 2. Local 환경에서 실행

Shell을 2개 실행하여 각각 Master와 Worker로 설정하여 실행한다.

```shell
spark-class org.apache.spark.deploy.master.Master -h localhost
spark-class org.apache.spark.deploy.worker.Worker spark://localhost:7077
```

```shell
export PYTHONPATH=$(pwd)/src
spark-submit \
  --packages org.apache.hadoop:hadoop-aws:3.3.4,com.amazonaws:aws-java-sdk-bundle:1.12.262 \
  --master spark://localhost:7077 \
  --total-executor-cores 2 \
  --executor-memory 500m \
  src/app/weather_southkorea_daily_average_parquet.py \
  --date 20250601
```

```shell
127.0.0.1:4040
```

## 3. Kubernetes 환경에서 spark-submit 실행

```shell
spark-submit \
  --master k8s://192.168.1.71:6443 \
  --deploy-mode cluster \
  --name spark-on-k8s-example \
  --conf spark.kubernetes.container.image=ghcr.io/ssup2-playground/k8s-data-platform_spark-jobs:0.1.0 \
  --conf spark.kubernetes.namespace=spark \
  --conf spark.executor.instances=2 \
  --conf spark.kubernetes.authenticate.driver.serviceAccountName=spark \
  --conf spark.hadoop.fs.s3a.endpoint=http://minio:9000 \
  --conf spark.hadoop.fs.s3a.access.key=<YOUR_MINIO_ACCESS_KEY> \
  --conf spark.hadoop.fs.s3a.secret.key=<YOUR_MINIO_SECRET_KEY> \
  --conf spark.hadoop.fs.s3a.path.style.access=true \
  --conf spark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem \
  --conf spark.jars.packages=org.apache.hadoop:hadoop-aws:3.3.4,com.amazonaws:aws-java-sdk-bundle:1.12.262 \
  local:///opt/spark/app/your_script.py
```

```shell
spark-submit \
  --master k8s://192.168.1.71:6443 \
  --deploy-mode cluster \
  --name spark-on-k8s-example \
  --conf spark.kubernetes.container.image=ghcr.io/ssup2-playground/k8s-data-platform_spark-apps:0.1.0 \
  --conf spark.kubernetes.namespace=spark \
  --conf spark.kubernetes.authenticate.driver.serviceAccountName=spark \
  --conf spark.executor.instances=2 \
  --conf spark.jars.packages=org.apache.hadoop:hadoop-aws:3.3.4,com.amazonaws:aws-java-sdk-bundle:1.12.262 \
  local:///app/weather_southkorea_daily_average_parquet.py \
  --date 20250602
```


```yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: spark
  namespace: spark
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: spark-role
  namespace: spark
rules:
  - apiGroups: [""]
    resources: ["pods", "services", "endpoints", "persistentvolumeclaims"]
    verbs: ["create", "get", "list", "watch", "delete"]
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["create", "get", "delete"]
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: spark-rolebinding
  namespace: spark
subjects:
  - kind: ServiceAccount
    name: spark
    namespace: spark
roleRef:
  kind: Role
  name: spark-role
  apiGroup: rbac.authorization.k8s.io
```

## 4. Kubernetes 환경에서 Spark Operator 실행

## 5. Dagster와 연동

## 6. 참고

* Spark Local 환경 설정 : [https://bluehorn07.github.io/2024/08/18/run-spark-on-local-2/](https://bluehorn07.github.io/2024/08/18/run-spark-on-local-2/)

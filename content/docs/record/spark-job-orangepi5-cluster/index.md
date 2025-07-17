---
title: Spark Job 수행 / Orange Pi 5 Max Cluster 환경
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
SPARK_VERSION="3.5.5"
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

```sql
CREATE TABLE iceberg.weather.southkorea_daily_average_iceberg_parquet (
    branch_name VARCHAR,

    temp DOUBLE,
    rain DOUBLE,
    snow DOUBLE,

    cloud_cover_total     INT,
    cloud_cover_lowmiddle INT,
    cloud_lowest          INT,

    humidity       INT,
    wind_speed     DOUBLE,
    pressure_local DOUBLE,
    pressure_sea   DOUBLE,
    pressure_vaper DOUBLE,
    dew_point      DOUBLE,

    year  INT,
    month INT,
    day   INT,
    hour  INT
)
WITH (
	location = 's3a://weather/southkorea/daily-average-iceberg-parquet',
	format = 'PARQUET',
	partitioning = ARRAY['year', 'month', 'day']
);
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
  src/jobs/weather_southkorea_daily_average_parquet.py \
  --date 20250601
```

```shell
export PYTHONPATH=$(pwd)/src
spark-submit \
  --packages org.apache.hadoop:hadoop-aws:3.3.4,com.amazonaws:aws-java-sdk-bundle:1.12.262,org.apache.iceberg:iceberg-spark3-runtime:0.13.2 \
  --master spark://localhost:7077 \
  --total-executor-cores 2 \
  --executor-memory 500m \
  src/jobs/weather_southkorea_daily_average_iceberg_parquet.py \
  --date 20250601
```

```
CREATE TABLE iceberg.weather.southkorea_daily_average_iceberg_parquet (
    branch_name VARCHAR,

    avg_temp DOUBLE,
    avg_rain DOUBLE,
    avg_snow DOUBLE,

    avg_cloud_cover_total     DOUBLE,
    avg_cloud_cover_lowmiddle DOUBLE,
    avg_cloud_lowest          DOUBLE,

    avg_humidity       DOUBLE,
    avg_wind_speed     DOUBLE,
    avg_pressure_local DOUBLE,
    avg_pressure_sea   DOUBLE,
    avg_pressure_vaper DOUBLE,
    avg_dew_point      DOUBLE,

    year  INT,
    month INT,
    day   INT
)
WITH (
	location = 's3a://weather/southkorea/daily-average-iceberg-parquet',
	format = 'PARQUET',
	partitioning = ARRAY['year', 'month', 'day']
);
```

```shell
127.0.0.1:4040
```

## 3. Kubernetes 환경에서 spark-submit 실행

```shell
spark-submit \
  --master k8s://192.168.1.71:6443 \
  --deploy-mode cluster \
  --name weather-southkorea-daily-average-parquet \
  --conf spark.kubernetes.container.image=ghcr.io/ssup2-playground/k8s-data-platform_spark-jobs:0.1.6 \
  --conf spark.kubernetes.namespace=spark \
  --conf spark.kubernetes.authenticate.driver.serviceAccountName=spark \
  --conf spark.executor.instances=2 \
  --conf spark.pyspark.python=/app/.venv/bin/python3 \
  --conf spark.jars.packages=org.apache.hadoop:hadoop-aws:3.3.4,com.amazonaws:aws-java-sdk-bundle:1.12.262 \
  --conf spark.eventLog.enabled=true \
  --conf spark.eventLog.dir=s3a://spark/logs \
  --conf spark.ui.prometheus.enabled=true \
  --conf spark.kubernetes.driver.annotation.prometheus.io/scrape=true \
  --conf spark.kubernetes.driver.annotation.prometheus.io/path=/metrics/executors/prometheus \
  --conf spark.kubernetes.driver.annotation.prometheus.io/port=4040 \
  local:///app/jobs/weather_southkorea_daily_average_parquet.py \
  --date 20250601
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
    resources: ["pods", "services", "endpoints", "configmaps", "persistentvolumeclaims"]
    verbs: ["create", "get", "list", "watch", "delete", "deletecollection"]
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

```yaml
apiVersion: "sparkoperator.k8s.io/v1beta2"
kind: SparkApplication
metadata:
  namespace: spark
  name:  weather-southkorea-daily-average-parquet
spec:
  type: Python
  mode: cluster
  image: "ghcr.io/ssup2-playground/k8s-data-platform_spark-jobs:0.1.6"
  sparkVersion: "3.5.5"
  imagePullPolicy: Always
  mainApplicationFile: "local:///app/jobs/weather_southkorea_daily_average_parquet.py"
  
  # Application arguments
  arguments:
    - "--date"
    - "20250601"
  
  # Spark configuration
  sparkConf:
    "spark.eventLog.enabled": "true"
    "spark.eventLog.dir": "s3a://spark/logs"
    "spark.kubernetes.driver.annotation.prometheus.io/scrape": "true"
    "spark.kubernetes.driver.annotation.prometheus.io/path": "/metrics/executors/prometheus"
    "spark.kubernetes.driver.annotation.prometheus.io/port": "4040"

  # Spark dependencies
  deps:
    packages:
      - org.apache.hadoop:hadoop-aws:3.4.0
      - com.amazonaws:aws-java-sdk-bundle:1.12.262
  
  # Executor configuration
  executor:
    instances: 2
    cores: 1
    memory: "1g"
    serviceAccount: spark
  
  # Driver configuration
  driver:
    cores: 1
    memory: "1g"
    serviceAccount: spark
  
  # Restart policy
  restartPolicy:
    type: Never
  
  # TTL for automatic cleanup (1 hour after completion)
  timeToLiveSeconds: 300
```

## 5. Dagster와 연동

## 6. 참고

* Spark Local 환경 설정 : [https://bluehorn07.github.io/2024/08/18/run-spark-on-local-2/](https://bluehorn07.github.io/2024/08/18/run-spark-on-local-2/)

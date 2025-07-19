---
title: Spark Job 수행 / Orange Pi 5 Max Cluster 환경
draft: true
---

Spark를 활용해서 MinIO에 저장되어 있는 데이터 변환을 수행한다.

## 1. 실습 환경 구성

### 1.1. 전체 실습 환경

Spark를 통해서 MinIO에 저장되어 있는 데이터를 변환하는 환경은 다음과 같다.

{{< figure caption="[Figure 1] Spark Job 구동 환경" src="images/environment.png" width="1000px" >}}

* MinIO : Data를 저장하는 Object Storage 역할을 수행한다. South Korea Weather Data를 저장한다.
  * South Korea Weather Data : CSV, Parquet, Iceberg 3가지 Data Format으로 날짜별로 Partition되어 저장된다.
* Spark Job : MinIO에 저장되어 있는 South Korea Weather Data의 평균 데이터를 계산하고 다시 MinIO에 저장한다.
* Spark History Server : Spark Job의 실행 로그를 확인하기 위한 역할을 수행한다.
* Volcano Scheduler : Spark Job 실행을 위한 Pod들을 대상으로 Gang Scheduling을 수행한다.
* Trino : MinIO에 저장되어 있는 Data를 조회하는 역할을 수행한다.
* Hive Metastore : Data의 Schema 정보를 관리하며, Trino에게 Schema 정보를 제공한다.
* Dagster : Data Pipeline을 실행하여 MinIO에 South Korea Weather Data의 저장 형태를 CSV에서 Parquet으로, Parquet에서 Iceberg로 변환한다.
* DBeaver : Trino에 접속하고 Query를 수행하기 위한 Client 역할을 수행한다.

전체 실슴 환경 구성은 다음의 링크를 참조한다.

* Orange Pi 5 Max 기반 Kubernetes Cluster 구축 : [https://ssup2.github.io/blog-software/docs/record/orangepi5-cluster-build/](https://ssup2.github.io/blog-software/docs/record/orangepi5-cluster-build/)
* Orange Pi 5 Max 기반 Kubernetes Data Platform 구축 : [https://ssup2.github.io/blog-software/docs/record/kubernetes-data-platform-orangepi5-cluster/](https://ssup2.github.io/blog-software/docs/record/kubernetes-data-platform-orangepi5-cluster/)
* Trino MinIO Query 수행 : [https://ssup2.github.io/blog-software/docs/record/trino-minio-query-orangepi5-cluster/](https://ssup2.github.io/blog-software/docs/record/trino-minio-query-orangepi5-cluster/)
* Dagster Workflow Github : [https://github.com/ssup2-playground/k8s-data-platform_dagster-workflows](https://github.com/ssup2-playground/k8s-data-platform_dagster-workflows)
* Spark Job Github : [https://github.com/ssup2-playground/k8s-data-platform_spark-jobs](https://github.com/ssup2-playground/k8s-data-platform_spark-jobs)

### 1.2. Spark 설치

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

### 1.3. Hive Metastore Table 생성

평균 날씨 데이터를 저장하는 Parquet Table을 생성한다.

```sql
CREATE TABLE hive.weather.southkorea_daily_average_parquet (
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
	external_location = 's3a://weather/southkorea/daily-average-parquet',
	format = 'PARQUET',
	partitioned_by = ARRAY['year', 'month', 'day']
);

CALL hive.system.sync_partition_metadata('weather', 'southkorea_daily_average_parquet', 'ADD');
```

평균 날씨 데이터를 저장하는 Iceberg Parquet Table을 생성한다.

```sql
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

## 2. Local 환경에서 실행

### 2.1. Spark Application Download

Spark Application을 Download 하고, Python 패키지를 설치한다.

```shell
git clone https://github.com/ssup2-playground/k8s-data-platform_spark-jobs.git
cd k8s-data-platform_spark-jobs
uv sync
```

### 2.2. Spark Master와 Worker 실행

Shell을 2개 실행하여 각각 Master와 Worker로 설정하여 Local Spark Cluster를 구성한다.

```shell
spark-class org.apache.spark.deploy.master.Master -h localhost
spark-class org.apache.spark.deploy.worker.Worker spark://localhost:7077
```

### 2.3. Spark Job 실행

구성한 Local Spark Cluster에 `daily-parquet` 데이터를 활용하여 평균 날씨 데이터를 계산하는 Spark Job을 실행한다.

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

구성한 Local Spark Cluster에 `daily-iceberg-parquet` 데이터를 활용하여 평균 날씨 데이터를 계산하는 Spark Job을 실행한다.

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

## 3. Kubernetes 환경에서 실행

### 3.1. Service Account 설정

Spark Job 실행을 위한 권한을 부여하기 위해서 Service Account를 설정한다.

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

### 3.2. Spark Job 실행

Kubernetes Cluster에 `daily-parquet` 데이터를 활용하여 평균 날씨 데이터를 계산하는 Spark Job을 실행한다. 주요 설정은 다음과 같다.

* `spark.jars.packages` : Spark Job 실행에 필요한 추가 패키지들을 설정한다. 
* `eventLog` : Spark Job가 저장될 MinIO의 위치를 지정한다.
* `spark.ui.prometheus.enabled` : Spark Job에서 Prometheus Metric을 노출시킨다.
* `spark.kubernetes.driver.annotation.prometheus.io` : Prometheus Server가 Spark Job이 노출하는 Metric을 수집할 수 있도록 설정한다.

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

Kubernetes Cluster에 `daily-iceberg-parquet` 데이터를 활용하여 평균 날씨 데이터를 계산하는 Spark Job을 실행한다. Package에 `iceberg-spark3-runtime`을 추가하여 Iceberg Table을 활용한다.

```shell
spark-submit \
  --master k8s://192.168.1.71:6443 \
  --deploy-mode cluster \
  --name weather-southkorea-daily-average-iceberg-parquet \
  --conf spark.kubernetes.container.image=ghcr.io/ssup2-playground/k8s-data-platform_spark-jobs:0.1.6 \
  --conf spark.kubernetes.namespace=spark \
  --conf spark.kubernetes.authenticate.driver.serviceAccountName=spark \
  --conf spark.executor.instances=2 \
  --conf spark.pyspark.python=/app/.venv/bin/python3 \
  --conf spark.jars.packages=org.apache.hadoop:hadoop-aws:3.3.4,com.amazonaws:aws-java-sdk-bundle:1.12.262,org.apache.iceberg:iceberg-spark3-runtime:0.13.2 \
  --conf spark.eventLog.enabled=true \
  --conf spark.eventLog.dir=s3a://spark/logs \
  --conf spark.ui.prometheus.enabled=true \
  --conf spark.kubernetes.driver.annotation.prometheus.io/scrape=true \
  --conf spark.kubernetes.driver.annotation.prometheus.io/path=/metrics/executors/prometheus \
  --conf spark.kubernetes.driver.annotation.prometheus.io/port=4040 \
  local:///app/jobs/weather_southkorea_daily_average_iceberg_parquet.py \
  --date 20250601
```

### 3.4. Volcano Scheduler를 활용한 Gang Scheduling 수행

### 3.5. Spark Operator를 이용한 실행

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
    "spark.ui.prometheus.enabled": "true"
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

## 4. 참고

* Spark Local 환경 설정 : [https://bluehorn07.github.io/2024/08/18/run-spark-on-local-2/](https://bluehorn07.github.io/2024/08/18/run-spark-on-local-2/)

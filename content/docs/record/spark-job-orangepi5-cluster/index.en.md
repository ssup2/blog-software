---
title: Spark Job Execution / Orange Pi 5 Max Cluster Environment
---

Perform data transformation on data stored in MinIO using Spark.

## 1. Practice Environment Configuration

### 1.1. Overall Practice Environment

The environment for transforming data stored in MinIO through Spark is as follows.

{{< figure caption="[Figure 1] Spark Job Execution Environment" src="images/environment.png" width="1000px" >}}

* **MinIO** : Performs the role of Object Storage for storing Data. Stores South Korea Weather Data.
  * **South Korea Weather Data** : Stored partitioned by date in 3 Data Formats: CSV, Parquet, Iceberg.
* **Spark Job** : Calculates average data from South Korea Weather Data stored in MinIO and stores it back in MinIO.
* **Spark History Server** : Performs the role of checking execution logs of Spark Jobs.
* **Volcano Scheduler** : Performs Gang Scheduling for Pods for Spark Job execution.
* **Trino** : Performs the role of querying Data stored in MinIO.
* **Hive Metastore** : Manages Schema information of Data and provides Schema information to Trino.
* **Dagster** : Executes Data Pipeline to convert the storage format of South Korea Weather Data in MinIO from CSV to Parquet, and from Parquet to Iceberg.
* **DBeaver** : Performs the role of Client for connecting to Trino and executing Queries.

Refer to the following links for the overall practice environment configuration.

* **Orange Pi 5 Max based Kubernetes Cluster Setup** : [https://ssup2.github.io/blog-software/docs/record/orangepi5-cluster-build/](https://ssup2.github.io/blog-software/docs/record/orangepi5-cluster-build/)
* **Orange Pi 5 Max based Kubernetes Data Platform Setup** : [https://ssup2.github.io/blog-software/docs/record/kubernetes-data-platform-orangepi5-cluster/](https://ssup2.github.io/blog-software/docs/record/kubernetes-data-platform-orangepi5-cluster/)
* **Trino MinIO Query Execution** : [https://ssup2.github.io/blog-software/docs/record/trino-minio-query-orangepi5-cluster/](https://ssup2.github.io/blog-software/docs/record/trino-minio-query-orangepi5-cluster/)
* **Dagster Workflow Github** : [https://github.com/ssup2-playground/k8s-data-platform_dagster-workflows](https://github.com/ssup2-playground/k8s-data-platform_dagster-workflows)
* **Spark Job Github** : [https://github.com/ssup2-playground/k8s-data-platform_spark-jobs](https://github.com/ssup2-playground/k8s-data-platform_spark-jobs)

### 1.2. Spark Local Installation

```shell
brew install openjdk@17
sudo ln -sfn /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-17.jdk

echo 'export JAVA_HOME="/opt/homebrew/opt/openjdk@17"' >> ~/.zshrc
echo 'export PATH="$JAVA_HOME/bin:$PATH"' >> ~/.zshrc
export JAVA_HOME="/opt/homebrew/opt/openjdk@17"
export PATH="$JAVA_HOME/bin:$PATH"
```

Install Java 17 Version.

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

Install Spark.

### 1.3. Hive Metastore Table Creation

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

Create a Parquet Table for storing average weather data.

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

Create an Iceberg Parquet Table for storing average weather data.

## 2. Execution in Local Environment

### 2.1. Spark Application Download

```shell
git clone https://github.com/ssup2-playground/k8s-data-platform_spark-jobs.git
cd k8s-data-platform_spark-jobs
uv sync
```

Download the Spark Application and install Python packages.

### 2.2. Spark Master and Worker Execution

```shell
spark-class org.apache.spark.deploy.master.Master -h localhost
spark-class org.apache.spark.deploy.worker.Worker spark://localhost:7077
```

Open 2 shells and configure each as Master and Worker to form a Local Spark Cluster.

### 2.3. Spark Job Execution

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

Execute a Spark Job on the configured Local Spark Cluster to calculate average weather data using `daily-parquet` data. Add `hadoop-aws` and `aws-java-sdk-bundle` to Packages to enable access to MinIO.

```sql
CALL hive.system.sync_partition_metadata('weather', 'southkorea_daily_average_parquet', 'ADD');
SELECT * FROM hive.weather.southkorea_daily_average_parquet;
```

Update Trino's Partition information and execute a Query to verify average weather data.

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

Execute a Spark Job on the configured Local Spark Cluster to calculate average weather data using `daily-iceberg-parquet` data. Add `iceberg-spark3-runtime` to Packages to utilize Iceberg Tables.

```sql
SELECT * FROM iceberg.weather.southkorea_daily_average_iceberg_parquet;
```

Execute a Query to verify average weather data.

## 3. Execution in Kubernetes Environment

### 3.1. Service Account Configuration

```yaml {caption="[File 1] spark-job-service-account.yaml Manifest"}
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

```shell
kubectl apply -f spark-job-service-account.yaml
```

Apply the Service Account Manifest in [File 1] to grant permissions for Spark Job execution.

### 3.2. Spark Job Execution

Execute a Spark Job on the Kubernetes Cluster to calculate average weather data using `daily-parquet` data. The main configurations are as follows.

* `eventLog` : Specifies the location in MinIO where Spark Jobs will be stored.
* `spark.ui.prometheus.enabled` : Exposes Prometheus Metrics from Spark Jobs.
* `spark.kubernetes.driver.annotation.prometheus.io` : Configures Prometheus Server to collect Metrics exposed by Spark Jobs.

```shell
spark-submit \
  --master k8s://192.168.1.71:6443 \
  --deploy-mode cluster \
  --name weather-southkorea-daily-average-parquet \
  --driver-cores 1 \
  --driver-memory 1g \
  --executor-cores 1 \
  --executor-memory 1g \
  --conf spark.executor.instances=2 \
  --conf spark.kubernetes.namespace=spark \
  --conf spark.kubernetes.container.image=ghcr.io/ssup2-playground/k8s-data-platform_spark-jobs:0.1.8 \
  --conf spark.kubernetes.authenticate.driver.serviceAccountName=spark \
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

Execute a Spark Job on the Kubernetes Cluster to calculate average weather data using `daily-parquet` data.

```shell
spark-submit \
  --master k8s://192.168.1.71:6443 \
  --deploy-mode cluster \
  --name weather-southkorea-daily-average-iceberg-parquet \
  --driver-cores 1 \
  --driver-memory 1g \
  --executor-cores 1 \
  --executor-memory 1g \
  --conf spark.executor.instances=2 \
  --conf spark.kubernetes.namespace=spark \
  --conf spark.kubernetes.container.image=ghcr.io/ssup2-playground/k8s-data-platform_spark-jobs:0.1.8 \
  --conf spark.kubernetes.authenticate.driver.serviceAccountName=spark \
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

Execute a Spark Job on the Kubernetes Cluster to calculate average weather data using `daily-iceberg-parquet` data.

{{< figure caption="[Figure 2] Spark History Server" src="images/spark-history-server.png" width="1000px" >}}

Check the Spark History Server to verify execution logs of Spark Jobs. [Figure 2] shows checking execution logs of Spark Jobs in the Spark History Server.

{{< figure caption="[Figure 3] Prometheus" src="images/spark-prometheus-metric.png" width="550px" >}}

Check the `executors` Metric in Prometheus. [Figure 3] shows checking the `executors` Metric in Prometheus.

### 3.4. Spark Job Execution Using Spark Operator

```yaml {caption="[File 2] spark-job-spark-application-parquet.yaml Manifest"}
apiVersion: "sparkoperator.k8s.io/v1beta2"
kind: SparkApplication
metadata:
  namespace: spark
  name:  weather-southkorea-daily-average-parquet
spec:
  type: Python
  mode: cluster
  image: "ghcr.io/ssup2-playground/k8s-data-platform_spark-jobs:0.1.8"
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

```shell
kubectl apply -f spark-job-spark-application-parquet.yaml
```

Apply the Spark Application Manifest in [File 2] to execute a Spark Job that calculates average weather data using `daily-parquet` data.

```yaml {caption="[File 3] spark-job-spark-application-iceberg-parquet.yaml Manifest"}
apiVersion: "sparkoperator.k8s.io/v1beta2"
kind: SparkApplication
metadata:
  namespace: spark
  name:  weather-southkorea-daily-average-iceberg-parquet
spec:
  type: Python
  mode: cluster
  image: "ghcr.io/ssup2-playground/k8s-data-platform_spark-jobs:0.1.8"
  sparkVersion: "3.5.5"
  imagePullPolicy: Always
  mainApplicationFile: "local:///app/jobs/weather_southkorea_daily_average_iceberg_parquet.py"
  
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
      - org.apache.iceberg:iceberg-spark3-runtime:0.13.2

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
```shell
kubectl apply -f spark-job-spark-application-iceberg-parquet.yaml
```

Apply the Spark Application Manifest in [File 3] to execute a Spark Job that calculates average weather data using `daily-iceberg-parquet` data.

### 3.5. Spark Job Execution from Dagster Pipeline

```python {caption="[File 4] execute_spark_job() Function"}
def execute_spark_job(context, job_name_prefix: str, job_script: str, job_args: list, 
                     spark_image: str, jars: list, timeout_seconds: int = 600):
    """Execute a Spark job on Kubernetes"""
    # Get job name with unique suffix
    spark_job_name = f"{job_name_prefix}-{str(uuid.uuid4())[:8]}"
    if len(spark_job_name) > 63:
        spark_job_name = spark_job_name[:63]

    # Get dagster pod info
    dagster_pod_service_account_name = get_k8s_service_account_name()
    dagster_pod_namespace = get_k8s_pod_namespace()
    dagster_pod_name = get_k8s_pod_name()
    dagster_pod_uid = get_k8s_pod_uid()

    # Init kubernetes client
    config.load_incluster_config()
    k8s_client = client.CoreV1Api()

    # Create spark driver service
    spark_driver_service = client.V1Service(
        api_version="v1",
        kind="Service",
        metadata=client.V1ObjectMeta(
            name=spark_job_name,
            owner_references=[
                client.V1OwnerReference(
                    api_version="v1",
                    kind="Pod",
                    name=dagster_pod_name,
                    uid=dagster_pod_uid
                )
            ],
        ),
        spec=client.V1ServiceSpec(
            selector={"spark": spark_job_name},
            ports=[
                client.V1ServicePort(port=7077, target_port=7077)
            ],
            cluster_ip="None"
        )
    )

    try:
        k8s_client.create_namespaced_service(
            namespace=dagster_pod_namespace,
            body=spark_driver_service
        )
        context.log.info(f"Spark driver service created for {spark_job_name}")
    except Exception as e:
        context.log.error(f"Error creating spark driver service: {e}")
        raise e

    # Create spark driver pod
    spark_driver_job = client.V1Pod(
        api_version="v1",
        kind="Pod",
        metadata=client.V1ObjectMeta(
            name=spark_job_name,
            labels={
                "spark": spark_job_name
            },
            annotations={
                "prometheus.io/scrape": "true",
                "prometheus.io/path": "/metrics/executors/prometheus",
                "prometheus.io/port": "4040"
            },
            owner_references=[
                client.V1OwnerReference(
                    api_version="v1",
                    kind="Pod",
                    name=dagster_pod_name,
                    uid=dagster_pod_uid
                )
            ]
        ),
        spec=client.V1PodSpec(
            service_account_name=dagster_pod_service_account_name,
            restart_policy="Never",
            automount_service_account_token=True,
            containers=[
                client.V1Container(
                    name="spark-driver",
                    image=spark_image,
                    args=[
                        "spark-submit",
                        "--master", "k8s://kubernetes.default.svc.cluster.local.:443",
                        "--deploy-mode", "client",
                        "--name", f"{spark_job_name}",
                        "--conf", "spark.driver.host=" + f"{spark_job_name}.{dagster_pod_namespace}.svc.cluster.local.",
                        "--conf", "spark.driver.port=7077",
                        "--conf", "spark.executor.cores=1",
                        "--conf", "spark.executor.memory=1g",
                        "--conf", "spark.executor.instances=2",
                        "--conf", "spark.pyspark.python=/app/.venv/bin/python3",
                        "--conf", "spark.jars.packages=" + ",".join(jars),
                        "--conf", "spark.jars.ivy=/tmp/.ivy",
                        "--conf", "spark.kubernetes.namespace=" + f"{dagster_pod_namespace}",
                        "--conf", "spark.kubernetes.driver.pod.name=" + f"{spark_job_name}",
                        "--conf", "spark.kubernetes.executor.podNamePrefix=" + f"{spark_job_name}",
                        "--conf", "spark.kubernetes.container.image=" + f"{spark_image}",
                        "--conf", "spark.kubernetes.executor.request.cores=1",
                        "--conf", "spark.kubernetes.executor.limit.cores=2",
                        "--conf", "spark.kubernetes.authenticate.serviceAccountName=" + f"{dagster_pod_service_account_name}",
                        "--conf", "spark.kubernetes.authenticate.caCertFile=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt",
                        "--conf", "spark.kubernetes.authenticate.oauthTokenFile=/var/run/secrets/kubernetes.io/serviceaccount/token",
                        "--conf", "spark.eventLog.enabled=true",
                        "--conf", "spark.eventLog.dir=s3a://spark/logs",
                        "--conf", "spark.ui.prometheus.enabled=true",
                        job_script
                    ] + job_args
                )
            ]
        )
    )

    try:
        k8s_client.create_namespaced_pod(
            namespace=dagster_pod_namespace,
            body=spark_driver_job
        )
        context.log.info(f"Spark driver pod created for {spark_job_name}")
    except Exception as e:
        context.log.error(f"Error creating spark driver pod: {e}")
        raise e

    # Wait for pod to be deleted with watch
    v1 = client.CoreV1Api()
    w = watch.Watch()
    timed_out = True

    for event in w.stream(v1.list_namespaced_pod, namespace=dagster_pod_namespace, 
                         field_selector=f"metadata.name={spark_job_name}", 
                         timeout_seconds=timeout_seconds):
        pod = event["object"]
        phase = pod.status.phase
        if phase in ["Succeeded", "Failed"]:
            timed_out = False
            if phase == "Failed":
                context.log.error(f"Pod '{spark_job_name}' has terminated with status: {phase}")
                raise Exception(f"Pod '{spark_job_name}' has terminated with status: {phase}")
            else:
                context.log.info(f"Pod '{spark_job_name}' has terminated with status: {phase}")
            break

    if timed_out:
        context.log.error(f"Pod '{spark_job_name}' timed out")
        raise Exception(f"Pod '{spark_job_name}' timed out")
```

Dagster does not officially support Spark Job submission using the `spark-submit` CLI. Therefore, define the `execute_spark_job` function in [File 4] to execute Spark Jobs from Dagster Pipeline. The main characteristics of the `execute_spark_job` function are as follows.

* Creates a separate `spark-submit` CLI Pod and executes Spark Jobs in Client Mode using the `spark-submit` CLI from the created Pod. That is, the Driver runs in the `spark-submit` Pod.
* The Owner of the `spark-submit` CLI Pod is the Pod of Dagster's Run or Op/Asset. Therefore, when the Dagster Pipeline terminates and the Dagster Pod is removed, the `spark-submit` CLI Pod is also naturally removed, and then the Executor Pods are automatically removed.
* Before creating the `spark-submit` CLI Pod, create a Headless Service for Executor Pods to access the `spark-submit` CLI Pod.

## 4. Execution with Volcano Scheduler in Kubernetes Environment

### 4.1. Volcano Scheduler Queue Configuration

```yaml
apiVersion: scheduling.volcano.sh/v1beta1
kind: Queue
metadata:
  name: sparkqueue
spec:
  weight: 4
  reclaimable: false
  capability:
    cpu: 10
    memory: 20Gi
```

Configure the Queue of Volcano Scheduler for Spark Jobs.

### 4.2. PodGroup Configuration

```yaml
apiVersion: scheduling.volcano.sh/v1beta1
kind: PodGroup
spec:
  queue: sparkqueue
  minMember: 1
  minResources:
    cpu: "4"
    memory: "4Gi"
```

Create a PodGroup file and copy it to `/app/configs/volcano.yaml` in the Spark Job Container Image. The main configurations are as follows.

* `queue` : Specifies the Queue name to use. Specify the Queue name created above.
* `minMember` : Specifies the minimum number of Pods that can be executed. Must be set to `1` because Driver Pods operate independently.
* `minResources` : Specifies the resources of the minimum Pods that can be executed. Specify the sum of Resources of Driver Pods and Executor Pods. Volcano Scheduler schedules Spark Job Pods when Resources equal to `minResources` are available.


### 4.2. Spark Job Execution

```shell
spark-submit \
  --master k8s://192.168.1.71:6443 \
  --deploy-mode cluster \
  --name weather-southkorea-daily-average-parquet \
  --driver-cores 1 \
  --driver-memory 1g \
  --executor-cores 1 \
  --executor-memory 1g \
  --conf spark.executor.instances=2 \
  --conf spark.kubernetes.namespace=spark \
  --conf spark.kubernetes.container.image=ghcr.io/ssup2-playground/k8s-data-platform_spark-jobs:0.1.8 \
  --conf spark.kubernetes.authenticate.driver.serviceAccountName=spark \
  --conf spark.pyspark.python=/app/.venv/bin/python3 \
  --conf spark.jars.packages=org.apache.hadoop:hadoop-aws:3.3.4,com.amazonaws:aws-java-sdk-bundle:1.12.262 \
  --conf spark.kubernetes.scheduler.name=volcano \
  --conf spark.kubernetes.scheduler.volcano.podGroupTemplateFile=/app/configs/volcano.yaml \
  --conf spark.eventLog.enabled=true \
  --conf spark.eventLog.dir=s3a://spark/logs \
  --conf spark.ui.prometheus.enabled=true \
  --conf spark.kubernetes.driver.annotation.prometheus.io/scrape=true \
  --conf spark.kubernetes.driver.annotation.prometheus.io/path=/metrics/executors/prometheus \
  --conf spark.kubernetes.driver.annotation.prometheus.io/port=4040 \
  local:///app/jobs/weather_southkorea_daily_average_parquet.py \
  --date 20250601
```

Execute a Spark Job with Volcano Scheduler to calculate average weather data using `daily-parquet` data. Specify `volcano` in `spark.kubernetes.scheduler.name` and `/app/configs/volcano.yaml` in `spark.kubernetes.scheduler.volcano.podGroupTemplateFile`.

```shell
spark-submit \
  --master k8s://192.168.1.71:6443 \
  --deploy-mode cluster \
  --name weather-southkorea-daily-average-iceberg-parquet \
  --driver-cores 1 \
  --driver-memory 1g \
  --executor-cores 1 \
  --executor-memory 1g \
  --conf spark.executor.instances=2 \
  --conf spark.kubernetes.namespace=spark \
  --conf spark.kubernetes.container.image=ghcr.io/ssup2-playground/k8s-data-platform_spark-jobs:0.1.8 \
  --conf spark.kubernetes.authenticate.driver.serviceAccountName=spark \
  --conf spark.pyspark.python=/app/.venv/bin/python3 \
  --conf spark.jars.packages=org.apache.hadoop:hadoop-aws:3.3.4,com.amazonaws:aws-java-sdk-bundle:1.12.262,org.apache.iceberg:iceberg-spark3-runtime:0.13.2 \
  --conf spark.kubernetes.scheduler.name=volcano \
  --conf spark.kubernetes.scheduler.volcano.podGroupTemplateFile=/app/configs/volcano.yaml \
  --conf spark.eventLog.enabled=true \
  --conf spark.eventLog.dir=s3a://spark/logs \
  --conf spark.ui.prometheus.enabled=true \
  --conf spark.kubernetes.driver.annotation.prometheus.io/scrape=true \
  --conf spark.kubernetes.driver.annotation.prometheus.io/path=/metrics/executors/prometheus \
  --conf spark.kubernetes.driver.annotation.prometheus.io/port=4040 \
  local:///app/jobs/weather_southkorea_daily_average_iceberg_parquet.py \
  --date 20250601
```

Execute a Spark Job on the Kubernetes Cluster to calculate average weather data using `daily-iceberg-parquet` data.

## 5. References

* Spark Local Environment Setup : [https://bluehorn07.github.io/2024/08/18/run-spark-on-local-2/](https://bluehorn07.github.io/2024/08/18/run-spark-on-local-2/)
* Volcano Scheduler Configuration : [https://docs.aws.amazon.com/emr/latest/EMR-on-EKS-DevelopmentGuide/tutorial-volcano.html](https://docs.aws.amazon.com/emr/latest/EMR-on-EKS-DevelopmentGuide/tutorial-volcano.html)

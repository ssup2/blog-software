---
title: Spark on Kubernetes
---

## 1. Spark on Kubernetes

Spark supports Kubernetes as a Cluster Manager. That is, Spark can use Computing Resources managed by Kubernetes Cluster.

### 1.1. Spark Job Submission

There are two ways to submit Spark Jobs to Kubernetes Cluster in Spark: using spark-submit CLI and using Spark Operator. The method of submitting Spark Jobs and Architecture differ depending on each method.

#### 1.1.1. spark-submit CLI

{{< figure caption="[Figure 1] spark-submit Architecture" src="images/spark-submit-architecture.png" width="1000px" >}}

spark-submit CLI is a tool for submitting Spark Jobs in Spark, and can also submit Spark Jobs to Kubernetes Cluster. The blue arrows in [Figure 1] show the Spark Job processing flow when Spark Job is submitted to Kubernetes Cluster through spark-submit CLI.

This shows the Architecture when submitting Spark Jobs with spark-submit CLI. Driver Pod is created through spark-submit CLI, and Driver Pod creates Executor Pods to process Spark Jobs. Detailed settings for Spark Jobs through spark-submit CLI can be configured through [Property](https://spark.apache.org/docs/latest/configuration.html) settings using "\-\-conf" Parameter or "\-\-properties-file" Parameter.

```shell {caption="[Shell 1] spark-submit CLI Example"}
$ spark-submit \
 --master k8s://87C2A505AF21618F97F402E454E530AF.yl4.ap-northeast-2.eks.amazonaws.com \
 --deploy-mode cluster \
 --driver-cores 1 \
 --driver-memory 512m \
 --num-executors 1 \
 --executor-cores 1 \
 --executor-memory 512m \
 --conf spark.kubernetes.namespace=spark \
 --conf spark.kubernetes.authenticate.driver.serviceAccountName=spark \
 --conf spark.kubernetes.container.image=public.ecr.aws/r1l5w1y9/spark-operator:3.2.1-hadoop-3.3.1-java-11-scala-2.12-python-3.8-latest \
 local:///opt/spark/examples/src/main/python/pi.py
```

[Shell 1] shows an example of submitting a Spark Job to Kubernetes Cluster through spark-submit CLI. When spark-submit CLI runs, it first creates a Driver ConfigMap with configuration information needed for Driver Pod and Spark Job startup. Then, when creating Driver Pod, it sets the previously created Driver ConfigMap as a Volume of Driver Pod, so that Driver inside Driver Pod can reference the contents of Driver ConfigMap.

```yaml {caption="[File 1] Driver Pod ConfigMap Example", linenos=table}
apiVersion: v1
data:
  spark.kubernetes.namespace: spark
  spark.properties: |
    #Java properties built from Kubernetes config map with name: spark-drv-ba5ad08a119168fa-conf-map
    #Sun Aug 20 15:10:56 KST 2023
    spark.executor.memory=512m
    spark.driver.port=7078
    spark.driver.memory=512m
    spark.master=k8s\://https\://87C2A505AF21618F97F402E454E530AF.yl4.ap-northeast-2.eks.amazonaws.com
    spark.submit.pyFiles=
    spark.driver.cores=1
    spark.app.name=pi.py
    spark.executor.cores=1
    spark.kubernetes.resource.type=python
    spark.submit.deployMode=cluster
    spark.driver.host=pi-py-d30f398a1191624d-driver-svc.spark.svc
    spark.driver.blockManager.port=7079
    spark.app.id=spark-ee85f8f3ee0b4a3ebf355860e3f4930c
    spark.kubernetes.namespace=spark
    spark.app.submitTime=1692511855108
    spark.kubernetes.container.image=public.ecr.aws/r1l5w1y9/spark-operator\:3.2.1-hadoop-3.3.1-java-11-scala-2.12-python-3.8-latest
    spark.kubernetes.memoryOverheadFactor=0.4
    spark.kubernetes.submitInDriver=true
    spark.kubernetes.authenticate.driver.serviceAccountName=spark
    spark.kubernetes.driver.pod.name=pi-py-d30f398a1191624d-driver
    spark.executor.instances=1
immutable: true
kind: ConfigMap
metadata:
  creationTimestamp: "2023-08-20T06:10:57Z"
  name: spark-drv-ba5ad08a119168fa-conf-map
  namespace: spark
  ownerReferences:
  - apiVersion: v1
    controller: true
    kind: Pod
    name: pi-py-d30f398a1191624d-driver
    uid: 4c0e60c2-6764-4724-9755-edf8f3b61873
  resourceVersion: "16540791"
  uid: be65c68c-cd50-4af9-8398-045785d2f991
```

[File 1] shows a Driver ConfigMap example. You can see that the Property section contains settings related to Driver/Executor Pods and Spark Jobs. Driver inside Driver Pod creates Executor ConfigMap that Executor inside Executor Pod will reference, based on the contents of Driver ConfigMap. It also creates Driver Pod's Headless Service to provide IP information of Driver Pod to Executor.

```yaml {caption="[File 2] Executor Pod ConfigMap Example", linenos=table}
apiVersion: v1
immutable: true
kind: ConfigMap
metadata:
  creationTimestamp: "2023-08-20T06:11:06Z"
  labels:
    spark-app-selector: spark-ee85f8f3ee0b4a3ebf355860e3f4930c
    spark-role: executor
  name: spark-exec-4dceb18a11919007-conf-map
  namespace: spark
  ownerReferences:
  - apiVersion: v1
    controller: true
    kind: Pod
    name: pi-py-d30f398a1191624d-driver
    uid: 4c0e60c2-6764-4724-9755-edf8f3b61873
  resourceVersion: "16540841"
  uid: 4dc52722-8ed4-424d-a988-ad3e4d515f4f
```

Afterwards, Driver creates Executor Pods that use Executor ConfigMap as Volume, based on the contents of Driver ConfigMap. [File 2] shows an Executor ConfigMap example. Driver creates Properties in Executor ConfigMap only when separate settings are needed for Executor. In the case of [File 2], you can see that the content is empty because no separate Property settings are needed. Executor inside Executor Pod finds out Driver Pod's IP information through Driver's Headless Service and then connects to Driver Pod. Afterwards, Executor receives Tasks from Driver and processes them.

#### 1.1.2. Spark Operator

{{< figure caption="[Figure 2] spark-operator Architecture" src="images/spark-operator-architecture.png" width="1000px" >}}

Spark Operator is a tool that helps define Spark Job submission as Kubernetes Objects. [Figure 2] shows the Architecture when submitting Spark Jobs through Spark Operator. Compared to spark-submit CLI's Architecture, the biggest difference is that Users do not use spark-submit CLI but define SparkApplication, ScheduledSparkApplication Objects to submit Spark Jobs.

Both SparkApplication and ScheduledSparkApplication are unique Objects provided by Spark Operator. SparkApplication is used for ad-hoc submission of a single Spark Job, and ScheduledSparkApplication Object is used when Spark Jobs need to be submitted periodically like Cron. When SparkApplication, ScheduledSparkApplication Objects are created, spark-submit CLI inside Spark Operator performs Spark Job submission. Detailed Specs of SparkApplication, ScheduledSparkApplication can be found at [Operator API Page](https://googlecloudplatform.github.io/spark-on-k8s-operator/docs/api-docs.html).

```yaml {caption="[File 3] SparkApplication Example", linenos=table}
apiVersion: sparkoperator.k8s.io/v1beta2
kind: SparkApplication
metadata:
  name: spark-pi
  namespace: default
spec:
  type: Python
  mode: cluster
  image: "public.ecr.aws/r1l5w1y9/spark-operator:3.2.1-hadoop-3.3.1-java-11-scala-2.12-python-3.8-latest"
  mainApplicationFile: local:///opt/spark/examples/src/main/python/pi.py
  sparkVersion: "3.1.1"
  driver:
    cores: 1
    memory: 512m
  executor:
    cores: 1
    instances: 1
    memory: 512m
```

[File 3] shows a SparkApplication example. You can see that the Spec section contains settings needed to perform Spark Jobs.

```yaml {caption="[File 4] ScheduledSparkApplication Example", linenos=table}
apiVersion: "sparkoperator.k8s.io/v1beta2"
kind: ScheduledSparkApplication
metadata:
  name: spark-pi-scheduled
  namespace: default
spec:
  schedule: "@every 5m"
  concurrencyPolicy: Allow
  successfulRunHistoryLimit: 1
  failedRunHistoryLimit: 3
  template:
    type: Python
    mode: cluster
    image: "public.ecr.aws/r1l5w1y9/spark-operator:3.2.1-hadoop-3.3.1-java-11-scala-2.12-python-3.8-latest"
    mainApplicationFile: local:///opt/spark/examples/src/main/python/pi.py
    sparkVersion: "3.1.1"
    driver:
      cores: 1
      memory: 512m
    executor:
      cores: 1
      instances: 1
      memory: 512m
```

[File 4] shows a ScheduledSparkApplication example. The Template section of ScheduledSparkApplication's Spec is the same as SparkApplication's Spec section. However, Schedule, Concurrency Policy, etc. located in Spec are only available in ScheduledSparkApplication.

Another difference when using Spark Operator compared to using spark-submit CLI is that Spark Operator creates Service and Ingress so that Users can access the Web UI provided by Spark Driver. The green arrows in [Figure 2] show the process of Users accessing Spark Web UI through Spark Driver's Service and Ingress.

### 1.2. Pod Template

```yaml {caption="[File 5] Pod Template Example", linenos=table}
apiVersion: v1
kind: Pod
spec:
  volumes:
    - name: source-data-volume
      emptyDir: {}
    - name: metrics-files-volume
      emptyDir: {}
  nodeSelector:
    eks.amazonaws.com/nodegroup: emr-containers-nodegroup
  containers:
  - name: spark-kubernetes-driver # This will be interpreted as driver Spark main container
    env:
      - name: RANDOM
        value: "random"
    volumeMounts:
      - name: shared-volume
        mountPath: /var/data
      - name: metrics-files-volume
        mountPath: /var/metrics/data
  - name: custom-side-car-container # Sidecar container
    image: <side_car_container_image>
    env:
      - name: RANDOM_SIDECAR
        value: random
    volumeMounts:
      - name: metrics-files-volume
        mountPath: /var/metrics/data
    command:
      - /bin/sh
      - '-c'
      -  <command-to-upload-metrics-files>
  initContainers:
  - name: spark-init-container-driver # Init container
    image: <spark-pre-step-image>
    volumeMounts:
      - name: source-data-volume # Use EMR predefined volumes
        mountPath: /var/data
    command:
      - /bin/sh
      - '-c'
      -  <command-to-download-dependency-jars>
```

Through Pod Template, settings for Driver Pod or Executor Pod that cannot be set with Spark Config are possible. [File 5] shows a Pod Template example provided in AWS EMR on EKS documentation. Init Container, Sidecar Container, etc. that cannot be set with Spark Config can be set through Pod Template.

```shell {caption="[Shell 2] spark-submit CLI with Pod Template Example"}
$ spark-submit \
 --master k8s://87C2A505AF21618F97F402E454E530AF.yl4.ap-northeast-2.eks.amazonaws.com \
 --deploy-mode cluster \
 --driver-cores 1 \
 --driver-memory 512m \
 --num-executors 1 \
 --executor-cores 1 \
 --executor-memory 512m \
 --conf spark.kubernetes.driver.podTemplateFile=s3a://bucket/driver.yml
 --conf spark.kubernetes.executor.podTemplateFile=s3a://bucket/executor.yml
...
```

[Shell 2] shows an example of specifying Pod Template. Pod Template can be specified through podTemplateFile setting in Spark Config. Driver Pod and Executor Pod can each be specified separately.

### 1.3. Spark History Server

Spark History Server performs the role of visualizing Event Logs left by Spark Driver or Spark Executor. In Kubernetes Cluster environments, Spark History Server runs as a separate Pod. When Spark Jobs are submitted, Event Log activation of Spark Driver and the location to leave Event Logs can be specified through Config settings. In Kubernetes Cluster environments, external Object Storage such as PVC or AWS S3 is generally used as Event Log storage.

```shell {caption="[Shell 3] spark-submit CLI with Event Log Example"}
$ spark-submit \
 --master k8s://87C2A505AF21618F97F402E454E530AF.yl4.ap-northeast-2.eks.amazonaws.com \
 --deploy-mode cluster \
 --driver-cores 1 \
 --driver-memory 512m \
 --num-executors 1 \
 --executor-cores 1 \
 --executor-memory 512m \
 --conf spark.kubernetes.namespace=spark \
 --conf spark.kubernetes.authenticate.driver.serviceAccountName=spark \
 --conf spark.kubernetes.container.image=public.ecr.aws/r1l5w1y9/spark-operator:3.2.1-hadoop-3.3.1-java-11-scala-2.12-python-3.8-latest \
 --conf spark.eventLog.enabled=true \
 --conf spark.eventLog.dir=s3a://ssup2-spark/history \
 --conf spark.kubernetes.driver.secretKeyRef.AWS_ACCESS_KEY_ID=aws-secrets:key \
 --conf spark.kubernetes.driver.secretKeyRef.AWS_SECRET_ACCESS_KEY=aws-secrets:secret \
 --conf spark.kubernetes.executor.secretKeyRef.AWS_ACCESS_KEY_ID=aws-secrets:key \
 --conf spark.kubernetes.executor.secretKeyRef.AWS_SECRET_ACCESS_KEY=aws-secrets:secret \
 local:///opt/spark/examples/src/main/python/pi.py
```

The red arrows in [Figure 1] show the process of Event Logs being delivered to users through Spark History Server. When submitting Spark Jobs with spark-submit CLI, Event Log path can be set through eventLog.dir setting in Config Parameter as shown in [Shell 3]. secretKeyRef settings represent Access Key and Secret Access Key stored in Kubernetes Secret to access s3 (s3a://ssup2-spark/history) specified as Event Log path.

```yaml {caption="[File 6] SparkApplication Example with Event Log", linenos=table}
apiVersion: sparkoperator.k8s.io/v1beta2
kind: SparkApplication
metadata:
  name: spark-pi
  namespace: default
spec:
  type: Python
  mode: cluster
  image: "public.ecr.aws/r1l5w1y9/spark-operator:3.2.1-hadoop-3.3.1-java-11-scala-2.12-python-3.8-latest"
  mainApplicationFile: local:///opt/spark/examples/src/main/python/pi.py
  sparkVersion: "3.1.1"
  sparkConf:
    spark.eventLog.enabled: "true"
    spark.eventLog.dir: "s3a://ssup2-spark/history"
    spark.kubernetes.driver.secretKeyRef.AWS_ACCESS_KEY_ID: "aws-secrets:key"
    spark.kubernetes.driver.secretKeyRef.AWS_SECRET_ACCESS_KEY : "aws-secrets:secret"
    spark.kubernetes.executor.secretKeyRef.AWS_ACCESS_KEY_ID: "aws-secrets:key"
    spark.kubernetes.executor.secretKeyRef.AWS_SECRET_ACCESS_KEY : "aws-secrets:secret"
  driver:
    cores: 1
    memory: 512m
  executor:
    cores: 1
    instances: 1
    memory: 512m
```

The red arrows in [Figure 2] also show the process of Event Logs being delivered to users through Spark History Server. [File 6] shows a SparkApplication with Event Log settings. Event Log path can be set through eventLog.dir setting in sparkConf section.

### 1.4. Scheduler for Spark

Kubernetes' Default Scheduler only performs Scheduling for each Pod unit and does not consider relationships between Pods when performing Scheduling. Kubernetes provides Multiple Scheduler functionality to help mitigate this shortcoming, allowing Third-party Schedulers or users to develop and use Custom Schedulers directly.

When Spark Jobs are submitted to Kubernetes Cluster, Driver inside Driver Pod directly creates and uses Executor Pods, which makes **Batch Scheduling** techniques that schedule multiple Pods at once useful in many cases. Also, because Executor Pods exchange a lot of data with each other due to Spark Job's Shuffle operations, **Application-aware Scheduling** techniques that can place Executor Pods on the same Node when possible are useful in many cases. These Scheduling techniques are generally available through Third-party Schedulers such as **YuniKorn** and **Volcano**.

#### 1.4.1. Batch Scheduling

When Spark Jobs are submitted to Kubernetes Cluster, Driver inside Driver Pod directly creates Executor Pods. This means that if Cluster Auto-scaling is not being used in Kubernetes Cluster, Executor Pods created by Driver may fail to be created due to resource shortage. If all Executor Pods fail to be created due to resource shortage after Driver Pod is created, not only does Spark Job processing fail, but unnecessary waste of resources used for Driver Pod operation also occurs.

The reason this problem occurs is that only Driver Pod is created when Spark Job is submitted, and Kubernetes' Default Scheduler does not recognize that Executor Pods created by Driver Pod are used inside Driver Pod. Using Batch Scheduling techniques that schedule all Pods at once only when resources available for Driver Pod and all Executor Pods are secured can solve this problem.

Using Batch Scheduling techniques helps process Spark Jobs quickly even in environments where Cluster Auto-scaler is running in Kubernetes Cluster. Without Batch Scheduling, Cluster Auto-scaling occurs once when Driver Pod is created, and then Auto-scaling occurs again when Executor Pods are created, resulting in a total of 2 Auto-scaling occurrences. On the other hand, with Batch Scheduling, resources needed for Driver Pod and Executor Pods can be secured with one Auto-scaling, so the number of Auto-scaling occurrences can be reduced.

### 1.5. Monitoring with Prometheus

From Spark 3.0 Version, Driver can receive Metrics from Executors and expose Executor Metrics at the ":4040/metrics/executors/prometheus" path. Exposed Executor Metrics can be found at [Link](https://spark.apache.org/docs/latest/monitoring.html#executor-metrics).

```shell {caption="[Shell 4] spark-submit CLI with Prometheus Monitoring"}
$ spark-submit \
 --master k8s://87C2A505AF21618F97F402E454E530AF.yl4.ap-northeast-2.eks.amazonaws.com \
 --deploy-mode cluster \
 --driver-cores 1 \
 --driver-memory 512m \
 --num-executors 1 \
 --executor-cores 1 \
 --executor-memory 512m \
 --conf spark.kubernetes.namespace=spark \
 --conf spark.kubernetes.authenticate.driver.serviceAccountName=spark \
 --conf spark.kubernetes.container.image=public.ecr.aws/r1l5w1y9/spark-operator:3.2.1-hadoop-3.3.1-java-11-scala-2.12-python-3.8-latest \
 --conf spark.ui.prometheus.enabled=true \
 --conf spark.kubernetes.driver.annotation.prometheus.io/scrape=true \
 --conf spark.kubernetes.driver.annotation.prometheus.io/path=/metrics/executors/prometheus \
 --conf spark.kubernetes.driver.annotation.prometheus.io/port=4040 \
```

By attaching a few Annotations to Executor Pod in Prometheus, Prometheus can automatically discover Targets and collect Metrics. [Shell 4] shows an example of automatically exposing Metrics with Prometheus. It enables Prometheus in Spark Config section and attaches Annotations so Prometheus can automatically collect Driver Metrics.

## 2. References

* [https://spark.apache.org/docs/latest/running-on-kubernetes.html](https://spark.apache.org/docs/latest/running-on-kubernetes.html)
* [https://swalloow.github.io/spark-on-kubernetes-scheduler/](https://swalloow.github.io/spark-on-kubernetes-scheduler/)
* spark-submit : [https://spark.apache.org/docs/latest/submitting-applications.html](https://spark.apache.org/docs/latest/submitting-applications.html)
* Spark Configuration : [https://spark.apache.org/docs/latest/configuration.html](https://spark.apache.org/docs/latest/configuration.html)
* Spark Pod Template Example : [https://docs.aws.amazon.com/emr/latest/EMR-on-EKS-DevelopmentGuide/pod-templates.html](https://docs.aws.amazon.com/emr/latest/EMR-on-EKS-DevelopmentGuide/pod-templates.html)
* Spark Operator API Spec : [https://googlecloudplatform.github.io/spark-on-k8s-operator/docs/api-docs.html](https://googlecloudplatform.github.io/spark-on-k8s-operator/docs/api-docs.html)
* Spark Executor Metric : [https://spark.apache.org/docs/latest/monitoring.html#executor-metrics](https://spark.apache.org/docs/latest/monitoring.html#executor-metrics)
* Spark Monitoring with Prometheus : [http://jason-heo.github.io/bigdata/2021/01/31/spark30-prometheus.html](http://jason-heo.github.io/bigdata/2021/01/31/spark30-prometheus.html)
* Spark Monitoring with Prometheus : [https://dzlab.github.io/bigdata/2020/07/03/spark3-monitoring-1/](https://dzlab.github.io/bigdata/2020/07/03/spark3-monitoring-1/)
* Spark Monitoring with Prometheus : [https://dzlab.github.io/bigdata/2020/07/03/spark3-monitoring-2/](https://dzlab.github.io/bigdata/2020/07/03/spark3-monitoring-2/)


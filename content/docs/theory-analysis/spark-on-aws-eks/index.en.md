---
title: Spark on AWS EKS
---

This document analyzes Spark Application operation in AWS EKS Cluster. There are two ways to run Spark Applications in AWS EKS Cluster: using spark-submit CLI and Spark Operator provided by Spark, and using StartJobRun API provided by EMR on EKS.

## 1. spark-submit CLI & Spark Operator

In AWS EKS, Spark Applications can be run using spark-submit CLI and Spark Operator, just like in general Kubernetes Clusters. In this case, the Architecture and operation method are the same as using spark-submit CLI and Spark Operator in general Kubernetes Clusters, as described in the following [Link](https://ssup2.github.io/blog-software/docs/theory-analysis/spark-on-kubernetes/).

However, in AWS EKS, it is recommended to use **EMR on EKS Spark Container Image** as the Container Image for Driver and Executor Pods. EMR on EKS Spark Container Image contains Optimized Spark optimized for EKS environments, showing better performance compared to Open Source Spark, and includes AWS-related Libraries and Spark Connectors listed below.

* EMRFS S3-optimized committer
* Spark Connector for AWS Redshift : Used when accessing AWS Redshift from Spark Applications
* Spark Library for AWS SageMaker : Data stored in Spark Application's DataFrame can be directly used for Training through AWS SageMaker

EMR on EKS Spark Container Image is publicly available at [Public AWS ECR](https://gallery.ecr.aws/emr-on-eks). When using unique Libraries and Spark Connectors in Spark Applications, Custom Container Images must be built, and in this case, it is also recommended to use EMR on EKS Spark Container Image as the Base Image.

## 2. StartJobRun API

StartJobRun API is an API for submitting Spark Jobs in EMR on EKS environments. To use StartJobRun API, a **Virtual Cluster**, which is a virtual Resource managed by AWS EMR, must be created. To create Virtual Cluster, one Namespace existing in EKS Cluster is needed. Multiple Namespaces can be created in one EKS Cluster, and multiple Virtual Clusters can be mapped to each Namespace, allowing multiple Virtual Clusters to be operated in one EKS Cluster.

{{< figure caption="[Figure 1] Spark on AWS EKS Architecture with StartJobRun API" src="images/spark-aws-eks-architecture-startjobrun-api.png" width="1000px" >}}

[Figure 1] shows the Architecture when submitting Spark Jobs through StartJobRun API to an EKS Cluster with one Virtual Cluster. When StartJobRun API is called, a job-runner Pod is created in the Namespace mapped to Virtual Cluster, and spark-submit CLI runs inside job-runner Pod. That is, **StartJobRun API method also uses spark-submit CLI internally** to submit Spark Jobs.

```shell {caption="[Shell 1] aws CLI StartJobRun API Example"}
$ aws emr-containers start-job-run \
 --virtual-cluster-id [virtual-cluster-id] \
 --name=pi \
 --region ap-northeast-2 \
 --execution-role-arn arn:aws:iam::[account-id]:role/ts-eks-emr-eks-emr-cli \
 --release-label emr-6.8.0-latest \
 --job-driver '{
     "sparkSubmitJobDriver":{
       "entryPoint": "local:///usr/lib/spark/examples/src/main/python/pi.py",
       "sparkSubmitParameters": "--conf spark.executor.instances=2 --conf spark.executor.memory=2G --conf spark.executor.cores=1 --conf spark.driver.cores=1"
     }
   }'
```

[Shell 1] shows an example of submitting Spark Jobs through StartJobRun API using aws CLI. You can see that Virtual Cluster, the name of submitted Spark Job, AWS Region, Role for Spark Job execution, and Spark-related settings are specified. You can also see that `--conf` Parameters passed through spark-submit CLI are set in the `sparkSubmitParameters` item.

```yaml {caption="[File 1] spark-default ConfigMap", linenos=table}
apiVersion: v1
data:
  spark-defaults.conf: |
    spark.kubernetes.executor.podTemplateValidation.enabled true
    spark.executor.extraClassPath \/usr\/lib\/hadoop-lzo\/lib\/*:\/usr\/lib\/hadoop\/hadoop-aws.jar:\/usr\/share\/aws\/aws-java-sdk\/*:\/usr\/share\/aws\/emr\/emrfs\/conf:\/usr\/share\/aws\/emr\/emrfs\/lib\/*:\/usr\/share\/aws\/emr\/emrfs\/auxlib\/*:\/usr\/share\/aws\/emr\/goodies\/lib\/emr-spark-goodies.jar:\/usr\/share\/aws\/emr\/security\/conf:\/usr\/share\/aws\/emr\/security\/lib\/*:\/usr\/share\/aws\/hmclient\/lib\/aws-glue-datacatalog-spark-client.jar:\/usr\/share\/java\/Hive-JSON-Serde\/hive-openx-serde.jar:\/usr\/share\/aws\/sagemaker-spark-sdk\/lib\/sagemaker-spark-sdk.jar:\/usr\/share\/aws\/emr\/s3select\/lib\/emr-s3-select-spark-connector.jar:\/docker\/usr\/lib\/hadoop-lzo\/lib\/*:\/docker\/usr\/lib\/hadoop\/hadoop-aws.jar:\/docker\/usr\/share\/aws\/aws-java-sdk\/*:\/docker\/usr\/share\/aws\/emr\/emrfs\/conf:\/docker\/usr\/share\/aws\/emr\/emrfs\/lib\/*:\/docker\/usr\/share\/aws\/emr\/emrfs\/auxlib\/*:\/docker\/usr\/share\/aws\/emr\/goodies\/lib\/emr-spark-goodies.jar:\/docker\/usr\/share\/aws\/emr\/security\/conf:\/docker\/usr\/share\/aws\/emr\/security\/lib\/*:\/docker\/usr\/share\/aws\/hmclient\/lib\/aws-glue-datacatalog-spark-client.jar:\/docker\/usr\/share\/java\/Hive-JSON-Serde\/hive-openx-serde.jar:\/docker\/usr\/share\/aws\/sagemaker-spark-sdk\/lib\/sagemaker-spark-sdk.jar:\/docker\/usr\/share\/aws\/emr\/s3select\/lib\/emr-s3-select-spark-connector.jar
    spark.executor.extraLibraryPath \/usr\/lib\/hadoop\/lib\/native:\/usr\/lib\/hadoop-lzo\/lib\/native:\/docker\/usr\/lib\/hadoop\/lib\/native:\/docker\/usr\/lib\/hadoop-lzo\/lib\/native
    spark.kubernetes.driver.internalPodTemplateFile \/etc\/spark\/conf\/driver-internal-pod.yaml
    spark.resourceManager.cleanupExpiredHost true
    spark.hadoop.mapreduce.fileoutputcommitter.algorithm.version.emr_internal_use_only.EmrFileSystem 2
    spark.kubernetes.executor.container.allowlistFile \/etc\/spark\/conf\/executor-pod-template-container-allowlist.txt
    spark.kubernetes.executor.container.image 996579266876.dkr.ecr.ap-northeast-2.amazonaws.com\/spark\/emr-6.8.0:latest
    spark.history.fs.logDirectory file:\/\/\/var\/log\/spark\/apps
    spark.kubernetes.pyspark.pythonVersion 3
    spark.driver.memory 1G
    spark.master k8s:\/\/https:\/\/kubernetes.default.svc:443
    spark.sql.emr.internal.extensions com.amazonaws.emr.spark.EmrSparkSessionExtensions
    spark.driver.cores 1
    spark.kubernetes.driver.container.image 996579266876.dkr.ecr.ap-northeast-2.amazonaws.com\/spark\/emr-6.8.0:latest
    spark.driver.extraLibraryPath \/usr\/lib\/hadoop\/lib\/native:\/usr\/lib\/hadoop-lzo\/lib\/native:\/docker\/usr\/lib\/hadoop\/lib\/native:\/docker\/usr\/lib\/hadoop-lzo\/lib\/native
    spark.kubernetes.executor.podTemplateContainerName spark-kubernetes-executor
    spark.kubernetes.driver.podTemplateValidation.enabled true
    spark.kubernetes.driver.pod.allowlistFile \/etc\/spark\/conf\/driver-pod-template-pod-allowlist.txt
    spark.history.ui.port 18080
    spark.hadoop.fs.s3.customAWSCredentialsProvider com.amazonaws.auth.WebIdentityTokenCredentialsProvider
    spark.blacklist.decommissioning.timeout 1h
    spark.driver.defaultJavaOptions -XX:OnOutOfMemoryError='kill -9 %p' -XX:+UseParallelGC -XX:InitiatingHeapOccupancyPercent=70
    spark.hadoop.fs.defaultFS file:\/\/\/
    spark.files.fetchFailure.unRegisterOutputOnHost true
    spark.dynamicAllocation.enabled false
    spark.kubernetes.container.image.pullPolicy Always
    spark.kubernetes.driver.podTemplateContainerName spark-kubernetes-driver
    spark.eventLog.logBlockUpdates.enabled true
    spark.driver.extraClassPath \/usr\/lib\/hadoop-lzo\/lib\/*:\/usr\/lib\/hadoop\/hadoop-aws.jar:\/usr\/share\/aws\/aws-java-sdk\/*:\/usr\/share\/aws\/emr\/emrfs\/conf:\/usr\/share\/aws\/emr\/emrfs\/lib\/*:\/usr\/share\/aws\/emr\/emrfs\/auxlib\/*:\/usr\/share\/aws\/emr\/goodies\/lib\/emr-spark-goodies.jar:\/usr\/share\/aws\/emr\/security\/conf:\/usr\/share\/aws\/emr\/security\/lib\/*:\/usr\/share\/aws\/hmclient\/lib\/aws-glue-datacatalog-spark-client.jar:\/usr\/share\/java\/Hive-JSON-Serde\/hive-openx-serde.jar:\/usr\/share\/aws\/sagemaker-spark-sdk\/lib\/sagemaker-spark-sdk.jar:\/usr\/share\/aws\/emr\/s3select\/lib\/emr-s3-select-spark-connector.jar:\/docker\/usr\/lib\/hadoop-lzo\/lib\/*:\/docker\/usr\/lib\/hadoop\/hadoop-aws.jar:\/docker\/usr\/share\/aws\/aws-java-sdk\/*:\/docker\/usr\/share\/aws\/emr\/emrfs\/conf:\/docker\/usr\/share\/aws\/emr\/emrfs\/lib\/*:\/docker\/usr\/share\/aws\/emr\/emrfs\/auxlib\/*:\/docker\/usr\/share\/aws\/emr\/goodies\/lib\/emr-spark-goodies.jar:\/docker\/usr\/share\/aws\/emr\/security\/conf:\/docker\/usr\/share\/aws\/emr\/security\/lib\/*:\/docker\/usr\/share\/aws\/hmclient\/lib\/aws-glue-datacatalog-spark-client.jar:\/docker\/usr\/share\/java\/Hive-JSON-Serde\/hive-openx-serde.jar:\/docker\/usr\/share\/aws\/sagemaker-spark-sdk\/lib\/sagemaker-spark-sdk.jar:\/docker\/usr\/share\/aws\/emr\/s3select\/lib\/emr-s3-select-spark-connector.jar
    spark.executor.defaultJavaOptions -verbose:gc -XX:+PrintGCDetails -XX:+PrintGCDateStamps -XX:+UseParallelGC -XX:InitiatingHeapOccupancyPercent=70 -XX:OnOutOfMemoryError='kill -9 %p'
    spark.kubernetes.namespace emr-cli
    spark.stage.attempt.ignoreOnDecommissionFetchFailure true
    spark.hadoop.fs.s3.getObject.initialSocketTimeoutMilliseconds 2000
    spark.kubernetes.executor.internalPodTemplateContainerName spark-kubernetes-executor
    spark.kubernetes.driver.container.allowlistFile \/etc\/spark\/conf\/driver-pod-template-container-allowlist.txt
    spark.kubernetes.executor.pod.allowlistFile \/etc\/spark\/conf\/executor-pod-template-pod-allowlist.txt
    spark.eventLog.dir file:\/\/\/var\/log\/spark\/apps
    spark.sql.parquet.fs.optimized.committer.optimization-enabled true
    spark.executor.memory 1G
    spark.hadoop.mapreduce.fileoutputcommitter.cleanup-failures.ignored.emr_internal_use_only.EmrFileSystem true
    spark.kubernetes.executor.internalPodTemplateFile \/etc\/spark\/conf\/executor-internal-pod.yaml
    spark.decommissioning.timeout.threshold 20
    spark.executor.cores 1
    spark.hadoop.dynamodb.customAWSCredentialsProvider com.amazonaws.auth.WebIdentityTokenCredentialsProvider
    spark.kubernetes.driver.internalPodTemplateContainerName spark-kubernetes-driver
    spark.submit.deployMode cluster
    spark.authenticate true
    spark.blacklist.decommissioning.enabled true
    spark.eventLog.enabled true
    spark.shuffle.service.enabled false
    spark.sql.parquet.output.committer.class com.amazon.emr.committer.EmrOptimizedSparkSqlParquetOutputCommitter
kind: ConfigMap
metadata:
  creationTimestamp: "2024-01-11T13:12:38Z"
  labels:
    emr-containers.amazonaws.com/job.configuration: spark-defaults
    emr-containers.amazonaws.com/job.id: 0000000337okspsc913
    emr-containers.amazonaws.com/virtual-cluster-id: jk518skp01ys9ka8b0npx9nt0
  name: 0000000337okspsc913-spark-defaults
  namespace: emr-cli
  ownerReferences:
  - apiVersion: batch/v1
    blockOwnerDeletion: true
    controller: true
    kind: Job
    name: 0000000337okspsc913
    uid: 77ead808-24e6-4c20-b02b-1b6db154674f
  resourceVersion: "68634058"
  uid: 14325ad5-cd76-4b32-98f4-599ee07be86f
```

The spark-submit CLI inside job-runner Pod obtains various configuration information needed for Spark Job creation through ConfigMap-based Files attached to job-runner Pod. ConfigMaps are created by AWS EMR before job-runner Pod is created, according to StartJobRun API settings. Configuration information includes settings related to Driver Pod and Executor Pod. When [Shell 1] command is executed, 3 ConfigMaps [File 1], [File 2], [File 3] are created.

[File 1] is the spark-defaults.conf ConfigMap for passing Spark Job settings to spark-submit CLI, [File 2] is the ConfigMap for Pod Template to be passed to spark-submit CLI, and [File 3] is the ConfigMap for fluentd to be set in Driver Pod. When Spark Jobs are submitted through StartJobRun API, fluentd Sidecar Container is always created in Driver Pod. The reason is that spark-submit CLI creates fluentd Container as Driver's Sidecar Container through spark-submit CLI's Pod Template functionality using [File 1], [File 2], [File 3] ConfigMaps.

Looking at [File 3] fluentd ConfigMap settings, you can see that Event Logs generated from Driver Pod are stored in `prod.ap-northeast-2.appinfo.src` Bucket. `appinfo.src` Bucket is a Bucket managed by AWS EMR, and is integrated with Spark History Server managed by EMR, allowing users to check History of Spark Jobs submitted through SparkJobRun API. Of course, it is also possible to set Event Logs to be stored at a path desired by users by specifying `--conf spark.eventLog.dir=s3a://[s3-bucket]` setting.

```yaml {caption="[File 2] Pod Template ConfigMap", linenos=table}
apiVersion: v1
data:
  driver: |-
    apiVersion: v1
    kind: Pod
    metadata:
      ownerReferences:
      - apiVersion: batch/v1
        blockOwnerDeletion: true
        controller: true
        kind: ConfigMap
        name: 0000000337omlr0m19o-spark-defaults
        uid: cfa61687-9915-4966-a02c-ead252e87f8a
    spec:
      serviceAccountName: emr-containers-sa-spark-driver-[account-id]-j3uv6jk0kk3sogu231qj91fmo3mvwfl561
      volumes:
        - name: emr-container-communicate
          emptyDir: {}
        - name: config-volume
          configMap:
            name: fluentd-jk518skp01ys9ka8b0npx9nt0-0000000337omlr0m19o
        - name: emr-container-s3
          secret:
            secretName: emr-containers-s3-jk518skp01ys9ka8b0npx9nt0-0000000337omlr0m19o
        - name: emr-container-application-log-dir
          emptyDir: {}
        - name: emr-container-event-log-dir
          emptyDir: {}
        - name: temp-data-dir
          emptyDir: {}
        - name: mnt-dir
          emptyDir: {}
        - name: home-dir
          emptyDir: {}
        - name: 0000000337omlr0m19o-spark-defaults
          configMap:
            name: 0000000337omlr0m19o-spark-defaults
      securityContext:
        fsGroup: 65534
      containers:
        - name: spark-kubernetes-driver
          image: 996579266876.dkr.ecr.ap-northeast-2.amazonaws.com/spark/emr-6.8.0:latest
          imagePullPolicy: Always
          securityContext:
            runAsNonRoot: true
            runAsUser: 999
            runAsGroup: 1000
            privileged: false
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
          volumeMounts:
            - name: emr-container-communicate
              mountPath: /var/log/fluentd
              readOnly: false
            - name: emr-container-application-log-dir
              mountPath: /var/log/spark/user
              readOnly: false
            - name: emr-container-event-log-dir
              mountPath: /var/log/spark/apps
              readOnly: false
            - name: temp-data-dir
              mountPath: /tmp
              readOnly: false
            - name: mnt-dir
              mountPath: /mnt
              readOnly: false
            - name: home-dir
              mountPath: /home/hadoop
              readOnly: false
            - name: 0000000337omlr0m19o-spark-defaults
              mountPath: /usr/lib/spark/conf/spark-defaults.conf
              subPath: spark-defaults.conf
              readOnly: false
          env:
            - name: SPARK_CONTAINER_ID
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: SIDECAR_SIGNAL_FILE
              value: /var/log/fluentd/main-container-terminated
            - name: K8S_SPARK_LOG_ERROR_REGEX
              value: (Error|Exception|Fail)
            - name: TERMINATION_ERROR_LOG_FILE_PATH
              value: /var/log/spark/error.log
          terminationMessagePath: /var/log/spark/error.log
        - name: emr-container-fluentd
          securityContext:
            runAsNonRoot: true
            runAsUser: 999
            runAsGroup: 1000
            privileged: false
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
          image: 996579266876.dkr.ecr.ap-northeast-2.amazonaws.com/fluentd/emr-6.8.0:latest
          imagePullPolicy: Always
          resources:
            requests:
              memory: 200Mi
            limits:
              memory: 512Mi
          env:
            - name: SPARK_CONTAINER_ID
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: SPARK_ROLE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.labels['spark-role']
            - name: K8S_SPARK_LOG_URL_STDERR
              value: "/var/log/spark/user/$(SPARK_CONTAINER_ID)/stderr"
            - name: K8S_SPARK_LOG_URL_STDOUT
              value: "/var/log/spark/user/$(SPARK_CONTAINER_ID)/stdout"
            - name: SIDECAR_SIGNAL_FILE
              value: /var/log/fluentd/main-container-terminated
            - name: FLUENTD_CONF
              value: fluent.conf
            - name: K8S_SPARK_EVENT_LOG_DIR
              value: /var/log/spark/apps
            - name: AWS_REGION
              value: ap-northeast-2
            - name: RUBY_GC_HEAP_OLDOBJECT_LIMIT_FACTOR
              value: 0.9
          volumeMounts:
            - name: config-volume
              mountPath: /etc/fluent/fluent.conf
              subPath: driver
              readOnly: false
            - name: emr-container-s3
              mountPath: /var/emr-container/s3
              readOnly: true
            - name: emr-container-communicate
              mountPath: /var/log/fluentd
              readOnly: false
            - name: emr-container-application-log-dir
              mountPath: /var/log/spark/user
              readOnly: false
            - name: emr-container-event-log-dir
              mountPath: /var/log/spark/apps
              readOnly: false
            - name: temp-data-dir
              mountPath: /tmp
              readOnly: false
            - name: home-dir
              mountPath: /home/hadoop
              readOnly: false
  driver-container-allowlist: |-
    container.env
    container.envFrom
    container.name
    container.lifecycle
    container.livenessProbe
    container.readinessProbe
    container.resources
    container.startupProbe
    container.stdin
    container.stdinOnce
    container.terminationMessagePath
    container.terminationMessagePolicy
    container.tty
    container.volumeDevices
    container.volumeMounts
    container.workingDir
  driver-pod-allowlist: |-
    pod.apiVersion
    pod.kind
    pod.metadata
    pod.spec.activeDeadlineSeconds
    pod.spec.affinity
    pod.spec.containers
    pod.spec.enableServiceLinks
    pod.spec.ephemeralContainers
    pod.spec.hostAliases
    pod.spec.hostname
    pod.spec.imagePullSecrets
    pod.spec.initContainers
    pod.spec.nodeName
    pod.spec.nodeSelector
    pod.spec.overhead
    pod.spec.preemptionPolicy
    pod.spec.priority
    pod.spec.priorityClassName
    pod.spec.readinessGates
    pod.spec.restartPolicy
    pod.spec.runtimeClassName
    pod.spec.schedulerName
    pod.spec.subdomain
    pod.spec.terminationGracePeriodSeconds
    pod.spec.tolerations
    pod.spec.topologySpreadConstraints
    pod.spec.volumes
  executor: |
    apiVersion: v1
    kind: Pod

    spec:
      serviceAccountName: emr-containers-sa-spark-executor-[account-id]-j3uv6jk0kk3sogu231qj91fmo3mvwfl561
      volumes:
        - name: 0000000337omlr0m19o-spark-defaults
          configMap:
            name: 0000000337omlr0m19o-spark-defaults
        - name: emr-container-communicate
          emptyDir: {}
        - name: emr-container-application-log-dir
          emptyDir: {}
        - name: emr-container-event-log-dir
          emptyDir: {}
        - name: temp-data-dir
          emptyDir: {}
        - name: mnt-dir
          emptyDir: {}
        - name: home-dir
          emptyDir: {}
      securityContext:
        fsGroup: 65534
      containers:
        - name: spark-kubernetes-executor
          image: 996579266876.dkr.ecr.ap-northeast-2.amazonaws.com/spark/emr-6.8.0:latest
          imagePullPolicy: Always
          securityContext:
            runAsNonRoot: true
            runAsUser: 999
            runAsGroup: 1000
            privileged: false
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
          env:
            - name: SPARK_CONTAINER_ID
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: SIDECAR_SIGNAL_FILE
              value: /tmp/main-container-terminated
            - name: SIDECAR_ERROR_FOLDER_PATH
              value: /var/log/fluentd/fluentd-error/
            - name: EXEC_POD_CPU_REQUEST
              valueFrom:
                resourceFieldRef:
                  containerName: spark-kubernetes-executor
                  resource: requests.cpu
                  divisor: 1
            - name: EXEC_POD_CPU_LIMIT
              valueFrom:
                resourceFieldRef:
                  containerName: spark-kubernetes-executor
                  resource: limits.cpu
                  divisor: 1
            - name: EXEC_POD_MEM_REQUEST
              valueFrom:
                resourceFieldRef:
                  containerName: spark-kubernetes-executor
                  resource: requests.memory
                  divisor: 1
            - name: EXEC_POD_MEM_LIMIT
              valueFrom:
                resourceFieldRef:
                  containerName: spark-kubernetes-executor
                  resource: limits.memory
                  divisor: 1

          volumeMounts:
            - name: 0000000337omlr0m19o-spark-defaults
              mountPath: /usr/lib/spark/conf/spark-defaults.conf
              subPath: spark-defaults.conf
              readOnly: false
            - name: emr-container-communicate
              mountPath: /var/log/fluentd
              readOnly: false
            - name: emr-container-application-log-dir
              mountPath: /var/log/spark/user
              readOnly: false
            - name: emr-container-event-log-dir
              mountPath: /var/log/spark/apps
              readOnly: false
            - name: temp-data-dir
              mountPath: /tmp
              readOnly: false
            - name: mnt-dir
              mountPath: /mnt
              readOnly: false
            - name: home-dir
              mountPath: /home/hadoop
              readOnly: false
  executor-container-allowlist: |-
    container.env
    container.envFrom
    container.name
    container.lifecycle
    container.livenessProbe
    container.readinessProbe
    container.resources
    container.startupProbe
    container.stdin
    container.stdinOnce
    container.terminationMessagePath
    container.terminationMessagePolicy
    container.tty
    container.volumeDevices
    container.volumeMounts
    container.workingDir
  executor-pod-allowlist: |-
    pod.apiVersion
    pod.kind
    pod.metadata
    pod.spec.activeDeadlineSeconds
    pod.spec.affinity
    pod.spec.containers
    pod.spec.enableServiceLinks
    pod.spec.ephemeralContainers
    pod.spec.hostAliases
    pod.spec.hostname
    pod.spec.imagePullSecrets
    pod.spec.initContainers
    pod.spec.nodeName
    pod.spec.nodeSelector
    pod.spec.overhead
    pod.spec.preemptionPolicy
    pod.spec.priority
    pod.spec.priorityClassName
    pod.spec.readinessGates
    pod.spec.restartPolicy
    pod.spec.runtimeClassName
    pod.spec.schedulerName
    pod.spec.subdomain
    pod.spec.terminationGracePeriodSeconds
    pod.spec.tolerations
    pod.spec.topologySpreadConstraints
    pod.spec.volumes
kind: ConfigMap
metadata:
  creationTimestamp: "2024-01-11T13:28:12Z"
  labels:
    emr-containers.amazonaws.com/job.configuration: pod-template
    emr-containers.amazonaws.com/job.id: 0000000337omlr0m19o
    emr-containers.amazonaws.com/virtual-cluster-id: jk518skp01ys9ka8b0npx9nt0
  name: podtemplate-0000000337omlr0m19o
  namespace: emr-cli
  ownerReferences:
  - apiVersion: batch/v1
    blockOwnerDeletion: true
    controller: true
    kind: Job
    name: 0000000337omlr0m19o
    uid: 2bde5561-1ad4-46c2-9034-ae28d507746a
  resourceVersion: "68639522"
  uid: 1f139a71-51bf-4be3-a269-5971ee1aff66
```

```yaml {caption="[File 3] fluentd ConfigMap", linenos=table}
apiVersion: v1
data:
  driver: "<system>\n  workers 1\n</system>\n<worker 0>\n  <source>\n    tag emr-containers-spark-s3-event-logs\n
    \   @label @emr-containers-spark-s3-event-logs\n    @type tail\n    path \"#{ENV['K8S_SPARK_EVENT_LOG_DIR']}/#{ENV['SPARK_APPLICATION_ID']}.inprogress,#{ENV['K8S_SPARK_EVENT_LOG_DIR']}/eventlog_v2_#{ENV['SPARK_APPLICATION_ID']}/#{ENV['SPARK_APPLICATION_ID']}.inprogress\"\n
    \   pos_file \"/tmp/fluentd/event-logs/in-tail.pos\"\n    read_from_head true\n
    \   refresh_interval 30\n    <parse>\n      @type none\n    </parse>\n  </source>\n
    \ \n  <label @emr-containers-spark-s3-event-logs>\n    <match emr-containers-spark-s3-event-logs>\n
    \     @type s3\n      <refreshing_file_presigned_post>\n        presigned_post_path
    /var/emr-container/s3/presigned-post\n      </refreshing_file_presigned_post>\n
    \     s3_bucket prod.ap-northeast-2.appinfo.src\n      s3_region ap-northeast-2\n
    \     check_bucket false\n      check_apikey_on_start false\n      check_object
    false\n      path \"[account-id]/jk518skp01ys9ka8b0npx9nt0/jobs/0000000337olhmpguek/sparklogs/eventlog_v2_#{ENV['SPARK_APPLICATION_ID']}\"\n
    \     s3_object_key_format \"%{path}/events_%{index}_#{ENV['SPARK_APPLICATION_ID']}\"\n
    \     store_as text\n      storage_class STANDARD\n      overwrite true\n      format
    single_value\n      <buffer time>\n        @type file\n        path /tmp/fluentd/event-logs/out-s3-buffer*\n
    \       chunk_limit_size 32MB\n        flush_at_shutdown true\n        timekey
    30\n        timekey_wait 0\n        retry_timeout 30s\n        retry_type exponential_backoff\n
    \       retry_exponential_backoff_base 2\n        retry_wait 1s\n        retry_randomize
    true\n        disable_chunk_backup true\n        retry_max_times 5\n      </buffer>\n
    \     <secondary>\n        @type secondary_file\n        directory /var/log/fluentd/error/\n
    \       basename s3-event-error.log\n      </secondary>\n    </match>\n  </label>\n</worker>\n\n\n<worker
    0>\n  <source>\n    tag emr-containers-spark-s3-event-status-file\n    @label
    @emr-containers-spark-s3-event-status-file\n    @type exec\n    command echo \"
    \"\n    format none\n  </source>\n  \n  <label @emr-containers-spark-s3-event-status-file>\n
    \   <match emr-containers-spark-s3-event-status-file>\n      @type s3\n      <refreshing_file_presigned_post>\n
    \       presigned_post_path /var/emr-container/s3/presigned-post\n      </refreshing_file_presigned_post>\n
    \     s3_bucket prod.ap-northeast-2.appinfo.src\n      s3_region ap-northeast-2\n
    \     check_bucket false\n      check_apikey_on_start false\n      check_object
    false\n      path \"[account-id]/jk518skp01ys9ka8b0npx9nt0/jobs/0000000337olhmpguek/sparklogs/eventlog_v2_#{ENV['SPARK_APPLICATION_ID']}\"\n
    \     s3_object_key_format \"%{path}/appstatus_#{ENV['SPARK_APPLICATION_ID']}\"\n
    \     store_as text\n      storage_class STANDARD\n      overwrite true\n      format
    single_value\n      <buffer time>\n        @type file\n        path /tmp/fluentd/event-logs/appstatus/out-s3-buffer*\n
    \       chunk_limit_size 1MB\n        flush_mode immediate\n        flush_at_shutdown
    true\n        retry_timeout 30s\n        retry_type exponential_backoff\n        retry_exponential_backoff_base
    2\n        retry_wait 1s\n        retry_randomize true\n        disable_chunk_backup
    true\n        retry_max_times 5\n      </buffer>\n      <secondary>\n        @type
    secondary_file\n        directory /var/log/fluentd/error/\n        basename s3-appstatus-event-error.log\n
    \     </secondary>\n    </match>\n  </label>\n</worker>\n"
  fluentd-pod-metadata.conf: "<system>\n  workers 1\n</system>\n<worker 0>\n  <source>\n
    \   tag emr-containers-pod-metadata\n    @label @emr-containers-pod-metadata\n
    \   @type tail\n    path \"#{ENV['POD_METADATA_PATH']}\"\n    pos_file \"/tmp/emr-containers/pod-info-in-tail.pos\"\n
    \   read_from_head true\n    refresh_interval 120\n    <parse>\n      @type none\n
    \   </parse>\n  </source>\n  \n  <label @emr-containers-pod-metadata>\n    <match
    emr-containers-pod-metadata>\n      @type stdout\n      format single_value\n
    \     output_to_console true\n    </match>\n  </label>\n</worker>\n"
kind: ConfigMap
metadata:
  creationTimestamp: "2024-01-11T13:18:20Z"
  labels:
    emr-containers.amazonaws.com/job.configuration: fluentd
    emr-containers.amazonaws.com/job.id: 0000000337olhmpguek
    emr-containers.amazonaws.com/virtual-cluster-id: jk518skp01ys9ka8b0npx9nt0
  name: fluentd-jk518skp01ys9ka8b0npx9nt0-0000000337olhmpguek
  namespace: emr-cli
  ownerReferences:
  - apiVersion: batch/v1
    blockOwnerDeletion: true
    controller: true
    kind: Job
    name: 0000000337olhmpguek
    uid: 60039ac0-b461-4c93-8488-06a3fe711383
  resourceVersion: "68636201"
  uid: 683034ea-45a8-4e96-99ed-20ae01be2a2d
```

The spark-submit CLI inside job-runner Pod obtains various configuration information needed for Spark Job creation through ConfigMap-based Files attached to job-runner Pod. ConfigMaps are created by AWS EMR before job-runner Pod is created, according to StartJobRun API settings. Configuration information includes settings related to Driver Pod and Executor Pod. When [Shell 1] command is executed, 3 ConfigMaps [File 1], [File 2], [File 3] are created.

[File 1] is the spark-defaults.conf ConfigMap for passing Spark Job settings to spark-submit CLI, [File 2] is the ConfigMap for Pod Template to be passed to spark-submit CLI, and [File 3] is the ConfigMap for fluentd to be set in Driver Pod. When Spark Jobs are submitted through StartJobRun API, fluentd Sidecar Container is always created in Driver Pod. The reason is that spark-submit CLI creates fluentd Container as Driver's Sidecar Container through spark-submit CLI's Pod Template functionality using [File 1], [File 2], [File 3] ConfigMaps.

Looking at [File 3] fluentd ConfigMap settings, you can see that Event Logs generated from Driver Pod are stored in `prod.ap-northeast-2.appinfo.src` Bucket. `appinfo.src` Bucket is a Bucket managed by AWS EMR, and is integrated with Spark History Server managed by EMR, allowing users to check History of Spark Jobs submitted through SparkJobRun API. Of course, it is also possible to set Event Logs to be stored at a path desired by users by specifying `--conf spark.eventLog.dir=s3a://[s3-bucket]` setting.

```shell {caption="[Shell 2] aws CLI StartJobRun API with Logging Example"}
$ aws emr-containers start-job-run \
 --virtual-cluster-id jk518skp01ys9ka8b0npx9nt0 \
 --name=pi-logs \
 --region ap-northeast-2 \
 --execution-role-arn arn:aws:iam::[account-id]:role/ts-eks-emr-eks-emr-cli \
 --release-label emr-6.8.0-latest \
 --job-driver '{
     "sparkSubmitJobDriver":{
       "entryPoint": "local:///usr/lib/spark/examples/src/main/python/pi.py",
       "sparkSubmitParameters": "--conf spark.driver.cores=1 --conf spark.driver.memory=512M --conf spark.executor.instances=1 --conf spark.executor.memory=512M --conf spark.executor.cores=1"
     }
   }' \
 --configuration-overrides '{
     "monitoringConfiguration": {
       "persistentAppUI": "ENABLED",
       "cloudWatchMonitoringConfiguration": {
         "logGroupName": "spark-startjobrun",
         "logStreamNamePrefix": "pi-logs"
       },
       "s3MonitoringConfiguration": {
         "logUri": "s3://ssup2-spark/startjobrun/"
       }
     }
   }'
```

StartJobRun API also provides functionality to easily send stdout/stderr of job-runner, driver, executor Pods to CloudWatch or S3. [Shell 2] shows an example of submitting Spark Jobs through StartJobRun API using aws CLI with Logging settings. Compared to [Shell 1], you can see that `monitoringConfiguration` setting is added, and CloudWatch and S3 settings exist under it respectively.

```yaml {caption="[File 4] spark-default ConfigMap with Logging", linenos=table}
apiVersion: v1
data:
  spark-defaults.conf: |
    spark.kubernetes.executor.podTemplateValidation.enabled true
    spark.executor.extraClassPath \/usr\/lib\/hadoop-lzo\/lib\/*:\/usr\/lib\/hadoop\/hadoop-aws.jar:\/usr\/share\/aws\/aws-java-sdk\/*:\/usr\/share\/aws\/emr\/emrfs\/conf:\/usr\/share\/aws\/emr\/emrfs\/lib\/*:\/usr\/share\/aws\/emr\/emrfs\/auxlib\/*:\/usr\/share\/aws\/emr\/goodies\/lib\/emr-spark-goodies.jar:\/usr\/share\/aws\/emr\/security\/conf:\/usr\/share\/aws\/emr\/security\/lib\/*:\/usr\/share\/aws\/hmclient\/lib\/aws-glue-datacatalog-spark-client.jar:\/usr\/share\/java\/Hive-JSON-Serde\/hive-openx-serde.jar:\/usr\/share\/aws\/sagemaker-spark-sdk\/lib\/sagemaker-spark-sdk.jar:\/usr\/share\/aws\/emr\/s3select\/lib\/emr-s3-select-spark-connector.jar:\/docker\/usr\/lib\/hadoop-lzo\/lib\/*:\/docker\/usr\/lib\/hadoop\/hadoop-aws.jar:\/docker\/usr\/share\/aws\/aws-java-sdk\/*:\/docker\/usr\/share\/aws\/emr\/emrfs\/conf:\/docker\/usr\/share\/aws\/emr\/emrfs\/lib\/*:\/docker\/usr\/share\/aws\/emr\/emrfs\/auxlib\/*:\/docker\/usr\/share\/aws\/emr\/goodies\/lib\/emr-spark-goodies.jar:\/docker\/usr\/share\/aws\/emr\/security\/conf:\/docker\/usr\/share\/aws\/emr\/security\/lib\/*:\/docker\/usr\/share\/aws\/hmclient\/lib\/aws-glue-datacatalog-spark-client.jar:\/docker\/usr\/share\/java\/Hive-JSON-Serde\/hive-openx-serde.jar:\/docker\/usr\/share\/aws\/sagemaker-spark-sdk\/lib\/sagemaker-spark-sdk.jar:\/docker\/usr\/share\/aws\/emr\/s3select\/lib\/emr-s3-select-spark-connector.jar
    spark.executor.extraLibraryPath \/usr\/lib\/hadoop\/lib\/native:\/usr\/lib\/hadoop-lzo\/lib\/native:\/docker\/usr\/lib\/hadoop\/lib\/native:\/docker\/usr\/lib\/hadoop-lzo\/lib\/native
    spark.kubernetes.driver.internalPodTemplateFile \/etc\/spark\/conf\/driver-internal-pod.yaml
    spark.resourceManager.cleanupExpiredHost true
    spark.hadoop.mapreduce.fileoutputcommitter.algorithm.version.emr_internal_use_only.EmrFileSystem 2
    spark.kubernetes.executor.container.allowlistFile \/etc\/spark\/conf\/executor-pod-template-container-allowlist.txt
    spark.kubernetes.executor.container.image 996579266876.dkr.ecr.ap-northeast-2.amazonaws.com\/spark\/emr-6.8.0:latest
    spark.history.fs.logDirectory file:\/\/\/var\/log\/spark\/apps
    spark.kubernetes.pyspark.pythonVersion 3
    spark.driver.memory 1G
    spark.master k8s:\/\/https:\/\/kubernetes.default.svc:443
    spark.sql.emr.internal.extensions com.amazonaws.emr.spark.EmrSparkSessionExtensions
    spark.driver.cores 1
    spark.kubernetes.driver.container.image 996579266876.dkr.ecr.ap-northeast-2.amazonaws.com\/spark\/emr-6.8.0:latest
    spark.driver.extraLibraryPath \/usr\/lib\/hadoop\/lib\/native:\/usr\/lib\/hadoop-lzo\/lib\/native:\/docker\/usr\/lib\/hadoop\/lib\/native:\/docker\/usr\/lib\/hadoop-lzo\/lib\/native
    spark.kubernetes.executor.podTemplateContainerName spark-kubernetes-executor
    spark.kubernetes.driver.podTemplateValidation.enabled true
    spark.kubernetes.driver.pod.allowlistFile \/etc\/spark\/conf\/driver-pod-template-pod-allowlist.txt
    spark.history.ui.port 18080
    spark.hadoop.fs.s3.customAWSCredentialsProvider com.amazonaws.auth.WebIdentityTokenCredentialsProvider
    spark.blacklist.decommissioning.timeout 1h
    spark.driver.defaultJavaOptions -XX:OnOutOfMemoryError='kill -9 %p' -XX:+UseParallelGC -XX:InitiatingHeapOccupancyPercent=70
    spark.hadoop.fs.defaultFS file:\/\/\/
    spark.files.fetchFailure.unRegisterOutputOnHost true
    spark.dynamicAllocation.enabled false
    spark.kubernetes.container.image.pullPolicy Always
    spark.kubernetes.driver.podTemplateContainerName spark-kubernetes-driver
    spark.eventLog.logBlockUpdates.enabled true
    spark.driver.extraClassPath \/usr\/lib\/hadoop-lzo\/lib\/*:\/usr\/lib\/hadoop\/hadoop-aws.jar:\/usr\/share\/aws\/aws-java-sdk\/*:\/usr\/share\/aws\/emr\/emrfs\/conf:\/usr\/share\/aws\/emr\/emrfs\/lib\/*:\/usr\/share\/aws\/emr\/emrfs\/auxlib\/*:\/usr\/share\/aws\/emr\/goodies\/lib\/emr-spark-goodies.jar:\/usr\/share\/aws\/emr\/security\/conf:\/usr\/share\/aws\/emr\/security\/lib\/*:\/usr\/share\/aws\/hmclient\/lib\/aws-glue-datacatalog-spark-client.jar:\/usr\/share\/java\/Hive-JSON-Serde\/hive-openx-serde.jar:\/usr\/share\/aws\/sagemaker-spark-sdk\/lib\/sagemaker-spark-sdk.jar:\/usr\/share\/aws\/emr\/s3select\/lib\/emr-s3-select-spark-connector.jar:\/docker\/usr\/lib\/hadoop-lzo\/lib\/*:\/docker\/usr\/lib\/hadoop\/hadoop-aws.jar:\/docker\/usr\/share\/aws\/aws-java-sdk\/*:\/docker\/usr\/share\/aws\/emr\/emrfs\/conf:\/docker\/usr\/share\/aws\/emr\/emrfs\/lib\/*:\/docker\/usr\/share\/aws\/emr\/emrfs\/auxlib\/*:\/docker\/usr\/share\/aws\/emr\/goodies\/lib\/emr-spark-goodies.jar:\/docker\/usr\/share\/aws\/emr\/security\/conf:\/docker\/usr\/share\/aws\/emr\/security\/lib\/*:\/docker\/usr\/share\/aws\/hmclient\/lib\/aws-glue-datacatalog-spark-client.jar:\/docker\/usr\/share\/java\/Hive-JSON-Serde\/hive-openx-serde.jar:\/docker\/usr\/share\/aws\/sagemaker-spark-sdk\/lib\/sagemaker-spark-sdk.jar:\/docker\/usr\/share\/aws\/emr\/s3select\/lib\/emr-s3-select-spark-connector.jar
    spark.executor.defaultJavaOptions -verbose:gc -XX:+PrintGCDetails -XX:+PrintGCDateStamps -XX:+UseParallelGC -XX:InitiatingHeapOccupancyPercent=70 -XX:OnOutOfMemoryError='kill -9 %p'
    spark.kubernetes.namespace emr-cli
    spark.stage.attempt.ignoreOnDecommissionFetchFailure true
    spark.hadoop.fs.s3.getObject.initialSocketTimeoutMilliseconds 2000
    spark.kubernetes.executor.internalPodTemplateContainerName spark-kubernetes-executor
    spark.kubernetes.driver.container.allowlistFile \/etc\/spark\/conf\/driver-pod-template-container-allowlist.txt
    spark.kubernetes.executor.pod.allowlistFile \/etc\/spark\/conf\/executor-pod-template-pod-allowlist.txt
    spark.eventLog.dir file:\/\/\/var\/log\/spark\/apps
    spark.sql.parquet.fs.optimized.committer.optimization-enabled true
    spark.executor.memory 1G
    spark.hadoop.mapreduce.fileoutputcommitter.cleanup-failures.ignored.emr_internal_use_only.EmrFileSystem true
    spark.kubernetes.executor.internalPodTemplateFile \/etc\/spark\/conf\/executor-internal-pod.yaml
    spark.decommissioning.timeout.threshold 20
    spark.executor.cores 1
    spark.hadoop.dynamodb.customAWSCredentialsProvider com.amazonaws.auth.WebIdentityTokenCredentialsProvider
    spark.kubernetes.driver.internalPodTemplateContainerName spark-kubernetes-driver
    spark.submit.deployMode cluster
    spark.authenticate true
    spark.blacklist.decommissioning.enabled true
    spark.eventLog.enabled true
    spark.shuffle.service.enabled false
    spark.sql.parquet.output.committer.class com.amazon.emr.committer.EmrOptimizedSparkSqlParquetOutputCommitter
kind: ConfigMap
metadata:
  creationTimestamp: "2024-01-11T14:50:32Z"
  labels:
    emr-containers.amazonaws.com/job.configuration: spark-defaults
    emr-containers.amazonaws.com/job.id: 0000000337p03c0klg8
    emr-containers.amazonaws.com/virtual-cluster-id: jk518skp01ys9ka8b0npx9nt0
  name: 0000000337p03c0klg8-spark-defaults
  namespace: emr-cli
  ownerReferences:
  - apiVersion: batch/v1
    blockOwnerDeletion: true
    controller: true
    kind: Job
    name: 0000000337p03c0klg8
    uid: 8c0b0b0b-0b0b-0b0b-0b0b-0b0b0b0b0b0b
  resourceVersion: "68639522"
  uid: 1f139a71-51bf-4be3-a269-5971ee1aff66
```

When [Shell 2] command is executed, 3 ConfigMaps [File 4], [File 5], [File 6] are created. You can see that fluentd is configured to run not only in job-runner Pod but also in Driver Pod and Executor Pod, and fluentd running in Driver Pod and Executor Pod is configured to send stdout/stderr to CloudWatch or S3.

```shell {caption="[Shell 3] aws CLI StartJobRun API with Prometheus Monitoring"}
$ aws emr-containers start-job-run \
 --virtual-cluster-id jk518skp01ys9ka8b0npx9nt0 \
 --name=pi \
 --region ap-northeast-2 \
 --execution-role-arn arn:aws:iam::[account-id]:role/ts-eks-emr-eks-emr-cli \
 --release-label emr-6.8.0-latest \
 --job-driver '{
     "sparkSubmitJobDriver":{
       "entryPoint": "local:///usr/lib/spark/examples/src/main/python/pi.py",
       "sparkSubmitParameters": "--conf spark.executor.instances=2 --conf spark.executor.memory=2G --conf spark.executor.cores=1 --conf spark.driver.cores=1"
     }
   }' \
   --configuration-overrides '{
     "applicationConfiguration": [
       {
         "classification": "spark-defaults",
         "properties": {
           "job-start-timeout":"1800",
           "spark.ui.prometheus.enabled":"true",
           "spark.executor.processTreeMetrics.enabled":"true",
           "spark.kubernetes.driver.annotation.prometheus.io/scrape":"true",
           "spark.kubernetes.driver.annotation.prometheus.io/path":"/metrics/executors/prometheus/",
           "spark.kubernetes.driver.annotation.prometheus.io/port":"4040"
         }
       }
     ]
   }'
```

Through StartJobRun API, various settings that can be configured in spark-submit CLI can be set identically. [Shell 3] shows an example for performing Monitoring with Prometheus.

### 2.1. with ACK EMR Container Controller

{{< figure caption="[Figure 2] Spark on AWS EKS Architecture with ACK EMR Container Controller" src="images/spark-aws-eks-architecture-ack-emr-container-controller.png" width="1000px" >}}

AWS provides ACK EMR Container Controller to enable submitting Spark Jobs based on StartJobRun API using Kubernetes Objects. [Figure 2] shows the process of submitting Spark Jobs through StartJobRun API based on ACK EMR Container Controller.

When ACK EMR Container Controller is installed in AWS EKS Cluster, two Custom Resources `Virtual Cluster` and `Job Run` become available. `Virtual Cluster` is a Custom Resource used to configure Virtual Cluster of EMR on EKS for a specific Namespace of AWS EKS Cluster where ACK EMR Container Controller is installed, and `Job Run` is a Custom Resource used when submitting Spark Jobs through StartJobRun API.

```yaml {caption="[File 7] JobRun Example", linenos=table}
apiVersion: emrcontainers.services.k8s.aws/v1alpha1
kind: JobRun
metadata:
  name: pi
  namespace: emr-ack
spec:
  name: pi
  virtualClusterID: kkm9hr2cypco1341w5b0iwuaj
  executionRoleARN: "arn:aws:iam::[account-id]:role/ts-eks-emr-eks-emr-ack"
  releaseLabel: "emr-6.7.0-latest"
  jobDriver:
    sparkSubmitJobDriver:
      entryPoint: "local:///usr/lib/spark/examples/src/main/python/pi.py"
      entryPointArguments:
      sparkSubmitParameters: "--conf spark.executor.instances=2 --conf spark.executor.memory=2G --conf spark.executor.cores=1 --conf spark.driver.cores=1"
  configurationOverrides: |
    ApplicationConfiguration: null
    MonitoringConfiguration: null
```

```yaml {caption="[File 8] JobRun Example with Logging", linenos=table}
apiVersion: emrcontainers.services.k8s.aws/v1alpha1
kind: JobRun
metadata:
  name: pi-logs
  namespace: emr-ack
spec:
  name: pi-logs
  virtualClusterID: kkm9hr2cypco1341w5b0iwuaj
  executionRoleARN: "arn:aws:iam::[account-id]:role/ts-eks-emr-eks-emr-ack"
  releaseLabel: "emr-6.8.0-latest"
  jobDriver:
    sparkSubmitJobDriver:
      entryPoint: "local:///usr/lib/spark/examples/src/main/python/pi.py"
      entryPointArguments:
      sparkSubmitParameters: "--conf spark.driver.cores=1 --conf spark.driver.memory=512M --conf spark.executor.instances=1 --conf spark.executor.cores=1 --conf spark.executor.memory=512M"
  configurationOverrides: |
    MonitoringConfiguration:
      PersistentAppUI: "ENABLED"
      CloudWatchMonitoringConfiguration:
        LogGroupName: "spark-startjobrun"
        LogStreamNamePrefix: "pi-logs"
      S3MonitoringConfiguration:
        LogUri: "s3://ssup2-spark/startjobrun/"
```

[File 7] shows an example of a simple Job Run, and [File 8] shows an example of a Job Run with Logging settings applied. Looking at the configuration values, you can see that options set through aws CLI can be set identically in Job Run.

## 3. References

* EMR on EKS Container Image : [https://gallery.ecr.aws/emr-on-eks](https://gallery.ecr.aws/emr-on-eks)
* StartJobRun Parameter : [https://docs.aws.amazon.com/emr/latest/EMR-on-EKS-DevelopmentGuide/emr-eks-jobs-CLI.html#emr-eks-jobs-parameters](https://docs.aws.amazon.com/emr/latest/EMR-on-EKS-DevelopmentGuide/emr-eks-jobs-CLI.html#emr-eks-jobs-parameters)


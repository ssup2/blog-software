---
title: Spark on AWS EKS
---

AWS EKS Cluster에서 Spark Application 동작을 분석한다. AWS EKS Cluster에서 Spark Application을 동작시키기 위해서는 Spark에서 제공하는 spark-submit CLI 및 Spark Operator를 이용하는 방식과 EMR on EKS에서 제공하는 StartJobRun API를 이용하는 방식 2가지가 존재한다.

## 1. spark-submit CLI & Spark Operator

AWS EKS에서도 일반적인 Kubernetes Cluster처럼 spark-submit CLI 및 Spark Operator를 이용하여 Spark Application을 동작시킬 수 있다. 이 경우 Architecture 및 동작 방식은 다음의 [Link](https://ssup2.github.io/blog-software/docs/theory-analysis/spark-on-kubernetes/)의 내용처럼 일반적인 Kubernetes Cluster에서 spark-submit CLI 및 Spark Operator를 이용하는 방식과 동일하다.

다만 AWS EKS에서는 Driver, Executor Pod의 Container Image를 **EMR on EKS Spark Container Image**로 이용하는 것을 권장한다. EMR on EKS Spark Container Image에는 EKS 환경에 최적화된 Optimized Spark가 내장되어 있어 Open Source Spark 대비 더 빠른 성능을 보이며, 아래에 명시된 AWS와 연관된 Library 및 Spark Connector가 포함되어 있기 때문이다.

* EMRFS S3-optimized comitter
* AWS Redshift용 Spark Connector : Spark Application에서 AWS Redshift 접근시 이용
* AWS SageMaker용 Spark Library : Spark Application의 DataFrame에 저장되어 있는 Data를 바로 AWS SageMaker를 통해서 Training 수행 가능

EMR on EKS Spark Container Image는 [Public AWS ECR](https://gallery.ecr.aws/emr-on-eks)에 공개되어 있다. Spark Application에서 고유한 Library 및 Spark Connector를 이용하는 경우 Custom Container Image를 구축해야 하는데, 이 경우에도 EMR on EKS Spark Container Image를 Base Image로 이용하는 것을 권장한다.

## 2. StartJobRun API

StartJobRun API는 EMR on EKS 환경에서 Spark Job을 제출하는 API이다. StartJobRun API를 이용하기 위해서는 AWS EMR에서 관리하는 가상의 Resource인 **Virtual Cluster**를 생성해야 한다. Virtual Cluster를 생성하기 위해서는 EKS Cluster에 존재하는 하나의 Namespace가 필요하다. 하나의 EKS Cluster에 다수의 Namespace를 생성하고 다수의 Virtual Cluster를 각 Namespace에 Mapping하여 하나의 EKS Cluster에서 다수의 Virtual Cluster를 운영할 수 있다.

{{< figure caption="[Figure 1] Spark on AWS EKS Architecture with StartJobRun API" src="images/spark-aws-eks-architecture-startjobrun-api.png" width="1000px" >}}

[Figure 1]은 하나의 Virtual Cluster가 있는 EKS Cluster에 StartJobRun API를 통해서 Spark Job을 제출할 경우의 Architecture를 나타내고 있다. StartJobRun API를 호출하면 Virtual Cluster와 Mapping 되어 있는 Namespace에 job-runner Pod가 생성되며, job-runner Pod 내부에서 spark-submit CLI가 동작한다. 즉 **StartJobRun API 방식도 내부적으로는 spark-submit CLI를 이용**하여 Spark Job을 제출하는 방식이다.

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

[Shell 1]은 aws CLI를 활용하여 StartJobRun API를 통해서 Spark Job을 제출하는 예제를 나타내고 있다. Virtual Cluster, 제출한 Spark Job의 이름, AWS Region, Spark Job 실행을 위한 Role, Spark 관련 설정들이 명시되어 있는것을 확인할 수 있다. `sparkSubmitParameters` 항목에는 spark-submit CLI를 통해서 전달하는 `--conf` Parameter들이 설정되어 있는것도 확인할 수 있다.

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

job-runner Pod 내부의 spark-submit CLI는 job-runner Pod에 붙는 ConfigMap 기반의 File을 통해서 Spark Job 생성에 필요한 각종 설정 정보들을 얻는다. ConfigMap은 StartJobRun API의 설정에 따라서 AWS EMR에서 job-runner Pod가 생성 되기전에 생성된다. 설정 정보에는 Driver Pod, Executor Pod 관련 설정들이 포함되어 있다. [Shell 1] 명령어를 실행하면 [File 1], [File 2], [File 3] 3개의 ConfigMap이 생성된다.

[File 1]은 spark-submit CLI에게 Spark Job 설정을 전달하기 위한 spark-defauls.conf ConfigMap, [File 2]는 spark-submit CLI에게 전달하기 위한 Pod Template을 위한 ConfigMap, [File 3]은 Driver Pod에 설정되는 fluentd를 위한 ConfigMap을 나타내고 있다. StartJobRun API를 통해서 Spark Job을 제출하면 Driver Pod에는 반드시 fluentd Sidecar Container가 생성이 된다. 이유는 spark-submit CLI가 [File 1], [File 2], [File 3] ConfigMap을 통해서 spark-submit CLI의 Pod Template 기능을 통해서 fluentd Container를 Driver의 Sidecar Container로 생성하기 때문이다.

[File 3] fluentd ConfigMap의 설정을 살펴보면 `prod.ap-northeast-2.appinfo.src` Bucket에 Driver Pod에서 발생하는 Event Log를 저장하는 것을 확인할 수 있다. `appinfo.src` Bucket은 AWS EMR에서 관리하는 Bucket이며, EMR이 관리하는 Spark History Server와 연동되어 사용자에게 SparkJobRun API를 통해서 제출된 Spark Job의 History를 확인할 수 있게 설정된다. 물론 `--conf spark.eventLog.dir=s3a://][s3-bucket]` 설정을 명시하여 사용자가 원하는 경로에 Event Log를 적제하도록 설정도 가능하다.

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

StartJobRun API는 job-runner, driver, executor Pod의 stdout/stderr를 CloudWatch 또는 S3에 간편하게 전송해주는 기능도 제공하고 있다. [Shell 2]는 Logging 설정과 함께 aws CLI를 통해서 StartJobRun API를 통해서 Spark Job을 제출하는 예제를 나타내고 있다. [Shell 1]과 비교하면 `monitoringConfigruation` 설정이 추가된 것을 확인할 수 있으며 하위에 CloudWatch와 S3 설정이 각각 존재하는것을 확인할 수 있다.

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
    uid: a0b14577-fe4f-4611-bd64-b45e9e898bb1
  resourceVersion: "68662395"
  uid: eb522369-1639-443b-a279-8e901d48b4ac
```

```yaml {caption="[File 5] Pod Template ConfigMap with Logging", linenos=table}
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
        name: 0000000337p03c0klg8-spark-defaults
        uid: eb522369-1639-443b-a279-8e901d48b4ac
    spec:
      serviceAccountName: emr-containers-sa-spark-driver-[account-id]-j3uv6jk0kk3sogu231qj91fmo3mvwfl561
      volumes:
        - name: emr-container-communicate
          emptyDir: {}
        - name: config-volume
          configMap:
            name: fluentd-jk518skp01ys9ka8b0npx9nt0-0000000337p03c0klg8
        - name: emr-container-s3
          secret:
            secretName: emr-containers-s3-jk518skp01ys9ka8b0npx9nt0-0000000337p03c0klg8
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
        - name: 0000000337p03c0klg8-spark-defaults
          configMap:
            name: 0000000337p03c0klg8-spark-defaults
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
            - name: 0000000337p03c0klg8-spark-defaults
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
            - name: K8S_SPARK_LOG_URL_STDOUT
              value: "/var/log/spark/user/$(SPARK_CONTAINER_ID)/stdout"
            - name: K8S_SPARK_LOG_URL_STDERR
              value: "/var/log/spark/user/$(SPARK_CONTAINER_ID)/stderr"
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
  executor: "apiVersion: v1\nkind: Pod\n\nspec:\n  serviceAccountName: emr-containers-sa-spark-executor-[account-id]-j3uv6jk0kk3sogu231qj91fmo3mvwfl561\n
    \ volumes:\n    - name: emr-container-communicate\n      emptyDir: {}\n    - name:
    config-volume\n      configMap:\n        name: fluentd-jk518skp01ys9ka8b0npx9nt0-0000000337p03c0klg8\n
    \   \n    - name: emr-container-application-log-dir\n      emptyDir: {}\n    -
    name: temp-data-dir\n      emptyDir: {}\n    - name: mnt-dir\n      emptyDir:
    {}\n    - name: home-dir\n      emptyDir: {}\n    - name: 0000000337p03c0klg8-spark-defaults\n
    \     configMap:\n        name: 0000000337p03c0klg8-spark-defaults\n  securityContext:\n
    \   fsGroup: 65534\n  containers:\n    - name: spark-kubernetes-executor\n      image:
    996579266876.dkr.ecr.ap-northeast-2.amazonaws.com/spark/emr-6.8.0:latest\n      imagePullPolicy:
    Always\n      securityContext:\n        runAsNonRoot: true\n        runAsUser:
    999\n        runAsGroup: 1000\n        privileged: false\n        allowPrivilegeEscalation:
    false\n        readOnlyRootFilesystem: true\n        capabilities:\n          drop:
    [\"ALL\"]\n      volumeMounts:\n        - name: emr-container-communicate\n          mountPath:
    /var/log/fluentd\n          readOnly: false\n        - name: emr-container-application-log-dir\n
    \         mountPath: /var/log/spark/user\n          readOnly: false\n        -
    name: temp-data-dir\n          mountPath: /tmp\n          readOnly: false\n        -
    name: mnt-dir\n          mountPath: /mnt\n          readOnly: false\n        -
    name: home-dir\n          mountPath: /home/hadoop\n          readOnly: false\n
    \       - name: 0000000337p03c0klg8-spark-defaults\n          mountPath: /usr/lib/spark/conf/spark-defaults.conf\n
    \         subPath: spark-defaults.conf\n          readOnly: false\n      env:\n
    \       - name: SPARK_CONTAINER_ID\n          valueFrom:\n            fieldRef:\n
    \             fieldPath: metadata.name\n        - name: K8S_SPARK_LOG_URL_STDERR\n
    \         value: \"/var/log/spark/user/$(SPARK_CONTAINER_ID)/stderr\"\n        -
    name: K8S_SPARK_LOG_URL_STDOUT\n          value: \"/var/log/spark/user/$(SPARK_CONTAINER_ID)/stdout\"\n
    \       - name: SIDECAR_SIGNAL_FILE\n          value: /var/log/fluentd/main-container-terminated\n
    \       - name: EXEC_POD_CPU_REQUEST\n          valueFrom:\n            resourceFieldRef:\n
    \             containerName: spark-kubernetes-executor\n              resource:
    requests.cpu\n              divisor: 1\n        - name: EXEC_POD_CPU_LIMIT\n          valueFrom:\n
    \           resourceFieldRef:\n              containerName: spark-kubernetes-executor\n
    \             resource: limits.cpu\n              divisor: 1\n        - name:
    EXEC_POD_MEM_REQUEST\n          valueFrom:\n            resourceFieldRef:\n              containerName:
    spark-kubernetes-executor\n              resource: requests.memory\n              divisor:
    1\n        - name: EXEC_POD_MEM_LIMIT\n          valueFrom:\n            resourceFieldRef:\n
    \             containerName: spark-kubernetes-executor\n              resource:
    limits.memory\n              divisor: 1\n        - name: SPARK_LOG_URL_STDERR\n
    \         value: \"https://s3.console.aws.amazon.com/s3/object/ssup2-spark/startjobrun/jk518skp01ys9ka8b0npx9nt0/jobs/0000000337p03c0klg8/containers/$(SPARK_APPLICATION_ID)/$(SPARK_CONTAINER_ID)/stderr.gz\"\n
    \       - name: SPARK_LOG_URL_STDOUT\n          value: \"https://s3.console.aws.amazon.com/s3/object/ssup2-spark/startjobrun/jk518skp01ys9ka8b0npx9nt0/jobs/0000000337p03c0klg8/containers/$(SPARK_APPLICATION_ID)/$(SPARK_CONTAINER_ID)/stdout.gz\"\n
    \       - name: SPARK_EXECUTOR_ATTRIBUTE_CONTAINER_ID\n          value: \"$(SPARK_CONTAINER_ID)\"\n
    \       - name: SPARK_EXECUTOR_ATTRIBUTE_LOG_FILES\n          value: \"stderr,stdout\"\n\n
    \   - name: emr-container-fluentd\n      securityContext:\n        runAsNonRoot:
    true\n        runAsUser: 999\n        runAsGroup: 1000\n        privileged: false\n
    \       allowPrivilegeEscalation: false\n        readOnlyRootFilesystem: true\n
    \       capabilities:\n          drop: [\"ALL\"]\n      image: 996579266876.dkr.ecr.ap-northeast-2.amazonaws.com/fluentd/emr-6.8.0:latest\n
    \     imagePullPolicy: Always\n      resources:\n        requests:\n          memory:
    200Mi\n        limits:\n          memory: 512Mi\n      env:\n        - name: SPARK_CONTAINER_ID\n
    \         valueFrom:\n            fieldRef:\n              fieldPath: metadata.name\n
    \       - name: SPARK_ROLE\n          valueFrom:\n            fieldRef:\n              fieldPath:
    metadata.labels['spark-role']\n        - name: K8S_SPARK_LOG_URL_STDERR\n          value:
    \"/var/log/spark/user/$(SPARK_CONTAINER_ID)/stderr\"\n        - name: K8S_SPARK_LOG_URL_STDOUT\n
    \         value: \"/var/log/spark/user/$(SPARK_CONTAINER_ID)/stdout\"\n        -
    name: SIDECAR_SIGNAL_FILE\n          value: /var/log/fluentd/main-container-terminated\n
    \       - name: FLUENTD_CONF\n          value: fluent.conf\n        - name: AWS_REGION\n
    \         value: ap-northeast-2\n        - name: RUBY_GC_HEAP_OLDOBJECT_LIMIT_FACTOR\n
    \         value: 0.9\n      volumeMounts:\n        - name: config-volume\n          mountPath:
    /etc/fluent/fluent.conf\n          subPath: executor\n          readOnly: false\n
    \       \n        - name: emr-container-communicate\n          mountPath: /var/log/fluentd\n
    \         readOnly: false\n        - name: emr-container-application-log-dir\n
    \         mountPath: /var/log/spark/user\n          readOnly: false\n        -
    name: temp-data-dir\n          mountPath: /tmp\n          readOnly: false\n        -
    name: home-dir\n          mountPath: /home/hadoop\n          readOnly: false"
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
  validation-script: |-
    #!/usr/bin/python3

    import boto3
    import os
    import time
    import json
    import logging

    class UploadJobMetadata(object):
        LOGGING_BUCKET_NAME_ENV = 'LOGGING_BUCKET_NAME'
        CLOUDWATCH_LOG_GROUP_NAME_ENV = 'CW_LOG_GROUP_NAME'
        S3_UPLOAD_PATH_ENV = 'JOB_METADATA_UPLOAD_S3_PATH'
        CW_UPLOAD_STREAM_ENV = 'JOB_METADATA_CW_LOG_STREAM_NAME'

        def get_role_credentials(self):
            role_arn = os.getenv('AWS_ROLE_ARN')
            token_file = os.getenv('AWS_WEB_IDENTITY_TOKEN_FILE')
            aws_region = os.getenv('AWS_REGION')
            sts_endpoint_url = os.getenv('STS_ENDPOINT_URL')

            token_file_obj = open(token_file, 'r')
            token = token_file_obj.read()

            sts_client = boto3.client('sts', region_name=aws_region, endpoint_url=sts_endpoint_url)
            return sts_client.assume_role_with_web_identity(RoleArn=role_arn,
                                                            WebIdentityToken=token,
                                                            RoleSessionName='emr-containers')

        def generate_job_metadata(self, region):
            s3_path = os.getenv(self.S3_UPLOAD_PATH_ENV)
            log_stream_name = os.getenv(self.CW_UPLOAD_STREAM_ENV)

            job_metadata = {'region': region, 'job_id': os.getenv('JOB_ID')}
            if s3_path is not None:
                job_metadata['logging_bucket_name'] = os.getenv(self.LOGGING_BUCKET_NAME_ENV)
                job_metadata['logging_s3_metadata_path'] = s3_path

            if log_stream_name is not None:
                job_metadata['cloudwatch_log_group_name'] = os.getenv(self.CLOUDWATCH_LOG_GROUP_NAME_ENV)
                job_metadata['cloudwatch_log_metadata_stream'] = log_stream_name

            return json.dumps(job_metadata)

        def upload_job_metadata_to_s3(self, job_metadata, region, creds):
            local_file_name = '/tmp/job-metadata.log'
            local_file_obj = open(local_file_name, 'w')
            local_file_obj.write(job_metadata)
            local_file_obj.close()

            bucket_name = os.getenv(self.LOGGING_BUCKET_NAME_ENV)
            s3_path = os.getenv(self.S3_UPLOAD_PATH_ENV)

            aws_access_key_id = creds['Credentials']['AccessKeyId']
            aws_secret_access_key = creds['Credentials']['SecretAccessKey']
            aws_session_token = creds['Credentials']['SessionToken']

            s3_client = boto3.client('s3',
                                     region_name=region,
                                     aws_access_key_id=aws_access_key_id,
                                     aws_secret_access_key=aws_secret_access_key,
                                     aws_session_token=aws_session_token)

            s3_client.upload_file(local_file_name, bucket_name, s3_path)
            s3_client.download_file(bucket_name, s3_path, local_file_name)

        def upload_job_metadata_to_cw(self, job_metadata, region, creds):
            log_group_name = os.getenv(self.CLOUDWATCH_LOG_GROUP_NAME_ENV)
            log_stream_name = os.getenv(self.CW_UPLOAD_STREAM_ENV)

            aws_access_key_id = creds['Credentials']['AccessKeyId']
            aws_secret_access_key = creds['Credentials']['SecretAccessKey']
            aws_session_token = creds['Credentials']['SessionToken']

            logs_client = boto3.client('logs',
                                       region_name=region,
                                       aws_access_key_id=aws_access_key_id,
                                       aws_secret_access_key=aws_secret_access_key,
                                       aws_session_token=aws_session_token)

            log_groups = logs_client.describe_log_groups(logGroupNamePrefix=log_group_name)
            if len(list(filter(lambda x: x['logGroupName'] == log_group_name, log_groups['logGroups']))) == 0:
                logs_client.create_log_group(logGroupName=log_group_name)

            log_streams = logs_client.describe_log_streams(logGroupName=log_group_name, logStreamNamePrefix=log_stream_name)
            log_stream = list(filter(lambda x: x['logStreamName'] == log_stream_name, log_streams['logStreams']))
            if len(log_stream) == 0:
                logs_client.create_log_stream(logGroupName=log_group_name, logStreamName=log_stream_name)
                self.put_log_event(logs_client, log_group_name, log_stream_name, job_metadata)
            else:
                if 'uploadSequenceToken' not in log_stream[0]:
                    self.put_log_event(logs_client, log_group_name, log_stream_name, job_metadata)
                else:
                    upload_token = log_stream[0]['uploadSequenceToken']
                    self.put_log_event_with_upload_token(logs_client, log_group_name, log_stream_name, upload_token, job_metadata)

        def put_log_event(self, logs_client, log_group_name, log_stream_name, job_metadata):
            logs_client.put_log_events(logGroupName=log_group_name, logStreamName=log_stream_name, logEvents=[
                {
                    'timestamp': round(time.time() * 1000),
                    'message': job_metadata
                }
            ])

        def put_log_event_with_upload_token(self, logs_client, log_group_name, log_stream_name, upload_token, job_metadata):
            logs_client.put_log_events(logGroupName=log_group_name, logStreamName=log_stream_name, logEvents=[
                {
                    'timestamp': round(time.time() * 1000),
                    'message': job_metadata
                }
            ], sequenceToken = upload_token)

        def run(self):
            region = os.getenv('AWS_REGION')
            job_metadata = self.generate_job_metadata(region)

            creds = None
            s3_path = os.getenv(self.S3_UPLOAD_PATH_ENV)
            if s3_path is not None:
                creds = self.get_role_credentials()
                self.upload_job_metadata_to_s3(job_metadata, region, creds)

            log_stream_name = os.getenv(self.CW_UPLOAD_STREAM_ENV)
            if log_stream_name is not None:
                if creds is None:
                    creds = self.get_role_credentials()

                self.upload_job_metadata_to_cw(job_metadata, region, creds)

    if __name__ == "__main__":
        UploadJobMetadata().run()
kind: ConfigMap
metadata:
  creationTimestamp: "2024-01-11T14:50:32Z"
  labels:
    emr-containers.amazonaws.com/job.configuration: pod-template
    emr-containers.amazonaws.com/job.id: 0000000337p03c0klg8
    emr-containers.amazonaws.com/virtual-cluster-id: jk518skp01ys9ka8b0npx9nt0
  name: podtemplate-0000000337p03c0klg8
  namespace: emr-cli
  ownerReferences:
  - apiVersion: batch/v1
    blockOwnerDeletion: true
    controller: true
    kind: Job
    name: 0000000337p03c0klg8
    uid: a0b14577-fe4f-4611-bd64-b45e9e898bb1
  resourceVersion: "68662402"
  uid: b9903ad0-e49c-43e3-9d8d-e004a050f051
```

```yaml {caption="[File 6] fluentd ConfigMap with Logging", linenos=table}
apiVersion: v1
data:
  driver: "<system>\n  workers 3\n</system>\n<worker 0>\n  <source>\n    tag chicago-spark-stdout\n
    \   @label @chicago-spark-stdout\n    @type tail\n    path \"#{ENV['K8S_SPARK_LOG_URL_STDOUT']}\"\n
    \   pos_file \"#{ENV['K8S_SPARK_LOG_URL_STDOUT']}-in-tail.pos\"\n    read_from_head
    true\n    <parse>\n      @type none\n    </parse>\n  </source>\n  \n  <label @chicago-spark-stdout>\n
    \   <match chicago-spark-stdout>\n      @type cloudwatch_logs\n      auto_create_stream
    true\n      region ap-northeast-2\n      include_time_key true\n      log_group_name
    \"spark-startjobrun\"\n      log_stream_name \"pi-logs/jk518skp01ys9ka8b0npx9nt0/jobs/0000000337p0p4se23o/containers/#{ENV['SPARK_APPLICATION_ID']}/#{ENV['SPARK_CONTAINER_ID']}/stdout\"\n
    \     put_log_events_disable_retry_limit false\n      put_log_events_retry_limit
    0\n      <buffer>\n        @type file\n        path \"/tmp/pi-logs/jk518skp01ys9ka8b0npx9nt0/jobs/0000000337p0p4se23o/containers/#{ENV['SPARK_APPLICATION_ID']}/#{ENV['SPARK_CONTAINER_ID']}/stdout-out-cwl-buffer*\"\n
    \       chunk_limit_size 16MB\n        flush_at_shutdown true\n        flush_mode
    interval\n        flush_interval 10s\n        retry_timeout 30s\n        retry_type
    exponential_backoff\n        retry_exponential_backoff_base 2\n        retry_wait
    1s\n        retry_randomize true\n        disable_chunk_backup true\n        retry_max_times
    5\n      </buffer>\n      <secondary>\n        @type secondary_file\n        directory
    /var/log/fluentd/error/\n        basename cw-container-error.log\n      </secondary>\n
    \   </match>\n  </label>\n</worker>\n\n\n<worker 0>\n  <source>\n    tag chicago-spark-stderr\n
    \   @label @chicago-spark-stderr\n    @type tail\n    path \"#{ENV['K8S_SPARK_LOG_URL_STDERR']}\"\n
    \   pos_file \"#{ENV['K8S_SPARK_LOG_URL_STDERR']}-in-tail.pos\"\n    read_from_head
    true\n    <parse>\n      @type none\n    </parse>\n  </source>\n  \n  <label @chicago-spark-stderr>\n
    \   <match chicago-spark-stderr>\n      @type cloudwatch_logs\n      auto_create_stream
    true\n      region ap-northeast-2\n      include_time_key true\n      log_group_name
    \"spark-startjobrun\"\n      log_stream_name \"pi-logs/jk518skp01ys9ka8b0npx9nt0/jobs/0000000337p0p4se23o/containers/#{ENV['SPARK_APPLICATION_ID']}/#{ENV['SPARK_CONTAINER_ID']}/stderr\"\n
    \     put_log_events_disable_retry_limit false\n      put_log_events_retry_limit
    0\n      <buffer>\n        @type file\n        path \"/tmp/pi-logs/jk518skp01ys9ka8b0npx9nt0/jobs/0000000337p0p4se23o/containers/#{ENV['SPARK_APPLICATION_ID']}/#{ENV['SPARK_CONTAINER_ID']}/stderr-out-cwl-buffer*\"\n
    \       chunk_limit_size 16MB\n        flush_at_shutdown true\n        flush_mode
    interval\n        flush_interval 10s\n        retry_timeout 30s\n        retry_type
    exponential_backoff\n        retry_exponential_backoff_base 2\n        retry_wait
    1s\n        retry_randomize true\n        disable_chunk_backup true\n        retry_max_times
    5\n      </buffer>\n      <secondary>\n        @type secondary_file\n        directory
    /var/log/fluentd/error/\n        basename cw-container-error.log\n      </secondary>\n
    \   </match>\n  </label>\n</worker>\n\n\n<worker 1>\n  <source>\n    tag chicago-spark-s3-container-stderr-logs\n
    \   @label @chicago-spark-s3-container-stderr-logs\n    @type tail\n    path \"#{ENV['K8S_SPARK_LOG_URL_STDERR']}\"\n
    \   pos_file \"#{ENV['K8S_SPARK_LOG_URL_STDERR']}-s3-container-log-in-tail.pos\"\n
    \   read_from_head true\n    <parse>\n      @type none\n    </parse>\n  </source>\n
    \ \n  <label @chicago-spark-s3-container-stderr-logs>\n    <match chicago-spark-s3-container-stderr-logs>\n
    \     @type s3\n      s3_bucket ssup2-spark\n      s3_region ap-northeast-2\n
    \     path \"startjobrun/jk518skp01ys9ka8b0npx9nt0/jobs/0000000337p0p4se23o/containers/#{ENV['SPARK_APPLICATION_ID']}/#{ENV['SPARK_CONTAINER_ID']}\"\n
    \     s3_object_key_format %{path}/stderr.gz\n      check_apikey_on_start false\n
    \     overwrite true\n      <buffer>\n        @type file\n        path /tmp/fluentd/container-logs/stderr/out-s3-buffer*\n
    \       chunk_limit_size 16MB\n        flush_at_shutdown true\n        flush_mode
    interval\n        flush_interval 120s\n        retry_timeout 30s\n        retry_type
    exponential_backoff\n        retry_exponential_backoff_base 2\n        retry_wait
    1s\n        retry_randomize true\n        disable_chunk_backup true\n        retry_max_times
    5\n      </buffer>\n      <local_file_upload>\n        file_path \"#{ENV['K8S_SPARK_LOG_URL_STDERR']}\"\n
    \     </local_file_upload>\n      <secondary>\n        @type secondary_file\n
    \       directory /var/log/fluentd/error/\n        basename s3-container-error.log\n
    \     </secondary>\n    </match>\n  </label>\n</worker>\n\n\n<worker 1>\n  <source>\n
    \   tag chicago-spark-s3-container-stdout-logs\n    @label @chicago-spark-s3-container-stdout-logs\n
    \   @type tail\n    path \"#{ENV['K8S_SPARK_LOG_URL_STDOUT']}\"\n    pos_file
    \"#{ENV['K8S_SPARK_LOG_URL_STDOUT']}-s3-container-log-in-tail.pos\"\n    read_from_head
    true\n    <parse>\n      @type none\n    </parse>\n  </source>\n  \n  <label @chicago-spark-s3-container-stdout-logs>\n
    \   <match chicago-spark-s3-container-stdout-logs>\n      @type s3\n      s3_bucket
    ssup2-spark\n      s3_region ap-northeast-2\n      path \"startjobrun/jk518skp01ys9ka8b0npx9nt0/jobs/0000000337p0p4se23o/containers/#{ENV['SPARK_APPLICATION_ID']}/#{ENV['SPARK_CONTAINER_ID']}\"\n
    \     s3_object_key_format %{path}/stdout.gz\n      check_apikey_on_start false\n
    \     overwrite true\n      <buffer>\n        @type file\n        path /tmp/fluentd/container-logs/stdout/out-s3-buffer*\n
    \       chunk_limit_size 16MB\n        flush_at_shutdown true\n        flush_mode
    interval\n        flush_interval 120s\n        retry_timeout 30s\n        retry_type
    exponential_backoff\n        retry_exponential_backoff_base 2\n        retry_wait
    1s\n        retry_randomize true\n        disable_chunk_backup true\n        retry_max_times
    5\n      </buffer>\n      <local_file_upload>\n        file_path \"#{ENV['K8S_SPARK_LOG_URL_STDOUT']}\"\n
    \     </local_file_upload>\n      <secondary>\n        @type secondary_file\n
    \       directory /var/log/fluentd/error/\n        basename s3-container-error.log\n
    \     </secondary>\n    </match>\n  </label>\n</worker>\n\n\n<worker 2>\n  <source>\n
    \   tag emr-containers-spark-s3-event-logs\n    @label @emr-containers-spark-s3-event-logs\n
    \   @type tail\n    path \"#{ENV['K8S_SPARK_EVENT_LOG_DIR']}/#{ENV['SPARK_APPLICATION_ID']}.inprogress,#{ENV['K8S_SPARK_EVENT_LOG_DIR']}/eventlog_v2_#{ENV['SPARK_APPLICATION_ID']}/#{ENV['SPARK_APPLICATION_ID']}.inprogress\"\n
    \   pos_file \"/tmp/fluentd/event-logs/in-tail.pos\"\n    read_from_head true\n
    \   refresh_interval 30\n    <parse>\n      @type none\n    </parse>\n  </source>\n
    \ \n  <label @emr-containers-spark-s3-event-logs>\n    <match emr-containers-spark-s3-event-logs>\n
    \     @type s3\n      <refreshing_file_presigned_post>\n        presigned_post_path
    /var/emr-container/s3/presigned-post\n      </refreshing_file_presigned_post>\n
    \     s3_bucket prod.ap-northeast-2.appinfo.src\n      s3_region ap-northeast-2\n
    \     check_bucket false\n      check_apikey_on_start false\n      check_object
    false\n      path \"[account-id]/jk518skp01ys9ka8b0npx9nt0/jobs/0000000337p0p4se23o/sparklogs/eventlog_v2_#{ENV['SPARK_APPLICATION_ID']}\"\n
    \     s3_object_key_format \"%{path}/events_%{index}_#{ENV['SPARK_APPLICATION_ID']}\"\n
    \     store_as text\n      storage_class STANDARD\n      overwrite true\n      format
    single_value\n      <buffer time>\n        @type file\n        path /tmp/fluentd/event-logs/out-s3-buffer*\n
    \       chunk_limit_size 32MB\n        flush_at_shutdown true\n        timekey
    30\n        timekey_wait 0\n        retry_timeout 30s\n        retry_type exponential_backoff\n
    \       retry_exponential_backoff_base 2\n        retry_wait 1s\n        retry_randomize
    true\n        disable_chunk_backup true\n        retry_max_times 5\n      </buffer>\n
    \     <secondary>\n        @type secondary_file\n        directory /var/log/fluentd/error/\n
    \       basename s3-event-error.log\n      </secondary>\n    </match>\n  </label>\n</worker>\n\n\n<worker
    2>\n  <source>\n    tag emr-containers-spark-s3-event-status-file\n    @label
    @emr-containers-spark-s3-event-status-file\n    @type exec\n    command echo \"
    \"\n    format none\n  </source>\n  \n  <label @emr-containers-spark-s3-event-status-file>\n
    \   <match emr-containers-spark-s3-event-status-file>\n      @type s3\n      <refreshing_file_presigned_post>\n
    \       presigned_post_path /var/emr-container/s3/presigned-post\n      </refreshing_file_presigned_post>\n
    \     s3_bucket prod.ap-northeast-2.appinfo.src\n      s3_region ap-northeast-2\n
    \     check_bucket false\n      check_apikey_on_start false\n      check_object
    false\n      path \"[account-id]/jk518skp01ys9ka8b0npx9nt0/jobs/0000000337p0p4se23o/sparklogs/eventlog_v2_#{ENV['SPARK_APPLICATION_ID']}\"\n
    \     s3_object_key_format \"%{path}/appstatus_#{ENV['SPARK_APPLICATION_ID']}\"\n
    \     store_as text\n      storage_class STANDARD\n      overwrite true\n      format
    single_value\n      <buffer time>\n        @type file\n        path /tmp/fluentd/event-logs/appstatus/out-s3-buffer*\n
    \       chunk_limit_size 1MB\n        flush_mode immediate\n        flush_at_shutdown
    true\n        retry_timeout 30s\n        retry_type exponential_backoff\n        retry_exponential_backoff_base
    2\n        retry_wait 1s\n        retry_randomize true\n        disable_chunk_backup
    true\n        retry_max_times 5\n      </buffer>\n      <secondary>\n        @type
    secondary_file\n        directory /var/log/fluentd/error/\n        basename s3-appstatus-event-error.log\n
    \     </secondary>\n    </match>\n  </label>\n</worker>\n"
  executor: "<system>\n  workers 2\n</system>\n<worker 0>\n  <source>\n    tag chicago-spark-stdout\n
    \   @label @chicago-spark-stdout\n    @type tail\n    path \"#{ENV['K8S_SPARK_LOG_URL_STDOUT']}\"\n
    \   pos_file \"#{ENV['K8S_SPARK_LOG_URL_STDOUT']}-in-tail.pos\"\n    read_from_head
    true\n    <parse>\n      @type none\n    </parse>\n  </source>\n  \n  <label @chicago-spark-stdout>\n
    \   <match chicago-spark-stdout>\n      @type cloudwatch_logs\n      auto_create_stream
    true\n      region ap-northeast-2\n      include_time_key true\n      log_group_name
    \"spark-startjobrun\"\n      log_stream_name \"pi-logs/jk518skp01ys9ka8b0npx9nt0/jobs/0000000337p0p4se23o/containers/#{ENV['SPARK_APPLICATION_ID']}/#{ENV['SPARK_CONTAINER_ID']}/stdout\"\n
    \     put_log_events_disable_retry_limit false\n      put_log_events_retry_limit
    0\n      <buffer>\n        @type file\n        path \"/tmp/pi-logs/jk518skp01ys9ka8b0npx9nt0/jobs/0000000337p0p4se23o/containers/#{ENV['SPARK_APPLICATION_ID']}/#{ENV['SPARK_CONTAINER_ID']}/stdout-out-cwl-buffer*\"\n
    \       chunk_limit_size 16MB\n        flush_at_shutdown true\n        flush_mode
    interval\n        flush_interval 10s\n        retry_timeout 30s\n        retry_type
    exponential_backoff\n        retry_exponential_backoff_base 2\n        retry_wait
    1s\n        retry_randomize true\n        disable_chunk_backup true\n        retry_max_times
    5\n      </buffer>\n      <secondary>\n        @type secondary_file\n        directory
    /var/log/fluentd/error/\n        basename cw-container-error.log\n      </secondary>\n
    \   </match>\n  </label>\n</worker>\n\n\n<worker 0>\n  <source>\n    tag chicago-spark-stderr\n
    \   @label @chicago-spark-stderr\n    @type tail\n    path \"#{ENV['K8S_SPARK_LOG_URL_STDERR']}\"\n
    \   pos_file \"#{ENV['K8S_SPARK_LOG_URL_STDERR']}-in-tail.pos\"\n    read_from_head
    true\n    <parse>\n      @type none\n    </parse>\n  </source>\n  \n  <label @chicago-spark-stderr>\n
    \   <match chicago-spark-stderr>\n      @type cloudwatch_logs\n      auto_create_stream
    true\n      region ap-northeast-2\n      include_time_key true\n      log_group_name
    \"spark-startjobrun\"\n      log_stream_name \"pi-logs/jk518skp01ys9ka8b0npx9nt0/jobs/0000000337p0p4se23o/containers/#{ENV['SPARK_APPLICATION_ID']}/#{ENV['SPARK_CONTAINER_ID']}/stderr\"\n
    \     put_log_events_disable_retry_limit false\n      put_log_events_retry_limit
    0\n      <buffer>\n        @type file\n        path \"/tmp/pi-logs/jk518skp01ys9ka8b0npx9nt0/jobs/0000000337p0p4se23o/containers/#{ENV['SPARK_APPLICATION_ID']}/#{ENV['SPARK_CONTAINER_ID']}/stderr-out-cwl-buffer*\"\n
    \       chunk_limit_size 16MB\n        flush_at_shutdown true\n        flush_mode
    interval\n        flush_interval 10s\n        retry_timeout 30s\n        retry_type
    exponential_backoff\n        retry_exponential_backoff_base 2\n        retry_wait
    1s\n        retry_randomize true\n        disable_chunk_backup true\n        retry_max_times
    5\n      </buffer>\n      <secondary>\n        @type secondary_file\n        directory
    /var/log/fluentd/error/\n        basename cw-container-error.log\n      </secondary>\n
    \   </match>\n  </label>\n</worker>\n\n\n<worker 1>\n  <source>\n    tag chicago-spark-s3-container-stderr-logs\n
    \   @label @chicago-spark-s3-container-stderr-logs\n    @type tail\n    path \"#{ENV['K8S_SPARK_LOG_URL_STDERR']}\"\n
    \   pos_file \"#{ENV['K8S_SPARK_LOG_URL_STDERR']}-s3-container-log-in-tail.pos\"\n
    \   read_from_head true\n    <parse>\n      @type none\n    </parse>\n  </source>\n
    \ \n  <label @chicago-spark-s3-container-stderr-logs>\n    <match chicago-spark-s3-container-stderr-logs>\n
    \     @type s3\n      s3_bucket ssup2-spark\n      s3_region ap-northeast-2\n
    \     path \"startjobrun/jk518skp01ys9ka8b0npx9nt0/jobs/0000000337p0p4se23o/containers/#{ENV['SPARK_APPLICATION_ID']}/#{ENV['SPARK_CONTAINER_ID']}\"\n
    \     s3_object_key_format %{path}/stderr.gz\n      check_apikey_on_start false\n
    \     overwrite true\n      <buffer>\n        @type file\n        path /tmp/fluentd/container-logs/stderr/out-s3-buffer*\n
    \       chunk_limit_size 16MB\n        flush_at_shutdown true\n        flush_mode
    interval\n        flush_interval 120s\n        retry_timeout 30s\n        retry_type
    exponential_backoff\n        retry_exponential_backoff_base 2\n        retry_wait
    1s\n        retry_randomize true\n        disable_chunk_backup true\n        retry_max_times
    5\n      </buffer>\n      <local_file_upload>\n        file_path \"#{ENV['K8S_SPARK_LOG_URL_STDERR']}\"\n
    \     </local_file_upload>\n      <secondary>\n        @type secondary_file\n
    \       directory /var/log/fluentd/error/\n        basename s3-container-error.log\n
    \     </secondary>\n    </match>\n  </label>\n</worker>\n\n\n<worker 1>\n  <source>\n
    \   tag chicago-spark-s3-container-stdout-logs\n    @label @chicago-spark-s3-container-stdout-logs\n
    \   @type tail\n    path \"#{ENV['K8S_SPARK_LOG_URL_STDOUT']}\"\n    pos_file
    \"#{ENV['K8S_SPARK_LOG_URL_STDOUT']}-s3-container-log-in-tail.pos\"\n    read_from_head
    true\n    <parse>\n      @type none\n    </parse>\n  </source>\n  \n  <label @chicago-spark-s3-container-stdout-logs>\n
    \   <match chicago-spark-s3-container-stdout-logs>\n      @type s3\n      s3_bucket
    ssup2-spark\n      s3_region ap-northeast-2\n      path \"startjobrun/jk518skp01ys9ka8b0npx9nt0/jobs/0000000337p0p4se23o/containers/#{ENV['SPARK_APPLICATION_ID']}/#{ENV['SPARK_CONTAINER_ID']}\"\n
    \     s3_object_key_format %{path}/stdout.gz\n      check_apikey_on_start false\n
    \     overwrite true\n      <buffer>\n        @type file\n        path /tmp/fluentd/container-logs/stdout/out-s3-buffer*\n
    \       chunk_limit_size 16MB\n        flush_at_shutdown true\n        flush_mode
    interval\n        flush_interval 120s\n        retry_timeout 30s\n        retry_type
    exponential_backoff\n        retry_exponential_backoff_base 2\n        retry_wait
    1s\n        retry_randomize true\n        disable_chunk_backup true\n        retry_max_times
    5\n      </buffer>\n      <local_file_upload>\n        file_path \"#{ENV['K8S_SPARK_LOG_URL_STDOUT']}\"\n
    \     </local_file_upload>\n      <secondary>\n        @type secondary_file\n
    \       directory /var/log/fluentd/error/\n        basename s3-container-error.log\n
    \     </secondary>\n    </match>\n  </label>\n</worker>\n"
  fluentd-pod-metadata.conf: "<system>\n  workers 1\n</system>\n<worker 0>\n  <source>\n
    \   tag emr-containers-pod-metadata\n    @label @emr-containers-pod-metadata\n
    \   @type tail\n    path \"#{ENV['POD_METADATA_PATH']}\"\n    pos_file \"/tmp/emr-containers/pod-info-in-tail.pos\"\n
    \   read_from_head true\n    refresh_interval 120\n    <parse>\n      @type none\n
    \   </parse>\n  </source>\n  \n  <label @emr-containers-pod-metadata>\n    <match
    emr-containers-pod-metadata>\n      @type stdout\n      format single_value\n
    \     output_to_console true\n    </match>\n  </label>\n</worker>\n"
  job: "<system>\n  workers 2\n</system>\n<worker 0>\n  <source>\n    tag chicago-spark-stdout\n
    \   @label @chicago-spark-stdout\n    @type tail\n    path \"#{ENV['K8S_SPARK_LOG_URL_STDOUT']}\"\n
    \   pos_file \"#{ENV['K8S_SPARK_LOG_URL_STDOUT']}-in-tail.pos\"\n    read_from_head
    true\n    <parse>\n      @type none\n    </parse>\n  </source>\n  \n  <label @chicago-spark-stdout>\n
    \   <match chicago-spark-stdout>\n      @type cloudwatch_logs\n      auto_create_stream
    true\n      region ap-northeast-2\n      include_time_key true\n      log_group_name
    \"spark-startjobrun\"\n      log_stream_name \"pi-logs/jk518skp01ys9ka8b0npx9nt0/jobs/0000000337p0p4se23o/control-logs/#{ENV['SPARK_CONTAINER_ID']}/stdout\"\n
    \     put_log_events_disable_retry_limit false\n      put_log_events_retry_limit
    0\n      <buffer>\n        @type file\n        path \"/tmp/pi-logs/jk518skp01ys9ka8b0npx9nt0/jobs/0000000337p0p4se23o/control-logs/#{ENV['SPARK_CONTAINER_ID']}/stdout-out-cwl-buffer*\"\n
    \       chunk_limit_size 16MB\n        flush_at_shutdown true\n        flush_mode
    interval\n        flush_interval 10s\n        retry_timeout 30s\n        retry_type
    exponential_backoff\n        retry_exponential_backoff_base 2\n        retry_wait
    1s\n        retry_randomize true\n        disable_chunk_backup true\n        retry_max_times
    5\n      </buffer>\n      <secondary>\n        @type secondary_file\n        directory
    /var/log/fluentd/error/\n        basename cw-container-error.log\n      </secondary>\n
    \   </match>\n  </label>\n</worker>\n\n\n<worker 0>\n  <source>\n    tag chicago-spark-stderr\n
    \   @label @chicago-spark-stderr\n    @type tail\n    path \"#{ENV['K8S_SPARK_LOG_URL_STDERR']}\"\n
    \   pos_file \"#{ENV['K8S_SPARK_LOG_URL_STDERR']}-in-tail.pos\"\n    read_from_head
    true\n    <parse>\n      @type none\n    </parse>\n  </source>\n  \n  <label @chicago-spark-stderr>\n
    \   <match chicago-spark-stderr>\n      @type cloudwatch_logs\n      auto_create_stream
    true\n      region ap-northeast-2\n      include_time_key true\n      log_group_name
    \"spark-startjobrun\"\n      log_stream_name \"pi-logs/jk518skp01ys9ka8b0npx9nt0/jobs/0000000337p0p4se23o/control-logs/#{ENV['SPARK_CONTAINER_ID']}/stderr\"\n
    \     put_log_events_disable_retry_limit false\n      put_log_events_retry_limit
    0\n      <buffer>\n        @type file\n        path \"/tmp/pi-logs/jk518skp01ys9ka8b0npx9nt0/jobs/0000000337p0p4se23o/control-logs/#{ENV['SPARK_CONTAINER_ID']}/stderr-out-cwl-buffer*\"\n
    \       chunk_limit_size 16MB\n        flush_at_shutdown true\n        flush_mode
    interval\n        flush_interval 10s\n        retry_timeout 30s\n        retry_type
    exponential_backoff\n        retry_exponential_backoff_base 2\n        retry_wait
    1s\n        retry_randomize true\n        disable_chunk_backup true\n        retry_max_times
    5\n      </buffer>\n      <secondary>\n        @type secondary_file\n        directory
    /var/log/fluentd/error/\n        basename cw-container-error.log\n      </secondary>\n
    \   </match>\n  </label>\n</worker>\n\n\n<worker 1>\n  <source>\n    tag chicago-spark-s3-container-stderr-logs\n
    \   @label @chicago-spark-s3-container-stderr-logs\n    @type tail\n    path \"#{ENV['K8S_SPARK_LOG_URL_STDERR']}\"\n
    \   pos_file \"#{ENV['K8S_SPARK_LOG_URL_STDERR']}-s3-container-log-in-tail.pos\"\n
    \   read_from_head true\n    <parse>\n      @type none\n    </parse>\n  </source>\n
    \ \n  <label @chicago-spark-s3-container-stderr-logs>\n    <match chicago-spark-s3-container-stderr-logs>\n
    \     @type s3\n      s3_bucket ssup2-spark\n      s3_region ap-northeast-2\n
    \     path \"startjobrun/jk518skp01ys9ka8b0npx9nt0/jobs/0000000337p0p4se23o/control-logs/#{ENV['SPARK_CONTAINER_ID']}\"\n
    \     s3_object_key_format %{path}/stderr.gz\n      check_apikey_on_start false\n
    \     overwrite true\n      <buffer>\n        @type file\n        path /tmp/fluentd/container-logs/stderr/out-s3-buffer*\n
    \       chunk_limit_size 16MB\n        flush_at_shutdown true\n        flush_mode
    interval\n        flush_interval 120s\n        retry_timeout 30s\n        retry_type
    exponential_backoff\n        retry_exponential_backoff_base 2\n        retry_wait
    1s\n        retry_randomize true\n        disable_chunk_backup true\n        retry_max_times
    5\n      </buffer>\n      <local_file_upload>\n        file_path \"#{ENV['K8S_SPARK_LOG_URL_STDERR']}\"\n
    \     </local_file_upload>\n      <secondary>\n        @type secondary_file\n
    \       directory /var/log/fluentd/error/\n        basename s3-container-error.log\n
    \     </secondary>\n    </match>\n  </label>\n</worker>\n\n\n<worker 1>\n  <source>\n
    \   tag chicago-spark-s3-container-stdout-logs\n    @label @chicago-spark-s3-container-stdout-logs\n
    \   @type tail\n    path \"#{ENV['K8S_SPARK_LOG_URL_STDOUT']}\"\n    pos_file
    \"#{ENV['K8S_SPARK_LOG_URL_STDOUT']}-s3-container-log-in-tail.pos\"\n    read_from_head
    true\n    <parse>\n      @type none\n    </parse>\n  </source>\n  \n  <label @chicago-spark-s3-container-stdout-logs>\n
    \   <match chicago-spark-s3-container-stdout-logs>\n      @type s3\n      s3_bucket
    ssup2-spark\n      s3_region ap-northeast-2\n      path \"startjobrun/jk518skp01ys9ka8b0npx9nt0/jobs/0000000337p0p4se23o/control-logs/#{ENV['SPARK_CONTAINER_ID']}\"\n
    \     s3_object_key_format %{path}/stdout.gz\n      check_apikey_on_start false\n
    \     overwrite true\n      <buffer>\n        @type file\n        path /tmp/fluentd/container-logs/stdout/out-s3-buffer*\n
    \       chunk_limit_size 16MB\n        flush_at_shutdown true\n        flush_mode
    interval\n        flush_interval 120s\n        retry_timeout 30s\n        retry_type
    exponential_backoff\n        retry_exponential_backoff_base 2\n        retry_wait
    1s\n        retry_randomize true\n        disable_chunk_backup true\n        retry_max_times
    5\n      </buffer>\n      <local_file_upload>\n        file_path \"#{ENV['K8S_SPARK_LOG_URL_STDOUT']}\"\n
    \     </local_file_upload>\n      <secondary>\n        @type secondary_file\n
    \       directory /var/log/fluentd/error/\n        basename s3-container-error.log\n
    \     </secondary>\n    </match>\n  </label>\n</worker>\n"
kind: ConfigMap
metadata:
  creationTimestamp: "2024-01-11T14:56:29Z"
  labels:
    emr-containers.amazonaws.com/job.configuration: fluentd
    emr-containers.amazonaws.com/job.id: 0000000337p0p4se23o
    emr-containers.amazonaws.com/virtual-cluster-id: jk518skp01ys9ka8b0npx9nt0
  name: fluentd-jk518skp01ys9ka8b0npx9nt0-0000000337p0p4se23o
  namespace: emr-cli
  ownerReferences:
  - apiVersion: batch/v1
    blockOwnerDeletion: true
    controller: true
    kind: Job
    name: 0000000337p0p4se23o
    uid: 21bbe42c-758b-42b4-9dba-aeb497bd1942
  resourceVersion: "68664513"
  uid: 68ec766a-2e38-46c3-a3f6-1c1ec9264cd8
```

[Shell 2] 명령어를 실행하면 [File 4], [File 5], [File 6] 3개의 ConfigMap이 생성된다. job-runner Pod 뿐만 아니라, Driver Pod, Executor Pod 또한 fluentd가 실행 되도록 설정되어 있는것을 확인할 수 있으며, Drvier Pod, Executor Pod에서 실행되는 fluentd는 stdout/stderr를 CloudWatch 또는 S3로 전송되도록 설정되어 있는것을 확인할 수 있다.

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

StartJobRun API를 통해서도 spark-submit CLI에서 설정 가능한 다양한 설정들을 동일하게 설정이 가능하다. [Shell 3]은 Promethues로 Monitoring 수행을 위한 예제를 나타내고 있다.

### 2.1. with ACK EMR Container Controller

{{< figure caption="[Figure 2] Spark on AWS EKS Architecture with ACK EMR Container Controller" src="images/spark-aws-eks-architecture-ack-emr-container-controller.png" width="1000px" >}}

AWS에서는 StartJobRun API를 기반으로 Spark Job을 제출하는 방식을 Kubernetes의 Object를 활용할 수 있도록 ACK EMR Container Controller를 제공하고 있다. [Figure 2]는 ACK EMR Container Controller를 기반으로 StartJobRun API를 통해서 Spark Job을 제출하는 과정을 나타내고 있다.

ACK EMR Container Controller를 AWS EKS Cluster에 설치하면 `Virtual Cluster`와 `Job Run` 두 가지 Custom Resource 이용이 가능해진다. `Virtual Cluster`는 ACK EMR Container Controller가 설치된 AWS EKS Cluster의 특정 Namespace를 대상으로 EMR on EKS의 Virtual Cluster를 설정하는데 이용하는 Custome Resource이며, `Job Run`은 StartJobRun API를 통해서 Spark Job을 제출하는 경우 이용하는 Custom Resource이다.

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

[File 7]은 단순한 Job Run의 예제를 나타내고 있으며, [File 8]은 Logging 설정이 적용된 Job Run의 예제를 나타내고 있다. 설정 값들을 살펴보면 aws CLI를 통해서 설정하는 옵션들을 동일하게 Job Run에 설장할 수 있는것을 확인할 수 있다.

## 3. 참조

* EMR on EKS Container Image : [https://gallery.ecr.aws/emr-on-eks](https://gallery.ecr.aws/emr-on-eks)
* StartJobRun Parameter : [https://docs.aws.amazon.com/emr/latest/EMR-on-EKS-DevelopmentGuide/emr-eks-jobs-CLI.html#emr-eks-jobs-parameters](https://docs.aws.amazon.com/emr/latest/EMR-on-EKS-DevelopmentGuide/emr-eks-jobs-CLI.html#emr-eks-jobs-parameters)
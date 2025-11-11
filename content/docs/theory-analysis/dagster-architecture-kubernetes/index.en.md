---
title: Dagster Architecture on Kubernetes
---

Analyzes the architecture when running Dagster on Kubernetes.

## 1. Control Plane

{{< figure caption="[Figure 1] Dagster K8s Run Launcher + Multiprocess Executor Architecture" src="images/dagster-architecture-k8srunlauncher-multiprocess.png" width="1000px" >}}

[Figure 1] shows the basic architecture when configuring Dagster on Kubernetes. **Dagster Web Server**, **Dagster Daemon**, and **Code Location Server** located in the Dagster Control Plane are Components that must always be running, so they all operate as Pods through Kubernetes Deployments. **Run** has the same lifecycle as a Workflow, being created when the Workflow is created and terminated when the Workflow terminates, so it operates as a Kubernetes Job. **Dagster Instance** is stored as a Kubernetes ConfigMap, and other Components located in the Dagster Control Plane operate by referencing the Dagster Instance ConfigMap.

Code Location Server is a server that containerizes Code Location according to Dagster's guide. Multiple Code Location Servers with different Dagster Objects defined can be located and operate in the Control Plane, and Dagster Web Server also provides the ability to separate and use Dagster Objects by Code Location Server unit through the **Workspace** feature. Generally, Code Location Servers are separated and configured by project unit.

When a Workflow is executed, the actual Control Plane Component responsible for the Workflow is Run. The remaining Control Plane Components perform the role of retrieving workflow configuration information from Dagster Instance and Code Location Server to execute Run. The executed Run executes the Workflow and directly accesses the Database to store the results. Because of this characteristic, after Run is executed, Workflows can continue to execute without problems even if Dagster Control Plane Components (Dagster Web Server, Dagster Daemon, Code Location Server) are not running. This means that Components of the Dagster Control Plane can be freely deployed regardless of Workflow execution.

## 2. Run Launcher, Executor

When running Dagster on Kubernetes, three combinations of Run Launcher and Executor can be used.

### 1.1. K8s Run Launcher + Multiprocess Executor

The combination of **K8s Run Launcher** and **Multiprocess Executor** is the most basic combination, and the Dagster Architecture in [Figure 1] also shows the Architecture when configured using the K8s Run Launcher and Multiprocess Executor combination. K8s Run Launcher creates a separate Kubernetes Job for each Run, and Run is executed in the Pod of the created Kubernetes Job. After that, Run creates multiple processes and executes Op/Asset.

```text {caption="[Text 1] Dagster Pod Examples with K8s Run Launcher + Multiprocess Executor"}
$ kubectl -n dagster get job
NAME                                               STATUS     COMPLETIONS   DURATION   AGE
dagster-run-527436fd-ef2f-40c5-978f-1b7bbffeab8b   Complete   1/1           85s        9m9s

$ kubectl -n dagster get pod
NAME                                                              READY   STATUS      RESTARTS        AGE
dagster-daemon-84c4c57ffd-4cdp4                                   1/1     Running     0               2d18h
dagster-dagster-user-deployments-dagster-workflows-868f5b75mfxv   1/1     Running     0               2d18h
dagster-dagster-webserver-85d8d95dfc-q6j97                        1/1     Running     1 (6d15h ago)   7d
dagster-run-527436fd-ef2f-40c5-978f-1b7bbffeab8b-2hzsn            0/1     Completed   0               9m30s
```

[Text 1] shows the list of Kubernetes Jobs and Pods when executing Dagster Run using the K8s Run Launcher and Multiprocess Executor combination. Kubernetes Jobs and Pods starting with the `dagster-run` string represent Kubernetes Jobs and Pods for a specific Run, and you can see that execution is complete. Each time a Workflow is executed, Kubernetes Jobs and Pods responsible for the executed Workflow are created and executed. [Text 1] also shows Pods of the Dagster Control Plane.

```yaml {caption="[Text 2] K8s Run Launcher Config in Dagster Instance", linenos=table}
run_launcher:
  module: dagster_k8s
  class: K8sRunLauncher
  config:
    resources:
      limits:
        cpu: 2000m
        memory: 4096Mi
      requests:
        cpu: 2000m
        memory: 4096Mi
    run_k8s_config:
      pod_spec_config:
        nodeSelector:
          node-group.dp.ssup2: worker
```

```python {caption="[Code 1] Run Resource Example", linenos=table}
@job(tags={
        "dagster-k8s/config": {
            "container_config": {
                "resources": {
                    "requests": {"cpu": "2000m", "memory": "4096Mi"},
                    "limits": {"cpu": "2000m", "memory": "4096Mi"},
                }
            }
        }
    })
def process_numbers():
...

process_numbers_asset = define_asset_job(
    name="process_numbers_asset",
    selection=AssetSelection.groups("numbers"),
    tags={
        "domain": "numbers",
        "dagster-k8s/config": {
            "container_config": {
                "resources": {
                    "requests": {"cpu": "2000m", "memory": "4096Mi"},
                    "limits": {"cpu": "2000m", "memory": "4096Mi"},
                }
            },
            "pod_spec_config": {
                "node_selector": {
                    "node-group.dp.ssup2": "worker"
                }
            }
        }
    })
```

The Spec of the Kubernetes Pod for Run created by K8s Run Launcher can be specified as a **Default** value in Dagster Instance or defined for each Dagster Job. [Text 2] is a Config example when specifying Default Spec in Dagster Instance, and [Code 1] is a Code example when defining Spec through Tags for each Dagster Job. The examples specify Resources and Node Selector, and most Pod Specs can be specified in addition to these.

### 1.2. K8s Run Launcher + K8s Job Executor

{{< figure caption="[Figure 2] Dagster K8s Run Launcher + K8s Job Executor Architecture" src="images/dagster-architecture-k8srunlauncher-multiprocess.png" width="1000px" >}}

[Figure 2] shows the Architecture when using the combination of **K8s Run Launcher** and **K8s Job Executor**. When using K8s Job Executor instead of Multiprocess Executor, Run creates and executes separate Kubernetes Jobs for each Op/Asset. Because of this characteristic, it has advantages and disadvantages compared to Multiprocess Executor. Because it uses multiple Kubernetes Jobs, a single Workflow can widely utilize Kubernetes Cluster resources, but because it creates separate Kubernetes Jobs for each Run, long Cold Start times can occur due to creation time.

On the other hand, Multiprocess Executor has the disadvantage that a single Workflow cannot use more resources than the Run Kubernetes Job is allocated, but it has the advantage that Cold Start does not occur because all Assets/Ops are executed in the same Kubernetes Job. Of course, even when using Multiprocess Executor, you can use Dagster's External Pipeline feature to execute Workflows outside of Dagster, and in this case, it is an exception because it uses resources separate from the resources allocated to the Run Kubernetes Job.

```text {caption="[Text 3] Dagster Pod Examples with K8s Run Launcher + K8s Job Executor"}
$ kubectl -n dagster get job
NAME                                               STATUS     COMPLETIONS   DURATION   AGE
dagster-run-7089f4e0-dfb9-49af-8c3b-6f9355085e27   Complete   1/1           2m46s      3m6s
dagster-step-377e3eab56ac3a9139bf74dff9436c8f      Complete   1/1           29s        78s
dagster-step-3a37b43a00d6475349fc9e814cd81e57      Complete   1/1           42s        2m43s
dagster-step-44d73c2196cbd520aadfb579c1665019      Complete   1/1           52s        2m5s
dagster-step-7fa7ca8f57d34ec0669efd681a7799f3      Complete   1/1           43s        2m6s
dagster-step-955bb321c832a470073fe7c84820a920      Complete   1/1           29s        54s
dagster-step-a46eb649b986676185b781c6f046a707      Complete   1/1           20s        87s

$ kubectl -n dagster get pod
NAME                                                              READY   STATUS      RESTARTS        AGE
dagster-daemon-84c4c57ffd-4cdp4                                   1/1     Running     0               2d18h
dagster-dagster-user-deployments-dagster-workflows-868f5b75mfxv   1/1     Running     0               2d18h
dagster-dagster-webserver-85d8d95dfc-q6j97                        1/1     Running     1 (6d15h ago)   7d
dagster-run-7089f4e0-dfb9-49af-8c3b-6f9355085e27-qfk2r            0/1     Completed   0               3m23s
dagster-step-377e3eab56ac3a9139bf74dff9436c8f-g4tjl               0/1     Completed   0               96s
dagster-step-3a37b43a00d6475349fc9e814cd81e57-fvkzb               0/1     Completed   0               3m1s
dagster-step-44d73c2196cbd520aadfb579c1665019-84mxl               0/1     Completed   0               2m23s
dagster-step-7fa7ca8f57d34ec0669efd681a7799f3-4dggd               0/1     Completed   0               2m24s
dagster-step-955bb321c832a470073fe7c84820a920-kdshq               0/1     Completed   0               72s
dagster-step-a46eb649b986676185b781c6f046a707-v9cdg               0/1     Completed   0               105s
```

[Text 3] shows the list of Kubernetes Jobs and Pods when executing Dagster Run using the K8s Run Launcher and K8s Job Executor combination. Similar to Multiprocess Executor, Kubernetes Jobs and Pods for Run starting with the `dagster-run` string exist, and Kubernetes Jobs and Pods starting with the `dagster-step` string can also be seen. Kubernetes Jobs and Pods starting with the `dagster-step` string represent Kubernetes Jobs and Pods for each Op/Asset, and looking at `STATUS` and `AGE`, you can see that all have been executed sequentially and completed.

```python {caption="[Code 2] Op/Asset Resource Example", linenos=table}
@op(description="Generate a list of numbers from 1 to 10",
    tags={
        "domain": "numbers",
        "dagster-k8s/config": {
            "container_config": {
                "resources": {
                    "requests": {"cpu": "2000m", "memory": "4096Mi"},
                    "limits": {"cpu": "2000m", "memory": "4096Mi"},
                }
            },
        }
    })
def generate_numbers():
    return list(range(1, 11))

@asset(key_prefix=["examples"], 
    group_name="numbers",
    description="Generated a list of numbers from 1 to 10", 
    kinds=["python"],
    op_tags={
        "dagster-k8s/config": {
            "container_config": {
                "resources": {
                    "requests": {"cpu": "2000m", "memory": "4096Mi"},
                    "limits": {"cpu": "2000m", "memory": "4096Mi"},
                }
            },
        }
    })
def generated_numbers():
    return list(range(1, 11))
```

The Spec of Op/Asset Kubernetes Pods created through K8s Job Executor **inherits** the Spec of Run's Kubernetes Job and Pod by default, and can also be defined for each Dagster Op/Asset. [Code 2] shows an example of defining Resource values through Tags on Op/Asset.

### 1.3. Celery K8s Run Launcher + Celery K8s Job Executor

{{< figure caption="[Figure 3] Dagster Celery K8s Run Launcher + Celery K8s Job Executor Architecture" src="images/dagster-architecture-k8scelery.png" width="1000px" >}}

[Figure 3] shows the Architecture when executing Dagster Run using the combination of **Celery K8s Run Launcher** and **Celery K8s Job Executor**. Similar to K8s Run Launcher, Celery K8s Run Launcher creates and executes separate Kubernetes Jobs for each Run. However, the difference is that instead of creating Processes or Kubernetes Jobs for Op/Asset execution from Run, it queues Op/Asset processing to Celery. After that, Celery Workers receive Op/Assets from Celery and process them. Because of this operation method, when using Celery K8s Run Launcher, Celery K8s Job Executor must be used.

The number of parallel processing for Op/Asset is the same as the number of Celery Workers. If there are 5 Celery Workers, the maximum number of parallel processing for Op/Asset is also 5. That is, the number of parallel processing for Op/Asset can be controlled through the number of Celery Workers. When using K8s Run Launcher and K8s Job Executor, if many Workflows are executed simultaneously, many Op/Asset Pods are created and executed proportionally. This can cause a heavy burden on the Kubernetes Cluster.

On the other hand, when using Celery K8s Run Launcher and Celery K8s Job Executor, even if many Workflows are executed simultaneously, only as many Op/Asset Pods as the maximum number of Celery Workers are created and executed, so the burden on the Kubernetes Cluster can be reduced. It also has the advantage of being able to utilize Celery's various Retry, Rate Limit, and Backoff features, and Cold Start does not occur for Op/Asset processing because Celery Workers are always running. However, there is a disadvantage that operational complexity increases because RabbitMQ/Redis used as Celery's Queue and Celery Workers must be additionally operated to use Celery K8s Run Launcher and Celery K8s Job Executor.

```text {caption="[Text 4] Dagster Pod Examples with Celery K8s Run Launcher + Celery K8s Job Executor"}
$ kubectl -n dagster-celery get job
NAME                                               STATUS     COMPLETIONS   DURATION   AGE
dagster-run-990449b2-9da1-41ad-a5ca-d7ee397b768d   Complete   1/1           50s        6m34s
dagster-step-50f4e368528a8887c5267d0b44535f5d      Complete   1/1           6s         6m31s
dagster-step-75121c5003b6ac46dc231aa21cb2ab5c      Complete   1/1           5s         5m58s
dagster-step-a7b5d7af7d831e8ead03771ba8744827      Complete   1/1           5s         6m9s
dagster-step-c6f52e1bf24419530e61e13f7d7bb0ed      Complete   1/1           5s         6m9s
dagster-step-f5ae327359276c078786d7ce2ae3d818      Complete   1/1           6s         6m20s
dagster-step-fd9bd10d0477966ec56f4d5ac1455f02      Complete   1/1           5s         6m20s

$ kubectl -n dagster get pod
NAME                                                              READY   STATUS      RESTARTS        AGE
dagster-celery-workers-dagster-bdb4bb986-9mhc5                    1/1     Running     2 (7d15h ago)   21d
dagster-celery-workers-dagster-bdb4bb986-x8gml                    1/1     Running     2 (7d15h ago)   21d
dagster-daemon-64d894f867-57qnx                                   1/1     Running     2 (7d15h ago)   21d
dagster-dagster-user-deployments-dagster-workflows-76b4b65q2f75   1/1     Running     2 (7d15h ago)   21d
dagster-dagster-webserver-6755c86fb8-s7x2x                        1/1     Running     2 (7d15h ago)   21d
dagster-flower-5cb9449b54-hwhph                                   1/1     Running     0               2m47s
dagster-postgresql-0                                              1/1     Running     2 (7d15h ago)   22d
dagster-redis-master-0                                            1/1     Running     2 (7d15h ago)   22d
dagster-redis-slave-0                                             1/1     Running     2 (7d15h ago)   22d
dagster-redis-slave-1                                             1/1     Running     2 (7d15h ago)   22d
dagster-run-990449b2-9da1-41ad-a5ca-d7ee397b768d-54fn4            0/1     Completed   0               6m9s
dagster-step-50f4e368528a8887c5267d0b44535f5d-dvjn7               0/1     Completed   0               6m6s
dagster-step-75121c5003b6ac46dc231aa21cb2ab5c-46mks               0/1     Completed   0               5m33s
dagster-step-a7b5d7af7d831e8ead03771ba8744827-brvsk               0/1     Completed   0               5m44s
dagster-step-c6f52e1bf24419530e61e13f7d7bb0ed-xf54r               0/1     Completed   0               5m44s
dagster-step-f5ae327359276c078786d7ce2ae3d818-dkpnl               0/1     Completed   0               5m55s
dagster-step-fd9bd10d0477966ec56f4d5ac1455f02-288lw               0/1     Completed   0               5m55s
```

[Text 4] shows the list of Kubernetes Jobs and Pods when executing Dagster Run using the Celery K8s Run Launcher and Celery K8s Job Executor combination. Similar to when using K8s Run Launcher and K8s Job Executor, Kubernetes Jobs and Pods for Run starting with the `dagster-run` string exist, and Kubernetes Jobs and Pods for Op/Asset starting with the `dagster-step` string can also be seen. Celery Worker Pods starting with the `dagster-celery-workers` string and Redis used as Celery's Queue can also be seen.

## 2. Container Image, Configuration Propagation

The Container Image of Code Location Server Pod is also used as-is in Run and Op/Asset Pods. When a Workflow inside `Code Location Server A` is triggered, Run and Op/Asset Pods all operate using the Container Image of `Code Location Server A`, and similarly, when a Job inside `Code Location Server B` is triggered, Run and Op/Asset Pods all operate using the Container Image of `Code Location Server B`. Since Run Pods and Op/Asset Pods are all dynamically created Pods when Workflows are executed, if the Container Image size of Code Location Server Pod is too large, Cold Start time can be long due to download time, which can lengthen Workflow execution time. Therefore, it is important to keep the Container Image of Code Location Server as small as possible.

```yaml {caption="[Text 5] Code Location Server Config Example"}
spec:
  affinity: {}
  automountServiceAccountToken: true
  containers:
  - args:
    - dagster
    - api
    - grpc
    - -h
    - 0.0.0.0
    - -p
    - "3030"
    - -f
    - workflows/definitions.py
    env:
    - name: DAGSTER_CURRENT_IMAGE
      value: ghcr.io/ssup2-playground/k8s-data-platform_dagster-workflows:0.4.8
    - name: DAGSTER_PG_PASSWORD
      valueFrom:
        secretKeyRef:
          key: postgresql-password
          name: dagster-postgresql-secret
    - name: DAGSTER_CLI_API_GRPC_CONTAINER_CONTEXT
      value: '{"k8s":{"env_config_maps":["dagster-dagster-user-deployments-dagster-workflows-user-env"],"image_pull_policy":"Always","namespace":"dagster","resources":{"limits":{"cpu":"1000m","memory":"2048Mi"},"requests":{"cpu":"1000m","memory":"2048Mi"}},"run_k8s_config":{"pod_spec_config":{"automount_service_account_token":true}},"service_account_name":"dagster-dagster-user-deployments-user-deployments"}}'
    - name: USER
      value: ssup2
    envFrom:
    - configMapRef:
        name: dagster-dagster-user-deployments-user-deployments-shared-env
    - configMapRef:
        name: dagster-dagster-user-deployments-dagster-workflows-user-env
```

```yaml {caption="[Text 6] Run Config Example"}
spec:
  automountServiceAccountToken: true
  containers:
  - args:
    - dagster
    - api
    - execute_run
    - '{"__class__": "ExecuteRunArgs", "instance_ref": {"__class__": "InstanceRef",
      "compute_logs_data": {"__class__": "ConfigurableClassData", "class_name": "S3ComputeLogManager",
      "config_yaml": "access_key_id: root\nallow_http: true\nallow_invalid_certificates:
      true\nbucket: dagster\nendpoint: http://minio.minio:9000\nprefix: compute-log\nregion:
      default\nsecret_access_key: root123!\n", "module_name": "dagster_obstore.s3.compute_log_manager"},
      "custom_instance_class_data": null, "event_storage_data": {"__class__": "ConfigurableClassData",
      "class_name": "PostgresEventLogStorage", "config_yaml": "postgres_db:\n  db_name:
      dagster\n  hostname: postgresql.postgresql\n  params: {}\n  password:\n    env:
      DAGSTER_PG_PASSWORD\n  port: 5432\n  username: postgres\n", "module_name": "dagster_postgres.event_log"},
      "local_artifact_storage_data": {"__class__": "ConfigurableClassData", "class_name":
      "LocalArtifactStorage", "config_yaml": "base_dir: /opt/dagster/dagster_home\n",
      "module_name": "dagster.core.storage.root"}, "run_coordinator_data": {"__class__":
      "ConfigurableClassData", "class_name": "QueuedRunCoordinator", "config_yaml":
      "dequeue_num_workers: 4\ndequeue_use_threads: true\nmax_concurrent_runs: -1\n",
      "module_name": "dagster.core.run_coordinator"}, "run_launcher_data": {"__class__":
      "ConfigurableClassData", "class_name": "K8sRunLauncher", "config_yaml": "dagster_home:
      /opt/dagster/dagster_home\nimage_pull_policy: Always\ninstance_config_map: dagster-instance\njob_namespace:
      dagster\nload_incluster_config: true\npostgres_password_secret: dagster-postgresql-secret\nrun_k8s_config:\n  pod_spec_config:\n    nodeSelector:\n      node-group.dp.ssup2:
      worker\nservice_account_name: dagster\n", "module_name": "dagster_k8s"}, "run_storage_data":
      {"__class__": "ConfigurableClassData", "class_name": "PostgresRunStorage", "config_yaml":
      "postgres_db:\n  db_name: dagster\n  hostname: postgresql.postgresql\n  params:
      {}\n  password:\n    env: DAGSTER_PG_PASSWORD\n  port: 5432\n  username: postgres\n",
      "module_name": "dagster_postgres.run_storage"}, "schedule_storage_data": {"__class__":
      "ConfigurableClassData", "class_name": "PostgresScheduleStorage", "config_yaml":
      "postgres_db:\n  db_name: dagster\n  hostname: postgresql.postgresql\n  params:
      {}\n  password:\n    env: DAGSTER_PG_PASSWORD\n  port: 5432\n  username: postgres\n",
      "module_name": "dagster_postgres.schedule_storage"}, "scheduler_data": {"__class__":
      "ConfigurableClassData", "class_name": "DagsterDaemonScheduler", "config_yaml":
      "{}\n", "module_name": "dagster.core.scheduler"}, "secrets_loader_data": null,
      "settings": {"run_monitoring": {"enabled": true, "free_slots_after_run_end_seconds":
      0, "max_resume_run_attempts": 0, "poll_interval_seconds": 120, "start_timeout_seconds":
      300}, "run_retries": {"enabled": true, "max_retries": 2}, "schedules": {"num_workers":
      4, "use_threads": true}, "sensors": {"num_workers": 4, "use_threads": true},
      "telemetry": {"enabled": true}}, "storage_data": {"__class__": "ConfigurableClassData",
      "class_name": "CompositeStorage", "config_yaml": "event_log_storage:\n  class_name:
      PostgresEventLogStorage\n  config_yaml: \"postgres_db:\\n  db_name: dagster\\n  hostname:
      postgresql.postgresql\\n\\\n    \\  params: {}\\n  password:\\n    env: DAGSTER_PG_PASSWORD\\n  port:
      5432\\n  username:\\\n    \\ postgres\\n\"\n  module_name: dagster_postgres.event_log\nrun_storage:\n  class_name:
      PostgresRunStorage\n  config_yaml: \"postgres_db:\\n  db_name: dagster\\n  hostname:
      postgresql.postgresql\\n\\\n    \\  params: {}\\n  password:\\n    env: DAGSTER_PG_PASSWORD\\n  port:
      5432\\n  username:\\\n    \\ postgres\\n\"\n  module_name: dagster_postgres.run_storage\nschedule_storage:\n  class_name:
      PostgresScheduleStorage\n  config_yaml: \"postgres_db:\\n  db_name: dagster\\n  hostname:
      postgresql.postgresql\\n\\\n    \\  params: {}\\n  password:\\n    env: DAGSTER_PG_PASSWORD\\n  port:
      5432\\n  username:\\\n    \\ postgres\\n\"\n  module_name: dagster_postgres.schedule_storage\n",
      "module_name": "dagster.core.storage.legacy_storage"}}, "pipeline_origin": {"__class__":
      "PipelinePythonOrigin", "pipeline_name": "process_numbers_k8s", "repository_origin":
      {"__class__": "RepositoryPythonOrigin", "code_pointer": {"__class__": "FileCodePointer",
      "fn_name": "defs", "python_file": "workflows/definitions.py", "working_directory":
      "/app"}, "container_context": {"k8s": {"env": [{"name": "USER", "value": "ssup2"}],
      "env_config_maps": ["dagster-dagster-user-deployments-dagster-workflows-user-env"],
      "image_pull_policy": "Always", "namespace": "dagster", "resources": {"limits":
      {"cpu": "1000m", "memory": "2048Mi"}, "requests": {"cpu": "1000m", "memory":
      "2048Mi"}}, "run_k8s_config": {"pod_spec_config": {"automount_service_account_token":
      true}}, "service_account_name": "dagster-dagster-user-deployments-user-deployments"}},
      "container_image": "ghcr.io/ssup2-playground/k8s-data-platform_dagster-workflows:0.4.8",
      "entry_point": ["dagster"], "executable_path": "/usr/local/bin/python3.11"}},
      "pipeline_run_id": "aaa0b6f8-b717-4aef-a4aa-4e1c590b960f", "set_exit_code_on_failure":
      null}'
    env:
    - name: DAGSTER_RUN_JOB_NAME
      value: process_numbers_k8s
    - name: DAGSTER_HOME
      value: /opt/dagster/dagster_home
    - name: DAGSTER_PG_PASSWORD
      valueFrom:
        secretKeyRef:
          key: postgresql-password
          name: dagster-postgresql-secret
    - name: USER
      value: ssup2
    envFrom:
    - configMapRef:
        name: dagster-dagster-user-deployments-dagster-workflows-user-env
```

```yaml {caption="[Text 7] Op/Asset (Step) Config Example"}
spec:
  automountServiceAccountToken: true
  containers:
  - args:
    - dagster
    - api
    - execute_step
    env:
    - name: DAGSTER_COMPRESSED_EXECUTE_STEP_ARGS
      value: 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
    - name: DAGSTER_RUN_JOB_NAME
      value: process_numbers_k8s
    - name: DAGSTER_RUN_STEP_KEY
      value: generate_numbers
    - name: DAGSTER_HOME
      value: /opt/dagster/dagster_home
    - name: DAGSTER_PG_PASSWORD
      valueFrom:
        secretKeyRef:
          key: postgresql-password
          name: dagster-postgresql-secret
    - name: USER
      value: ssup2
    envFrom:
    - configMapRef:
        name: dagster-dagster-user-deployments-dagster-workflows-user-env
```

Although the Container Image is the same, each operates according to its role because the internal Commands and environment variables are different. [Text 5~7] show examples of Commands and environment variables for Code Location Server Pod, Run Pod, and Op/Asset (Step) Pod when using K8s Run Launcher and K8s Job Executor. For Code Location Server, it uses the `dagster api grpc -h 0.0.0.0 -p "3030" -f workflows/definitions.py` Command, and Container Image name and PostgreSQL Password information are set in environment variables.

```json {caption="[Text 8] Op/Asset Uncompressed Config Example"}
{"__class__":"ExecuteStepArgs","instance_ref":{"__class__":"InstanceRef","compute_logs_data":{"__class__":"ConfigurableClassData","class_name":"S3ComputeLogManager","config_yaml":"access_key_id: root\nallow_http: true\nallow_invalid_certificates: true\nbucket: dagster\nendpoint: http://minio.minio:9000\nprefix: compute-log\nregion: default\nsecret_access_key: root123!\n","module_name":"dagster_obstore.s3.compute_log_manager"},"custom_instance_class_data":null,"event_storage_data":{"__class__":"ConfigurableClassData","class_name":"PostgresEventLogStorage","config_yaml":"postgres_db:\n  db_name: dagster\n  hostname: postgresql.postgresql\n  params: {}\n  password:\n    env: DAGSTER_PG_PASSWORD\n  port: 5432\n  username: postgres\n","module_name":"dagster_postgres.event_log"},"local_artifact_storage_data":{"__class__":"ConfigurableClassData","class_name":"LocalArtifactStorage","config_yaml":"base_dir: /opt/dagster/dagster_home\n","module_name":"dagster.core.storage.root"},"run_coordinator_data":{"__class__":"ConfigurableClassData","class_name":"QueuedRunCoordinator","config_yaml":"dequeue_num_workers: 4\ndequeue_use_threads: true\nmax_concurrent_runs: -1\n","module_name":"dagster.core.run_coordinator"},"run_launcher_data":{"__class__":"ConfigurableClassData","class_name":"K8sRunLauncher","config_yaml":"dagster_home: /opt/dagster/dagster_home\nimage_pull_policy: Always\ninstance_config_map: dagster-instance\njob_namespace: dagster\nload_incluster_config: true\npostgres_password_secret: dagster-postgresql-secret\nrun_k8s_config:\n  pod_spec_config:\n    nodeSelector:\n      node-group.dp.ssup2: worker\nservice_account_name: dagster\n","module_name":"dagster_k8s"},"run_storage_data":{"__class__":"ConfigurableClassData","class_name":"PostgresRunStorage","config_yaml":"postgres_db:\n  db_name: dagster\n  hostname: postgresql.postgresql\n  params: {}\n  password:\n    env: DAGSTER_PG_PASSWORD\n  port: 5432\n  username: postgres\n","module_name":"dagster_postgres.run_storage"},"schedule_storage_data":{"__class__":"ConfigurableClassData","class_name":"PostgresScheduleStorage","config_yaml":"postgres_db:\n  db_name: dagster\n  hostname: postgresql.postgresql\n  params: {}\n  password:\n    env: DAGSTER_PG_PASSWORD\n  port: 5432\n  username: postgres\n","module_name":"dagster_postgres.schedule_storage"},"scheduler_data":{"__class__":"ConfigurableClassData","class_name":"DagsterDaemonScheduler","config_yaml":"{}\n","module_name":"dagster.core.scheduler"},"secrets_loader_data":null,"settings":{"run_monitoring":{"enabled":true,"free_slots_after_run_end_seconds":0,"max_resume_run_attempts":0,"poll_interval_seconds":120,"start_timeout_seconds":300},"run_retries":{"enabled":true,"max_retries":2},"schedules":{"num_workers":4,"use_threads":true},"sensors":{"num_workers":4,"use_threads":true},"telemetry":{"enabled":true}},"storage_data":{"__class__":"ConfigurableClassData","class_name":"CompositeStorage","config_yaml":"event_log_storage:\n  class_name: PostgresEventLogStorage\n  config_yaml: \"postgres_db:\\n  db_name: dagster\\n  hostname: postgresql.postgresql\\n\\\n    \\  params: {}\\n  password:\\n    env: DAGSTER_PG_PASSWORD\\n  port: 5432\\n  username:\\\n    \\ postgres\\n\"\n  module_name: dagster_postgres.event_log\nrun_storage:\n  class_name: PostgresRunStorage\n  config_yaml: \"postgres_db:\\n  db_name: dagster\\n  hostname: postgresql.postgresql\\n\\\n    \\  params: {}\\n  password:\\n    env: DAGSTER_PG_PASSWORD\\n  port: 5432\\n  username:\\\n    \\ postgres\\n\"\n  module_name: dagster_postgres.run_storage\nschedule_storage:\n  class_name: PostgresScheduleStorage\n  config_yaml: \"postgres_db:\\n  db_name: dagster\\n  hostname: postgresql.postgresql\\n\\\n    \\  params: {}\\n  password:\\n    env: DAGSTER_PG_PASSWORD\\n  port: 5432\\n  username:\\\n    \\ postgres\\n\"\n  module_name: dagster_postgres.schedule_storage\n","module_name":"dagster.core.storage.legacy_storage"}},"known_state":{"__class__":"KnownExecutionState","dynamic_mappings":{},"parent_state":null,"previous_retry_attempts":{},"ready_outputs":{"__set__":[]},"step_output_versions":[]},"pipeline_origin":{"__class__":"PipelinePythonOrigin","pipeline_name":"process_numbers_k8s","repository_origin":{"__class__":"RepositoryPythonOrigin","code_pointer":{"__class__":"FileCodePointer","fn_name":"defs","python_file":"workflows/definitions.py","working_directory":"/app"},"container_context":{"k8s":{"env":[{"name":"USER","value":"ssup2"}],"env_config_maps":["dagster-dagster-user-deployments-dagster-workflows-user-env"],"image_pull_policy":"Always","namespace":"dagster","resources":{"limits":{"cpu":"1000m","memory":"2048Mi"},"requests":{"cpu":"1000m","memory":"2048Mi"}},"run_k8s_config":{"pod_spec_config":{"automount_service_account_token":true}},"service_account_name":"dagster-dagster-user-deployments-user-deployments"}},"container_image":"ghcr.io/ssup2-playground/k8s-data-platform_dagster-workflows:0.4.8","entry_point":["dagster"],"executable_path":"/usr/local/bin/python3.11"}},"pipeline_run_id":"aaa0b6f8-b717-4aef-a4aa-4e1c590b960f","print_serialized_events":false,"retry_mode":{"__enum__":"RetryMode.DEFERRED"},"should_verify_step":true,"step_keys_to_execute":["generate_numbers"]}
```

For Run Pod, it uses the `dagster api execute_run [config]` Command, and `config` is composed based on information from Dagster Instance and Workflow information received from Code Location Server. For environment variables, Job name and PostgreSQL Password information are set in environment variables. Finally, for Op/Asset (Step) Pod, it uses the `dagster api execute_step [compressed config]` Command, and environment variables include Job name, Op/Asset name, and PostgreSQL Password information. `compressed config` can be checked for original Config values through base64 Decoding and Zlib Decoding, and [Text 8] shows an example of the original Config value.

Custom environment variables set in Code Location Server are also set identically in Run Pod and Op/Asset (Step) Pod. You can see that the `User:ssup2` environment variable set in Code Location Server in [Text 5] is also set identically in the environment variables of Run Pod and Op/Asset (Step) in [Text 6~8]. Therefore, environment variables to be used in Workflows should be set in Code Location Server.

## 3. High Availability

Dagster Components ensure **High Availability** in different ways. They can be largely divided into Components operating as Kubernetes Deployments and Components operating as Kubernetes Jobs.

### 3.1. Kubernetes Deployment Component

{{< table caption="[Table 1] Dagster Kubernetes Deployment Replica Pod " >}}
| Compoment Name | High Availability Method |
|----|----|
| Dagster Web Server | Replica Pods |
| Dagster Daemon | Restarting Pod |
| Code Location Server | Restarting Pods |
| Celery Worker | Replica Pods |
{{< /table >}}

For Dagster Components operating as Kubernetes Deployments, they can be divided into a method that ensures High Availability by creating multiple Replica Pods, and a method that ensures High Availability by configuring to operate only a single Pod and restarting the Pod based on the Pod's Liveness Probe. [Table 1] shows the High Availability methods for Dagster Components operating as Kubernetes Deployments.

### 3.2. Kubernetes Job Component

```text {caption="[Text 9] Dagster Daemon Default Retry Config Example with Dagster Helm Chart"}
dagsterDaemon:
  runRetries:
    enabled: true
    maxRetries: 2
```

```python {caption="[Code 3] Op/Asset Resource Example", linenos=table}
@job(tags={"dagster/max_retries": 3})
def sample_job():
    pass
```

For Runs or Op/Assets operating as Kubernetes Jobs, they do not use the Restart Policy provided by Kubernetes Jobs for High Availability, but instead use Dagster's own Retry Policy feature to perform restarts. [Text 9] shows an example of Dagster Daemon's Default Retry Policy configuration, and [Code 3] shows an example of Op/Asset's Retry Policy configuration.

## 4. External Kubernetes Job Creation

When running Dagster on Kubernetes, Workflow Op/Assets basically operate within Run Kubernetes Jobs or Op/Asset (Step) Kubernetes Jobs managed by Dagster. However, if necessary, Op/Assets can also be configured to execute in separate external Kubernetes Jobs rather than Kubernetes Jobs managed by Dagster. The functions of the Kubernetes Job Client provided by Dagster used at this time are `k8s_job_op()` and `execute_k8s_job()`.

```python {caption="[Code 4] k8s_job_op, execute_k8s_job Example", linenos=table}
echo_hello_job_op = k8s_job_op.configured(
    {
        "image": "busybox",
        "command": ["/bin/sh", "-c"],
        "args": ["echo HELLO"],
        "resources": {
            "requests": {"cpu": "125m", "memory": "256Mi"},
            "limits": {"cpu": "250m", "memory": "512Mi"},
        }
    },
    name="echo_hello_job_op",
)

@op(description="Echo goodbye")
def echo_goodbye_job_k8s(context: OpExecutionContext, Nothing):
    execute_k8s_job(
        context=context,
        image="busybox",
        command=["/bin/sh", "-c"],
        args=["echo GOODBYE"],
        resources={
            "requests": {"cpu": "125m", "memory": "256Mi"},
            "limits": {"cpu": "250m", "memory": "512Mi"},
        }
    )

@job
def process_words_k8s_job():
    echo_goodbye_job_k8s(echo_hello_job_op())
```

[Code 4] shows an example of creating external Kubernetes Jobs using `k8s_job_op()` and `execute_k8s_job()`. Both functions create external Kubernetes Jobs but have different purposes. `k8s_job_op()` is a High Level function used when defining external Kubernetes Jobs along with op creation, and `execute_k8s_job()` is a Low Level function used when creating external Kubernetes Jobs inside op/asset functions. Both functions provide various options to freely define the Spec of external Kubernetes Jobs.

When creating external Kubernetes Jobs with these two functions, the Pod's Spec also inherits the Spec of Run and Op/Asset's Kubernetes Pods. Therefore, settings such as environment variables, Resources, and Node Selector set in Code Location Server are also applied to external Kubernetes Jobs as-is. Stdout/Stderr of created external Kubernetes Jobs can also be viewed in Dagster Web Server. Because of these characteristics, when creating external Kubernetes Jobs, it is recommended to use `k8s_job_op()` and `execute_k8s_job()` provided by Dagster rather than directly using Kubernetes Client.

## 5. References

* Dagster Run Launcher: [https://docs.dagster.io/guides/deploy/execution/run-launchers](https://docs.dagster.io/guides/deploy/execution/run-launchers)
* Dagster Executor: [https://docs.dagster.io/guides/operate/run-executors](https://docs.dagster.io/guides/operate/run-executors)
* Dagster Kubernetes : [https://docs.dagster.io/api/python-api/libraries/dagster-k8s](https://docs.dagster.io/api/python-api/libraries/dagster-k8s)


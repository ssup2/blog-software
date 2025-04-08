---
title: Dagster Architecture on Kubernetes
draft: true
---

Dagster를 Kubernetes 위에서 동작시킬때의 Architecture를 분석한다.

## 1. Control Plane

{{< figure caption="[Figure 1] Dagster K8s Run Launcher + Multiprocess Executor Architecture" src="images/dagster-architecture-k8srunlauncher-multiprocess.png" width="1000px" >}}

[Figure 1]은 Dagster를 Kubernetes 위에서 구성할 경우 기본적인 Architecture를 나타내고 있다. Dagster Control Plane에 위치한 **Dagster Web Server**, **Dagster Daemon**, **Code Location Server**는 언제나 동작하고 있어야하는 Component이기 때문에 모두 Kubernetes의 Deployment를 통해서 Pod로 동작한다. **Run**은 Workflow와 동일한 Lifecycle을 가지며 Workflow가 생성될때 같이 생성되며 Workflow가 종료되는 경우에 같이 종료되기 때문에, Kubernetes Job으로 동작한다. **Dagster Instance**는 Kubernetes의 ConfigMap으로 저장되며, Dagster Control Plane에 위치한 다른 Component들은 Dagster Instance ConfigMap을 참조하여 동작한다.

Code Location Server는 Code Location을 Dagster의 가이드에 따라서 Containerize를 수행한 Server이다. 서로 다른 Dagster Object가 정의된  다수의 Code Location Server가 Control Plane에 위치하여 동작할 수 있으며, Dagster Web Server에서도 **Workspace** 기능을 통해서 Code Location Server 단위로 Dagster Object들을 분리하여 이용할 수 있도록 제공한다. 일반적으로 Project 단위로 Code Location Server를 분리하여 구성한다.

Workflow가 수행되면 Workflow를 담당하는 실질적인 Control Plane Component는 Run이다. 나머지 Control Plane Component는 Run 실행을 위해서 Dagster Instance 및 Code Location Server로 부터 Workflow 설정 정보를 가져와 Run을 실행하는 역할을 수행한다. 실행된 Run은 Workflow를 실행하고 그 결과를 직접 Database에 접근하여 저장한다. 이러한 특징 때문에 Run이 실행된 이후에는 Dagster Control Plane Component (Dagster Web Server, Dagster Daemon, Code Location Server)가 동작하지 않더라도 Workflows는 계속해서 문제 없이 실행이 가능하다. 이는 Workflow 수행에 관계없이 Dagster Control Plane의 Component를 자유롭게 배포할 수 있다는걸 의미한다.

## 2. Run Launcher, Executor

Dagster를 Kubernetes 위에서 동작시키는 경우 3가지 조합의 Run Launcher와 Executor를 이용할 수 있다.

### 1.1. K8s Run Launcher + Multiprocess Executor

**K8s Run Launcher**와 **Multiprocess Executor** 조합은 가장 기본적인 조합이며, [Figure 1]의 Dagster Architecture도 K8s Run Launcher와 Multiprocess Executor 조합을 이용하여 구성되어 있을 경우의 Architecture를 나타내고 있다. K8s Run Launcher는 각 Run을 위한 별도의 Kubernetes Job을 생성하며, Run은 생성된 Kubernetes Job의 Pod에서 실행된다. 이후에 Run은 다수의 Process를 생성하며 Op/Asset을 수행한다.

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

[Text 1]은 K8s Run Launcher와 Multiprocess Executor 조합을 이용하여 Dagster Run을 수행한 경우의 Kubernetes Job과 Pod의 목록을 나타내고 있다. `dagster-run` 문자열으로 시작하는 Kubernetes Job과 Pod가 특정 Run을 위한 Kubernetes Job과 Pod를 나타내며, 실행이 완료된 것을 확인할 수 있다. Workflow가 한번 수행될때마다 수행된 Workflow를 담당하는 Kubernetes Job과 Pod가 생성되며 실행된다. [Text 1]에서는 Dagster Control Plane의 Pod들도 확인할 수 있다.

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
            }
        }
    })
```

K8s Run Launcher가 생성한 Kubernetes Job Pod의 Resource는 Dagster Instance에 Default 값을 지정하거나, 각 Dagster Job마다 정의할 수 있다. [Text 2]는 Dagster Instance에 Default Resource 값을 지정하는 경우의 Config 예시이며, [Code 1]은 각 Dagster Job마다 Tag를 통해서 Resource 값을 정의하는 경우의 Code 예시를 나타내고 있다.

### 1.2. K8s Run Launcher + K8s Job Executor

{{< figure caption="[Figure 2] Dagster K8s Run Launcher + K8s Job Executor Architecture" src="images/dagster-architecture-k8srunlauncher-multiprocess.png" width="1000px" >}}

[Figure 2]는 **K8s Run Launcher**와 **K8s Job Executor**를 조합하여 이용하는 경우의 Architecture를 나타내고 있다. Multiprocess Executor 대신 K8s Job Executor를 이용하는 경우 Run은 각 Op/Asset을 위한 별도의 Kubernetes Job을 생성하여 실행된다. 이러한 특징 때문에 Multiprocess Executor와 비교하여 장단점을 가지고 있다. 다수의 Kubernetes Job을 이용하는 방식이기 때문에 하나의 Workflow가 Kubernetes Cluster의 Resource를 폭넓게 이용할 수 있다는 장점이 있지만, 각 Run을 위한 별도의 Kubernetes Job을 생성하기 때문에 생성 시간으로 인해서 긴 Cold Start 시간이 발생할 수 있다.

반면에 Multiprocess Executor는 하나의 Workflow가 Run Kubernetes Job이 할당받은 Resource 이상을 이용할 수 없다는 단점을 가지고 있지만, 모든 Asset/Op들이 동일한 Kubernetes Job에서 실행되기 때문에 Cold Start가 발생하지 않는 장점을 갖는다. 물론 Multiprocess Executor를 활용해도 Dagster의 External Pipeline 기능을 활용하여 Dagster 외부에서 Workflow를 수행할 수 있으며, 이 경우는 Run Kubernetes Job이 할당받은 Resource와 별개의 Resource를 활용하는 형태이기 때문에 예외 사항이다.

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

[Text 3]은 K8s Run Launcher와 K8s Job Executor 조합을 이용하여 Dagster Run을 수행한 경우의 Kubernetes Job과 Pod의 목록을 나타내고 있다. Multiprocess Executor와 동일하게 `dagster-run` 문자열으로 시작하는 Kubernetes Job과 Pod가 동일하게 존재하며, `dagster-step` 문자열로 시작하는 Kubernetes Job과 Pod도 확인할 수 있다. `dagster-step` 문자열로 시작하는 Kubernetes Job과 Pod가 각 Op/Asset을 위한 Kubernetes Job과 Pod를 나타내며, `STATUS`와 `AGE`를 보면 순차적으로 모두 실행이 완료된 것을 확인할 수 있다.

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

K8s Job Executor를 통해서 생성되는 Kubernetes Job의 Resource는 Dagster Instance에 Default 값을 지정하거나, 각 Dagster Job마다 정의할 수 있다. [Code 2]는 Op/Asset에 Tag를 통해서 Resource 값을 정의하는 경우의 Code 예시를 나타내고 있다.

### 1.3. Celery K8s Run Launcher + Celery K8s Job Executor

{{< figure caption="[Figure 3] Dagster Celery K8s Run Launcher + Celery K8s Job Executor Architecture" src="images/dagster-architecture-k8scelery.png" width="1000px" >}}

[Figure 3]은 **Celery K8s Run Launcher**와 **Celery K8s Job Executor**를 조합을 이용하여 Dagster Run을 수행한 경우의 Architecture를 나타내고 있다. K8s Run Launcher와 동일하게 Celery K8s Run Launcher는 각 Run을 위한 별도의 Kubernetes Job을 생성하여 실행한다. 다만 차이점은 Run에서 Op/Asset 수행을 위해서 Process나 Kubernetes Job을 생성하는 것이 아니라, Celery에게 Op/Asset 처리를 Queuing한다. 이후에 Celery Worker는 Celery에서 Op/Asset을 전달받아 처리한다. 이러한 동작 방식 때문에 Celery K8s Run Launcher를 이용할 경우 반드시 Celery K8s Job Executor를 이용해야 한다.

Op/Asset의 병렬 처리 개수는 Celery Worker의 개수와 동일하다. 만약 Celery Worker의 개수가 5개라면 Op/Asset의 최대 병렬 처리 개수도 5개가 된다. 즉 Celery Worker의 개수를 통해서 Op/Asset의 병렬 처리 개수를 조절할 수 있다. K8s Run Launcher와 K8s Job Executor를 이용하는 경우에는 동시에 많은 Workflow가 실행되면 이에 비례하여 동시에 많은 Op/Asset Pod가 생성되고 실행된다. 이는 Kubernetes Cluster에 많은 부담을 발생시킬 수 있다. 반면에 Celery K8s Run Launcher와 Celery K8s Job Executor를 이용하는 경우에는 동시에 많은 Workflow가 실행되더라도 최대 Celery Worker의 개수 만큼만 Op/Asset Pod가 생성되고 실행되기 때문에 Kubernetes Cluster의 부담을 경감시킬 수 있다.

하지만 Celery K8s Run Launcher와 Celery K8s Job Executor를 이용하기 위해서는 Celery의 Queue로 활용되는 RabbitMQ/Redis와 Celery Worker를 추가적으로 운영해야 하기 때문에 운영의 복잡도는 더 올라가는 단점이 존재한다.

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

[Text 4]는 Celery K8s Run Launcher와 Celery K8s Job Executor 조합을 이용하여 Dagster Run을 수행한 경우의 Kubernetes Job과 Pod의 목록을 나타내고 있다. K8s Run Launcher와 K8s Job Executor를 이용하는 경우와 동일하게 `dagster-run` 문자열로 시작하는 Run을 위한 Kubernetes Job과 Pod가 존재하며, `dagster-step` 문자열로 시작하는 Op/Asset을 위한 Kubernetes Job과 Pod도 확인할 수 있다. 또한 `dagster-celery-workers` 문자열로 시작하는 Celery Worker Pod와 Celery의 Queue로 이용되는 Redis도 확인할 수 있다.

## 2. Configuration Propagation

Code Location Server Pod의 Container Image는 Run, Op/Asset의 Pod에서도 그대로 이용된다. `Code Location Server A` 내부에 있는 Workflow가 Trigger되면 Run, Op/Asset의 Pod는 모두 `Code Location Server A`의 Container Image를 이용하여 동작하며, 유사하게 `Code Location Server B` 내부에 있는 Job이 Trigger되면 Run, Op/Asset의 Pod는 모두 `Code Location Server B`의 Container Image를 이용하여 동작한다. Run Pod와 Op/Asset Pod는 모두 Workflow가 실행될때 동적으로 생성되는 Pod이기 때문에 Code Location Server Pod의 Container Image의 크기가 너무 큰 경우에는 Download 시간으로 인해서 Cold Start 시간이 길어져 Workflow 실행 시간이 길어질 수 있다. 따라서 Code Location Server의 Container Image는 가능한 작은 크기를 갖도록 유지하는 것이 중요하다.

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

Container Image는 동일하지만 내부의 Command와 환경 변수 등이 다르기 때문에 각각의 역할에 맞게 동작한다. [Text 5~7]은 K8s Run Launcher와 K8s Job Executor 이용시 Code Location Server Pod, Run Pod, Op/Asset (Step) Pod의 Command와 환경 변수의 예제를 나타내고 있다. Code Location Server의 경우에는 `dagster api grpc -h 0.0.0.0 -p "3030" -f workflows/definitions.py` Command를 이용하고 있으며, Container Image 이름 및 PostgreSQL Password 정보들이 환경변수에 설정되어 있다.

```json {caption="[Text 8] Op/Asset Uncompressed Config Example"}
{"__class__":"ExecuteStepArgs","instance_ref":{"__class__":"InstanceRef","compute_logs_data":{"__class__":"ConfigurableClassData","class_name":"S3ComputeLogManager","config_yaml":"access_key_id: root\nallow_http: true\nallow_invalid_certificates: true\nbucket: dagster\nendpoint: http://minio.minio:9000\nprefix: compute-log\nregion: default\nsecret_access_key: root123!\n","module_name":"dagster_obstore.s3.compute_log_manager"},"custom_instance_class_data":null,"event_storage_data":{"__class__":"ConfigurableClassData","class_name":"PostgresEventLogStorage","config_yaml":"postgres_db:\n  db_name: dagster\n  hostname: postgresql.postgresql\n  params: {}\n  password:\n    env: DAGSTER_PG_PASSWORD\n  port: 5432\n  username: postgres\n","module_name":"dagster_postgres.event_log"},"local_artifact_storage_data":{"__class__":"ConfigurableClassData","class_name":"LocalArtifactStorage","config_yaml":"base_dir: /opt/dagster/dagster_home\n","module_name":"dagster.core.storage.root"},"run_coordinator_data":{"__class__":"ConfigurableClassData","class_name":"QueuedRunCoordinator","config_yaml":"dequeue_num_workers: 4\ndequeue_use_threads: true\nmax_concurrent_runs: -1\n","module_name":"dagster.core.run_coordinator"},"run_launcher_data":{"__class__":"ConfigurableClassData","class_name":"K8sRunLauncher","config_yaml":"dagster_home: /opt/dagster/dagster_home\nimage_pull_policy: Always\ninstance_config_map: dagster-instance\njob_namespace: dagster\nload_incluster_config: true\npostgres_password_secret: dagster-postgresql-secret\nrun_k8s_config:\n  pod_spec_config:\n    nodeSelector:\n      node-group.dp.ssup2: worker\nservice_account_name: dagster\n","module_name":"dagster_k8s"},"run_storage_data":{"__class__":"ConfigurableClassData","class_name":"PostgresRunStorage","config_yaml":"postgres_db:\n  db_name: dagster\n  hostname: postgresql.postgresql\n  params: {}\n  password:\n    env: DAGSTER_PG_PASSWORD\n  port: 5432\n  username: postgres\n","module_name":"dagster_postgres.run_storage"},"schedule_storage_data":{"__class__":"ConfigurableClassData","class_name":"PostgresScheduleStorage","config_yaml":"postgres_db:\n  db_name: dagster\n  hostname: postgresql.postgresql\n  params: {}\n  password:\n    env: DAGSTER_PG_PASSWORD\n  port: 5432\n  username: postgres\n","module_name":"dagster_postgres.schedule_storage"},"scheduler_data":{"__class__":"ConfigurableClassData","class_name":"DagsterDaemonScheduler","config_yaml":"{}\n","module_name":"dagster.core.scheduler"},"secrets_loader_data":null,"settings":{"run_monitoring":{"enabled":true,"free_slots_after_run_end_seconds":0,"max_resume_run_attempts":0,"poll_interval_seconds":120,"start_timeout_seconds":300},"run_retries":{"enabled":true,"max_retries":2},"schedules":{"num_workers":4,"use_threads":true},"sensors":{"num_workers":4,"use_threads":true},"telemetry":{"enabled":true}},"storage_data":{"__class__":"ConfigurableClassData","class_name":"CompositeStorage","config_yaml":"event_log_storage:\n  class_name: PostgresEventLogStorage\n  config_yaml: \"postgres_db:\\n  db_name: dagster\\n  hostname: postgresql.postgresql\\n\\\n    \\  params: {}\\n  password:\\n    env: DAGSTER_PG_PASSWORD\\n  port: 5432\\n  username:\\\n    \\ postgres\\n\"\n  module_name: dagster_postgres.event_log\nrun_storage:\n  class_name: PostgresRunStorage\n  config_yaml: \"postgres_db:\\n  db_name: dagster\\n  hostname: postgresql.postgresql\\n\\\n    \\  params: {}\\n  password:\\n    env: DAGSTER_PG_PASSWORD\\n  port: 5432\\n  username:\\\n    \\ postgres\\n\"\n  module_name: dagster_postgres.run_storage\nschedule_storage:\n  class_name: PostgresScheduleStorage\n  config_yaml: \"postgres_db:\\n  db_name: dagster\\n  hostname: postgresql.postgresql\\n\\\n    \\  params: {}\\n  password:\\n    env: DAGSTER_PG_PASSWORD\\n  port: 5432\\n  username:\\\n    \\ postgres\\n\"\n  module_name: dagster_postgres.schedule_storage\n","module_name":"dagster.core.storage.legacy_storage"}},"known_state":{"__class__":"KnownExecutionState","dynamic_mappings":{},"parent_state":null,"previous_retry_attempts":{},"ready_outputs":{"__set__":[]},"step_output_versions":[]},"pipeline_origin":{"__class__":"PipelinePythonOrigin","pipeline_name":"process_numbers_k8s","repository_origin":{"__class__":"RepositoryPythonOrigin","code_pointer":{"__class__":"FileCodePointer","fn_name":"defs","python_file":"workflows/definitions.py","working_directory":"/app"},"container_context":{"k8s":{"env":[{"name":"USER","value":"ssup2"}],"env_config_maps":["dagster-dagster-user-deployments-dagster-workflows-user-env"],"image_pull_policy":"Always","namespace":"dagster","resources":{"limits":{"cpu":"1000m","memory":"2048Mi"},"requests":{"cpu":"1000m","memory":"2048Mi"}},"run_k8s_config":{"pod_spec_config":{"automount_service_account_token":true}},"service_account_name":"dagster-dagster-user-deployments-user-deployments"}},"container_image":"ghcr.io/ssup2-playground/k8s-data-platform_dagster-workflows:0.4.8","entry_point":["dagster"],"executable_path":"/usr/local/bin/python3.11"}},"pipeline_run_id":"aaa0b6f8-b717-4aef-a4aa-4e1c590b960f","print_serialized_events":false,"retry_mode":{"__enum__":"RetryMode.DEFERRED"},"should_verify_step":true,"step_keys_to_execute":["generate_numbers"]}
```

Run Pod의 경우에는 `dagster api execute_run [config]` Command를 이용하고 있으며 `config`는 Dagster Instance의 정보과 Code Location Server로부터 받은 Workflow 정보를 기반으로 구성되어 있다. 환경 변수의 경우에는 Job의 이름과 PostgreSQL Password 정보들이 환경 변수에 설정되어 있다. 마지막으로 Op/Asset (Step) Pod의 경우에는 `dagster api execute_step [compressed config]` Command를 이용하고 있으며, 환경 변수에는 Job 이름과 Op/Asset 이름, PostgreSQL Password 정보들이 환경 변수에 설정되어 있다. `compressed config`는 base64 Decoding 및 Zlib Decoding을 통해서 원본 Config 값을 확인할 수 있으며 [Text 8]은 원본 Config 값의 예제를 나타내고 있다.

## 3. High Availability

Dagster의 Component 마다 다른 방식으로 **High Availability**를 보장한다. 크게 Kubernetes Deployment로 Component와 Kubernetes Job으로 동작하는 Component로 구분지을 수 있다.

### 3.1. Kubernetes Deployment Component

{{< table caption="[Table 1] Dagster Kubernetes Deployment Replica Pod " >}}
| Compoment Name | High Availability Method |
|----|----|
| Dagster Web Server | Replica Pods |
| Dagster Daemon | Restarting Pod |
| Code Location Server | Restarting Pods |
| Celery Worker | Replica Pods |
{{< /table >}}

Kubernetes Deployment로 동작하는 Dagster Component의 경우에는 다수의 Replica Pod를 생성하여 High Availability를 보장하는 방식과, 반드시 단일 Pod만 동작하도록 구성하고 Pod의 Livness Probe를 기반으로 Pod 재시작하여 High Availability를 보장하는 방식으로 구분지을 수 있다. [Table 1]은 Kubernetes Deployment로 동작하는 Dagster Component의 High Availability 방식을 나타내고 있다.

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

Kubernetes Job으로 동작하는 Run 또는 Op/Asset의 경우에는 High Availability를 위해서 Kubernetes Job이 제공하는 Restart Policy를 이용하지 않으며, Dagster 자체적으로 제공하는 Retry Policy 기능을 활용하여 재시작을 수행한다. [Text 9]는 Dagster Daemon의 Default Retry Policy 설정 예제를 나타내고 있으며, [Code 3]은 Op/Asset의 Retry Policy 설정 예제를 나타내고 있다.

## 4. External Pipeline

## 5. 참조

* Dagster Run Launcher: [https://docs.dagster.io/guides/deploy/execution/run-launchers](https://docs.dagster.io/guides/deploy/execution/run-launchers)
* Dagster Executor: [https://docs.dagster.io/guides/operate/run-executors](https://docs.dagster.io/guides/operate/run-executors)

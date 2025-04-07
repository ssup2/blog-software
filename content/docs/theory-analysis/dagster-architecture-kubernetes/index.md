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

하지만 Celery K8s Run Launcher와 Celery K8s Job Executor를 이용하기 위해서는 Celery의 Queue로 활용되는 RabbitMQ/Redis와 Celery Worker를 추가적으로 운영해야하영 때문에 운영의 복잡도는 더 올라가는 단점이 존재한다.

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

```text {caption="[Text 2] "}
# Code Location Server Command
dagster api grpc -h 0.0.0.0 -p "3030" -f workflows/definitions.py

# Run Command
dagster api execute_run [configs]

# Step Command
dagster api execute_step [configs]
```

Run을 위한 Kubernetes Job Pod의 Container Image는 Run이 실행하는 Workflow가 정의된 **Code Location Server의 Container Image를 그대로 이용**한다. 따라서 Code Location Server의 Container Image의 크기가 너무 큰 경우에는 Run 실행을 위한 Container Image Download 시간이 길어져 Cold Start 시간도 길어질 수 있다. Container Image는 동일하지만 Command가 다른것윽 확인할 수 있다.

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

```text {caption="[Text 10] "}
dagsterDaemon:
  runRetries:
    enabled: true
    maxRetries: 2
```

```python {caption="[Code 2] Op/Asset Resource Example", linenos=table}
@job(tags={"dagster/max_retries": 3})
def sample_job():
    pass
```

Kubernetes Job으로 동작하는 Run 또는 Op/Asset의 경우에는 High Availability를 위해서 Kubernetes Job이 제공하는 Restart Policy를 이용하지 않으며, Dagster 자체적으로 제공하는 Retry Policy 기능을 활용하여 재시작을 수행한다. 

## 4. 참조

* Dagster Run Launcher: [https://docs.dagster.io/guides/deploy/execution/run-launchers](https://docs.dagster.io/guides/deploy/execution/run-launchers)
* Dagster Executor: [https://docs.dagster.io/guides/operate/run-executors](https://docs.dagster.io/guides/operate/run-executors)

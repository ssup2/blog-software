---
title: Dagster Architecture on Kubernetes
draft: true
---

Dagster를 Kubernetes 위에서 동작시킬때의 Architecture를 분석한다.

## 1. Run Launcher, Executor

Dagster를 Kubernetes 위에서 동작시키는 경우 3가지 조합의 Run Launcher와 Executor를 이용할 수 있다.

### 1.1. K8s Run Launcher + Multiprocess Executor

{{< figure caption="[Figure 1] Dagster K8s Run Launcher + Multiprocess Executor Architecture" src="images/dagster-architecture-k8srunlauncher-multiprocess.png" width="1000px" >}}

K8s Run Launcher와 Multiprocess Executor 조합은 가장 기본적인 조합이다. [Figure 1]은 K8s Run Launcher와 Multiprocess Executor 조합하여 이용하는 경우의 Architecture를 나타내고 있다. Dagster Control Plane에 위치한 Dagster Web Server, Dagster Daemon, Code Location Server는 모두 Kubernetes의 Deployment를 통해서 Pod로 동작한다. Dagster Instance는 Kubernetes의 ConfigMap으로 저장되며, Dagster Control Plane에 위치한 다른 Component들은 Dagster Instance ConfigMap을 참조하여 동작한다.

```yaml {caption="[Text 1] K8s Run Launcher Config in Dagster Instance", linenos=table}
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

K8s Run Launcher는 각 Run을 위한 별도의 Kubernetes Job을 생성하며, Run은 생성된 Kubernetes Job의 Pod에서 실행된다. 이후에 Run은 다수의 Process를 생성하며 Op/Asset을 수행한다. K8s Run Launcher가 생성한 Kubernetes Job Pod의 Resource는 Dagster Instance에 Default 값을 지정하거나, 각 Workflow마다 정의할 수 있다.

### 1.2. K8s Run Launcher + K8s Job Executor

{{< figure caption="[Figure 2] Dagster K8s Run Launcher + K8s Job Executor Architecture" src="images/dagster-architecture-k8srunlauncher-multiprocess.png" width="1000px" >}}

[Figure 2]는 K8s Run Launcher와 K8s Job Executor 조합하여 이용하는 경우의 Architecture를 나타내고 있다. Multiprocess Executor 대신 K8s Job Executor를 이용하는 경우 Run은 각 Op/Asset을 위한 별도의 Kubernetes Job을 생성하여 실행된다. 이러한 특징 때문에 Multiprocess Executor와 비교하여 장단점을 가지고 있다. 다수의 Kubernetes Job을 이용하는 방식이기 때문에 하나의 Workflow가 Kubernetes Cluster의 Resource를 폭넓게 이용할 수 있다는 장점이 있지만, 각 Run을 위한 별도의 Kubernetes Job을 생성하기 때문에 각 Run의 실행 시간이 길어질 수 있다는 단점이 있다. 반면에 Multiprocess Executor는 하나의 Workflow가 Run Kubernetes Job이 할당받은 Resource 이상을 이용할 수 없다는 단점을 가지고 있지만, 모든 Asset/Op들이 동일한 Kubernetes Job에서 실행되기 때문에 빠르게 실행될 수 있는 장점을 갖는다.

```python {caption="[Code 1] Op/Asset Resource Example", linenos=table}
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

### 1.3. Celery K8s Run Launcher + Celery K8s Job Executor

{{< figure caption="[Figure 3] Dagster Celery K8s Run Launcher + Celery K8s Job Executor Architecture" src="images/dagster-architecture-k8scelery.png" width="1000px" >}}

## 2. 설정 전달

### 2.1. Databas서

### 2.2. 환경 변수

### 2.3. Retry Policy

### 2.4. HA

## 3. 참조

* Dagster Run Launcher: [https://docs.dagster.io/guides/deploy/execution/run-launchers](https://docs.dagster.io/guides/deploy/execution/run-launchers)
* Dagster Executor: [https://docs.dagster.io/guides/operate/run-executors](https://docs.dagster.io/guides/operate/run-executors)

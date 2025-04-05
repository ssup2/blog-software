---
title: Dagster Architecture, Object
---

## 1. Dagster Architecture, Object

{{< figure caption="[Figure 1] Dagster Architecture" src="images/dagster-architecture.png" width="1000px" >}}

[Figure 1]은 Dagster Architecture를 나타내고 있다. 사용자가 정의한 Workflow가 존재하는 **Control Plane**과 실제 Workflow가 동작하는 **Data Plane**으로 구분지을 수 있다. Dagster는 Workflow 구성을 위한 다양한 Type의 **Object**를 제공하며, User는 이러한 Object들을 이용하여 Workflow를 구성할 수 있다.

### 1.1. Code Location

 Workflow에 이용되는 대부분의 Dagster Object들은 Control Plane의 **Code Location**에 모두 정의되어 활용된다. 즉 Workflow를 구성하는 User는 Dagster Object들을 정의하고 정의한 Object들을 Code Location에 등록하면, Dagster는 이를 활용하여 Workflow를 구성하고 실행한다. Code Location에 정의되어 이용되는 Dagster Object들은 다음과 같다.

#### 1.1.1. Op, Job

```python {caption="[Code 1] Op, Job Example", linenos=table}
@op(description="Generate a list of numbers from 1 to 10")
def generate_numbers():
    return list(range(1, 11))

@op(description="Filter even numbers from the list")
def filter_even_numbers(numbers):
    return [num for num in numbers if num % 2 == 0]

@op(description="Filter odd numbers from the list")
def filter_odd_numbers(numbers):
    return [num for num in numbers if num % 2 != 0]

@op(description="Calculate the sum of the given list of even numbers")
def sum_even_numbers(numbers):
    return sum(numbers)

@op(description="Calculate the sum of the given list of odd numbers")
def sum_odd_numbers(numbers):
    return sum(numbers)

@op(description="Sum the two numbers")
def sum_two_sums(first_number, second_number):
    return first_number + second_number

@job(description="Process numbers",
    tags={
        "domain": "numbers",
    })
def process_numbers():
    numbers = generate_numbers()
    
    even_numbers = filter_even_numbers(numbers)
    odd_numbers = filter_odd_numbers(numbers)

    even_sum = sum_even_numbers(even_numbers)
    odd_sum = sum_odd_numbers(odd_numbers)

    sum_two_sums(even_sum, odd_sum)
```

**Op**는 Workflow에서 실행되는 가장 작은 단위의 Action을 의미한다. 이러한 Op들을 조합하여 Workflow를 구성할 수 있다. Airflow를 기준으로 하나의 Task가 Dagster에서는 Op에 해당한다. **Job**은 하나의 Workflow를 의미하며 하나 이상의 Op를 포함할 수 있다.

[Code 1]은 Op와 Job의 예제를 나타내고 있다. `generate_numbers`, `filter_even_numbers`, `filter_odd_numbers`, `sum_even_numbers`, `sum_odd_numbers`, `sum_two_numbers` 6개의 Action 함수가 정의되어 있고, `@Op` Decorator를 통해 Op인것을 명시하고 있다. 또한 `process_numbers` Job 함수가 정의되어 있고, `@job` Decorator를 통해 Job 인것을 명시하고 있다. 정의된 Op는 Job 함수 내부에서 DAG 형태로 호출되고 있는것을 확인할 수 있다. Decorator를 통해서 Object 명시와 함께 **Description** 또는 **Tag**등의 다양한 Metadata를 같이 정의할 수 있다.

{{< figure caption="[Figure 2] Dagster Op, Job Example" src="images/dagster-op-job-example.png" width="700px" >}}

[Figure 2]는 [Code 1]의 Op와 Job을 Dagster의 Web Console에서 확인한 모습을 나타내고 있다. 정의된 Op는 Job 함수 내부에서 DAG 형태로 호출되고 있는것을 확인할 수 있다. Dagster에서는 Action 위주의 Workflow를 구성하는것 보다 Data 중심의 Workflow를 구성을 권장하기 때문에 Op보다는 다음에 소개할 Asset을 중심으로 Workflow 구성을 권장한다. 따라서 Op는 Slack 알림/e-mail 알림과 같이 Asset으로 간주하기 어려운 Action들 또는 하나의 Asset 내부에서 너무 많은 Action이 필요할때 Action을 쪼개는 용도로 활용된다.

#### 1.1.2. Asset

```python {caption="[Code 2] Asset Example", linenos=table}
@asset(group_name="numbers",
    description="Generated a list of numbers from 1 to 10",
    kinds=["python"])
def generated_numbers():
    return list(range(1, 11))

@asset(group_name="numbers",
    description="Filtered even numbers from the list",
    kinds=["python"])
def filtered_even_numbers(generated_numbers):
    return [num for num in generated_numbers if num % 2 == 0]

@asset(group_name="numbers",
    description="Filtered odd numbers from the list",
    kinds=["python"])
def filtered_odd_numbers(generated_numbers):
    return [num for num in generated_numbers if num % 2 != 0]

@asset(group_name="numbers",
    description="Summed the even numbers",
    kinds=["python"])
def summed_even_numbers(filtered_even_numbers):
    return sum(filtered_even_numbers)

@asset(group_name="numbers",
    description="Summed the odd numbers",
    kinds=["python"])
def summed_odd_numbers(filtered_odd_numbers):
    return sum(filtered_odd_numbers)

@asset(group_name="numbers",
    description="Summed the two sums",
    kinds=["python"])
def summed_two_sums(summed_even_numbers, summed_odd_numbers):
    return summed_even_numbers + summed_odd_numbers

process_numbers_asset = define_asset_job(
    name="process_numbers_asset",
    selection=AssetSelection.groups("numbers"))
```

Asset은 Workflow 과정중에 생성되는 Data를 의미한다. ETL 과정의 최종 Data 뿐만 아니라 ETL 과정 중간중간 생성되는 Data 또한 Asset으로 정의할 수 있다. 즉 Workflow를 순차적인 Action의 실행이 아닌 Data의 변화 과정으로 이해할 수 있으며, 이 경우 이용되는 Dagster의 Object가 Asset이다.

[Code 2]는 Asset의 예제를 나타내고 있다. `generated_numbers`, `filtered_even_numbers`, `filtered_odd_numbers`, `summed_even_numbers`, `summed_odd_numbers`, `summed_two_numbers` 6개의 Asset 함수가 정의되어 있고, `@asset` Decorator를 통해 Asset인것을 명시한다. [Code 1]의 Op들과 동일한 역할을 수행하지만 Action이 중심이 아닌 Data가 중심이며, Asset 이름도 Data인 `numbers`를 기준으로 수동태가 사용된것을 확인할 수 있다.

Asset과 Op의 문법적인 차이는 Parameter로 Asset을 받는다는 점이다. `filtered_even_numbers`와 `filtered_odd_numbers` asset의 Parameter는 `generated_numbers`로 명시되어 있고 이는 `generated_numbers` asset을 Input으로 받는걸 의미한다. 이와 유사하게 `summed_two_numbers` asset의 Parameter는 `summed_even_numbers`와 `summed_odd_numbers` asset으로 명시되어 있고 이는 `summed_even_numbers`와 `summed_odd_numbers` asset을 Input으로 받는걸 의미한다.

즉 Asset의 Parameter를 통해서 Asset 사이의 의존성을 나타낼 수 있으며, 자연스럽게 DAG 형태로 표현된다. `define_asset_job` 함수는 이러한 Asset들을 하나의 Job으로 변환하는 함수이다. selection은 어떤 Asset들을 포함할지를 명시하며, [Code 2]에서는 `numbers` 그룹에 속한 Asset들을 포함하도록 명시하고 있다.

{{< figure caption="[Figure 3] Dagster Asset Example" src="images/dagster-asset-example.png" width="1000px" >}}

[Figure 3]은 [Code 2]의 Asset을 Dagster의 Web Console에서 확인한 모습을 나타내고 있다. Asset이 DAG 형태로 표현되어 있는것을 확인할 수 있으며, 자연스럽게 Asset의 Lineage가 표현되어 있는것을 확인할 수 있다. Asset의 경우에는 수행 과정을 **Materialize (구체화)** 과정으로 표현한다.

#### 1.1.3. External Resource

**External Resource**는 Dagster에서 지원하는 다양한 외부 리소스를 의미한다. 주로 I/O Manager, 외부 데이터 저장소, BI 도구들을 External Resource로 정의하고 이용한다. External Resource 중에서 **I/O Manager**는 Op 또는 Asset 사이의 데이터를 주고 받는 역할을 수행하기 때문에 중요한 External Resource이다. I/O Manager는 다양한 Backend를 이용할 수 있으며, 지원되는 주요 Backend는 다음과 같다.

* FilesystemIOManager : Local Filesystem에 데이터를 저장한다. 별도로 I/O Manager를 지정하지 않으면 Default I/O Manager로 동작한다.
* InMemoryIOManager : Local Memory에 데이터를 저장한다.
* s3.S3PickleIOManager : AWS S3에 Pickle 형태로 데이터를 저장한다.
* GCSPickleIOManager : GCP GCS에 Pickle 형태로 데이터를 저장한다.
* BigQueryPandasIOManager : BigQuery에 Pandas DataFrame 형태로 데이터를 저장한다.
* BigQueryPySparkIOManager : BigQuery에 PySpark DataFrame 형태로 데이터를 저장한다.

```python {caption="[Code 3] External Resource (I/O Manager) Example", linenos=table}
def get_io_manager():
    return {
        "io_manager": s3_pickle_io_manager.configured({
            "s3_bucket": IO_MANAGER_S3_BUCKET,
            "s3_prefix": IO_MANAGER_S3_PREFIX,
        }),
        "s3": s3_resource.configured({
            "endpoint_url": IO_MANAGER_S3_ENDPOINT_URL,
            "use_ssl": False,
            "aws_access_key_id": IO_MANAGER_S3_ACCESS_KEY_ID,
            "aws_secret_access_key": IO_MANAGER_S3_SECRET_ACCESS_KEY,
        })
```

[Code 3]은 I/O Manager를 정의하는 External Resource 예제를 나타내고 있다. 예제에서는 S3PickleIOManager를 I/O Manager로 이용하고 있고, Backend로 이용할 S3도 External Resource로 정의하고 있다. 설정들은 Python Dictionary 형태로 정의된다.

I/O Manager는 비교적 작은 크기의 데이터를 손쉽게 전달하도록 설계되어 있으며, 몇십 TB 이상의 큰 데이터를 병렬처리를 통해서 빠르게 전달하도록 설계되어 있지는 않다. 따라서 큰 데이터를 주고 받는 경우에는 외부 저장소에 Data를 저장한 이후에 Data가 저장된 경로를 I/O Manager를 통해서 전달하는 방식이 효과적이다. Op 또는 Asset을 수행하는 방식을 결정하는 Run Launcher나 Executor에 따라서 이용할 수 있는 I/O Manager가 제한되기도 한다.

#### 1.1.4. Schedule

```python {caption="[Code 4] Asset Example", linenos=table}
process_numbers_every_minute = ScheduleDefinition(
    job=process_numbers,
    cron_schedule="* * * * *",
)

process_numbers_asset_every_minute = ScheduleDefinition(
    job=process_numbers_asset,
    cron_schedule="* * * * *",
)
```

Schedule은 **cron** 형식의 문법을 이용해서 Workflow를 주기적으로 실행시키는 역할을 수행한다. [Code 3]은 [Code 1]에서 정의한 `process_numbers` Job과 [Code 2]에서 정의한 `process_numbers_asset` Job을 매 분마다 실행시키는 Schedule을 정의한 예제를 나타내고 있다.

#### 1.1.5. Sensor

```python {caption="[Code 5] Sensor Example", linenos=table}
@dg.sensor(
    job=process_numbers,
    minimum_interval_seconds=5,
)
def check_file_sensor():
    if os.path.exists("/check"):
        yield dg.RunRequest(
            run_key="check_file_exists",
        )
    else:
        yield dg.SkipReason("check file not exists")
```

**Sensor**는 외부 조건에 따라서 Workflow를 실행시키는 역할을 수행한다. [Code 4]는 `/check` 파일이 존재하는지 확인하는 Sensor를 정의한 예제를 나타내고 있다. 파일이 존재하면 `process_numbers` Job을 실행시키고, 파일이 존재하지 않으면 `process_numbers` Job을 실행시키지 않는다. `dg.sensor` Decorator를 통해서 Sensor를 정의하고, `job` Parameter를 통해서 실행할 Job을 명시한다. Sensor는 Polling 기반으로 동작하며  `minimum_interval_seconds` Parameter는 Polling 간격을 명시한다.

#### 1.1.6. Definitions

```python {caption="[Code 5] Definitions Example", linenos=table}
defs = Definitions(
    assets=[
        generated_numbers,
        filtered_even_numbers,
        filtered_odd_numbers,
        summed_even_numbers,
        summed_odd_numbers,
        summed_two_sums,
    ],
    jobs=[
        process_numbers,
        process_numbers_k8s,
    ],
    schedules=[
        process_numbers_every_minute,
        process_numbers_asset_every_minute,
    ],
    sensors=[
        check_file_sensor,
    ],
    resources=get_io_manager(),
)
```

Definitions는 Dagster에서 사용되는 모든 Object를 등록하는 역할을 수행한다. [Code 5]는 [Code 1 ~ 4]에서 정의한 Object들을 포함하는 Definitions Object를 정의한 예제를 나타내고 있다. Definitions에 등록되지 않은 Object는 Dagster에서 인식하지 못하기 때문에 반드시 Definitions에 등록해야 한다.

### 1.2. Dagster Instance

```yaml {caption="[File 1] Dagster Instance Example", linenos=table}
scheduler:
  module: dagster.core.scheduler
  class: DagsterDaemonScheduler

schedule_storage:
  module: dagster_postgres.schedule_storage
  class: PostgresScheduleStorage
  config:
    postgres_db:
      username: postgres
      password:
        env: DAGSTER_PG_PASSWORD
      hostname: "postgresql.postgresql"
      db_name: dagster
      port: 5432
      params: {}

run_launcher:
  module: dagster_k8s
  class: K8sRunLauncher
  config:
    load_incluster_config: true
    job_namespace: dagster
    image_pull_policy: Always
    service_account_name: dagster
    dagster_home: "/opt/dagster/dagster_home"
    instance_config_map: "dagster-instance"
    postgres_password_secret: "dagster-postgresql-secret"
    run_k8s_config:
      pod_spec_config:
        nodeSelector:
          node-group.dp.ssup2: worker

run_storage:
  module: dagster_postgres.run_storage
  class: PostgresRunStorage
  config:
    postgres_db:
      username: postgres
      password:
        env: DAGSTER_PG_PASSWORD
      hostname: "postgresql.postgresql"
      db_name: dagster
      port: 5432
      params: {}

event_log_storage:
  module: dagster_postgres.event_log
  class: PostgresEventLogStorage
  config:
    postgres_db:
      username: postgres
      password:
        env: DAGSTER_PG_PASSWORD
      hostname: "postgresql.postgresql"
      db_name: dagster
      port: 5432
      params: {}

run_coordinator:
  module: dagster.core.run_coordinator
  class: QueuedRunCoordinator
  config:
    max_concurrent_runs: -1
    dequeue_use_threads: true
    dequeue_num_workers: 4

compute_logs:
  module: "dagster_obstore.s3.compute_log_manager"
  class: "S3ComputeLogManager"
  config:
    access_key_id: root
    allow_http: true
    allow_invalid_certificates: true
    bucket: dagster
    endpoint: http://minio.minio:9000
    prefix: compute-log
    region: default
    secret_access_key: root123!

run_monitoring:
  enabled: true
  start_timeout_seconds: 300
  max_resume_run_attempts: 0
  poll_interval_seconds: 120
  free_slots_after_run_end_seconds: 0

run_retries:
  enabled: true

sensors:
  use_threads: true
  num_workers: 4

schedules:
  use_threads: true
  num_workers: 4

telemetry:
  enabled: true
```

**Dagster Instance**는 Dagster Control Plane의 모든 설정 정보를 포함하는 Object를 의미하며 내부적으로는 `dagster.yaml` 파일로 형태로 설정 정보를 관리한다. Dagster Control Plane의 모든 Component는 Dagster Instance에 접근하여 설정 정보를 조회하고 사용한다. [File 1]은 Dagster Instance의 예제를 나타내고 있다.

### 1.3. Dagster Database

Database는 Run Storage, Event Storage, Schedule Storage의 역할을 수행하며 Dagster Control Plane의 모든 Component가 접근하여 이용한다. Database 및 각 Storage의 설정정보는 Dagster Instance([File 1])에서 확인할 수 있다.

* Run Storage : 하나의 Run은 하나의 Trigger된 Workflow를 의미하며, Run Storage는 이러한 Run의 상태 정보를 저장하는 저장소이다. 즉 Workflow의 현재 상태나 실행 결과 같은 Run의 메타 정보를 저장하는 역할을 수행한다.
* Event Storage : Event Storage는 Workflow의 실행과정 중에 발생하는 Event를 저장하는 저장소이다.
* Schedule Storage : Workflow Schedule 정보를 저장하는 저장소이다.

### 1.4. Dagster Workflow Trigger

Dagster Web Server, Dagster CLI, Dagster Daemon은 Workflow를 Trigger하는 역할을 수행한다. 3개의 Component 모두 Code Location, Dagster Instance의 정보를 참고하여 Workflow를 Trigger하며, Dagster Instance에 설정된 Storage에 따라서 Trigger된 Workflow의 상태 정보는 Database에 저장된다.

사용자는 Dagster는 Web Server 또는 CLI를 통해서 Workflow를 Trigger를 직접 수행할 수 있으며, Dagster Daemon은 사용자가 Code Location에 정의한 Schedule Object 또는 Sensor Object를 통해서 Job을 Trigger한다. Trigger된 Workflow는 **Run Coordinator**에 Scheduling 과정을 거쳐 **Run Launcher**에 의해서 **Run**이 생성되고, Run 내부에서는 **Executor**를 통해서 하나씩 Op 또는 Asset이 실행되며 Workflow가 수행된다.

하나의 Run은 하나의 Trigger된 Workflow를 의미하며, Workflow가 종료되면 종료된 Workflow를 담당하는 Run도 같이 종료된다. Run이 실제적인 Workflow의 Control Plane 역할을 수행하며, Op 또는 Asset을 Executor를 통해서 DAG 형태로 순차적으로 수행한다. Run은 Run Launcher에 의해서 생성된다. Dagster는 몇가지 Type의 Run Launcher와 Executor를 제공하며 설정된 Run Launcher와 Executor에 따라서 Workflow가 수행되는 방식이 결정된다.

Run Launcher는 Dagster Instance([File 1])에 설정되며, Dagster가 지원하는 Run Launcher는 다음과 같다.

* K8sRunLauncher : Run이 Kubernetes의 Job (Pod) 형태로 실행된다. 
* ecs.EcsRunLauncher : Run이 AWS ECS의 Task 형태로 실행된다.
* DockerRunLauncher : Run이 Docker Container 형태로 실행된다.
* CeleryK8sRunLauncher : Run이 Celery를 이용하여 Kubernetes의 Job (Pod) 형태로 실행된다.

Dagster가 지원하는 주요 Executor는 다음과 같다.

* in_process_executor : Op/Asset이 하나의 Process 내부에서 순차적으로 실행된다.
* multiprocess_executor : Op/Asset이 다수의 Process 내부에서 병렬로 실행된다.
* celery_executor : Op/Asset이 Celery를 이용하여 병렬로 실행된다.
* docker_executor : Op/Asset이 Docker Container를 이용하여 병렬로 실행된다.
* k8s_job_executor : Op/Asset이 Kubernetes Job을 이용하여 병렬로 실행된다.
* celery_k8s_job_executor : Op/Asset이 Celery와 Kubernetes Job을 이용하여 병렬로 실행된다.

Run Coordinator는 Workflow Scheduling을 수행하며 Dagster Instance([File 1])에 설정된다. Dagster에서 지원하는 Run Coordinator는 다음과 같다.

* DefaultRunCoordinator : Workflow 생성 요청이 오면 즉시 Run Launcher를 호출하여 Run을 생성한다. Dagster Web Server와 Dagster CLI에서 이용된다.
* QueuedRunCoordinator : Workflow 생성 요청이 오면 요청을 Queue에 저장한다음 규칙에 맞게 가져와 Run을 생성한다. Dagster Daemon에서 이용된다. QueuedRunCoordinator를 이용하도록 설정되어 있으면 Dagster Web Server는 Workflow 생성 요청을 직접 처리하지 않고 Dagster Daemon에게 전달한다.

Dagster Daemon은 Dagster 운영에 필수적인 Component는 아니며, Dagster Daemon이 없으면 Schedule Object, Sensor Object와 QueuedRunCoordinator를 이용하지 못하지만 Workflow 실행에는 문제가 없다.

### 1.5. Compute Log

Compute Log는 Dagster에서 실행되는 Op 또는 Asset의 실행 로그를 저장하는 역할을 수행한다. Compute Log는 Dagster Instance([File 1])에 설정된다. Dagster에서 지원하는 Compute Log는 다음과 같다.

* LocalComputeLogManager : Local Filesystem에 Compute Log를 저장한다.
* NoOpComputeLogManager : Compute Log를 저장하지 않는다.
* S3ComputeLogManager : AWS S3에 Compute Log를 저장한다.
* AzureComputeLogManager : Azure Blob Storage에 Compute Log를 저장한다.
* GCSComputeLogManager : Google Cloud Storage에 Compute Log를 저장한다.

## 2. 참조

* Dagster Architecture : [https://docs.dagster.io/guides/deploy/oss-deployment-architecture](https://docs.dagster.io/guides/deploy/oss-deployment-architecture)
* Dagster Concepts : [https://docs.dagster.io/getting-started/concepts](https://docs.dagster.io/getting-started/concepts)
* Dagster Code Location : [https://dagster.io/blog/dagster-code-locations](https://dagster.io/blog/dagster-code-locations)
* Dagster Internals : [https://docs.dagster.io/api/python-api/internals](https://docs.dagster.io/api/python-api/internals)
* Dagster Run Launcher : [https://docs.dagster.io/guides/deploy/execution/run-launchers](https://docs.dagster.io/guides/deploy/execution/run-launchers)
* Dagster Executor : [https://docs.dagster.io/guides/operate/run-executors](https://docs.dagster.io/guides/operate/run-executors)
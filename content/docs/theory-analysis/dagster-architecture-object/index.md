---
title: Dagster Architecture, Object
draft: true
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

#### 1.1.3. I/O Manager

I/O Manager는 Op 또는 Asset 사이의 데이터를 주고 받는 역할을 수행한다. 다양한 Backend를 지원하며, 지원하는 주요 Backend는 다음과 같다.

* FilesystemIOManager : Local Filesystem에 데이터를 저장한다. 별도로 I/O Manager를 지정하지 않으면 Default I/O Manager로 동작한다.
* InMemoryIOManager : Local Memory에 데이터를 저장한다.
* s3.S3PickleIOManager : AWS S3에 Pickle 형태로 데이터를 저장한다.
* GCSPickleIOManager : GCP GCS에 Pickle 형태로 데이터를 저장한다.
* BigQueryPandasIOManager : BigQuery에 Pandas DataFrame 형태로 데이터를 저장한다.
* BigQueryPySparkIOManager : BigQuery에 PySpark DataFrame 형태로 데이터를 저장한다.

I/O Manager는 비교적 작은 크기의 데이터를 손쉽게 전달하도록 설계되어 있으며, 몇십 TB 이상의 큰 데이터를 병렬처리를 통해서 빠르게 전달하도록 설계되어 있지는 않다. 따라서 큰 데이터를 주고 받는 경우에는 외부 저장소에 Data를 저장한 이후에 Data가 저장된 경로를 I/O Manager를 통해서 전달하는 방식이 효과적이다. Op 또는 Asset을 수행하는 방식을 결정하는 Run Launcher나 Executor에 따라서 이용할 수 있는 I/O Manager가 제한되기도 한다.

#### 1.1.4. Schedule

```python {caption="[Code 3] Asset Example", linenos=table}
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

```python {caption="[Code 4] Sensor Example", linenos=table}

```

#### 1.1.6. Definitions

```python {caption="[Code 5] Definitions Example", linenos=table}

```

### 1.2. Dagster Instance

```yaml {caption="[File 1] Dagster Instance Example", linenos=table}
local_artifact_storage:
  module: dagster._core.storage.root
  class: LocalArtifactStorage
  config:
    base_dir: /opt/dagster/dagster_home
run_storage:
  module: dagster_postgres.run_storage
  class: PostgresRunStorage
  config:
    postgres_db:
      db_name: dagster
      hostname: postgresql.postgresql
      params: {}
      password:
        env: DAGSTER_PG_PASSWORD
      port: 5432
      username: postgres
event_log_storage:
  module: dagster_postgres.event_log
  class: PostgresEventLogStorage
  config:
    postgres_db:
      db_name: dagster
      hostname: postgresql.postgresql
      params: {}
      password:
        env: DAGSTER_PG_PASSWORD
      port: 5432
      username: postgres
compute_logs: NoneType
schedule_storage:
  module: dagster_postgres.schedule_storage
  class: PostgresScheduleStorage
  config:
    postgres_db:
      db_name: dagster
      hostname: postgresql.postgresql
      params: {}
      password:
        env: DAGSTER_PG_PASSWORD
      port: 5432
      username: postgres
scheduler:
  module: dagster._core.scheduler
  class: DagsterDaemonScheduler
  config: {}
run_coordinator:
  module: dagster._core.run_coordinator
  class: QueuedRunCoordinator
  config:
    dequeue_num_workers: 4
    dequeue_use_threads: true
    max_concurrent_runs: -1
run_launcher:
  module: dagster_k8s
  class: K8sRunLauncher
  config:
    dagster_home: /opt/dagster/dagster_home
    image_pull_policy: Always
    instance_config_map: dagster-instance
    job_namespace: dagster
    load_incluster_config: true
    postgres_password_secret: dagster-postgresql-secret
    run_k8s_config:
      pod_spec_config:
        nodeSelector:
          node-group.dp.ssup2: worker
    service_account_name: dagster
run_retries:
  enabled: true
sensors:
  use_threads: true
  num_workers: 4
telemetry:
  enabled: true
run_monitoring:
  enabled: true
  start_timeout_seconds: 300
  max_resume_run_attempts: 0
  poll_interval_seconds: 120
  free_slots_after_run_end_seconds: 0
schedules:
  use_threads: true
  num_workers: 4
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

하나의 Run은 하나의 Trigger된 Workflow를 의미하며, Workflow가 종료되면 종료된 Workflow를 담당하는 Run도 같이 종료된다. Run이 실제적인 Workflow의 Control Plane 역할을 수행하며, Op 또는 Asset을 Executor를 통해서 DAG 형태로 수행한다. Run은 Run Launcher에 의해서 생성이 되며, Run Launcher와 Executor의 설정에 따라서 Workflow가 수행되는 방식이 결정된다.

Dagster는 Dagit이라는 이름의 Web Server를 제공하여 Dagster를 **Web 기반의 UI**를 통해서 제어할 수 있는 환경을 제공한다. 또한 Dagster의 상태를 제어하고 조회할 수 있는 **GraphQL API**를 제공하는 역활도 수행한다.

## 2. 참조

* Dagster Architecture : [https://docs.dagster.io/guides/deploy/oss-deployment-architecture](https://docs.dagster.io/guides/deploy/oss-deployment-architecture)
* Dagster Concepts : [https://docs.dagster.io/getting-started/concepts](https://docs.dagster.io/getting-started/concepts)
* Dagster Code Location : [https://dagster.io/blog/dagster-code-locations](https://dagster.io/blog/dagster-code-locations)
* Dagster Internals : [https://docs.dagster.io/api/python-api/internals](https://docs.dagster.io/api/python-api/internals)
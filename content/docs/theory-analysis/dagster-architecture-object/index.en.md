---
title: Dagster Architecture, Object
---

## 1. Dagster Architecture, Object

{{< figure caption="[Figure 1] Dagster Architecture" src="images/dagster-architecture.png" width="1000px" >}}

[Figure 1] shows the Dagster Architecture. It can be divided into the **Control Plane**, where user-defined workflows exist, and the **Data Plane**, where workflows actually run. Dagster provides various types of **Objects** for workflow composition, and users can compose workflows using these Objects.

### 1.1. Code Location

Most Dagster Objects used in workflows are all defined and utilized in the **Code Location** of the Control Plane. That is, users who compose workflows define Dagster Objects and register them in Code Location, and Dagster uses them to compose and execute workflows. The Dagster Objects defined and used in Code Location are as follows.

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

**Op** represents the smallest unit of action executed in a workflow. Workflows can be composed by combining these Ops. In Airflow terms, a Task corresponds to an Op in Dagster. **Job** represents a single workflow and can contain one or more Ops.

[Code 1] shows an example of Op and Job. Six action functions are defined: `generate_numbers`, `filter_even_numbers`, `filter_odd_numbers`, `sum_even_numbers`, `sum_odd_numbers`, `sum_two_numbers`, and they are marked as Ops through the `@op` decorator. Also, a `process_numbers` Job function is defined and marked as a Job through the `@job` decorator. You can see that the defined Ops are called in DAG form within the Job function. Through decorators, you can define various metadata such as **Description** or **Tags** along with Object specification.

{{< figure caption="[Figure 2] Dagster Op, Job Example" src="images/dagster-op-job-example.png" width="700px" >}}

[Figure 2] shows the Op and Job from [Code 1] viewed in Dagster's Web Console. You can see that the defined Ops are called in DAG form within the Job function. Dagster recommends composing workflows centered on Data rather than Action-oriented workflows, so it recommends composing workflows centered on Assets, which will be introduced next, rather than Ops. Therefore, Ops are used for actions that are difficult to consider as Assets, such as Slack notifications/e-mail notifications, or for splitting actions when too many actions are needed within a single Asset.

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

Asset refers to data created during the workflow process. Not only the final data in the ETL process but also intermediate data created during the ETL process can be defined as Assets. That is, workflows can be understood as a process of data transformation rather than sequential execution of actions, and the Dagster Object used in this case is Asset.

[Code 2] shows an example of Assets. Six Asset functions are defined: `generated_numbers`, `filtered_even_numbers`, `filtered_odd_numbers`, `summed_even_numbers`, `summed_odd_numbers`, `summed_two_numbers`, and they are marked as Assets through the `@asset` decorator. They perform the same role as the Ops in [Code 1], but are centered on Data rather than Action, and you can see that the Asset names use passive voice based on the data `numbers`.

The grammatical difference between Assets and Ops is that Assets receive other Assets as parameters. The parameters of the `filtered_even_numbers` and `filtered_odd_numbers` assets are specified as `generated_numbers`, which means they receive the `generated_numbers` asset as input. Similarly, the parameters of the `summed_two_numbers` asset are specified as `summed_even_numbers` and `summed_odd_numbers` assets, which means they receive the `summed_even_numbers` and `summed_odd_numbers` assets as inputs.

That is, dependencies between Assets can be expressed through Asset parameters, and they are naturally expressed in DAG form. The `define_asset_job` function converts these Assets into a single Job. Selection specifies which Assets to include, and [Code 2] specifies to include Assets belonging to the `numbers` group.

{{< figure caption="[Figure 3] Dagster Asset Example" src="images/dagster-asset-example.png" width="1000px" >}}

[Figure 3] shows the Assets from [Code 2] viewed in Dagster's Web Console. You can see that Assets are expressed in DAG form, and the Asset lineage is naturally expressed. For Assets, the execution process is expressed as a **Materialize** process.

#### 1.1.3. External Resource

**External Resource** refers to various external resources supported by Dagster. Mainly I/O Managers, external data storage, and BI tools are defined and used as External Resources. Among External Resources, **I/O Manager** is an important External Resource because it handles data transfer between Ops or Assets. I/O Manager can use various backends, and the main supported backends are as follows.

* FilesystemIOManager : Stores data in the local filesystem. If no I/O Manager is specified separately, it operates as the default I/O Manager.
* InMemoryIOManager : Stores data in local memory.
* s3.S3PickleIOManager : Stores data in Pickle format on AWS S3.
* GCSPickleIOManager : Stores data in Pickle format on GCP GCS.
* BigQueryPandasIOManager : Stores data in Pandas DataFrame format on BigQuery.
* BigQueryPySparkIOManager : Stores data in PySpark DataFrame format on BigQuery.

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

[Code 3] shows an example of defining an I/O Manager as an External Resource. The example uses S3PickleIOManager as the I/O Manager and also defines S3 used as the backend as an External Resource. Settings are defined in Python dictionary format.

I/O Manager is designed to easily transfer relatively small-sized data and is not designed to quickly transfer very large data of several tens of TB or more through parallel processing. Therefore, when transferring large data, it is effective to store the data in external storage first and then pass the path where the data is stored through the I/O Manager. The I/O Managers that can be used may be limited depending on the Run Launcher or Executor that determines how Ops or Assets are executed.

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

Schedule performs the role of periodically executing workflows using **cron** format syntax. [Code 3] shows an example of defining a Schedule that executes the `process_numbers` Job defined in [Code 1] and the `process_numbers_asset` Job defined in [Code 2] every minute.

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

**Sensor** performs the role of executing workflows based on external conditions. [Code 4] shows an example of defining a Sensor that checks whether the `/check` file exists. If the file exists, it executes the `process_numbers` Job, and if the file does not exist, it does not execute the `process_numbers` Job. The Sensor is defined through the `dg.sensor` decorator, and the Job to execute is specified through the `job` parameter. Sensors operate based on polling, and the `minimum_interval_seconds` parameter specifies the polling interval.

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

Definitions performs the role of registering all Objects used in Dagster. [Code 5] shows an example of defining a Definitions Object that includes the Objects defined in [Code 1 ~ 4]. Objects not registered in Definitions are not recognized by Dagster, so they must be registered in Definitions.

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

**Dagster Instance** refers to an Object that contains all configuration information for the Dagster Control Plane, and internally manages configuration information in the form of a `dagster.yaml` file. All Components of the Dagster Control Plane access the Dagster Instance to retrieve and use configuration information. [File 1] shows an example of a Dagster Instance.

### 1.3. Dagster Database

Database performs the roles of Run Storage, Event Storage, and Schedule Storage, and all Components of the Dagster Control Plane access and use it. Configuration information for Database and each Storage can be found in the Dagster Instance ([File 1]).

* Run Storage : A single Run represents a single triggered workflow, and Run Storage is a storage that stores state information of such Runs. That is, it stores metadata of Runs such as the current state or execution results of workflows.
* Event Storage : Event Storage is a storage that stores Events that occur during workflow execution.
* Schedule Storage : Storage that stores workflow schedule information.

### 1.4. Dagster Workflow Trigger

Dagster Web Server, Dagster CLI, and Dagster Daemon perform the role of triggering workflows. All three Components trigger workflows by referencing Code Location and Dagster Instance information, and state information of triggered workflows is stored in the Database according to the Storage configured in the Dagster Instance.

Users can directly trigger workflows through Dagster Web Server or CLI, and Dagster Daemon triggers Jobs through Schedule Objects or Sensor Objects defined by users in Code Location. Triggered workflows go through a scheduling process in the **Run Coordinator** and a **Run** is created by the **Run Launcher**, and within the Run, Ops or Assets are executed one by one through the **Executor**, and the workflow is performed.

```python {caption="[Code 6] Setting Executor Example", linenos=table}
@job(executor_def=multiprocess_executor)
def process_numbers():
...

process_numbers_asset_k8s = define_asset_job(
    name="process_numbers_asset_k8s",
    selection=AssetSelection.groups("numbers"),
    executor_def=k8s_job_executor)
```

A single Run represents a single triggered workflow, and when the workflow ends, the Run responsible for the ended workflow also ends. Run performs the actual Control Plane role of the workflow and executes Ops or Assets sequentially in DAG form through the Executor. Run is created by the Run Launcher. Dagster provides several types of Run Launchers and Executors, and the way workflows are executed depends on the configured Run Launcher and Executor. In a single Dagster Cluster, only one Run Launcher Type configured in the Dagster Instance ([File 1]) can be used, and Executors can be configured and used for each Workflow (Job). [Code 6] shows an example of setting an Executor. You can see that it is set through the `executor_def` parameter of the Job.

The Run Launcher Types supported by Dagster are as follows.

* K8sRunLauncher : Run is executed as a Kubernetes Job (Pod).
* ecs.EcsRunLauncher : Run is executed as an AWS ECS Task.
* DockerRunLauncher : Run is executed as a Docker Container.
* CeleryK8sRunLauncher : Run is executed as a Kubernetes Job (Pod) using Celery.

The main Executors supported by Dagster are as follows.

* in_process_executor : Ops/Assets are executed sequentially within a single process.
* multiprocess_executor : Ops/Assets are executed in parallel within multiple processes.
* celery_executor : Ops/Assets are executed in parallel using Celery.
* docker_executor : Ops/Assets are executed in parallel using Docker Containers.
* k8s_job_executor : Ops/Assets are executed in parallel using Kubernetes Jobs.
* celery_k8s_job_executor : Ops/Assets are executed in parallel using Celery and Kubernetes Jobs.

Run Coordinator performs workflow scheduling and is configured in the Dagster Instance ([File 1]). The Run Coordinators supported by Dagster are as follows.

* DefaultRunCoordinator : When a workflow creation request comes in, it immediately calls the Run Launcher to create a Run. Used in Dagster Web Server and Dagster CLI.
* QueuedRunCoordinator : When a workflow creation request comes in, it stores the request in a queue and then retrieves it according to rules to create a Run. Used in Dagster Daemon. If configured to use QueuedRunCoordinator, Dagster Web Server does not directly process workflow creation requests but passes them to Dagster Daemon.

Dagster Daemon is not an essential Component for Dagster operation. If Dagster Daemon is not present, Schedule Objects, Sensor Objects, and QueuedRunCoordinator cannot be used, but workflow execution is not affected.

### 1.5. Compute Log

Compute Log performs the role of storing execution logs of Ops or Assets executed in Dagster. Compute Log is configured in the Dagster Instance ([File 1]). The Compute Logs supported by Dagster are as follows.

* LocalComputeLogManager : Stores Compute Log in the local filesystem.
* NoOpComputeLogManager : Does not store Compute Log.
* S3ComputeLogManager : Stores Compute Log on AWS S3.
* AzureComputeLogManager : Stores Compute Log on Azure Blob Storage.
* GCSComputeLogManager : Stores Compute Log on Google Cloud Storage.

## 2. References

* Dagster Architecture : [https://docs.dagster.io/guides/deploy/oss-deployment-architecture](https://docs.dagster.io/guides/deploy/oss-deployment-architecture)
* Dagster Concepts : [https://docs.dagster.io/getting-started/concepts](https://docs.dagster.io/getting-started/concepts)
* Dagster Code Location : [https://dagster.io/blog/dagster-code-locations](https://dagster.io/blog/dagster-code-locations)
* Dagster Internals : [https://docs.dagster.io/api/python-api/internals](https://docs.dagster.io/api/python-api/internals)
* Dagster Run Launcher : [https://docs.dagster.io/guides/deploy/execution/run-launchers](https://docs.dagster.io/guides/deploy/execution/run-launchers)
* Dagster Executor : [https://docs.dagster.io/guides/operate/run-executors](https://docs.dagster.io/guides/operate/run-executors)


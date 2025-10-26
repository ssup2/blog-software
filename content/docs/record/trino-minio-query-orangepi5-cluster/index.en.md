---
title : Trino MinIO Query Execution / Orange Pi 5 Max Cluster Environment
---

Query data stored in MinIO through Trino.

## 1. Practice Environment Setup

### 1.1. Overall Practice Environment

{{< figure caption="[Figure 1] Trino, Hive Metastore Integration Environment" src="images/environment.png" width="1000px" >}}

The practice environment for querying data stored in MinIO through Trino is as shown in [Figure 1].

* **MinIO** : Performs the role of Object Storage for storing data. Stores Airport Data and South Korea Weather Data.
  * **Airport Data** : Stored in CSV format.
  * **South Korea Weather Data** : Stored partitioned by time in 3 data formats: CSV, Parquet, Iceberg.
* **Trino** : Performs the role of querying data stored in MinIO.
* **Hive Metastore** : Manages schema information of data and provides schema information to Trino.
* **Dagster** : Executes data pipeline to transform South Korea Weather Data in MinIO and store it back in MinIO.
* **DBeaver** : Performs the role of a client for connecting to Trino and executing queries.

Refer to the following links for the overall practice environment setup.

* Orange Pi 5 Max based Kubernetes Cluster Construction : [https://ssup2.github.io/blog-software/docs/record/orangepi5-cluster-build/](https://ssup2.github.io/blog-software/docs/record/orangepi5-cluster-build/)
* Orange Pi 5 Max based Kubernetes Data Platform Construction : [https://ssup2.github.io/blog-software/docs/record/kubernetes-data-platform-orangepi5-cluster/](https://ssup2.github.io/blog-software/docs/record/kubernetes-data-platform-orangepi5-cluster/)
* Dagster Workflow Github : [https://github.com/ssup2-playground/k8s-data-platform_dagster-workflows](https://github.com/ssup2-playground/k8s-data-platform_dagster-workflows)

### 1.2. Hive Metastore Main Configuration

```yaml
catalogs:
  hive: |
    connector.name=hive
    hive.metastore.uri=thrift://hive-metastore.hive-metastore:9083
    hive.partition-projection-enabled=true
    fs.native-s3.enabled=true
    s3.endpoint=http://minio.minio:9000
    s3.region=default
    s3.aws-access-key=root
    s3.aws-secret-key=root123!
    s3.path-style-access=true
  iceberg: |
    connector.name=iceberg
    hive.metastore.uri=thrift://hive-metastore.hive-metastore:9083
    fs.native-s3.enabled=true
    s3.endpoint=http://minio.minio:9000
    s3.region=default
    s3.aws-access-key=root
    s3.aws-secret-key=root123!
    s3.path-style-access=true
```

Configure Hive Catalog for CSV and Parquet data formats and Iceberg Catalog for Iceberg data format in the Hive Metastore Helm Chart.

### 1.3. MinIO CLI Client Configuration

```shell
brew install minio/stable/mc
mc alias set dp http://$(kubectl -n minio get service minio -o jsonpath="{.status.loadBalancer.ingress[0].ip}"):9000 root root123!
```

Install MinIO CLI Client.

## 2. Trino Connection

```shell
kubectl -n trino get service trino --output jsonpath='{.status.loadBalancer.ingress[0].ip}'
```
```shell
192.168.1.87
```

Check the external IP address of the Trino service.

{{< figure caption="[Figure 1] Select Trino in DBeaver" src="images/dbeaver-trino-database-select.png" width="800px" >}}

Add a new database in DBeaver and select Trino.

{{< figure caption="[Figure 2] Enter Trino Connection Information" src="images/dbeaver-trino-connection-setting.png" width="800px" >}}

Enter the external IP of the Trino service and username. Any string can be entered for the username, and the password must be left blank.

## 3. Single Object Query Execution

### 3.1. Schema, Table Creation

```sql
CREATE SCHEMA hive.airport;

CREATE TABLE hive.airport.codes (
	ident VARCHAR,
	type  VARCHAR,
	name  VARCHAR,
	elevation_ft VARCHAR,
	continent    VARCHAR,
	iso_country	 VARCHAR,
	iso_region	 VARCHAR,
	municipality VARCHAR,
	gps_code	 VARCHAR,
	iata_code	 VARCHAR,
	local_code	 VARCHAR,
	coordinates  VARCHAR
)
WITH (
	external_location = 's3a://airport/codes/',
	format = 'CSV'
);
```

Create an Airport schema and Airport Code table based on objects stored in MinIO. All data stored in CSV format is declared as `VARCHAR` type.

### 3.2. Data Loading

```shell
wget https://raw.githubusercontent.com/datasets/airport-codes/refs/heads/main/data/airport-codes.csv
mc mb dp/airport/codes
mc cp airport-codes.csv dp/airport/codes/data.csv
```

Load sample data into MinIO through the MinIO CLI client.

### 3.3. Data Query

```sql
select * from hive.airport.codes;
```

{{< figure caption="[Figure 3] Query `airport.codes` Table Data in Trino" src="images/dbeaver-trino-airport-query-select.png" width="900px" >}}

Query data loaded in the `airport.codes` table.

## 4. Partition Object Query Execution

### 4.1. Schema, Table Creation

```sql
CREATE SCHEMA hive.weather;
```

Create a Weather schema.

```sql
CREATE TABLE hive.weather.southkorea_hourly_csv (
  branch_name VARCHAR,

  temp VARCHAR,
  rain VARCHAR,
  snow VARCHAR,

  cloud_cover_total     VARCHAR,
  cloud_cover_lowmiddle VARCHAR,
  cloud_lowest          VARCHAR,
  cloud_shape           VARCHAR,

  humidity       VARCHAR,
  wind_speed     VARCHAR,
  wind_direction VARCHAR,
  pressure_local VARCHAR,
  pressure_sea   VARCHAR,
  pressure_vaper VARCHAR,
  dew_point      VARCHAR,

	year  VARCHAR,
  month VARCHAR,
  day   VARCHAR,
  hour  VARCHAR
)
WITH (
	external_location = 's3a://weather/southkorea/hourly-csv',
	format = 'CSV',
	partitioned_by = ARRAY['year', 'month', 'day', 'hour'],
  skip_header_line_count = 1
);
```

Create a `southkorea_hourly_csv` table based on partitioned CSV format objects stored in MinIO. All data stored in CSV format is declared as `VARCHAR` type. For CSV format, all data is declared as `VARCHAR` type. The first header line is ignored through the `skip_header_line_count` setting.

```sql
CREATE TABLE hive.weather.southkorea_hourly_parquet (
  branch_name VARCHAR,

  temp DOUBLE,
  rain DOUBLE,
  snow DOUBLE,

  cloud_cover_total     INT,
  cloud_cover_lowmiddle INT,
  cloud_lowest          INT,
  cloud_shape           VARCHAR,

  humidity       INT,
  wind_speed     DOUBLE,
  wind_direction VARCHAR,
  pressure_local DOUBLE,
  pressure_sea   DOUBLE,
  pressure_vaper DOUBLE,
  dew_point      DOUBLE,    

  year  INT,
  month INT,
  day   INT,
  hour  INT
)
WITH (
	external_location = 's3a://weather/southkorea/hourly-parquet',
	format = 'PARQUET',
	partitioned_by = ARRAY['year', 'month', 'day', 'hour']
);
```

Create a `southkorea_hourly_parquet` table based on partitioned Parquet format objects stored in MinIO.

```sql
CREATE TABLE iceberg.weather.southkorea_hourly_iceberg_parquet (
  branch_name VARCHAR,

  temp DOUBLE,
  rain DOUBLE,
  snow DOUBLE,

  cloud_cover_total     INT,
  cloud_cover_lowmiddle INT,
  cloud_lowest          INT,
  cloud_shape           VARCHAR,

  humidity       INT,
  wind_speed     DOUBLE,
  wind_direction VARCHAR,
  pressure_local DOUBLE,
  pressure_sea   DOUBLE,
  pressure_vaper DOUBLE,
  dew_point      DOUBLE,    

  year  INT,
  month INT,
  day   INT,
  hour  INT
)
WITH (
	location = 's3a://weather/southkorea/hourly-iceberg-parquet',
	format = 'PARQUET',
	partitioning = ARRAY['year', 'month', 'day', 'hour']
);
```

Create a `southkorea_hourly_iceberg_parquet` table based on partitioned Iceberg Parquet format objects stored in MinIO.

### 4.2. Data Loading

Execute Dagster's data pipeline to store South Korea Weather Data in MinIO. For `southkorea_hourly_csv` and `southkorea_hourly_parquet` tables using CSV and Parquet formats, data can be loaded into MinIO and tables can be created without issues. However, for the `southkorea_hourly_iceberg_parquet` table using Iceberg Parquet format, the table must be created first before loading data.

### 4.3. Data Query

Query data loaded in the `southkorea_hourly_csv`, `southkorea_hourly_parquet`, and `southkorea_hourly_iceberg_parquet` tables. Each table has the same data, only differing in the stored format. Therefore, all queries return the same results. Partition (time) information can also be confirmed in the query results.

For `southkorea_hourly_csv` and `southkorea_hourly_parquet` tables using CSV and Parquet formats, added partition information can be synchronized to Hive Metastore using the `hive.system.sync_partition_metadata` query, and then data can be queried. On the other hand, for the `southkorea_hourly_iceberg_parquet` table using Iceberg Parquet format, data can be queried without synchronizing partition information.

```sql
CALL hive.system.sync_partition_metadata('weather', 'southkorea_hourly_csv', 'ADD');
SELECT * FROM hive.weather."southkorea_hourly_csv$partitions";

SELECT * FROM hive.weather.southkorea_hourly_csv;
```

Synchronize partition information for the `southkorea_hourly_csv` table and query the synchronized partition information.

```sql
CALL hive.system.sync_partition_metadata('weather', 'southkorea_hourly_parquet', 'ADD');
SELECT * FROM hive.weather."southkorea_hourly_parquet$partitions";

SELECT * FROM hive.weather.southkorea_hourly_parquet;
```

Synchronize partition information for the `southkorea_hourly_parquet` table and query the synchronized partition information.

```sql
SELECT * FROM iceberg.weather.southkorea_hourly_iceberg_parquet;
```

Query information from the `southkorea_hourly_iceberg_parquet` table.

{{< figure caption="[Figure 4] Query `southkorea_hourly_*` Table Data in Trino" src="images/dbeaver-trino-weather-query-select.png" width="900px" >}}

Only the `southkorea_hourly_iceberg_parquet` table using Iceberg Parquet format can utilize transaction functionality to not only query data but also insert, modify, and delete data.

## 5. References

* Hive Metastore : [https://mjs1995.tistory.com/307](https://mjs1995.tistory.com/307)
* Trino Query : [https://developnote-blog.tistory.com/187](https://developnote-blog.tistory.com/187)
* Trino Qeury : [https://mjs1995.tistory.com/307](https://mjs1995.tistory.com/307)
* Trino Partition : [https://passwd.tistory.com/entry/TrinoHive-%ED%8C%8C%ED%8B%B0%EC%85%98-%EC%A0%80%EC%9E%A5%EB%90%9C-S3-%EB%8D%B0%EC%9D%B4%ED%84%B0-%EC%BF%BC%EB%A6%AC](https://passwd.tistory.com/entry/TrinoHive-%ED%8C%8C%ED%8B%B0%EC%85%98-%EC%A0%80%EC%9E%A5%EB%90%9C-S3-%EB%8D%B0%EC%9D%B4%ED%84%B0-%EC%BF%BC%EB%A6%AC)
* Trino Partition : [https://dev-soonieee.tistory.com/entry/TrinoHive-Jdbc-Partition-%EA%B2%80%EC%83%89](https://dev-soonieee.tistory.com/entry/TrinoHive-Jdbc-Partition-%EA%B2%80%EC%83%89)


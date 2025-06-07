---
title : Trino MinIO Query 수행 / Kubernetes Data Platform 환경
---

Trino를 통해서 MinIO에 저장되어 있는 데이터를 조회한다.

## 1. 실습 환경 구성

### 1.1. 전체 실습 환경

Trino를 통해서 MinIO에 저장되어 있는 데이터를 조회하는 실습 환경은 다음과 같다.

{{< figure caption="[Figure 1] Trino, Hive Metastore 연동 환경" src="images/environment.png" width="1000px" >}}

* MinIO : Data를 저장하는 Object Storage 역할을 수행한다. Airport Data와 South Korea Weather Data를 저장한다.
  * Airport Data : CSV Format으로 저장된다.
  * South Korea Weather Data : CSV, Parquet, Iceberg 3가지 Data Format으로 시간별로 Partition되어 저장된다.
* Trino : MinIO에 저장되어 있는 Data를 조회하는 역할을 수행한다.
* Hive Metastore : Data의 Schema 정보를 관리하며, Trino에게 Schema 정보를 제공한다.
* Dagster : Data Pipeline을 실행하여 MinIO에 South Korea Weather Data를 저장한다.
* DBeaver : Trino에 접속하고 Query를 수행하기 위한 Client 역할을 수행한다.

전체 실슴 환경 구성은 다음의 링크를 참조한다.

* Kubernetes Cluster 구축 : [https://ssup2.github.io/blog-software/docs/record/orangepi-cluster-build/](https://ssup2.github.io/blog-software/docs/record/orangepi-cluster-build/)
* Kubernetes Data Platform 구축 : [https://ssup2.github.io/blog-software/docs/record/kubernetes-data-platform-orangepi-cluster/](https://ssup2.github.io/blog-software/docs/record/kubernetes-data-platform-orangepi-cluster/)
* Dagster Workflow Github : [https://github.com/ssup2-playground/k8s-data-platform_dagster-workflows](https://github.com/ssup2-playground/k8s-data-platform_dagster-workflows)

### 1.2. Hive Metastore 주요 설정

Hive Metastore의 Helm Chart에 CSV, Parquet Data Format을 위한 Hive Catalog와 Iceberg Data Format을 위한 Iceberg Catalog를 설정한다.

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

### 1.3. MinIO CLI Client 설정

MinIO CLI Client를 설치한다.

```shell
brew install minio/stable/mc
mc alias set dp http://$(kubectl -n minio get service minio -o jsonpath="{.status.loadBalancer.ingress[0].ip}"):9000 root root123!
```

## 2. Trino 접속

Trino Service의 External IP 주소를 확인한다.

```shell
kubectl -n trino get service trino --output jsonpath='{.status.loadBalancer.ingress[0].ip}'
```
```shell
192.168.1.87
```

DBeaver에서 신규 Database를 추가하고 Trino를 선택한다.

{{< figure caption="[Figure 1] DBeaver에서 Trino 선택" src="images/dbeaver-trino-database-select.png" width="800px" >}}

Trino Service의 External IP와 Username를 입력한다. Username은 아무런 문자열이나 입력해도 관계 없으며, Password는 반드시 비워둔다.

{{< figure caption="[Figure 2] Trino 접속 정보 입력" src="images/dbeaver-trino-connection-setting.png" width="800px" >}}

## 3. 단일 Object Query 수행

### 3.1. Schema, Table 생성

Airport Schema와 MinIO에 저장되어 있는 Object를 기반으로 Airport Code Table을 생성한다. CSV Format으로 저장되어 있는 데이터는 모두 `VARCHAR` Type으로 선언된다.

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

### 3.2. Data 적재

MinIO CLI Client를 통해서 MinIO에 Sample Data를 적재한다.

```shell
wget https://raw.githubusercontent.com/datasets/airport-codes/refs/heads/main/data/airport-codes.csv
mc mb dp/airport/codes
mc cp airport-codes.csv dp/airport/codes/data.csv
```

### 3.3. Data 조회

`airport.codes` Table에 적재된 데이터를 조회한다.

```sql
select * from hive.airport.codes;
```

{{< figure caption="[Figure 3] Trino에서 `airport.codes` Table 데이터 조회" src="images/dbeaver-trino-airport-query-select.png" width="900px" >}}

## 4. Partition Object Query 수행

### 4.1. Schema,Table 생성

Weather Schema를 생성한다.

```sql
CREATE SCHEMA hive.weather;
```

MinIO에 저장되어 있는 Partition된 CSV Format의 Object를 기반으로 `southkorea_hourly_csv` Table을 생성한다. CSV Format으로 저장되어 있는 데이터는 모두 `VARCHAR` Type으로 선언된다. CSV Format의 경우, 모든 데이터가 `VARCHAR` Type으로 선언된다.

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
	partitioned_by = ARRAY['year', 'month', 'day', 'hour']
);
```

MinIO에 저장되어 있는 Partition된 Parquet Format의 Object를 기반으로 `southkorea_hourly_parquet` Table을 생성한다.

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

MinIO에 저장되어 있는 Partition된 Iceberg Parquet Format의 Object를 기반으로 `southkorea_hourly_iceberg_parquet` Table을 생성한다.

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
	partitioned_by = ARRAY['year', 'month', 'day', 'hour'],
    'write.delete.isolation-level' = 'serializable'
);
```

### 4.2. Data 적재

Dagster의 Data Pipeline을 실행하여 MinIO에 South Korea Weather Data를 저장한다. CSV, Parquet Format을 이용하는 `southkorea_hourly_csv`, `southkorea_hourly_parquet` Table은 MinIO에 Data를 적재하고 Table을 생성해도 무방하다. 하지만 Iceberg Parquet Format을 이용하는 `southkorea_hourly_iceberg_parquet` Table에 Data 적재하기 위해서는 반드시 Table을 먼저 생성한 다음에 Data를 적재해야 한다.

### 4.3. Data 조회

`southkorea_hourly_csv`, `southkorea_hourly_parquet`, `southkorea_hourly_iceberg_parquet` Table에 적재된 Data를 조회한다. 각 Table은 저장된 Format만 다를뿐 모두 동일한 Data를 갖는다. 따라서 모든 Query는 동일한 결과를 반환한다. Partition (시간) 정보도 Query 결과에서 확인할 수 있다.

CSV, Parquet Format을 이용하는 `southkorea_hourly_csv`, `southkorea_hourly_parquet` Table은 추가된 파티션 정보를 `hive.system.sync_partition_metadata` Query를 활용하여 Hive Metastore에 동기화한 다음 Data 조회가 가능하다. 반면에 Iceberg Parquet Format을 이용하는 `southkorea_hourly_iceberg_parquet` Table은 파티션 정보를 동기화하지 않아도 데이터 조회가 가능하다.

`southkorea_hourly_csv` Table 파티션 정보를 동기화하고, 동기화된 파티션 정보를 조회한다. 

```sql
CALL hive.system.sync_partition_metadata('weather', 'southkorea_hourly_csv', 'ADD');
SELECT * FROM hive.weather."southkorea_hourly_csv$partitions";

SELECT * FROM hive.weather.southkorea_hourly_csv;
```

`southkorea_hourly_parquet` Table 파티션 정보를 동기화하고, 동기화된 파티션 정보를 조회한다.

```sql
CALL hive.system.sync_partition_metadata('weather', 'southkorea_hourly_parquet', 'ADD');
SELECT * FROM hive.weather."southkorea_hourly_parquet$partitions";

SELECT * FROM hive.weather.southkorea_hourly_parquet;
```

`southkorea_hourly_iceberg_parquet` Table 정보를 조회한다.

```sql
SELECT * FROM iceberg.weather.southkorea_hourly_iceberg_parquet;
```

{{< figure caption="[Figure 4] Trino에서 `southkorea_hourly_*` Table 데이터 조회" src="images/dbeaver-trino-weather-query-select.png" width="900px" >}}

## 5. 참조

* Hive Metastore : [https://mjs1995.tistory.com/307](https://mjs1995.tistory.com/307)
* Trino Query : [https://developnote-blog.tistory.com/187](https://developnote-blog.tistory.com/187)
* Trino Qeury : [https://mjs1995.tistory.com/307](https://mjs1995.tistory.com/307)
* Trino Partition : [https://passwd.tistory.com/entry/TrinoHive-%ED%8C%8C%ED%8B%B0%EC%85%98-%EC%A0%80%EC%9E%A5%EB%90%9C-S3-%EB%8D%B0%EC%9D%B4%ED%84%B0-%EC%BF%BC%EB%A6%AC](https://passwd.tistory.com/entry/TrinoHive-%ED%8C%8C%ED%8B%B0%EC%85%98-%EC%A0%80%EC%9E%A5%EB%90%9C-S3-%EB%8D%B0%EC%9D%B4%ED%84%B0-%EC%BF%BC%EB%A6%AC)
* Trino Partition : [https://dev-soonieee.tistory.com/entry/TrinoHive-Jdbc-Partition-%EA%B2%80%EC%83%89](https://dev-soonieee.tistory.com/entry/TrinoHive-Jdbc-Partition-%EA%B2%80%EC%83%89)

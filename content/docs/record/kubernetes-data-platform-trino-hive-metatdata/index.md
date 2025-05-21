---
title : Trino, Hive Metastore 연동 / Kubernetes Data Platform 환경
---

## 1. 실습 환경

### 1.1. MinIO CLI Client 설정

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

### 3.1. MinIO에 Object 적재

MinIO CLI Client를 통해서 MinIO에 Sample Data를 적재한다.

```shell
wget https://raw.githubusercontent.com/datasets/airport-codes/refs/heads/main/data/airport-codes.csv
mc mb dp/airport/codes
mc cp airport-codes.csv dp/airport/codes/data.csv
```

### 3.2. Schema, Table 생성

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

### 3.3. Trino에서 데이터 조회

Airport Code Table에 적재된 데이터를 조회한다.

```sql
select * from hive.airport.codes;
```

{{< figure caption="[Figure 3] Trino에서 데이터 조회" src="images/dbeaver-trino-query-select.png" width="800px" >}}

## 4. Partition Object Query 수행

Weather Schema를 생성한다.

```sql
CREATE SCHEMA hive.weather;
```

### 4.1. CSV Partition Table 생성 및 조회

MinIO에 저장되어 있는 Partition된 CSV Format의 Object를 기반으로 South Korea Hourly Weather Table을 생성한다. CSV Format으로 저장되어 있는 데이터는 모두 `VARCHAR` Type으로 선언된다.

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

Partition 정보를 동기화하고, 동기화된 Partition 정보를 조회한다.

```sql
CALL hive.system.sync_partition_metadata('weather', 'southkorea_hourly_csv', 'ADD');

SELECT * FROM hive.weather."southkorea_hourly_csv$partitions";
```

South Korea Hourly Weather Table에 적재된 데이터를 조회한다.

```sql
SELECT * FROM hive.weather.southkorea_hourly_csv;
```

### 4.3. Parquet Partition Table 생성 및 조회

MinIO에 저장되어 있는 Partition된 Parquet Format의 Object를 기반으로 South Korea Hourly Weather Table을 생성한다.

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

Partition 정보를 동기화하고, 동기화된 Partition 정보를 조회한다.

```sql
CALL hive.system.sync_partition_metadata('weather', 'southkorea_hourly_parquet', 'ADD');

SELECT * FROM hive.weather."southkorea_hourly_parquet$partitions";
```

South Korea Hourly Weather Table에 적재된 데이터를 조회한다.

```sql
SELECT * FROM hive.weather.southkorea_hourly_parquet;
```

### 4.4. Iceberg Parquet Partition Table 생성 및 조회

MinIO에 저장되어 있는 Partition된 Iceberg Parquet Format의 Object를 기반으로 South Korea Hourly Weather Table을 생성한다.

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

## 5. Ranger 기반 Data 접근 제어

## 6. 참조

* Hive Metastore : [https://mjs1995.tistory.com/307](https://mjs1995.tistory.com/307)
* Trino Query : [https://developnote-blog.tistory.com/187](https://developnote-blog.tistory.com/187)
* Trino Qeury : [https://mjs1995.tistory.com/307](https://mjs1995.tistory.com/307)
* Trino Partition : [https://passwd.tistory.com/entry/TrinoHive-%ED%8C%8C%ED%8B%B0%EC%85%98-%EC%A0%80%EC%9E%A5%EB%90%9C-S3-%EB%8D%B0%EC%9D%B4%ED%84%B0-%EC%BF%BC%EB%A6%AC](https://passwd.tistory.com/entry/TrinoHive-%ED%8C%8C%ED%8B%B0%EC%85%98-%EC%A0%80%EC%9E%A5%EB%90%9C-S3-%EB%8D%B0%EC%9D%B4%ED%84%B0-%EC%BF%BC%EB%A6%AC)
* Trino Partition : [https://dev-soonieee.tistory.com/entry/TrinoHive-Jdbc-Partition-%EA%B2%80%EC%83%89](https://dev-soonieee.tistory.com/entry/TrinoHive-Jdbc-Partition-%EA%B2%80%EC%83%89)

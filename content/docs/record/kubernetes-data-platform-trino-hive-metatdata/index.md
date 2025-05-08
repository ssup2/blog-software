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
mc mb dp/airport-codes
mc cp airport-codes.csv dp/airport-codes/data/
```

### 3.2. Hive Metastore에 Table 생성

DBeaver에서 Trino에 접속한 다음, 다음의 DML을 실행하여 Hive Metastore에 Table을 생성한다.

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
	external_location = 's3a://airport-codes/data/',
	format = 'CSV'
);
```

### 3.3. Trino에서 데이터 조회

Trino에서 Select 쿼리를 실행하여 데이터를 조회한다.

```sql
select * from hive.airport.codes;
```

{{< figure caption="[Figure 3] Trino에서 데이터 조회" src="images/dbeaver-trino-query-select.png" width="800px" >}}

## 4. 다수의 Partition Object Query 수행

### 4.1. MinIO에 Partition된 Object 적재

```shell
```

### 4.2. Hive Metastore에 Partition된 Table 생성

```sql
CREATE SCHEMA hive.weather;

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

### 4.3. Trino에서 데이터 조회

## 5. Ranger 기반 Data 접근 제어

## 6. 참조

* Hive Metastore : [https://mjs1995.tistory.com/307](https://mjs1995.tistory.com/307)
* Trino Query : [https://developnote-blog.tistory.com/187](https://developnote-blog.tistory.com/187)
* Trino Qeury : [https://mjs1995.tistory.com/307](https://mjs1995.tistory.com/307)

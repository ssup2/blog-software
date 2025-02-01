---
title : Trino, Hive Metastore 연동 / Kubernetes Data Platform 환경
draft : true
---

## 1. 실습 환경

## 2. Trino 접속

## 3. Hive Metastore에 Table 생성

```sql
create schema hive.airport;

create table hive.airport.codes (
	ident varchar,	
	type  varchar,	
	name  varchar,
	elevation_ft varchar,
	continent    varchar,
	iso_country	 varchar,
	iso_region	 varchar,
	municipality varchar,
	gps_code	 varchar,
	iata_code	 varchar,
	local_code	 varchar,
	coordinates  varchar
)
with (
	external_location = 's3a://airport-codes/data/',
	format = 'CSV'
);

select * from hive.airport.codes;
```

## 4. MinIO에 Data 적재

MinIO CLI Client를 설치한다.

```shell
brew install minio/stable/mc
mc alias set dp http://192.168.1.89:9000 root root123!
```

MinIO CLI Client를 통해서 MinIO에 Data를 적재한다.

```shell
wget https://raw.githubusercontent.com/datasets/airport-codes/refs/heads/main/data/airport-codes.csv
mc mb dp/airport-codes
mc cp airport-codes.csv dp/airport-codes/data/
```

## 5. 참조

* Hive Metastore : [https://mjs1995.tistory.com/307](https://mjs1995.tistory.com/307)
* Trino Query : [https://developnote-blog.tistory.com/187](https://developnote-blog.tistory.com/187)
* Trino Qeury : [https://mjs1995.tistory.com/307](https://mjs1995.tistory.com/307)

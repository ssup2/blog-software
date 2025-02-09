---
title : Trino, Hive Metastore 연동 / Kubernetes Data Platform 환경
draft : true
---

## 1. 실습 환경

## 2. Trino 접속

Trino Service의 External IP 주소를 확인한다.

```shell
kubectl -n trino get service trino --output jsonpath='{.status.loadBalancer.ingress[0].ip}'
```
```shell
192.168.1.87
```

DBeaver에서 신규 Database를 추가하고 Trino를 선택한다.

{{< figure caption="[Figure 1] DBeaver에서 Trino 선택" src="images/dbeaver-trino-select.png" width="700px" >}}

Trino Service의 External IP와 Username를 입력한다. Username은 아무런 문자열이나 입력해도 관계 없으며, Password는 반드시 비워둔다.

{{< figure caption="[Figure 2] Trino 접속 정보 입력" src="images/dbeaver-trino-connection-setting.png" width="700px" >}}

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

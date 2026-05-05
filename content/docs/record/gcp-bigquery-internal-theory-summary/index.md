---
title: GCP BigQuery 내부 이론 정리
---

## 1. Introduction to BigQuery

### 1.1. 기존 Data Warehouse 문제점

* Data Warehouse의 이용 변천사
  * 90년대 : Data Warehouse 솔루션 등장
  * 2000년대 : Adhoc Query 지원 필요성 증가
  * 2010년대 : Data Mining (과거의 데이터를 기반으로 분석하는 기술)
  * 현재 : 미래 예측

* Batch Data Ingestion
  * 데이터를 한번에 모아서 처리하는 방식
  * 실시간 데이터 처리 불가능

* Scalability Issue
  * 기존 Data Warehouse는 확장성이 떨어장

* Cost Issue
  * 높은 비용
  * Idle Cost 발생

* Upgrades
  * Manual Upgrade 필요
  * Downtime 발생
  * 운영에 DBA 필요

### 1.2. What is BigQuery?

* Fully Managed, Serverless, Highly Scalable, Cost-Effective Data Warehouse
* Batch and Streaming Data Ingestion
* Supports AI and ML
* Fully Managed
* Scalable
* Pay as you go
* Automated data transfer
* Access Control

### 1.3. Out of the Box Features

* GIS Support
* Auto Backup
* Integration with other GCP Services
* Foundation for BI
* Programmatic Access
* High Security
* Rich monitoring, logging, alerting through Cloud Audit Logs
* Federated Queries
* Run Data Science workloads
* Powerful data repository

### 1.4. BigQuery Architecture

* Dremel Engine
* Colossus File System
  * Columnar Storage
  * 압축된 데이터를 복구할필요 없이 바로 처리 가능
* Stroage
  * Streaming Data, Bulk Load 지원
* Compute
* Petabit Network
  * Storage, Compute 연결


## 2. Dataset & Table Creation

### 2.1. Region vs Multi-Region

* Region
  * 하나의 Region이나 근처 Region에서만 Data 접근이 필요할 경우 이용
  * Data도 하나의 Region에만 자정

* Multi-Region
  * 여러 Region에서 Data 접근이 필요할 경우 이용
  * Data는 여러 Region에 저장하여 Soft & Hard Failure 방지 가능

### 2.2. Dataset Creation

* Default Rounding Mode : 반올림 모드
* Time Travel Window : 데이터 복구 가능한 시간 범위


## 3. Using BigQuery Dashboard Options

###  3.1. Running query with varioius query settings

* Destination
  * BigQuery의 Query 결과는 Table로 저장되며, 어느 Table에 저장할지 설정
  * Save query results in a temporary table
     * 임시 Table에 저장
     * 임시 Table은 Caching 용도로 사용되며, 약 24시간 동안 Caching
     * 다른 사용자와 공유가 불가능
     * 추가 비용이 발생하지 않음
  * Select a destination table for query results
     * 특정 Table에 저장
     * 저장 비용 발생
     * 동일한 DataSet의 Table에만 저장 가능

* Allow Large Results : 10GB 이상의 결과를 저장 가능

* Job Priority
  * Interactive : 즉시 쿼리 실행
  * Batch : Idle Resource가 발생하는 시점에 실행, 일반적으로 1~2분 이내에 실행됨. 24시간 이내에 실행되지 않으면 Interactive로 변경되어 실행

### 3.2. Caching Features & Limits

* To retrive data from stored cached, the query should be exact replica of the original query
* Not cached when destination table is specified to store the results in query
* Not cached if tables/views being used in the query have changed since the last cache.
* Not cached for tables having streaming ingestion.
* Not cached if query uses non-deterministic functions. (NOW(), CURRENT_USER())
* Not cached if query runs against external data sources like BigTable or CloudStorage.
* Result set must be smaller than maximum response size (10GB Default)

### 3.3. Wildcard Tables

* 다수의 Table에서 한번에 데이터를 조회하고 싶을때 이용
  * Example : SELECT * FROM `project_id.dataset_id.table_id_*`
* `_TABLE_SUFFIX` : Wildcard Table 쿼리 이용시 Pseudo Column이며, 이를 활용하여 특정 Table만 조회 가능
  * Example : SELECT * FROM `project_id.dataset_id.table_id_*` WHERE _TABLE_SUFFIX = '100' OR _TABLE_SUFFIX = '200'
* Limitations
  * Support BigQuery storage only
  * Caching is not supported
  * DML is not supported

### 3.4. Scheduled Queries

* 특정 시간에 쿼리 수행
* Backfill 지원

### 3.5. Auto Schema Detection

* 최대 100개의 Random Row를 선택해서 Schema 파악
* 다음의 제약 조건 존재 
  * CSV, SON 형태만 지원
  * Gzip 지원
  * Comma, Pipe, Tab, Delimiter 지원
  * Header from file
  * endline 지원
  * `YYYY-MM-DD` 형태의 Date 지원
  * `yyyy-mm-dd hh:mm:ss` 형태의 Timestamp 지원

## 4. Efficient Schema Design

* BigQuery 환경에서는 De-normalized Schema를 권장
  * 분산 처리에 유리
* Nested & Repeated Column 지원

## 5. Query Plan Execution

* BigQuery는 SQL 쿼리를 실행할 때 단순히 순서대로 처리하는 게 아니라, 최적화된 실행 계획(Execution Plan)을 자동으로 설계. 다른 DB의 EXPLAIN 문과 유사한 개념

* In-Memory Shuffle
  * BigQuery는 중간 데이터를 전용 **메모리 노드**에 저장하여 처리 속도를 획기적으로 향상시킴. 특히 데이터가 생성되는 즉시 다음 작업자가 소비할 수 있어 파이프라인 방식 실행이 가능

* 주요 성능 지표
  * Elapsed Time : 쿼리 시작부터 완료까지 실제 경과 시간
  * Slot Time : 모든 슬롯이 작업한 시간의 합계
  * Bytes Shuffled : 단계 간 전송된 데이터량 (낮을수록 좋음)
  * Bytes Spilled to Disk : 메모리 초과로 디스크에 기록된 데이터량 (0이 이상적)

## 6. Execution Plan

* Stage별 타이밍 지표
  * Average Time : 해당 Stage의 모든 Worker 평균 시간
  * Max Time : 가장 느린 Worker(Long Tail)의 시간

* Worker의 4가지 상태
  * Wait : 스케줄링 대기 또는 이전 Stage 완료 대기
  * Read : 데이터 읽기 및 필터링
  * Compute : 연산 처리 (수식 계산, SQL 함수, 집계 등)
  * Write : 결과 출력 (메모리 또는 디스크에 저장)

## 7. Partitioned Tables

* 대용량 테이블을 특정 기준에 따라 작은 세그먼트(파티션)로 분할하여 저장

* Advantage
  * 쿼리 성능 향상 : 필요한 파티션만 스캔하여 처리 시간 단축
  * 비용 절감 : 읽는 데이터량 감소 → BigQuery 과금 감소
  * 병렬 처리 : 향상각 파티션에 독립적으로 병렬 작업 할당 가능
  * 독립적 관리 : 파티션별 압축, 스토리지 계층(빠른/느린 디스크) 설정 가능
  * 대용량 Upsert 효율화 : 전체 테이블 대신 해당 파티션만 교체

### 7.1. 수집 시간(Ingestion Time) 기반 파티셔닝

* 일(Day) : 데이터가 넓은 날짜 범위에 걸쳐 있을 때, 지속적으로 데이터가 쌓일 때 (대부분의 경우)
* 시간(Hour) : 6개월 미만의 짧은 기간에 데이터가 대량으로 집중될 때

* 자동 생성되는 Pseudo 컬럼
  * `_PARTITIONTIME` : TIMESTAMP, 적재 시각 (UTC 기준)
  * `_PARTITIONDATE` : DATE, 적재 일자 (UTC 기준)

* Partition Meta 조회
  * `SELECT * FROM dataset1.__PARTITIONS_SUMMARY__`

### 7.2. 특정 컬럼 기반 파티셔닝

* 수집 시간이 아닌 데이터 내의 특정 날짜 컬럼 값을 기준으로 파티션을 나누는 방식

* 파티셔닝 컬럼 제약 조건
  * 타입 : DATE 또는 TIMESTAMP만 가능
  * 모드 : Required 또는 Nullable 가능, Repeated는 불가
  * 위치 : 반드시 최상위 필드여야 함 (STRUCT 내부 필드 불가)

* 특수 파티션 2가지
  * `__NULL__` : 파티션 컬럼 값이 NULL인 행
  * `__UNPARTITIONED__` : 허용 범위를 벗어난 날짜 (예: 9020년) + 버퍼 데이터

* 스트리밍 버퍼(Buffer) 메커니즘
  * 레코드가 올 때마다 바로 디스크에 쓰면 극도로 비효율적이라 버퍼를 사용
  * 버퍼에 있는 동안에도 쿼리 시 테이블 + 버퍼를 동시에 조회하므로 사용자 입장에서는 데이터 일관성이 보장
  * 디스크에 완전히 쓰이기 전까지는 어느 파티션에 속할지 확정되지 않으므로 임시로 __UNPARTITIONED__에 위치

### 7.3. Integer Range Partitioning

* 데이터 내 정수형 컬럼 값을 기준으로, 사용자가 지정한 시작값·끝값·간격에 따라 파티션을 나누는 방식

* 파티션 범위 설정
  * Start : 파티션 시작 값
  * End : 파티션 끝 값
  * Interval : 파티션 간격

* 제약 사항
  * 테이블당 최대 파티션 수 : 4,000개
  * 단일 작업당 최대 수정 파티션 수 : 4,000개
  * 수집 시간 파티션 테이블 일일 수정 한도 : 5,000회
  * 컬럼 기반 파티션 테이블 일일 수정 한도 : 30,000회

### 7.4 Partition Expiration

* 만료 시간은 ALTER 문으로 설정 (Web UI 미지원)

* 개별 파티션마다 다른 만료 시간 설정 불가 → 테이블 전체에 일괄 적용

* 테이블 만료 > 파티션 만료 (테이블이 삭제되면 파티션도 같이 삭제)
  * 테이블 만료 5일, 파티션 만료 7일 → 5일 후 모두 삭제

* 파티션 만료 설정 우선 순위
  * 1순위: ALTER 문으로 명시적 설정
  * 2순위: 테이블 생성 시 설정
  * 3순위: 데이터셋 기본 설정
  * 만료 없음 → 수동 삭제 필요

### 7.5. Partition Best Practices

* 권장 O : 파티션 컬럼을 WHERE 절에 단독으로 사용

```
-- 좋음: 파티션 컬럼을 좌변에 단독으로
WHERE _PARTITIONTIME > TIMESTAMP_SUB(TIMESTAMP('2024-01-01'), INTERVAL 1 DAY)

-- 나쁨: 파티션 컬럼에 연산 포함
WHERE _PARTITIONTIME + INTERVAL 1 DAY > '2024-01-01'
```

* 권장 O : AND 조건으로 추가 필터 사용

```
-- 좋음: AND는 스캔 범위를 더 좁혀줌
WHERE department = 45 AND id = 1
```

* 권장 X : OR 조건으로 비파티션 컬럼 추가

```
-- 나쁨: OR로 비파티션 컬럼이 들어오면 전체 스캔
WHERE department = 45 OR id = 1
-- id가 어느 파티션에 있는지 알 수 없어 풀스캔 발생
```

* 파티션 컬럼에 다른 컬럼과의 연산 포함

```
-- 나쁨: 전체 스캔 발생
WHERE department + LENGTH(name) = 45
```

* 서브쿼리를 WHERE 절에 사용

```
-- 나쁨: 파티션 제거 효과 없음
WHERE department = (SELECT MAX(department) FROM ...)
```

* 파티션 컬럼을 다른 컬럼과 비교

```
-- 나쁨: 전체 스캔 발생
WHERE _PARTITIONTIME > ts1  -- ts1은 테이블의 다른 컬럼
```

* 파티션을 너무 많이 생성
  * 파티션마다 메타데이터가 쌓여 오히려 성능 저하
  * 파티션이 너무 많아지면 비파티션 테이블과 다를 바 없어짐
  * 이런 경우엔 파티션 대신 클러스터 테이블 사용을 권장

## 8. Clustered Tables

* 파티셔닝 한계점
  * 파티션 내에 데이터가 여전히 너무 많을 때
  * 파티션 크기가 불균형할 때 (부서별 인원 차이 등)

* 클러스터링
  * 파티션 내부의 데이터를 특정 컬럼 값 기준으로 같은 버킷(파일)에 모아 저장하는 방식입니다. Hive의 버킷팅(Bucketing)과 동일한 개념입니다.

* 파티션 vs 클러스터
  * 파티션 : 디렉토리
  * 클러스터 : 파티션 디렉토리 안의 파일

* 파티셔닝만 사용
  * 쿼리 실행 전에 정확한 처리 데이터량과 비용을 미리 알아야 할 때
  * 파티션 단위의 만료, DML 등 세부 관리가 필요할 때
* 파티셔닝 + 클러스터링 사용
  * 데이터가 대용량이고 정교한 데이터 조직화가 필요할 때
  * 주로 집계(Aggregation)와 필터링 쿼리를 많이 실행할 때
  * 비용 사전 예측이 크게 중요하지 않을 때
* 클러스터링만 사용
  * 파티셔닝 시 파티션이 수천 개 이상으로 너무 많이 생성될 때
  * 평균 파티션 크기가 1GB 미만으로 작을 때

### 8.1. Best Practices

* WHERE 절 컬럼 순서를 생성 시 순서와 동일하게 : O
```
-- 테이블 생성 시: CLUSTER BY name, surname
-- 좋음: 생성 순서와 동일
WHERE name = 'John' AND surname = 'Doe'

-- 나쁨: 순서가 다르면 최적 성능 보장 안 됨
WHERE surname = 'Doe' AND name = 'John'
```

* 클러스터 컬럼에 복잡한 표현식 사용 금지 : O

```
-- 좋음: 단순 비교 → 100KB만 스캔
WHERE layer_code = 123

-- 나쁨: 캐스팅/연산 포함 → 203GB 전체 스캔
WHERE CAST(layer_code AS STRING) = '123'
```

* 클러스터 컬럼을 다른 컬럼과 비교 금지 : X

```
WHERE cluster_column = other_column
```

## 9. Loading & Querying External Data Sources

## 6. 참고

* [https://www.udemy.com/course/bigquery/](https://www.udemy.com/course/bigquery/)

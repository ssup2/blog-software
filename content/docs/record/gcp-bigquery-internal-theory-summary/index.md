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

### 8.2. Partitioning Limits

* 쿼리 방식 : Standard SQL만 지원
* 클러스터 컬럼 지정 : 테이블 생성 시 지정해야 함
* 클러스터 컬럼 변경 : API로 변경 가능하나 이후 적재 데이터에만 적용
* 컬럼 위치 : 최상위 필드만 가능 (STRUCT, ARRAY 내부 필드 불가)
* 최대 클러스터 컬럼 수 : 4개
* 지원 타입 : DATE, BOOLEAN, GEOGRAPHY, INTEGER, NUMERIC, STRING, TIMESTAMP
* 쿼터 : 일반 테이블과 동일 (Load/Export/Query/Copy)

## 9. Loading & Querying External Data Sources

* 외부 저장소 (GCS)의 Data를 BigQuery에서 바로 조회 가능

### 9.1. Limitations

* 데이터 일관성 미보장
  * 쿼리 실행 중 외부 데이터가 변경되면 예상치 못한 결과가 나올 수 있음

* 쿼리 성능 저하
  * 속도가 중요하다면 데이터를 BigQuery에 직접 로드하는 것을 권장
  * 스토리지 유형별 성능 차이 존재
    * Cloud Storage > Google Drive

* 직접 Export 불가
  * 외부 데이터 변경 시 쿼리 재실행 필요

* 와일드카드 테이블 쿼리 불가
  * 외부 데이터 소스는 와일드카드 테이블 쿼리에서 참조할 수 없습니다.

* 파티셔닝/클러스터링 제한적 지원
  * 지원 포맷: Avro, Parquet, ORC, JSON, CSV (Cloud Storage)
  * Hive 파티셔닝 레이아웃 방식으로만 지원
  * 파티셔닝 키와 컬럼이 겹치면 안 됨
  * Standard SQL만 지원

* 쿼리 결과 캐싱 없음
  * 동일한 쿼리를 반복 실행해도 매번 비용이 청구됩니다.

## 10. View

* SQL 쿼리로 정의된 가상 테이블. 실제 데이터를 저장하지 않고, 쿼리 결과를 테이블처럼 보여줌

* 특성
  * 데이터 저장 : 물리적 데이터 없음
  * 읽기/쓰기 : 읽기 전용 (INSERT/UPDATE/DELETE 불가)
  * 스키마 독립성 : 생성 후 기본 테이블 스키마 변경해도 뷰 스키마는 그대로 유지
  * 기본 테이블 삭제 시 : 뷰가 무효화되어 쿼리 실패
  * 저장 비용 : 무료 (조회 비용은 테이블과 동일)

* View를 이용하는 이유
  * 보안/접근 제어
    * 사용자마다 다른 컬럼만 보여줄 수 있습니다.
  * 기본 테이블 보호
    * 뷰는 읽기 전용이므로 기본 테이블 데이터를 실수로 변경하거나 삭제할 위험이 없습니다.
  * 복잡한 쿼리 단순화 (Join Query 결과를 View로 저장)
  * 저장 공간 무료 (실제 데이터를 저장하지 않으므로 스토리지 비용이 발생하지 않습니다.)

* 일반 뷰 vs Materialized View
  * 데이터 저장 : X vs O
  * 저장 비용 : 무료 vs 비용 발료
  * 쿼리 성능 : 기본 Table 조회 vs 저장된 결과 바로 반환
  * 쿼리만 저장 vs 쿼리 결과를 실제 Storage에 저장

### 10.1. Row-Level Security

* 특정 사용자마다 다른 데이터만 보여줄 수 있음

* 적용 방법
  * `SESSION_USER()` 함수를 사용하여 현재 쿼리를 실행하는 사용자의 email 반환

### 10.2. Limitations

* 데이터셋 : 위치뷰와 참조 테이블이 같은 위치(Location) 에 있어야 함
* 데이터 Export : 뷰는 물리적 데이터가 없으므로 직접 Export 불가
* SQL 방언 혼용 : Standard SQL과 Legacy SQL 혼용 불가
* 쿼리 파라미터 : 뷰 정의 쿼리에서 참조 불가
* 사용자 정의 함수(UDF) : 뷰를 정의하는 쿼리에는 포함 불가 (뷰를 조회할 때는 사용 가능)
* 와일드카드 테이블 : 와일드카드 테이블 쿼리에서 참조 불가
* 중첩 뷰 : 최대 레벨16단계
* 데이터셋당 인가된 뷰 수 : 2500개

## 11. Materialized View

* Data Refresh : 수동 갱신, Auto Refresh 활성화 → 주기적으로 자동 갱신
* Smart Query Optimization : BigQuery가 일반 쿼리를 실행할 때 자동으로 구체화 뷰를 활용
* 최신의 데이터를 제공 기능 with streaming tables
* Materialized View 유용한 경우
  * 반복적이고 예측 가능한 쿼리 : 미리 계산된 결과 재사용 가능
  * ETL/BI 파이프 라인 : 동일 쿼리 반복 실행 패턴
  * 집계 쿼리 (SUM, AVG 등) : 연산 시간은 길지만 결과는 작은 경우

### 11.1. Alert Materialized View

* 지원
  * CREATE : Materialized View 생성
  * DROP : Materialized View 삭제
  * ALTER : Auto Refresh만 변경 가능

* 불가능
  * COPY : Materialized View 복사 불가
  * IMPORT/EXPORT : Materialized View로 가져오거나 내보내기 불가
  * INSERT : Materialized View에 직접 쓰기 불가능
  * BigQuery Storage API : API를 통한 직접 접근 불가

* 기본 Table 삭제시
  * 기본 Table을 동일한 이름으로 재생성해도, Materialized View도 다시 생성 필요

### 11.2. Ad-hoc Query를 Materialized View 활용

* MV의 GROUP BY/집계 컬럼의 부분집합 사용
* GROUP BY 컬럼에 연산 적용
* MV의 그룹핑 컬럼 또는 기존 필터 조건으로 필터링
* MV 필터의 부분집합으로 필터링

### 11.3. Materialized View 갱신

* 변경 유형
  * INSERT만 (append) : 변경된 델타 데이터만 읽어서 추가
  * UPDATE/DELETE/MERGE : 영향받은 부분 무효화 후 재읽기

* 파티션 여부에 따른 차이
  * 파티션 MV : 영향받은 파티션만 무효화 + 재읽기
  * 비파티션 MV : 전체 무효화 + 전체 기본 테이블 재읽기

* 갱신 방법
  * 수동 갱신
  * Auto Refresh 설정

* Auto Refresh 동작 원리
  * 기본 테이블 변경 감지
  * 5분 이내 자동 갱신 (변경 발생 후)
  * 단, 최소 갱신 간격 준수 (기본 30분) : 기본 테이블이 계속 바뀌어도 30분마다 최대 1회 갱신

* 갱신 사이 시간대의 데이터 처리
  * INSERT만 : MV 데이터 + 마지막 갱신 이후 델타 데이터 합산
  * UPDATE/DELETE : MV 스캔 안 하고 기본 테이블 직접 조회

* BigQuery는 MV 갱신 여부와 관계없이 항상 최신 데이터를 보장합니다. 갱신 전이면 델타를 합산하거나 기본 테이블을 직접 조회하는 방식으로 일관성을 유지합니다.

### 11.4. Materialized View Limitations

| 항목 | 일반 뷰 | 구체화 뷰 |
|------|------|------|
| 데이터 저장 | ❌ | ✅ |
| 저장 비용 | 무료 | 발생 |
| 쿼리 성능 | 느림 | 빠름 |
| JOIN 지원 | ✅ | ❌ |
| 중첩 | 16단계 | ❌ |
| 참조 테이블 | 다중 | 단일 |
| DML | ❌ | ❌ |
| 데이터셋 위치 | 자유 | 동일 데이터셋 |
| 최대 개수 | 2,500개/데이터셋 | 20개/기본 테이블 |
| SQL 방언 | Legacy/Standard | Standard SQL만 |

* 불가능한 작업
  * COPY : 소스/대상으로 복사 불가
  * EXPORT : 데이터 내보내기 불가
  * LOAD : 직접 데이터 적재 불가
  * INSERT : 쿼리 결과 직접 쓰기 불가
  * DML : UPDATE/DELETE/MERGE 불가
  * UNNEST : 배열 펼치기 불가
  * JOIN : 여러 테이블 조인 불가
  * MV 중첩 : MV 기반 MV 생성 불가

### 11.5. Materialized View Best Practices

* Materialized View를 넓은 범위의 쿼리를 커버하도록 설계
  * 최대 20개 제한이 있으므로 세분화된 필터보다 그룹핑 중심으로 설계합니다.

```
-- 나쁨: 특정 값으로 필터링 → 재사용성 낮음
CREATE MATERIALIZED VIEW mv_household AS
SELECT customer_id, SUM(sales)
FROM orders
WHERE product_category = 'household'  -- 너무 구체적
GROUP BY customer_id

-- 좋음: 그룹핑으로 설계 → 다양한 쿼리가 활용 가능
CREATE MATERIALIZED VIEW mv_sales_summary AS
SELECT customer_id, product_category, SUM(sales)
FROM orders
GROUP BY customer_id, product_category
```

* 사용자들이 자주 쓰는 날짜 범위를 Materialized View 생성 시 미리 포함시켜 두기

* Materialized View 크기가 크면 Materialized View에도 파티셔닝 적용

* Auto Refresh 주기는 데이터 변경 패턴에 맞게 설정 (비용 최적화를 위해서)
  * 기본 테이블 변경이 적음 : 갱신 주기 길게 설정
  * 기본 테이블 변경이 많음 : 갱신 주기 짧게 설정
  * ETL/야간 배치로 데이터 적재 : Auto Refresh 끄고 수동 갱신 또는 스케줄링

* DML 작업은 배치로 묶고 수동 갱신
  * UPDATE/DELETE/MERGE는 MV를 무효화시키므로 개별 실행보다 한 번에 묶어서 실행 후 수동 갱신합니다.

* JOIN이 필요한 경우 집계를 먼저 MV로 만들기
  * Materialized View 생성시에 JOIN을 지원하지 않음
  * 집계용 Materialized View를 먼저 생성하고, 이를 원래 Base Table과 JOIN 쿼리로 묶어서 사용

## 12. Pricing

### 12.1. Storage Pricing

* 활성 데이터 vs 장기 데이터
  * 활성 데이터 : 최근 90일 이내에 수정된 테이블/파티션
  * 장기 데이터 : 90일 연속으로 수정되지 않은 테이블/파티션

* 활성 스토리지
  * 멀티 리전 (미국 & 유럽 & 아시아) : $0.02/GB/월
  * 단일 리전 : $0.02 ~ $0.023/GB/월

* 장기 스토리지
  * 멀티 리전 (미국 & 유럽) : $0.01/GB/월
  * 단일 리전 : $0.01 ~ $0.012/GB/월

* 공통 사항
  * 매월 첫 10GB는 무료. 스토리지는 MB/초 단위로 측정
  * 요금 예시
    * 100MB를 반 달 동안 저장 → 약 $0.001
    * 500GB를 반 달 동안 저장 → 약 $5.00

* 주요 동작 방식
  * 각 파티션은 독립적으로 평가. 하나의 파티션만 수정된 경우, 그 파티션만 활성 요금으로 전환되고 나머지는 장기 요금이 유지.
  * 90일 타이머를 초기화 하는 작업
    * 데이터 로드 (추가 또는 덮어쓰기 모드)
    * 테이블로 데이터 복사
    * 쿼리 결과를 테이블에 저장
    * DML / DDL 작업
    * 테이블로 데이터 스트리밍
  * 타이머를 초기화하지 않는 작업
    * 테이블 쿼리
    * 테이블을 조회하는 뷰 생성
    * 테이블에서 데이터 내보내기
    * 테이블을 다른 대상 테이블로 복사
    * 테이블 리소스 패치/업데이트

### 12.2. Query Pricing

* 두가지 요금제
  * 온디멘드 요금제
    * 쿼리 실행 시에만 과금
    * 처리된 바이트 수
    * 기본 적용
  * 정액제 (Flat Rate)
    * 슬롯 구매 (구독형)
    * 할당된 처리 용량
    * 별도 전환 필요

* 온디멘드 요금제
  * 데이터 위치에 관계없이 처리된 바이트 수에 따라 과금 (BigQuery, Cloud Storage, BigTable 동일)
  * 매월 1TB는 무료

* 정액제 (Flat Rate)
  * 안정적인 비용을 원하는 고객에게 적합한 구독형 모델.
  * 처리된 바이트에 대한 추가 과금 없음
  * BigQuery ML, DML, DDL 쿼리 모두 포함
  * 스토리지, 스트리밍 수집, BI Engine 비용은 별도
  * 슬롯은 지역 단위 자원 (다른 지역으로 이동 불가)
  * 최소 100슬롯 구매, 100슬롯 단위로 확장
  * 조직 전체에서 슬롯 공유 가능
  * 용량 초과 시 추가 과금 없이 **대기열(Queue)** 처리

### 12.3. API, DML Pricing

* Streaming Inserts
  * File Upload 방식의 데이터 적재는 무료
  * 스트리밍 수집 모드로 적재 시 처리된 바이트 수에 따라 과금
  * 성공적으로 적재된 데이터만 과금
  * 행당 최소 최소 과금 단위 : 1KB

* DML Query Cost
  * 데이터 스캔이 발생할 경우에만 과금. 과금 기준은 테이블 유형과 DML 작업 종류에 따라 다름.
  * INSERT : 소스 테이블에서 SELECT로 참조된 모든 컬럼의 바이트 합계
  * UPDATE : 참조된 컬럼의 바이트 합계 + 수정 대상 행의 모든 컬럼 바이트 합계
  * DELETE : 참조된 컬럼의 바이트 합계 + 삭제 대상 행의 모든 컬럼 바이트 합계
  * MERGE : 포함된 INSERT/UPDATE/DELETE 각각의 위 공식 적용

* BigQuery Storage API 요금
  * RPC 기반 프로토콜로 BigQuery 스토리지에 빠르게 접근하는 API.
  * 정액제 고객 : 월 3TB까지 무료 읽기 제공, 초과 시 온디맨드 요금 적용
  * 온디맨드 요금 : $1.10 / TB (멀티 리전에서만 제공)
  * 임시 테이블 읽기 : 무료

* ReadRows 메서드 호출 시 다음 경우에도 과금 발생
  * ReadRows 호출이 실패한 경우 → 읽은 데이터만큼 과금
  * ReadRows 호출을 중간에 취소한 경우 → 취소 전까지 읽은 데이터 과금
  * 취소 전 읽혔지만 반환되지 않은 데이터도 과금 대상

### 12.4. Free Operations

* Data Load
  * Cloud Storage 또는 로컬 파일에서 BigQuery로 데이터 로드
  * 단, Cloud Storage에 저장된 동안의 스토리지 비용 및 로드 후 BigQuery 스토리지 비용은 별도 과금

* 네트워크
  * 목적지 데이터셋이 US 멀티 리전인 경우, 다른 지역의 Cloud Storage 버킷에서 로드 시 네트워크 비용 무료

* 복사 & 내보내기
  * 테이블 복사 무료 (단, 원본/복사본 테이블 스토리지 비용은 과금)
  * BigQuery → Cloud Storage 데이터 내보내기 무료 (단, Cloud Storage 스토리지 비용은 과금)

* 삭제 작업 (전부 무료)
  * 데이터셋 삭제
  * 테이블 삭제
  * 뷰 삭제
  * 테이블 파티션 삭제
  * 사용자 정의 함수(UDF) 삭제

* 메타데이터 작업
  * List, Get, Patch, Update, Delete 호출 등 대부분의 메타데이터 작업 무료
  * 데이터셋 목록 조회, 데이터셋 ACL 업데이트, 테이블 설명 업데이트, UDF 목록 조회 등

* 의사 컬럼(Pseudo Column) 쿼리
  * `_TABLE_SUFFIX` (와일드카드 테이블 쿼리 시)
  * `_PARTITIONDATE` / `_PARTITIONTIME` (수집 시간 파티션 테이블 쿼리 시)

## 13. Best Practices

* 핵심 원칙
  * "적게 일하는 쿼리가 더 빠르고 더 저렴하다"
  * 클라우드 환경에서는 성능과 비용을 동시에 고려해야 합니다. 리소스를 늘려 성능을 높이는 것은 언제든 가능하지만, 그만큼 비용도 증가하기 때문입니다.

* 왜 쿼리 최적화가 중요한가?
  * 온디맨드 요금제의 경우
    * 쿼리가 스캔하는 데이터가 많을수록 비용 증가
    * 쿼리 한 줄의 차이로 수백 달러가 절감될 수 있음
  * 정액제(Flat Rate)의 경우
    * 슬롯 초과 시 추가 구매가 아닌 대기열(Queue) 처리
    * 슬롯 추가 구매 전에 쿼리 최적화가 우선

* 쿼리 성능/비용에 영향을 주는 5가지 요소
  * 입력 데이터 : 쿼리가 몇 바이트를 읽는가?
  * 노드 간 통신 (셔플링) : 다음 단계로 몇 바이트를 전달하는가?
  * 연산량 : 얼마나 많은 CPU 시간이 필요한가?
  * 출력 데이터 : 쿼리가 몇 바이트를 쓰는가?
  * 쿼리 안티패턴 : SQL 모범 사례를 따르고 있는가?

### 13.1. Data Scan 제한

* Data Scan 최적화
  * SELECT * 사용 금지
  * LIMIT은 비용 절감 효과 없음 (오해 주의!)
  * 파티셔닝 & 클러스터링 적극 활용
  * 데이터 비정규화 (De-normalize)
  * Materialized View 활용
  * 캐시 결과 활용
  * 외부 데이터 소스 사용 주의
  * Cloud Storage, BigTable 등 외부 소스는 BigQuery 내부 스토리지보다 느리고 비쌈
  * 외부 소스가 적합한 경우: ETL 작업, 자주 변경되는 데이터, 주기적 로드

* 셔플링 줄이기
  * JOIN 전에 데이터를 최대한 줄이기
  * JOIN 쿼리 테이블 순서 : 큰 테이블부터 작은 테이블 순으로
  * 비정규화 스키마 활용

### 13.2. CPU Time 감소

* 연산량(CPU Time) 줄이기
  * 변환 작업은 중간 테이블로 분리
  * 근사 집계 함수 활용 (가능한 경우)
  * ORDER BY 사용 주의
    * 반드시 가장 바깥쪽 쿼리에서만 사용
  * JOIN 테이블 순서 — 큰 테이블부터 작은 테이블 순

* 출력 데이터 관리
  * LIMIT으로 출력 데이터 제한
  * 중복 저장 방지
  * 구체화된 뷰 크기 주의

### 13.3. SQL Anti-Patterns

## 6. 참고

* [https://www.udemy.com/course/bigquery/](https://www.udemy.com/course/bigquery/)

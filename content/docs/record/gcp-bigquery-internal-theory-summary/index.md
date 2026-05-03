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

## 6. Partitioned Tables

* Stage별 타이밍 지표
  * Average Time : 해당 Stage의 모든 Worker 평균 시간
  * Max Time : 가장 느린 Worker(Long Tail)의 시간

* Worker의 4가지 상태
  * Wait : 스케줄링 대기 또는 이전 Stage 완료 대기
  * Read : 데이터 읽기 및 필터링
  * Compute : 연산 처리 (수식 계산, SQL 함수, 집계 등)
  * Write : 결과 출력 (메모리 또는 디스크에 저장)


## 6. 참고

* [https://www.udemy.com/course/bigquery/](https://www.udemy.com/course/bigquery/)

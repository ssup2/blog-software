---
title: 자격증 AWS Certified Database 이론 정리
---

## 1. Base

아래의 정리된 내용을 바탕으로 부족한 내용 정리

* [AWS Solutions Architecture Assosicate](../certificate-aws-solutions-architect-associate)

## 2. The Basic

### 2.1. Data

* Data Type
  * Structured
  * Semi-structured
  * Unstructured
  * 각 Database 마다 다루기 적합한 Type이 존재 
* Structured Data
  * Table 형태로 Data 저장
  * OLTP, OLAP Workload에 적합
  * 일반적으로 Relational Database에 저장
  * 복잡한 Query나 분석에 적합
    * Ex) 다수의 Table Join
* Semi-structured Data
  * 정렬은 되어 있지마 고정된 Schema는 이용하지 않음
    * Ex) JSON
  * 다양한 Data Type 수용 가능
  * 일반적으로 Non-relational Database에 저장
  * BigData, Low-latency Application에 적합
* Unstructured Data
  * 문서, 이미지, 영상...
  * File System, Object Storage, Data Lake와 같은 별도의 Storage에 저장

### 2.2. Relational Database

* 미리 정의된 Schema
* ACID 특성 충족 및 Join 연산 지원
* OLTP, OLAP 환경에서 이용
* Ex) MySQL, PostreSQL, MariaDB, Oracle, Microsoft SQL Server
* Table Index 생성을 통해서 Query 성능 향상
  * Primary Index
  * Secondary Index
* ACID
  * Atomicty : All or Nothing
  * Consistency : Transaction 이후에도 Data는 Schema와 일치 필요
  * Isolation : 다른 Transaction과 구별
  * Durability : 예상하지 못한 장애 발생시 복구가 가능해야 함

### 2.3. Non-relational Database

## 3. 참고

* [https://www.udemy.com/course/aws-certified-database-specialty-dbs/](https://www.udemy.com/course/aws-certified-database-specialty-dbs/)]
---
title: AWS Certified Database Certificate Theory Summary
---

## 1. Base

Organize missing content based on the following organized content

* [AWS Solutions Architecture Assosicate](../certificate-aws-solutions-architect-associate)

## 2. The Basic

### 2.1. Data

* Data Type
  * Structured
  * Semi-structured
  * Unstructured
  * Each database has a suitable type for handling
* Structured Data
  * Data stored in table format
  * Suitable for OLTP and OLAP workloads
  * Generally stored in Relational Database
  * Suitable for complex queries or analysis
    * Ex) Multiple table joins
* Semi-structured Data
  * Ordered but does not use a fixed schema
    * Ex) JSON
  * Can accommodate various data types
  * Generally stored in Non-relational Database
  * Suitable for BigData and Low-latency applications
* Unstructured Data
  * Documents, images, videos...
  * Stored in separate storage such as File System, Object Storage, Data Lake

### 2.2. Relational Database

* Predefined schema
* Supports ACID properties and join operations
* Used in OLTP and OLAP environments
* Ex) MySQL, PostgreSQL, MariaDB, Oracle, Microsoft SQL Server
* Query performance improvement through table index creation
  * Primary Index
  * Secondary Index
* ACID
  * Atomicity : All or Nothing
  * Consistency : Data must match the schema after transactions
  * Isolation : Distinguished from other transactions
  * Durability : Must be recoverable in case of unexpected failures

### 2.3. Non-relational Database

* NoSQL
* Suitable for Semi-structured and Unstructured data
* Data stored in non-normalized form
* Suitable for Big Data
  * High Volume, High Velocity, High Variety
* Suitable for Low-latency applications
* Flexible data model
* Not suitable for OLAP workloads

## 3. Amazon RDS

* Relational Database Service
* Create clusters inside VPC
* Uses EBS as volume storage and provides volume size auto-scaling functionality
* Provides backup functionality
* Provides snapshot functionality, Cross AZ possible
* Provides monitoring functionality through CloudWatch
* Provides event notification through RDS Events

### 3.1. Cost

* Instance Type
  * On-demand
  * Reserved
* Storage
  * Data storage capacity
  * Backup capacity
  * Snapshot capacity
  * I/O request count
* Data Transfer
  * Inter-AZ traffic cost
  * VPC outbound traffic cost

### 3.2. Parameter Group

* Default Parameter Group exists for each DB engine
* Can create Custom Parameter Group by inheriting Default Parameter Group
* Can apply Parameter Group to DB instances in the same region
* Parameter Examples
  * autocommit
  * time_zone
  * force_ssl
  * default_storage_engine
  * max_connections
* Parameter Changes
  * Dynamic Parameters are applied immediately upon change
  * Static Parameters require DB reboot
    * Static Parameters maintain pending-reboot status before DB reboot
    * Changes to in-sync status after reboot

### 3.3. Option Group

## 4. References

* [https://www.udemy.com/course/aws-certified-database-specialty-dbs/](https://www.udemy.com/course/aws-certified-database-specialty-dbs/)


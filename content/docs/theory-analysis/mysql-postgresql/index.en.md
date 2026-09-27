---
title: MySQL vs PostgreSQL
---

This post compares and analyzes MySQL and PostgreSQL.

## 1. MySQL vs PostgresSQL

### 1.1. Summary

* **MySQL** : Fast performance based on simple features/Architecture
* **PostgreSQL** : Satisfies diverse requirements based on diverse features

MySQL has simpler features/Architecture compared to PostgreSQL. Therefore, it uses fewer Resources than PostgreSQL, and is generally known to show faster performance than PosgreSQL even for simple CRUD operations. In the past Monolithic Architecture, a lot of Business Logic was put into the Database, so the diverse features of the Database were important, but in MSA (Micro Service Architecture), Business Logic is generally handled in the Application, so the importance of Database features drops considerably. Therefore, when choosing an RDMBS for OLTP in MSA, MySQL is generally more suitable than PosgreSQL in many cases.

On the other hand, the diverse features of PostgreSQL are often useful for Data analysis. That is, when choosing an RDBMS for OLAP, PostgreSQL is generally more recommended. For the same reason, when using an RDMBS to build a small-scale Data Warehose, using MySQL is recommended over PostgreSQL.

### 1.2. Relation Database vs Object-Relational Database

### 1.3. Engine

### 1.4. Replication

### 1.5. Client Connection

* **MySQL** : Creates a new Thread when a Client Connection is created
* **PostgreSQL** : Creates a new Process when a Client Connection is created

Since MySQL uses the approach of creating a new Thread, it has the advantage of using fewer Resources compared to PostgreSQL, which creates a Process. This is because the Resources required for Thread creation are less than the Resources required for Process creation, and the Resources required for communication between Threads also cost less than the communication cost between Processes. It is generally known that MySQL is more stable than PostgreSQL when many Client Connections occur.

On the other hand, since PostgreSQL uses the approach of creating a Process, the isolation level and security between Clients are better compared to MySQL, which creates a Thread.

## 2. References

* MySQL vs PostgreSQL - Choose the Right Database for Your Project : [https://developer.okta.com/blog/2019/07/19/mysql-vs-postgres](https://developer.okta.com/blog/2019/07/19/mysql-vs-postgres)
* PostgreSQL vs. MySQL: Differences in performance and uses : [https://www.fivetran.com/blog/postgresql-vs-mysql](https://www.fivetran.com/blog/postgresql-vs-mysql)
* PostgreSQL vs MySQL : [https://www.sumologickorea.com/blog/postgresql-vs-mysql/](https://www.sumologickorea.com/blog/postgresql-vs-mysql/)
* MySQL vs PostgreSQL in 2023 : [https://dbconvert.com/blog/mysql-vs-postgresql/](https://dbconvert.com/blog/mysql-vs-postgresql/)
* [RDBMS] Differences Between PostgreSQL and MySQL (Regardless of Version) : [https://uminoh.tistory.com/32](https://uminoh.tistory.com/32)
* Why You Should Use Postgres Over MySQL For Analytics Purpose : [https://www.holistics.io/blog/why-you-should-use-postgres-over-mysql-for-analytics-purpose/?utm-campaign=pg-mysql&utm-source=medium](https://www.holistics.io/blog/why-you-should-use-postgres-over-mysql-for-analytics-purpose/?utm-campaign=pg-mysql&utm-source=medium)

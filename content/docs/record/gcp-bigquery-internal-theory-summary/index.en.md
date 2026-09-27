---
title: GCP BigQuery Internal Theory Summary
---

## 1. Introduction to BigQuery

### 1.1. Problems of Traditional Data Warehouses

* History of Data Warehouse usage
  * **1990s** : Emergence of Data Warehouse solutions
  * **2000s** : Growing need for Adhoc Query support
  * **2010s** : Data Mining (technique for analyzing based on past data)
  * **Present** : Predicting the future
* Batch Data Ingestion
  * A method of collecting and processing data all at once
  * Real-time data processing is impossible
* Scalability Issue
  * Traditional Data Warehouses lack scalability
* Cost Issue
  * High cost
  * Idle Cost occurs
* Upgrades
  * Manual Upgrade required
  * Downtime occurs
  * DBA required for operation

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
  * Compressed data can be processed directly without decompression
* Stroage
  * Supports Streaming Data and Bulk Load
* Compute
* Petabit Network
  * Connects Storage and Compute


## 2. Dataset & Table Creation

### 2.1. Region vs Multi-Region

* Region
  * Used when Data access is needed only from one Region or nearby Regions
  * Data is also stored in only one Region
* Multi-Region
  * Used when Data access is needed from multiple Regions
  * Data is stored in multiple Regions, which can prevent Soft & Hard Failures

### 2.2. Dataset Creation

* **Default Rounding Mode** : Rounding mode
* **Time Travel Window** : Time range within which data can be recovered


## 3. Using BigQuery Dashboard Options

###  3.1. Running query with varioius query settings

* Destination
  * BigQuery Query results are stored as a Table, and this sets which Table to store them in
  * Save query results in a temporary table
     * Stored in a temporary Table
     * The temporary Table is used for Caching, and is cached for about 24 hours
     * Cannot be shared with other users
     * No additional cost is incurred
  * Select a destination table for query results
     * Stored in a specific Table
     * Storage cost is incurred
     * Can only be stored in a Table of the same DataSet
* **Allow Large Results** : Allows storing results larger than 10GB
* Job Priority
  * **Interactive** : Executes the query immediately
  * **Batch** : Executes when Idle Resources become available, generally within 1~2 minutes. If not executed within 24 hours, it is changed to Interactive and executed

### 3.2. Caching Features & Limits

* To retrive data from stored cached, the query should be exact replica of the original query
* Not cached when destination table is specified to store the results in query
* Not cached if tables/views being used in the query have changed since the last cache.
* Not cached for tables having streaming ingestion.
* Not cached if query uses non-deterministic functions. (`NOW()`, `CURRENT_USER()`)
* Not cached if query runs against external data sources like BigTable or CloudStorage.
* Result set must be smaller than maximum response size (10GB Default)

### 3.3. Wildcard Tables

* Used when you want to query data from multiple Tables at once
  * **Example** : SELECT * FROM `project_id.dataset_id.table_id_*`
* `_TABLE_SUFFIX` : A Pseudo Column when using Wildcard Table queries, which can be used to query only specific Tables
  * **Example** : SELECT * FROM `project_id.dataset_id.table_id_*` WHERE `_TABLE_SUFFIX` = '100' OR `_TABLE_SUFFIX` = '200'
* Limitations
  * Support BigQuery storage only
  * Caching is not supported
  * DML is not supported

### 3.4. Scheduled Queries

* Executes queries at specific times
* Supports Backfill

### 3.5. Auto Schema Detection

* Selects up to 100 Random Rows to detect the Schema
* The following constraints exist
  * Supports only CSV, SON formats
  * Supports Gzip
  * Supports Comma, Pipe, Tab, Delimiter
  * Header from file
  * Supports endline
  * Supports Date in `YYYY-MM-DD` format
  * Supports Timestamp in `yyyy-mm-dd hh:mm:ss` format

## 4. Efficient Schema Design

* A De-normalized Schema is recommended in the BigQuery environment
  * Advantageous for distributed processing
* Supports Nested & Repeated Columns

## 5. Query Plan Execution

* When BigQuery executes an SQL query, it does not simply process it in order but automatically designs an optimized Execution Plan. A concept similar to the EXPLAIN statement in other DBs
* In-Memory Shuffle
  * BigQuery dramatically improves processing speed by storing intermediate data in dedicated **memory nodes**. In particular, data can be consumed by the next worker as soon as it is generated, enabling pipelined execution
* Key performance metrics
  * **Elapsed Time** : Actual elapsed time from query start to completion
  * **Slot Time** : Sum of the time all slots worked
  * **Bytes Shuffled** : Amount of data transferred between stages (lower is better)
  * **Bytes Spilled to Disk** : Amount of data written to disk due to memory overflow (0 is ideal)

## 6. Execution Plan

* Timing metrics per Stage
  * **Average Time** : Average time of all Workers in the Stage
  * **Max Time** : Time of the slowest Worker (Long Tail)
* 4 states of a Worker
  * **Wait** : Waiting for scheduling or waiting for the previous Stage to complete
  * **Read** : Reading and filtering data
  * **Compute** : Computation processing (formula calculation, SQL functions, aggregation, etc.)
  * **Write** : Outputting results (storing in memory or disk)

## 7. Partitioned Tables

* Splits and stores a large table into small segments (partitions) according to specific criteria
* Advantage
  * **Improved query performance** : Reduces processing time by scanning only the needed partitions
  * **Cost reduction** : Reduced amount of data read → Reduced BigQuery billing
  * **Parallel processing** : Independent parallel work can be assigned to each partition
  * **Independent management** : Compression and storage tier (fast/slow disk) can be configured per partition
  * **Efficient large-scale Upserts** : Replaces only the relevant partition instead of the entire table

### 7.1. Ingestion Time Based Partitioning

* **Day** : When data spans a wide date range, when data accumulates continuously (most cases)
* **Hour** : When a large amount of data is concentrated in a short period of less than 6 months
* Automatically generated Pseudo columns
  * `_PARTITIONTIME` : TIMESTAMP, ingestion time (UTC based)
  * `_PARTITIONDATE` : DATE, ingestion date (UTC based)
* Querying Partition Meta
  * `SELECT * FROM dataset1.__PARTITIONS_SUMMARY__`

### 7.2. Specific Column Based Partitioning

* A method of dividing partitions based on the value of a specific date column in the data rather than the ingestion time
* Partitioning column constraints
  * **Type** : Only DATE or TIMESTAMP allowed
  * **Mode** : Required or Nullable allowed, Repeated not allowed
  * **Position** : Must be a top-level field (fields inside a STRUCT not allowed)
* 2 special partitions
  * `__NULL__` : Rows whose partition column value is NULL
  * `__UNPARTITIONED__` : Dates outside the allowed range (e.g. year 9020) + buffer data
* Streaming Buffer mechanism
  * Writing to disk immediately for every record is extremely inefficient, so a buffer is used
  * Even while in the buffer, queries look at the table + buffer simultaneously, so data consistency is guaranteed from the user's perspective
  * Until fully written to disk, the partition it belongs to is not determined, so it is temporarily placed in `__UNPARTITIONED__`

### 7.3. Integer Range Partitioning

* A method of dividing partitions based on an integer column value in the data, according to a user-specified start value, end value, and interval
* Partition range settings
  * **Start** : Partition start value
  * **End** : Partition end value
  * **Interval** : Partition interval
* Constraints
  * **Maximum partitions per table** : 4,000
  * **Maximum partitions modified per single job** : 4,000
  * **Daily modification limit for ingestion time partitioned tables** : 5,000
  * **Daily modification limit for column-based partitioned tables** : 30,000

### 7.4 Partition Expiration

* Expiration time is set with the `ALTER` statement (Web UI not supported)
* Different expiration times cannot be set for individual partitions → Applied uniformly to the entire table
* Table expiration > Partition expiration (when the table is deleted, the partitions are deleted with it)
  * Table expiration 5 days, partition expiration 7 days → All deleted after 5 days
* Partition expiration setting priority
  * 1st priority: Explicit setting with the `ALTER` statement
  * 2nd priority: Setting at table creation
  * 3rd priority: Dataset default setting
  * No expiration → Manual deletion required

### 7.5. Partition Best Practices

* **Recommended O** : Use the partition column alone in the WHERE clause

```
-- 좋음: 파티션 컬럼을 좌변에 단독으로
WHERE _PARTITIONTIME > TIMESTAMP_SUB(TIMESTAMP('2024-01-01'), INTERVAL 1 DAY)

-- 나쁨: 파티션 컬럼에 연산 포함
WHERE _PARTITIONTIME + INTERVAL 1 DAY > '2024-01-01'
```

* **Recommended O** : Use additional filters with AND conditions

```
-- 좋음: AND는 스캔 범위를 더 좁혀줌
WHERE department = 45 AND id = 1
```

* **Recommended X** : Adding non-partition columns with OR conditions

```
-- 나쁨: OR로 비파티션 컬럼이 들어오면 전체 스캔
WHERE department = 45 OR id = 1
-- id가 어느 파티션에 있는지 알 수 없어 풀스캔 발생
```

* Including operations with other columns on the partition column

```
-- 나쁨: 전체 스캔 발생
WHERE department + LENGTH(name) = 45
```

* Using a subquery in the WHERE clause

```
-- 나쁨: 파티션 제거 효과 없음
WHERE department = (SELECT MAX(department) FROM ...)
```

* Comparing the partition column with another column

```
-- 나쁨: 전체 스캔 발생
WHERE _PARTITIONTIME > ts1  -- ts1은 테이블의 다른 컬럼
```

* Creating too many partitions
  * Metadata accumulates per partition, which actually degrades performance
  * If there are too many partitions, it becomes no different from a non-partitioned table
  * In such cases, using a clustered table instead of partitioning is recommended

## 8. Clustered Tables

* Limitations of partitioning
  * When there is still too much data within a partition
  * When partition sizes are unbalanced (differences in headcount by department, etc.)
* Clustering
  * A method of gathering and storing data inside a partition into the same bucket (file) based on specific column values. It is the same concept as Bucketing in Hive.
* Partition vs Cluster
  * **Partition** : Directory
  * **Cluster** : Files inside a partition directory
* Using only partitioning
  * When you need to know the exact amount of processed data and cost in advance before executing a query
  * When detailed management such as partition-level expiration and DML is needed
* Using partitioning + clustering
  * When data is large and sophisticated data organization is needed
  * When mainly executing Aggregation and filtering queries frequently
  * When advance cost prediction is not very important
* Using only clustering
  * When partitioning would create too many partitions, in the thousands or more
  * When the average partition size is small, less than 1GB

### 8.1. Best Practices

* Keep the order of WHERE clause columns the same as the order at creation : O
```
-- 테이블 생성 시: CLUSTER BY name, surname
-- 좋음: 생성 순서와 동일
WHERE name = 'John' AND surname = 'Doe'

-- 나쁨: 순서가 다르면 최적 성능 보장 안 됨
WHERE surname = 'Doe' AND name = 'John'
```

* Do not use complex expressions on cluster columns : O

```
-- 좋음: 단순 비교 → 100KB만 스캔
WHERE layer_code = 123

-- 나쁨: 캐스팅/연산 포함 → 203GB 전체 스캔
WHERE CAST(layer_code AS STRING) = '123'
```

* Do not compare cluster columns with other columns : X

```
WHERE cluster_column = other_column
```

### 8.2. Partitioning Limits

* **Query method** : Only Standard SQL supported
* **Cluster column specification** : Must be specified at table creation
* **Cluster column change** : Can be changed via API, but applies only to data loaded afterwards
* **Column position** : Only top-level fields allowed (fields inside STRUCT, ARRAY not allowed)
* **Maximum number of cluster columns** : 4
* **Supported types** : DATE, BOOLEAN, GEOGRAPHY, INTEGER, NUMERIC, STRING, TIMESTAMP
* **Quota** : Same as regular tables (Load/Export/Query/Copy)

## 9. Loading & Querying External Data Sources

* Data in external storage (GCS) can be queried directly from BigQuery

### 9.1. Limitations

* Data consistency not guaranteed
  * If external data changes while a query is running, unexpected results may occur
* Degraded query performance
  * If speed matters, loading the data directly into BigQuery is recommended
  * Performance differences exist by storage type
    * Cloud Storage > Google Drive
* Direct Export not possible
  * Query re-execution required when external data changes
* Wildcard table queries not possible
  * External data sources cannot be referenced in wildcard table queries.
* Limited partitioning/clustering support
  * Supported formats: Avro, Parquet, ORC, JSON, CSV (Cloud Storage)
  * Supported only with the Hive partitioning layout
  * Partitioning keys must not overlap with columns
  * Only Standard SQL supported
* No query result caching
  * Running the same query repeatedly is billed every time.

## 10. View

* A virtual table defined by an SQL query. It does not store actual data, but shows query results like a table
* Characteristics
  * **Data storage** : No physical data
  * **Read/Write** : Read-only (`INSERT`/`UPDATE`/`DELETE` not possible)
  * **Schema independence** : Even if the base table schema changes after creation, the view schema remains as is
  * **When the base table is deleted** : The view is invalidated and queries fail
  * **Storage cost** : Free (query cost is the same as a table)
* Reasons to use Views
  * Security/access control
    * Different columns can be shown to each user.
  * Base table protection
    * Since a view is read-only, there is no risk of accidentally changing or deleting base table data.
  * Simplifying complex queries (storing Join Query results as a View)
  * Free storage space (since no actual data is stored, no storage cost is incurred.)
* Regular View vs Materialized View
  * **Data storage** : X vs O
  * **Storage cost** : Free vs Cost incurred
  * **Query performance** : Queries the base Table vs Returns stored results immediately
  * Stores only the query vs Stores the query results in actual Storage

### 10.1. Row-Level Security

* Different data can be shown to each specific user
* How to apply
  * Use the `SESSION_USER()` function to return the email of the user executing the current query

### 10.2. Limitations

* **Dataset** : The view and referenced tables must be in the same Location
* **Data Export** : Since a view has no physical data, direct Export is not possible
* **Mixing SQL dialects** : Standard SQL and Legacy SQL cannot be mixed
* **Query parameters** : Cannot be referenced in the view definition query
* **User Defined Functions** (UDF) : Cannot be included in the query defining the view (can be used when querying the view)
* **Wildcard tables** : Cannot be referenced in wildcard table queries
* **Nested views** : Maximum 16 levels
* **Number of authorized views per dataset** : 2500

## 11. Materialized View

* **Data Refresh** : Manual refresh, enabling Auto Refresh → Automatically refreshed periodically
* **Smart Query Optimization** : BigQuery automatically leverages materialized views when executing regular queries
* Provides up-to-date data with streaming tables
* Cases where Materialized Views are useful
  * **Repetitive and predictable queries** : Pre-computed results can be reused
  * **ETL/BI pipelines** : Patterns of repeatedly executing the same query
  * **Aggregation queries** (SUM, AVG, etc.) : When computation time is long but results are small

### 11.1. Alert Materialized View

* Supported
  * `CREATE` : Create a Materialized View
  * `DROP` : Delete a Materialized View
  * `ALTER` : Only Auto Refresh can be changed
* Not possible
  * `COPY` : Materialized Views cannot be copied
  * `IMPORT`/`EXPORT` : Cannot import into or export from a Materialized View
  * `INSERT` : Cannot write directly to a Materialized View
  * **BigQuery Storage API** : Direct access via the API not possible
* When the base Table is deleted
  * Even if the base Table is recreated with the same name, the Materialized View must also be recreated

### 11.2. Leveraging Materialized Views for Ad-hoc Queries

* Using a subset of the MV's GROUP BY/aggregation columns
* Applying operations to GROUP BY columns
* Filtering by the MV's grouping columns or existing filter conditions
* Filtering by a subset of the MV's filters

### 11.3. Materialized View Refresh

* Change types
  * `INSERT` only (append) : Reads only the changed delta data and appends it
  * `UPDATE`/`DELETE`/`MERGE` : Invalidates the affected part and re-reads it
* Difference depending on partitioning
  * **Partitioned MV** : Only the affected partitions are invalidated + re-read
  * **Non-partitioned MV** : Full invalidation + full re-read of the base table
* Refresh methods
  * Manual refresh
  * Auto Refresh setting
* How Auto Refresh works
  * Detects base table changes
  * Automatically refreshes within 5 minutes (after a change occurs)
  * However, the minimum refresh interval is respected (default 30 minutes) : Even if the base table keeps changing, it is refreshed at most once every 30 minutes
* Handling data in the period between refreshes
  * `INSERT` only : MV data + delta data since the last refresh combined
  * `UPDATE`/`DELETE` : The MV is not scanned and the base table is queried directly
* BigQuery always guarantees up-to-date data regardless of whether the MV has been refreshed. Before a refresh, consistency is maintained by combining the delta or querying the base table directly.

### 11.4. Materialized View Limitations

| Item | Regular View | Materialized View |
|------|------|------|
| Data storage | ❌ | ✅ |
| Storage cost | Free | Incurred |
| Query performance | Slow | Fast |
| `JOIN` support | ✅ | ❌ |
| Nesting | 16 levels | ❌ |
| Referenced tables | Multiple | Single |
| DML | ❌ | ❌ |
| Dataset location | Free | Same dataset |
| Maximum count | 2,500/dataset | 20/base table |
| SQL dialect | Legacy/Standard | Standard SQL only |

* Impossible operations
  * `COPY` : Cannot be copied as source/destination
  * `EXPORT` : Cannot export data
  * `LOAD` : Cannot load data directly
  * `INSERT` : Cannot write query results directly
  * **DML** : `UPDATE`/`DELETE`/`MERGE` not possible
  * `UNNEST` : Cannot unnest arrays
  * `JOIN` : Cannot join multiple tables
  * **MV nesting** : Cannot create an MV based on an MV

### 11.5. Materialized View Best Practices

* Design Materialized Views to cover a wide range of queries
  * Since there is a limit of up to 20, design around grouping rather than fine-grained filters.

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

* Include date ranges frequently used by users in advance when creating the Materialized View
* If the Materialized View is large, apply partitioning to the Materialized View as well
* Set the Auto Refresh interval according to the data change pattern (for cost optimization)
  * **Base table changes rarely** : Set a long refresh interval
  * **Base table changes frequently** : Set a short refresh interval
  * **Data loaded via ETL/nightly batch** : Turn off Auto Refresh and refresh manually or on a schedule
* Batch DML operations and refresh manually
  * Since `UPDATE`/`DELETE`/`MERGE` invalidate the MV, execute them batched together rather than individually, then refresh manually.
* When `JOIN` is needed, create the aggregation as an MV first
  * `JOIN` is not supported when creating a Materialized View
  * Create an aggregation Materialized View first, then combine it with the original Base Table using a `JOIN` query

## 12. Pricing

### 12.1. Storage Pricing

* Active data vs long-term data
  * **Active data** : Tables/partitions modified within the last 90 days
  * **Long-term data** : Tables/partitions not modified for 90 consecutive days
* Active storage
  * **Multi-region** (US & Europe & Asia) : $0.02/GB/month
  * **Single region** : $0.02 ~ $0.023/GB/month
* Long-term storage
  * **Multi-region** (US & Europe) : $0.01/GB/month
  * **Single region** : $0.01 ~ $0.012/GB/month
* Common points
  * The first 10GB each month is free. Storage is measured in MB/second
  * Pricing examples
    * Storing 100MB for half a month → about $0.001
    * Storing 500GB for half a month → about $5.00
* Key behavior
  * Each partition is evaluated independently. If only one partition is modified, only that partition switches to the active rate and the rest keep the long-term rate.
  * Operations that reset the 90-day timer
    * Loading data (append or overwrite mode)
    * Copying data into a table
    * Saving query results to a table
    * DML / DDL operations
    * Streaming data into a table
  * Operations that do not reset the timer
    * Querying a table
    * Creating a view that queries a table
    * Exporting data from a table
    * Copying a table to another destination table
    * Patching/updating a table resource

### 12.2. Query Pricing

* Two pricing plans
  * On-demand pricing
    * Billed only when queries are executed
    * Number of bytes processed
    * Applied by default
  * Flat Rate
    * Purchasing slots (subscription)
    * Allocated processing capacity
    * Requires separate switching
* On-demand pricing
  * Billed by the number of bytes processed regardless of data location (same for BigQuery, Cloud Storage, BigTable)
  * 1TB per month is free
* Flat Rate
  * A subscription model suitable for customers who want stable costs.
  * No additional billing for bytes processed
  * Includes all BigQuery ML, DML, and DDL queries
  * Storage, streaming ingestion, and BI Engine costs are separate
  * Slots are a regional resource (cannot be moved to another region)
  * Minimum purchase of 100 slots, expandable in units of 100 slots
  * Slots can be shared across the entire organization
  * When capacity is exceeded, requests are handled via a **Queue** without additional billing

### 12.3. API, DML Pricing

* Streaming Inserts
  * Loading data via File Upload is free
  * When loading in streaming ingestion mode, billed by the number of bytes processed
  * Only successfully loaded data is billed
  * **Minimum billing unit per row** : 1KB
* DML Query Cost
  * Billed only when a data scan occurs. The billing basis differs depending on the table type and the kind of DML operation.
  * `INSERT` : Sum of bytes of all columns referenced by the SELECT from the source table
  * `UPDATE` : Sum of bytes of referenced columns + sum of bytes of all columns of the rows being modified
  * `DELETE` : Sum of bytes of referenced columns + sum of bytes of all columns of the rows being deleted
  * `MERGE` : The above formulas applied to each contained `INSERT`/`UPDATE`/`DELETE`
* BigQuery Storage API pricing
  * An API for fast access to BigQuery storage via an RPC-based protocol.
  * **Flat-rate customers** : Free reads up to 3TB per month, on-demand rates apply beyond that
  * **On-demand rate** : $1.10 / TB (available only in multi-region)
  * **Reading temporary tables** : Free
* When calling the ReadRows method, billing also occurs in the following cases
  * When the ReadRows call fails → Billed for the data read
  * When the ReadRows call is cancelled midway → Billed for the data read before cancellation
  * Data read before cancellation but not returned is also billable

### 12.4. Free Operations

* Data Load
  * Loading data from Cloud Storage or local files into BigQuery
  * However, storage costs while stored in Cloud Storage and BigQuery storage costs after loading are billed separately
* Network
  * If the destination dataset is the US multi-region, network costs are free when loading from a Cloud Storage bucket in another region
* Copy & Export
  * Table copy is free (however, storage costs for the source/copied tables are billed)
  * Exporting data from BigQuery → Cloud Storage is free (however, Cloud Storage storage costs are billed)
* Delete operations (all free)
  * Deleting a dataset
  * Deleting a table
  * Deleting a view
  * Deleting a table partition
  * Deleting a User Defined Function (UDF)
* Metadata operations
  * Most metadata operations such as List, Get, Patch, Update, and Delete calls are free
  * Listing datasets, updating dataset ACLs, updating table descriptions, listing UDFs, etc.
* Pseudo Column queries
  * `_TABLE_SUFFIX` (when querying wildcard tables)
  * `_PARTITIONDATE` / `_PARTITIONTIME` (when querying ingestion time partitioned tables)

## 13. Best Practices

* Core principle
  * "A query that does less work is faster and cheaper"
  * In a cloud environment, performance and cost must be considered together. Increasing resources to improve performance is always possible, but costs increase accordingly.
* Why is query optimization important?
  * For the on-demand pricing plan
    * The more data a query scans, the higher the cost
    * A single line difference in a query can save hundreds of dollars
  * For the Flat Rate plan
    * When slots are exceeded, requests are queued rather than additional slots being purchased
    * Query optimization comes before purchasing additional slots
* 5 factors affecting query performance/cost
  * **Input data** : How many bytes does the query read?
  * **Inter-node communication** (shuffling) : How many bytes are passed to the next stage?
  * **Computation** : How much CPU time is needed?
  * **Output data** : How many bytes does the query write?
  * **Query anti-patterns** : Are SQL best practices being followed?

### 13.1. Limiting Data Scan

* Data Scan optimization
  * Do not use SELECT *
  * LIMIT has no cost-saving effect (beware of this misconception!)
  * Actively use partitioning & clustering
  * De-normalize data
  * Use Materialized Views
  * Use cached results
  * Be careful when using external data sources
  * External sources such as Cloud Storage and BigTable are slower and more expensive than BigQuery internal storage
  * Cases where external sources are suitable: ETL jobs, frequently changing data, periodic loads
* Reducing shuffling
  * Reduce data as much as possible before `JOIN`
  * `JOIN` query table order : From the largest table to the smallest table
  * Use a de-normalized schema

### 13.2. Reducing CPU Time

* Reducing computation (CPU Time)
  * Separate transformation work into intermediate tables
  * Use approximate aggregation functions (where possible)
  * Be careful when using ORDER BY
    * Use it only in the outermost query
  * `JOIN` table order — from the largest table to the smallest table
* Managing output data
  * Limit output data with LIMIT
  * Prevent duplicate storage
  * Watch the size of materialized views
    * Default maximum response size: 10GB (compressed)
    * Storing large results exceeding this can cause performance degradation

### 13.3. SQL Anti-Patterns

* Beware of SQL anti-patterns
  * No Self Joins → Replace with window functions
  * No Cross Joins → Replace with pre-aggregation or window functions
  * Beware of Data Skew
    * Data skew is a state where data sizes between partitions are extremely unbalanced
    * Cause: Data concentrated on specific values of the partition key column
    * Solution: Change the partition key or use a composite partition key
  * Do not use BigQuery like an OLTP system
    * DML that modifies one row at a time is unsuitable for BigQuery
    * If single-record processing is needed → Using Cloud SQL is recommended
    * In BigQuery, updates/inserts must be batched together
* Project-wide cost saving strategies
  * Set table/partition expiration times
  * Keep data only for the period needed → Old data is automatically deleted
    * Example: Only the last 7 days of data needed → Set expiration to 7 days → Rolling 7 days of data maintained
    * Also useful for experimental data (automatic cleanup after testing)
  * Actively leverage long-term storage pricing
    * About 50% discount applied automatically after 90 days without modification
    * Similar level to Cloud Storage Nearline pricing
    * Keeping it in BigQuery internal storage → Good query performance and reduced cost

## 14. File Format, Apache Beam

### 14.1. Text File

| Item | CSV/TSV | Sequence | Avro | RC | ORC | Parquet |
|---|---|---|---|---|---|---|
| **Read performance** | Slowest | Slow | Medium | Good | Fastest | Good |
| **Write performance** | Fastest | Fast | Medium | Low | Slowest | Medium |
| **Compression unit** | Whole file | Block | Block | Block | Block | Block |
| **Supported compression** | bzip2, etc. | Various | Deflate, Snappy | High compression ratio | Zlib, Snappy, LZO, LZ4 | Snappy, GZip, LZO_1X |
| **Splittable** | Yes | Yes | Yes | Yes | Yes (per stripe) | Conditionally |
| **Metadata** | Not supported | Not supported | Supported | Not supported | Not supported | Supported |
| **Schema evolution** | Append only | Append only | Fully supported | Not supported | Not supported | Append at end only |
| **Nested structures** | Not supported | Not supported | Supported | Not supported | Not supported | Supported |
| **Storage format** | Row based | Row based | Row based | Columnar | Columnar | Columnar |
| **BigQuery recommendation** | Fast when uncompressed | N/A | Top recommendation | N/A | N/A | N/A |
| **Suitable use** | DB dumps, fast writes | Fast writes | Frequent schema changes | Read-heavy | Read-optimized | Read-heavy, nested structures |

| Situation | Recommended format | Reason |
|---|---|---|
| **Schema changes frequently** | Avro | Full schema evolution support |
| **Write-heavy** (DB/HDFS dumps, etc.) | Text (CSV) | Best write performance |
| **Read-heavy** (data lakes, etc.) | Parquet / ORC | Read-optimized columnar format |
| **MapReduce intermediate data** | Sequence | Fast network transfer as binary format |
| **BigQuery data loading** | Avro | Officially recommended format for BigQuery |

### 14.2. Apache Beam

* An open-source data processing programming model that handles batch and stream data with one unified API and can run on any execution engine
* In Beam, focus only on the data itself without distinguishing batch/stream
* No need to care about the pipeline type
* Supported languages
  * Java (most mature), Python (2nd), Go, more being added
  * Apache Spark
  * Apache Flink
  * Google Cloud Dataflow
  * Apache Apex
  * Apache Samza
  * Apache Gearpump

## 15. References

* Google BigQuery Udemy Course : [https://www.udemy.com/course/bigquery/](https://www.udemy.com/course/bigquery/)

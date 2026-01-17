---
title: AWS Certified Data Analytics Certificate Theory Summary
---

## 1. Base

Organize missing content based on the following organized content

* [AWS Solutions Architecture Assosicate](../certificate-aws-solutions-architect-associate)

## 2. Collection

* RealTime : Real-time data collection
  * Kinesis Data Streams (KDS)
  * Simple Queue Service (SQS)
  * Internet of Things (IoT)

* Near-real Time : Near-real-time data collection
  * Kinesis Data Firehose (KDF)
  * Database Migration Service (DMS)

* Batch : Batch data collection
  * Snowball
  * Data Pipeline

### 2.1. Kinesis Data Streams

* Composed of multiple shards
* Retention : 1 ~ 365 Days
* Stored data cannot be deleted
* Producer
* Record
  * Data sent by producer
  * Partition Key : Determines which shard the record is delivered to
  * Data Blob : Data storage
* Consumer
* Capacity Mode
  * Provisioned Mode
    * User specifies the number of shards
    * Cost per shard
  * On-demand Mode
    * Automatically scales based on traffic volume
    * Default performance : 4 MB/sec, 4000 msg/sec
    * Cost based on shard count and traffic volume
* Security
  * IAM-based authentication/authorization
  * HTTPS used for data encryption in transit
  * KMS used for data encryption at rest
  * Accessible via VPC Endpoint within VPC
  * Tracking through CloudTrail

#### 2.1.1. Kinesis Producer

* Ex) Application, SDK KPL, Kinesis Agent, CloudWatch Logs, AWS IoT, Kinesis Data Analytics
* Performance
  * 1 MB/sec, 1000 msg/sec limit per shard
  * ProvisionedThroughputExceeded Exception occurs when exceeded
    * Need to check if sending more data or if hot shard is occurring
    * Resolve by retrying with backoff, increasing shards, checking partition key
* API
  * Single : PutRecord
  * Multiple : PutRecords
* Kinesis Producer Library (KPL)
  * Supports C++/Java
  * Retry logic support
    * Holds data for up to 30 minutes and retries
  * Supports Sync and Async API
  * Sends metrics to CloudWatch
  * Performs batching
    * Increases throughput, reduces cost
    * Waits for RecordMaxBufferedTime duration then sends at once (Default 100ms)
    * Latency occurs compared to using Write API directly, so KPL is not recommended for applications where latency is important
  * Does not provide compression, needs to be implemented in app
  * Records encoded with KPL must be decoded through KPL or Helper Library
* Kinesis Agent
  * Sends log files to Kinesis Data Streams
  * Based on KPL
  * Supports data preprocessing

#### 2.1.2. Kinesis Consumer

* Ex) Application, AWS Lambda, Kinesis Data Firehose, Kinesis Data Analytics
* Performance
  * Default : 2 MB/sec for all consumers
  * With Enhanced Fan Out : 2 MB/sec per consumer
* API
  * GetRecords
    * Retrieves multiple records
    * Requires client polling
    * Can receive up to 2 MB data per shard per call
    * Can receive up to 10 MB data, 10000 records per call
      * Throttled for 5 seconds when receiving 10 MB due to performance limits
    * Can access up to 5 times per second per shard
* Kinesis Client Library (KCL)
  * Golang, Python, Ruby, NodeJs
  * Multiple consumers can distribute and process multiple shards through group functionality
  * Can resume data processing through checkpointing functionality
  * Performs de-aggregation of data aggregated through KPL
* Kinesis Connector Library
  * Delivers data to other AWS services
  * Needs to run on EC2 instance
  * Deprecated : Replaced by Kinesis Firehose
* Lambda
  * De-aggregated and delivered to Lambda function
  * Can specify batch size

#### 2.1.3. Kinesis Scaling

* Adding Shards
  * When adding shards, multiple child shards are created replacing existing parent shard
  * Recommended to process data in child shards after processing all data in parent shard
    * Implemented internally in KCL
* Merging Shards
  * When merging shards, one child shard is created replacing multiple existing parent shards

#### 2.1.4. Duplicated Records

* Producer
  * Due to temporary network failures, the same record may be duplicated and stored in stream
  * Cannot avoid duplicate storage, needs duplicate processing at consumer
* Consumer
  * Add unique ID to data, process app logic so that duplicate processing does not occur even when receiving the same data

### 2.2. Kinesis Data Firehose

* Loads data to AWS services and 3rd party applications
* Fully Managed Service : Supports auto-scaling
* Near Real Time : Minimum 60 second delay occurs
* Compression support : GZIP, ZIP, SNAPPY
* Producer
  * SDK KPL, Kinesis Agent, Kinesis Data Streams, Amazon CloudWatch, AWS IoT
  * Maximum 1MB per record
* Consumer
  * Amazon S3, Amazon OpenSearch, Datadog, Splunk, New Relic, MongoDB, HTTP Endpoints
  * Performs batch writes
* Transformation
  * Can transform data using Lambda

## 3. Processing

### 3.1. Glue

* Performs serverless ETL
* Can process data from S3, RDS, Redshift
* Glue Crawler
  * Generates schema from S3 data
  * Generated schema is stored in Glue Data Catalog
* Glue Data Catalog
  * Schema information storage
  * Can be created through user input or Glue Crawler
  * Can convert EMR Hive metastore to Glue Data Catalog
  * Can be provided as Hive metastore from EMR Hive
* Glue Studio : Processes Glue jobs through visual interface
* Glue Data Quality
  * Service for data quality evaluation and inspection
  * Defines rules using DQDL (Data Quality Definition Language)
  * Available in Glue Studio

### 3.2. Glue DataBrew

### 3.3. Lake Formation

* Manages data access permissions for Data Lake (S3)
* Provides data monitoring functionality
* Provides data transformation functionality
* Based on Glue

### 3.4. Amazon Security Lake

* Centralizes data security
* Normalizes data including multi-account and on-premise environments
* Manages data lifecycle

### 3.5. EMR

* Managed Hadoop framework based on EC2
  * Spark, HBase, Presto, Flink
  * EMR Notebooks

### 3.5.1. EMR Cluster

* Master Node
  * Tracks task status, manages cluster status
* Core Node
  * Provides HDFS, performs tasks
  * Must have at least one core node in multi-node cluster
    * Because HDFS is still used in some Hadoop ecosystem components
  * Can scale up & down but data loss risk exists
* Task Node
  * Performs tasks
  * No data loss risk when removed since it does not store data like HDFS
  * Suitable for Spot instances
* Transient vs Long-Running Cluster
  * Transient Cluster
    * Removes cluster after task completion
    * Suitable for batch jobs
  * Long-running Cluster
    * Performs stream tasks using RI instances
    * Performs batch tasks using Spot instances
* Task Submission
  * Submit tasks by directly accessing master node
  * Submit tasks through AWS Console

### 3.5.2. EMR with AWS Services

* Stores input data and output data in S3
* Performs performance monitoring through CloudWatch
* Manages authorization through IAM
* Performs audit through CloudTrail
* Configures task scheduling and workflow through AWS Data Pipeline and AWS Step Functions

### 3.5.3. EMR Storage

* HDFS
  * Composed of core node cluster
  * Same lifecycle as EMR cluster, HDFS data is also deleted when EMR cluster is removed
  * Recommended for caching temporary data due to faster performance than EMRFS
* EMRFS
  * S3-based filesystem
  * Separate lifecycle from EMR cluster, data preserved even when EMR cluster is removed
  * Guarantees strong consistency in S3
* Local Filesystem
  * Used for temporary cache

### 3.5.4. EMR Managed Scaling

* EMR Automatic Scaling
  * Based on CloudWatch metrics
  * Only supports instance groups
* EMR Managed Scaling
  * Supports instance groups and instance fleets
  * Supports Spark, Hive, YARN workloads

### 3.5.5. EMR Serverless

* Supports Spark, Hive, Presto
* Automatically manages cluster size
* Users can specify size
* Processes tasks only within one region

### 3.5.6. EMR Spark

* Can integrate with Kinesis and Spark Streaming
* Can store data processed through Spark in Redshift
* Can analyze data by executing Spark in Athena Console

### 3.5.7. EMR Hive

* Can query data stored in HDFS and EMRFS using SQL (HiveQL)
* Performs distributed SQL processing based on MapReduce and Tez
* Suitable for OLAP
* Supports User Defined Functions, Thrift, JDBC/ODBC drivers
* Metastore
  * Data structure information
  * Column name and type information
  * Stores metastore in MySQL on master node by default
  * Recommends storing in Glue Data Catalog or Amazon RDS in AWS environment
* Integration with AWS Services
  * Can load data from S3 and write data to S3
  * Can load scripts from S3

### 3.5.8. EMR Apache Pig

* Provides script environment to quickly help write Mapper and Reducer
* Performs Map and Reduce steps using SQL-like syntax
* Provides user-defined functions (UDFs)
* Performs distributed processing based on MapReduce and Tez
* Integration with AWS Services
  * Can query S3 data
  * Can load JAR and scripts from S3

### 3.5.9. EMR HBase

* Non-relational, petabyte-scale database
* Based on HDFS and Google BigTable
* Performs computation in memory
* Integration with AWS Services
  * Supports S3 data storage through EMRFS
  * Can backup to S3

### 3.5.10. EMR Presto

* Can connect to various big data databases
* HDFS, S3, Cassandra, MongoDB, HBase, SQL, Redshift, Teradata
* Suitable for OLAP tasks

### 3.5.11. EMR Hue, Splunk, Flume

* Hue
  * Provides web interface for EMR cluster management
  * Provides integration with IAM
  * Provides data movement functionality between HDFS and S3
* Splunk
* Flume
  * Log aggregation platform
  * Based on HDFS and HBase
* MXNet
  * Neural network construction platform
  * Included in EMR

### 3.5.12. EMR Security

* Can use various authentication/authorization methods
  * IAM Policy, IAM Role, Kerberos, SSH
* Block Public Access
  * Blocks public access

### 3.6. AWS Data Pipeline

* Can set S3, RDS, DynamoDB, Redshift, EMR as data transfer destinations
* Manages task dependencies
* Retries tasks and notifies on failure
* Supports cross-region pipelines
* Supports precondition checks
* Supports on-premise data sources
* Provides high availability
* Provides various activities
  * EMR, Hive, Copy, SQL, Script

### 3.7. AWS Step Functions

* Workflow service
* Provides easy visualization functionality
* Provides error handling and retry functionality
* Provides audit functionality
* Provides wait functionality for arbitrary duration

## 4. Analytics

### 4.1. Kinesis Analytics

* Real-time data processing service
* Components
  * Input Stream : Stream where data enters
  * Reference Table : Table referenced during data processing, can join with S3 data
  * Output Stream : Stream that outputs processed data
  * Error Stream : Stream that outputs data that occurred during data processing
* with Lambda
  * Can specify Lambda as data destination
  * Modifies data and delivers to AWS services
* with Apache Flink
  * Supports Apache Flink framework
  * Write Flink applications instead of SQL queries
  * Serverless
    * Performs auto-scaling
    * Measures cost in KPU units
    * 1 KPU = 1 vCPU, 4 Memory
  * Components
    * Flink Source : MSK, Kinesis Data Streams
    * Flink Datastream API
    * Flink Sink : S3, Kinesis Datastream, Kinesis Data Firehose
  * RANDOM_CUT_FOREST
    * SQL function that performs anomaly detection

### 4.2. OpenSearch

* Search engine based on ElasticSearch
* Scalable
* Based on Lucene
* Use cases
  * Full-text search
  * Log analytics
  * Application monitoring
  * Security analytics
  * Clickstream analytics
* Concept
  * Document : Search target, supports not only full-text but also JSON structure
  * Types : Schema definition, not commonly used currently
  * Indices
    * Composed of inverted index
    * Composed of multiple shards, performs distributed processing
    * Primary Shard : Performs read/write
    * Replica Shard : Can only perform reads, performs load balancing when multiple replicas are configured
* Fully-managed (Not Serverless)
* Performs scale in/out without downtime
* Integration with various AWS services
  * S3 Bucket
  * Kinesis Data Streams
  * DynamoDB Streams
  * CloudWatch, CloudTrail
  * Zone Awareness
* Options
  * Dedicated Master Node : Number and spec of nodes
  * Domains : Means all information needed to run cluster (configuration information)
  * Provides S3-based snapshot functionality
  * Zone Awareness
* Security
  * Resource-based policy
  * Identity-based policy
  * IP-based policy
  * Request signing
  * Private cluster in VPC
  * Dashboard Security
    * AWS Cognito
    * Outside VPC
      * SSH Tunnel
      * Reserve Proxy on EC2 Instance
      * VPC Direct Connect
      * VPN
* Not suitable for OLTP tasks
  * Does not provide transaction functionality

### 4.2.1. Index Management

* Storage Type
  * Hot Storage
    * Fastest store, but high cost
    * EBS, Instance Store
    * Default store
  * Ultra Warm Storage
    * Based on S3 + Caching
    * Requires dedicated master node
    * Advantageous for cases with low writes like logs and immutable data
  * Cold Storage
    * Based on S3
    * Advantageous for storing old or periodic data
    * Requires dedicated master node, requires UltraWarm activation
    * Not available on T2, T3 instance types
  * Data migration possible between storage types
* Index State Management (ISM)
  * Deletes old indices
  * Converts index to read-only
  * Moves index from Hot -> UltraWarm -> Cold Storage
  * Reduces replica count
  * Automatic index snapshot
  * Summarizes index through rollup
    * Cost reduction
  * Executes at 30 ~ 48 minute intervals
  * Sends notification when execution completes
* Provides cross-cluster replication functionality
  * Ensures high availability
  * Follower index synchronizes by fetching data from leader index
* Stability
  * Recommends using 3 dedicated master nodes
  * Disk capacity management
  * Selecting appropriate shard count
    * ??

### 4.2.2. Performance

* When memory pressure occurs
  * When shards are unevenly distributed
  * When there are too many shards
* Deletes old and unused indices when JVM memory pressure occurs

### 4.3. Athena

* SQL query service for S3
* Based on Presto
* Serverless
* Supports various formats
  * CSV, TSV, JSON, ORC (Columnar), Parquet (Columnar), Avro, Snappy, Zlib, LZO, Gzip
* Athena collects metadata through Glue Data Catalog
* Various use cases
  * Ad-hoc queries for app log analysis
  * Queries for data analysis before loading data into Redshift
  * CloudTrail, CloudFront, VPC, ELB log analysis
  * Integration with QuickSight
* Provides workgroups functionality
  * Can track query access permissions and costs per workgroup
  * Can integrate with IAM, CloudWatch, SNS
  * Can configure the following per workgroup
    * Query history, data limit, IAM policy, encryption settings
* Cost
  * $5 per TB
  * Charges per successful or cancelled query
  * Failed queries are not charged
  * DDL is not charged
  * Cost reduction and performance benefits when using columnar format
  * Glue and S3 are charged separately
* Performance
  * Performance benefits when using columnar format
  * Should be composed of fewer large files for performance benefits
  * Utilize partition functionality
* Transaction
  * Available through Iceberg
    * Specify ICEBERG in table type
  * Transaction functionality also available through Lake Formation's governed tables

### 4.4. Redshift

* Service for OLAP
* Provides SQL, ODBC, JDBC interfaces
* Scale-up/down on-demand method
* Built-in replication
* Monitoring based on CloudWatch and CloudTrail
* Architecture
  * Leader Node
    * Receives client queries and creates parallel processing plan
    * Distributes tasks to compute nodes and collects results according to parallel processing plan
  * Compute Node
    * Can configure up to 128 compute nodes
    * Type
      * Dense Storage : Type with HDD and low-cost large capacity storage
      * Dense Compute : Type focused on compute performance
* Spectrum
  * Directly accesses data in S3
  * Concurrency limit
  * Supports horizontal scaling
  * Separates storage and compute
* Performance
  * MPP (Massively Parallel Processing)
  * Columnar data storage
  * Column compression
* Durability
  * Data replication occurs within cluster
  * Performs data backup to S3
  * Automatically recovers failed nodes
  * Only RA3 clusters support Multi-AZ (DS2 is Single AZ)
* Scaling
  * Performs vertical and horizontal scaling
  * New cluster is created and data is migrated when scaling (temporary downtime occurs)
* Data Distribution Style
  * Determines how to distribute data to compute nodes
  * Auto : Automatically distributes data based on data size
  * Even : Automatically distributes data in round-robin fashion
  * Key : Distributes data based on key and hashing
  * All : Replicates data to all compute nodes
* Sort Key
  * Stored sorted on disk according to sort key
  * Compound : Combines multiple columns to use as sort key
  * Interleaved : ??
* Data Replication
  * COPY
    * Performs data replication from S3, EMR, DynamoDB remote hosts
    * Performs data replication in parallel
  * UNLOAD : Performs replication of processed results to S3
  * S3 Auto-copy : Automatically replicates to Redshift when data changes in S3
  * Aurora zero-ETL Integration : Automatically replicates data from Aurora to Redshift
  * Redshift Ingestion
  * DBLINK : Performs data replication by connecting to RDS
* Integration with AWS Services
  * S3, DMS, EMR, EC2, Data Pipeline
* WLM (Workload Management)
  * Query queue
  * Manages by assigning priority to queries
  * Uses 5 queues by default
  * Can configure up to 8 queues
  * Each queue has concurrency level, can be set up to 50
  * Automatically adjusts concurrency level based on query characteristics, can also be set manually
* Concurrency Scaling
  * Processes queries by adding clusters
  * Sends and processes queries queued in WLM to added clusters
* SQA (Short Query Acceleration)
  * Uses queue for short queries in WLM
  * Applies to read-only queries and CREATE TABLE AS queries
  * Can set short criteria time
* VACUUM
  * VACUUM FULL :
  * VACUUM DELETE ONLY :
  * VACUUM SORT ONLY :
  * VACUUM REINDEX :
* Resize
  * Elastic Resize
    * Can quickly add/remove nodes or change node type (DS2 to RA3)
    * Limited number of nodes that can be changed (2, 4, 6, 8...)
    * Cluster down occurs for a few minutes, connections remain open
  * Classic Resize
    * Existing resize method
    * Can add/remove nodes, change node type
    * Can freely set number of nodes
    * Cluster operates in read-only mode for several hours because it creates new cluster and replicates data from existing cluster
  * Snapshot
    * Performs snapshot and creates cluster of new size
* Security
  * Uses HSM (Hardware Security Module)
  * Grants privilege permissions to users and groups
* Redshift Serverless
  * No need to manage EC2 instances
  * Optimizes costs & performance
  * Easy to set up development & test environments
  * Easy to configure ad-hoc environments
  * Can utilize snapshot functionality

## 5. Visualization

### 5.1. QuickSight

* Data visualization
* Provides pagination functionality
* Provides alert functionality
* Serverless
* Data Source
  * Redshift, Aurora/RDS, Athena, OpenSearch, IoT Analytics, Files (Excel, CSV, TSV)
* SPICE : In-memory engine used in QuickSight
* Specialized for ad-hoc queries
* Security
  * Multi-factor auth
  * VPC connectivity
  * Row-level security
  * Private VPC access
  * QuickSight can only access data sources in the same region by default
* Pricing
  * Annual subscription, monthly subscription
  * Additional charges when using extra SPICE capacity
* Dashboard
  * Read-only
  * Can share externally
  * Can embed
  * Authentication through Active Directory, Cognito, SSO
  * Provides JavaScript SDK and QuickSight API
* ML Functionality
  * Anomaly detection functionality
  * Prediction functionality
  * Insight recommendation functionality
* QuickSight Q
  * Performs queries based on natural language

## 6. References

* [https://www.udemy.com/course/aws-data-analytics/](https://www.udemy.com/course/aws-data-analytics/)
* [https://hevodata.com/learn/redshift-elastic-resize/](https://hevodata.com/learn/redshift-elastic-resize/)


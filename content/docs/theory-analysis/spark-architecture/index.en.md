---
title: Spark Architecture
---

This document analyzes Spark Architecture.

## 1. Spark Architecture

{{< figure caption="[Figure 1] Spark Architecture" src="images/spark-architecture.png" width="900px" >}}

[Figure 1] shows the Spark Architecture. Spark consists of Spark Core at its center, Cluster Manager for Task processing, Storage for data storage, and Libraries for various functions.

### 1.1. Spark Core

Spark Core performs the role of distributing and processing data in Task units. Tasks are composed as part of **RDD** (Resilient Distributed Data), a data set designed by Spark for distributed data processing. Therefore, RDD composition and processing are the core roles of Spark Core.

Cluster Manager performs the role of executing Tasks, and can use Spark Standalone built with Spark alone, or separate Cluster Managers such as Hadoop YARN, Mesos, and Kubernetes. Storage refers to the space where data is stored, and supports HDFS, Gluster FS, Amazon S3, etc. Spark Core provides APIs in Java, Scala, Python, and R languages.

### 1.2. Library

Library performs the role of helping process various types of workloads based on Spark Core. Libraries can be used through various development languages. Libraries can be categorized into Spark SQL, MLib, GraphX, and Streaming.

* Spark SQL : Provides a DataFrame data structure created to process data composed of rows and columns. Data stored in DataFrame can be queried through Spark SQL Query. Data composed of rows and columns can be imported into DataFrame through Hive, and since JDBC/ODBC is also supported, schemas stored in databases can also be imported into DataFrame.
* MLib : Provides algorithms needed for Machine Learning or statistics. Algorithms such as Regression, Clustering, Classification, Collaborative Filtering, Pattern Mining can be used. Can read and process data from Hadoop-based systems such as HDFS, HBase.
* GraphX : Provides algorithms for Graphic Data processing. Currently, it is rarely used.
* Streaming : Provides functionality to receive and process Streaming Data in real-time from Streaming Sources such as Kafka, Flume. Processes data using Dstream, which is composed of a collection of RDDs by time. It is also possible to convert Dstream to DataFrame and process it.

## 2. Spark Runtime Architecture

{{< figure caption="[Figure 2] Spark Runtime Architecture" src="images/spark-runtime-architecture.png" width="750px" >}}

[Figure 2] shows the Spark Runtime Architecture. It consists of Driver, Cluster Manager, and Executor.

* Driver : Driver is a program that initializes and manages Spark Context. SparkContext is an object that contains overall information about tasks. It separates tasks into Tasks, and the separated Tasks are sent to Executors through the Scheduler inside SparkContext and executed. RDDs are also created through SparkContext.

* Cluster Manager : Performs the role of running and managing Spark Executors with the Resources (CPU, Memory) required by SparkContext. Cluster Manager can integrate with various platforms, and currently supports Hadoop YARN, Apache Mesos, and Kubernetes.

* Executor : Executor is a program that performs the role of receiving Tasks from SparkContext, executing them, and returning results. Executor is created by Cluster Manager at the request of SparkContext, and after creation is complete, Executor connects to SparkContext and waits for Tasks to execute from SparkContext. Executor belongs to one SparkContext and is not shared with multiple SparkContexts. Therefore, even if multiple Spark Applications use the same Cluster Manager, they run independently. When SparkContext terminates, Executor also terminates.

{{< figure caption="[Figure 3] Client Mode Spark Runtime Architecture" src="images/spark-runtime-architecture-client-mode.png" width="650px" >}}

{{< figure caption="[Figure 4] Cluster Mode Spark Runtime Architecture" src="images/spark-runtime-architecture-cluster-mode.png" width="850px" >}}

Spark Runtime Architecture can be divided into 2 modes: **Client Mode** and **Cluster Mode**. [Figure 3] shows Client Mode, and [Figure 4] shows Cluster Mode.

* Client Mode : In Client Mode, the Client directly runs the Driver. Mainly used when using Spark interactively for Spark Application development, such as Spark Shell or Jupyter Notebook.

* Cluster Mode : In Cluster Mode, the Client delegates Driver operation to Cluster Manager. Therefore, Driver also runs inside the Cluster, same as Executor. Mainly used in Production environments.

## 3. References

* [https://www.interviewbit.com/blog/apache-spark-architecture/](https://www.interviewbit.com/blog/apache-spark-architecture/)
* [https://spark.apache.org/docs/latest/cluster-overview.html](https://spark.apache.org/docs/latest/cluster-overview.html)
* [https://datastrophic.io/core-concepts-architecture-and-internals-of-apache-spark/](https://datastrophic.io/core-concepts-architecture-and-internals-of-apache-spark/)
* [https://0x0fff.com/spark-architecture/](https://0x0fff.com/spark-architecture/)
* [https://www.alluxio.io/learn/spark/architecture/](https://www.alluxio.io/learn/spark/architecture/)
* [https://dwgeek.com/apache-spark-architecture-design-and-overview.html/](https://dwgeek.com/apache-spark-architecture-design-and-overview.html/)


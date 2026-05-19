---
title: Spark RDD
---

This document analyzes Spark RDD.

## 1. Spark RDD

{{< figure caption="[Figure 1] Spark RDD DAG" src="images/spark-rdd.png" width="800px" >}}

Spark's **RDD** (Resilient Distributed Dataset) is the most fundamental data unit in Spark. Each RDD has the property of immutability. That is, once an RDD is created, it cannot be modified. Because of this property, Spark processes data by creating new RDDs during data processing, which naturally forms relationships between RDDs. The logical relationship between RDDs is called **Lineage**, and when this lineage is expressed from a physical perspective, a **DAG** (Directed Acyclic Graph) is formed. [Figure 1] shows the DAG of Spark RDDs.

The reason Spark RDDs are immutable is, as the name Resilient suggests, to reliably recover data when failures occur in a distributed environment. Even if an RDD is lost due to a failure on a specific node, Spark can recover that RDD by recomputing it along the lineage. The reason for recovery through RDD lineage rather than storing intermediate processing data is that storing intermediate results of large-scale data every time consumes enormous storage space, and recovery also takes considerable time to load the stored data.

### 1.1. Job, Stage, Partition, Task

[Figure 1] also shows the relationship between Spark RDDs and Job, Stage, Task, and Partition.

* **Job** : A Job is the unit of execution for a Spark Application. A Job consists of one or more Stages.
* **Stage** : A Stage is the unit of execution within a Job, and is generally divided at points where shuffling occurs. Here, shuffling means the process of completely redistributing data between RDDs based on keys. In [Figure 1], you can see that one Job has three Stages A, B, and C, and you can also see that Stages are divided at points where shuffling occurs.
* **Partition** : A Partition is the physical division unit of an RDD. In many cases, data is divided based on a specific key, and it is important to choose an appropriate key to minimize partition skew.
* **Task** : A Task is the actual execution unit of a Stage. Task and Partition have a 1:1 relationship, and one Executor can run multiple Tasks in parallel up to the number of allocated cores.

### 1.2. Narrow Dependency, Wide Dependency

{{< figure caption="[Figure 2] Spark RDD Dependency" src="images/spark-rdd-dependency.png" width="800px" >}}

Dependencies between Spark RDDs are classified into **Narrow Dependency** and **Wide Dependency**. [Figure 2] shows Narrow Dependency and Wide Dependency. Narrow Dependency means that each partition of a child RDD depends on only a small number of parent partitions. In this type of dependency, data movement (shuffle) does not occur, so operations can be performed within a single Stage. On the other hand, Wide Dependency means that each partition of a child RDD depends on multiple parent partitions. In this case, redistribution of data between partitions (shuffle) occurs, and a new Stage is created.

Representative functions that create Narrow Dependency are as follows.

* `map()` : Used when transforming data in a 1:1 manner.
* `filter()` : Used when filtering only data that matches a condition.

Representative functions that create Wide Dependency are as follows.

* `groupByKey()` : Used when grouping data by key.
* `reduceByKey()` : Used when aggregating data by key.
* `repartition()` : Used when redistributing data.

Functions that can result in either Narrow or Wide Dependency are as follows.

* `join()` : Used when joining two RDDs. If the data of the RDDs being joined have a **Co-Partition** relationship where they are located in the same partition based on key, it becomes Narrow Dependency; otherwise, it becomes Wide Dependency.

### 1.3. Lazy Evaluation

**Lazy Evaluation** is, as the name suggests, a technique that performs computation only when needed, and Spark also uses this to optimize performance and resources. From a lazy evaluation perspective, Spark functions are divided into **Transformation** functions such as `map()` and `filter()`, and **Action** functions such as `collect()` and `count()`. Transformation functions are functions that transform data, while Action functions trigger actual execution, such as returning results or saving to external storage.

Through lazy evaluation, actual data processing is not performed when Transformation functions are called; actual data processing is performed only when Action functions are called afterward. Because Spark understands the entire execution plan at once when an Action is called, it can optimize by bundling multiple Transformation operations into a pipeline and does not need to store intermediate results unnecessarily. Transformation functions and Action functions are as follows.

## 2. References

* Spark Core Concepts and Architecture :  [https://datastrophic.io/core-concepts-architecture-and-internals-of-apache-spark/](https://datastrophic.io/core-concepts-architecture-and-internals-of-apache-spark/)
* Batch Processing Apache Spark : [https://blog.k2datascience.com/batch-processing-apache-spark-a67016008167](https://blog.k2datascience.com/batch-processing-apache-spark-a67016008167)
* Spark RDD DAG : [https://stackoverflow.com/questions/41340612/do-stages-in-an-application-run-parallel-in-spark](https://stackoverflow.com/questions/41340612/do-stages-in-an-application-run-parallel-in-spark)
* Spark Join Optimization : [https://jaemunbro.medium.com/apache-spark-%EC%A1%B0%EC%9D%B8-join-%EC%B5%9C%EC%A0%81%ED%99%94-c9e54d20ae06](https://jaemunbro.medium.com/apache-spark-%EC%A1%B0%EC%9D%B8-join-%EC%B5%9C%EC%A0%81%ED%99%94-c9e54d20ae06)
* Spark Lazy Loading : [https://snowturtle93.github.io/posts/Spark%EA%B0%80-Lazy-Evaluation%EC%9D%84-%EC%82%AC%EC%9A%A9%ED%95%98%EB%8A%94-%EC%9D%B4%EC%9C%A0/](https://snowturtle93.github.io/posts/Spark%EA%B0%80-Lazy-Evaluation%EC%9D%84-%EC%82%AC%EC%9A%A9%ED%95%98%EB%8A%94-%EC%9D%B4%EC%9C%A0/)

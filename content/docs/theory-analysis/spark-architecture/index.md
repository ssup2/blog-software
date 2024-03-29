---
title: Spark Architecture
---

Spark Architecture를 분석한다.

## 1. Spark Architecture

{{< figure caption="[Figure 1] Spark Architecture" src="images/spark-architecture.png" width="900px" >}}

[Figure 1]은 Spark Architecture를 나타내고 있다. Spark는 Spark Core를 중심으로 Task 처리를 위한 Cluster Manager, Data를 저장하는데 이용하는 Storage, 다양한 기능을 수행하는 Libary로 구성되어 있다.

### 1.1. Spark Core

Spark Core는 Data를 Task 단위로 분산하여 처리하는 역할을 수행한다. Task는 Spark에서 데이터 분산 처리를 위해 고안한 데이터 집합인 **RDD** (Resillient Distributed Data)의 일부로 구성된다. 따라서 RDD 구성 및 처리가 Spark Core의 핵심 역할이다.

Cluster Manager는 Task를 수행하는 역할을 수행하며, Spark만을 이용하여 구성하는 Spark Standalone 부터 Hadoop YARN, Mesos, Kubernetes와 같은 별도의 Cluster Manager 이용도 가능하다. Storage는 Data가 저장되는 공간을 의미하며 HDFS, Gluster FS, Amazon S3등을 지원한다. Spark Core는 Java, Scala, Python, R 언어로 API를 제공한다.

### 1.2. Library

Library는 Spark Core를 기반으로 다양한 Type의 Workload 처리를 도와주는 역할을 수행한다. Library는 다양한 개발 언어를 통해서 이용할 수 있다. Library는 Spark SQL, MLib, GraphX, Streaming으로 구분지을 수 있다.

* Spark SQL : 행과 열로 구성된 Data를 처리하기 위해서 생긴 DataFrame 자료 구조를 제공한다. DataFrame에 저장된 Data는 Spark SQL Query를 통해서 조회가 가능하다. Hive를 통해서 행과 열로 구성된 Data를 Dataframe으로 가져올 수 있으며, JDBC/ODBC도 지원하기 때문에 Database에 저장된 Schema도 Dataframe으로 가져올 수 있다.
* MLib : Machine Learning이나 통계에 필요한 알고리즘을 제공한다. Regression, Clustering, Classification, Collaborative Filtering, Pattern Mining 등의 알고리즘을 이용할 수 있다. HDFS, HBase 등의 Hadoop 기반의 System에서 Data를 읽고 처리할 수 있다.
* GraphX : Graphic Data 처리를 위한 알고리즘을 제공한다. 현재는 거의 이용되지 않는다.
* Streaming : Kafka, Flume과 같은 Streaming Source로부터 Streaming Data를 실시간으로 수신하고 처리하는 기능을 제공한다. 시간별 RDD의 집합으로 구성되는 Dstream를 활용하여 Data를 처리한다. Dstream을 DataFrame으로 변환하여 처리도 가능하다.

## 2. Spark Runtime Architecture

{{< figure caption="[Figure 2] Spark Runtime Architecture" src="images/spark-runtime-architecture.png" width="750px" >}}

[Figure 2]는 Spark Runtime Architecture를 나타내고 있다. Driver, Cluster Manager, Executor로 구성되어 있다.

* Driver : Driver는 Spark Context를 초기화하고 관리하는 Program이다. SparkContext는 작업에 대한 전반적인 정보를 가지고 있는 객체이다. 작업을 Task로 분리하며 분리된 Task는 SparkContext 내부의 Scheulder를 통해서 Executor로 전송하여 실행된다. RDD도 SparkContext를 통해서 생성된다.

* Cluster Manager : SparkContext가 요구하는 Resource (CPU, Memory)를 갖는 Spark Executor를 실행하고 관리하는 역할을 수행한다. Cluster Manager는 다양한 Platform과 연동할 수 있으며, 현재 Hadoop YARN, Apache Mesos, Kubernetes를 지원한다.

* Executor : Executor는 SparkContext로부터 Task를 받아 수행하고 그 결과를 반환하는 역할을 수행하는 Program이다. Executor는 SparkContext의 요청에 의해서 Cluster Manager로부터 생성되며, 생성이 완료된 Executor는 SparkContext로 접속하여 SparkContext로부터 실행할 Task를 대기한다. Executor는 하나의 SparkContext에 귀속되며 다수의 SparkContext와 공유되지 않는다. 따라서 다수의 Spark Application이 동일한 Cluster Manager를 이용하더라도 독립되어 실행된다. SparkContext가 종료되면 Executor도 같이 종료된다.

{{< figure caption="[Figure 3] Client Mode Spark Runtime Architecture" src="images/spark-runtime-architecture-client-mode.png" width="650px" >}}

{{< figure caption="[Figure 4] Cluster Mode Spark Runtime Architecture" src="images/spark-runtime-architecture-cluster-mode.png" width="850px" >}}

Spark Runtime Architecture는 **Client Mode**와 **Cluster Mode** 2가지 Mode로 구분할 수 있다. [Figure 3]은 Client Mode를 나타내고 있으며, [Figure 4]는 Cluster Mode를 나타내고 있다.

* Client Mode : Client Mode에서 Client는 직접 Driver를 동작시킨다. 주로 Spark Shell 또는 Juypter Nodebook과 같이 Spark Application 개발을 위해서 대화형으로 Spark를 이용하는 경우 Client Mode를 이용한다.

* Cluster Mode : Cluster Mode에서 Client는 Cluster Manager에게 Driver 동작을 위임한다. 따라서 Driver도 Executor와 동일하게 Cluster 내부에서 동작한다. 주로 Production 환경에서 이용된다.

## 3. 참조

* [https://www.interviewbit.com/blog/apache-spark-architecture/](https://www.interviewbit.com/blog/apache-spark-architecture/)
* [https://spark.apache.org/docs/latest/cluster-overview.html](https://spark.apache.org/docs/latest/cluster-overview.html)
* [https://datastrophic.io/core-concepts-architecture-and-internals-of-apache-spark/](https://datastrophic.io/core-concepts-architecture-and-internals-of-apache-spark/)
* [https://0x0fff.com/spark-architecture/](https://0x0fff.com/spark-architecture/)
* [https://www.alluxio.io/learn/spark/architecture/](https://www.alluxio.io/learn/spark/architecture/)
* [https://dwgeek.com/apache-spark-architecture-design-and-overview.html/](https://dwgeek.com/apache-spark-architecture-design-and-overview.html/)

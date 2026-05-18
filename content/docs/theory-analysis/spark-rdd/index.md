---
title: Spark RDD
draft: true
---

Spark의 RDD를 분석한다.

## 1. Spark RDD

{{< figure caption="[Figure 1] Spark RDD DAG" src="images/spark-rdd.png" width="800px" >}}

Spark의 **RDD** (Resilient Distributed Dataset)는 Spark의 가장 기본적인 Data 단위이다. 각 RDD는 불변성 (Immutable)을 갖는다. 즉 한번 생성된 RDD는 변경할 수 없다는 특징을 갖는다. 이러한 특징 때문에 Spark는 RDD를 활용하여 Data를 처리하는 과정에서 새로운 RDD를 생성하는 방식으로 Data를 처리하게 되며, 자연스럽게 RDD 사이의 관계를 형성하게된다. 이러한 RDD 사이의 Logical 관점의 관계를 **Lineage**라고 부르며, Lineage를 처리하기 위해서 Physical 관점의 관계를 표현하면  **DAG** (Directed Acyclic Graph)가 구성된다. [Figure 1]은 Spark RDD의 DAG를 나타내고 있다.

Spark RDD가 불변성을 갖는 이유는 Resilient라는 이름에서 알 수 있듯이, 분산 환경에서 장애 발생 시 Data를 안정적으로 복구하기 위해서이다. 특정 노드에서 장애가 발생하여 RDD가 손실되더라도, Spark는 Lineage를 따라 해당 RDD를 재계산하여 복구할 수 있다. 중간 처리 Data를 저장하는 방식 대신 RDD의 Lineage를 통해 복구하는 이유는, 대규모 Data의 중간 처리 결과를 매번 저장하면 막대한 저장 공간이 소모될 뿐만 아니라 복구 시에도 저장된 Data를 불러오는 데 상당한 시간이 걸리기 때문이다.

### 1.1. Job, Stage, Partition, Task

[Figure 1]은 Spark RDD와 Job, Stage, Task, Partition의 관계도 나타내고 있다.

* **Job** : Job은 Spark Application의 실행 단위이다. Job은 하나 또는 여러개의 Stage로 구성된다.
* **Stage** : Stage는 Job의 실행 단위이며, 일반적으로 Shuffling이 발생하는 기준으로 구분된다. 여기서 Shuffling은 RDD 사이에 Key를 기준으로 Data를 완전히 재배치하는 과정을 의미한다. [Figure 1]에서 하나의 Job에 A,B,C 3개의 Stage가 있는 것을 확인할 수 있으며, Shuffling이 발생하는 지점을 기준으로 Stage가 구분되는것도 확인할 수 있다.
* **Partition** : Partition은 RDD의 물리적 분할 단위를 의미한다.
* **Task** : Task는 Stage의 실제 실행 단위를 의미한다. Task와 Partition은 1:1 관계를 갖는다.

### 1.2. Narrow Dependency, Wide Dependency

{{< figure caption="[Figure 2] Spark RDD Dependency" src="images/spark-rdd-dependency.png" width="800px" >}}

### 1.3. Lazy Evaluation

## 2. 참조

* [https://datastrophic.io/core-concepts-architecture-and-internals-of-apache-spark/](https://datastrophic.io/core-concepts-architecture-and-internals-of-apache-spark/)
* [https://blog.k2datascience.com/batch-processing-apache-spark-a67016008167](https://blog.k2datascience.com/batch-processing-apache-spark-a67016008167)
* [https://stackoverflow.com/questions/41340612/do-stages-in-an-application-run-parallel-in-spark](https://stackoverflow.com/questions/41340612/do-stages-in-an-application-run-parallel-in-spark)
* [https://jaemunbro.medium.com/apache-spark-%EC%A1%B0%EC%9D%B8-join-%EC%B5%9C%EC%A0%81%ED%99%94-c9e54d20ae06](https://jaemunbro.medium.com/apache-spark-%EC%A1%B0%EC%9D%B8-join-%EC%B5%9C%EC%A0%81%ED%99%94-c9e54d20ae06)
* [https://alklid.github.io/dlog/2017/10/12/spark-01/index.html](https://alklid.github.io/dlog/2017/10/12/spark-01/index.html)
* [https://pizzathief.oopy.io/spark-rdd](https://pizzathief.oopy.io/spark-rdd)

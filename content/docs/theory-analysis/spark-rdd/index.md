---
title: Spark RDD
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
* **Partition** : Partition은 RDD의 물리적 분할 단위를 의미한다. 일반적으로 특정 Key를 기준으로 분할하는 경우가 많으며, 적절한 Key를 선택하여 Partition Skew를 최소화하는 것이 중요하다.
* **Task** : Task는 Stage의 실제 실행 단위를 의미한다. Task와 Partition은 1:1 관계를 갖으며, 하나의 Executor는 할당된 Core수 만큼 다수의 Task를 병렬로 실행할 수 있다.

### 1.2. Narrow Dependency, Wide Dependency

{{< figure caption="[Figure 2] Spark RDD Dependency" src="images/spark-rdd-dependency.png" width="800px" >}}

Spark의 RDD 사이의 Dependency는 **Narrow Dependency**와 **Wide Dependency**로 구분된다. [Figure 2]는 Narrow Dependency와 Wide Dependency를 나타낸다. Narrow Dependency는 자식 RDD의 각 Partition이 소수의 부모 Partition에만 의존하는 경우를 의미한다. 이러한 Dependency에서는 데이터 이동(Shuffle)이 발생하지 않으므로 하나의 Stage 내에서 연산이 수행될 수 있다. 반면, Wide Dependency는 자식 RDD의 각 Partition이 여러 부모 Partition에 의존하는 경우를 의미한다. 이 경우 Partition 간 데이터 재분배(Shuffle)가 발생하며, 새로운 Stage가 생성된다.

Narrow Dependency를 생성하는 대표적인 함수는 다음과 같다.

* `map()` : 데이터를 1:1로 변환할 때 사용한다.
* `filter()` : 조건에 맞는 데이터만 걸러낼 때 사용한다.

Wide Dependency를 생성하는 대표적인 함수는 다음과 같다.

* `groupByKey()` : 키를 기준으로 데이터를 그룹화할 때 사용한다.
* `reduceByKey()` : 키를 기준으로 데이터를 집계할 때 사용한다.
* `repartition()` : 데이터를 다시 분배할 때 사용한다.

Narrow, Wide Dependency가 모두 가능한 함수는 다음과 같다.

* `join()` : 두 개의 RDD를 조인할 때 사용한다. 조인을 수행하는 RDD의 Data가 Key를 기준으로 같은 Partition에 위치하는 **Co-Partition** 관계를 갖는 경우에는 Narrow Dependency, 그렇지 않은 경우에는 Wide Dependency가 된다.

### 1.3. Lazy Evaluation

**Lazy Evalutation**은 이름에서도 알 수 있는것 처럼 필요한 시점에만 연산을 수행하는 기법을 의미하며, Spark에서도 이를 통해서 성능과 Resource를 최적화하고 있다. Lazy Evalutation 관점에서 Spark 함수는 `map()`, `filter()`와 같은 **Transformation** 함수와 `collect()`, `count()`와 같은 **Action** 함수로 구분된다. Transformation 함수는 데이터를 변환하는 함수를 의미하며, Action 함수는 결과를 반환하거나 외부에 저장하는 등 실제 실행을 트리거하는 함수를 의미한다.

Lazy Evaluation을 통해 Transformation 함수가 호출되는 시점에는 실제 Data 처리가 수행되지 않으며, 이후 Action 함수가 호출되는 시점에 비로소 실제 Data 처리가 수행된다. Spark는 Action 호출 시점에 전체 실행 계획을 한번에 파악하기 때문에, 다수의 Transformation 연산을 파이프라인으로 묶어 최적화할 수 있으며 중간 결과를 불필요하게 저장하지 않아도 된다. Transformation 함수와 Action 함수는 다음과 같다.

## 2. 참조

* Spark Core Concepts and Architecture :  [https://datastrophic.io/core-concepts-architecture-and-internals-of-apache-spark/](https://datastrophic.io/core-concepts-architecture-and-internals-of-apache-spark/)
* Batch Processing Apache Spark : [https://blog.k2datascience.com/batch-processing-apache-spark-a67016008167](https://blog.k2datascience.com/batch-processing-apache-spark-a67016008167)
* Spark RDD DAG : [https://stackoverflow.com/questions/41340612/do-stages-in-an-application-run-parallel-in-spark](https://stackoverflow.com/questions/41340612/do-stages-in-an-application-run-parallel-in-spark)
* Spark Join Optimization : [https://jaemunbro.medium.com/apache-spark-%EC%A1%B0%EC%9D%B8-join-%EC%B5%9C%EC%A0%81%ED%99%94-c9e54d20ae06](https://jaemunbro.medium.com/apache-spark-%EC%A1%B0%EC%9D%B8-join-%EC%B5%9C%EC%A0%81%ED%99%94-c9e54d20ae06)
* Spark Lazy Loading : [https://snowturtle93.github.io/posts/Spark%EA%B0%80-Lazy-Evaluation%EC%9D%84-%EC%82%AC%EC%9A%A9%ED%95%98%EB%8A%94-%EC%9D%B4%EC%9C%A0/](https://snowturtle93.github.io/posts/Spark%EA%B0%80-Lazy-Evaluation%EC%9D%84-%EC%82%AC%EC%9A%A9%ED%95%98%EB%8A%94-%EC%9D%B4%EC%9C%A0/)

---
title: Kafka Connect
draft: true
---

Kafka Connect에 대해서 분석한다.

## 1. Kafka Connect

{{< figure caption="[Figure 1] Kafka Connect" src="images/kafka-connect-architecture.png" width="900px" >}}

Kafka Connect는 Kafka를 기반으로 외부의 Data 저장소와 연동하여 Data Stream 구축을 도와주는 도구이다. [Figure 1]은 Kafka Connect의 Architecture를 나타내고 있으며 다음과 같은 구성요소로 이루어져 있다.

* **Data Source** : Data Stream의 출발점이 되는 Data 저장소.
* **Data Destination** : Data Stream의 도착점이 되는 Data 저장소.
* **Kafka Cluster, Topic** : Data Stream을 저장하는 Kafka Cluster 내부의 Topic.
* **Kafka Connect Cluster** : Data 저장소와 Kakfa 사이에서 Data Stream을 주고받는 Kafka Connect, Transforms, Converter를 관리한다. **Rest API**를 통해서 원격에서 관리가 가능하다. 하나 또는 다수의 **Worker**로 구성되어 있다.
  * **Connector** : Data 저장소와 Kakfa 사이에서 실제로 Data Stream을 주고받는 역할을 수행한다. Data Source와 연동되는 Connector를 **Source Connector**, Data Destination와 연동되는 Connector를 **Destination Connector**라고 명칭한다.
  * **Converter** : Connector와 Kafka 사이에서 Data Format(JSON, Protobuf, Avro...)을 변환하는 역할을 수행한다.
  * **Transforms** : Connector와 Converter 사이에서 간단한 Data 변환을 수행하는 역할을 수행한다. 필수 요소는 아니며, 선택적으로 사용할 수 있다.

### 1.1. Worker

{{< figure caption="[Figure 2] Kafka Connect Worker" src="images/kafka-connect-worker-standalone.png" width="550px" >}}

{{< figure caption="[Figure 3] Kafka Connect Connector" src="images/kafka-connect-worker-distributed.png" width="550px" >}}

### 1.2. Converter

### 1.3. Transforms

### 1.4. Exactly Once

## 2. 참조

* Kafka Connect : [https://docs.confluent.io/platform/current/connect/index.html#](https://docs.confluent.io/platform/current/connect/index.html#)
* Kafka Connect : [https://developer.confluent.io/courses/kafka-connect/how-connectors-work/](https://developer.confluent.io/courses/kafka-connect/how-connectors-work/)
* Kakka Connect : [https://www.instaclustr.com/blog/apache-kafka-connect-architecture-overview/](https://www.instaclustr.com/blog/apache-kafka-connect-architecture-overview/)
* Kakfa Connect : [https://kafka.apache.org/documentation.html#connect](https://kafka.apache.org/documentation.html#connect)
* Kafka Connect : [https://cjw-awdsd.tistory.com/53](https://cjw-awdsd.tistory.com/53)
* Kafka Connect Rest API : [https://docs.confluent.io/platform/current/connect/references/restapi.html](https://docs.confluent.io/platform/current/connect/references/restapi.html)
* Kafka Connect Rebalancing : [https://cwiki.apache.org/confluence/display/KAFKA/KIP-415:+Incremental+Cooperative+Rebalancing+in+Kafka+Connect](https://cwiki.apache.org/confluence/display/KAFKA/KIP-415:+Incremental+Cooperative+Rebalancing+in+Kafka+Connect)
* Kafka S3 Connector Exactly-once : [https://jaegukim.github.io/posts/s3-connector%EC%9D%98-exactly-once/](https://jaegukim.github.io/posts/s3-connector%EC%9D%98-exactly-once/)
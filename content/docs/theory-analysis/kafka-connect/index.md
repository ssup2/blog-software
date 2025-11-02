---
title: Kafka Connect
draft: true
---

Kafka Connect에 대해서 분석한다.

## 1. Kafka Connect

{{< figure caption="[Figure 1] Kafka Connect Architecture" src="images/kafka-connect-architecture.png" width="900px" >}}

Kafka Connect는 Kafka를 기반으로 외부의 Data 저장소와 연동하여 Data Stream 구축을 도와주는 도구이다. [Figure 1]은 Kafka Connect의 Architecture를 나타내고 있으며 다음과 같은 구성요소로 이루어져 있다.

* **Data Source** : Data Stream의 출발점이 되는 Data 저장소.
* **Data Destination** : Data Stream의 도착점이 되는 Data 저장소.
* **Kafka Connect Cluster** : Data 저장소와 Kakfa 사이에서 Data Stream을 주고받는 **Plugin**(Kafka Connector, Transform, Converter)을 관리한다. **Rest API**를 통해서 원격에서 관리가 가능하다. 하나 또는 다수의 **Worker**로 구성되어 있다. [Figure 1]에서는 다수의 Worker로 구성된 Distributed Mode의 Kafka Connect Cluster를 나타내고 있다.
  * **Connector** : Data 저장소와 Converter 사이에서 실제로 Data Stream을 주고받는 역할을 수행한다. Data Source와 연동되는 Connector를 **Source Connector**, Data Destination와 연동되는 Connector를 **Sink Connector**라고 명칭한다.
  * **Converter** : Connector와 Kafka 사이에서 Data 직렬화/역직렬화를 수행한다의
  * **Transform** : Connector와 Converter 사이에서 간단한 Data 변환을 수행한다. 필수 요소는 아니며 선택적으로 사용할 수 있다.
* **Kafka Cluster, Data Stream Topic** : Connector가 처리한 Data Stream을 저장하는 Kafka Topic.
* **Kafka Cluster, Connect Topic** : Kafka Connect의 설정/상태 정보를 저장하는 Kafka Topic. Kafka Connect Cluster는 설정/상태 정보를 저장하기 위해서 Database를 이용하지 않으며 Kafka Topic을 이용하여 이를 구현하고 있다. 각 Kafka Connect Cluster 별로 별도의 Config, Offset, Status Kafka Topic을 이용한다.
  * **Config Topic** : Kafka Connect Cluster의 설정 정보를 저장하는 Topic.
  * **Offset Topic** : Kafka Connect Cluster이 Data Stream을 어디까지 처리했는지를 나타내는 오프셋 정보를 저장하는 Topic.
  * **Status Topic** : Kafka Connect Cluster의 상태 정보를 저장하는 Topic.
* **Kafka Schema Registry** : Converter에서 Data 직렬화/역직렬화를 수행하기 위해서 필요한 Schema 정보를 저장하고 관리한다.

### 1.1. Worker

Kafka Connect Cluster는 하나 또는 다수의 **Worker**로 구성된다. 하나의 Worker로 구성되는 경우 **Standalone Mode**로 동작하며, 다수의 Worker로 구성되는 경우 **Distributed Mode**로 동작한다.

#### 1.1.1. Standalone Mode

{{< figure caption="[Figure 2] Kafka Connect Worker Standalone Mode" src="images/kafka-connect-worker-standalone.png" width="650px" >}}

[Figure 2]는 하나의 Worker로 구성된 **Standalone Mode**를 나타내고 있다. Worker에서 동작하는 Connector, Converter, Transform도 같이 나타내고 있다. Connector는 다시 **Connector Instance**와 **Connector Task**로 구성되며, 각각 별도의 **Thread**를 할당받아 동작한다. 따라서 하나의 Worker에서 다수의 Connector Instance와 Connector Task가 동작 가능하다. Connector Instance와 Connector Task는 다음의 역할을 수행한다.

* **Connector Instance** : 다수의 Data Stream을 설정에 따라서 다수의 Task로 분배하여 생성하는 역할을 수행한다. 또한 Data 저장소의 상태를 모니터링하며 이에 따라서 Task를 적절하게 재구성 하는 역할도 수행한다.
* **Connector Task** : Connector Instance에 의해서 생성되며, 실제로 Data 저장소에 접근하여 Data Stream을 주고받는 역할을 수행한다. 일반적으로 각 Task마다 고유의 **Partition**을 할당받아 별도의 Data Stream을 구성하여 동작하며, [Figure 2]에서도 Task마다 할당된 Partition을 확인할 수 있다.

Converter와 Transform은 **Class Instance**로 존재하며 Connector Task에서 Method를 통해서 호출되어 동작한다. Standalone Mode에서 Worker는 모든 설정/상태 정보를 **Host**에 저장하고 이용한다. Config 정보는 Host의 Properties 파일, Offset 상태 정보는 Host의 파일, Status 상태 정보는 Host의 Memory에 저장하고 이용한다. 모두 Host 환경에서 동작하기 때문에 가용성이 떨어지는 단점을 가지고 있으며, Local 환경에서 사용되는 경우가 일반적이다.

#### 1.1.2. Distributed Mode

{{< figure caption="[Figure 3] Kafka Connect Worker Distributed Mode" src="images/kafka-connect-worker-distributed.png" width="900px" >}}

일반적으로 Alpha 환경이나 Production 환경에서는 다수의 Worker로 구성되어 높은 가용성 확보가 가능하고, Scale-out도 가능한 **Distributed Mode**를 사용한다. [Figure 3]는 Distributed Mode를 나타내고 있다. Connector Instance와 Connector Task가 다수의 Worker로 분산되어 동작하는 것을 확인할 수 있으며, Class Instance로 존재하는 Converter와 Transform의 경우에는 각 Worker마다 별도로 위치하는 것도 확인할 수 있다.

Distributed Mode로 동작하는 경우에는 하나의 Worker는 **Leader Worker**로 동작하며, 다수의 Worker는 공유하는 Config, Offset, Status Kafka Topic을 이용하여 설정/상태 정보를 공유하며 동작한다. 공유 Topic은 

Leader Worker는 공유 Kafka Topic을 통해서 Kafka Connect Cluster의 모든 Connector Instance, Connector Task, Worker 정보를 얻어와 Connector Instance와 Connector Task를 어느 Worker에게 할당할지 결정하는 Scheduler 역할을 수행한다. 또한 Worker가 죽었을 경우에 Task Rebalancing 역할도 수행한다. 만약 Leader Worker가 죽었을 경우에는 다른 Worker 중에서 새로운 Leader Worker로 선출되어 동작한다.

하나의 Worker는 하나의 Process이기 때문에, Class Instance로 존재하는 Converter와 Transform의 경우에는 각 Worker마다 별도로 위치하게 된다. Kafka Connect Cluster를 Kubernetes 위에서 동작시킬 경우에는 Worker가 하나의 Pod로 동작하게 된다.

```properties
config.storage.topic=connect-configs
offset.storage.topic=connect-offsets
status.storage.topic=connect-status

config.storage.replication.factor=1
offset.storage.replication.factor=1
status.storage.replication.factor=1
```

### 1.2. Rest API

{{< table caption="[Table 1] Kafka Connect Rest API" >}}
| URI | Method | Description |
| --- | --- | --- |
| /connectors | GET | 현재 등록된 모든 Connector를 조회한다. |
| /connectors | POST | 새로운 Connector를 등록한다. |
| /connectors/{connector-name} | GET | 특정 Connector의 정보를 조회한다. |
| /connectors/{connector-name} | PUT | 특정 Connector의 정보를 수정한다. |
| /connectors/{connector-name} | DELETE | 특정 Connector를 삭제한다. |
| /connectors/{connector-name}/config | GET | 특정 Connector의 설정 정보를 조회한다. |
| /connectors/{connector-name}/config | PUT | 특정 Connector의 설정 정보를 수정한다. |
| /connectors/{connector-name}/status | GET | 특정 Connector의 상태 정보를 조회한다. |
| /connectors/{connector-name}/pause | GET | 특정 Connector를 일시 정지한다. |
| /connectors/{connector-name}/resume | GET | 특정 Connector를 재시작한다. |
| /connectors/{connector-name}/tasks | GET | 특정 Connector의 모든 Task 정보를 조회한다. |
| /connectors/{connector-name}/tasks/{taskId} | GET | 특정 Connector의 특정 Task 정보를 조회한다. |
| /connectors/{connector-name}/tasks/{taskId}/status | PUT | 특정 Connector의 특정 Task의 상태를 수정한다. |
| /connectors/{connector-name}/tasks/{taskId}/restart | GET | 특정 Connector의 특정 Task를 재시작한다. |
{{< /table >}}

Kafka Connect Cluster는 Rest API를 통해서 외부에서 제어가 가능하다. [Table 1]은 Kafka Connect Cluster에서 제공하는 Rest API를 나타내고 있다. Connector를 등록, 조회, 삭제, 정지, 재시작 하거나 Connector의 세부설정 또는 Task 상태 정보를 조회 할 수 있는걸 확인할 수 있다.

Standalone Mode에서는 Worker는 설정 정보를 Local의 Properties 파일을 이용하기 때문에 PUT, POST, DELETE Rest API를 통해서 설정 정보를 변경할 수 없으며, 설정 정보를 변경하기 위해서는 Local의 Properties 파일을 직접 변경하고 Worker를 재시작해야 한다. 정보를 조회하는 GET Rest API는 정상적으로 이용할 수 있다. 반면에 Distributed Mode에서는 모든 Rest API를 통해서 설정/상태 정보를 변경하거나 조회할 수 있다.

Distributed Mode로 동작하는 경우에도 Leader Worker 뿐만 아니라 모든 Worker는 Rest API를 통해서 요청을 받을수 있다. 설정/상태 정보를 변경하지 않는 GET Rest API 요청을 받은 Worker는 받은 요청을 공유 Kafka Topic으로 부터 직접 설정/상태 정보를 받아 응답한다. 반면에 설정/상태 정보를 변경하는 POST, PUT, DELETE Rest API 요청을 받은 Worker는 받은 요청을 공유 Kafka Topic에 저장만 하는 역할을 수행한다. 이후에 Leader Worker는 공유 Kafka Topic을 통해서 변경된 설정/상태 정보를 얻어와 요청을 처리한다.

```properties {caption="[File 1] Kafka Connect Properties Configuration" linenos=table}
rest.port=8083
rest.advertised.host.name=localhost
```

### 1.3. Converter

Converter는 Connector와 Kafka 사이에서 Data 직렬화/역직렬화를 수행한다. [Figure 1]에서 확인할 수 있는것 처럼 Data Source 쪽의 Converter는 Serializer, 즉 구조화된 Data를 Byte Array로 변환하는 역할을 수행하며, Data Destination 쪽의 Converter는 Deserializer, 즉 Byte Array를 구조화된 Data로 변환하는 역할을 수행한다.

{{< table caption="[Table 2] Kafka Connect Converter" >}}
| Converter | Class | Kafka Schema Registry | Description |
| --- | --- | --- | --- |
| ByteArrayConverter | org.apache.kafka.connect.converters.ByteArrayConverter | X | 변환하지 않고 Pass-through. |
| DoubleConverter | org.apache.kafka.connect.converters.DoubleConverter | X | Double 형식의 변환을 지원. |
| FloatConverter | org.apache.kafka.connect.converters.FloatConverter | X | Float 형식의 변환을 지원. |
| IntegerConverter | org.apache.kafka.connect.converters.IntegerConverter | X | Integer 형식의 변환을 지원. |
| LongConverter | org.apache.kafka.connect.converters.LongConverter | X | Long 형식의 변환을 지원. |
| ShortConverter | org.apache.kafka.connect.converters.ShortConverter | X | Short 형식의 변환을 지원. |
| AvroConverter | io.confluent.connect.avro.AvroConverter | O | Avro 형식의 변환을 지원. |
| ProtobufConverter | io.confluent.connect.protobuf.ProtobufConverter | O | Protobuf 형식의 변환을 지원. |
| JsonSchemaConverter | io.confluent.connect.json.JsonSchemaConverter | O | JSON 형식의 변환을 지원. |
{{< /table >}}

Converter는 Class Instance로 존재하며, [Table 2]는 기본적으로 지원하는 Converter 목록을 나타내고 있다. Kafka Schema Registry를 이용하는 Converter와 이용하지 않는 Converter로 구분할 수 있다.

```properties {caption="[File 1] Kafka Connect Converter Configuration" linenos=table}
key.converter=org.apache.kafka.connect.json.JsonConverter
value.converter=org.apache.kafka.connect.json.JsonConverter
key.converter.schemas.enable=false
value.converter.schemas.enable=false
```

### 1.3. Transform

* **org.apache.kafka.connect.transforms.ExtractField$Value** : 특정 Field를 추출하여 변환을 지원.
* **org.apache.kafka.connect.transforms.ExtractField$Key** : 특정 Field를 추출하여 변환을 지원.

Transform은 Connector와 Converter 사이에서 간단한 Data 변환을 수행한다. [Table 3]는 기본적으로 지원하는 Transform 목록을 나타내고 있다.

### 1.4. Exactly Once

## 2. 참조

* Kafka Connect : [https://docs.confluent.io/platform/current/connect/index.html#](https://docs.confluent.io/platform/current/connect/index.html#)
* Kafka Connect : [https://docs.lenses.io/latest/connectors/understanding-kafka-connect](https://docs.lenses.io/latest/connectors/understanding-kafka-connect)
* Kafka Connect : [https://developer.confluent.io/courses/kafka-connect/how-connectors-work/](https://developer.confluent.io/courses/kafka-connect/how-connectors-work/)
* Kakka Connect : [https://www.instaclustr.com/blog/apache-kafka-connect-architecture-overview/](https://www.instaclustr.com/blog/apache-kafka-connect-architecture-overview/)
* Kakfa Connect : [https://kafka.apache.org/documentation.html#connect](https://kafka.apache.org/documentation.html#connect)
* Kafka Connect : [https://cjw-awdsd.tistory.com/53](https://cjw-awdsd.tistory.com/53)
* Kafka Connect Rest API : [https://docs.confluent.io/platform/current/connect/references/restapi.html](https://docs.confluent.io/platform/current/connect/references/restapi.html)
* Kafka Connect Rebalancing : [https://cwiki.apache.org/confluence/display/KAFKA/KIP-415:+Incremental+Cooperative+Rebalancing+in+Kafka+Connect](https://cwiki.apache.org/confluence/display/KAFKA/KIP-415:+Incremental+Cooperative+Rebalancing+in+Kafka+Connect)
* Kafka S3 Connector Exactly-once : [https://jaegukim.github.io/posts/s3-connector%EC%9D%98-exactly-once/](https://jaegukim.github.io/posts/s3-connector%EC%9D%98-exactly-once/)
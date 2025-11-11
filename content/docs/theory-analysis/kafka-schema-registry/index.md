---
title: Kafka Schema Registry
draft: true
---

## 1. Kafka Schema Registry

{{< figure caption="[Figure 1] Kafka Schema Registry Architecture" src="images/kafka-schema-registry-architecture.png" width="900px" >}}

Kafka Schema Registry는 Kafka Producer와 Kafka Consumer 사이에서 Kafka Message의 Schema를 관리하는 역할을 수행한다. [Figure 1]은 Kafka Schema Registry의 Architecture를 나타내고 있다. Kafka Schema Registry는 상태 정보를 유지하기 위해서 별도의 Database를 이용하지 않고, Kafka의 `_schema_` Topic을 이용한다. 

모든 Schema 관련 정보는 `_schema_` Topic에 기록되기 때문에 Kafka Schema Registry는 Stateless한 특징을 갖으며, 부하 분산을 위해서 손쉽게 Scale-out을 수행할 수 있다. 단 Topic에 저장된 Schema 정보는 Memory에도 Caching되어 있기 때문에 Kafka Schema Registry가 Topic에 직접 접근하는 빈도는 낮으며, 일반적으로 Schema가 등록/변경/삭제되거나 Kafka Schema Registry가 초기화 되는 경우에만 Topic에 접근한다.

```json {caption="[Schema Key 1] _schema_ Topic Key Example", linenos=table}
{
	"keytype": "SCHEMA",
	"subject": "user-events-value",
	"version": 1,
	"magic": 1
}
```
```json {caption="[Schema Value 1] _schema_ Topic Value Example", linenos=table}
{
	"subject": "user-events-value",
	"version": 1,
	"id": 3,
	"schemaType": "AVRO",
	"schema": "{\"type\":\"record\",\"name\":\"User\",\"namespace\":\"ssup2.com\",\"fields\":[{\"name\":\"id\",\"type\":\"int\"},{\"name\":\"name\",\"type\":\"string\"},{\"name\":\"email\",\"type\":\"string\"}]}",
	"deleted": false
}
```

`_schema_` Topic에는 [Schema Key 1], [Schema Value 1]와 같은 Key, Value 형식으로 Schema 관련 정보가 기록된다. Key는 Schema의 고유 식별자로 사용되며, Value는 Schema의 정보를 담고 있다. [Figure 1]에서는 Kafka Schema Registry의 동작 과정도 나타내고 있으며, Kafka Producer가 Kafka Message를 전송하는 과정과, Kafka Consumer가 Kafka Message를 수신하는 과정을 나타내고 있다.

### 1.1. Schema 등록 과정

Kafka Schema Registry는 Rest API를 통해서 Schema를 등록할 수 있으며 다음과 같은 과정을 수행한다.

1. Rest API를 통해서 Schema를 등록 요청을 Kafka Schema Registry에 전송한다.
2. Kafka Schema Registry는 Schema를 `_schema_` Topic에 기록한다.
3. Kafka Schema Registry는 이후에 Schema를 Memory에 Caching하며 Producer, Consumer가 Schema를 요청할때 캐시된 Schema를 반환한다.

### 1.2. Schema 이용 과정

## 2. 참고

* Kafka Schema Registry : [https://medium.com/@tlsrid1119/kafka-schema-registry-feat-confluent-example-cde8a276f76c](https://medium.com/@tlsrid1119/kafka-schema-registry-feat-confluent-example-cde8a276f76c)

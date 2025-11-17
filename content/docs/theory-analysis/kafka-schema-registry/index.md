---
title: Kafka Schema Registry
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

### 1.2. Schema를 통한 Message 직렬화 및 역직렬화 과정

Producer와 Consumer가 Schema를 이용하는 과정은 다음과 같다.

1. Producer는 Kafka Schema Registry에 등록된 Schema를 요청하고 이름과 Version을 통해서 요청하여 Schema와 Schema ID를 반환받는다.
2. Producer는 받은 Schema를 기반으로 Message를 직렬화하고, 직렬화한 Message와 함께 Schema ID를 Kafka Topic에 전송한다.
3. Consumer는 Kafka Topic에서 직렬화됨 Message와 함께 전달된 Schema ID를 수신한다.
4. Consumer는 수신한 Schema ID를 기반으로 Kafka Schema Registry에서 Schema를 요청한다.
5. Consumer는 수신한 Schema를 기반으로 Message를 역직렬화한다.

```python {caption="[Code 1] Producer Python Example", linenos=table}\
import os
import time
from confluent_kafka import Producer
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroSerializer
from confluent_kafka.serialization import SerializationContext, MessageField

# Schema Registry configuration
schema_registry_url = os.getenv(
    "SCHEMA_REGISTRY_URL",
    "http://schema-registry.kafka:8081"
)
schema_registry_client = SchemaRegistryClient({"url": schema_registry_url})

# Kafka Producer configuration
kafka_bootstrap_servers = os.getenv(
    "KAFKA_BOOTSTRAP_SERVERS",
    "kafka-kafka-sasl-bootstrap.kafka:9092"
)
producer_config = {
    "bootstrap.servers": kafka_bootstrap_servers,
    "security.protocol": "SASL_PLAINTEXT",
    "sasl.mechanisms": "SCRAM-SHA-512",
    "sasl.username": "user",
    "sasl.password": "user",
}

# Retrieve schema from Schema Registry
print("Retrieving schema from Schema Registry")
schema = schema_registry_client.get_latest_version("user")
avro_schema_str = schema.schema.schema_str

# Create Avro Serializer (automatically registers schema in Schema Registry and uses schema ID)
avro_serializer = AvroSerializer(
    schema_registry_client,
    avro_schema_str,
    lambda obj, ctx: {
        "id": obj["id"],
        "name": obj["name"],
        "email": obj["email"]
    }
)

# Create Producer
producer = Producer(producer_config)

# Send message
def send_message(user_data):
    topic = "user-events"
    serialization_context = SerializationContext(topic, MessageField.VALUE)
    serialized_value = avro_serializer(user_data, serialization_context)
    
    producer.produce(
        topic=topic,
        value=serialized_value,
        callback=lambda err, msg: print(f"Message delivered: {msg.topic()} [{msg.partition()}]") if err is None else print(f"Delivery failed: {err}")
    )
    producer.poll(0)

# Send sample data
users = [
    {"id": 1, "name": "Alice", "email": "alice@example.com"},
    {"id": 2, "name": "Bob", "email": "bob@example.com"},
    {"id": 3, "name": "Charlie", "email": "charlie@example.com"},
]

for user in users:
    send_message(user)
    time.sleep(1)

# Wait for all messages to be sent
producer.flush()
print("All messages sent")
```

[Code 1]은 Producer가 Schema를 요청하고, Schema를 기반으로 Message를 직렬화하고, 직렬화한 Message와 함께 Schema ID를 Kafka Topic에 전송하는 Python 예제 Code를 나타내고 있다. 이러한 과정들은 `confluent_kafka.schema_registry` Python Package를 통해서 손쉽게 구현할 수 있다.

```python {caption="[Code 2] Consumer Example", linenos=table}
import os
from confluent_kafka import Consumer
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroDeserializer
from confluent_kafka.serialization import SerializationContext, MessageField

# Schema Registry configuration
schema_registry_url = os.getenv(
    "SCHEMA_REGISTRY_URL",
    "http://schema-registry.schema-registry.svc.cluster.local:8081"
)
schema_registry_client = SchemaRegistryClient({"url": schema_registry_url})

# Kafka Consumer configuration
kafka_bootstrap_servers = os.getenv(
    "KAFKA_BOOTSTRAP_SERVERS",
    "kafka-kafka-sasl-bootstrap.kafka:9092"
)
consumer_config = {
    "bootstrap.servers": kafka_bootstrap_servers,
    "group.id": "user-consumer-group",
    "auto.offset.reset": "earliest",
    "security.protocol": "SASL_PLAINTEXT",
    "sasl.mechanisms": "SCRAM-SHA-512",
    "sasl.username": "user",
    "sasl.password": "user",
}

# Create Avro Deserializer (automatically retrieves schema using schema ID from message if schema is not provided)
avro_deserializer = AvroDeserializer(schema_registry_client)

# Create Consumer
consumer = Consumer(consumer_config)

# Subscribe to topic
topic = "user-events"
consumer.subscribe([topic])

# Receive and process messages
print(f"Waiting for messages from topic: {topic}")
try:
    while True:
        msg = consumer.poll(timeout=1.0)
        if msg is None:
            continue
        if msg.error():
            print(f"Consumer error: {msg.error()}")
            continue
        
        # Deserialize Avro (automatically retrieves schema from Schema Registry using schema ID from message)
        serialization_context = SerializationContext(msg.topic(), MessageField.VALUE)
        user_data = avro_deserializer(msg.value(), serialization_context)
        
        print(f"Received message: {user_data}")
        
except KeyboardInterrupt:
    print("Consumer interrupted")
finally:
    consumer.close()
```

[Code 2]은 Consumer가 Kafka Topic에서 직렬화된 Message와 함께 전달된 Schema ID를 수신하고, 수신한 Schema ID를 기반으로 Kafka Schema Registry에서 Schema를 요청하고, 요청한 Schema를 기반으로 Message를 역직렬화하는 Python 예제 Code를 나타내고 있다. 마찬가지로 `confluent_kafka.schema_registry` Python Package를 통해서 손쉽게 구현할 수 있다.

## 2. 참고

* Kafka Schema Registry : [https://medium.com/@tlsrid1119/kafka-schema-registry-feat-confluent-example-cde8a276f76c](https://medium.com/@tlsrid1119/kafka-schema-registry-feat-confluent-example-cde8a276f76c)

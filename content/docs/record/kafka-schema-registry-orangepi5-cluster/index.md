---
title: Kafka Schema Registry 실습 / Orange Pi 5 Max Cluster 환경
---

Kafka Schema Registry를 활용해서 Schema를 관리하는 실습을 수행한다.

## 1. 실습 환경 구성

### 1.1. 전체 실습 환경

{{< figure caption="[Figure 1] Kafka Schema Registry 실습 환경" src="images/environment.png" width="850px" >}}

* **Kafka Schema Registry** : Kafka Message를 위한 Schema를 관리하는 역할을 수행한다.
* **Kafka** : Producer와 Consumer 사이에서 Message를 전송하는 역할을 수행한다.
  * **_schema_ Topic** : Schema Registry에 등록된 Schema를 저장하는 Topic.
  * **user-events Topic** : Producer가 전송한 Message를 저장하는 Topic.
* **Producer** : Kafka Schema Registry에서 스키마를 가져와 Avro 형식으로 직렬화하여 Kafka Topic에 전송하는 역할을 수행한다.
* **Consumer** : Kafka Topic에서 Avro 형식으로 직렬화된 Message를 수신하여 역직렬화하는 역할을 수행한다.

전체 실슴 환경 구성은 다음의 링크를 참조한다.

* **Orange Pi 5 Max 기반 Kubernetes Cluster 구축** : [https://ssup2.github.io/blog-software/docs/record/orangepi5-cluster-build/](https://ssup2.github.io/blog-software/docs/record/orangepi5-cluster-build/)
* **Orange Pi 5 Max 기반 Kubernetes Data Platform 구축** : [https://ssup2.github.io/blog-software/docs/record/kubernetes-data-platform-orangepi5-cluster/](https://ssup2.github.io/blog-software/docs/record/kubernetes-data-platform-orangepi5-cluster/)

### 1.2. Producer, Consumer 구동을 위한 Python 패키지 설치

```bash
mkdir -p ~/kafka-schema-registry
cd ~/kafka-schema-registry
uv init
source .venv/bin/activate
uv add "confluent-kafka[avro,registry]" avro-python3
```

`uv`를 통해서 Producer, Consumer 실행을 위한 Python 패키지를 설치한다.

## 2. Kafka Schema Registry 이용

Kafka Schema Registry를 활용하여 Avro 스키마를 관리하고, Python Producer와 Consumer를 통해 스키마가 적용된 Record를 전송 및 수신한다.

### 2.1. Schema 등록

```bash
SCHEMA_REGISTRY_EXTERNAL_IP=$(kubectl get service -n kafka schema-registry -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
SCHEMA_REGISTRY_PORT=$(kubectl get service -n kafka schema-registry -o jsonpath='{.spec.ports[0].port}')
SCHEMA_REGISTRY_URL="http://${SCHEMA_REGISTRY_EXTERNAL_IP}:${SCHEMA_REGISTRY_PORT}"

echo "Schema Registry URL: ${SCHEMA_REGISTRY_URL}"
```
```bash
Schema Registry URL: http://192.168.1.99:8081
```

Kafka Schema의 Endpoint를 환경변수로 설정하고, 확인한다.

```bash
SCHEMA='{
  "type": "record",
  "name": "User",
  "namespace": "ssup2.com",
  "fields": [
    {"name": "id", "type": "int"},
    {"name": "name", "type": "string"},
    {"name": "email", "type": "string"}
  ]
}'

curl -X POST ${SCHEMA_REGISTRY_URL}/subjects/user/versions \
  -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  -d "{
    \"schema\": $(echo "$SCHEMA" | jq -c tojson)
  }"
```
```bash
{"id":3,"version":1,"guid":"e06655b8-8d49-9800-f924-ea691503f834","schemaType":"AVRO","schema":"{\"type\":\"record\",\"name\":\"User\",\"namespace\":\"ssup2.com\",\"fields\":[{\"name\":\"id\",\"type\":\"int\"},{\"name\":\"name\",\"type\":\"string\"},{\"name\":\"email\",\"type\":\"string\"}]}"}
```

Schema Registry에 Avro 스키마를 등록한다. 사용자 정보를 담는 `User` 스키마를 등록한다.

### 2.2. Producer 실행

```python {caption="[Code 1] producer.py", linenos=table}
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

# Create Avro Serializer (uses the retrieved schema from Schema Registry and embeds its schema ID in serialized messages)
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

Python으로 작성된 Producer는 Schema Registry에서 스키마를 가져와 Avro 형식으로 직렬화하여 Kafka Topic에 전송한다. Producer는 스키마를 전달하면 Schema Registry에 자동으로 등록하고 스키마 ID를 사용한다.

```bash
SCHEMA_REGISTRY_EXTERNAL_IP=$(kubectl get service -n kafka schema-registry -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
SCHEMA_REGISTRY_PORT=$(kubectl get service -n kafka schema-registry -o jsonpath='{.spec.ports[0].port}')
export SCHEMA_REGISTRY_URL="http://${SCHEMA_REGISTRY_EXTERNAL_IP}:${SCHEMA_REGISTRY_PORT}"

python producer.py
```
```bash
Retrieved schema from Schema Registry: user
Message delivered: user-events [0]
Message delivered: user-events [0]
Message delivered: user-events [0]
All messages sent
```

Producer를 실행하고, Message가 Kafka Topic에 전송되는 것을 확인한다.

### 2.3. Consumer 실행

Python으로 작성된 Consumer는 Kafka Topic에서 Avro 형식으로 직렬화된 Record를 수신하여 역직렬화한다. Consumer는 메시지에 포함된 스키마 ID를 사용하여 Schema Registry에서 자동으로 스키마를 가져온다.

```python {caption="[Code 2] consumer.py", linenos=table}
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

Consumer를 실행한다.

```bash
SCHEMA_REGISTRY_EXTERNAL_IP=$(kubectl get service -n kafka schema-registry -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
SCHEMA_REGISTRY_PORT=$(kubectl get service -n kafka schema-registry -o jsonpath='{.spec.ports[0].port}')
export SCHEMA_REGISTRY_URL="http://${SCHEMA_REGISTRY_EXTERNAL_IP}:${SCHEMA_REGISTRY_PORT}"

python consumer.py
```
```bash
Waiting for messages from topic: user-events
Received message: {'id': 1, 'name': 'Alice', 'email': 'alice@example.com'}
Received message: {'id': 2, 'name': 'Bob', 'email': 'bob@example.com'}
Received message: {'id': 3, 'name': 'Charlie', 'email': 'charlie@example.com'}
```

Consumer 실행 시 Producer에서 전송한 메시지가 Avro 형식으로 역직렬화되어 출력되는 것을 확인할 수 있다.

## 3. 참조

* Kafka Schema Producer : [https://suwani.tistory.com/154](https://suwani.tistory.com/154)
* Kafka Schema Consumer : [https://suwani.tistory.com/155](https://suwani.tistory.com/155)


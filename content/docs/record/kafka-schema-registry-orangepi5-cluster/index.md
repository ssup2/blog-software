---
title: Kafka Schema Registry 실습 / Orange Pi 5 Max Cluster 환경
draft: true
---

Kafka Schema Registry를 활용해서 Schema를 관리하는 실습을 수행한다.

## 1. 실습 환경 구성

### 1.1. 전체 실습 환경

### 1.2. Producer, Consumer 구동을 위한 Python 패키지 설치

```bash
mkdir -p ~/kafka-schema-registry
cd ~/kafka-schema-registry
uv init
uv add "confluent-kafka[avro,registry]" avro-python3
```

## 2. Kafka Schema Registry 이용

Kafka Schema Registry를 활용하여 Avro 스키마를 관리하고, Python Producer와 Consumer를 통해 스키마가 적용된 Record를 전송 및 수신한다.

### 2.1. Schema 등록

Kafka Schema의 Endpoint를 환경변수로 설정하고, 확인한다.

```bash
SCHEMA_REGISTRY_EXTERNAL_IP=$(kubectl get service -n kafka schema-registry -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
SCHEMA_REGISTRY_PORT=$(kubectl get service -n kafka schema-registry -o jsonpath='{.spec.ports[0].port}')
SCHEMA_REGISTRY_URL="http://${SCHEMA_REGISTRY_EXTERNAL_IP}:${SCHEMA_REGISTRY_PORT}"

echo "Schema Registry URL: ${SCHEMA_REGISTRY_URL}"
```
```bash
Schema Registry URL: http://192.168.1.99:8081
```

Schema Registry에 Avro 스키마를 등록한다. 사용자 정보를 담는 `User` 스키마를 등록한다.

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

curl -X POST ${SCHEMA_REGISTRY_URL}/subjects/user-value/versions \
  -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  -d "{
    \"schema\": $(echo "$SCHEMA" | jq -c tojson)
  }"
```
```bash
{"id":3,"version":3,"guid":"e06655b8-8d49-9800-f924-ea691503f834","schemaType":"AVRO","schema":"{\"type\":\"record\",\"name\":\"User\",\"namespace\":\"ssup2.com\",\"fields\":[{\"name\":\"id\",\"type\":\"int\"},{\"name\":\"name\",\"type\":\"string\"},{\"name\":\"email\",\"type\":\"string\"}]}"}
```

### 2.2. Producer 실행

Python으로 작성된 Producer는 Schema Registry에서 스키마를 가져와 Avro 형식으로 직렬화하여 Kafka Topic에 전송한다. Producer는 스키마를 전달하면 Schema Registry에 자동으로 등록하고 스키마 ID를 사용한다.

```python {caption="[File 1] producer.py", linenos=table}
import os
import time
from confluent_kafka import Producer
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroSerializer
from confluent_kafka.serialization import SerializationContext, MessageField

# Schema Registry configuration
schema_registry_url = os.getenv(
    "SCHEMA_REGISTRY_URL",
    "http://schema-registry.schema-registry.svc.cluster.local:8081"
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
subject_name = os.getenv("SCHEMA_SUBJECT", "user-value")
try:
    # Get latest version of schema
    schema = schema_registry_client.get_latest_version(subject_name)
    avro_schema_str = schema.schema.schema_str
    print(f"Retrieved schema from Schema Registry: {subject_name}")
except Exception as e:
    print(f"Failed to retrieve schema from Schema Registry: {e}")
    print("Make sure the schema is registered in Schema Registry first.")
    exit(1)

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

# Topic name
topic = os.getenv("KAFKA_TOPIC", "user-events")

# Send message
def send_message(user_data):
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

Producer를 실행한다.

```bash
# Python 패키지 설치
pip install confluent-kafka[avro,registry] avro-python3

# Schema Registry External IP를 환경변수로 설정
SCHEMA_REGISTRY_EXTERNAL_IP=$(kubectl get service -n kafka schema-registry -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
SCHEMA_REGISTRY_PORT=$(kubectl get service -n kafka schema-registry -o jsonpath='{.spec.ports[0].port}')
export SCHEMA_REGISTRY_URL="http://${SCHEMA_REGISTRY_EXTERNAL_IP}:${SCHEMA_REGISTRY_PORT}"

# Producer 실행
python producer.py
```

### 2.3. Consumer 실행

Python으로 작성된 Consumer는 Kafka Topic에서 Avro 형식으로 직렬화된 Record를 수신하여 역직렬화한다. Consumer는 메시지에 포함된 스키마 ID를 사용하여 Schema Registry에서 자동으로 스키마를 가져온다.

```python {caption="[File 2] consumer.py", linenos=table}
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
topic = os.getenv("KAFKA_TOPIC", "user-events")
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
# Schema Registry External IP를 환경변수로 설정
SCHEMA_REGISTRY_EXTERNAL_IP=$(kubectl get service -n kafka schema-registry -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
SCHEMA_REGISTRY_PORT=$(kubectl get service -n kafka schema-registry -o jsonpath='{.spec.ports[0].port}')
export SCHEMA_REGISTRY_URL="http://${SCHEMA_REGISTRY_EXTERNAL_IP}:${SCHEMA_REGISTRY_PORT}"

# Consumer 실행
python consumer.py
```

Consumer 실행 시 Producer에서 전송한 메시지가 Avro 형식으로 역직렬화되어 출력되는 것을 확인할 수 있다.

## 3. 참조

* Confluent Schema Registry : [https://docs.confluent.io/platform/current/schema-registry/index.html](https://docs.confluent.io/platform/current/schema-registry/index.html)
* Confluent Kafka Python : [https://github.com/confluentinc/confluent-kafka-python](https://github.com/confluentinc/confluent-kafka-python)
* Apache Avro : [https://avro.apache.org/](https://avro.apache.org/)
* Schema Registry REST API : [https://docs.confluent.io/platform/current/schema-registry/develop/api.html](https://docs.confluent.io/platform/current/schema-registry/develop/api.html)
* Kafka UI : [https://github.com/provectus/kafka-ui](https://github.com/provectus/kafka-ui)


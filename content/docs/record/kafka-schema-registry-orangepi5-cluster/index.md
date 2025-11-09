---
title: Kafka Schema Registry 실습 / Orange Pi 5 Max Cluster 환경
draft: true
---

Kafka Schema Registry를 활용해서 Schema를 관리하는 실습을 수행한다.

## 1. 실습 환경 구성

### 1.1. 전체 실습 환경

### 1.2. Python 패키지 설치

## 2. Kafka Schema Registry 이용

Kafka Schema Registry를 활용하여 Avro 스키마를 관리하고, Python Producer와 Consumer를 통해 스키마가 적용된 Record를 전송 및 수신한다.

### 2.1. Schema 등록

Schema Registry에 Avro 스키마를 등록하는 방법은 두 가지가 있다. 첫 번째는 REST API를 사용하는 방법이고, 두 번째는 Kafka UI를 사용하는 방법이다.

#### 2.1.1. REST API를 사용한 Schema 등록

Schema Registry에 Avro 스키마를 등록한다. 예제로 사용자 정보를 담는 `User` 스키마를 등록한다.

```bash
SCHEMA_REGISTRY_EXTERNAL_IP=$(kubectl get service -n kafka schema-registry -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
SCHEMA_REGISTRY_PORT=$(kubectl get service -n kafka schema-registry -o jsonpath='{.spec.ports[0].port}')
SCHEMA_REGISTRY_URL="http://${SCHEMA_REGISTRY_EXTERNAL_IP}:${SCHEMA_REGISTRY_PORT}"

echo "Schema Registry URL: ${SCHEMA_REGISTRY_URL}"
```
```bash
Schema Registry URL: http://192.168.1.99:8081
```

```bash
# Schema Registry에 스키마 등록
curl -X POST ${SCHEMA_REGISTRY_URL}/subjects/user-value/versions \
  -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  -d '{
    "schema": "{\"type\":\"record\",\"name\":\"User\",\"namespace\":\"com.example\",\"fields\":[{\"name\":\"id\",\"type\":\"int\"},{\"name\":\"name\",\"type\":\"string\"},{\"name\":\"email\",\"type\":\"string\"}]}"
  }'
```
```bash
{"id":2,"version":2,"guid":"b157942d-73b9-472c-ff5c-10a0dc1bde6c","schemaType":"AVRO","schema":"{\"type\":\"record\",\"name\":\"User\",\"namespace\":\"com.example\",\"fields\":[{\"name\":\"id\",\"type\":\"int\"},{\"name\":\"name\",\"type\":\"string\"},{\"name\":\"email\",\"type\":\"string\"}]}"}
```

등록된 스키마를 확인한다.

```bash
# 등록된 스키마 조회
curl ${SCHEMA_REGISTRY_URL}/subjects/user-value/versions/latest
```

#### 2.1.2. Kafka UI를 사용한 Schema 등록

Kafka UI는 웹 인터페이스를 통해 Schema Registry를 쉽게 관리할 수 있게 해준다. Kafka UI에 Schema Registry를 연결하려면 Kafka UI 설정에 Schema Registry URL을 추가해야 한다.

```yaml {caption="[File 1] kafka-ui-values.yaml - Schema Registry 설정 추가", linenos=table}
yamlApplicationConfig:
  kafka:
    clusters:
      - name: kafka
        bootstrapServers: kafka-kafka-sasl-bootstrap.kafka:9092
        properties:
          security.protocol: SASL_PLAINTEXT
          sasl.mechanism: SCRAM-SHA-512
          sasl.jaas.config: "org.apache.kafka.common.security.scram.ScramLoginModule required username=\"user\" password=\"user\";"
        schemaRegistry: http://schema-registry.schema-registry.svc.cluster.local:8081
    auth:
      type: disabled
```

Kafka UI Helm Chart를 업데이트한다.

```bash
# Kafka UI Helm Chart 업데이트
helm upgrade kafka-ui kafka-ui \
  --namespace kafka-ui \
  --values kafka-ui-values.yaml
```

Kafka UI에 접속하여 Schema Registry를 관리한다.

```bash
# Kafka UI Service 확인
kubectl get svc -n kafka-ui kafka-ui

# Kafka UI 접속 (LoadBalancer IP 사용)
# 브라우저에서 http://<LOADBALANCER_IP> 접속
```

Kafka UI 웹 인터페이스에서 Schema Registry를 사용하는 방법:

1. **Schema Registry 탭 접근**: Kafka UI 메인 화면에서 왼쪽 메뉴의 "Schema Registry" 탭을 클릭한다.
2. **Schema 등록**: "Create Schema" 버튼을 클릭하여 새로운 스키마를 등록한다.
   - **Subject**: 스키마의 Subject 이름을 입력한다 (예: `user-value`).
   - **Schema Type**: 스키마 타입을 선택한다 (예: `AVRO`).
   - **Schema**: Avro 스키마 JSON을 입력한다.
3. **Schema 조회**: 등록된 스키마 목록을 확인하고, 각 스키마의 버전 및 상세 정보를 조회할 수 있다.
4. **Schema 수정**: 기존 스키마의 새 버전을 등록하거나, 스키마 호환성 검사를 수행할 수 있다.
5. **Schema 삭제**: 더 이상 사용하지 않는 스키마를 삭제할 수 있다.

Kafka UI를 사용하면 REST API를 직접 호출하지 않고도 웹 인터페이스를 통해 Schema Registry를 쉽게 관리할 수 있다.

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


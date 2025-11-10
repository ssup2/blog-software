---
title: Kafka Schema Registry Practice / Orange Pi 5 Max Cluster Environment
---

Practice managing schemas using Kafka Schema Registry.

## 1. Practice Environment Setup

### 1.1. Overall Practice Environment

{{< figure caption="[Figure 1] Kafka Schema Registry Practice Environment" src="images/environment.png" width="850px" >}}

* **Kafka Schema Registry** : Manages schemas for Kafka messages.
* **Kafka** : Transmits messages between Producer and Consumer.
  * **_schema_ Topic** : Topic that stores schemas registered in Schema Registry.
  * **user-events Topic** : Topic that stores messages sent by Producer.
* **Producer** : Retrieves schemas from Kafka Schema Registry, serializes them in Avro format, and sends them to Kafka topics.
* **Consumer** : Receives messages serialized in Avro format from Kafka topics and deserializes them.

For the overall practice environment setup, refer to the following links:

* **Orange Pi 5 Max based Kubernetes Cluster Setup** : [https://ssup2.github.io/blog-software/docs/record/orangepi5-cluster-build/](https://ssup2.github.io/blog-software/docs/record/orangepi5-cluster-build/)
* **Orange Pi 5 Max based Kubernetes Data Platform Setup** : [https://ssup2.github.io/blog-software/docs/record/kubernetes-data-platform-orangepi5-cluster/](https://ssup2.github.io/blog-software/docs/record/kubernetes-data-platform-orangepi5-cluster/)

### 1.2. Python Package Installation for Producer and Consumer

```bash
mkdir -p ~/kafka-schema-registry
cd ~/kafka-schema-registry
uv init
source .venv/bin/activate
uv add "confluent-kafka[avro,registry]" avro-python3
```

Install Python packages required for running Producer and Consumer using `uv`.

## 2. Using Kafka Schema Registry

Manage Avro schemas using Kafka Schema Registry and send/receive records with schemas applied through Python Producer and Consumer.

### 2.1. Schema Registration

```bash
SCHEMA_REGISTRY_EXTERNAL_IP=$(kubectl get service -n kafka schema-registry -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
SCHEMA_REGISTRY_PORT=$(kubectl get service -n kafka schema-registry -o jsonpath='{.spec.ports[0].port}')
SCHEMA_REGISTRY_URL="http://${SCHEMA_REGISTRY_EXTERNAL_IP}:${SCHEMA_REGISTRY_PORT}"

echo "Schema Registry URL: ${SCHEMA_REGISTRY_URL}"
```
```bash
Schema Registry URL: http://192.168.1.99:8081
```

Set and verify the Kafka Schema endpoint as an environment variable.

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

Register an Avro schema in Schema Registry. Register a `User` schema containing user information.

### 2.2. Producer Execution

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

The Producer written in Python retrieves schemas from Schema Registry, serializes them in Avro format, and sends them to Kafka topics. When a schema is provided, the Producer automatically registers it in Schema Registry and uses the schema ID.

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

Execute the Producer and verify that messages are sent to the Kafka topic.

### 2.3. Consumer Execution

The Consumer written in Python receives records serialized in Avro format from Kafka topics and deserializes them. The Consumer automatically retrieves schemas from Schema Registry using the schema ID included in the message.

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

Execute the Consumer.

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

When executing the Consumer, you can verify that messages sent by the Producer are deserialized in Avro format and output.

## 3. References

* Kafka Schema Producer : [https://suwani.tistory.com/154](https://suwani.tistory.com/154)
* Kafka Schema Consumer : [https://suwani.tistory.com/155](https://suwani.tistory.com/155)


---
title: Kafka Schema Registry
---

## 1. Kafka Schema Registry

{{< figure caption="[Figure 1] Kafka Schema Registry Architecture" src="images/kafka-schema-registry-architecture.png" width="900px" >}}

Kafka Schema Registry performs the role of managing the Schema of Kafka Messages between Kafka Producer and Kafka Consumer. [Figure 1] shows the Architecture of Kafka Schema Registry. Kafka Schema Registry uses Kafka's `_schemas` Topic instead of a separate Database to maintain state information.

Since all Schema-related information is recorded in the `_schemas` Topic, Kafka Schema Registry has a Stateless characteristic and can easily perform Scale-out for load balancing. However, since Schema information stored in the Topic is also cached in Memory, the frequency of Kafka Schema Registry directly accessing the Topic is low, and generally accesses the Topic only when Schema is registered/changed/deleted or when Kafka Schema Registry is initialized.

```json {caption="[Schema Key 1] _schemas Topic Key Example", linenos=table}
{
	"keytype": "SCHEMA",
	"subject": "user-events-value",
	"version": 1,
	"magic": 1
}
```
```json {caption="[Schema Value 1] _schemas Topic Value Example", linenos=table}
{
	"subject": "user-events-value",
	"version": 1,
	"id": 3,
	"schemaType": "AVRO",
	"schema": "{\"type\":\"record\",\"name\":\"User\",\"namespace\":\"ssup2.com\",\"fields\":[{\"name\":\"id\",\"type\":\"int\"},{\"name\":\"name\",\"type\":\"string\"},{\"name\":\"email\",\"type\":\"string\"}]}",
	"deleted": false
}
```

The `_schemas` Topic records Schema-related information in Key, Value format like [Schema Key 1] and [Schema Value 1]. Key is used as a unique identifier for Schema, and Value contains Schema information. [Figure 1] also shows the operation process of Kafka Schema Registry, showing the process of Kafka Producer sending Kafka Messages and Kafka Consumer receiving Kafka Messages.

### 1.1. Schema Registration Process

Kafka Schema Registry can register Schemas through REST API and performs the following process:

1. Send a Schema registration request to Kafka Schema Registry through REST API.
2. Kafka Schema Registry records the Schema in the `_schemas` Topic.
3. Kafka Schema Registry then caches the Schema in Memory and returns the cached Schema when Producer or Consumer requests the Schema.

### 1.2. Message Serialization and Deserialization Process Using Schema

The process of Producer and Consumer using Schema is as follows:

1. Producer requests a Schema registered in Kafka Schema Registry and receives Schema and Schema ID by requesting with name and Version.
2. Producer serializes the Message based on the received Schema and sends the serialized Message along with Schema ID to Kafka Topic.
3. Consumer receives the serialized Message along with the Schema ID passed from Kafka Topic.
4. Consumer requests Schema from Kafka Schema Registry based on the received Schema ID.
5. Consumer deserializes the Message based on the received Schema.

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
avro_schemasstr = schema.schema.schema_str

# Create Avro Serializer (automatically registers schema in Schema Registry and uses schema ID)
avro_serializer = AvroSerializer(
    schema_registry_client,
    avro_schemasstr,
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

[Code 1] shows Python example code where Producer requests Schema, serializes Message based on Schema, and sends the serialized Message along with Schema ID to Kafka Topic. These processes can be easily implemented through the `confluent_kafka.schema_registry` Python Package.

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

[Code 2] shows Python example code where Consumer receives the serialized Message along with Schema ID passed from Kafka Topic, requests Schema from Kafka Schema Registry based on the received Schema ID, and deserializes Message based on the requested Schema. Similarly, it can be easily implemented through the `confluent_kafka.schema_registry` Python Package.

## 2. References

* Kafka Schema Registry : [https://medium.com/@tlsrid1119/kafka-schema-registry-feat-confluent-example-cde8a276f76c](https://medium.com/@tlsrid1119/kafka-schema-registry-feat-confluent-example-cde8a276f76c)


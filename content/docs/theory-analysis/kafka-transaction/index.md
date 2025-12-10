---
title: Kafka Transaction
draft: true
---

Kafka의 Transaction 기법을 분석한다.

## 1. Kafka Transaction

### 1.1. Producer-only Transaction

{{< figure caption="[Figure 1] Producer-only Transaction" src="images/producer-only-transaction.png" width="700px" >}}

```python {caption="[Code 1] Producing to multiple topics and partitions without transaction", linenos=table}
from confluent_kafka import Producer

producer = Producer({
    'bootstrap.servers': 'localhost:9092'
})

try:
    # Send to multiple topics and partitions
    producer.produce('orders', partition=0, value=b'order-1')
    producer.produce('orders', partition=1, value=b'order-2')
    producer.produce('payments', partition=0, value=b'payment-1')
    producer.produce('notifications', partition=0, value=b'notify-1')
    
    producer.flush()  # Wait for delivery
    print("All messages sent")
    
except Exception as e:
    print(f"Send failed: {e}")
```

```python {caption="[Code 2] Producing to multiple topics and partitions with transaction", linenos=table}
from confluent_kafka import Producer

producer = Producer({
    'bootstrap.servers': 'localhost:9092',
    'transactional.id': 'multi-partition-tx'
})

producer.init_transactions()
producer.begin_transaction()

try:
    # Send to multiple topics and partitions
    producer.produce('orders', partition=0, value=b'order-1')
    producer.produce('orders', partition=1, value=b'order-2')
    producer.produce('payments', partition=0, value=b'payment-1')
    producer.produce('notifications', partition=0, value=b'notify-1')
    
    producer.commit_transaction()  # Commit all atomically
    print("All messages committed atomically")
    
except Exception as e:
    producer.abort_transaction()  # Rollback all
    print(f"Transaction aborted: {e}")
```

### 1.2. Consume-Produce Transaction

{{< figure caption="[Figure 2] Consume-Produce Transaction" src="images/consume-produce-transaction.png" width="850px" >}}

```python {caption="[Code 3] Consuming and producing without transaction", linenos=table}
from confluent_kafka import Consumer, Producer

# Configuration
consumer = Consumer({
    'bootstrap.servers': 'localhost:9092',
    'group.id': 'my-group',
    'enable.auto.commit': False  # Manual commit
})
consumer.subscribe(['orders'])

producer = Producer({
    'bootstrap.servers': 'localhost:9092'
})

while True:
    # 1. Fetch message
    msg = consumer.poll(timeout=1.0)
    
    if msg is None or msg.error():
        continue
    
    # 2. Process & produce
    result = process(msg.value().decode('utf-8'))
    producer.produce('processed-orders', value=result.encode('utf-8'))
    producer.flush()
    
    # 3. Commit offset (separately!)
    consumer.commit()
```

```python {caption="[Code 4] Consuming and producing with transaction", linenos=table}
from confluent_kafka import Consumer, Producer, TopicPartition

# Consumer configuration
consumer = Consumer({
    'bootstrap.servers': 'localhost:9092',
    'group.id': 'my-group',
    'enable.auto.commit': False,
    'isolation.level': 'read_committed'  # Read only committed messages
})
consumer.subscribe(['orders'])

# Producer configuration (for Transaction)
producer = Producer({
    'bootstrap.servers': 'localhost:9092',
    'transactional.id': 'my-transactional-id',  # Required!
    'enable.idempotence': True
})

# Initialize transaction (once at startup)
producer.init_transactions()

while True:
    # 1. Fetch message (outside Transaction!)
    msg = consumer.poll(timeout=1.0)
    
    if msg is None or msg.error():
        continue
    
    # 2. Begin transaction
    producer.begin_transaction()
    
    try:
        # 3. Process & produce
        result = process(msg.value().decode('utf-8'))
        producer.produce('processed-orders', value=result.encode('utf-8'))
        
        # 4. Build offset information
        offsets = [TopicPartition(msg.topic(), msg.partition(), msg.offset() + 1)]
        
        # 5. Include offset commit in transaction
        producer.send_offsets_to_transaction(
            offsets,
            consumer.consumer_group_metadata()
        )
        
        # 6. Commit together (produce + offset)
        producer.commit_transaction()
        
    except Exception as e:
        print(f"Transaction failed: {e}")
        producer.abort_transaction()  # Rollback both
```

## 2. 참조

* Kafka Transaction : [https://developer.confluent.io/courses/architecture/transactions/](https://developer.confluent.io/courses/architecture/transactions/)
* Kafka Transaction : [https://www.confluent.io/blog/transactions-apache-kafka/](https://www.confluent.io/blog/transactions-apache-kafka/)
* Kafka Idempotence, Transaction : [https://stackoverflow.com/questions/58894281/difference-between-idempotence-and-exactly-once-in-kafka-stream](https://stackoverflow.com/questions/58894281/difference-between-idempotence-and-exactly-once-in-kafka-stream)
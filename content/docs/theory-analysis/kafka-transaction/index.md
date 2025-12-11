---
title: Kafka Transaction
draft: true
---

Kafka의 Transaction 기법을 분석한다.

## 1. Kafka Transaction

Kafka Transaction은 의미에서 유추할 수 있는것 처럼 **Producer가 Kafka로 보내는 다량의 Record를 하나의 Transaction으로 묶어서 처리하는 기법**을 의미한다. 여기서 다량의 Record들은 다수의 Topic, Partition에 전달되는 경우에도 하나의 Transaction으로 묶어서 처리될 수 있는 특징이 있다.

반면에 Kafka Transaction은 Consumer가 다수의 Record를 하나의 Transaction으로 묶어서 처리하는 기법은 Kafka에서 지원하지 않는다. 즉 Kafka Transaction은 Producer 중심의 Transaction 기법이다. Kafka Transaction은 크게 **Produce-only Transaction**과 **Consume-Produce Transaction** 2가지 방식으로 나누어진다.

### 1.1. Produce-only Transaction

{{< figure caption="[Figure 1] Produce-only Transaction" src="images/produce-only-transaction.png" width="700px" >}}

Produce-only Transaction은 의미 그대로 다수의 Topic, Partition에 전달되는 다량의 Record를 하나의 Transaction으로 묶어서 처리하는 기법을 의미한다. [Figure 1]은 Produce-only Transaction의 동작 과정을 나타내고 있다. Producer는 `Topic A`의 `Partition 0,1`과 `Topic B`의 `Partition 0,1,2`에 하나의 Transaction으로 묶어서 Record를 전달한다. 하나의 Transaction으로 묶여 있는 Record들은 모두 Kafka에 저장되거나 모두 저장되지 않는 **Atomicity** 특징을 갖는다.

Produce-only Transaction을 이용하는 경우는 주로 Kafka를 Event Bus가 아닌 Event Store로 활용하는 경우에 많이 이용된다. 즉 Kafka에 저장되는 Event의 정합성을 보장하기 위해서 Producer가 전송하는 다수의 Record들 중에서 일부 Record만 저장되는 것을 방지하기 위해서 사용된다.

```python {caption="[Code 1] Producing to multiple topics and partitions without transaction", linenos=table}
from confluent_kafka import Producer

producer = Producer({
    'bootstrap.servers': 'kafka-server:9092'
})

try:
    # Send to multiple topics and partitions
    producer.produce('orders', partition=0, value=b'order-1')
    producer.produce('orders', partition=1, value=b'order-2')
    producer.produce('payments', partition=0, value=b'payment-1')
    producer.produce('notifications', partition=0, value=b'notify-1')
    
    # Wait for delivery
    producer.flush()
    print("All messages sent")
    
except Exception as e:
    print(f"Send failed: {e}")
```

```python {caption="[Code 2] Producing to multiple topics and partitions with transaction", linenos=table}
from confluent_kafka import Producer

producer = Producer({
    'bootstrap.servers': 'kafka-server:9092',
    'transactional.id': 'producer-id'
})

# Initialize transaction (once at startup)
producer.init_transactions()

# Begin transaction
producer.begin_transaction()

try:
    # Send to multiple topics and partitions
    producer.produce('orders', partition=0, value=b'order-1')
    producer.produce('orders', partition=1, value=b'order-2')
    producer.produce('payments', partition=0, value=b'payment-1')
    producer.produce('notifications', partition=0, value=b'notify-1')
    
    # Commit all atomically
    producer.commit_transaction()  
    print("All messages committed atomically")
    
except Exception as e:
    # Rollback all
    producer.abort_transaction()
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
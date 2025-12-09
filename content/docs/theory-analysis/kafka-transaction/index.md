---
title: Kafka Idempotence, Transaction
draft: true
---

Kafka의 Idempotence과 Transaction에 대해서 분석한다.

## 1. Kafka Idempotence

* Producer ID : 
* Producer Epoch : 
* Sequence Number : 

## 2. Kafka Transaction

* `ENABLE_IDEMPOTENCE_CONFIG` : Kafka의 Idempotence 기능을 활성화 하기 위한 설정 값이다.
* `ACKS_CONFIG` : Kafka의 ACK 설정 값이다.
* `MAX_IN_FLIGHT_REQUESTS_PER_CONNECTION` : Kafka의 동시 요청 수 제한 값이며, 기본값은 5이다.
* `RETRIES_CONFIG` : Kafka의 재시도 횟수 설정 값이다.
* `TRANSACTIONAL_ID_CONFIG` : Kafka의 Transaction 기능을 활성화 하기 위한 설정 값이다.

```python
from confluent_kafka import Producer

producer = Producer({
    'bootstrap.servers': 'localhost:9092'
})

try:
    # 여러 토픽, 여러 파티션에 전송
    producer.produce('orders', partition=0, value=b'order-1')
    producer.produce('orders', partition=1, value=b'order-2')
    producer.produce('payments', partition=0, value=b'payment-1')
    producer.produce('notifications', partition=0, value=b'notify-1')
    
    producer.flush()  # 전송 완료 대기
    print("All messages sent")
    
except Exception as e:
    print(f"Send failed: {e}")
```

```python
from confluent_kafka import Producer

producer = Producer({
    'bootstrap.servers': 'localhost:9092',
    'transactional.id': 'multi-partition-tx'
})

producer.init_transactions()

producer.begin_transaction()

try:
    # 여러 토픽, 여러 파티션에 전송
    producer.produce('orders', partition=0, value=b'order-1')
    producer.produce('orders', partition=1, value=b'order-2')
    producer.produce('payments', partition=0, value=b'payment-1')
    producer.produce('notifications', partition=0, value=b'notify-1')
    
    producer.commit_transaction()
    print("All messages committed atomically")
    
except Exception as e:
    producer.abort_transaction()
    print(f"Transaction aborted: {e}")
```

```python
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

```python
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
* Understanding Kafka Producer Part 2 : [https://github.com/AutoMQ/automq/wiki/Understanding-Kafka-Producer-Part-2](https://github.com/AutoMQ/automq/wiki/Understanding-Kafka-Producer-Part-2)
* Kafka Guarantee : [https://developer.confluent.io/courses/architecture/guarantees/](https://developer.confluent.io/courses/architecture/guarantees/)
* Kafka Transaction : [https://baebalja.tistory.com/627](https://baebalja.tistory.com/627)
* Kafka Idempotence, Transaction : [https://www.confluent.io/blog/exactly-once-semantics-are-possible-heres-how-apache-kafka-does-it/](https://www.confluent.io/blog/exactly-once-semantics-are-possible-heres-how-apache-kafka-does-it/)
* Kafka Transaction : [https://tjsals7825.medium.com/%EB%A9%94%EC%8B%9C%EC%A7%80-%EB%B8%8C%EB%A1%9C%EC%BB%A4-3-kafka-e0b51005c472](https://tjsals7825.medium.com/%EB%A9%94%EC%8B%9C%EC%A7%80-%EB%B8%8C%EB%A1%9C%EC%BB%A4-3-kafka-e0b51005c472)
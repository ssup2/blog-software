---
title: Kafka Transaction
draft: true
---

Kafka의 Transaction 기법을 분석한다.

## 1. Kafka Transaction

Kafka Transaction은 의미에서 유추할 수 있는것 처럼 **Producer가 Kafka로 보내는 다량의 Record를 하나의 Transaction으로 묶어서 처리하는 기법**을 의미한다. 여기서 다량의 Record들은 다수의 Topic, Partition에 전달되는 경우에도 하나의 Transaction으로 묶어서 처리될 수 있는 특징이 있다. 반면에 Kafka Transaction은 Consumer가 다수의 Record를 하나의 Transaction으로 묶어서 처리하는 기법은 Kafka에서 지원하지 않는다. 즉 Kafka Transaction은 Producer 중심의 Transaction 기법이다.

Kafka Transaction은 내부적으로 two-phase commit 기법을 이용하여 구현되어 있으며, Kafka Transaction을 이용하기 위해서는 반드시 **Idempotence 기능** (`enable.idempotence`)과 **In-flight Request 제한 기능** (`max.in.flight.requests.per.connection`)을 `5` 이하로 설정하여 동일한 Event/Data가 중복으로 저장되는 것을 방지해야 한다. Kafka Transaction은 크게 **Produce-only Transaction**과 **Consume-Produce Transaction** 2가지 방식으로 나누어진다.

### 1.1. Produce-only Transaction

{{< figure caption="[Figure 1] Produce-only Transaction" src="images/produce-only-transaction.png" width="700px" >}}

Produce-only Transaction은 의미 그대로 다수의 Topic, Partition에 전달되는 다량의 Record를 하나의 Transaction으로 묶어서 처리하는 기법을 의미한다. [Figure 1]은 Produce-only Transaction의 동작 과정을 나타내고 있다. Producer는 `Topic A`의 `Partition 0,1`과 `Topic B`의 `Partition 0,1,2`에 하나의 Transaction으로 묶어서 Record를 전달한다. 하나의 Transaction으로 묶여 있는 Record들은 모두 Kafka에 저장되거나 모두 저장되지 않는 **Atomicity** 특징을 갖는다.

Produce-only Transaction을 이용하는 경우는 주로 Kafka를 Event Bus가 아닌 Event/Data Store로 활용하는 경우에 많이 이용된다. 즉 Kafka에 저장되는 Event/Data의 정합성을 보장하기 위해서 Producer가 전송하는 다수의 Record들 중에서 일부 Record만 저장되는 것을 방지하기 위해서 사용된다.

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
    'transactional.id': 'producer-id' # Required!
    'enable.idempotence': True
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

[Code 1]은 Transaction 적용 전의 Producer App Code를 나타내고 있으며, [Code 2]는 Transaction 적용 후의 Producer App Code를 나타내고 있다. Kafka Transaction을 이용하는 경우 DB Transaction과 마찬가지로 Transaction을 시작하기 전에 Transaction을 초기화하고, Transaction을 시작하고, Transaction을 종료하는 과정을 거쳐야 한다.

[Code 2]에서는 `producer.init_transactions()`를 통해서 Transaction을 초기화하고, `producer.begin_transaction()`를 통해서 Transaction을 시작하고, `producer.commit_transaction()`를 통해서 Transaction을 종료한다. 만약 Transaction 중에 에러가 발생하면 `producer.abort_transaction()`를 통해서 Transaction을 중단한다.

Transaction을 이용하기 위해서는 반드시 `transactional.id` 설정 값을 설정해야 한다. `transactional.id` 각 Producer마다 고유의 ID를 설정해야 한다. 일반적으로 Hostname을 이용하여 고유의 ID를 설정한다.

### 1.2. Consume-Produce Transaction

{{< figure caption="[Figure 2] Consume-Produce Transaction" src="images/consume-produce-transaction.png" width="850px" >}}

Consume-Produce Transaction은 의미 그대로 Application에서 Kafka에서 다수의 Record를 가져와 (Consume) Event/Data를 처리하고, 처리한 Event/Data를 다시 Kafka로 전달 (Produce)하는 과정을 하나의 Transaction으로 묶어서 처리하는 기법을 의미한다. [Figure 2]는 Consume-Produce Transaction의 동작 과정을 나타내고 있다. Application은 `Topic A`의 `Partition 0,1`으로부터 Record를 가져와 Event/Data를 처리하고, 처리한 Event/Data를 `Topic B`의 `Partition 0,1,2`에 전달하는 과정을 하나의 Transaction으로 묶어서 처리하고 있다.

Consume-Produce Transaction은 주로 Kafka에 저장된 Event/Data를 정확히 한번만 처리하는 **Exactly-Once**를 구현하기 위해서 사용된다. Kafka와 Kafka 사이에서 Event/Data를 변환하는 Spark Streams Application에서도 Kafka Transaction을 이용하여 **Exactly-Once**를 구현하고 있다.

```python {caption="[Code 3] Consuming and producing without transaction", linenos=table}
from confluent_kafka import Consumer, Producer

# Configuration
consumer = Consumer({
    'bootstrap.servers': 'kafka-server:9092',
    'group.id': 'consumer-group',
    'enable.auto.commit': False  # Manual commit
})
consumer.subscribe(['orders'])

producer = Producer({
    'bootstrap.servers': 'kafka-server:9092'
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
    
    # 3. Commit offset
    consumer.commit()
```

[Code 3]은 Transaction 적용 전의 Consumer, Data 처리, Producer 역할을 수행하는 App Code를 나타내고 있다. Transaction이 적용되기 전이라면 `2.Process & produce` 과정을 마치고 `3.Commit offset` 과정이 실행되기 전에 App이 죽고 다시 실행되면, 다시 실행된 App은 동일한 Data를 Kafka로부터 가져와 동일한 처리를 수행하고 Kafka에 중복으로 저장을 수행하게 된다. 왜냐하면 Kafka 로부터 Data를 처음 가져왔을때 Data 처리만 수행하고 Commit 까지는 완료하지 못했기 때문에 Kafka는 Commit이 완료될때 까지 동일한 Data를 Consumer에게 전달하기 때문이다.

```python {caption="[Code 4] Consuming and producing with transaction", linenos=table}
from confluent_kafka import Consumer, Producer, TopicPartition

# Consumer configuration
consumer = Consumer({
    'bootstrap.servers': 'kafka-server:9092',
    'group.id': 'consumer-group',
    'enable.auto.commit': False,
    'isolation.level': 'read_committed'  # Read only committed messages
})
consumer.subscribe(['orders'])

# Producer configuration (for Transaction)
producer = Producer({
    'bootstrap.servers': 'kafka-server:9092',
    'transactional.id': 'producer-id',  # Required!
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
        
        # 4. Get next offset
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

[Code 4]은 Transaction 적용 후의 Consumer, Data 처리, Producer 역할을 수행하는 App Code를 나타내고 있다. 핵심은 가져온 Data의 **Record Offset**보다 하나 많은 값을 처리가 완료된 Data와 함께 `producer.send_offsets_to_transaction()` 함수를 통해서 하나의 Transaction으로 묶어서 처리한다는 점이다. 즉 Transaction을 통해서 처리가 완료된 Data와 다음에 처리할 Data의 Offset의 Atomicity를 보장하여 **Exactly-Once**를 구현한다.

## 2. 참조

* Kafka Transaction : [https://developer.confluent.io/courses/architecture/transactions/](https://developer.confluent.io/courses/architecture/transactions/)
* Kafka Transaction : [https://www.confluent.io/blog/transactions-apache-kafka/](https://www.confluent.io/blog/transactions-apache-kafka/)
* Kafka Idempotence, Transaction : [https://stackoverflow.com/questions/58894281/difference-between-idempotence-and-exactly-once-in-kafka-stream](https://stackoverflow.com/questions/58894281/difference-between-idempotence-and-exactly-once-in-kafka-stream)
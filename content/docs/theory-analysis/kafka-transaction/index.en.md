---
title: Kafka Transaction
---

Analyzes Kafka's Transaction technique.

## 1. Kafka Transaction

Kafka Transaction, as the name suggests, refers to a **technique that bundles multiple Records sent by Producer to Kafka into one Transaction for processing**. Here, multiple Records can be bundled into one Transaction for processing even when delivered to multiple Topics and Partitions. On the other hand, Kafka Transaction does not support a technique where Consumer bundles multiple Records into one Transaction for processing. That is, Kafka Transaction is a Producer-centric Transaction technique.

Kafka Transaction is internally implemented using two-phase commit technique, and to use Kafka Transaction, **Idempotence functionality** (`enable.idempotence`) and **In-flight Request limiting functionality** (`max.in.flight.requests.per.connection`) must be set to `5` or less to prevent duplicate storage of identical Events/Data. Kafka Transaction is largely divided into two methods: **Produce-only Transaction** and **Consume-Produce Transaction**.

### 1.1. Produce-only Transaction

{{< figure caption="[Figure 1] Produce-only Transaction" src="images/produce-only-transaction.png" width="700px" >}}

Produce-only Transaction, as the name suggests, refers to a technique that bundles multiple Records delivered to multiple Topics and Partitions into one Transaction for processing. [Figure 1] shows the operation process of Produce-only Transaction. Producer delivers Records bundled into one Transaction to `Partition 0,1` of `Topic A` and `Partition 0,1,2` of `Topic B`. Records bundled into one Transaction have **Atomicity** characteristics where all are stored in Kafka or all are not stored.

Produce-only Transaction is mainly used when utilizing Kafka as an Event/Data Store rather than an Event Bus. That is, it is used to prevent only some Records among multiple Records sent by Producer from being stored, in order to ensure consistency of Events/Data stored in Kafka.

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

[Code 1] shows Producer App Code before Transaction is applied, and [Code 2] shows Producer App Code after Transaction is applied. When using Kafka Transaction, similar to DB Transaction, the process of initializing Transaction before starting Transaction, starting Transaction, and ending Transaction must be performed.

In [Code 2], Transaction is initialized through `producer.init_transactions()`, Transaction is started through `producer.begin_transaction()`, and Transaction is ended through `producer.commit_transaction()`. If an error occurs during Transaction, Transaction is aborted through `producer.abort_transaction()`.

To use Transaction, `transactional.id` setting value must be set. `transactional.id` must be set to a unique ID for each Producer. Generally, a unique ID is set using Hostname.

### 1.2. Consume-Produce Transaction

{{< figure caption="[Figure 2] Consume-Produce Transaction" src="images/consume-produce-transaction.png" width="850px" >}}

Consume-Produce Transaction, as the name suggests, refers to a technique that bundles the process of fetching multiple Records from Kafka (Consume) in Application, processing Events/Data, and delivering processed Events/Data back to Kafka (Produce) into one Transaction for processing. [Figure 2] shows the operation process of Consume-Produce Transaction. Application bundles the process of fetching Records from `Partition 0,1` of `Topic A`, processing Events/Data, and delivering processed Events/Data to `Partition 0,1,2` of `Topic B` into one Transaction for processing.

Consume-Produce Transaction is mainly used to implement **Exactly-Once**, which processes Events/Data stored in Kafka exactly once. Spark Streams Applications that transform Events/Data between Kafka and Kafka also use Kafka Transaction to implement **Exactly-Once**.

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

[Code 3] shows App Code that performs Consumer, Data processing, and Producer roles before Transaction is applied. If Transaction is not applied, if App dies after completing the `2.Process & produce` process and before executing the `3.Commit offset` process, and then runs again, the restarted App fetches the same Data from Kafka, performs the same processing, and performs duplicate storage in Kafka. This is because when Data is first fetched from Kafka, only Data processing is performed and Commit is not completed, so Kafka delivers the same Data to Consumer until Commit is completed.

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

[Code 4] shows App Code that performs Consumer, Data processing, and Producer roles after Transaction is applied. The key point is that it bundles processed Data together with a value one more than the **Record Offset** of fetched Data through the `producer.send_offsets_to_transaction()` function into one Transaction for processing. That is, it implements **Exactly-Once** by ensuring Atomicity of processed Data and Offset of Data to be processed next through Transaction.

## 2. References

* Kafka Transaction : [https://developer.confluent.io/courses/architecture/transactions/](https://developer.confluent.io/courses/architecture/transactions/)
* Kafka Transaction : [https://www.confluent.io/blog/transactions-apache-kafka/](https://www.confluent.io/blog/transactions-apache-kafka/)
* Kafka Idempotence, Transaction : [https://stackoverflow.com/questions/58894281/difference-between-idempotence-and-exactly-once-in-kafka-stream](https://stackoverflow.com/questions/58894281/difference-between-idempotence-and-exactly-once-in-kafka-stream)


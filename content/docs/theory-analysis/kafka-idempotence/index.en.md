---
title: Kafka Idempotence
---

Analyzes Kafka's Idempotence functionality.

## 1. Kafka Idempotence Functionality

Kafka Idempotence, as the name suggests, is a functionality to prevent duplicate storage of Records sent by Kafka's Producer in Kafka. When Kafka is simply used as an Event Bus, duplicate storage of identical Records in Kafka is generally not a problem, but when Kafka is utilized beyond an Event Bus as an Event Store, duplicate storage of identical Records becomes a problem, and utilizing Kafka Idempotence functionality is essential to prevent such problems.

{{< figure caption="[Figure 1] Kafka Idempotence Architecture" src="images/kafka-idempotence-architecture.png" width="1000px" >}}

[Figure 1] shows the Architecture of Kafka when Kafka Idempotence functionality is enabled. To enable Kafka Idempotence, the following Properties must be set.

* `enable.idempotence=true` : Configuration value to enable Kafka Idempotence functionality.
* `acks=all` : ACK configuration must use the `all` setting value. The `all` setting value means that Producer can receive ACK only after Records are replicated to all Replica Topics/Partitions.

When Idempotence functionality is enabled, Producer's Request includes **PID (Producer ID)**, **Epoch**, and **Sequence Number** information.

* **PID (Producer ID)** : Unique ID of Producer assigned by Kafka. When Producer connects to Kafka, Producer ID is issued and delivered to Producer, and thereafter Producer sends Records along with the assigned PID. If Kafka Transaction technique is not used, Producer receives a new PID when Producer restarts. If Producer sends a PID that Broker has not issued, Producer receives `UnknownProducerIdException` Exception from Kafka Broker.
* **Epoch (Producer Epoch)** : Represents Producer's unique Epoch. Epoch value starts at 0 and increases by 1 each time Producer receives `OutOfOrderSequenceException` Exception from Kafka Broker.
* **Sequence Number** : Unique sequential number of Records assigned by Producer. Generally, one Producer Request contains Record Batches by Partition/Topic, and each Record Batch contains **Base Sequence Number** that represents the start of Records and **Offset** that represents the difference from Base Sequence Number to the last Record.

When Idempotence functionality is enabled, Kafka Broker **Caches up to 5** Sequence Numbers of processed Record Batches by Topic/Partition **for each PID and Epoch**, and through the following operations, it **prevents duplicate Record storage** as well as **prevents Records from being stored in incorrect order**.

* When Broker receives a Record Batch, it first checks whether the Record Batch's Sequence Number is already Cached.
* If the Record Batch's Sequence Number is Cached, Kafka Broker considers it as an already received Record Batch and does not store it in Topic/Partition. And it only sends ACK to Producer.
* If the Record Batch's Sequence Number is not Cached, Kafka Broker removes the Sequence Number of the first Cached Record Batch and Caches the Sequence Number of the received Record Batch. And it stores the received Record Batch in Topic/Partition and sends ACK to Producer.
* Even if the Record Batch's Sequence Number is not Cached, if the Sequence Number of the received Record Batch is not the next number after the Sequence Number of the previously received Batch, Kafka Broker does not store the received Record Batch in Topic/Partition and makes Broker raise `OutOfOrderSequenceException` Exception.
* When Producer receives `OutOfOrderSequenceException` Exception, Producer increases Epoch value by 1 and then retries transmission. When Kafka Broker receives Batch Record with increased Epoch value, it removes the previously Cached Sequence Number and Caches the new Sequence Number.

Producer manages sent Requests as **In-flight Requests** until ACK is received from Kafka Broker for necessary Request retransmission, and has the following characteristics.

* In-flight Request disappears when ACK is received from Kafka Broker.
* In-flight Request contains all Metadata necessary for Request retransmission.
* When In-flight Request is retransmitted, it is retransmitted as a Request with **the same Sequence Number**. That is, Sequence Number is not reconstructed during Request retransmission.
* The maximum number of In-flight Requests that can be managed per Producer can be limited through the `max.in.flight.requests.per.connection` setting, and the default value is **5**. That is, by default, up to 5 Requests can be managed in In-flight state.

Kafka Idempotence functionality does not prevent duplicate Records in all cases, and duplicate Records can occur in the following cases.

* When Producer sends a Record Batch and then Producer restarts, changing PID, and then sends the same Record Batch again, duplicate Records can occur. This is because Kafka Broker manages Sequence Number Cache based on PID, so when PID changes, it is considered as a new Producer.
* When Producer sends a Record Batch to a different Partition instead of the same Partition, duplicate Records can occur. This is because Kafka Broker manages Sequence Number Cache by each Partition.
* When Producer sets the `inflight.requests.per.connection` setting value to **6 or more**, and Producer sends 6 or more Requests simultaneously, duplicate Records can occur. This is because Kafka Broker can only Cache Sequence Numbers of up to 5 Record Batches per Partition. This 5 is a Hard-coded value and cannot be changed. Therefore, to properly utilize Kafka Idempotence functionality, the `inflight.requests.per.connection` setting value must be set to **5 or less**.

## 2. Sequence Flow with Kafka Idempotence

Summarizes various Sequence Flows that can occur when Kafka Idempotence functionality is enabled.

### 2.1. Sequence Flow with Success

{{< figure caption="[Figure 2] Sequence Flow with Success" src="images/kafka-idempotence-sequence-flow-success.png" width="900px" >}}

[Figure 2] shows the Sequence Flow when Records are stored normally with Kafka Idempotence functionality enabled. Assuming a single Topic/Partition, only Sequence Numbers are shown. Three Record Batches `A/120~114`, `B/124~121`, `C/132~125` and two Record Batches `D/142~133`, `E/150~143` were sent separately, and thereafter Kafka Broker sends ACK to Producer sequentially after processing Record Batches.

### 2.2. Sequence Flow with Missing ACKs

{{< figure caption="[Figure 3] Sequence Flow with Missing ACKs" src="images/kafka-idempotence-sequence-flow-missing-acks.png" width="900px" >}}

[Figure 3] shows the Sequence Flow where duplicate storage of Record Batches is prevented even when ACKs are lost with Kafka Idempotence functionality enabled. It shows a case where 5 Batch Records `A/120~114`, `B/124~121`, `C/132~125`, `D/142~133`, `E/150~143` sent by Producer were processed well, but ACKs for 2 Batch Records `D/142~133`, `E/150~143` were lost.

Producer that did not receive ACKs for `D/142~133`, `E/150~143` waits for `request.timeout.ms` time and then sends the same Record Batches again. At this time, Kafka Broker considers them as already received Record Batches and does not store them in Topic/Partition. And it only sends ACK to Producer to prevent Producer from sending the same Record Batches again.

### 2.3. Sequence Flow with Missing Records

{{< figure caption="[Figure 4] Sequence Flow with Missing Records" src="images/kafka-idempotence-sequence-flow-missing-records.png" width="900px" >}}

[Figure 4] shows the Sequence Flow when Batch Records are lost with Kafka Idempotence functionality enabled. It shows a case where among 5 Batch Records `A/120~114`, `B/124~121`, `C/132~125`, `D/142~133`, `E/150~143` sent by Producer, the `C/132~125` Batch Record was lost. Kafka Broker receives the next Batch Records `D/142~133`, `E/150~143` after skipping the `C/132~125` Batch Record, so it sends `OutOfOrderSequenceException` Exception to Producer.

Producer that received `OutOfOrderSequenceException` Exception increases Epoch value by 1 and then starts retransmission from the next Batch Record after the last Batch Record that received ACK. In this way, utilizing Idempotence functionality can also prevent the phenomenon where the order of Batch Records changes based on Sequence Number.

### 2.4. Sequence Flow with Sequence Cache Missed

{{< figure caption="[Figure 5] Sequence Flow with Sequence Cache Missed" src="images/kafka-idempotence-sequence-flow-cache-missed.png" width="900px" >}}

[Figure 5] shows the Sequence Flow where duplicate Records occur when the `inflight.requests.per.connection` setting value is set to 6. It shows a case where 6 Batch Records `A/120~114`, `B/124~121`, `C/132~125`, `D/142~133`, `E/150~143`, `F/155~151` sent by Producer were processed well, but ACK for the first Batch Record `A/120~114` was lost.

Producer that did not receive ACK for the `A/120~114` Batch Record waits for `request.timeout.ms` time and then sends the same Record Batch again. At this time, Kafka Broker has only the last 5 Batch Records Cached, and the first `A/120~114` Batch Record is not Cached. Therefore, Kafka Broker does not recognize that the `A/120~114` Batch Record is an already stored Batch Record and raises `OutOfOrderSequenceException` Exception.

Producer that received `OutOfOrderSequenceException` Exception increases Epoch value by 1 and then retransmits the `A/120~114` Batch Record that did not receive ACK, and Kafka Broker that received the `A/120~114` Batch Record with increased Epoch value performs duplicate storage.

## 3. References

* Kafka Idempotence, Transaction : [https://stackoverflow.com/questions/58894281/difference-between-idempotence-and-exactly-once-in-kafka-stream](https://stackoverflow.com/questions/58894281/difference-between-idempotence-and-exactly-once-in-kafka-stream)
* Understanding Kafka Producer Part 2 : [https://github.com/AutoMQ/automq/wiki/Understanding-Kafka-Producer-Part-2](https://github.com/AutoMQ/automq/wiki/Understanding-Kafka-Producer-Part-2)


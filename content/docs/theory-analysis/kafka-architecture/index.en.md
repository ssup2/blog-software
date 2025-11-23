---
title: Kafka Architecture
---

Analyze the architecture of Kafka, a distributed message queue.

## 1. Kafka Architecture

Kafka is a distributed message queue based on publish-subscribe. Kafka has the characteristic of storing received messages for a certain period and allowing reprocessing, so it is generally used as an **Event Bus** in Event Driven Architecture. It also has the characteristic of high message throughput, and based on this, it is also used as a **Data Stream Queue** for big data processing platforms like Storm.

{{< figure caption="[Figure 1] Kafka Architecture" src="images/kafka-architecture.png" width="1000px" >}}

[Figure 1] shows the components of Kafka along with the process of delivering messages in Kafka. When a **Producer** sends (Publishes) a message to a specific **Topic**, all **Consumers** of **Consumer Groups** that subscribe to that Topic check for the existence of messages in that Topic, and if there is a message, they fetch the message. The roles of each component are as follows.

* **Kafka Broker** : The core server of Kafka that receives, manages, and sends messages. Kafka Brokers generally operate as a **Kafka Cluster** on multiple nodes for load balancing and HA (High Availability).
* **Zookeeper** : Performs the role of a highly available storage for storing metadata of Kafka Cluster. Like Kafka Brokers, it operates as a cluster on multiple nodes. From Kafka version 2.8 onwards, it supports **KRaft Mode** where Kafka Brokers operating based on the Raft algorithm perform the storage role themselves. When operating in KRaft Mode, Zookeeper is not used separately.
* **Topic** : Unit for managing messages. Topics are divided into smaller units called **Partitions**, and Kafka increases message throughput using multiple Partitions. Partitions are composed of a collection of **Records**, where Record means the **minimum transmission unit** defined in Kafka.
* **Producer** : App that sends (**Publishes**) messages to Topics. When multiple Partitions exist, it determines which Partition to store Records in through **Partitioner** built into Producer.
* **Consumer** : App that receives (**Subscribes**) messages from Topics. Consumers check for the existence of messages through Poll functions in a **Polling manner**, and if there is a message, they fetch it. That is, messages are delivered from Topics to Consumers, but the entity that fetches messages is the Consumer.
* **Consumer Group** : As the name implies, it performs the role of grouping multiple Consumers, and Kafka uses Consumer Groups to increase the availability and message throughput of Consumers.

### 1.1. Record

Record means the **minimum transmission unit** defined in Kafka. Producer creates Records and delivers them to Topics, and Consumer fetches Records stored in Topics and processes them. Producer Record and Consumer Record are as follows.

#### 1.1.1. Producer Record

{{< table caption="[Table 1] Producer Record" >}}
| Field | Optional | Description |
|---|---|---|
| **Topic** | X | Topic to which the Record should be delivered. |
| **Key** | O | Key of the Record, used to determine which Partition to store the Record in. If there is no Key, Partition is determined using Round-robin method. |
| **Value** | O | Actual message to be delivered. |
| **Partition** | O | Specifies the Partition to deliver the Record to. |
| **Headers** | O | Contains additional information about the Record. |
| **Timestamp** | O | Time when the Record was created. If not specified, it is set to `System.currentTimeMillis` by default. |
{{< /table >}}

[Table 1] describes the Fields of Records delivered by Producers. All Fields except Topic are Optional fields.

#### 1.1.2. Consumer Record

{{< table caption="[Table 2] Consumer Record" >}}
| Field | Optional | Description |
|---|---|---|
| **Topic** | X | Topic where the Record was stored. |
| **Partition** | X | Partition where the Record was stored. |
| **Key** | O | Key of the Record. |
| **Value** | O | Actual message that was delivered. |
| **Offset** | X | Offset of the Record stored in the Partition. |
| **Headers** | X | Contains additional information about the Record. |
| **Timestamp** | X | Timestamp of the Record. |
| **Timestamp Type** | X | Timestamp type of the Record. Supports two types: `CreateTime` and `LogAppendTime`. `CreateTime` means the Timestamp of the Record sent by Producer, i.e., the time when the Record was created, and `LogAppendTime` means the time when the Record was stored in Kafka Broker. If not specified, it is set to `CreateTime` by default. |
| **Serialized Key Size** | X | Size of the serialized Key of the Record. If there is no Key, it is set to `-1`. |
| **Serialized Value Size** | X | Size of the serialized Value of the Record. If there is no Value, it is set to `-1`. |
| **Leader Epoch** | X | Epoch of the Leader Partition where the Record was stored. |
{{< /table >}}

[Table 2] describes the Fields of Records received by Consumers. All Fields except Topic and Partition are Optional fields.

#### 1.1.3. Record Retention

Kafka preserves Records stored in Partitions according to certain criteria, which is expressed as **Record Retention** policy in Kafka. The Record Retention policy includes two methods: preserving only Records within a specific period, and preserving so that Partition size does not exceed a specific capacity. Both methods can be applied simultaneously. The default Record Retention policy preserves Records for 7 days and preserves them with unlimited size.

* `log.retention.hours` : Sets the Record retention period in hours. If set to `-1`, unlimited time retention is performed.
* `log.retention.minutes` : Sets the Record retention period in minutes. If set to `-1`, unlimited minute retention is performed.
* `log.retention.ms` : Sets the Record retention period in milliseconds. If set to `-1`, unlimited millisecond retention is performed.
* `log.retention.bytes` : Sets the Record retention capacity in bytes. If set to `-1`, unlimited size retention is performed.

```properties {caption="[Config 1] Kafka Record Retention Properties Example for Broker", linenos=table}
# 7 Days Duration
log.retention.hours=168

# Infinite Size
log.retention.bytes=-1 
```

```shell {caption="[Shell 1] Kafka Record Retention Command Example for Topic", linenos=table}
kafka-configs.sh --bootstrap-server kafka-broker-host:9092 --entity-type topics --entity-name topic-name --alter --add-config log.retention.hours=168
kafka-configs.sh --bootstrap-server kafka-broker-host:9092 --entity-type topics --entity-name topic-name --alter --add-config log.retention.bytes=-1
```

Record Retention can be set through **global settings via Kafka Properties** or **settings for each Topic**. [Config 1] shows an example of global settings via Kafka Properties, and [Shell 1] shows an example of Record Retention settings for each Topic.

### 1.2. Partition, Offset

{{< figure caption="[Figure 2] Kafka Partition" src="images/kafka-partition.png" width="1000px" >}}

Partition is a unit for distributing one Topic to multiple Kafka Brokers within a Kafka Cluster for parallel processing to increase message throughput, and also performs the role of a Queue that stores messages sequentially. Each Topic can have a different number of Partitions. [Figure 2] shows Partitions interacting with Producers and Consumers. You can see that `Topic A` is composed of one Partition operating on one Broker, and `Topic B` is composed of 3 Partitions operating on multiple Brokers.

Producer sends messages to be sent as Records to Kafka, and Kafka stores the received Records sequentially in Partitions. When storing Records, Kafka assigns and manages **Offset**, which represents the unique position of the Record. Separately from Producers, Consumers start from the beginning of the Partition and read Records sequentially while increasing the **Consumer Offset**. Here, Consumer Offset means the Offset of the last Record in the Partition that the Consumer has finished processing, and is stored and managed in Kafka's internal Topic `__consumer_offsets`. For example, in [Figure 2], for `Partition 0` of `Topic A`, the Consumer Offset of `Consumer Group A` is `6`, and the Consumer Offset of `Consumer Group B` is `4`.

Partitions exist on **Disk**, not in Memory, for Record retention. Disk generally has lower Read/Write performance compared to Memory, and especially, Random Read/Write performance is much lower for Disk compared to Memory. However, for Sequential Read/Write, Disk performance does not significantly lag behind Memory performance, so Kafka is designed to use Sequential Read/Write as much as possible when using Partitions.

Also, Kafka is designed so that Records in the Kernel's Disk Cache (Page Cache) are directly copied to the Kernel's Socket Buffer without going through Kafka, minimizing Copy Overhead that occurs when delivering Records to Consumers through the Network. Partitions are not actually stored on Disk as a single file, but are divided and stored in units called **Segments**. The default size of a Segment is 1GB.

### 1.3. Producer

#### 1.3.1. Producer Partitioner

{{< table caption="[Table 3] Producer Default Partitioner" >}}
| Key | Partition | Description |
|---|---|---|
| X | X | Before Kafka 2.4 Version : Partition is determined using Round-robin method for each Record. After Kafka 2.4 Version : Partition is determined by distributing Partitions as evenly as possible in Record Batch units. (Sticky Partitioner) |
| O | X | Partition is determined using a Hashing function based on Key. |
| X | O | Stored in the specified Partition, and Partitioner is not used. |
| O | O | Stored in the specified Partition, and Partitioner is not used. |
{{< /table >}}

When multiple Partitions exist in a Topic, Partitioner built into Producer determines which Partition to send Records to. When Partitioner is not specified in Producer, **Default Partitioner** is used by default. [Table 3] shows the operation method of Default Partitioner. Default Partitioner, when Key and Partition are not specified in Records, determines Partition using Round-robin method for each Record before Kafka 2.4 Version, and uses **Sticky Partitioner** method that distributes Partitions as evenly as possible in Batch units after Kafka 2.4 Version.

When only Key is specified in Records, Partition is determined using a Hashing function, and when Partition is specified in Records, Records are stored in the specified Partition regardless of Key. In this case, Partitioner is not used. When Key or Partition is specified, Records may concentrate on specific Partitions, so it is important to set appropriate Key or Partition. In addition to Default Partitioner, Custom Partitioner can be used to allow users to implement and use their own Partitioner.

#### 1.3.2. Producer Buffer

Producer Buffer means the Memory space where Producer temporarily stores Records before sending them. It is used to prevent Record loss when Producer generates many Records and Kafka Broker temporarily cannot receive them, or when Record cannot be sent due to Kafka Broker failure. The following Producer Buffer-related settings exist.

* `buffer.memory` : Sets the maximum size (Bytes) of Producer Buffer. The default value is `32MB`.
* `max.block.ms` : Sets the maximum time (ms) that Producer's `send()` Method can be blocked when Buffer is full. If Buffer remains full even after `max.block.ms` time has passed, Producer's `send()` Method throws an Exception. The default value is `60000ms`.

#### 1.3.3. Producer Batch

Kafka provides Batch functionality where Producer sends multiple Records at once so that Producer can efficiently send large amounts of Records. Generally, Batch functionality is often utilized. The following Producer Batch-related settings exist.

* `batch.size` : Sets the maximum Record size (Bytes) that Producer can send at once. The default value is `16384B`.
* `linger.ms` : Sets the maximum time (ms) that Producer can wait to send in Batch units. The default value is `0ms`, which does not mean that Batch functionality is not used, but means that Batch functionality is used with a minimum wait time.

#### 1.3.4. Producer ACK

Kafka provides ACK-related options for Producers. Producers can use ACK to check whether the Records they sent were properly delivered to Brokers, as well as minimize Record loss. It provides three options: `0`, `1`, and `all`. Each Producer can set a different ACK option.

* `0` : Producer does not check for ACK.
* `1` : Producer waits for ACK. Here, ACK means that the Record has been delivered to only one Kafka Broker. Therefore, if the Kafka Broker that received the Record from the Producer dies before copying the Record to another Kafka Broker according to Replica settings, Record loss can occur. This is the default setting.
* `all (-1)` : Producer waits for ACK. Here, ACK means that the Record has been copied to as many Kafka Brokers as the configured Replicas. Therefore, even if the Kafka Broker that received the Record from the Producer dies, the Record is maintained if Kafka Brokers that have the copied Record are alive.

### 1.4. Consumer

#### 1.4.1. Consumer Group

Consumer Group groups multiple Consumers so that multiple Consumers can process one Topic simultaneously, increasing the availability and message throughput of Consumers. In [Figure 1], you can see that `Consumer Group A` has one Consumer, `Consumer Group B` has 2 Consumers, and `Consumer Group C` has 3 Consumers.

{{< figure caption="[Figure 3] Kafka Architecture with Wrong Consumer Group" src="images/kafka-architecture-wrong-consumer-group.png" width="1000px" >}}

However, having more Consumers does not necessarily increase throughput, and an appropriate number of Partitions for Topics is also important. In [Figure 1], since the number of Consumers matches the number of Partitions, all Consumers can process messages efficiently, but as in [Figure 3], when the number of Partitions and Consumers differ, all Consumers cannot process messages efficiently.

Partitions and Consumers must have an **N:1** relationship. Therefore, as with `Consumer Group B`, when the number of Partitions is less than the number of Consumers, idle Consumers occur. On the other hand, as with `Consumer Group A` or `Consumer Group C`, when the number of Partitions is greater than the number of Consumers, there is no problem with operation, but some Consumers process more messages, causing throughput asymmetry. For this reason, it is best to set the number of Partitions and Consumers to be exactly the same.

#### 1.4.2. Consumer Batch

Consumers provide Batch functionality to fetch multiple Records at once, similar to Producers. The following Consumer Batch-related settings exist.

* `fetch.min.bytes` : Sets the minimum Record size (Bytes) that Consumer can fetch at once. If only Records smaller than the `fetch.min.bytes` setting value exist in the Topic, Kafka Broker does not return Records, so Consumer's `poll()` Method blocks and waits for up to `fetch.max.wait.ms` time. The default value is `1B`.
* `fetch.max.bytes` : Sets the maximum Record size (Bytes) that Consumer can fetch at once. The default value is `5242880B (50MB)`.
* `fetch.max.wait.ms` : Sets the maximum time (ms) that Consumer can fetch at once. The default value is `500ms`.
* `max.partition.fetch.bytes` : Sets the maximum Partition size (Bytes) that Consumer can receive at once. The default value is `1048576B (1MB)`.
* `max.poll.records` : Sets the maximum number of Records that Consumer can receive at once. The default value is `500`.

#### 1.4.3. Consumer ACK

Kafka does not provide separate ACK options for Consumers. Consumers deliver the Offset of Records that have been processed to Kafka Broker, and **the Offset of Records delivered by Consumers performs the role of ACK to Kafka Broker**. Generally, Apps performing the Consumer role use the Auto Commit feature (`enable.auto.commit=true`) of the Consumer Library to deliver the Offset of received Records to Kafka Broker at certain intervals without App intervention, or directly deliver the Offset after completing Record processing in the App.

### 1.5. Replication, Failover

Even when using multiple Brokers and Partitions, if Replication is not applied, Record loss cannot be prevented when some Brokers die. For example, in [Figure 1], if `Broker C` dies, Record loss occurs for all Records of `Topic B` and `Partition 0` of `Topic C`. To prevent such Record loss, it is necessary to apply Replication to duplicate Partitions.

{{< figure caption="[Figure 4] Kafka Replication" src="images/kafka-replication.png" width="1000px" >}}

[Figure 4] shows Kafka with Replication applied from [Figure 1]. `Topic A` and `Topic B` are set to Replica `2`, and `Topic C` is set to Replica `3`. Therefore, `Topic A` and `Topic B` have one duplicate Partition, and `Topic C` has two duplicate Partitions.

The original Partition is called **Leader Partition**, and duplicate Partitions are called **Follower Partitions**. Producers and Consumers use only Leader Partitions and do not directly use Follower Partitions. Follower Partitions are used only for Failover when Leader Partitions cannot be used due to failure. Replication can be set separately for each Topic.

The Replication synchronization method can use both Sync and Async methods depending on the Producer's ACK settings. Only in the case of `all (-1)` ACK settings, since Producer receives ACK only after Record replication is complete, from a Replication perspective, `all (-1)` corresponds to **Sync method**. On the other hand, in the case of `0`, `1` ACK settings, since Producer receives ACK even if Record is not replicated, from a Replication perspective, `0`, `1` corresponds to **Async method**, and Record loss can occur when performing Failover.

{{< figure caption="[Figure 5] Kafka Failover" src="images/kafka-replication-failover.png" width="1000px" >}}

[Figure 5] shows the Failover operation when `Broker C` dies in [Figure 4]. You can see that the Leader Partition of `Topic B` moves to `Broker A`, and the Leader Partition of `Topic C` moves to `Broker B`. Kafka promotes an arbitrary Follower Partition among Follower Partitions that are completely synchronized with Leader Partition (**ISR**, In-Sync Replicas) to Leader Partition. Partitions of the failed Broker become **Offline** status, and when the Broker recovers, they become Follower Partitions.

Even if Replication of a Record is complete, due to Broker failure, Producer may not receive ACK. This means that Producer can send Records stored in Partitions redundantly, meaning that Record duplication can occur. To prevent such Record duplication, **Kafka's idempotence** setting (`enable.idempotence`) can be used to prevent Record duplication.

Consumers may also send the Offset of Records that have been processed to Broker, but may not receive ACK due to Broker failure. Therefore, Consumers can also receive the same Record redundantly, and Consumers must implement idempotence logic so that there is no problem even if they receive the same Record, or use Kafka Transaction to prevent processing the same Record.

## 2. References

* Kafka : [https://fizalihsan.github.io/technology/bigdata-frameworks.html](https://fizalihsan.github.io/technology/bigdata-frameworks.html)
* Kafka : [https://en.wikipedia.org/wiki/Apache-Kafka](https://en.wikipedia.org/wiki/Apache-Kafka)
* Kafka : [https://www.quora.com/What-is-Apache-Kafka](https://www.quora.com/What-is-Apache-Kafka)
* Kafka : [https://sookocheff.com/post/kafka/kafka-in-a-nutshell/](https://sookocheff.com/post/kafka/kafka-in-a-nutshell/)
* Kafka ACK : [https://medium.freecodecamp.org/what-makes-apache-kafka-so-fast-a8d4f94ab145](https://medium.freecodecamp.org/what-makes-apache-kafka-so-fast-a8d4f94ab145)
* [https://www.popit.kr/kafka-%EC%9A%B4%EC%98%81%EC%9E%90%EA%B0%80-%EB%A7%90%ED%95%98%EB%8A%94-producer-acks/](https://www.popit.kr/kafka-%EC%9A%B4%EC%98%81%EC%9E%90%EA%B0%80-%EB%A7%90%ED%95%98%EB%8A%94-producer-acks/)
* Kafka Record : [https://lankydan.dev/intro-to-kafka-consumers](https://lankydan.dev/intro-to-kafka-consumers)
* Kafka Record : [https://zzzzseong.tistory.com/107](https://zzzzseong.tistory.com/107)
* Kafka Buffer, Batch : [https://stackoverflow.com/questions/49649241/apache-kafka-batch-size-vs-buffer-memory](https://stackoverflow.com/questions/49649241/apache-kafka-batch-size-vs-buffer-memory)
* Kafka Buffer, Batch : [https://medium.com/%40charchitpatidar/optimizing-kafka-consumer-for-high-throughput-313a91438f92](https://medium.com/%40charchitpatidar/optimizing-kafka-consumer-for-high-throughput-313a91438f92)

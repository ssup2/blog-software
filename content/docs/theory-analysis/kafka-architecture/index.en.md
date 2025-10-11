---
title: Kafka Architecture
---

This document analyzes the Architecture of Kafka, a distributed Message Queue.

## 1. Kafka Architecture

Kafka is a distributed Message Queue based on Publish-subscribe. Kafka is often used as an **Event Bus** for Event Driven Architecture because it has the characteristic of storing received Messages for a specific period and allowing reprocessing. It also has the characteristic of high Message throughput, and based on this, it is also widely used as a **Data Stream Queue** for big data processing platforms like Storm.

{{< figure caption="[Figure 1] Kafka Architecture" src="images/kafka-architecture.png" width="750px" >}}

[Figure 1] shows the components of Kafka.

* **Kafka Broker**: This is the core Server of Kafka that receives, manages, and transmits Messages. Kafka Brokers generally operate as a Cluster on multiple Nodes for Load Balancing and HA (High Availability).
* **Zookeeper**: It identifies the operational status of each Kafka Broker that forms the Cluster and delivers status information to Producers and Consumers. Zookeeper also serves as a storage that stores information necessary for Message management.
* **Topic**: This is the unit for managing Messages. Topics are divided into smaller units called **Partitions**, and Kafka increases Message throughput by using multiple Partitions.
* **Producer**: This refers to an App that sends (Publishes) Messages to Topics.
* **Consumer**: This refers to an App that receives Messages from Topics.
* **Consumer Group**: As the name suggests, it groups multiple Consumers, and Kafka increases Consumer availability and Message throughput using Consumer Groups.

[Figure 1] also shows the process of delivering Messages in Kafka. When a Producer sends (Publishes) a Message to a specific Topic, the Kafka Cluster sends the Message received from the Producer to all Consumer Groups that are subscribing to that Topic. In [Figure 1], since `Consumer Group B` and `Consumer Group C` are subscribing to `Topic B`, the Kafka Broker delivers the Message sent by `Producer A` to `Topic B` to `Consumer Group B` and `Consumer Group C`.

### 1.1. Partition

{{< figure caption="[Figure 2] Kafka Partition" src="images/kafka-partition.png" width="750px" >}}

**Partition** is a unit for distributing one Topic to multiple Kafka Brokers within the Kafka Cluster to increase Message throughput through parallel processing, and it serves as a Queue that stores Messages sequentially. [Figure 2] shows in detail the Partition that interacts with Producers and Consumers. Messages sent by Producers are stored sequentially at the end of the Partition. At this time, the Message ID increases sequentially like an Array Index. This Message ID is called **Offset** in Kafka.

Separately from Producers, Consumers start from the front of the Partition and read Messages sequentially while increasing the **Consumer Offset**. Here, Consumer Offset refers to the Offset of the last Message in the Partition that the Consumer has completed processing. Therefore, Consumer Offset is stored by the Kafka Broker but is changed by Consumer requests. Consumer Offset is stored in the Kafka Broker for each Partition and Consumer Group. In [Figure 2], for `Partition 0` of `Topic B`, the Consumer Offset of `Consumer Group B` is `6`, and the Consumer Offset of `Consumer Group C` is `4`.

The number of Partitions can be set differently for each Topic. Generally, each Partition is placed on different Kafka Brokers to process Messages in parallel. In [Figure 2], since `Topic C` consists of 3 Partitions, each Partition is distributed to 3 different Kafka Brokers. Since `Topic C` uses 3 Kafka Brokers, it can process Messages up to 3 times faster than `Topic B` which uses only one Topic. However, using 3 Partitions means dividing Messages into 3 Queues for storage, so the order of Messages sent by Producers and the order of Messages received by Consumers may differ. `Topic B` maintains Message order because it uses only one Partition.

When a Topic has multiple Partitions, Producers basically select the Partition to deliver Messages using the **Round-robin** method. If a different Partition selection algorithm is needed, Producer developers can develop and apply Partition selection algorithms directly through the Interface provided by Kafka. For Consumers, there are **Sync method** that delivers the changed Consumer Offset to the Kafka Broker each time a Message is processed, and **Async method** that processes multiple Messages at once and delivers only the Offset of the last Message to the Kafka Broker. Generally, Async method is used to increase Message throughput.

Partitions exist on **Disk** rather than Memory for Message preservation. Disks generally have lower Read/Write performance compared to Memory, and especially Random Read/Write performance is much lower for Disks compared to Memory. However, for Sequential Read/Write, Disk performance does not significantly drop compared to Memory performance, so Kafka is designed to use Sequential Read/Write as much as possible when using Partitions. Also, Kafka allows Messages in the Kernel's Disk Cache (Page Cache) to be copied directly to the Kernel's Socket Buffer without going through Kafka, minimizing Copy Overhead that occurs when delivering Messages to Consumers through the Network. Partitions are not actually stored as a single file on Disk but are divided and stored in units called **Segments**. The default size of a Segment is 1GB.

### 1.2. Consumer Group

Consumer Groups bundle multiple Consumers to allow multiple Consumers to process one Topic simultaneously. In the first figure, Consumer Group C is subscribing to Topic C. Since Consumer Group C has 2 Consumers, Messages from Topic C can be processed in parallel by 2 Consumers. However, to increase the efficiency of Consumer Groups, the number of Partitions of the Topic that the Consumer Group subscribes to is important.

{{< figure caption="[Figure 3] Relationship between Partition and Consumer Group" src="images/kafka-partition-consumer.png" width="750px" >}}

[Figure 3] shows the relationship diagram according to the number of Partitions in the same Topic and the number of Consumers in the same Consumer Group. The relationship between Partition and Consumer is N:1. Consumers in the same Consumer Group cannot use one Partition simultaneously. In other words, if there are more Consumers than Partitions, there will be Consumers that do not process Messages. Therefore, when using Consumer Groups, the number of Partitions of the Topic must also be considered together.

Each Consumer Group has a **Consumer Leader** that manages the Consumers of the Consumer Group. Also, the Consumer Leader performs the task of mapping Consumers and Partitions in cooperation with the Kafka Broker. Consumer and Partition mapping is performed when various Events occur, such as when some Consumers of the Consumer Group die, when Partitions are added, or when Consumers are added to the Consumer Group.

### 1.3. ACK

Kafka provides ACK-related Options for Producers. Producers can not only check whether their sent Messages have been properly delivered to Brokers using ACK but also minimize Message loss. It provides 3 Options: `0`, `1`, and `all`. Each Producer can set different ACK Options.

* `0`: Producers do not check ACK.
* `1`: Producers wait for ACK. Here, ACK means that the Message has been delivered to only one Kafka Broker. Therefore, if the Kafka Broker that received the Message from the Producer dies before copying the Message to other Kafka Brokers according to Replica settings, Message loss may occur. This is the default setting.
* `all` (-1): Producers wait for ACK. Here, ACK means that the Message has been copied to multiple Kafka Brokers as much as the set Replicas. Therefore, even if the Kafka Broker that received the Message from the Producer dies, the Message is maintained if the Kafka Broker that has the copied Message is alive.

Kafka does not provide separate ACK Options for Consumers. As mentioned above, Consumers deliver the Offset of processed Messages to the Kafka Broker. In other words, **the Offset of Messages delivered by Consumers serves as ACK to the Kafka Broker**. Generally, Apps that perform Consumer roles use the Auto Commit function (`enable.auto.commit=true`) of the Consumer Library to deliver the Offset of received Messages to the Kafka Broker at specific intervals without App intervention, or use a method of directly delivering the Offset after completing Message processing in the App.

### 1.4. Message Retention

Kafka preserves Messages stored in Partitions according to certain criteria, which is called **Message Retention** policy in Kafka. The Message Retention policy first has a method of preserving only Messages within a specific period. If the period is set to 7 days, Messages are preserved for 7 days after arriving at Kafka, and preservation is not guaranteed after that. Second, there is a method of preserving so that the Partition size does not exceed a specific capacity. If the Partition becomes larger than the set capacity due to Message Write, it maintains the Partition capacity by deleting Messages from the front of the Partition.

## 2. References

* [https://fizalihsan.github.io/technology/bigdata-frameworks.html](https://fizalihsan.github.io/technology/bigdata-frameworks.html)
* [https://en.wikipedia.org/wiki/Apache-Kafka](https://en.wikipedia.org/wiki/Apache-Kafka)
* [https://www.quora.com/What-is-Apache-Kafka](https://www.quora.com/What-is-Apache-Kafka)
* [https://sookocheff.com/post/kafka/kafka-in-a-nutshell/](https://sookocheff.com/post/kafka/kafka-in-a-nutshell/)
* [https://epicdevs.com/17](https://epicdevs.com/17)
* [https://medium.freecodecamp.org/what-makes-apache-kafka-so-fast-a8d4f94ab145](https://medium.freecodecamp.org/what-makes-apache-kafka-so-fast-a8d4f94ab145)
* [https://www.popit.kr/kafka-%EC%9A%B4%EC%98%81%EC%9E%90%EA%B0%80-%EB%A7%90%ED%95%98%EB%8A%94-producer-acks/](https://www.popit.kr/kafka-%EC%9A%B4%EC%98%81%EC%9E%90%EA%B0%80-%EB%A7%90%ED%95%98%EB%8A%94-producer-acks/)

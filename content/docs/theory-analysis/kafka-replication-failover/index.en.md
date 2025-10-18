---
title: Kafka Replication, Failover
---

This document analyzes Kafka Replication and Failover techniques.

## 1. Kafka Replication

{{< figure caption="[Figure 1] Kafka before Replication" src="images/kafka.png" width="900px" >}}

Kafka configures multiple Brokers and distributes Partitions to each Broker as much as possible to increase Message throughput. However, even when using multiple Brokers and Partitions, if Replication is not applied, Message loss cannot be prevented when some Brokers die. [Figure 1] shows the Kafka Cluster before applying Replication. Since Replication is not applied, Message loss will inevitably occur when any Broker dies. For example, if `Broker C` dies, all Messages of `Topic B` and Messages of `Partition 2` of `Topic C` will be lost.

{{< figure caption="[Figure 2] Kafka after Replication" src="images/kafka-replication.png" width="900px" >}}

Replication can **set a separate Replica count for each Topic**. [Figure 2] shows the Kafka Cluster after applying Replication to the Kafka Topics in [Figure 1]. `Topic A` and `Topic B` are set to Replica `2`, and `Topic C` is set to Replica `3`. Accordingly, `Topic A` and `Topic B` have one Leader Partition and one Follower Partition, and `Topic C` has one Leader Partition and two Follower Partitions.

In Kafka, the Partition used by Producers and Consumers is called **Leader Partition**, and the remaining replicas are called **Follower Partition**. Even when Replication is applied, Producers and Consumers only use Leader Partitions and do not directly use Follower Partitions. Follower Partitions are only used for Failover when Leader Partitions cannot be used due to failures.

The Replication synchronization method can use both Sync and Async methods depending on the Producer's ACK settings. When the Producer's ACK setting is `0`, the Producer sends Messages and does not wait for ACK from the Broker, and when it is `1`, the Producer receives ACK from the Broker only when Message transmission to the Leader Partition is completed. Therefore, from a Replication perspective, `0` and `1` correspond to **Async methods**. On the other hand, when the Producer's ACK setting is `all`, the Producer receives ACK from the Broker only when Message transmission to the Leader Partition is completed. Therefore, from a Replication perspective, `all` corresponds to **Sync methods**.

## 2. Kafka Failover

{{< figure caption="[Figure 3] Kafka after Failover" src="images/kafka-failover.png" width="900px" >}}

Failover refers to the process where a Follower Partition becomes a Leader Partition when the Leader Partition cannot be used due to failure. [Figure 3] shows the Failover operation when `Broker C` dies in the state of [Figure 2]. It can be seen that the Leader Partition of `Topic B` moves to `Broker B`, and the Leader Partition of `Topic C` moves to `Broker A`.

Kafka promotes an arbitrary Follower Partition to Leader Partition among Follower Partitions that are completely synchronized with the Leader Partition (ISR, In-Sync Replicas). Producers and Consumers receive information about the changed Leader Partition from the running Kafka Broker and operate accordingly. When Producers use ACK settings of `0` or `1`, Replication is not guaranteed, so Messages sent by Producers may not be replicated to the new Leader Partition. On the other hand, when using ACK settings of `all`, Replication is guaranteed, so Messages sent by Producers exist in the new Leader Partition and Message loss does not occur.

Messages may have completed Replication but Producers may not receive ACK due to Broker failure. This means that Producers may send Messages stored in Partitions redundantly, which means Message duplication may occur. To prevent such Message duplication, **Kafka's idempotency** setting (`enable.idempotence`) can be used to prevent Message duplication. Consumers may also not receive ACK due to Broker failure even though they sent the Offset of processed Messages to the Broker. Therefore, Consumers may also receive the same Message redundantly, and Consumers must implement idempotency Logic to ensure that there are no problems even when receiving the same Message.

## 3. References

* [https://www.popit.kr/kafka-%EC%9A%B4%EC%98%81%EC%9E%90%EA%B0%80-%EB%A7%90%ED%95%98%EB%8A%94-topic-replication/](https://www.popit.kr/kafka-%EC%9A%B4%EC%98%81%EC%9E%90%EA%B0%80-%EB%A7%90%ED%95%98%EB%8A%94-topic-replication/)
* [https://www.tutorialspoint.com/apache-kafka/apache-kafka-cluster-architecture.htm](https://www.tutorialspoint.com/apache-kafka/apache-kafka-cluster-architecture.htm)
* [https://medium.com/@durgaswaroop/a-practical-introduction-to-kafka-storage-internals-d5b544f6925f](https://medium.com/@durgaswaroop/a-practical-introduction-to-kafka-storage-internals-d5b544f6925f)
* [https://www.linkedin.com/pulse/partitions-rebalance-kafka-raghunandan-gupta/](https://www.linkedin.com/pulse/partitions-rebalance-kafka-raghunandan-gupta/)
* [https://grokbase.com/t/kafka/users/1663h6ydyz/kafka-behind-a-load-balancer](https://grokbase.com/t/kafka/users/1663h6ydyz/kafka-behind-a-load-balancer)

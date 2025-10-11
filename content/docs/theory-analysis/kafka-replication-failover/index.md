---
title: Kafka Replication, Failover
---

Kafka의 Replication, Failover 분석한다.

## 1. Kafka Replication

{{< figure caption="[Figure 1] Kafka before Replication" src="images/kafka-cluster.png" width="900px" >}}

{{< figure caption="[Figure 2] Kafka after Replication" src="images/kafka-cluster-replication.png" width="900px" >}}

Kafka는 다수의 Broker를 구성하고 Partition을 최대한 각 Broker에 분산시켜 Message 처리량을 높인다. 하지만 다수의 Broker와 Partition을 이용하여도 Replication이 적용되지 않은 상태에서는 일부 Broker가 죽으면 Message 손실을 막을 수 없다. [Figure 1]은 Replication 적용전의 Kafka Cluster를 나타내고 있고, [Figure 2]는 Kafka Replication을 적용한 후의 Kafka Cluster를 나타내고 있다. `Topic A`와 `Topic B`는 Replica 2, `Topic C`는 Replica 3으로 설정한 상태를 나타내고 있다. Replication을 적용하지 않은 상태에서는 `Broker C`가 죽을경우 `Topic B`의 모든 Message와 `Topic C`의 `Partition 2`의 Message 손실이 발생하지만, Replication을 적용한 상태에서는 복제된 Partition을 이용하여 Message 손실을 방지할 수 있다.

Kafka에서는 Producer와 Consumer가 이용하는 Partition은 **Leader Partition**라고 부르며 나머지 복재본은 **Follower Partition**이라고 부른다. Replication이 적용되어도 Producer와 Consumer는 Leader Partition만을 이용하며, Follower Partition을 직접 이용하지 않는다. Follower Partition은 오직 Leader Partition이 장애로 인해서 이용하지 못할경우 Failover를 위해서 이용된다.

Replication 동기 방식은 Producer의 ACK 설정에 따라서 Sync 방식, Async 방식 둘다 이용이 가능하다. Producer의 ACK 설정이 `0`일 경우 Producer는 Message를 전송하고 Broker로부터 ACK를 기다리지 않고, `1`일 경우 Producer는 Leader Partition에게만 Message 전송이 완료되면 Broker로부터 ACK를 수신한다. 따라서 Replcation 관점에서 `0`, `1`은 Async 방식에 해당된다. 반면에 Producer의 ACK 설정이 `all`일 경우에는 Broker로부터 Leader Partition에게 Message 전송이 완료되면 Broker로부터 ACK를 수신한다. 따라서 Replcation 관점에서 `all`은 Sync 방식에 해당된다.

## 2. Kafka Failover

## 3. 참조

* [https://www.popit.kr/kafka-%EC%9A%B4%EC%98%81%EC%9E%90%EA%B0%80-%EB%A7%90%ED%95%98%EB%8A%94-topic-replication/](https://www.popit.kr/kafka-%EC%9A%B4%EC%98%81%EC%9E%90%EA%B0%80-%EB%A7%90%ED%95%98%EB%8A%94-topic-replication/)
* [https://www.tutorialspoint.com/apache-kafka/apache-kafka-cluster-architecture.htm](https://www.tutorialspoint.com/apache-kafka/apache-kafka-cluster-architecture.htm)
* [https://medium.com/@durgaswaroop/a-practical-introduction-to-kafka-storage-internals-d5b544f6925f](https://medium.com/@durgaswaroop/a-practical-introduction-to-kafka-storage-internals-d5b544f6925f)
* [https://www.linkedin.com/pulse/partitions-rebalance-kafka-raghunandan-gupta/](https://www.linkedin.com/pulse/partitions-rebalance-kafka-raghunandan-gupta/)
* [https://grokbase.com/t/kafka/users/1663h6ydyz/kafka-behind-a-load-balancer](https://grokbase.com/t/kafka/users/1663h6ydyz/kafka-behind-a-load-balancer)

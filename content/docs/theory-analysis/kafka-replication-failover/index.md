---
title: Kafka Replication, Failover
---

Kafka의 Replication, Failover 분석한다.

## 1. Kafka Replication

{{< figure caption="[Figure 1] Kafka before Replication" src="images/kafka.png" width="900px" >}}

{{< figure caption="[Figure 2] Kafka after Replication" src="images/kafka-replication.png" width="900px" >}}

Kafka는 다수의 Broker를 구성하고 Partition을 최대한 각 Broker에 분산시켜 Message 처리량을 높인다. 하지만 다수의 Broker와 Partition을 이용하여도 Replication이 적용되지 않은 상태에서는 일부 Broker가 죽으면 Message 손실을 막을 수 없다. [Figure 1]은 Replication 적용전의 Kafka Cluster를 나타내고 있고, [Figure 2]는 Kafka Replication을 적용한 후의 Kafka Cluster를 나타내고 있다. `Topic A`와 `Topic B`는 Replica 2, `Topic C`는 Replica 3으로 설정한 상태를 나타내고 있다. Replication을 적용하지 않은 상태에서는 `Broker C`가 죽을경우 `Topic B`의 모든 Message와 `Topic C`의 `Partition 2`의 Message 손실이 발생하지만, Replication을 적용한 상태에서는 복제된 Partition을 이용하여 Message 손실을 방지할 수 있다.

Kafka에서는 Producer와 Consumer가 이용하는 Partition은 **Leader Partition**라고 부르며 나머지 복재본은 **Follower Partition**이라고 부른다. Replication이 적용되어도 Producer와 Consumer는 Leader Partition만을 이용하며, Follower Partition을 직접 이용하지 않는다. Follower Partition은 오직 Leader Partition이 장애로 인해서 이용하지 못할경우 Failover를 위해서 이용된다.

Replication 동기 방식은 Producer의 ACK 설정에 따라서 Sync 방식, Async 방식 둘다 이용이 가능하다. Producer의 ACK 설정이 `0`일 경우 Producer는 Message를 전송하고 Broker로부터 ACK를 기다리지 않고, `1`일 경우 Producer는 Leader Partition에게만 Message 전송이 완료되면 Broker로부터 ACK를 수신한다. 따라서 Replcation 관점에서 `0`, `1`은 Async 방식에 해당된다. 반면에 Producer의 ACK 설정이 `all`일 경우에는 Broker로부터 Leader Partition에게 Message 전송이 완료되면 Broker로부터 ACK를 수신한다. 따라서 Replcation 관점에서 `all`은 Sync 방식에 해당된다.

## 2. Kafka Failover

{{< figure caption="[Figure 3] Kafka after Failover" src="images/kafka-failover.png" width="900px" >}}

Failover는 Leader Partition이 장애로 인해서 이용하지 못할경우 Follower Partition이 Leader Partition으로 넘어가는 과정을 의미한다. [Figure 3]은 [Figure 2]의 상태에서 `Broker C`가 죽을경우 동작하는 Failover의 모습을 나타내고 있다. `Topic B`의 Leader Partition이 `Broker B`로 넘어가고, `Topic C`의 Leader Partition이 `Broker A`로 넘어가는 것을 확인할 수 있다.

Kafka는 Leader Partition과 완전히 동기화된 Follower Partition (ISR, In-Sync Replicas)중에서 임의의 Follower Partition을 Leader Partition으로 승격한다. Producer와 Consumer는 변경된 Leader Partition 정보를 동작하고 있는 Kafka Broker로부터 받아서 동작하게 된다. Producer가 `0` 또는 `1`의 ACK 설정을 이용할 경우 Replication이 보장되지 않기 때문에, 새로운 Leader Partition에는 Producer가 전송했던 Message가 복제되지 않을 수 있다. 반면에 `all`의 ACK 설정을 이용할 경우에는 Replication이 보장되기 때문에, 새로운 Leader Partition에는 Producer가 전송했던 Message가 존재하며 Message 손실이 발생하지 않는다.

Message가 Replication이 완료되었지만 Broker의 장애로 Producer는 ACK만 수신하지 못할 수 있다. 이는 Producer가 Parition에 저장된 Message를 중복해서 전송할 수 있다는걸 의미하며, Message 중복이 발생할 수 있다는걸 의미한다. 이러한 Message 중복을 방지하기 위해서 **Kafka의 멱등성** 설정 (`enable.idempotence`)을 통해서 Message 중복을 방지할 수 있다. Consumer도 처리가 완료된 Message의 Offset을 Broker에게 전송했지만 Broker의 장애로 ACK를 수신하지 못할 수 있다. 따라서 Consumer도 동일한 Message를 중복해서 받을 수 있으며, Consumer는 반드시 동일한 Message를 받더라도 문제가 없도록 멱등성 Logic을 구현해야 한다.

## 3. 참조

* [https://www.popit.kr/kafka-%EC%9A%B4%EC%98%81%EC%9E%90%EA%B0%80-%EB%A7%90%ED%95%98%EB%8A%94-topic-replication/](https://www.popit.kr/kafka-%EC%9A%B4%EC%98%81%EC%9E%90%EA%B0%80-%EB%A7%90%ED%95%98%EB%8A%94-topic-replication/)
* [https://www.tutorialspoint.com/apache-kafka/apache-kafka-cluster-architecture.htm](https://www.tutorialspoint.com/apache-kafka/apache-kafka-cluster-architecture.htm)
* [https://medium.com/@durgaswaroop/a-practical-introduction-to-kafka-storage-internals-d5b544f6925f](https://medium.com/@durgaswaroop/a-practical-introduction-to-kafka-storage-internals-d5b544f6925f)
* [https://www.linkedin.com/pulse/partitions-rebalance-kafka-raghunandan-gupta/](https://www.linkedin.com/pulse/partitions-rebalance-kafka-raghunandan-gupta/)
* [https://grokbase.com/t/kafka/users/1663h6ydyz/kafka-behind-a-load-balancer](https://grokbase.com/t/kafka/users/1663h6ydyz/kafka-behind-a-load-balancer)

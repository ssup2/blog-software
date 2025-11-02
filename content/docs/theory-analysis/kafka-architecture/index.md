---
title: Kafka Architecture
---

분산 Message Queue인 kafka의 Architecture를 분석한다.

## 1. Kafka Architecture

Kafka는 Publish-subscribe 기반의 분산 Message Queue이다. Kafka는 수신한 Message를 특정 기간동안 저장하고 재처리가 가능하다는 특징 때문에 일반적으로 Event Driven Architecture의 **Event Bus**로 많이 활용된다. 또한 높은 Message 처리량을 갖는 특징도 갖고 있으며, 이를 기반으로 Storm 같은 빅데이터 처리 Platform의 **Data Stream Queue**로도 많이 이용되고 있다.

{{< figure caption="[Figure 1] Kafka Architecture" src="images/kafka-architecture.png" width="1000px" >}}

[Figure 1]은 Kafka의 구성요소와 함께 Kafka에서 Message를 전달하는 과정을 나타내고 있다. **Producer**가 특정 **Topic**으로 Message를 전송(Publish)하면, 해당 Topic을 구독(Subscribe)하고 있는 모든 **Consumer Group**의 **Consumer**는 해당 Topic의 Message 존재 여부를 확인하고, Message가 있을경우 Message를 가져온다. 각 구성 요소의 역할은 다음과 같다.

* **Kafka Broker** : Message를 수신, 관리, 전송하는 Kafka의 핵심 Server이다. Kafka Broker는 일반적으로 Load Balancing 및 HA (High Availability)를 위해서 다수의 Node 위에서 **Kafka Cluster**를 이루어 동작한다.
* **Zookeeper** : Kafka Cluster의 Metadata를 저장하기 위한 고가용성을 제공하는 저장소 역할을 수행한다. Kafka Broker와 같이 다수의 Node 위에서 Cluster를 이루어 동작한다. Kafka 2.8 Version 이후에는 Raft 알고리즘을 기반으로 동작하는 Kafka Broker가 스스로 저장소 역할을 수행하는 **KRaft Mode**를 지원한다. KRaft Mode로 동작하는 경우 Zookeeper를 별도로 이용하지 않는다.
* **Topic** : Message를 관리하는 단위이다. Topic은 다시 **Partition**이라는 작은 단위로 쪼개지며, Kafka는 다수의 Partiton을 이용하여 Message 처리량을 높인다. Partition은 다시 **Record**의 집합으로 구성되며, 여기서 Record는 Kafka에서 정의하는 Message 단위를 의미한다.
* **Producer** : Topic에게 Message를 전송(**Publish**)하는 App을 의미한다.
* **Consumer** : Topic으로부터 Message를 전달 받는(**Subscribe**) App을 의미한다. Consumer는 Poll 함수를 통해서 **Polling 방식**으로 Message의 존재 여부를 확인하고, Message가 있을경우 Message를 가져온다. 즉 Message는 Topic에서 Consumer로 전달되지만, Message를 가져오는 주체는 Consumer이다.
* **Consumer Group** : 의미 그대로 다수의 Consumer 묶는 역할을 수행하며, Kafka는 Consumer Group을 이용하여 Consumer의 가용성 및 Message 처리량을 높인다.

### 1.1. Record

### 1.2. Consumer Group

Consumer Group은 다수의 Consumer를 묶어 하나의 Topic을 다수의 Consumer가 동시에 처리할 수 있도록 만들어 Consumer의 가용성 및 Message 처리량을 높인다. [Figure 1]에서 `Consumer Group A`는 하나의 Consumer, `Consumer Group B`는 2개의 Consumer, `Consumer Group C`는 3개의 Consumer를 가지고 있는것을 확인할 수 있다.

{{< figure caption="[Figure 3] Kafka Architecture with Wrong Consumer Group" src="images/kafka-architecture-wrong-consumer-group.png" width="1000px" >}}

다만 Consumer의 개수만 많다고 해서 처리량이 높아지는것은 아니며, 적절한 Topic의 Partition의 개수도 중요하다. [Figure 1]에서는 Partition의 개수와 동일하게 Consumer의 개수가 동일하기 때문에 모든 Consumer가 효율적으로 Message를 처리할 수 있지만, [Figure 3] 처럼 Partition의 개수와 Consumer의 개수가 다른 경우에는 모든 Consumer가 효율적으로 Message를 처리할 수 없다.

Partition과 Consumer는 반드시 **N:1**의 관계를 가져아한다. 따라서 `Consumer Group B`와 같이 Partition의 개수가 Consumer 개수보다 적은 경우 유휴 Consumer가 발생하게 된다. 반면에 `Consumer Group A` 또는 `Consumer Group C`와 같이 Partition의 개수가 Consumer 개수보다 많은 경우, 동작에는 문제가 없지만 일부 Consumer에 더 많은 Message를 처리하게 되어 처리량 비대칭이 발생하게 된다. 이러한 이유 때문에 Partition의 개수와 Consumer의 개수는 반드시 동일하게 설정하는게 좋다.

### 1.3. Partition, Offset

{{< figure caption="[Figure 4] Kafka Partition" src="images/kafka-partition.png" width="1000px" >}}

Partition은 병렬처리로 Message의 처리량을 높이기 위해서 하나의 Topic을 Kafka Cluster 내부의 다수의 Kafka Broker에게 분산하기 위한 단위이자, Message를 순차적으로 저장하는 Queue 역할을 수행한다. 각 Topic 별로 다른 개수의 Partition을 가질 수 있다. [Figure 4]는 Producer 및 Consumer와 상호작용을 하는 Partition을 나타내고 있다. `Topic A`는 하나의 Broker에서 동작하는 하나의 Partition로 구성되어 있고, `Topic B`는 다수의 Broker에서 동작하는 3개의 Partition으로 구성되어 있는것을 확인할 수 있다.

Producer는 전송할 Message를 **Record**로 전환하여 Partition의 끝에 차례대로 저장한다. 이때 Record의 ID는 Array의 Index처럼 순차적으로 증가한다. 이러한 Record의 ID를 Kafka에서는 **Offset**이라고 한다. Producer와 별개로 Consumer는 Partition의 앞부분부터 시작하여 **Consumer Offset**을 증가시키며 차례대로 Record를 읽는다. 여기서 Consumer Offset은 Consumer가 처리를 완료한 Partition의 가장 마지막 Record의 Offset을 의미한다. Consumer Offset은 각 Partition, Consumer Group 별로 Kafka Broker에 저장된다. 예를들어 [Figure 4]에서 `Topic A`의 `Partition 0`의 경우 `Consumer Group B`의 Consumer Offset은 `6`, `Consumer Group B`의 Consumer Offset은 `4`를 나타내고 있다.

Topic에 다수의 Partition이 존재할 때 Producer는 전송하는 Record에 Key가 존재하지 않을 경우 기본적으로 **Round-robin** 방식으로 Record를 전달할 Partiton 선택한다. 이 경우 Record의 순서가 보장되지는 않지만, 다수의 Partition에 균등하게 Record가 분배된다는 장점을 얻을 수 있다. 반면에 Record에 Key가 존재할 경우 Key를 기반으로 어떤 Partition에 저장될지 결정된다. 따라서 Key를 기준으로는 Record의 순서 보장이 가능하지만, 특정 Partition에만 Record가 쏠리는 문제가 발생할 수 있다.

Partition은 Record 보존을 위해서 Memory가 아닌 **Disk**에 존재한다. Disk는 일반적으로 Memory에 비해서 Read/Write 성능이 떨어지며, 특히 Random Read/Write의 성능은 Disk가 Memory에 비해서 많이 떨어진다. 하지만 Sequential Read/Write의 경우 Disk의 성능이 Memory의 성능에 비해서 크게 떨어지지 않기 때문에, Kafka는 Partition 이용시 최대한 Sequential Read/Write를 많이 이용하도록 설계되어 있다.

또한 Kafka는 Kernel의 Disk Cache (Page Cache)에 있는 Record가 Kafka를 거치지 않고 Kernel의 Socket Buffer로 바로 복사되도록 만들어, Record를 Network를 통해 Consumer로 전달시 발생하는 Copy Overhead를 최소한으로 줄였다. Partition은 실제로 하나의 파일로 Disk에 저장되지 않고 **Segment** 불리는 단위로 쪼개져서 저장된다. Segment의 기본 크기값은 1GB이다.

### 1.4. ACK

Kafka는 Producer를 위한 ACK 관련 Option을 제공한다. Producer는 ACK를 이용하여 자신이 전송한 Record가 Broker에게 잘 전달되었는지 확인할 수 있을 뿐만 아니라 Record 유실도 최소화 할 수 있다. `0`, `1`, `all` 3가지 Option을 제공한다. Producer마다 각각 다른 ACK Option을 설정할 수 있다.

* `0` : Producer는 ACK를 확인하지 않는다.
* `1` : Producer는 ACK를 기다린다. 여기서 ACK는 Record가 하나의 Kafka Broker에게만 전달되었다는 것을 의미한다. 따라서 Producer로부터 Record를 전달받은 Kafka Broker가 Replica 설정에 따라서 Record를 다른 Kafka Broker에게 복사하기전에 죽는다면 Record 손실이 발생할 수 있다. 기본 설정값이다.
* `all (-1)` : Producer는 ACK를 기다린다. 여기서 ACK는 Record가 설정한 Replica만큼 여러 Kafka Broker들에게 복사가 완료되었다는 의미이다. 따라서 Producer로부터 Record를 전달받은 Kafka Broker가 죽어도 복사한 Record를 갖고있는 Kafka Broker가 살아있다면 Record는 유지된다.

Kafka는 Consumer를 위한 별도의 ACK Option을 제공하지 않는다. 위에서 언급한것 처럼 Consumer는 처리가 완료된 Record의 Offset을 Kafka Broker에게 전달한다. 즉 **Consumer가 전달하는 Record의 Offset이 Kafka Broker에게 ACK의 역할**을 수행한다. 일반적으로 Consumer 역할을 수행하는 App은 Consumer Library의 Auto Commit 기능(`enable.auto.commit=true`)을 통해서 특정 주기마다 App의 간섭없이 수신 완료한 Record의 Offset을 Kafka Broker에게 전달하거나, App에서 Record 처리까지 완료한 이후에 직접 Offset을 전달하는 방식을 이용한다.

### 1.5. Record Retention

Kafka는 Partition에 저장되어있는 Record를 일정한 기준에 따라서 보존하며 이를 Kafka에서는 **Record Retention** 정책이라고 표현한다. Record Retention 정책에는 먼져 특정 기간안의 Record만 보존하는 방법이 있다. 기간을 7일로 설정해 준다면 Record는 Kakfka에 도착한뒤 7일까지 보존되며 그 이후에는 보존을 보장하지 않는다. 두번째로는 Partition 사이즈가 특정 용량을 초과하지 않게 보존하는 방법이 있다. Record Write로 인해서 Partition이 설정한 용량보다 커지게 되면 Partition 앞의 Record를 지원 Partition 용량을 유지한다.

```properties {caption="[Config 1] Kafka Record Retention Properties Example for Broker", linenos=table}
# by Duration (Default: 7 days)
log.retention.hours=168
log.retention.minutes=10080
log.retention.ms=604800000

# by Size (Default: Infinite)
log.retention.bytes=-1
```

```shell {caption="[Shell 1] Kafka Record Retention Command Example for Topic", linenos=table}
kafka-configs.sh --bootstrap-server kafka-broker-host:9092 --entity-type topics --entity-name topic-name --alter --add-config log.retention.hours=168
kafka-configs.sh --bootstrap-server kafka-broker-host:9092 --entity-type topics --entity-name topic-name --alter --add-config log.retention.bytes=-1
```

Record Retention은 Broker에 설정하여 전역 설정 방법과, 각 Topic별로 설정하는 방법이 있다. [Config 1]은 Broker에 기간, 용량을 기준으로 Record Retention 설정 예시를 나타내고 있으며, [Shell 1]은 Topic 별로 기간 또는 용량을 기준으로 Record Retention 설정 예시를 나타내고 있다.

### 1.6. Replication, Failover

다수의 Broker와 Partition을 이용하여도 Replication이 적용되지 않은 상태에서는 일부 Broker가 죽으면 Record 손실을 막을 수 없다. 예를 들어 [Figure 1]에서 `Broker C`가 죽을경우 `Topic B`의 모든 Record와 `Topic C`의 `Partition 0`의 Record 손실이 발생하게 된다. 이러한 Record 손실을 방지하기 위해서는 Replication을 적용하여 Parition을 복제하는 것이 필요하다. 

{{< figure caption="[Figure 5] Kafka Replication" src="images/kafka-replication.png" width="1000px" >}}

[Figure 5]는 [Figure 1]에서 Replication 적용된 Kafka를 나타내고 있다. `Topic A`와 `Topic B`는 Replica `2`, `Topic C`는 Replica `3`으로 설정한 상태이다. 따라서 `Topic A`와 `Topic B`는 한개의 복제본 Partition을 가지며, `Topic C`는 두개의 복제본 Partition을 갖게 된다.

원본 Partition은 **Leader Partition**이라고 부르며 복제본 Partition은 **Follower Partition**이라고 부른다. Producer와 Consumer는 Leader Partition만을 이용하며, Follower Partition을 직접 이용하지 않는다. Follower Partition은 오직 Leader Partition이 장애로 인해서 이용하지 못할경우 Failover를 위해서 이용된다. Replication은 각 Topic마다 별도로 설정할 수 있다.

Replication 동기 방식은 Producer의 ACK 설정에 따라서 Sync 방식, Async 방식 둘다 이용이 가능하다. `all (-1)` ACK 설정이 경우에만 Producer가 Record가 복제까지 완료되어야 ACK를 수신하기 때문에, Replication 관점에서 `all (-1)`은 **Sync 방식**에 해당된다. 반면에 `0`, `1` ACK 설정이 경우에는 Producer가 Record가 복제되지 않아도  ACK를 수신하기 때문에, Replication 관점에서 `0`, `1`은 **Async 방식**에 해당되며 Failover 수행시 Record 손실이 발생할 수 있다.

{{< figure caption="[Figure 6] Kafka Failover" src="images/kafka-replication-failover.png" width="1000px" >}}

[Figure 6]는 [Figure 5]에서 `Broker C`가 죽을경우 동작하는 Failover의 모습을 나타내고 있다. `Topic B`의 Leader Partition이 `Broker A`로 넘어가고, `Topic C`의 Leader Partition이 `Broker B`로 넘어가는 것을 확인할 수 있다. Kafka는 Leader Partition과 완전히 동기화된 Follower Partition (**ISR**, In-Sync Replicas)중에서 임의의 Follower Partition을 Leader Partition으로 승격한다. 장애가 발생한 Broker의 Partition들은 **Offline** 상태가 되며, Broker가 복구되면 Follower Partition이 된다.

Message가 Replication이 완료되었지만 Broker의 장애로 Producer는 ACK만 수신하지 못할 수 있다. 이는 Producer가 Parition에 저장된 Message를 중복해서 전송할 수 있다는걸 의미하며, Message 중복이 발생할 수 있다는걸 의미한다. 이러한 Message 중복을 방지하기 위해서 **Kafka의 멱등성** 설정 (`enable.idempotence`)을 통해서 Message 중복을 방지할 수 있다.

Consumer도 처리가 완료된 Message의 Offset을 Broker에게 전송했지만 Broker의 장애로 ACK를 수신하지 못할 수 있다. 따라서 Consumer도 동일한 Message를 중복해서 받을 수 있으며, Consumer는 반드시 동일한 Message를 받더라도 문제가 없도록 멱등성 Logic을 구현하거나, Kafka Transaction을 이용하여 동일한 Message를 처리하지 못하도록 만들어야 한다.

## 2. 참조

* [https://fizalihsan.github.io/technology/bigdata-frameworks.html](https://fizalihsan.github.io/technology/bigdata-frameworks.html)
* [https://en.wikipedia.org/wiki/Apache-Kafka](https://en.wikipedia.org/wiki/Apache-Kafka)
* [https://www.quora.com/What-is-Apache-Kafka](https://www.quora.com/What-is-Apache-Kafka)
* [https://sookocheff.com/post/kafka/kafka-in-a-nutshell/](https://sookocheff.com/post/kafka/kafka-in-a-nutshell/)
* [https://epicdevs.com/17](https://epicdevs.com/17)
* [https://medium.freecodecamp.org/what-makes-apache-kafka-so-fast-a8d4f94ab145](https://medium.freecodecamp.org/what-makes-apache-kafka-so-fast-a8d4f94ab145)
* [https://www.popit.kr/kafka-%EC%9A%B4%EC%98%81%EC%9E%90%EA%B0%80-%EB%A7%90%ED%95%98%EB%8A%94-producer-acks/](https://www.popit.kr/kafka-%EC%9A%B4%EC%98%81%EC%9E%90%EA%B0%80-%EB%A7%90%ED%95%98%EB%8A%94-producer-acks/)



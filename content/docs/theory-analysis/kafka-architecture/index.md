---
title: Kafka Architecture
---

분산 Message Queue인 kafka의 Architecture를 분석한다.

## 1. Kafka Architecture

Kafka는 Publish-subscribe 기반의 분산 Message Queue이다. Kafka는 수신한 Message를 특정 기간동안 저장하고 재처리가 가능하다는 특징 때문에 일반적으로 Event Driven Architecture의 **Event Bus**로 많이 활용된다. 또한 높은 Message 처리량을 갖는 특징도 갖고 있으며, 이를 기반으로 Storm 같은 빅데이터 처리 Platform의 **Data Stream Queue**로도 많이 이용되고 있다.

{{< figure caption="[Figure 1] Kafka Architecture" src="images/kafka-architecture.png" width="750px" >}}

[Figure 1]은 Kafka의 구성요소를 나타내고 있다.

* **Kafka Broker** : Message를 수신, 관리, 전송하는 Kafka의 핵심 Server이다. Kafka Broker는 일반적으로 Load Balancing 및 HA (High Availability)를 위해서 다수의 Node 위에서 Cluster를 이루어 동작한다.
* **Zookeeper** : Cluster를 이루는 각 Kafka Broker의 동작 상태를 파악하고 상태 정보를 Producer 및 Consumer에게 전달한다. 또한 Zookeeper는 Message 관리를 위해 필요한 정보를 저장하는 저장소 역할도 수행한다.
* **Topic** : Message를 관리하는 단위이다. Topic은 다시 **Partition**이라는 작은 단위로 쪼개지며, Kafka는 다수의 Partiton을 이용하여 Message 처리량을 높인다.
* **Producer** : Topic에게 Message를 전송(**Publish**)하는 App을 의미한다.
* **Consumer** : Topic으로부터 Message를 전달받는(**Subscribe**) App을 의미한다. Consumer는 Poll 함수를 통해서 **Polling 방식**으로 Message의 존재 여부를 확인하고, 있을경우 Message를 가져온다.
* **Consumer Group** : 의미 그대로 다수의 Consumer 묶는 역할을 수행하며, Kafka는 Consumer Group을 이용하여 Consumer의 가용성 및 Message 처리량을 높인다.

[Figure 1]은 Kafka에서 Message를 전달하는 과정도 나타내고 있다. Producer가 특정 Topic으로 Message를 전송(Publish)하면, Kafka Cluster는 해당 Topic을 구독(Subscribe)하고 있는 모든 Consumer Group에게 Producer로부터 전달받은 Message를 전송한다. [Figure 1]에서 `Consumer Group B`와 `Consumer Group C`는 `Topic B`를 구독하고 있기 때문에 Kafka Broker는 `Producer A`가 `Topic B`로 전송한 Message를 `Consumer Group B`와 `Consumer Group C`에게 전달한다.

### 1.1. Consumer Group

Consumer Group은 다수의 Consumer를 묶어 하나의 Topic을 다수의 Consumer가 동시에 처리할 수 있도록 만들어준다. 첫 그림에서 Consumer Group C는 Topic C를 구독하고 있다. Consumer Group C는 2개의 Consumer를 갖고 있기 때문에 Topic C의 Message는 2개의 Consumer가 나누어 병렬처리가 가능하다. 다만 Consumer Group의 효율을 높이기 위해서는 Consumer Group이 구독하는 Topic의 Partiton의 개수가 중요하다.

{{< figure caption="[Figure 2] Partition와 Consumer Group의 관계" src="images/kafka-partition-consumer.png" width="750px" >}}

[Figure 2]는 같은 Topic에 있는 Partiton의 개수와 같은 Consumer Group에 있는 Consumer의 개수에 따른 관계도를 나타내고 있다. Partition과 Consumer는 N:1의 관계이다. 같은 Consumer Group에 있는 Consumer들은 하나의 Partition을 동시에 같이 이용할 수 없다. 즉 Partition 보다 Consumer의 개수가 많으면 Message를 처리하지 않는 Consume가 생기게 된다. 따라서 Consumer Group을 이용할 경우 Topic의 Partiton 개수도 반드시 같이 고려되야 한다는

각 Consumer Group에는 **Consumer Leader**가 존재하며 Consumer Group의 Consumer들을 관리하는 역할을 수행한다. 또한 Consumer Leader는 Kafka Broker와 협력하여 Consumer와 Partition을 Mapping하는 작업을 수행한다. Consumer와 Partition을 Mapping 작업은 Consumer Group의 일부 Consumer가 죽었을 경우, Parition이 추가될 경우, Consumer Group에 Consumer가 추가되었을 경우 등 다양한 Event 발생시 수행된다.

### 1.2. Partition, Offset

{{< figure caption="[Figure 3] Kafka Partition" src="images/kafka-partition.png" width="750px" >}}

**Partition**은 병렬처리로 Message의 처리량을 높이기 위해서 하나의 Topic을 Kafka Cluster 내부의 여러 Kafka Broker에게 분산하기 위한 단위이자, Message를 순차적으로 저장하는 Queue 역할을 수행한다. [Figure 3]는 Producer 및 Consumer와 상호작용을 하는 Partition을 자세히 나타내고 있다. Producer가 전송한 Message는 Partition의 끝에 차례대로 저장된다. 이때 Message의 ID는 Array의 Index처럼 순차적으로 증가한다. 이러한 Message의 ID를 Kafka에서는 **Offset**이라고 한다.

Producer와 별개로 Consumer는 Partition의 앞부분부터 시작하여 **Consumer Offset**을 증가시키며 차례대로 Message를 읽는다. 여기서 Consumer Offset은 Consumer가 처리를 완료한 Partition의 가장 마지막 Message의 Offset을 의미한다. 따라서 Consumer Offset은 Kafka Broker가 저장하고 있지만 Consumer의 요청에 의해서 변경된다. Consumer Offset은 각 Partition, Consumer Group 별로 Kafka Broker에 저장된다. [Figure 2]에서 `Topic B`의 `Partition 0`의 경우 `Consumer Group B`의 Consumer Offset은 `6`, `Consumer Group C`의 Consumer Offset은 `4`를 나타내고 있다.

Partition의 개수는 Topic마다 다르게 설정할 수 있다. 일반적으로 각 Partition은 서로 다른 Kafka Broker에 배치되어 Message를 병렬처리 한다. [Figure 2]에서 `Topic C`는 3개의 Partiton으로 이루어져 있기 때문에 각 Partiton은 서로 다른 3개의 Kafka Broker에 분산된다. `Topic C`는 3개의 Kafka Broker를 이용하기 때문에 하나의 Topic을 이용하는 `Topic B`에 비해서 최대 3배 빠르게 Message를 처리 할 수 있다. 하지만 3개의 Partiton을 이용한다는 의미는 3개의 Queue에 Message를 나누어 저장한다는 의미이기 때문에 Producer 전송한 Message의 순서와 Consumer가 수신하는 Message의 순서는 달라질 수 있다. `Topic B`는 하나의 Partition만을 이용하기 때문에 Message 순서는 그대로 유지된다.

Producer는 Topic이 다수의 Partition을 갖고 있을 경우 기본적으로 **Round-robin** 방식으로 Message를 전달할 Partiton 선택한다. 만약 다른 Partition 선택 알고리즘이 필요하면, Producer 개발자는 Kafka가 제공하는 Interface를 통해 Partition 선택 알고리즘을 직접 개발 및 적용할 수 있다. Consumer는 Message를 하나씩 처리할때마다 변경된 Consumer Offset을 Kafka Broker에게 전달하는 **Sync 방식**과, 한꺼번에 여러 Message를 모아서 처리하고 마지막 Message의 Offset만 Kafka Broker에게 전달하는 **Async 방식**이 존재한다. 일반적으로 Message 처리량을 높이기 위해서 Async 방식을 이용한다.

Partition은 Message 보존을 위해서 Memory가 아닌 **Disk**에 존재한다. Disk는 일반적으로 Memory에 비해서 Read/Write 성능이 떨어지며, 특히 Random Read/Write의 성능은 Disk가 Memory에 비해서 많이 떨어진다. 하지만 Sequential Read/Write의 경우 Disk의 성능이 Memory의 성능에 비해서 크게 떨어지지 않기 때문에, Kafka는 Partition 이용시 최대한 Sequential Read/Write를 많이 이용하도록 설계되어 있다. 또한 Kafka는 Kernel의 Disk Cache (Page Cache)에 있는 Message가 Kafka를 거치지 않고 Kernel의 Socket Buffer로 바로 복사되도록 만들어, Message를 Network를 통해 Consumer로 전달시 발생하는 Copy Overhead를 최소한으로 줄였다. Partition은 실제로 하나의 파일로 Disk에 저장되지 않고 **Segment** 불리는 단위로 쪼개져서 저장된다. Segment의 기본 크기값은 1GB이다.

### 1.3. ACK

Kafka는 Producer를 위한 ACK 관련 Option을 제공한다. Producer는 ACK를 이용하여 자신이 전송한 Message가 Broker에게 잘 전달되었는지 확인할 수 있을 뿐만 아니라 Message 유실도 최소화 할 수 있다. `0`, `1`, `all` 3가지 Option을 제공한다. Producer마다 각각 다른 ACK Option을 설정할 수 있다.

* `0` : Producer는 ACK를 확인하지 않는다.
* `1` : Producer는 ACK를 기다린다. 여기서 ACK는 Message가 하나의 Kafka Broker에게만 전달되었다는 것을 의미한다. 따라서 Producer로부터 Message를 전달받은 Kafka Broker가 Replica 설정에 따라서 Message를 다른 Kafka Broker에게 복사하기전에 죽는다면 Message 손실이 발생할 수 있다. 기본 설정값이다.
* `all (-1)` : Procker는 ACK를 기다린다. 여기서 ACK는 Message가 설정한 Replica만큼 여러 Kafka Broker들에게 복사가 완료되었다는 의미이다. 따라서 Producer로부터 Message를 전달받은 Kafka Broker가 죽어도 복사한 Message를 갖고있는 Kafka Broker가 살아있다면 Message는 유지된다.

Kafka는 Consumer를 위한 별도의 ACK Option을 제공하지 않는다. 위에서 언급한것 처럼 Consumer는 처리가 완료된 Message의 Offset을 Kafka Broker에게 전달한다. 즉 **Consumer가 전달하는 Message의 Offset이 Kafka Broker에게 ACK의 역할**을 수행한다. 일반적으로 Consumer 역할을 수행하는 App은 Consumer Library의 Auto Commit 기능(`enable.auto.commit=true`)을 통해서 특정 주기마다 App의 간섭없이 수신 완료한 Message의 Offset을 Kafka Broker에게 전달하거나, App에서 Message 처리까지 완료한 이후에 직접 Offset을 전달하는 방식을 이용한다.

### 1.4. Message Retention

Kafka는 Partition에 저장되어있는 Message를 일정한 기준에 따라서 보존하며 이를 Kafka에서는 **Message Retention** 정책이라고 표현한다. Message Retention 정책에는 먼져 특정 기간안의 Message만 보존하는 방법이 있다. 기간을 7일로 설정해 준다면 Message는 Kakfka에 도착한뒤 7일까지 보존되며 그 이후에는 보존을 보장하지 않는다. 두번째로는 Partition 사이즈가 특정 용량을 초과하지 않게 보존하는 방법이 있다. Message Write로 인해서 Partition이 설정한 용량보다 커지게 되면 Partition 앞의 Message를 지원 Partition 용량을 유지한다.

## 2. 참조

* [https://fizalihsan.github.io/technology/bigdata-frameworks.html](https://fizalihsan.github.io/technology/bigdata-frameworks.html)
* [https://en.wikipedia.org/wiki/Apache-Kafka](https://en.wikipedia.org/wiki/Apache-Kafka)
* [https://www.quora.com/What-is-Apache-Kafka](https://www.quora.com/What-is-Apache-Kafka)
* [https://sookocheff.com/post/kafka/kafka-in-a-nutshell/](https://sookocheff.com/post/kafka/kafka-in-a-nutshell/)
* [https://epicdevs.com/17](https://epicdevs.com/17)
* [https://medium.freecodecamp.org/what-makes-apache-kafka-so-fast-a8d4f94ab145](https://medium.freecodecamp.org/what-makes-apache-kafka-so-fast-a8d4f94ab145)
* [https://www.popit.kr/kafka-%EC%9A%B4%EC%98%81%EC%9E%90%EA%B0%80-%EB%A7%90%ED%95%98%EB%8A%94-producer-acks/](https://www.popit.kr/kafka-%EC%9A%B4%EC%98%81%EC%9E%90%EA%B0%80-%EB%A7%90%ED%95%98%EB%8A%94-producer-acks/)



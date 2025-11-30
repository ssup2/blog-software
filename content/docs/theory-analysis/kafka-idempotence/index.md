---
title: Kafka Idempotence
draft: true
---

Kafka의 Idempotence 기능을 분석한다.

## 1. Kafka Idempotence 기능

Kafka Idempotence는 이름에서도 유추할수 있는것 처럼 Kafka의 Producer가 전송한 Record가 Kafka에 중복으로 저장되는 것을 방지하기 위한 기능이다. Kafka를 단순히 Event Bus로 이용하는 경우에는 Kafka에 동일한 Record가 중복으로 저장되는 것이 일반적으로 문제되지 않지만, Kafka를 Event Bus를 넘어 Event Store로 활용하는 경우에는 동일한 Record가 중복으로 저장되는 것이 문제가 되며, 이러한 문제를 방지하기 위해서 Kafka Idempotence 기능 활용이 필수적이다.

{{< figure caption="[Figure 1] Kafka Idempotence Architecture" src="images/kafka-idempotence-architecture.png" width="1000px" >}}

[Figure 1]은 Kafka Idempotence 기능이 활성화 됬을때의 Kafka의 Architecture를 나타내고 있다. Kafka Idempotence를 활성화 하기 위해서는 다음과 같은 Properties를 설정하면 된다.

* `enable.idempotence=true` : Kafka Idempotence 기능을 활성화 하기 위한 설정 값이다.
* `acks=all` : ACK 설정은 반드시 `all` 설정 값을 사용해야 한다. `all` 설정 값은 Producer가 Record가 모든 Replica Topic/Partition까지 복제되어야 Producer가 ACK를 수신할 수 있다.

Idempotence 기능이 활성화되면 Producer의 Request에는 **PID (Producer ID)**, **Epoch**, **Sequence 번호** 정보가 추가된다.

* **PID (Producer ID)** : Kafka가 할당한 Producer의 고유 ID이다. Producer가 Kafka에 접속하면 Producer ID가 발급되어 Producer에 전달되며, 이후에 Producer는 Record에 할당받은 PID를 같이 전송한다. Kafka Transaction 기법을 이용하지 않는다면 Producer가 재시작 되는 경우 새로운 PID를 할당받는다. 만약 Producer가 Broker가 발급하지 않은 PID를 전송하는 경우에는 `UnknownProducerIdException` Exception이 발생한다.
* **Epoch (Producer Epoch)** : Producer의 고유 Epoch를 나타낸다. Idempotence 기능이 활성화되면 Record에는 반드시 Epoch가 추가된다. 하지만 Kafka Transaction 기법을 이용하지 않을 경우에는 Record에는 항상 `0` 값이 설정되며, 큰 의미를 갖지 않는다.
* **Sequence Number** : Producer가 할당한 Record의 고유의 순서 번호이다. 일반적으로 하나의 Producer Request에는 Partition/Topic별로 Record Batch가 존재하며, 각 Record Batch에는 Record의 시작 Sequence Number와 종료 Sequence Number가 존재한다.

Kafka Broker는 Idempotence 기능이 활성화 됬을때, 각 PID 마다 Topic/Partition별 처리가 완료된 Record Batch의 시작/끝 Sequence Number를 **5개까지 Caching**하며 다음과 같은 동작을 통해서 중복 Record와 잘못된 순서로 Record가 저장되는 것을 방지한다.

* Broker는 Record Batch를 수신하면 먼져 Record Batch의 시작/끝 Sequence Number가 이미 Caching된 상태인지 확인한다.
* 만약 Record Batch의 시작/끝 Sequence Number가 Caching 된 상태라면, Kafka Broker는 이미 수신한 Record Batch라고 간주하여 Topic/Partition에 저장하지 않는다. 그리고 ACK만 Producer에 전송한다.
* 만약 Record Batch의 시작/끝 Sequence Number가 Caching 되지 않는 상태라면, Kafka Broker는 마지막으로 Caching된 Record Batch의 시작/끝 Sequence Number를 제거하고 수신한 Record Batch의 시작/끝 Sequence Number를 Caching한다. 그리고 수신한 Record를 Topic/Partition에 저장하고 ACK를 Producer에 전송한다.
* 만약 Record Batch의 시작/끝 Sequence Number가 Caching 되지 않는 상태라도, 수신한 시작/끝 Sequence Number가 연속적인 숫자가 아니라면 Kafka Broker는 수신한 Record Batch를 Topic/Partition에 저장하지 않고, Broker가 `OutOfOrderSequenceException` Exception을 발생시키도록 만든다.

Kafka Idempotence 기능은 모든 경우에 대해서 중복 Record를 방지하지는 못하며, 다음의 경우에는 중복 Record가 발생할 수 있다.

* Producer가 Record Batch를 전송한 다음에, Producer가 재시작되어 PID가 변경된 이후에 다시 동일한 Record Batch를 전송하는 경우에는 중복 Record가 발생할 수 있다. Kafka Broker는 PID를 기준으로 SEQ Cache를 관리하기 때문에 PID가 변경되면 새로운 Producer라 간주하기 때문이다.
* Producer가 전송한 Record Batch를 동일한 Paritition이 아닌 다른 Paritition에 전송하는 경우에는 중복 Record가 발생할 수 있다. Kafka Broker는 각 Partition별로 SEQ Cache를 관리하기 때문이다.
* Producer가 `inflight.requests.per.connection` 설정 값을 **6개** 이상으로 설정하여, Producer가 한꺼번에 6개 이상의 Request를 전송하는 경우에는 중복 Record가 발생할 수 있다. 각 Partition별로 최대 5개의 Record Batch의 시작/끝 Sequence Number만 Caching할 수 있기 때문이다. 5개는 Hard-code로 설정된 값이다. 따라서 Kafka Idempotence 기능을 이용하기 위해서는 `inflight.requests.per.connection` 설정 값은 반드시 **5개** 이하로 설정해야 한다.

### 1.1. Sequence Flow with Success

{{< figure caption="[Figure 2] Sequence Flow with Success" src="images/kafka-idempotence-sequence-flow-success.png" width="900px" >}}

### 1.2. Sequence Flow with Missing ACKs

{{< figure caption="[Figure 3] Sequence Flow with Missing ACKs" src="images/kafka-idempotence-sequence-flow-missing-acks.png" width="900px" >}}

### 1.3. Sequence Flow with Missing Records

{{< figure caption="[Figure 4] Sequence Flow with Missing Records" src="images/kafka-idempotence-sequence-flow-missing-records.png" width="900px" >}}

### 1.4. Sequence Flow with Sequence Cache Missed

{{< figure caption="[Figure 5] Sequence Flow with Sequence Cache Missed" src="images/kafka-idempotence-sequence-flow-cache-missed.png" width="900px" >}}

## 2. 참조

* Kafka Idempotence, Transaction : [https://stackoverflow.com/questions/58894281/difference-between-idempotence-and-exactly-once-in-kafka-stream](https://stackoverflow.com/questions/58894281/difference-between-idempotence-and-exactly-once-in-kafka-stream)
* Understanding Kafka Producer Part 2 : [https://github.com/AutoMQ/automq/wiki/Understanding-Kafka-Producer-Part-2](https://github.com/AutoMQ/automq/wiki/Understanding-Kafka-Producer-Part-2)

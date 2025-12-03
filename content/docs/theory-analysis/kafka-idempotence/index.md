---
title: Kafka Idempotence
---

Kafka의 Idempotence 기능을 분석한다.

## 1. Kafka Idempotence 기능

Kafka Idempotence는 이름에서도 유추할수 있는것 처럼 Kafka의 Producer가 전송한 Record가 Kafka에 중복으로 저장되는 것을 방지하기 위한 기능이다. Kafka를 단순히 Event Bus로 이용하는 경우에는 Kafka에 동일한 Record가 중복으로 저장되는 것이 일반적으로 문제되지 않지만, Kafka를 Event Bus를 넘어 Event Store로 활용하는 경우에는 동일한 Record가 중복으로 저장되는 것이 문제가 되며, 이러한 문제를 방지하기 위해서 Kafka Idempotence 기능 활용이 필수적이다.

{{< figure caption="[Figure 1] Kafka Idempotence Architecture" src="images/kafka-idempotence-architecture.png" width="1000px" >}}

[Figure 1]은 Kafka Idempotence 기능이 활성화 됬을때의 Kafka의 Architecture를 나타내고 있다. Kafka Idempotence를 활성화 하기 위해서는 다음과 같은 Properties를 설정하면 된다.

* `enable.idempotence=true` : Kafka Idempotence 기능을 활성화 하기 위한 설정 값이다.
* `acks=all` : ACK 설정은 반드시 `all` 설정 값을 사용해야 한다. `all` 설정 값은 Producer가 Record가 모든 Replica Topic/Partition까지 복제되어야 Producer가 ACK를 수신할 수 있다.

Idempotence 기능이 활성화되면 Producer의 Request에는 **PID (Producer ID)**, **Epoch**, **Sequence 번호** 정보가 추가된다.

* **PID (Producer ID)** : Kafka가 할당한 Producer의 고유 ID이다. Producer가 Kafka에 접속하면 Producer ID가 발급되어 Producer에 전달되며, 이후에 Producer는 Record에 할당받은 PID를 같이 전송한다. Kafka Transaction 기법을 이용하지 않는다면 Producer가 재시작 되는 경우 새로운 PID를 할당받는다. 만약 Producer가 Broker가 발급하지 않은 PID를 전송하는 경우에는 Kafka Broker로부터 `UnknownProducerIdException` Exception을 받는다.
* **Epoch (Producer Epoch)** : Producer의 고유 Epoch를 나타낸다. Epoch 값은 0에서 시작하며, Producer가 Kafka Broker로부터 `OutOfOrderSequenceException` Exception이 수신할때마다 1씩 증가한다.
* **Sequence Number** : Producer가 할당한 Record의 고유의 순서 번호이다. 일반적으로 하나의 Producer Request에는 Partition/Topic별로 Record Batch가 존재하며, 각 Record Batch에는 Record의 시작을 나타내는 **Base Sequence Number**와 Base Sequence Number에서 마지막 Record까지의 차이를 나타내는 **Offset**이 존재한다.

Kafka Broker는 Idempotence 기능이 활성화 됬을때, **각 PID, Epoch 마다** Topic/Partition별 처리가 완료된 Record Batch의 Sequence Number를 **5개까지 Caching**하며 다음과 같은 동작을 통해서 **중복 Record 저장을 방지**할 뿐만 아니라 **잘못된 순서로 Record가 저장되는 것도 방지**한다.

* Broker는 Record Batch를 수신하면 먼져 Record Batch의 Sequence Number가 이미 Caching된 상태인지 확인한다.
* 만약 Record Batch의 Sequence Number가 Caching 된 상태라면, Kafka Broker는라이미 수신한 Record Batch라고 간주하여 Topic/Partition에 저장하지 않는다. 그리고 ACK만 Producer에 전송한다.
* 만약 Record Batch의 Sequence Number가 Caching 되지 않는 상태라면, Kafka Broker는 가장 먼저 Caching된 Record Batch의 Sequence Number를 제거하고 수신한 Record Batch의 Sequence Number를 Caching한다. 그리고 수신한 Record Batch를 Topic/Partition에 저장하고 ACK를 Producer에 전송한다.
* 만약 Record Batch의 Sequence Number가 Caching 되지 않는 상태라도, 수신한 Record Batch의 Sequence Number가 이전에 받은 Batch의 Sequence Number의 다음 숫자가 아니라면 Kafka Broker는 수신한 Record Batch를 Topic/Partition에 저장하지 않고, Broker가 `OutOfOrderSequenceException` Exception을 발생시키도록 만든다.
* `OutOfOrderSequenceException` Exception을 받은 Producer는 Epoch 값을 1 증가시킨다음 재전송을 시도한다. Epoch 값이 증가된 Batch Record를 받은 Kafka Broker는 기존의 Caching된 Sequence Number를 제거하고 새로운 Sequence Number를 Caching한다.

Producer는 필요에 따른 Request 재전송을 위해서, 전송한 Request를 Kafka Broker로부터 ACK를 받기 전까지는 **In-flight Request**로 관리되며 다음과 같은 특징을 갖는다.

* In-flight Request는 Kafka Broker로부터 ACK를 받으면 사라진다.
* In-flight Request는 Request 재전송을 위한 모든 Metadata를 포함하고 있다.
* In-flight Request가 재전송되는 경우 반드시 **동일한 Sequence Number를 가진** Request로 재전송된다. 즉 Request 재전송시 Sequence Number를 재구성하지 않는다.
* 각 Producer마다 관리할 수 있는 최대 In-flight Request의 개수는 `max.in.flight.requests.per.connection` 설정을 통해서 제한할 수 있으며, 기본값은 **5개** 이다. 즉 기본적으로 최대 5개까지의 Request를 In-flight 상태로 관리할 수 있다.

Kafka Idempotence 기능은 모든 경우에 대해서 중복 Record를 방지하지는 못하며, 다음의 경우에는 중복 Record가 발생할 수 있다.

* Producer가 Record Batch를 전송한 다음에, Producer가 재시작되어 PID가 변경된 이후에 다시 동일한 Record Batch를 전송하는 경우에는 중복 Record가 발생할 수 있다. Kafka Broker는 PID를 기준으로 Sequence Number Cache를 관리하기 때문에 PID가 변경되면 새로운 Producer라 간주하기 때문이다.
* Producer가 전송한 Record Batch를 동일한 Paritition이 아닌 다른 Paritition에 전송하는 경우에는 중복 Record가 발생할 수 있다. Kafka Broker는 각 Partition별로 Sequence Number Cache를 관리하기 때문이다.
* Producer가 `inflight.requests.per.connection` 설정 값을 **6개** 이상으로 설정하여, Producer가 동시에 6개 이상의 Request를 전송하는 경우에는 중복 Record가 발생할 수 있다. 이는 Kafka Broker가 각 Partition별로 최대 5개의 Record Batch의 시작/끝 Sequence Number만 Caching할 수 있기 때문이다. 이 5개는 Hard-code로 설정된 값이며, 변경할 수 없다. 따라서 Kafka Idempotence 기능을 제대로 활용하기 위해서는 `inflight.requests.per.connection` 설정 값을 반드시 **5개** 이하로 설정해야 한다.

## 2. Sequence Flow with Kafka Idempotence

Kafka Idempotence 기능을 활성화 했을때 발생할 수 있는 다양한 Sequence Flow를 정리한다.

### 2.1. Sequence Flow with Success

{{< figure caption="[Figure 2] Sequence Flow with Success" src="images/kafka-idempotence-sequence-flow-success.png" width="900px" >}}

[Figure 2]는 Kafka Idempotence 기능이 활성화 됬을때 정상적으로 Record가 저장되는 경우의 Sequence Flow를 나타내고 있다. 단일 Topic/Partition이라고 가정하고 Sequence Number만 나타내고 있다. `A/120~114`, `B/124~121`, `C/132~125` 3개의 Record Batch와 `D/142~133`, `E/150~143` 2개의 Record Batch가 나누어 전송되었고, 이후에 Kafka Broker는 Record Batch 처리 이후에 차례대로 ACK를 Producer에 전송하는 것을 확인할 수 있다.

### 2.2. Sequence Flow with Missing ACKs

{{< figure caption="[Figure 3] Sequence Flow with Missing ACKs" src="images/kafka-idempotence-sequence-flow-missing-acks.png" width="900px" >}}

[Figure 3]는 Kafka Idempotence 기능이 활성화 됬을때 ACK가 유실되었을 경우에도 Record Batch가 중복으로 저장되는 것을 방지되는 Sequence Flow를 나타내고 있다. Producer가 전송한 `A/120~114`, `B/124~121`, `C/132~125`, `D/142~133`, `E/150~143` 5개의 Batch Record가 잘 처리되었지만, `D/142~133`, `E/150~143` 2개의 Batch Record의 ACK가 유실되는 경우를 나타내고 있다.

`D/142~133`, `E/150~143` 2개의 ACK를 받지 못한 Producer는 `request.timeout.ms` 시간만큼 대기한 이후에 다시 동일한 Record Batch를 전송하게 된다. 이때 Kafka Broker는 이미 수신한 Record Batch라고 간주하여 Topic/Partition에 저장하지 않는다. 그리고 ACK만 Producer에 전송하여 Producer가 다시 동일한 Record Batch를 전송하지 않도록 만든다.

### 2.3. Sequence Flow with Missing Records

{{< figure caption="[Figure 4] Sequence Flow with Missing Records" src="images/kafka-idempotence-sequence-flow-missing-records.png" width="900px" >}}

[Figure 4]는 Kafka Idempotence 기능이 활성화 됬을때 Batch Record가 유실되었을때의 Sequence Flow를 나타내고 있다. Producer가 전송한 `A/120~114`, `B/124~121`, `C/132~125`, `D/142~133`, `E/150~143` 5개의 Batch Record 중에서 `C/132~125` Batch Record가 유실된 경우를 나타내고 있다. Kafka Broker는 `C/132~125` Batch Record를 건너뛴 채로 다음 Batch Record인 `D/142~133`, `E/150~143` Batch Record를 수신하기 때문에 `OutOfOrderSequenceException` Exception을 Producer에게 전송한다.

`OutOfOrderSequenceException` Exception을 받은 Producer는 Epoch 값을 1 증가시킨다음 마지막 ACK를 받은 Batch Record의 다음 Batch Record부터 재전송을 시작하게 된다. 이처럼 Idempotence 기능을 활용하면 Sequence Number를 기반으로 Batch Record의 순서가 바뀌는 현상도 방지할 수 있다.

### 2.4. Sequence Flow with Sequence Cache Missed

{{< figure caption="[Figure 5] Sequence Flow with Sequence Cache Missed" src="images/kafka-idempotence-sequence-flow-cache-missed.png" width="900px" >}}

[Figure 5]는 `inflight.requests.per.connection` 설정값을 6개로 설정할 경우 중복 Record가 발생하는 Sequence Flow를 나타내고 있다. Producer가 전송한 `A/120~114`, `B/124~121`, `C/132~125`, `D/142~133`, `E/150~143`, `F/155~151` 6개의 Batch Record가 잘 처리되었지만, 가장 첫번째 Batch Record인 `A/120~114`의 ACK가 유실되는 경우를 나타내고 있다.

`A/120~114` Batch Record에 대한 ACK를 받지못한 Producer는 `request.timeout.ms` 시간만큼 대기한 이후에 다시 동일한 Record Batch를 전송하게 된다. 이때 Kafka Broker에는 마지막으로 받은 5개의 Batch Record만 Caching 되어있고, 가장 첫번째 `A/120~114` Batch Record는 Caching 되어있지 않다. 따라서 Kafka Broker는 `A/120~114` Batch Record가 이미 저장된 Batch Record라고 인식하지 못하고 `OutOfOrderSequenceException` Exception을 발생시킨다.

`OutOfOrderSequenceException` Exception을 받은 Producer는 Epoch 값을 1 증가시킨다음 ACK를 받지 못한 `A/120~114` Batch Record를 재전송하며, Epoch 값이 증가된 `A/120~114` Batch Record를 받은 Kafka Broker는 중복 저장을 수행한다.

## 3. 참조

* Kafka Idempotence, Transaction : [https://stackoverflow.com/questions/58894281/difference-between-idempotence-and-exactly-once-in-kafka-stream](https://stackoverflow.com/questions/58894281/difference-between-idempotence-and-exactly-once-in-kafka-stream)
* Understanding Kafka Producer Part 2 : [https://github.com/AutoMQ/automq/wiki/Understanding-Kafka-Producer-Part-2](https://github.com/AutoMQ/automq/wiki/Understanding-Kafka-Producer-Part-2)

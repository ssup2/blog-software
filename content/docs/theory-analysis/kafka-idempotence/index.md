---
title: Kafka Idempotence
draft: true
---

Kafka의 Idempotence를 분석한다.

## 1. Kafka Idempotence

{{< figure caption="[Figure 1] Kafka Idempotence Architecture" src="images/kafka-idempotence-architecture.png" width="1000px" >}}

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

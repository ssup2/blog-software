---
title: Kafka Idempotence, Transaction
draft: true
---

Kafka의 Idempotence과 Transaction에 대해서 분석한다.

## 1. Kafka Idempotence

* Producer ID : 
* Producer Epoch : 
* Sequence Number : 

## 2. Kafka Transaction

* `ENABLE_IDEMPOTENCE_CONFIG` : Kafka의 Idempotence 기능을 활성화 하기 위한 설정 값이다.
* `ACKS_CONFIG` : Kafka의 ACK 설정 값이다.
* `MAX_IN_FLIGHT_REQUESTS_PER_CONNECTION` : Kafka의 동시 요청 수 제한 값이며, 기본값은 5이다.
* `RETRIES_CONFIG` : Kafka의 재시도 횟수 설정 값이다.
* `TRANSACTIONAL_ID_CONFIG` : Kafka의 Transaction 기능을 활성화 하기 위한 설정 값이다.

## 2. 참조

* Kafka Transaction : [https://developer.confluent.io/courses/architecture/transactions/](https://developer.confluent.io/courses/architecture/transactions/)
* Kafka Transaction : [https://www.confluent.io/blog/transactions-apache-kafka/](https://www.confluent.io/blog/transactions-apache-kafka/)

* Kafka Idempotence, Transaction : [https://stackoverflow.com/questions/58894281/difference-between-idempotence-and-exactly-once-in-kafka-stream](https://stackoverflow.com/questions/58894281/difference-between-idempotence-and-exactly-once-in-kafka-stream)
* Understanding Kafka Producer Part 2 : [https://github.com/AutoMQ/automq/wiki/Understanding-Kafka-Producer-Part-2](https://github.com/AutoMQ/automq/wiki/Understanding-Kafka-Producer-Part-2)
* Kafka Guarantee : [https://developer.confluent.io/courses/architecture/guarantees/](https://developer.confluent.io/courses/architecture/guarantees/)
* Kafka Transaction : [https://baebalja.tistory.com/627](https://baebalja.tistory.com/627)
* Kafka Idempotence, Transaction : [https://www.confluent.io/blog/exactly-once-semantics-are-possible-heres-how-apache-kafka-does-it/](https://www.confluent.io/blog/exactly-once-semantics-are-possible-heres-how-apache-kafka-does-it/)
* Kafka Transaction : [https://tjsals7825.medium.com/%EB%A9%94%EC%8B%9C%EC%A7%80-%EB%B8%8C%EB%A1%9C%EC%BB%A4-3-kafka-e0b51005c472](https://tjsals7825.medium.com/%EB%A9%94%EC%8B%9C%EC%A7%80-%EB%B8%8C%EB%A1%9C%EC%BB%A4-3-kafka-e0b51005c472)
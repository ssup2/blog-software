---
title: Kafka 인증, 인가
draft: true
---

Kafka의 인증, 인가를 분석한다.

## 1. Kafka Authentication

* Security Protocol
  * `PLAINTEXT`
  * `SSL`
  * `SASL_PLAINTEXT`
  * `SASL_SSL`

* SASL Mechanism
  * `PLAIN`
  * `SCRAM-SHA-256`
  * `SCRAM-SHA-512`
  * `GSSAPI`
  * `OAUTHBEARER`

## 2. Kafka Authorization

## 3. 참조

* Kafka Security Protocol : [https://kafka.apache.org/25/javadoc/org/apache/kafka/common/security/auth/SecurityProtocol.html](https://kafka.apache.org/25/javadoc/org/apache/kafka/common/security/auth/SecurityProtocol.html)
* Kafka SASL : [https://velog.io/@limsubin/Kafka-SASLPALIN-%EC%9D%B8%EC%A6%9D-%EC%84%A4%EC%A0%95%EC%9D%84-%ED%95%B4%EB%B3%B4%EC%9E%90](https://velog.io/@limsubin/Kafka-SASLPALIN-%EC%9D%B8%EC%A6%9D-%EC%84%A4%EC%A0%95%EC%9D%84-%ED%95%B4%EB%B3%B4%EC%9E%90)
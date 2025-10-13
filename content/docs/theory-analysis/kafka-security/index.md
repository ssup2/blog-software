---
title: Kafka Security
draft: true
---

Kafka의 인증, 인가를 분석한다.

## 1. Kafka Security Protocol

Kafka에서 제공하는 Security Protocol은 다음과 같다. 여기서 Security Protocol은 Kafka에 접근하기 위한 **인증**과 **Network 구간 암호화** 방식을 결정한다.
ㅇ
* `PLAINTEXT` : 인증을 수행하지 않고, Network 구간 암호화를 수행하지 않는다.
* `SSL` : 인증을 수행하지 않고, Network 구간을 SSL로 암호화한다.
* `SASL_PLAINTEXT` : SASL을 이용하여 인증을 수행하고, Network 구간 암호화를 수행하지 않는다.
* `SASL_SSL` : SASL을 이용하여 인증을 수행하고, Network 구간을 SSL로 암호화한다.

### 1.1. SASL (Simple Authentication and Security Layer)

SASL은 Kafka에서 이용하는 인증 기법을 의미한다. 다음과 같은 Mechanism을 이용하여 인증을 수행할 수 있다.

* `PLAIN` : Username과 Password를 이용하여 인증을 수행한다. Username과 Password가 그대로 Kafka에 전송되는 방식이기 때문에, SSL로 Network 구간을 암호화하지 않으면 Username과 Password가 그대로 노출된다.
* `SCRAM-SHA-256`, `SCRAM-SHA-512` : Username과 Password를 이용하여 인증을 수행한다. Username과 Password를 SCRAM (Salted Challenge Response Authentication Mechanism) 방식으로 암호화하여 Kafka에 전송한다.
* `GSSAPI` : Kerberos를 이용하여 인증을 수행한다.
* `OAUTHBEARER` : OAuth 2.0을 이용하여 인증을 수행한다.

### 1.2. Kafka Config Examples

Security Protocol과 SASL Mechanism 설정에 따른 Kafka의 Config와 Producer/Consumer의 Config를 예시는 다음과 같다.

#### 1.2.1. Security Protocol : `PLAINTEXT`

```properties {caption="[Config 1] Kafka config for PLAINTEXT security protocol", linenos=table}
# Listener
listeners=PLAINTEXT://:9092
advertised.listeners=PLAINTEXT://external.broker.com:9092

# Security Protocol
security.inter.broker.protocol=PLAINTEXT
```

```properties {caption="[Config 2] Producer/Consumer config for PLAINTEXT security protocol", linenos=table}
# Broker configuration
bootstrap.servers=external.broker.com:9092
```

[Config 1]는 Kafka Config 예시를 나타내고 있다. Listener와 Inter-Broker Communication Protocol을 `PLAINTEXT`로 설정하고 있는걸 확인할 수 있다. [Config 2]는 Producer/Consumer Config 예시를 나타낸다. bootstrap.servers에 Kafka Broker의 외부 주소인 `external.broker.com:9092`로 설정하고 있는걸 확인할 수 있으며, 별도의 인증 설정이 없기 때문에 별도의 인증 정보를 전달하지 않는다.

#### 1.2.2. Security Protocol : `SASL_PLAINTEXT`, SASL : `PLAIN`

```properties {caption="[Config 3] Kafka config for SASL_PLAINTEXT security protocol and PLAIN SASL", linenos=table}
# Listener
listeners=SASL_PLAINTEXT://0.0.0.0:9092
advertised.listeners=SASL_PLAINTEXT://kafka-broker:9092

# Security Protocol
security.inter.broker.protocol=SASL_PLAINTEXT

# SASL Mechanism
sasl.enabled.mechanisms=PLAIN
sasl.mechanism.inter.broker.protocol=PLAIN

# SASL Plain Username and Password
listener.name.sasl_plaintext.plain.sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required \
  username="admin" \
  password="admin-password"; \
  user_servicea="servicea-password"; \
  user_serviceb="serviceb-password";
```

[Config 3]는 Kafka Config 예시를 나타내고 있다. Listener와 Inter-Broker Communication Protocol을 `SASL_SSL`로 설정하고 있으며, SASL Mechanism을 `PLAIN`으로 설정하고 있는걸 확인할 수 있다. 또한 Username과 Password를 설정하고 있는것도 확인할 수 있다. `username`과 `password`는 Kafka Broker 사이에 인증을 위한 Admin User/Password를 의미하며, `user_[username]`은 해당 User의 Password를 의미한다.

```properties {caption="[Config 4] Producer/Consumer config for SASL_PLAINTEXT security protocol and PLAIN SASL", linenos=table}
# Broker configuration
bootstrap.servers=broker1.example.com:9093

# Specify the security protocol and mechanism
security.protocol=SASL_SSL
sasl.mechanism=PLAIN

# Client authentication information
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required \
  username="servicea" \
  password="servicea-password";
```

[Config 4]는 Producer/Consumer Config 예시를 나타내고 있다. security.protocol과 sasl.mechanism을 `SASL_SSL`과 `PLAIN`으로 설정하고 있으며, Username과 Password를 설정하고 있는걸 확인할 수 있다.

## 2. Kafka Authorization

## 3. 참조

* Kafka Security : [https://godekdls.github.io/Apache%20Kafka/security/](https://godekdls.github.io/Apache%20Kafka/security/)
* Kafka Security Protocol : [https://kafka.apache.org/25/javadoc/org/apache/kafka/common/security/auth/SecurityProtocol.html](https://kafka.apache.org/25/javadoc/org/apache/kafka/common/security/auth/SecurityProtocol.html)
* Kafka SASL : [https://velog.io/@limsubin/Kafka-SASLPALIN-%EC%9D%B8%EC%A6%9D-%EC%84%A4%EC%A0%95%EC%9D%84-%ED%95%B4%EB%B3%B4%EC%9E%90](https://velog.io/@limsubin/Kafka-SASLPALIN-%EC%9D%B8%EC%A6%9D-%EC%84%A4%EC%A0%95%EC%9D%84-%ED%95%B4%EB%B3%B4%EC%9E%90)
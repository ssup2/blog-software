---
title: Kafka Security
---

This document analyzes Kafka authentication and authorization.

## 1. Kafka Security Protocol

The Security Protocols provided by Kafka are as follows. Here, Security Protocol determines the **authentication** method for accessing Kafka and the **Network encryption** method.

* `PLAINTEXT`: Performs no authentication and no Network encryption.
* `SSL`: Performs no authentication and encrypts Network with SSL.
* `SASL_PLAINTEXT`: Performs authentication using SASL and performs no Network encryption.
* `SASL_SSL`: Performs authentication using SASL and encrypts Network with SSL.

### 1.1. SASL (Simple Authentication and Security Layer)

SASL refers to the authentication method used in Kafka. Authentication can be performed using the following Mechanisms.

* `PLAIN`: Performs authentication using Username and Password. Since Username and Password are transmitted to Kafka as-is, they are exposed if the Network is not encrypted with SSL.
* `SCRAM-SHA-256`, `SCRAM-SHA-512`: Performs authentication using Username and Password. Username and Password are encrypted using SCRAM (Salted Challenge Response Authentication Mechanism) and transmitted to Kafka.
* `GSSAPI`: Performs authentication using Kerberos.
* `OAUTHBEARER`: Performs authentication using OAuth 2.0.

### 1.2. Kafka Config Examples

The following are examples of Kafka Config and Producer/Consumer Config according to Security Protocol and SASL Mechanism settings.

#### 1.2.1. Security Protocol: `PLAINTEXT`

```properties {caption="[Config 1] Kafka server.properties for PLAINTEXT security protocol", linenos=table}
# Listener
listeners=PLAINTEXT://:9092
advertised.listeners=PLAINTEXT://external.broker.com:9092

# Security Protocol
security.inter.broker.protocol=PLAINTEXT
```

[Config 1] shows an example of Kafka's `server.properties` when the Security Protocol is `PLAINTEXT`. It can be seen that the Listener and Inter-Broker Communication Protocol are set to `PLAINTEXT`.

```properties {caption="[Config 2] Producer/Consumer config for PLAINTEXT security protocol", linenos=table}
# Broker configuration
bootstrap.servers=external.broker.com:9092
```

[Config 2] shows an example of Producer/Consumer Config when the Security Protocol is `PLAINTEXT`. It can be seen that `bootstrap.servers` is set to `external.broker.com:9092`, which is the external address of the Kafka Broker, and since there are no separate authentication settings, no separate authentication information is transmitted.

#### 1.2.2. Security Protocol: `SASL_PLAINTEXT`, SASL: `PLAIN`

```properties {caption="[Config 3] Kafka server.properties for SASL_PLAINTEXT security protocol and PLAIN SASL", linenos=table}
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

[Config 3] shows an example of Kafka's `server.properties` when the Security Protocol is `SASL_PLAINTEXT` and the SASL Mechanism is `PLAIN`. It can be seen that the Listener and Inter-Broker Communication Protocol are set to `SASL_SSL`, and the SASL Mechanism is set to `PLAIN`. It can also be seen that Username and Password are configured. `username` and `password` refer to Admin User/Password for authentication between Kafka Brokers, and `user_[username]` refers to the Password of that User.

```properties {caption="[Config 4] Producer/Consumer config for SASL_PLAINTEXT security protocol and PLAIN SASL", linenos=table}
# Broker configuration
bootstrap.servers=external.broker.com:9093

# Specify the security protocol and mechanism
security.protocol=SASL_SSL
sasl.mechanism=PLAIN

# Client authentication information
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required \
  username="servicea" \
  password="servicea-password";
```

[Config 4] shows an example of Producer/Consumer Config. It can be seen that `security.protocol` and `sasl.mechanism` are set to `SASL_SSL` and `PLAIN`, and Username and Password are configured.

## 2. Kafka ACL (Access Control List)

```properties {caption="[Config 5] Kafka server.properties for ACL", linenos=table}
# Enable authorizer
authorizer.class.name=kafka.security.authorizer.AclAuthorizer

# Super Users (ACL check bypass)
super.users=User:admin

# Default behavior when ACL is not found (false recommended)
allow.everyone.if.no.acl.found=false
```

Kafka's ACL can be used to restrict which Topics and Operations each User can access. [Config 5] shows an example of Kafka's `server.properties` to enable ACL. `authorizer.class.name` must be set to `kafka.security.authorizer.AclAuthorizer` for Kafka to use ACL. `super.users` is used to specify Super Users who can access Kafka while bypassing ACL. `allow.everyone.if.no.acl.found` is used to specify default behavior when ACL is not found, and setting it to `false` denies access when ACL is not found.

```shell {caption="[Shell 6] Kafka Add User ACL", linenos=table}
kafka-acls.sh \
  --bootstrap-server <broker_address:port> \
  --<add or remove> \
  --allow-principal User:<username> \
  --operation <Operation 1> \
  --operation <Operation 2> \
  --topic <topic_name>
```

[Shell 6] shows an example of Commands to add User ACL to Kafka. Specify the Kafka Broker address in `bootstrap-server`, add ACL with `add` or remove ACL with `remove`, specify User in `allow-principal`, specify Operation in `operation`, and specify Topic in `topic`. The supported Operations are as follows.

* `Read`: Grants permission to read Messages from Topics.
* `Write`: Grants permission to write Messages to Topics.
* `Describe`: Grants permission to query Topic information.
* `Create`: Grants permission to create Topics or Consumer Groups.
* `Delete`: Grants permission to delete Topics or Consumer Groups.
* `Describe`: Grants permission to query Meta information of Topics or Consumer Groups.
* `DescribeConfigs`: Grants permission to query Topic configuration information.
* `AlterConfigs`: Grants permission to modify Topic configuration information.
* `IdempotentWrite`: Grants Idempotent write permission to prevent duplicate messages.
* `All`: Refers to all Operations.

## 3. References

* Kafka Security: [https://godekdls.github.io/Apache%20Kafka/security/](https://godekdls.github.io/Apache%20Kafka/security/)
* Kafka Security Protocol: [https://kafka.apache.org/25/javadoc/org/apache/kafka/common/security/auth/SecurityProtocol.html](https://kafka.apache.org/25/javadoc/org/apache/kafka/common/security/auth/SecurityProtocol.html)
* Kafka SASL: [https://velog.io/@limsubin/Kafka-SASLPALIN-%EC%9D%B8%EC%A6%9D-%EC%84%A4%EC%A0%95%EC%9D%84-%ED%95%B4%EB%B3%B4%EC%9E%90](https://velog.io/@limsubin/Kafka-SASLPALIN-%EC%9D%B8%EC%A6%9D-%EC%84%A4%EC%A0%95%EC%9D%84-%ED%95%B4%EB%B3%B4%EC%9E%90)
* Kafka Operation ACL Operation: [https://docs.arenadata.io/en/ADStreaming/current/how-to/kafka/access_management/authorization/acl.html](https://docs.arenadata.io/en/ADStreaming/current/how-to/kafka/access_management/authorization/acl.html)

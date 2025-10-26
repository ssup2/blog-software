---
title: Kafka JDBC Connector 실습 / Orange Pi 5 Max Cluster 환경
---

Kafka JDBC Connector를 활용해서 PostgreSQL의 Table 복제를 수행한다.

## 1. 실습 환경 구성

### 1.1. 전체 실습 환경

{{< figure caption="[Figure 1] Kafka Connect JDBC Connector 실습 환경" src="images/environment.png" width="900px" >}}

Spark를 통해서 MinIO에 저장되어 있는 데이터를 변환하는 환경은 [Figure 1]과 같다.

* **PostgreSQL** : Data 저장소 역할을 수행한다.
  * **kafka_connect_src Database, Users Table** : Data를 가져오기 위한 Source Table.
  * **kafka_connect_dst Database, Users Table** : 가져온 Data를 저장하는 Destination Table.

* **Kafka Connect** : Kafka와 PostgreSQL 사이에서 Data를 주고받는 역할을 수행한다.
  * **postgresql-src-connector Source JDBC Connector** : Source Table의 Data를 Kafka로 보내는 JDBC Connector.
  * **postgresql-dst-connector Destination JDBC Connector** : Kafka에서 가져온 Data를 Destination Table에 저장하는 JDBC Connector.

* **Kafka** : JDBC Connector를 통해서 Data를 주고받는 역할을 수행한다. 또한 Kafka Connect의 작업 상태를 저장하는 역할도 수행한다.
  * **postgresql-users Topic** : 복제된 Data를 저장하는 Topic.
  * **connect-cluster-configs** : Kafka Connect의 설정 정보를 저장하는 Topic.
  * **connect-cluster-offsets** : Kafka Connect의 오프셋 정보를 저장하는 Topic.
  * **connect-cluster-status** : Kafka Connect의 상태 정보를 저장하는 Topic.

* **Strimzi Kafka Operator** : Kafka와 Kafka Connect를 관리하는 Operator.

전체 실습 환경 구성은 다음의 링크를 참조한다.

* **Orange Pi 5 Max 기반 Kubernetes Cluster 구축** : [https://ssup2.github.io/blog-software/docs/record/orangepi5-cluster-build/](https://ssup2.github.io/blog-software/docs/record/orangepi5-cluster-build/)
* **Orange Pi 5 Max 기반 Kubernetes Data Platform 구축** : [https://ssup2.github.io/blog-software/docs/record/kubernetes-data-platform-orangepi5-cluster/](https://ssup2.github.io/blog-software/docs/record/kubernetes-data-platform-orangepi5-cluster/)

### 1.2. Kafka Connect JDBC Connector 이미지 생성

```Dockerfile {caption="[File 1] Dockerfile", linenos=table}
FROM quay.io/strimzi/kafka:0.48.0-kafka-4.1.0

USER root

# Create Kafka Connect Plugin Directory
RUN mkdir -p /opt/kafka/plugins/jdbc-connector

# Install Confluent Hub CLI and JDBC Connector
RUN curl -L --http1.1 https://client.hub.confluent.io/confluent-hub-client-latest.tar.gz \
    -o /tmp/confluent-hub-client.tar.gz && \
    tar -xzf /tmp/confluent-hub-client.tar.gz -C /tmp && \
    /tmp/bin/confluent-hub install --no-prompt confluentinc/kafka-connect-jdbc:10.7.6 \
        --component-dir /opt/kafka/plugins --worker-configs /dev/null && \
    rm -rf /tmp/confluent-hub-client.tar.gz /tmp/bin

# Download PostgreSQL JDBC Driver
RUN curl -L https://jdbc.postgresql.org/download/postgresql-42.7.1.jar \
    -o /opt/kafka/plugins/jdbc-connector/postgresql-42.7.1.jar

# Set Permissions
RUN chown -R 1001:1001 /opt/kafka/plugins

USER 1001

# Kafka Connect Plugin Path Environment Variable
ENV KAFKA_CONNECT_PLUGIN_PATH=/opt/kafka/plugins
```

```shell
docker build -t ghcr.io/ssup2-playground/k8s-data-platform_kafka-connect-jdbc-connector:0.48.0-kafka-4.1.0 .
docker push ghcr.io/ssup2-playground/k8s-data-platform_kafka-connect-jdbc-connector:0.48.0-kafka-4.1.0
```

[File 1]의 Dockerfile을 활용하여 Kafka JDBC Connector가 포함된 Container Image를 Build 및 Push한다.

### 1.3. PostgreSQL 구성

```bash
# Create Source Database
kubectl exec -it postgresql-0 -n postgresql -- psql -U postgres -c "CREATE DATABASE kafka_connect_src;"

# Create Destination Database
kubectl exec -it postgresql-0 -n postgresql -- psql -U postgres -c "CREATE DATABASE kafka_connect_dst;"

# Create users Table in Source Database
kubectl exec -it postgresql-0 -n postgresql -- psql -U postgres -d kafka_connect_src -c "
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL,
    age INTEGER
);"
```

PostgreSQL에서 `kafka_connect_src` Source Database 및 `kafka_connect_dst` Destination Database를 생성하고, `kafka_connect_src` Source Database에 `users` Table을 생성한다.

## 2. Kafka, Kafka Connect 구성

### 2.1. Kafka 구성

```yaml {caption="[File 2] kafka.yaml Manifest" linenos=table}
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaNodePool
metadata:
  name: broker
  namespace: kafka
  labels:
    strimzi.io/cluster: kafka
spec:
  replicas: 1
  roles:
    - controller
    - broker
  storage:
    type: jbod
    volumes:
      - id: 0
        type: persistent-claim
        size: 8Gi
        deleteClaim: false
        kraftMetadata: shared
  template:
    pod:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: node-group.dp.ssup2
                operator: In
                values:
                - worker
---
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: kafka
  namespace: kafka
spec:
  kafka:
    version: 4.1.0
    metadataVersion: 4.1-IV1
    listeners:
    - name: sasl
      port: 9092
      type: loadbalancer
      tls: false
      authentication:
        type: scram-sha-512
    config:
      offsets.topic.replication.factor: 1
      transaction.state.log.replication.factor: 1
      transaction.state.log.min.isr: 1
      default.replication.factor: 1
      min.insync.replicas: 1
  entityOperator:
    template:
      pod:
        affinity:
          nodeAffinity:
            requiredDuringSchedulingIgnoredDuringExecution:
              nodeSelectorTerms:
              - matchExpressions:
                - key: node-group.dp.ssup2
                  operator: In
                  values:
                  - worker
    topicOperator: {}
    userOperator: {}
---
apiVersion: v1
kind: Secret
metadata:
  name: kafka-user-credentials
  namespace: kafka
type: Opaque
data:
  password: dXNlcg==
---
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaUser
metadata:
  name: user
  namespace: kafka
  labels:
    strimzi.io/cluster: kafka
spec:
  authentication:
    type: scram-sha-512
    password:
      valueFrom:
        secretKeyRef:
          name: kafka-user-credentials
          key: password
```

```shell
kubectl apply -f kafka.yaml
```

[File 2]의 Kafka Manifest를 적용하여, Strimzi Kafka Operator가 Kafka를 구성하도록 만든다.

### 2.1. Kafka Connect 구성

```yaml {caption="[File 3] kafka-connect.yaml" linenos=table}
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaConnect
metadata:
  name: kafka-connect
  namespace: kafka
  annotations:
    strimzi.io/use-connector-resources: "true"
spec:
  version: 4.1.0
  replicas: 1
  image: ghcr.io/ssup2-playground/k8s-data-platform_kafka-connect:0.48.0-kafka-4.1.0
  bootstrapServers: kafka-kafka-sasl-bootstrap.kafka:9092
  authentication:
    type: scram-sha-512
    username: user
    passwordSecret:
      secretName: kafka-user-credentials
      password: password
  config:
    group.id: connect-cluster
    offset.storage.topic: connect-cluster-offsets
    config.storage.topic: connect-cluster-configs
    status.storage.topic: connect-cluster-status
    config.storage.replication.factor: -1
    offset.storage.replication.factor: -1
    status.storage.replication.factor: -1
  template:
    pod:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: node-group.dp.ssup2
                operator: In
                values:
                - worker
```

```shell
kubectl apply -f kafka-connect.yaml
```

[File 3]의 Kafka Connect Manifest를 적용하여, Strimzi Kafka Operator가 Kafka Connect를 구성하도록 만든다. `4.1.0` Version을 명시하고 있고, `connect-cluster` Group ID를 사용한다. `connect-cluster-offsets`, `connect-cluster-configs`, `connect-cluster-status` Topic을 통해서 Kafka Connect의 작업 상태를 저장한다.

### 2.3. Kafka Connect JDBC Connector 구성

```yaml {caption="[File 4] postgresql-src-connector.yaml Manifest" linenos=table}
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaConnector
metadata:
  name: postgresql-src-connector
  namespace: kafka
  labels:
    strimzi.io/cluster: kafka-connect
spec:
  class: io.confluent.connect.jdbc.JdbcSourceConnector
  tasksMax: 1
  config:
    # DB Connection
    connection.url: jdbc:postgresql://postgresql.postgresql:5432/kafka_connect_src
    connection.user: postgres
    connection.password: root123!
    connection.attempts: 3
    connection.backoff.ms: 10000

    # Replication
    mode: incrementing
    table.whitelist: users
    topic.prefix: postgresql-
    incrementing.column.name: id

    # Error Handling
    errors.retry.timeout: 300000 
    errors.retry.delay.max.ms: 60000     
    errors.tolerance: all                   
    errors.log.enable: true      
    errors.log.include.messages: true    
```

```shell
kubectl apply -f postgresql-src-connector.yaml
```

[File 4]의 Kafka Connector Manifest를 적용하여, Kafka Connect가 `kafka_connect_src` Source Database의 `users` Table의 Data를 Kafka로 보내도록 만든다.

```yaml {caption="[File 5] postgresql-dst-connector.yaml Manifest" linenos=table}
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaConnector
metadata:
  name: postgresql-dst-connector
  namespace: kafka
  labels:
    strimzi.io/cluster: kafka-connect
spec:
  class: io.confluent.connect.jdbc.JdbcSinkConnector
  tasksMax: 1
  config:
    # DB Connection
    connection.url: jdbc:postgresql://postgresql.postgresql:5432/kafka_connect_dst
    connection.user: postgres
    connection.password: root123!
    connection.attempts: 3
    connection.backoff.ms: 10000

    # Replication
    topics: postgresql-users
    table.name.format: users
    insert.mode: upsert
    pk.mode: record_value
    pk.fields: id
    auto.create: true
    auto.evolve: true

    # Error Handling
    errors.retry.timeout: 300000 
    errors.retry.delay.max.ms: 60000     
    errors.tolerance: all                   
    errors.log.enable: true      
    errors.log.include.messages: true    
```

```shell
kubectl apply -f postgresql-dst-connector.yaml
```

[File 5]의 Kafka Connector Manifest를 적용하여, Kafka Connect가 Kafka의 `postgresql-users` Topic에서 가져온 Data를 `kafka_connect_dst` Destination Database의 `users` Table에 저장하도록 만든다.

### 2.5. Data 복제 실습

```bash
kubectl exec -it postgresql-0 -n postgresql -- psql -U postgres -d kafka_connect_src -c "
INSERT INTO users (name, email, age) VALUES 
('John Doe', 'john@ssup2.com', 30),
('Jane Smith', 'jane@ssup2.com', 25),
('Bob Johnson', 'bob@ssup2.com', 35),
('Alice Brown', 'alice@ssup2.com', 28),
('Charlie Wilson', 'charlie@ssup2.com', 32);"
```

`kafka_connect_src` Source Database의 `users` Table에 Data를 추가한다.

```bash
kubectl exec -it postgresql-0 -n postgresql -- psql -U postgres -d kafka_connect_dst -c "SELECT * FROM users;"
```
```bash
id |      name      |       email       | age 
----+----------------+-------------------+-----
  1 | John Doe       | john@ssup2.com    |  30
  2 | Jane Smith     | jane@ssup2.com    |  25
  3 | Bob Johnson    | bob@ssup2.com     |  35
  4 | Alice Brown    | alice@ssup2.com   |  28
  5 | Charlie Wilson | charlie@ssup2.com |  32
```

`kafka_connect_dst` Destination Database의 `users` Table에 Data가 저장되었는지 확인한다.

## 3. 참고

* Strimzi Kafka Operator : [https://togomi.tistory.com/66](https://togomi.tistory.com/66)

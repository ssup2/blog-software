---
title: Kafka JDBC Connector Practice / Orange Pi 5 Max Cluster Environment
---

Perform PostgreSQL table replication using Kafka JDBC Connector.

## 1. Practice Environment Setup

### 1.1. Overall Practice Environment

{{< figure caption="[Figure 1] Kafka Connect JDBC Connector Practice Environment" src="images/environment.png" width="900px" >}}

The environment for transforming data stored in MinIO through Spark is as shown in [Figure 1].

* **PostgreSQL** : Performs the role of data storage.
  * **kafka_connect_src Database, Users Table** : Source table for retrieving data.
  * **kafka_connect_dst Database, Users Table** : Destination table for storing retrieved data.

* **Kafka Connect** : Performs the role of exchanging data between Kafka and PostgreSQL.
  * **postgresql-src-connector Source JDBC Connector** : JDBC connector that sends data from source table to Kafka.
  * **postgresql-dst-connector Destination JDBC Connector** : JDBC connector that stores data retrieved from Kafka into destination table.

* **Kafka** : Performs the role of exchanging data through JDBC connectors. Also performs the role of storing Kafka Connect's work status.
  * **postgresql-users Topic** : Topic for storing replicated data.
  * **connect-cluster-configs** : Topic for storing Kafka Connect's configuration information.
  * **connect-cluster-offsets** : Topic for storing Kafka Connect's offset information.
  * **connect-cluster-status** : Topic for storing Kafka Connect's status information.

* **Strimzi Kafka Operator** : Operator for managing Kafka and Kafka Connect.

Refer to the following links for the overall practice environment setup.

* **Orange Pi 5 Max based Kubernetes Cluster Construction** : [https://ssup2.github.io/blog-software/docs/record/orangepi5-cluster-build/](https://ssup2.github.io/blog-software/docs/record/orangepi5-cluster-build/)
* **Orange Pi 5 Max based Kubernetes Data Platform Construction** : [https://ssup2.github.io/blog-software/docs/record/kubernetes-data-platform-orangepi5-cluster/](https://ssup2.github.io/blog-software/docs/record/kubernetes-data-platform-orangepi5-cluster/)

### 1.2. Kafka Connect JDBC Connector Image Creation

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

Build and push a container image containing Kafka JDBC Connector using the Dockerfile in [File 1].

### 1.3. PostgreSQL Configuration

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

Create `kafka_connect_src` source database and `kafka_connect_dst` destination database in PostgreSQL, and create a `users` table in the `kafka_connect_src` source database.

## 2. Kafka, Kafka Connect Configuration

### 2.1. Kafka Configuration

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

Apply the Kafka Manifest in [File 2] to have the Strimzi Kafka Operator configure Kafka.

### 2.1. Kafka Connect Configuration

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

Apply the Kafka Connect Manifest in [File 3] to have the Strimzi Kafka Operator configure Kafka Connect. Version `4.1.0` is specified, and `connect-cluster` Group ID is used. Kafka Connect's work status is stored through `connect-cluster-offsets`, `connect-cluster-configs`, and `connect-cluster-status` topics.

### 2.3. Kafka Connect JDBC Connector Configuration

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

Apply the Kafka Connector Manifest in [File 4] to have Kafka Connect send data from the `users` table in the `kafka_connect_src` source database to Kafka.

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

Apply the Kafka Connector Manifest in [File 5] to have Kafka Connect store data retrieved from the `postgresql-users` topic in Kafka into the `users` table in the `kafka_connect_dst` destination database.

### 2.5. Data Replication Practice

```bash
kubectl exec -it postgresql-0 -n postgresql -- psql -U postgres -d kafka_connect_src -c "
INSERT INTO users (name, email, age) VALUES 
('John Doe', 'john@ssup2.com', 30),
('Jane Smith', 'jane@ssup2.com', 25),
('Bob Johnson', 'bob@ssup2.com', 35),
('Alice Brown', 'alice@ssup2.com', 28),
('Charlie Wilson', 'charlie@ssup2.com', 32);"
```

Add data to the `users` table in the `kafka_connect_src` source database.

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

Check if data has been stored in the `users` table in the `kafka_connect_dst` destination database.

## 3. References

* Strimzi Kafka Operator : [https://togomi.tistory.com/66](https://togomi.tistory.com/66)

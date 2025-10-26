---
title: Kafka JDBC Connector 실습 / Orange Pi 5 Max Cluster 환경
draft: true
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

전체 실슴 환경 구성은 다음의 링크를 참조한다.

* **Orange Pi 5 Max 기반 Kubernetes Cluster 구축** : [https://ssup2.github.io/blog-software/docs/record/orangepi5-cluster-build/](https://ssup2.github.io/blog-software/docs/record/orangepi5-cluster-build/)
* **Orange Pi 5 Max 기반 Kubernetes Data Platform 구축** : [https://ssup2.github.io/blog-software/docs/record/kubernetes-data-platform-orangepi5-cluster/](https://ssup2.github.io/blog-software/docs/record/kubernetes-data-platform-orangepi5-cluster/)

### 1.2. Kafka Connect JDBC Connector 이미지 생성

```Dockerfile {caption="[File 1] Dockerfile", linenos=table}
FROM quay.io/strimzi/kafka:0.48.0-kafka-4.1.0

USER root

# Kafka Connect 플러그인 디렉토리 생성
RUN mkdir -p /opt/kafka/plugins/jdbc-connector

# Confluent Hub CLI 설치 및 JDBC Connector 설치
RUN curl -L --http1.1 https://client.hub.confluent.io/confluent-hub-client-latest.tar.gz \
    -o /tmp/confluent-hub-client.tar.gz && \
    tar -xzf /tmp/confluent-hub-client.tar.gz -C /tmp && \
    /tmp/bin/confluent-hub install --no-prompt confluentinc/kafka-connect-jdbc:10.7.6 \
        --component-dir /opt/kafka/plugins --worker-configs /dev/null && \
    rm -rf /tmp/confluent-hub-client.tar.gz /tmp/bin

# PostgreSQL JDBC 드라이버 다운로드
RUN curl -L https://jdbc.postgresql.org/download/postgresql-42.7.1.jar \
    -o /opt/kafka/plugins/jdbc-connector/postgresql-42.7.1.jar

# 권한 설정
RUN chown -R 1001:1001 /opt/kafka/plugins

USER 1001

# Kafka Connect 플러그인 경로 환경변수 설정
ENV KAFKA_CONNECT_PLUGIN_PATH=/opt/kafka/plugins
```

[File 1]의 Dockerfile을 생성하여 Kafka JDBC Connector Container Image를 생성한다.

```shell
docker build -t ghcr.io/ssup2-playground/k8s-data-platform_kafka-connect-jdbc-connector:0.48.0-kafka-4.1.0 .
docker push ghcr.io/ssup2-playground/k8s-data-platform_kafka-connect-jdbc-connector:0.48.0-kafka-4.1.0
```
 Container Image Build 및 Push를 수행한다.


## 2. Kafka, Kafka Connect 구성

### 2.1. Kafka Connect 구성

```yaml {caption="[File 2] kafka-connect.yaml" linenos=table}
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

[File 2]의 Kafka Connect Manifest를 생성 및 적용하여, Strimzi Kafka Operator가 Kafka Connect를 구성하도록 만든다.

```shell
kubectl apply -f kafka-connect.yaml
```

### 2.3. Kafka Connect JDBC Connector 구성

```yaml
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

```yaml
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

### 2.4. PostgreSQL 데이터베이스 구성

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgresql-init-script
  namespace: kafka
data:
  init.sql: |
    -- Source Database (kafka_connect_src)
    CREATE DATABASE kafka_connect_src;
    \c kafka_connect_src;
    
    CREATE TABLE users (
        id SERIAL PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        email VARCHAR(100) UNIQUE NOT NULL,
        age INTEGER,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    
    -- Sample data for source database
    INSERT INTO users (name, email, age) VALUES 
    ('John Doe', 'john@ssup2.com', 30),
    ('Jane Smith', 'jane@ssup2.com', 25),
    ('Bob Johnson', 'bob@ssup2.com', 35),
    ('Alice Brown', 'alice@ssup2.com', 28),
    ('Charlie Wilson', 'charlie@ssup2.com', 32);
    
    -- Destination Database (kafka_connect_dst)
    CREATE DATABASE kafka_connect_dst;
    \c kafka_connect_dst;
    
    -- Destination table will be auto-created by Kafka Connect Sink Connector
    -- But we can create it manually for reference:
    CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        email VARCHAR(100) UNIQUE NOT NULL,
        age INTEGER,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgresql
  namespace: kafka
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgresql
  template:
    metadata:
      labels:
        app: postgresql
    spec:
      containers:
      - name: postgresql
        image: postgres:15
        env:
        - name: POSTGRES_DB
          value: postgres
        - name: POSTGRES_USER
          value: postgres
        - name: POSTGRES_PASSWORD
          value: root123!
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: postgresql-storage
          mountPath: /var/lib/postgresql/data
        - name: init-script
          mountPath: /docker-entrypoint-initdb.d
      volumes:
      - name: postgresql-storage
        emptyDir: {}
      - name: init-script
        configMap:
          name: postgresql-init-script
---
apiVersion: v1
kind: Service
metadata:
  name: postgresql-service
  namespace: kafka
spec:
  selector:
    app: postgresql
  ports:
  - port: 5432
    targetPort: 5432
    protocol: TCP
  type: ClusterIP
```

### 2.5. 실습 명령어

#### 2.5.1. PostgreSQL 데이터베이스 및 테이블 생성

```bash
# Source 데이터베이스 생성
kubectl exec -it postgresql-0 -n postgresql -- psql -U postgres -c "CREATE DATABASE kafka_connect_src;"

# Destination 데이터베이스 생성
kubectl exec -it postgresql-0 -n postgresql -- psql -U postgres -c "CREATE DATABASE kafka_connect_dst;"

# Source 데이터베이스에 users 테이블 생성
kubectl exec -it postgresql-0 -n postgresql -- psql -U postgres -d kafka_connect_src -c "
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL,
    age INTEGER
);"

# Source 데이터베이스에 샘플 데이터 삽입
kubectl exec -it postgresql-0 -n postgresql -- psql -U postgres -d kafka_connect_src -c "
INSERT INTO users (name, email, age) VALUES 
('John Doe', 'john@ssup2.com', 30),
('Jane Smith', 'jane@ssup2.com', 25),
('Bob Johnson', 'bob@ssup2.com', 35),
('Alice Brown', 'alice@ssup2.com', 28),
('Charlie Wilson', 'charlie@ssup2.com', 32);"

# Destination 데이터베이스에 users 테이블 생성 (Sink Connector가 자동 생성하지만 참고용)
kubectl exec -it postgresql-0 -n postgresql -- psql -U postgres -d kafka_connect_dst -c "
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    age INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);"
```

#### 2.5.2. PostgreSQL 연결 및 테이블 확인

```bash
# PostgreSQL Pod에 접속
kubectl exec -it postgresql-0 -n postgresql -- psql -U postgres

# Source 데이터베이스 확인
\c kafka_connect_src
\dt
SELECT * FROM users;

# Destination 데이터베이스 확인
\c kafka_connect_dst
\dt
SELECT * FROM users;
```

#### 2.5.3. Kafka Connect 상태 확인

```bash
# Kafka Connect Pod 상태 확인
kubectl get pods -n kafka | grep connect

# Kafka Connect 로그 확인
kubectl logs -f deployment/kafka-connect-connect -n kafka

# Connector 상태 확인
kubectl get kafkaconnector -n kafka
kubectl describe kafkaconnector postgresql-src-connector -n kafka
kubectl describe kafkaconnector postgresql-dst-connector -n kafka
```

#### 2.5.4. Kafka 토픽 확인

```bash
# Kafka 토픽 목록 확인
kubectl exec -it kafka-kafka-0 -n kafka -- bin/kafka-topics.sh --bootstrap-server localhost:9092 --list

# postgresql-users 토픽 메시지 확인
kubectl exec -it kafka-kafka-0 -n kafka -- bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic postgresql-users --from-beginning
```

#### 2.5.5. 데이터 변경 테스트

```bash
# Source 데이터베이스에 새 사용자 추가
kubectl exec -it postgresql-0 -n postgresql -- psql -U postgres -d kafka_connect_src -c "
INSERT INTO users (name, email, age) VALUES 
('Test User', 'test@ssup2.com', 27);
"

# Destination 데이터베이스에서 변경사항 확인
kubectl exec -it postgresql-0 -n postgresql -- psql -U postgres -d kafka_connect_dst -c "
SELECT * FROM users ORDER BY id;
"
```

## 3. 참고

* Strimzi Kafka Operator : [https://togomi.tistory.com/66](https://togomi.tistory.com/66)

---
title: Kafka Connect JDBC Connector 실습 / Orange Pi 5 Max Cluster 환경
draft: true
---

Kafka Connect와 JDBC Connector를 활용해서 PostgreSQL의 Table 복제를 수행한다.

## 1. 실습 환경 구성

```
FROM quay.io/strimzi/kafka:0.48.0-kafka-4.1.0

USER root

# Kafka Connect 플러그인 디렉토리 생성
RUN mkdir -p /opt/kafka/plugins/jdbc-connector

# Confluent JDBC Connector 다운로드
RUN curl -L https://packages.confluent.io/maven/io/confluent/kafka-connect-jdbc/10.7.4/kafka-connect-jdbc-10.7.4.jar \
    -o /opt/kafka/plugins/jdbc-connector/kafka-connect-jdbc-10.7.4.jar

# PostgreSQL JDBC 드라이버 다운로드
RUN curl -L https://jdbc.postgresql.org/download/postgresql-42.7.1.jar \
    -o /opt/kafka/plugins/jdbc-connector/postgresql-42.7.1.jar

# 권한 설정
RUN chown -R 1001:1001 /opt/kafka/plugins

USER 1001

# Kafka Connect 플러그인 경로 환경변수 설정
ENV KAFKA_CONNECT_PLUGIN_PATH=/opt/kafka/plugins
```

## 2. Kafka, Kafka Connect 구성

### 2.1. Kafka Cluster 구성

```yaml
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

### 2.2. Kafka Connect 구성

```yaml
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
  tasksMax: 2
  config:
    connection.url: jdbc:postgresql://postgresql.postgresql:5432/kafka_connect_src
    connection.user: postgres
    connection.password: root123!
    mode: incrementing
    incrementing.column.name: id
    table.whitelist: users
    topic.prefix: postgresql-
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
  tasksMax: 2
  config:
    connection.url: jdbc:postgresql://postgresql.postgresql:5432/kafka_connect_dst
    connection.user: postgres
    connection.password: root123!
    topics: postgresql-users
    insert.mode: insert
    auto.create: true
    auto.evolve: true
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
    email VARCHAR(100) UNIQUE NOT NULL,
    age INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
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

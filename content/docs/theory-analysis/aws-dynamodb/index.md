---
title: AWS DynamoDB
---

AWS의 DynamoDB Service를 분석한다. **DynamoDB Service**는 Managed Key-value Data 또는 Documented Data 저장을 지원하는 Managed NoSQL DB Service이다.

## 1. Table

{{< figure caption="[Figure 1] DynamoDB Table" src="images/aws-dynamodb-basetable.png" width="1000px" >}}

[Figure 1]은 DynamoDB의 Table을 나타내고 있다. Table은 **Item**의 집합으로 구성되어 있다.

### 1.1. Item

Item은 Table의 **Row** 역할을 수행한다. 각 Item은 **Primary Key**와 **Attribute**로 구성되어 있다.

### 1.2. Primary Key

Primary Key는 Table에서 반드시 고유한 값을 가져야 한다. Primary Key는 **Partition Key** 또는 **Partition Key** + **Sort Key**로 구성되어 있다. 즉 Partition Key는 필수 요소지만 Sort Key는 필수 요소가 아니다.

#### 1.2.1. Partition Key

Partition Key는 이름 그대로 Item이 위치할 Disk의 Partition를 결정하는 Key이다. [Figure 1]에서 `USER#1111`를 Partition Key로 갖는 3개의 Item은 모두 동일한 Disk의 Partition에 위치하게 된다. DynamoDB는 Parition Key를 기반으로 **Consistent Hashing**을 이용하여 Disk의 Partition을 결정하는 것으로 알려져 있다.

DynamoDB의 성능을 끌어올리기 위해서는 Item들을 여러 Disk의 Parition으로 분배하여 각 Disk Partition의 성능을 이끌어내야 한다. 따라서 Partition Key를 잘 설계하여 Item들이 다수의 Disk Partition으로 골고루 분배되도록 설계해야 한다. 만약 요청이 하나의 Partition Key 또는 하나의 Disk Partition으로 쏠릴경우 Throttling이 발생하여 일시적으로 Data Read/Write 동작이 수행되지 않을 수 있다.

Partition Key는 `=`, `!=`과 같은 비교 연산자만 이용할 수 있다.

#### 1.2.2. Sort Key

Sort Key는 이름 그대로 Disk 내부의 Partition에서 Column을 정렬하는데 이용하는 Key이다. Sort Key를 기반으로 내부적으로 Index를 생성하기 때문에 비교 연산자와 `>`, `<=`과 같은 범위 연산를 이용할 수 있다. 따라서 DynamoDB에서 정렬과 같은 동작을 수행하기 위해서는 반드시 Sort Key를 활용해야 한다.

### 1.3. Attribute

Attribute는 Table의 **Column** 역할을 수행한다. 각 Item마다 다른 Attribute를 갖을 수 있다. [Figure 1]에서 첫번째 Item에서는 `Email Address`, `Total Amount`, `Phone`을 Attribute를 갖고 있고, 두번째 Item에서는 `Purchase Price`, `Purchase Count`를 Attribute로 가지고 있다. 서로 다른 Attribute를 갖고 있는 것을 확인할 수 있다.

일반적인 Attribute를 대상으로는 비교 연산자, 또는 범위 연산자를 이용할 수 없고, **LSI (Local Secondary Index)** 또는 **GSI** (Global Secondary Index)와 같은 Secondary Index를 생성하고 이용해야 한다.

## 2. Secondary Index

Secondary Index는 Table 생성시 Sort Key로 인해서 생성되는 Index와 별개의 Index가 필요할 경우 이용할 수 있는 기능이다. LSI (Local Secondary Index)와 GSI (Global Secondary Index)가 존재한다. Secondary Index의 경우에도 Partition Key와 Sort Key의 조합으로 구성된 Primary Key가 반드시 존재하며, Secondary Index를 생성하기 위해서 참조하는 원본의 Table을 **Base Table**이라고 명칭한다.

### 2.1. LSI (Local Secondary Index)

{{< figure caption="[Figure 2] DynamoDB LSI" src="images/aws-dynamodb-lsi.png" width="800px" >}}

[Figure 2]은 [Figure 1]의 Table을 Base Table로 하여 생성한 LSI의 예제를 나타내고 있다. LSI의 Partition Key는 반드시 Base Table의 Partition Key와 동일해야 한다. 하지만 Sort Key의 경우에는 Base Table의 임의의 Attribute를 선택하여 이용할 수 있다. [Figure 2]에서도 [Figure 1]과 Partition Key는 `PK`로 동일하지만, Sort Key는 Base Table의 `Created Date` Attribute를 `LSI_SK`라는 이름으로 이용하고 있다.

LSI 구성시 Base Table의 전체 또는 일부 Attribute들을 Projection 수행을 통해서 LSI의 Projected Attribute로 가져올 수 있다. [Figure 2]에서는 `Email Address`, `Purchase Price`, `Purchase Count`, `Count` 4개의 Attribute를 Projected Attribute로 이용하고 있다. LSI의 경우에는 Projected Attribute로 존재하지 않더라도 Base Table에서 Attribute를 가져올 수 있는 장점을 가지고 있다. 하지만 Base Table을 한번더 읽으면서 비용이 추가적으로 발생하고 성능도 느려지는 문제가 있기 때문에, LSI를 이용하는 경우에는 가능하면 Projected Attribute만 이용하는 것이 권장된다.

LSI의 Read 동작은 Base Table의 RCU (Read Capacity Unit)를 소모한다. Base Table의 Write 동작이 발생하면 LSI에도 Write된 내용이 반영되며 이경우에도 Base Table의 WCU (Write Capacity Unit)를 소모하며, Base Table, LSI 두번 Write를 수행하기 때문에 WCU도 두배 많이 소모된다.

LSI는 (Base) Table을 생성할 경우에만 설정을 통해서 같이 생성이 가능하며, (Base) Table 생성 이후에는 생성, 삭제가 불가능하다. 또한 하나의 Base Table당 최대 5개의 LSI만 생성 가능하며, LSI의 하나의 Partiton의 크기는 10GB를 넘지 못한다는 제약조건을 가지고 있다. 하지만 LSI는 **Strongly-Consistency Read**를 지원하고, Base Table의 RCU, WCU를 소모하기 때문에 Provisioned Capacity Mode를 이용하는 경우 별도의 RCU, WCU를 소모하는 GSI에 대비하여 비용 절감효과를 얻을 수 있다는 장점을 가지고 있다.

### 2.2. GSI (Global Secondary Index)

{{< figure caption="[Figure 3] DynamoDB GSI" src="images/aws-dynamodb-gsi.png" width="750px" >}}

[Figure 3]은 [Figure 1]의 Table을 Base Table로 하여 생성한 GSI의 예제를 나타내고 있다. GSI의 Partition Key와 Sort Key는 Base Table의 임의의 Attribute를 선택하여 구성할 수 있다.

## 3. Capacity Mode

DynamoDB는 Table의 Read/Write 용량을 관리하는 방식으로 **Provisioned Mode**와 **On-demand Mode** 두 가지 Capacity Mode를 제공한다. Capacity Mode는 Table 단위로 지정하며 Table 생성 이후에도 변경할 수 있다.

### 3.1. Provisioned Mode

Provisioned Mode는 Table이 이용할 용량을 **RCU** (Read Capacity Unit)와 **WCU** (Write Capacity Unit) 단위로 미리 지정하는 Mode이다. 1 RCU는 최대 4KB 크기의 Item에 대한 초당 한번의 Strongly Consistent Read를 의미하며, Eventually Consistent Read는 절반인 0.5 RCU만 소모한다. 1 WCU는 최대 1KB 크기의 Item에 대한 초당 한번의 Write를 의미한다. Transaction을 이용하는 Read/Write는 두배의 RCU/WCU를 소모한다.

지정한 RCU/WCU를 초과하는 요청이 발생하면 Throttling이 발생하여 요청이 거부되며, Auto Scaling을 함께 이용하면 목표 사용률을 기준으로 RCU/WCU가 자동으로 조정된다. 트래픽이 일정하고 예측 가능한 경우에는 On-demand Mode에 비해서 저렴하게 이용할 수 있다.

### 3.2. On-demand Mode

On-demand Mode는 용량을 미리 지정하지 않고 실제로 수행한 Read/Write 요청의 횟수에 비례하여 비용이 발생하는 Mode이다. DynamoDB가 트래픽에 맞추어 용량을 자동으로 조정하며 직전 Peak 트래픽의 두배까지는 즉시 수용하지만, 짧은 시간에 직전 Peak의 두배를 초과하는 트래픽이 유입되면 Throttling이 발생할 수 있다. 트래픽 예측이 어렵거나 변동 폭이 큰 경우에 적합하다.

## 4. Data Type

DynamoDB의 Data Type은 Scalar, Document, Set 3가지로 분류할 수 있다. 각 분류마다 아래의 Data Type들이 존재한다.

* **Scalar** : String, Number, Binary, Boolean, Null
* **Document** : List, Map
* **Set** : String Set, Number Set, Binary Set

## 5. Consistency

DynamoDB는 Write 수행시 Data를 하나의 Region 내부의 다수의 AZ에 위치하는 복제본에 저장한다. Write 요청은 모든 복제본에 반영되기 전에 성공으로 응답하고 나머지 복제본에는 비동기로 전파되기 때문에, Read를 수행하는 복제본에 따라서 최신 Write가 반영되지 않은 Data를 읽을 수 있다. 이를 제어하기 위해서 DynamoDB는 두 가지 Read Consistency를 제공한다.

* **Eventually Consistent Read** : 기본 Read 방식이며 임의의 복제본에서 Read를 수행한다. 따라서 직전 Write가 반영되지 않은 이전 Data가 반환될 수 있다. Strongly Consistent Read의 절반인 0.5 RCU를 소모한다.
* **Strongly Consistent Read** : 가장 최신의 Write가 반영된 Data의 반환을 보장하는 Read 방식이다. 1 RCU를 소모하며 Eventually Consistent Read에 비해서 Latency가 상대적으로 높다. Base Table과 LSI에서만 이용 가능하며, GSI는 Eventually Consistent Read만 지원한다.

## 6. DAX (DynamoDB Accelerator)

**DAX**는 DynamoDB 전용의 Managed In-memory Cache Cluster이다. DynamoDB의 Read Latency는 Millisecond 수준이지만 DAX의 Cache에 존재하는 Data는 Microsecond 수준의 Latency로 Read할 수 있다. DAX는 DynamoDB API와 호환되기 때문에 App은 DAX Client를 이용하면 큰 코드 수정 없이 DAX를 이용할 수 있다. DAX Cluster는 User의 VPC 내부에 위치하며 하나의 Primary Node와 다수의 Read Replica Node로 구성된다.

DAX는 Write-through 방식으로 동작하여 App의 Write 요청을 DynamoDB와 DAX의 Cache에 모두 반영한 다음에 응답한다. Cache는 `GetItem`, `BatchGetItem`의 결과를 저장하는 **Item Cache**와 `Query`, `Scan`의 결과를 저장하는 **Query Cache**로 분리되어 있으며, Cache된 Data는 지정한 TTL (기본 5분) 동안 유지된다.

DAX는 Eventually Consistent Read만 Cache에서 처리한다. Strongly Consistent Read 요청은 DAX가 DynamoDB로 그대로 전달하며 반환된 결과도 Cache에 저장하지 않는다.

## 7. TTL

**TTL**은 Item마다 만료 시각을 지정하고 만료된 Item을 자동으로 삭제하는 기능이다. Table의 특정 Attribute를 TTL Attribute로 지정하면, DynamoDB는 해당 Attribute에 저장된 초 단위의 Unix Timestamp와 현재 시각을 비교하여 만료된 Item을 Background에서 삭제한다. TTL로 인한 삭제는 WCU를 소모하지 않기 때문에 비용 없이 불필요한 Data를 정리할 수 있으며, 삭제된 Item은 LSI, GSI에서도 함께 제거된다.

만료된 Item은 즉시 삭제되지 않고 일반적으로 만료 이후 수일 이내에 삭제된다. 따라서 만료되었지만 아직 삭제되지 않은 Item이 Read, Query, Scan의 결과에 포함될 수 있으며, 이러한 Item을 제외하기 위해서는 Filter Expression을 이용해야 한다. DynamoDB Streams를 이용하는 경우 TTL로 인한 삭제 Event도 Stream에 기록되기 때문에 만료된 Item의 후처리에 활용할 수 있다.

## 8. Locking

DynamoDB는 별도의 Lock 기능을 제공하지 않으며, 조건을 만족하는 경우에만 Write를 수행하는 **Conditional Write**를 통해서 Optimistic Locking을 구현할 수 있다. Item에 Version을 나타내는 Attribute를 두고 Read시 Version 값을 함께 읽은 다음, Write시 Version 값이 Read 시점과 동일한 경우에만 Write와 Version 증가를 수행하도록 조건을 지정한다. 다른 Client가 먼저 Write를 수행하여 Version 값이 변경된 경우에는 조건 검사가 실패하여 `ConditionalCheckFailedException`이 발생하며, Client는 Item을 다시 Read한 다음에 Write를 재시도해야 한다.

AWS SDK for Java의 DynamoDBMapper는 `@DynamoDBVersionAttribute` Annotation을 통해서 위의 Optimistic Locking 과정을 자동으로 처리한다. Pessimistic Locking이 필요한 경우에는 AWS에서 제공하는 DynamoDB Lock Client Library를 이용하여 Lease 기반의 Lock을 구현할 수 있다.

## 9. REST API

DynamoDB는 전용 Protocol과 Connection을 이용하는 일반적인 DB와 다르게 **HTTPS 기반의 REST API**를 통해서 모든 동작을 수행한다. 각 요청은 독립적인 HTTP 요청으로 전달되며, `X-Amz-Target` Header에 수행할 Operation을 명시하고 JSON 형식의 Body에 Operation의 Parameter를 담아 AWS Signature V4 방식으로 서명하여 전송한다. `GetItem`, `PutItem`, `UpdateItem`, `DeleteItem`, `Query`, `Scan`과 같은 Operation이 제공되며, AWS SDK와 AWS CLI도 내부적으로는 모두 REST API를 호출한다.

Persistent Connection과 Connection Pool의 관리가 필요 없기 때문에, AWS Lambda와 같이 생명주기가 짧은 Serverless 환경에서도 Connection 유지에 대한 부담 없이 DynamoDB를 이용할 수 있다.

## 10. 참조

* Amazon DynamoDB 키 디자인 패턴 : [https://www.youtube.com/watch?v=I7zcRxHbo98](https://www.youtube.com/watch?v=I7zcRxHbo98)
* Single Table Design : [https://emshea.com/post/part-1-dynamodb-single-table-design](https://emshea.com/post/part-1-dynamodb-single-table-design)
* Secondary Index : [https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/SecondaryIndexes.html](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/SecondaryIndexes.html)
* Secondary Index : [https://www.dynamodbguide.com/local-or-global-choosing-a-secondary-index-type-in-dynamo-db](https://www.dynamodbguide.com/local-or-global-choosing-a-secondary-index-type-in-dynamo-db)
* Secondary Index : [https://stackoverflow.com/questions/21381744/difference-between-local-and-global-indexes-in-dynamodb](https://stackoverflow.com/questions/21381744/difference-between-local-and-global-indexes-in-dynamodb)
* Architecture : [https://medium.com/swlh/architecture-of-amazons-dynamodb-and-why-its-performance-is-so-high-31d4274c3129](https://medium.com/swlh/architecture-of-amazons-dynamodb-and-why-its-performance-is-so-high-31d4274c3129)
* Read/Write Capacity Mode : [https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/HowItWorks.ReadWriteCapacityMode.html](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/HowItWorks.ReadWriteCapacityMode.html)
* Read Consistency : [https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/HowItWorks.ReadConsistency.html](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/HowItWorks.ReadConsistency.html)
* DAX : [https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/DAX.html](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/DAX.html)
* TTL : [https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/TTL.html](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/TTL.html)
* Optimistic Locking : [https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/DynamoDBMapper.OptimisticLocking.html](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/DynamoDBMapper.OptimisticLocking.html)
* Low-Level API : [https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Programming.LowLevelAPI.html](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Programming.LowLevelAPI.html)
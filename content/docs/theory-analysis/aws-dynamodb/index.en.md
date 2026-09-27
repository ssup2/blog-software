---
title: AWS DynamoDB
---

This post analyzes AWS's DynamoDB Service. **DynamoDB Service** is a Managed NoSQL DB Service that supports storing Managed Key-value Data or Documented Data.

## 1. Table

{{< figure caption="[Figure 1] DynamoDB Table" src="images/aws-dynamodb-basetable.png" width="1000px" >}}

[Figure 1] shows a Table of DynamoDB. A Table consists of a collection of **Items**.

### 1.1. Item

An Item serves as a **Row** of a Table. Each Item consists of a **Primary Key** and **Attributes**.

### 1.2. Primary Key

The Primary Key must have a unique value within a Table. The Primary Key consists of a **Partition Key** or a **Partition Key** + **Sort Key**. That is, the Partition Key is a required element, but the Sort Key is not.

#### 1.2.1. Partition Key

The Partition Key, as its name suggests, is the Key that determines the Disk Partition where an Item is located. In [Figure 1], the three Items that have `USER#1111` as their Partition Key are all located in the same Disk Partition. DynamoDB is known to determine the Disk Partition by using **Consistent Hashing** based on the Partition Key.

To maximize DynamoDB's performance, Items must be distributed across multiple Disk Partitions to draw out the performance of each Disk Partition. Therefore, the Partition Key must be designed well so that Items are evenly distributed across many Disk Partitions. If requests are concentrated on a single Partition Key or a single Disk Partition, Throttling occurs and Data Read/Write operations may temporarily not be performed.

Only comparison operators such as `=` and `!=` can be used with the Partition Key.

#### 1.2.2. Sort Key

The Sort Key, as its name suggests, is the Key used to sort Columns within a Partition inside the Disk. Since an Index is created internally based on the Sort Key, comparison operators and range operators such as `>` and `<=` can be used. Therefore, to perform operations such as sorting in DynamoDB, the Sort Key must be utilized.

### 1.3. Attribute

An Attribute serves as a **Column** of a Table. Each Item can have different Attributes. In [Figure 1], the first Item has `Email Address`, `Total Amount`, and `Phone` as Attributes, and the second Item has `Purchase Price` and `Purchase Count` as Attributes. It can be seen that they have different Attributes.

Comparison operators or range operators cannot be used on ordinary Attributes; a Secondary Index such as an **LSI (Local Secondary Index)** or **GSI** (Global Secondary Index) must be created and used.

## 2. Secondary Index

A Secondary Index is a feature that can be used when an Index separate from the Index created by the Sort Key at Table creation is needed. There are the LSI (Local Secondary Index) and the GSI (Global Secondary Index). A Secondary Index also always has a Primary Key composed of a combination of a Partition Key and a Sort Key, and the original Table referenced to create the Secondary Index is called the **Base Table**.

### 2.1. LSI (Local Secondary Index)

{{< figure caption="[Figure 2] DynamoDB LSI" src="images/aws-dynamodb-lsi.png" width="800px" >}}

[Figure 2] shows an example of an LSI created with the Table of [Figure 1] as the Base Table. The Partition Key of an LSI must be identical to the Partition Key of the Base Table. However, for the Sort Key, an arbitrary Attribute of the Base Table can be selected and used. In [Figure 2] as well, the Partition Key is `PK`, identical to [Figure 1], but the Sort Key uses the `Created Date` Attribute of the Base Table under the name `LSI_SK`.

When configuring an LSI, all or some of the Base Table's Attributes can be brought in as the LSI's Projected Attributes through Projection. In [Figure 2], four Attributes — `Email Address`, `Purchase Price`, `Purchase Count`, and `Count` — are used as Projected Attributes. An LSI has the advantage of being able to fetch an Attribute from the Base Table even if it does not exist as a Projected Attribute. However, since this reads the Base Table once more, additional cost is incurred and performance also slows down, so when using an LSI it is recommended to use only Projected Attributes if possible.

An LSI's Read operation consumes the Base Table's RCU (Read Capacity Unit). When a Write operation occurs on the Base Table, the written content is also reflected in the LSI; in this case as well, the Base Table's WCU (Write Capacity Unit) is consumed, and since Writes are performed twice — on the Base Table and the LSI — twice as much WCU is consumed.

An LSI can be created together only through configuration when creating the (Base) Table, and cannot be created or deleted after the (Base) Table is created. In addition, a maximum of 5 LSIs can be created per Base Table, and there is a constraint that the size of a single LSI Partition cannot exceed 10GB. However, an LSI supports **Strongly-Consistency Read**, and since it consumes the Base Table's RCU and WCU, it has the advantage of cost savings compared to a GSI, which consumes separate RCU and WCU, when using Provisioned Capacity Mode.

### 2.2. GSI (Global Secondary Index)

{{< figure caption="[Figure 3] DynamoDB GSI" src="images/aws-dynamodb-gsi.png" width="750px" >}}

[Figure 3] shows an example of a GSI created with the Table of [Figure 1] as the Base Table. The Partition Key and Sort Key of a GSI can be composed by selecting arbitrary Attributes of the Base Table.

## 3. Capacity Mode

DynamoDB provides two Capacity Modes for managing a Table's Read/Write capacity: **Provisioned Mode** and **On-demand Mode**. The Capacity Mode is specified per Table and can be changed even after Table creation.

### 3.1. Provisioned Mode

Provisioned Mode is a Mode in which the capacity a Table will use is specified in advance in units of **RCU** (Read Capacity Unit) and **WCU** (Write Capacity Unit). 1 RCU means one Strongly Consistent Read per second for an Item up to 4KB in size, and an Eventually Consistent Read consumes only half, 0.5 RCU. 1 WCU means one Write per second for an Item up to 1KB in size. Reads/Writes using Transactions consume twice the RCU/WCU.

If requests exceeding the specified RCU/WCU occur, Throttling occurs and the requests are rejected; when Auto Scaling is used together, the RCU/WCU are adjusted automatically based on a target utilization. When traffic is steady and predictable, it can be used at a lower cost than On-demand Mode.

### 3.2. On-demand Mode

On-demand Mode is a Mode in which capacity is not specified in advance and cost is incurred in proportion to the number of Read/Write requests actually performed. DynamoDB automatically adjusts capacity to match the traffic and immediately accommodates up to twice the previous Peak traffic, but Throttling may occur if traffic exceeding twice the previous Peak flows in within a short time. It is suitable when traffic is difficult to predict or fluctuates widely.

## 4. Data Type

DynamoDB's Data Types can be classified into three categories: Scalar, Document, and Set. The following Data Types exist for each category.

* **Scalar** : String, Number, Binary, Boolean, Null
* **Document** : List, Map
* **Set** : String Set, Number Set, Binary Set

## 5. Consistency

When performing a Write, DynamoDB stores the Data in replicas located in multiple AZs within a single Region. Since a Write request is acknowledged as successful before it is reflected in all replicas and is propagated to the remaining replicas asynchronously, Data in which the latest Write is not yet reflected may be read depending on the replica where the Read is performed. To control this, DynamoDB provides two types of Read Consistency.

* **Eventually Consistent Read** : The default Read method, which performs the Read on an arbitrary replica. Therefore, old Data in which the previous Write is not reflected may be returned. It consumes 0.5 RCU, half that of a Strongly Consistent Read.
* **Strongly Consistent Read** : A Read method that guarantees the return of Data reflecting the most recent Write. It consumes 1 RCU and has relatively higher Latency than an Eventually Consistent Read. It is available only on the Base Table and LSIs; GSIs support only Eventually Consistent Reads.

## 6. DAX (DynamoDB Accelerator)

**DAX** is a Managed In-memory Cache Cluster dedicated to DynamoDB. DynamoDB's Read Latency is at the Millisecond level, but Data that exists in DAX's Cache can be Read with Microsecond-level Latency. Since DAX is compatible with the DynamoDB API, an App can use DAX without major code changes by using the DAX Client. The DAX Cluster is located inside the User's VPC and consists of one Primary Node and multiple Read Replica Nodes.

DAX operates in a Write-through manner, responding to the App's Write request only after it is reflected in both DynamoDB and DAX's Cache. The Cache is separated into an **Item Cache**, which stores the results of `GetItem` and `BatchGetItem`, and a **Query Cache**, which stores the results of `Query` and `Scan`; the Cached Data is retained for the specified TTL (5 minutes by default).

DAX handles only Eventually Consistent Reads from the Cache. Strongly Consistent Read requests are passed through by DAX to DynamoDB as they are, and the returned results are not stored in the Cache either.

## 7. TTL

**TTL** is a feature that specifies an expiration time for each Item and automatically deletes expired Items. When a specific Attribute of a Table is designated as the TTL Attribute, DynamoDB compares the Unix Timestamp in seconds stored in that Attribute with the current time and deletes expired Items in the Background. Since deletion by TTL does not consume WCU, unnecessary Data can be cleaned up at no cost, and deleted Items are also removed from LSIs and GSIs.

Expired Items are not deleted immediately and are generally deleted within a few days after expiration. Therefore, Items that have expired but have not yet been deleted may be included in the results of Read, Query, and Scan, and a Filter Expression must be used to exclude such Items. When using DynamoDB Streams, deletion Events caused by TTL are also recorded in the Stream, so they can be utilized for post-processing of expired Items.

## 8. Locking

DynamoDB does not provide a separate Lock feature; Optimistic Locking can be implemented through **Conditional Writes**, which perform a Write only when a condition is satisfied. An Attribute representing a Version is placed on the Item, the Version value is read together at Read time, and a condition is specified so that the Write and the Version increment are performed only when the Version value at Write time is the same as at Read time. If another Client has performed a Write first and the Version value has changed, the condition check fails and a `ConditionalCheckFailedException` occurs, and the Client must Read the Item again and then retry the Write.

The DynamoDBMapper of the AWS SDK for Java automatically handles the above Optimistic Locking process through the `@DynamoDBVersionAttribute` Annotation. When Pessimistic Locking is needed, a Lease-based Lock can be implemented using the DynamoDB Lock Client Library provided by AWS.

## 9. REST API

Unlike ordinary DBs that use a dedicated Protocol and Connections, DynamoDB performs all operations through an **HTTPS-based REST API**. Each request is delivered as an independent HTTP request; the Operation to perform is specified in the `X-Amz-Target` Header, the Operation's Parameters are carried in a JSON-format Body, and the request is signed and sent using the AWS Signature V4 method. Operations such as `GetItem`, `PutItem`, `UpdateItem`, `DeleteItem`, `Query`, and `Scan` are provided, and the AWS SDK and AWS CLI also all call the REST API internally.

Since Persistent Connections and Connection Pool management are not needed, DynamoDB can be used without the burden of maintaining Connections even in Serverless environments with short lifecycles, such as AWS Lambda.

## 10. References

* Amazon DynamoDB Key Design Patterns : [https://www.youtube.com/watch?v=I7zcRxHbo98](https://www.youtube.com/watch?v=I7zcRxHbo98)
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
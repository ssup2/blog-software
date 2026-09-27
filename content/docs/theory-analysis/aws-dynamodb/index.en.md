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

The Primary Key must have a unique value within a Table. The Primary Key consists of a **Partition Key** or a **Partition Key** + **Sort Key**. That is, the Partition Key is a required element, but the Sort Key is not. The Primary Key value must always 

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

{{< figure caption="[Figure 1] DynamoDB LSI" src="images/aws-dynamodb-lsi.png" width="800px" >}}

[Figure 2] shows an example of an LSI created with the Table of [Figure 1] as the Base Table. The Partition Key of an LSI must be identical to the Partition Key of the Base Table. However, for the Sort Key, an arbitrary Attribute of the Base Table can be selected and used. In [Figure 2] as well, the Partition Key is `PK`, identical to [Figure 1], but the Sort Key uses the `Created Date` Attribute of the Base Table under the name `LSI_SK`.

When configuring an LSI, all or some of the Base Table's Attributes can be brought in as the LSI's Projected Attributes through Projection. In [Figure 2], four Attributes — `Email Address`, `Purchase Price`, `Purchase Count`, and `Count` — are used as Projected Attributes. An LSI has the advantage of being able to fetch an Attribute from the Base Table even if it does not exist as a Projected Attribute. However, since this reads the Base Table once more, additional cost is incurred and performance also slows down, so when using an LSI it is recommended to use only Projected Attributes if possible.

An LSI's Read operation consumes the Base Table's RCU (Read Capacity Unit). When a Write operation occurs on the Base Table, the written content is also reflected in the LSI; in this case as well, the Base Table's WCU (Write Capacity Unit) is consumed, and since Writes are performed twice — on the Base Table and the LSI — twice as much WCU is consumed.

An LSI can be created together only through configuration when creating the (Base) Table, and cannot be created or deleted after the (Base) Table is created. In addition, a maximum of 5 LSIs can be created per Base Table, and there is a constraint that the size of a single LSI Partition cannot exceed 10GB. However, an LSI supports **Strongly-Consistency Read**, and since it consumes the Base Table's RCU and WCU, it has the advantage of cost savings compared to a GSI, which consumes separate RCU and WCU, when using Provisioned Capacity Mode.

### 2.2. GSI (Global Secondary Index)

{{< figure caption="[Figure 3] DynamoDB GSI" src="images/aws-dynamodb-gsi.png" width="750px" >}}

[Figure 3] shows an example of a GSI created with the Table of [Figure 1] as the Base Table. The Partition Key and Sort Key of a GSI can be composed by selecting arbitrary Attributes of the Base Table.

## 3. Capacity Mode

TODO

## 4. Data Type

DynamoDB's Data Types can be classified into three categories: Scalar, Document, and Set. The following Data Types exist for each category.

* **Scalar** : String, Number, Binary, Boolean, Null
* **Document** : List, Map
* **Set** : String Set, Number Set, Binary Set

## 5. Consistency

TODO

## 6. DAX (DynamoDB Accelerator)

TODO

## 7. TTL

TODO

## 8. Locking

TODO

## 9. REST API

TODO

## 10. References

* Amazon DynamoDB 키 디자인 패턴 : [https://www.youtube.com/watch?v=I7zcRxHbo98](https://www.youtube.com/watch?v=I7zcRxHbo98)
* Single Table Design : [https://emshea.com/post/part-1-dynamodb-single-table-design](https://emshea.com/post/part-1-dynamodb-single-table-design)
* Secondary Index : [https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/SecondaryIndexes.html](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/SecondaryIndexes.html)
* Secondary Index : [https://www.dynamodbguide.com/local-or-global-choosing-a-secondary-index-type-in-dynamo-db](https://www.dynamodbguide.com/local-or-global-choosing-a-secondary-index-type-in-dynamo-db)
* Secondary Index : [https://stackoverflow.com/questions/21381744/difference-between-local-and-global-indexes-in-dynamodb](https://stackoverflow.com/questions/21381744/difference-between-local-and-global-indexes-in-dynamodb)
* Architecture : [https://medium.com/swlh/architecture-of-amazons-dynamodb-and-why-its-performance-is-so-high-31d4274c3129](https://medium.com/swlh/architecture-of-amazons-dynamodb-and-why-its-performance-is-so-high-31d4274c3129)
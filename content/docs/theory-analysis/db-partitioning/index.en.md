---
title: DB Partitioning
---

This document analyzes DB partitioning and sharding.

## 1. DB Partitioning

{{< figure caption="[Figure 1] DB Partitioning" src="images/db-partitioning.png" width="900px" >}}

Partitioning is a technique that splits one table into multiple tables for performance, availability, and ease of maintenance. As the table is split, the table's data is also separated into distinct disk space. Partitioning includes **Vertical Partitioning** and **Horizontal Partitioning**. [Figure 1] shows Vertical Partitioning and Horizontal Partitioning.

### 1.1. Vertical Partitioning

Vertical Partitioning is a technique that splits a table vertically. If data reads occur frequently on only some columns, you can improve read performance by placing only the frequently read columns in a separate table. Even when the DB is composed of multiple instances, vertical partitioning does not allow proper utilization of multiple DB instances.

### 1.2. Horizontal Partitioning

Horizontal Partitioning is a technique that splits a table horizontally. Applying horizontal partitioning on a single DB instance yields little performance benefit. However, when tables split horizontally are distributed across multiple DB instances, you gain the advantage of utilizing the performance of many DB instances, because queries can be distributed and processed across multiple DB instances.

In general, **DB Sharding** means a technique that horizontally splits tables through horizontal partitioning and stores the split tables across multiple DB instances. Horizontal partitioning includes **Hash**, **Range**, and **List** methods depending on the algorithm used to split tables horizontally.

#### 1.2.1. Hash

{{< figure caption="[Figure 2] Horizontal Partitioning Hash" src="images/db-partitioning-hash.png" width="600px" >}}

[Figure 2] shows horizontal partitioning using a modular arithmetic-based hash algorithm. [Figure 2] uses Fruit ID as the hash key, but other columns can also be used as the hash key. It has the advantage of uniform data distribution by the hash algorithm. On the other hand, it has the disadvantage that when DB instances storing the table are added or removed, most data must be reorganized.

#### 1.2.2. Range

{{< figure caption="[Figure 3] Horizontal Partitioning Range" src="images/db-partitioning-range.png" width="600px" >}}

[Figure 3] shows horizontal partitioning using a range algorithm. You can see that the range of Fruit IDs that can go into each DB instance is specified. [Figure 3] specifies ranges using Fruit ID, but other columns can also be used to specify ranges. It has the advantage of minimizing data reorganization when DB instances storing the table are added or removed, depending on range configuration, but has the disadvantage that data may not be distributed properly depending on the data.

#### 1.2.3. List

{{< figure caption="[Figure 4] Horizontal Partitioning List" src="images/db-partitioning-list.png" width="600px" >}}

[Figure 4] shows horizontal partitioning using a list algorithm. You can see that the Fruit IDs that can go into each DB instance are listed. [Figure 4] lists Fruit IDs, but values of other columns can also be listed. It has the same advantages and disadvantages as the range algorithm.

## 2. References

* [https://www.digitalocean.com/community/tutorials/understanding-database-sharding](https://www.digitalocean.com/community/tutorials/understanding-database-sharding)
* [https://blog.yugabyte.com/how-data-sharding-works-in-a-distributed-sql-database/](https://blog.yugabyte.com/how-data-sharding-works-in-a-distributed-sql-database/)
* [https://hazelcast.com/glossary/sharding/](https://hazelcast.com/glossary/sharding/)
* [https://hevodata.com/learn/understanding-mysql-sharding-simplified/](https://hevodata.com/learn/understanding-mysql-sharding-simplified/)
* [https://devopedia.org/database-sharding](https://devopedia.org/database-sharding)
* [https://woowabros.github.io/experience/2020/07/06/db-sharding.html](https://woowabros.github.io/experience/2020/07/06/db-sharding.html)
* [https://soye0n.tistory.com/267](https://soye0n.tistory.com/267)

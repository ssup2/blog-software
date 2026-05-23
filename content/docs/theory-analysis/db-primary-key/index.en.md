---
title: DB Primary Key
---

This document analyzes DB primary keys.

## 1. Primary Key

A primary key serves as the identifier for each record in a table. Therefore, primary key values must be unique within a single table. In general, when a duplicate primary key occurs during transaction processing, the DB cancels that transaction to guarantee uniqueness of the primary key. Records are sorted and stored on disk based on the primary key. Sorting uses a **B+ Tree**. Because this B+ Tree determines the disk location where records are stored, it is called a **clustered index**.

### 1.1. Auto Increment vs Random

Primary keys generally use two approaches: **auto increment**, which increments and stores one value each time a record is created, and an approach that uses random values where duplication rarely occurs. UUID is commonly used for random values.

For record insert operations, the auto increment approach, where the primary key increases steadily, shows better **performance** than the random approach. This is because record ordering is B+ Tree-based and because of the memory buffer that the DB uses as a disk cache. When records are stored with the primary key increasing one by one through auto increment, records are likely to be added repeatedly to the same disk page by the B+ Tree. That is, the DB can store records added to the memory buffer and reflect them to disk at once.

On the other hand, when the primary key uses the random approach, records added by the B+ Tree are likely to be stored on different pages rather than the same disk page. In this case, utilization of the DB memory buffer decreases and memory buffer flushes occur frequently, lowering insert performance.

For read performance as well, the auto increment approach shows better performance than the random approach because the primary key size is smaller. The auto increment approach mostly uses an integer type for the primary key. That is, only 4 bytes are needed to store the primary key. On the other hand, random values require a larger primary key size to prevent collisions, so an integer type cannot be used. Even UUID, the most commonly used random value, requires at least 16 bytes.

On the other hand, the random approach has the major advantage of higher **flexibility** compared to auto increment. With the random approach, the uniqueness of each record's primary key is not limited to a specific table but is also valid globally. Because of this characteristic, when migrating records to another DB or table, migration can be performed without changing the primary key.

## 2. References

* [https://www.percona.com/blog/2019/11/22/uuids-are-popular-but-bad-for-performance-lets-discuss/](https://www.percona.com/blog/2019/11/22/uuids-are-popular-but-bad-for-performance-lets-discuss/)

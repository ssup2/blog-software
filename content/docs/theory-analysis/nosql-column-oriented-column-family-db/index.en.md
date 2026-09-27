---
title: NoSQL Column-oriented, Column Family DB
---

This post analyzes Column-oriented DB and Column Family DB, which are NoSQL DBs.

## 1. Column-oriented DB

{{< figure caption="[Figure 1] NoSQL Column-oriented-DB" src="images/column-oriented-db.png" width="900px" >}}

**Column-oriented** refers to a DB that splits and stores a Data Table by Column. [Figure 1] compares the Row-oriented technique used by a general RDBMS with the Column-oriented technique. In the Row-oriented approach, one Row is stored in one Disk Block, while in the Column-oriented approach, one Column is stored in one Disk Block.

In [Figure 1], when the DB performs an operation to count how many people have Male as their Gender, the Row-oriented approach must read 4 Blocks, find out the Gender values inside, and perform a Sum. On the other hand, the Column-oriented approach can obtain the result by reading only 1 Block, enabling fast processing. As such, in the case of data analysis operations, most of the time only some Columns of the Data Table are needed rather than all Columns. Therefore, a Column-oriented DB is advantageous for OLAP (Online Analytical Processing). Conversely, when adding or deleting one Row, a Row-oriented DB only needs to use 1 Block, while a Column-oriented DB must use 4 Blocks, so a Column-oriented DB is disadvantageous for OTLP (Online transaction processing).

A Column-oriented DB can easily Compress Data. In [Figure 1], the Data of the Block storing Gender in the Column-oriented technique contains only Male or Female. Since the Data stored in a Block is often duplicated, the Data can be easily Compressed. For example, if Male and Female are Mapped to specific IDs and the Mapped IDs are stored in the Block, the Data can be stored with a small capacity.

## 2. Column Family DB

{{< figure caption="[Figure 2] NoSQL Column-Family-DB" src="images/column-family-db.png" width="800px" >}}

A Column Family DB is a DB that represents a Data Table by Mapping Column Key/Data/Timestamp Tuples representing Columns to a Row Key representing a Row. In an RDBMS, a NULL value also occupies Disk Block space, but in a Column Family DB, Columns can be freely added/deleted per Row, so a separate Column for NULL values is not needed.

Generally, Column-oriented DB and Column Family DB are used interchangeably, and Column Family DBs are often regarded as Column-oriented DBs. However, it cannot be said that a Column Family DB is a Column-oriented DB. HBASE, a Column Family DB, is classified as a Column-oriented DB because it stores data in Disk Blocks by Column Family, which is a set of Columns. However, Cassandra, another Column Family DB, cannot be called a Column-oriented DB because it stores data in Disk Blocks by Row.

## 3. References

* Column family - Wikipedia : [https://en.wikipedia.org/wiki/Column_family](https://en.wikipedia.org/wiki/Column_family)
* What is a Column Store Database? : [https://database.guide/what-is-a-column-store-database/](https://database.guide/what-is-a-column-store-database/)
* Why many refer to Cassandra as a Column oriented database : [https://stackoverflow.com/questions/13010225/why-many-refer-to-cassandra-as-a-column-oriented-database](https://stackoverflow.com/questions/13010225/why-many-refer-to-cassandra-as-a-column-oriented-database)
* Cassandra vs. HBase: twins or just strangers with similar looks? : [https://www.scnsoft.com/blog/cassandra-vs-hbase](https://www.scnsoft.com/blog/cassandra-vs-hbase)

---
title: DB Indexing
---

This document analyzes DB indexing techniques.

## 1. DB Indexing

{{< figure caption="[Figure 1] DB Indexing" src="images/db-indexing.png" width="600px" >}}

DB indexing is literally a technique that improves DB performance by creating an index. [Figure 1] briefly illustrates DB indexing. The table on the right represents a DB table, and the table on the left represents an index based on the State column. The index **sorts** record values in the State column and stores the **ID** of each record value.

```sql {caption="[Query 1] SELECT with single WHERE condition"}
SELECT * FROM Fruit_Info WHERE State = 'NC'
```

The DB can use created indexes to improve the performance of specific SQL queries. When executing [Query 1], if there is no index, the DB must read all record values in the Fruit_Info table and check whether the State field value is 'NC'. That is, a table full scan occurs. However, if an index exists, search algorithms such as binary search can be used, so records with the value 'NC' can be found quickly without reading all record values.

Conversely, when an index exists, the index must also be updated when records are created or deleted, which causes **overhead**. Therefore, indexes should not be created unconditionally in large numbers; they should be applied appropriately according to schema and SQL queries. Note that the DB creates and manages an index on the primary key field by default. Indexes on other user-defined fields can be created and deleted through DDL (Data Definition Language).

### 1.1. Index Type

{{< figure caption="[Figure 2] Index Type" src="images/clustered-non-clustered-index.png" width="1000px" >}}

Indexes can be classified into clustered index and non-clustered index by nature and characteristics. Both types generally use **B+ Tree**, a data structure designed considering physical disk characteristics, to manage and search indexes. [Figure 2] shows clustered index and non-clustered index based on [Figure 1]. The bottom part shows clustered index, and the top part shows non-clustered index. In [Figure 2], both clustered and non-clustered indexes are not deep, but as index size increases, index depth also increases due to the B+ Tree data structure.

A **clustered index** is an index built on **actual records** stored on disk. Therefore, using a clustered index has the advantage of direct access to records. On the other hand, when the field on which a clustered index was created in a record changes, the clustered index must also change, so it has the disadvantage of large overhead not only on record creation and deletion but also on record **updates**. Because it is built on actual records, only one clustered index can exist per table.

In [Figure 2], the red arrow shows the process of accessing the record with Fruit ID 4 through the clustered index. You can see that a single index lookup allows direct access to the page where the record is located. The index on the primary key, which is used most often for record access and rarely changes, is generally created as a clustered index. [Figure 2] assumes Fruit ID as the primary key. Therefore, it shows a clustered index created using Fruit ID.

A **non-clustered index** is an index built on **references** that point to actual records stored on disk. Therefore, when using a non-clustered index, only the reference to the record can be accessed, and an additional access step through the reference is required to obtain the record. Thus, slower record access compared to clustered index is a disadvantage. On the other hand, it has the advantage that the non-clustered index does not need to change even when records change. It also has the advantage that multiple non-clustered indexes can be created for one table.

The blue arrow in [Figure 2] shows the process of accessing records with NC state through a non-clustered index. You can see that after finding Fruit IDs with NC state through the non-clustered index, actual records are accessed again through the clustered index. You can also see that the index in [Figure 1] is a non-clustered index. In general, indexes created on columns other than the primary key use non-clustered indexes.

### 1.2. Index Column Selection

The usefulness and utilization of a created index vary depending on which column is chosen for the index. The more duplicate values in an index, the less effective index-based search becomes. For example, if an index is created on a column where all values are the same, search through the index becomes meaningless. Also, if an index is created but not used, only DB performance degradation occurs due to index overhead.

Therefore, columns for indexes should be selected with **high cardinality**, so values are unlikely to duplicate, and **high utilization**, so they are used frequently. ID is a representative column with high cardinality and high utilization. In general, the ID column is set as the table's primary key to create and use an index.

## 2. References

* [https://www.progress.com/tutorials/odbc/using-indexes](https://www.progress.com/tutorials/odbc/using-indexes)
* [https://www.sqlshack.com/what-is-the-difference-between-clustered-and-non-clustered-indexes-in-sql-server/](https://www.sqlshack.com/what-is-the-difference-between-clustered-and-non-clustered-indexes-in-sql-server/)
* [https://velog.io/@gillog/SQL-Clustered-Index-Non-Clustered-Index](https://velog.io/@gillog/SQL-Clustered-Index-Non-Clustered-Index)
* [https://dev-navill.tistory.com/26](https://dev-navill.tistory.com/26)
* [https://yurimkoo.github.io/db/2020/03/14/db-index.html](https://yurimkoo.github.io/db/2020/03/14/db-index.html)

---
title: DB SQL Query with Index
---

This post summarizes SQL Queries that utilize Indexes.

## 1. Where

```sql {caption="[Query 1] Where Single Condition"}
WHERE state = 'NC'
WHERE state IN ('NC')
WHERE state >= 'NC'
WHERE state < 'NC'
```

Using an Index can improve the performance of SQL Queries that use `WHERE` clauses. [Query 1] shows examples of `WHERE` clauses. The Index is used not only when finding identical values, but also when finding greater or smaller values. In the case of the `IN` syntax, the Index is used when the number of values is small, but the Index is not used when the number of values becomes large. In MySQL, the maximum number of values for which the Index is used can be configured depending on the value of `range-optimizer-max-mem-size` and the size of the Data.

```sql {caption="[Query 2] Where Multiple Conditions"}
WHERE state = 'NC' AND fruit >= 'Apple' AND fruit < 'Lemon'
WHERE state > 'NC' AND fruit >= 'Apple' AND fruit < 'Lemon'
```

When multiple conditions are added to a `WHERE` clause with the `AND` syntax, one Index with the smallest condition range is selected and referenced to execute the Query. When an Index on the Fruit Field and an Index on the State Field each exist, the first Query in [Query 2] references the Index of the State Field. This is because the range of the State Field is fixed to `NC`. The second Query references the Index of the Fruit Field. This is because only the minimum value of the State Field's range is set, while both the minimum and maximum values of the Fruit Field's range are set.

## 2. Concatenated Index

{{< figure caption="[Figure 1] DB Table" src="images/db-table.png" width="400px" >}}

[Figure 1] shows a hypothetical Table for explanation. Most DBs today support the ability to create an Index by combining multiple Fields rather than a single Field. Such an Index is called a **Concatenated Index**. When creating a Concatenated Index, the order in which Fields are combined is very important. This is because the Index is created by concatenating the Record values in the order the Fields are combined. In [Figure 1], if the Index is created in the order of the Fruit and State Fields, the value `OrangeFL` goes into the Index, and if the Index is created in the order of the State and Fruit Fields, the value `FLOrange` goes into the Index.

```sql {caption="[Query 3] Select, Where Multiple Conditions"}
SELECT * FROM fruit-info WHERE fruit = 'Lemon' AND state = 'NC'
```

When [Query 3] uses the Index created in the order of the Fruit and State Fields, the Index can be fully utilized to find the Record quickly. However, when using the Index created in the order of the State and Fruit Fields, the State Field part at the front of the Index can be used, but the Fruit part at the back of the Index cannot be used. In this way, SQL performance varies depending on the Field order of the Concatenated Index and the `WHERE` clause. Also, the first Field of a Concatenated Index can be used in various `WHERE` clauses.

## 3. Join

```sql {caption="[Query 4] Join"}
SELECT * FROM dept, emp WHERE dept.id = emp.dept-id
```

Using an Index can improve the performance of Join Queries. When the DB executes the Query in [Query 4], it selects one record from the `dept` Table and then checks `dept.dept-id`. After that, it searches the `emp` Table to find records whose `emp.dept-id` has the same value as `dept.id` and performs the Join. Then the DB selects the next record of the `dept` Table and repeats the same process.

During the execution of [Query 4], the DB repeatedly performs the operation of searching the entire `emp` Table to find the `dept.id` value in the `dept-id` Field of the `emp` Table. If an Index is created on `emp.dept-id`, the DB does not have to search the entire `emp` Table thanks to the Index, which leads to improved performance.

## 4. References

* Using Indexes - Progress ODBC Tutorial : [https://www.progress.com/tutorials/odbc/using-indexes](https://www.progress.com/tutorials/odbc/using-indexes)
* MySQL - 정상 수행되던 쿼리가 IN 절에서 Index Scan 을 하지 않을 경우 Table Full Scan : [https://hoing.io/archives/24493](https://hoing.io/archives/24493)

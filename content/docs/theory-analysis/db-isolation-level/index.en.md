---
title: DB Isolation Level
---

This document analyzes DB isolation levels and issues that occur depending on isolation level.

## 1. Isolation Level

Transactions that follow ACID properties should theoretically be guaranteed to operate completely independently of each other. However, preserving full ACID properties for transactions requires coarse-grained locks, which leads to DB performance degradation. To address this problem, most DBs support isolation levels.

DB users can configure the DB isolation level to determine the balance between DB performance and the degree of ACID guarantee for transactions. The higher the isolation level, the lower DB performance, but ACID properties are better guaranteed. Conversely, the lower the isolation level, the higher DB performance, but ACID properties are less well guaranteed, and the degree of influence each transaction has on others increases.

DB isolation levels generally include four: Serializable, Repeatable Read, Read Committed, and Read Uncommitted. To implement isolation levels, DBs often use table locks that lock entire tables and row locks that lock individual rows. Depending on the DB type, each lock may be further divided into shared lock (read lock) and exclusive lock (write lock). When a DB uses shared and exclusive locks, table and row locks mentioned in the isolation level descriptions below can all be considered **exclusive locks**.

#### 1.1. Serializable

The highest isolation level. It places table locks on all tables related to the transaction's queries and executes queries. Therefore, each transaction runs completely independently.

#### 1.2. Repeatable Read

The second highest isolation level. It is a level that guarantees that when a row read once during a transaction is read again, the same data always appears. To implement Repeatable Read level, DBs have two approaches: using row locks and using snapshot + row locks.

##### 1.2.1. Row Lock

When a DB implements Repeatable Read level using row locks, the DB places row locks on all rows of all tables related to the transaction's queries, executes queries, and releases row locks when the transaction ends. Therefore, because other transactions cannot change rows that were read in the transaction, reading the same row multiple times within the same transaction always shows the same data.

However, because only row locks are used and table locks are not, when another transaction adds a new row to that table, the added row may be read together in the original transaction. This phenomenon is called **phantom read**.

##### 1.2.2. Snapshot + Row Lock

Using snapshot together with row locks can secure parallelism for read (SELECT) operations and eliminate phantom read. When only row locks are used, because row locks are held until the transaction ends, multiple transactions cannot read the same row concurrently.

When using snapshot, when performing a read operation inside a transaction, a transaction-specific snapshot is created, and subsequent read operations inside the transaction are performed against that transaction-specific snapshot. Therefore, even when multiple transactions read the same row concurrently, each transaction actually reads its own transaction-specific snapshot, so concurrent reads are possible and phantom read does not occur.

When performing update operations, row locks are placed on actual rows rather than snapshots and update operations are performed. Therefore, when multiple transactions try to update the same row concurrently, only one transaction can update at a time.

#### 1.3. Read Committed

The third highest isolation level. It is a level where commits of other transactions that occur while a transaction is running affect the current transaction. That is, if a row read during a transaction is changed by another transaction through update and commit, the change is reflected in the current transaction. The phenomenon where values change depending on other transactions' commits when reading the same row repeatedly within a transaction is called **non-repeatable read**.

At Read Committed level, the DB places row locks on rows related to the query, executes the query, and releases those row locks when query execution finishes. Because locking is performed per query rather than per transaction, other transactions' commit contents are reflected even while a transaction is running.

#### 1.4. Read Uncommitted

The lowest isolation level. It is a level where row changes by other transactions that occur while a transaction is running affect the current transaction. That is, even if a row read during a transaction is changed by another transaction without commit, the change is reflected in the current transaction. The phenomenon where uncommitted changes affect other transactions' reads is called **dirty read**.

At Read Uncommitted level, the DB executes queries without placing locks, so transaction processing is exposed to other transactions as-is.

## 2. Isolation Level & Issue

{{< table caption="[Table 1] Issues by DB Isolation Level" >}}
| | Read Uncommitted | Read Committed | Repeatable Read | Serializable |
|----|----|----|----|----|
| Lost Update | O | O | X | X |
| Dirty Read | O | X | X | X |
| Non-repeatable Read | O | O | X | X |
| Phantom Read | O | O | O | X |
{{< /table >}}

Depending on isolation level, issues such as those in [Table 1] occur.

#### 2.1. Lost Update

{{< table caption="[Table 2] Lost Update Example" >}}
| T1 | T2 |
|----|----|
| SELECT age FROM users WHERE id = 1; | |
| | SELECT age FROM users WHERE id = 1; |
| UPDATE users SET age = 21 WHERE id = 1; <br> COMMIT; | |
| | UPDATE users SET age = 31 WHERE id = 1; <br> COMMIT;|
{{< /table >}}

Lost update is a phenomenon where change contents disappear when two or more transactions change one row concurrently. It occurs at Read Uncommitted and Read Committed levels, which do not lock at transaction unit. In [Table 2], at Read Uncommitted and Read Committed levels, T1's value of 21 disappears. However, at Repeatable Read and Serializable levels, when T2 performs commit, an exception occurs and the value is not changed to 31.

#### 2.2. Dirty Read

{{< table caption="[Table 3] Dirty Read Example" >}}
| T1 | T2 |
|----|----|
| SELECT age FROM users WHERE id = 1; | |
| | UPDATE users SET age = 21 WHERE id = 1; |
| SELECT age FROM users WHERE id = 1; | |
| | ROLLBACK; |
{{< /table >}}

Dirty read is a phenomenon where uncommitted changes affect other transactions' reads. In [Table 3], T1 ends up with the value 21 that was rolled back by T2.

#### 2.3. Non-repeatable Read

{{< table caption="[Table 4] Non-repeatable Read Example" >}}
| T1 | T2 |
|----|----|
| SELECT age FROM users WHERE id = 1; | |
| | UPDATE users SET age = 21 WHERE id = 1; <br> COMMIT;|
| SELECT age FROM users WHERE id = 1; <br> COMMIT;| |
{{< /table >}}

Non-repeatable read is a phenomenon where values change depending on other transactions' commits when reading the same row repeatedly within a transaction. In [Table 4], because of T2, T1's first age read value and second age read value differ.

#### 2.4. Phantom Read

{{< table caption="[Table 5] Phantom Read Example" >}}
| T1 | T2 |
|----|----|
| SELECT * FROM users WHERE age BETWEEN 10 AND 30;| |
| | INSERT INTO users(id,name,age) VALUES ( 3, 'Bob', 27 ); <br> COMMIT;|
| SELECT * FROM users WHERE age BETWEEN 10 AND 30; <br> COMMIT;| |
{{< /table >}}

Phantom read is a phenomenon where newly added rows by other transactions are reflected in results. In [Table 5], T1 does not read Bob's information in the first SELECT query, but reads Bob's information in the second SELECT query due to T2's transaction.

## 3. RDBMS Isolation Level

* MySQL - Uses Repeatable Read level as the default isolation level, and Repeatable Read uses a snapshot + row lock-based approach.
* SQL Server - Uses Read Committed as the default isolation level. It also provides a snapshot-based isolation level called Snapshot between Serializable and Repeatable Read levels.

## 4. References

* [http://whiteship.tistory.com/1554](http://whiteship.tistory.com/1554)
* [http://hundredin.net/2012/07/26/isolation-level/](http://hundredin.net/2012/07/26/isolation-level/)
* [https://blog.pythian.com/understanding-mysql-isolation-levels-Repeatable Read/](https://blog.pythian.com/understanding-mysql-isolation-levels-Repeatable Read/)
* [https://vladmihalcea.com/a-beginners-guide-to-database-locking-and-the-lost-update-phenomena/](https://vladmihalcea.com/a-beginners-guide-to-database-locking-and-the-lost-update-phenomena/)
* [https://docs.microsoft.com/ko-kr/sql/t-sql/statements/set-transaction-isolation-level-transact-sql?view=sql-server-2017](https://docs.microsoft.com/ko-kr/sql/t-sql/statements/set-transaction-isolation-level-transact-sql?view=sql-server-2017)
* [https://en.wikipedia.org/wiki/Isolation-(database-systems)](https://en.wikipedia.org/wiki/Isolation-(database-systems))
* [https://stackoverflow.com/questions/10935850/when-to-use-select-for-update](https://stackoverflow.com/questions/10935850/when-to-use-select-for-update)
* [https://stackoverflow.com/questions/33784779/whats-the-use-of-select-for-update-when-using-Repeatable Read-isolation](https://stackoverflow.com/questions/33784779/whats-the-use-of-select-for-update-when-using-Repeatable Read-isolation)
* [https://stackoverflow.com/questions/33784779/whats-the-use-of-select-for-update-when-using-repeatable-read-isolation](https://stackoverflow.com/questions/33784779/whats-the-use-of-select-for-update-when-using-repeatable-read-isolation)
* [https://jyeonth.tistory.com/32](https://jyeonth.tistory.com/32)

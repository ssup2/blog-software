---
title: DB SQL `SELECT FOR UPDATE` Query
---

This document analyzes the SQL `SELECT FOR UPDATE` query.

## 1. `SELECT FOR UPDATE` Query

The `SELECT FOR UPDATE` query is a query that acquires an exclusive (write) row lock before performing a read operation during SELECT, and the acquired lock is held until the transaction ends. This contrasts with a regular `SELECT` query, which reads an MVCC snapshot without acquiring a lock.

In a DB environment based on MVCC (Multi-Version Concurrency Control), such as MySQL InnoDB, a regular `SELECT` query operates as consistent read (snapshot read), reading a snapshot from the time the transaction started without acquiring a lock. Therefore, even if another transaction holds an exclusive row lock on that row, a regular `SELECT` query can read snapshot data without waiting.

On the other hand, a `SELECT FOR UPDATE` query attempts to acquire an exclusive row lock, so if another transaction holds an exclusive or shared row lock on that row, it waits until that lock is released before performing the read. After acquiring the lock, it operates as current read, reading the latest committed data rather than a snapshot, and because it does not release the acquired exclusive row lock until the transaction ends, other transactions cannot update those rows. Therefore, `SELECT FOR UPDATE` is used when you need to obtain data with consistency guaranteed across multiple transactions.

Depending on the DB type and isolation level, `SELECT FOR UPDATE` may be unnecessary and a regular `SELECT` query may suffice. For example, if you use Serializable, the highest isolation level in MySQL, a shared row lock is automatically granted on every regular `SELECT` query. A shared lock blocks other transactions from acquiring an exclusive lock, so you can read data with consistency guaranteed by preventing those rows from being updated by other transactions while reading. However, because this creates dependency on the DB type and isolation level, when you need data with guaranteed consistency in any environment, it is better to explicitly use `SELECT FOR UPDATE`.

## 2. References

* [https://stackoverflow.com/questions/33784779/whats-the-use-of-select-for-update-when-using-repeatable-read-isolation](https://stackoverflow.com/questions/33784779/whats-the-use-of-select-for-update-when-using-repeatable-read-isolation)
* [https://stackoverflow.com/questions/33784779/whats-the-use-of-select-for-update-when-using-repeatable-read-isolation](https://stackoverflow.com/questions/33784779/whats-the-use-of-select-for-update-when-using-repeatable-read-isolation)

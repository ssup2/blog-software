---
title: MySQL Buffer Pool, Redo Log, Log Buffer
---

This post analyzes MySQL's Buffer Pool, Redo Log, and Log Buffer.

## 1. Buffer Pool, Redo Log, Log Buffer

{{< figure caption="[Figure 1] MySQL Buffer Pool, Redo Log, Log Buffer" src="images/buffer-pool-redo-log-log-buffer.png" width="500px" >}}

[Figure 1] shows the Buffer Pool, Redo Log, and Log Buffer that process Transactions. The **Buffer Pool** is the Memory space that InnoDB, MySQL's DB Engine, uses for **Table Caching** and **Index Data Caching**. The larger the Buffer Pool size, the fewer Disk accesses are needed relatively, so DB performance improves. Since the Buffer Pool is a Memory space, if a failure occurs in MySQL, the contents of the Buffer Pool disappear, which can lead to the loss of Transactions. The File used to prevent such loss is the **Redo Log**. The Redo Log records Transaction contents, and when a MySQL failure occurs, MySQL performs **Recovery** to the point before the failure based on the Transaction contents recorded in the Redo Log.

InnoDB does not keep accumulating Transaction contents in the Buffer Pool and Redo Log; it applies the Transaction contents recorded in the Buffer Pool to the actual Disk periodically or when the Redo Log becomes full. This operation is called a **Checkpoint**. The Redo Log uses two files alternately. When a Redo Log becomes full, the full Redo Log is left alone and Transaction contents are recorded in the Redo Log that was not being used. The full Redo Log is emptied after the Checkpoint operation is performed.

Since the Redo Log is also a File, writing Transaction contents directly to the Redo Log every time a Transaction is processed can cause performance degradation due to frequent Disk access. To solve this problem, InnoDB records Transaction contents in the **Log Buffer**, which serves as a Cache for the Redo Log, and writes them to the Redo Log all at once. The Transaction contents in the Log Buffer are delivered to the OS's Disk Cache by InnoDB's Write operation and are stored in the Redo Log file by InnoDB's Flush operation. The timing of InnoDB's Write and Flush operations varies depending on InnoDB's configuration.

## 2. Configuration

This section analyzes the Configuration related to MySQL's Buffer Pool and Log Buffer.

### 2.1. innodb-buffer-pool-size

`innodb-buffer-pool-size` sets the size of the Buffer Pool. The default value is 128MB. In general, the larger the Buffer Pool Size, the fewer Disk accesses are needed, so DB performance improves. However, setting a value too large for the Server Memory capacity actually degrades performance due to frequent Page Swaps. Therefore, it must be set to an appropriate value. If only MySQL is running on the Server, setting it to 80% of the Server Memory size is recommended.

### 2.2. innodb-log-file-size

`innodb-log-file-size` sets the size of the Redo Log. As explained above, InnoDB performs the Checkpoint operation, which applies the Data changes recorded in the Buffer Pool to the actual Disk, periodically or when the Redo Log becomes full. No matter how large the Buffer Pool is, if the Redo Log size is small, Checkpoints occur frequently, so the Buffer Pool cannot be utilized properly. Therefore, when changing the Buffer Pool size, the Redo Log size must be changed together. It is generally set to half of the Buffer Pool Size (`innodb-buffer-pool-size`) value.

### 2.3. innodb-log-buffer-size

`innodb-log-buffer-size` sets the size of the Log Buffer. `innodb-log-buffer-size` represents the size of the Redo Log Buffer Memory. When many Data changes occur within a single Transaction, it is better to increase the size of the Redo Log Buffer Memory so that the Redo Log does not become full. It is generally set to a size between 1MB and 8MB.

### 2.4. innodb-flush-log-at-trx-commit

{{< figure caption="[Figure 2] MySQL Flush Log Buffer" src="images/flush-log-buffer.png" width="900px" >}}

This sets when InnoDB performs the Write and Flush operations of the Log Buffer contents to the Redo Log. Currently, MySQL provides only three Options: 0, 1, and 2. The Default value is set to 1. [Figure 2] shows when the Write and Flush operations are performed depending on the Option.

* **Option 0** : InnoDB performs the Write and Flush operations to the Redo Log at 1-second intervals regardless of Commits. Even after a Transaction ends with a Commit command, the Data changes may remain only in the Redo Log Buffer for up to 1 second and may not be applied to the Redo Log. Therefore, when using Option 0, if a failure occurs in MySQL or in the Node where MySQL is running, the Transaction contents of the 1 second before the failure are lost.
* **Option 1** : InnoDB performs the Write and Flush operations to the Redo Log together every time a Commit command is executed. Performance is slower due to many Disk accesses caused by frequent Write and Flush operations, but completed Transactions are not lost no matter what failure occurs.
* **Option 2** : InnoDB performs the Write operation to the Redo Log together every time a Commit command is executed, but performs the Flush operation at 1-second intervals. It operates in a form intermediate between Option 0 and Option 1. If a failure occurs only in MySQL, the Transaction contents stored in the OS Cache are likely to be applied to the Redo Log. However, if a failure occurs in the Node where MySQL is running, the Transaction contents of the 1 second before the Node failure are lost.

## 3. References

* Redo Log : [http://intomysql.blogspot.com/2010/12/redo-log.html](http://intomysql.blogspot.com/2010/12/redo-log.html)
* Configuration : [https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html)

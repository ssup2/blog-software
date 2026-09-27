---
title: PostgreSQL Replication
---

This post analyzes the Replication techniques for PostgreSQL HA (High Availability).

## 1. PostgreSQL Replication

{{< figure caption="[Figure 1] PostgreSQL Master-slave Replication" src="images/master-slave.png" width="600px" >}}

PostgreSQL **Replication** is basically based on Master-Slave Replication. Master-Slave Replication is a method that performs Replication through one Master DB and multiple Slave DBs. [Figure 1] shows Master-Slave Replication. The Master changes the DB according to DB change Queries received from Clients, and performs Replication by delivering the changes to the Slave DBs. Therefore, the Master operates in Read/Write Mode and the Slaves operate in Read Mode. Clients must send Write requests to the Master, and Read requests can be sent to the appropriate Master or an appropriate Slave. Generally, an LB (Load Balancer) is placed in front of the Slaves to distribute Read requests coming to the Slaves and increase Read performance.

### 1.1. Replication

Two Replication methods are supported: the WAL (Write Ahead Log) method and the Streaming method.

#### 1.1.1. WAL (Write Ahead Log) Replication

{{< figure caption="[Figure 2] PostgreSQL WAL Replication" src="images/wal-replication.png" width="550px" >}}

To understand WAL (Write Ahead Log) Replication, you need to understand WAL. WAL is, as the name implies, a Log that records DB changes caused by Write operations before they are applied to the actual Disk. It can be regarded as the same as the Redo Log recorded by InnoDB, MySQL's DB Engine. To minimize Disk access, PostgreSQL records DB changes in Buffer Memory and WAL, and then applies them to Disk at once through an operation called Checkpoint. Since the WAL applied to Disk is deleted at this point, the WAL is not kept on Disk indefinitely and has the characteristic of being deleted periodically according to certain rules. WAL is used not only for Replication but also for various Query-related operations such as Query re-execution and Query Rollback.

WAL Replication is a technique that performs Replication by delivering the WAL to the Slave. [Figure 2] shows WAL Replication. Since the WAL has the characteristic of being deleted periodically, PostgreSQL configured with WAL Replication periodically copies the WAL to an Archive. The Slave DB copies and fetches the WAL from the Master DB's Archive, then applies the DB changes in the WAL to its own WAL to proceed with Replication.

Since WAL Replication is performed in units of **Segments**, the file unit in which the WAL is stored, it is not a method in which the Master DB's changes are split up and frequently delivered to the Slave DB, but a method in which many changes are delivered at once. Therefore, a sudden death of the Master DB can lead to the loss of a lot of Data, and it takes time for the Master DB's changes to be applied to the Slave DB. The technique introduced to solve these drawbacks is Streaming Replication.

#### 1.1.2. Streaming Replication

{{< figure caption="[Figure 3] PostgreSQL Streaming Replication" src="images/streaming-replication.png" width="450px" >}}

Streaming Replication is a technique that immediately delivers the changes recorded in the WAL to the Slave DB. [Figure 3] shows Streaming Replication. The Master DB delivers the Master DB changes recorded in the WAL to the Slave DB's WAL Receiver through the WAL Sender. The Slave DB performs Replication by recording the Master DB's changes received through the WAL Receiver into its own WAL. Since Streaming Replication immediately delivers the Master DB's changes to the Slave DB in units of **Records**, the unit of a change, it can minimize Data loss caused by a sudden death of the Master DB.

Streaming Replication is performed using the original WAL, not the WAL in the Archive. Therefore, Master DB changes in a WAL deleted due to a Checkpoint cannot be delivered to the Slave DB through Streaming Replication. In other words, Master DB changes from long ago cannot be delivered to the Slave DB through Streaming Replication. To solve this problem, PostgreSQL can use WAL Replication as a supplement when using Streaming Replication. A Slave DB that uses WAL Replication as a supplement first copies and fetches the WAL from the Master DB's Archive and performs Replication. After that, it completes the Replication through the WAL Records coming over Streaming. Streaming Replication supports both Sync and Async methods, and the default setting is configured to use the Async method.

### 1.2. Pgpool-II

{{< figure caption="[Figure 4] PostgreSQL Pgpool-II" src="images/pgpool.png" width="600px" >}}

Pgpool-II is a Middleware that performs various roles between PostgreSQL and Apps. [Figure 4] shows PostgreSQL operating together with Pgpool-II. The first role performed by Pgpool-II is Connection Pooling. Pgpool-II establishes a certain number of Connections with the PostgreSQL instances in advance to create a Connection Pool. After that, whenever an App establishes a Connection with Pgpool-II, Pgpool-II allocates a Connection from the Connection Pool to that App. Through Connection Pooling, Pgpool-II can prevent an excessive number of App Connections, and Connection Filtering is also possible. In addition, even if the Master DB and Slave DB are swapped due to Failover, since the App establishes a Connection only with Pgpool-II, Pgpool-II can support Auto Failover for the App.

The second main function of Pgpool-II is Load Balancing of Read requests (Select Queries). Pgpool-II can increase Read performance by appropriately Load Balancing Read requests between the Master DB and Slave DBs. A Weight can be set for each DB, and Read requests can be distributed in proportion to the Weight. When using the Async method for Replication, a Data difference between the Master DB and Slave DB can occur, and Pgpool-II also has a function that prevents Read requests from being sent to a Slave DB if that Slave DB differs from the Master DB by a certain amount of Data. If you want to provide the App with an Endpoint that sends Read requests only to the Master because of the Data difference between the Master DB and Slave DB, a separate Pgpool-II must be run and provided to the App. Write requests are always delivered only to the Master DB by Pgpool-II.

Pgpool-II provides a function to group multiple Pgpool-II instances in Active-standby for HA. Apps always access only the Active Pgpool-II through a VIP. Pgpool-II has a built-in Watchdog, and it monitors the state of external Pgpool-II instances through the Watchdog. If the Active Pgpool-II dies, the Standby Pgpool-II sets the VIP to itself so that Apps can access it, and continues operation by being promoted to the Active Pgpool-II.

## 2. References

* Replication : [https://severalnines.com/blog/postgresql-streaming-replication-deep-dive](https://severalnines.com/blog/postgresql-streaming-replication-deep-dive)
* Pgpool-II : [https://www.cybertec-postgresql.com/en/connection-pooling-intro-pgbouncer-and-pgpool-ii](https://www.cybertec-postgresql.com/en/connection-pooling-intro-pgbouncer-and-pgpool-ii/)
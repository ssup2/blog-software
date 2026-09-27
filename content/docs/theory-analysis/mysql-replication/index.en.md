---
title: MySQL Replication
---

This post analyzes Replication techniques for MySQL HA (High Availabilty).

## 1. Master-Slave Replication

{{< figure caption="[Figure 1] MySQL Master-Slave Replication" src="images/master-slave-replication.png" width="600px" >}}

**Master-Slave Replication** is a technique that performs Replication through one Master DB and multiple Slave DBs. [Figure 1] shows Master-Slave Replication. The Master changes the DB according to the DB change Queries received from Clients, and performs Replication by delivering the changes to the Slave DBs. Therefore the Master operates in Read/Write Mode and the Slaves operate in Read Mode. Clients must send Write requests to the Master, while Read requests can be sent to either the Master or an appropriate Slave. Generally, an LB (Load Balancer) is placed in front of the Slaves to distribute the Read requests coming to the Slaves and increase Read performance.

Two Replication methods are supported: Async and Semi-sync. Since neither method is a fully synchronized Sync method, a Slave DB can be out of sync with the Master DB for a short moment. As the number of Slave DBs increases, the number of DBs that can perform Reads concurrently also increases, so Read performance can be improved. However, even if the number of Slave DBs increases, Write performance is not improved because DB change Queries are propagated from the Master DB.

If a failure occurs on the Master DB, the DB administrator can respond to the failure by restarting the failed Master DB, or by promoting a Slave DB to a new Master DB. Both response methods are performed **manually** with the DB administrator's intervention. Responding to the failure by restarting the Master DB is the safest method with no concern of Data loss, but it has the disadvantage that Write requests cannot be sent to the DB until the Master DB is recovered.

The failure response method of promoting a Slave DB and using it as a new Master has the advantage of minimizing the Master's Downtime, but Data loss can occur because the Master DB and Slave DBs do not use a fully synchronous Replication method. It also has the disadvantage that the App's configuration must be changed so that the App can send requests to the new Master DB, or the Network configuration between the App and the Master DB must be changed. When a failure occurs on a Slave DB, the response differs depending on which Replication method is applied.

### 1.1. Async Replication

{{< figure caption="[Figure 2] MySQL Master-Slave Async Replication Process" src="images/master-slave-async-replication.png" width="550px" >}}

To understand the Replication process, the **Binary Log** and **Relay Log** must be understood. The Binary Log is used in every MySQL and is the Log used to record DB changes. The Binary Log is a separate Log, different from the Redo Log recorded by InnoDB, MySQL's DB Engine. The Binary Log records MySQL's overall operations, while the Redo Log is the Log where InnoDB internally records Queries for Query re-execution and Query Rollback. The Relay Log exists only on Slave DBs and is the Log used to copy and store the Master DB's Binary Log.

[Figure 2] shows the Async Replication process. The Master DB changes the DB regardless of the Slave DBs and records the DB changes in its Binary Log. When a Slave DB establishes a Connection to the Master for Replication, one Dump Thread is created on the Master DB, and two Threads, an I/O Thread and a SQL Thread, are created on the Slave. The Master DB's Dump Thread and the Slave DB's I/O Thread maintain a Connection. The Slave DB's I/O Thread requests the Master DB's Binary Log through the Master DB's Dump Thread, receives it, and copies it into its own Relay Log. The Slave DB's SQL Thread changes its own DB based on the Relay Log contents and records the changes in its own Binary Log.

The Master DB performs no additional operations for the Slave DBs while executing a Transaction. Replication proceeds separately from the Transaction. Therefore the Master DB experiences almost no performance degradation caused by the Slave DBs. Because it is an Async method, even DB changes whose Transaction has completed on the Master DB are not immediately reflected on the Slaves. This means that a sudden failure of the Master DB can lead to Data loss. A Slave DB failure has no effect on the Master DB's Transactions. After recovering, the failed Slave DB continues the interrupted Replication based on its own Relay Log, Binary Log, and the Master DB's Binary Log.

### 1.2. Semi-sync Replication

{{< figure caption="[Figure 3] MySQL Master-Slave Semi-sync Replication Process" src="images/master-slave-semi-sync-replication.png" width="900px" >}}

[Figure 3] shows the Semi-sync Replication process. Semi-sync Replication is a method in which the Master DB proceeds with the Transaction after receiving an ACK from a Slave DB indicating that the Relay Log has been written. Therefore it causes more DB performance degradation compared to the Async Replication method, but it better guarantees synchronization between the Master and Slave DBs. The Semi-sync Replicaiton method is divided into two methods, `AFTER-COMMIT` and `AFTER-SYNC`, depending on when the Master DB delivers the DB changes to the Slave DBs.

If the Master DB does not receive the Relay Log ACK from a Slave DB, the Transaction is suspended. Such Transcation suspension can be minimized by having multiple Slave DBs. This is because the Master DB delivers the DB changes to all Slave DBs, but proceeds with the Transaction once it receives a Relay Log ACK from a single Slave DB.

## 2. Group Replication

Group Replication is a technique that performs Replication by organizing multiple DB Instances into a Group. Clients access the DB through MySQL Router. MySQL Router performs roles such as Proxy and LB. Group Replication supports two Modes: **Single-primary** and **Multi-primary**.

### 2.1. Single-primary

{{< figure caption="[Figure 4] MySQL Group Single-primary Replication" src="images/group-replication-single-primary.png" width="600px" >}}

[Figure 4] shows Single-primary Mode. It is a Mode that operates similarly to Master-slave Replication. Only one DB operates as the Primary DB, and it is the only DB that receives and processes Read/Write requests from MySQL Router. The remaining DBs operate as Secondary DBs and receive and process only Read requests from MySQL Router. Replication between the Primary and Secondary DBs supports the same two methods as Master-Slave Replication: Async and Semi-Sync.

MySQL Router provides two Ports: a Read/Write Port that receives Read/Write requests, and a Read Port that receives Read requests. Read/Write requests sent to the Read/Write Port are delivered to the Primary DB, and Read requests sent to the Read Port are delivered to an appropriate Secondary DB through Load Balancing. Therefore the App must send requests to the appropriate MySQL Router Port as needed. One of the differences from Master-Slave Replication is that when a failure occurs on the Primary DB, a Secondary DB is **automatically** promoted to the Primary DB.

### 2.1. Multi-primary

{{< figure caption="[Figure 5] MySQL Group Multi-primary Replication" src="images/group-replication-multi-primary.png" width="600px" >}}

[Figure 5] shows Multi-primary Mode. In Multi-primary Mode, all DBs operate as Primary Nodes. Therefore the App's Read/Write requests can be delivered to any DB. MySQL Router delivers requests to an appropriate DB according to the DBs' load. If a Commit conflict occurs because different Primary DBs change the same Row simultaneously, the changes of the Primary DB that **committed first** are applied, and the Primary DB that committed later is Aborted. As in Single-primary Mode, even if a DB failure occurs, the Primary DB and MySQL Router **automatically** fail over, so the DB can continue to be used without the DB administrator's intervention.

{{< figure caption="[Figure 6] MySQL Group Multi-primary Replication, Certify Process" src="images/group-replication-multi-primary-certify-replication.png" width="550px" >}}

[Figure 6] shows the Certify and Replication process of Multi-primary Mode. Certify refers to the Commit conflict check process. The first Primary DB that receives a Commit request from the App changes its own DB and delivers a Certify request and the DB changes to the second Primary DB that will perform Replication. The second Primary DB performs Certify, delivers the Certify result to the first Primary DB, and then changes its own DB. The first Primary delivers the Commit result to the App only after receiving the Certify completion from the second Primary. This Certify process is a major cause of Commit Overhead. The Certify and Replication process is not a fully Sync method, but is similar to a Semi-sync or 2 Phase-Commit method.

## 3. Galera Cluster

{{< figure caption="[Figure 7] MySQL Galera Cluster" src="images/galera-cluster.png" width="600px" >}}

Galera Cluster is a Multi-master Replication technique very similar to Group Replication's Multi-primary Mode. Although Galera Cluster documentation describes the Replication process as a Sync or Virtual Sync method, it is actually implemented similarly to a Semi-sync or 2 Phase-Commit method, like Group Replication's Multi-primary Mode. [Figure 7] shows Galera Cluster. Clients access the DBs through an LB. Each DB communicates with the others via the wsrep API through the wsrep (Write Set Replication) Plugin and performs Replication.

Galera Cluster and Group Replication's Multi-primary Mode are similar but have a few differences. In Galera Cluster, when a DB is changed, the Commit succeeds only when the changes are applied to all DBs. If a Galera Cluster consists of 3 DBs, this means the Commit succeeds only when the changes are applied to all 3 DBs. In contrast, in Group Replication's Multi-primary Mode, the Commit succeeds when the changes are applied to only a majority of the DBs. If Group Replication's Multi-primary Mode consists of 3 DBs, the Commit succeeds when the changes are applied to only 2 of the 3 DBs. Galera Cluster can also be applied to MariaDB and Percona, which are based on MySQL, but Group Replication can currently be applied only to MySQL.

## 4. References

* MySQL High Availability Architectures : [http://skillachie.com/2014/07/25/mysql-high-availability-architectures/](http://skillachie.com/2014/07/25/mysql-high-availability-architectures/)
* Overview of Different MySQL Replication Solutions : [https://www.percona.com/blog/2017/02/07/overview-of-different-mysql-replication-solutions/](https://www.percona.com/blog/2017/02/07/overview-of-different-mysql-replication-solutions/)
* Master-Slave Replication : [https://www.percona.com/blog/2013/01/09/how-does-mysql-replication-really-work/](https://www.percona.com/blog/2013/01/09/how-does-mysql-replication-really-work/)
* Semi-sync : [http://gywn.net/tag/semi-sync-replication/](http://gywn.net/tag/semi-sync-replication/)
* Replication, Master : [https://stackoverflow.com/questions/38036955/when-to-prefer-master-slave-and-when-to-cluster](https://stackoverflow.com/questions/38036955/when-to-prefer-master-slave-and-when-to-cluster)
* Group Replication : [https://www.percona.com/live/17/sessions/everything-you-need-know-about-mysql-group-replication](https://www.percona.com/live/17/sessions/everything-you-need-know-about-mysql-group-replication)
* Group Replication : [https://lefred.be/content/mysql-group-replication-synchronous-or-asynchronous-replication/](https://lefred.be/content/mysql-group-replication-synchronous-or-asynchronous-replication/)
* Group Replicaiton : [https://scriptingmysql.wordpress.com/category/mysql-replication/](https://scriptingmysql.wordpress.com/category/mysql-replication/)
* Group Replication : [https://dev.mysql.com/doc/mysql-router/8.0/en/mysql-router-innodb-cluster.html](https://dev.mysql.com/doc/mysql-router/8.0/en/mysql-router-innodb-cluster.html)
* Galera Cluster : [https://www.slideshare.net/MyDBOPS/galera-cluster-for-high-availability](https://www.slideshare.net/MyDBOPS/galera-cluster-for-high-availability)
* Group Replication, Galera Cluster : [https://www.percona.com/blog/2017/02/24/battle-for-synchronous-replication-in-mysql-galera-vs-group-replication/](https://www.percona.com/blog/2017/02/24/battle-for-synchronous-replication-in-mysql-galera-vs-group-replication/)
* Group Replicaiton, Galera Cluster : [https://severalnines.com/resources/tutorials/mysql-load-balancing-haproxy-tutorial](https://severalnines.com/resources/tutorials/mysql-load-balancing-haproxy-tutorial)

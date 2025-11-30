---
title: Couchbase
---

Analyze Couchbase.

## 1. Couchbase

{{< figure caption="[Figure 1] Document-Node Mapping" src="images/document-node-mapping.png" width="800px" >}}

Couchbase is a Document-Oriented DB that stores hierarchical Key-Value Data like JSON. [Figure 1] shows how Documents managed by Couchbase are mapped to Nodes. Couchbase's Documents are located in Document Groups called **Buckets**. Documents are separated and stored in Shards called **vBuckets** through CRC32 Hashing algorithm of Document's Key. Couchbase performs Replication and Rebalancing in vBucket units. There are 1024 vBuckets per Bucket. vBuckets are mapped to specific Nodes forming Couchbase Cluster through vBucket-Node Map.

Couchbase has **Built-in Cache** based on Memcached. Since most Data-related operations are performed in Built-in Cache, i.e., Memory, fast Data processing is possible. Data stored or changed in Built-in Cache is designed to be asynchronously written to Disk. Couchbase also provides Memcached compatibility features to replace existing Memcached with Couchbase using Built-in Cache.

### 1.1. Bucket

Bucket is a Document Group managed by Couchbase. Multiple Buckets can exist in one Couchbase Cluster, and Resource usage can be limited for each Bucket. There are three types of Buckets: Couchbase, Ephemeral, and Memcached.

* Couchbase : Bucket Type that uses memory + disk. Data is stored in Memory and Disk, and when Memory is full, Data in Memory is overwritten. However, since Data remains on Disk, it does not lead to Data loss. Supports Replication and Rebalancing.

* Ephemeral : Bucket Type that uses only memory. Data is stored only in Memory, and when Memory is full, existing Data is overwritten. This leads to Data loss. Supports Replication and Rebalancing.

* Memcached : Method that uses only memory. Stores Data using Ketama consistent hashing like memcached. Does not support Replication and Rebalancing.

### 1.2. Replication

Couchbase's Replica exists only for HA. Replica is not provided to other Clients until it becomes Active state due to Failover. Couchbase Cluster provides the following four ACK options for Client's Write operations.

* Memory : Sends ACK when Data is stored in Memory.
* Memory, Disk : Sends ACK when Data is stored in Primary Node's Memory and Disk.
* Memory, Replica : Sends ACK when Data is stored in Primary Node's Memory and Secondary Node's Memory.
* Memory, Disk, Replica : Sends ACK when Data is stored in Primary Node's Memory and Disk, and Secondary Node's Memory.

## 2. References

* [https://docs.couchbase.com/server/5.0/architecture/core-data-access-buckets.html](https://docs.couchbase.com/server/5.0/architecture/core-data-access-buckets.html)
* [https://docs.couchbase.com/server/6.0/learn/buckets-memory-and-storage/vbuckets.html](https://docs.couchbase.com/server/6.0/learn/buckets-memory-and-storage/vbuckets.html)
* [https://docs.couchbase.com/server/4.1/concepts/data-management.html](https://docs.couchbase.com/server/4.1/concepts/data-management.html)



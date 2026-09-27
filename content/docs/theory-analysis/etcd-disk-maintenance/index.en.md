---
title: etcd Disk Maintenance
---

This post analyzes the Disk Maintenance of etcd.

## 1. etcd Compaction

Compaction of etcd can be divided into Log Compaction and Revision (History) Compaction.

#### 1.1. Log Compaction

When etcd forms a Server Cluster, it uses the Raft Consensus Algorithm to keep the Key-Value Data consistent between Servers. The Raft Consensus Algorithm basically replicates the Log of each Server and keeps the Key-Value Data consistent through the Log. Therefore, as an etcd Server Cluster performs Data Writes, Logs keep accumulating. In other words, the Disk capacity used by etcd increases. The way to remove these Logs is to take a **Snapshot**. When a Snapshot is taken, the Key-Value Data at the time of the Snapshot remains as a Log, and the previous Logs are removed.

etcd takes a Snapshot by itself and performs Log Compaction when a certain number of Logs have accumulated. Through the `--snapshot-count` Option of the etcd Server, you can configure how many Logs must accumulate before a Snapshot is taken. In Versions after v3.3.0, the default value is 100,000. etcd also caches Logs in Memory for fast Log replication between Servers, and when a Snapshot is taken, the Logs cached in Memory are also removed. Therefore, depending on the `--snapshot-count` value, Memory usage and Server Log replication speed are in a Trade Off relationship.

#### 1.2. Revision (History) Compaction

```shell {caption="[Shell 1] etcd Revision"}
# revision 12 
$ etcdctl put key1 1
OK
# revision 13
$ etcdctl put key2 2
OK
# revision 14
$ etcdctl put key1 10
OK
# revision 15
$ etcdctl put key2 20
OK

# revision 15
$ etcdctl get --prefix key
key1
10
key2
20
$ etcdctl get --prefix key --rev 15
key1
10
key2
20
# revision 14
$ etcdctl get --prefix key --rev 14
key1
10
key2
2
```

Separately from the Log, etcd manages the Revision (History) of Key-Value Data. [Shell 1] shows an example of etcd Revisions. Each time a key is set, the Revision also increases. Through the `--rev` Option, you can fetch the Key-Value Data of a specific Revision. As these Revisions accumulate, the Disk capacity used by etcd also increases. Even if a Snapshot is performed, Revisions are not removed because Revisions are Data managed in a separate area, not in the Log.

Revisions can be forcibly removed through the `etcdctl compact` command. In addition, through the `--auto-compaction` command of the etcd Server, Revisions can be removed based on Revisions or on a specific interval. By default, it is configured to remove Revisions every hour.

## 2. etcd Defragmentation

Even if Log Compaction and Revision Compaction are performed, if Key-Value Data is repeatedly Read/Written, Fragmentation occurs and the actual Disk usage of etcd gradually increases. etcd provides Defragmentation to remove this Fragmentation. Defragmentation can be performed through the `etcdctl defrag` command.

While etcd performs Defragmentation, its functionality is suspended. To prevent an outage due to the suspension, etcd must be configured as a Server Cluster and then Defragmentation must be performed on each Server separately. The Defragmentation operation is not replicated between Servers and is not delivered to other Servers. Therefore, the etcd administrator must perform Defragmentation on each Server of the Server Cluster one by one through the `etcdctl defrag` command.

## 3. References

* Maintenance : [https://etcd.io/docs/v3.4.0/op-guide/maintenance/](https://etcd.io/docs/v3.4.0/op-guide/maintenance/)
* A Few Notes on etcd Maintenance : [https://blog.gojekengineering.com/a-few-notes-on-etcd-maintenance-c06440011cbe](https://blog.gojekengineering.com/a-few-notes-on-etcd-maintenance-c06440011cbe)
* etcdserver: increase snapshot to 100,000 · etcd-io/etcd@c5a9d54 : [https://github.com/etcd-io/etcd/commit/c5a9d548358f64483b9fc1726f1a64722c4cdf6f](https://github.com/etcd-io/etcd/commit/c5a9d548358f64483b9fc1726f1a64722c4cdf6f)

---
title: Elasticsearch Shard, Replica
---

Analyzes content related to Elasticsearch Shard and Replica.

## 1. Elasticsearch Shard, Replica

{{< figure caption="[Figure 1] Shard, Replica Recovery" src="images/elasticsearch-shard-replica.png" width="550px" >}}

[Figure 1] shows Shard and Replica managed by Elasticsearch. The original Shard is called Primary Shard, and the copy of Primary Shard is called Replica. [Figure 1] shows an Index with 5 Shards and 1 Replica. Both Shard and Replica can be configured at the **Index level**, and the number of Shards can only be set when the Index is created and cannot be changed after the Index is created. The number of Replicas can be freely changed. In Elasticsearch 6.0 and below, the Default Shard is 5 and Default Replica is 1. In Elasticsearch 7.0 and above, the Default Shard is 1 and Default Replica is 1.

[Figure 1] also shows the recovery process of Shard and Replica when a failure occurs in a Data Node. When a failure occurs in Data Node C, since Primary Shard 1 existed in Data Node C, Replica 1 in Data Node D becomes Primary Shard. Then, to match the Replica count of 1, Primary Shard 1 in Data Node D was replicated to Data Node B where Replica 1 does not exist. Since Replica 4 existed in Data Node C, to match the Replica count of 1, Primary Shard 4 in Data Node B was replicated to Data Node D where Replica 4 does not exist.

## 2. References

* [https://esbook.kimjmin.net/03-cluster/3.2-index-and-shards](https://esbook.kimjmin.net/03-cluster/3.2-index-and-shards)
* [https://www.elastic.co/guide/en/elasticsearch/reference/current/docs-replication.html](https://www.elastic.co/guide/en/elasticsearch/reference/current/docs-replication.html)
* [https://nesoy.github.io/articles/2019-01/ElasticSearch-Document](https://nesoy.github.io/articles/2019-01/ElasticSearch-Document)


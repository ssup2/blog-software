---
title: Memcached
---

This post analyzes Memcached, which is widely used as a distributed Cache in various Systems.

## 1. Memcached

**Memcached** is, as the name implies, a **distributed Key-Value Storage designed for Caching** various Data. The core of a Caching System is fast Read/Write performance for Data. Therefore, Memcached also focuses on fast Read/Write performance for Data. Memcached maximizes Data Read/Write performance by using only **Memory** without using Disk when storing Data. Since Data is stored only in Memory, Data can be lost at any time, but Data loss is not fatal in a Caching System, so it is not a big problem. Memcached supports both a **Text Protocol** and a **Binary Protocol** when communicating with Clients, but it is better to use the Binary Protocol for performance.

### 1.1. Cluster

{{< figure caption="[Figure 1] Memcached Cluster" src="images/memcached-cluster.png" width="700px" >}}

Memcached is generally used by composing a Cluster. [Figure 1] shows a Memcached Cluster. Strictly speaking, a Memcached Cluster is hard to regard as a Cluster. This is because Memcached instances do not exchange any Data with each other and only perform the simple operation of Reading/Writing Data according to Client requests. Most Cluster-related functions, such as Data distribution among Memcached instances and checking the state of each Memcached composing the Cluster, are performed by the Client Lib (Library). Therefore, the Memcached Cluster functionality is determined by the Client Lib.

In general, the Client Lib distributes Data using simple Hashing. The Client Lib also maintains Sessions with all Memcached instances, and it identifies the state of each Memcached through the state of the Session. If a particular Memcached dies and its Session is disconnected, the Client Lib distributes Data excluding the Memcached whose Session was disconnected. These Data distribution and Memcached state checking operations are performed independently by each Client Lib. Therefore, a Client Lib does not interact with other Client Libs.

Since Memcached is a Caching System, it assumes that Data stored in Memcached can be lost at any time. Therefore, most Client Libs do not support Data Replication for the Cluster.

## 2. References

* AWS re:Invent DAT207: Amazon ElastiCache (SlideShare) : [https://www.slideshare.net/AmazonWebServices/dat207](https://www.slideshare.net/AmazonWebServices/dat207)
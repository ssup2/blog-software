---
title: Couchbase Memcached Compatibility
---

This document analyzes Couchbase's Memcached compatibility features.

## 1. Couchbase Memcached Compatibility

{{< figure caption="[Figure 1] Memcached compatibility using Couchbase and Moxi" src="images/couchbase-memcached-compatibility.png" width="700px" >}}

Couchbase provides Memcached compatibility so that existing Memcached deployments can be replaced with Couchbase. When an existing Memcached cluster is replaced with a Couchbase cluster, data processing performance decreases, but you gain access to data replication, HA, and data rebalancing features that a Memcached cluster cannot provide. In addition, by using a Couchbase-type bucket, you can prevent data loss caused by data overwrites when all memory space is used, which can occur with Memcached.

[Figure 1] shows how to replace existing Memcached with Couchbase and Moxi. Three approaches are provided: Couchbase Library, Server Side Moxi, and Client Side Moxi. **Moxi** is a proxy server that converts the Memcached protocol to the Couchbase protocol between a Memcached client and a Couchbase server.

* Couchbase Library : A method that replaces the existing Memcached library with the Couchbase library. It can minimize performance degradation, but has the disadvantage of requiring modifications to existing applications.

* Server Side Moxi : A method that runs Moxi on a server node to convert the Memcached protocol to the Couchbase protocol. This approach is not recommended today due to SPOF (single point of failure) issues.

* Client Side Moxi : A method that runs Moxi on a client node to convert the Memcached protocol to the Couchbase protocol. The application must be modified so that the Memcached library connects to Moxi on the client node rather than to Memcached on the server node.

## 2. References

* [https://forums.couchbase.com/t/moxi-with-memcached-bucket/18438](https://forums.couchbase.com/t/moxi-with-memcached-bucket/18438)

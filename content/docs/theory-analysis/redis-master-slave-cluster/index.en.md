---
title: Redis Master-slave, Cluster
---

This post analyzes Redis Master-slave and Redis Cluster.

## 1. Redis Master-slave

{{< figure caption="[Figure 1] Redis Master-slave" src="images/redis-master-slave.png" width="600px" >}}

**Redis Master-slave** is the most basic Replication technique provided by Redis. [Figure 1] shows the Architecture of a Redis Master-slave configuration. Redis's Master-slave technique has many similarities with MySQL's Master-slave Replication technique. Multiple Slaves can attach to a single Master. The Master operates in Read-Write Mode and the Slaves operate in Read-Only Mode. A Client can attach to the Master to perform Write operations, or attach to an appropriate Master or Slave to perform Read operations as needed.

**Replication between Master and Slave uses an Async method.** When Data changes, the Master records the changes in the backlog. A Slave connects to the Master and performs Replication based on the contents of the backlog. Because it is an Async method, Data stored on the Master may not be stored on the Slave for a short period of time. Therefore, the Client (App) must take this Async characteristic into account when reading Data from a Slave.

When the Master dies, the Slaves periodically request Connections to the Master and wait until the Master comes back to life. When the Master comes back, the Slaves perform Replication to synchronize with the Master. If recovering the Master is difficult, the Redis administrator must manually promote one of the Slaves to Master and configure the remaining Slaves to replicate from the new Master. After the Master is replaced, the dead Master must be configured as a Slave of the new Master when it is used again.

### 1.1. Sentinel

When the Master stops operating, the Client can perform Read operations through the Slaves, but cannot perform Write operations. Therefore, the Master's Downtime reduces the availability of the Redis Cluster. Sentinel is the App that helps solve this availability problem. **Sentinel detects whether the Master has died, and when the Master dies, it promotes one of the Slaves to Master and demotes the existing Master to a Slave.** Since this is done automatically without intervention from the Redis administrator, it minimizes the Master's Downtime and makes HA (High Availabilty) possible.

Sentinels are generally configured in odd numbers to prevent Split-brain. [Figure 1] shows Sentinels configured on Nodes separate from Redis, but it is also fine to configure Sentinel on the same Node as Redis. The Sentinel configuration includes a setting called Quorum. Quorum is the threshold that determines how many Sentinels must detect the failure of a specific Redis before it is judged as a failure. For example, if the Quorum value is set to 2, Sentinel performs failure handling for a specific Redis only when 2 or more Sentinels determine that the Redis has failed.

### 1.2. HAProxy

In a Redis Master-slave configuration, the Master operates in RW Mode and the Slaves operate in RO Mode, so the Client must know the Master's IP/Port and the Slaves' IP/Port respectively, and attach to the appropriate Master or Slave as needed. Therefore, when the Master fails and is replaced, the Client's Redis configuration must also change accordingly. However, changing the configuration of every Client that uses Redis each time the Master is replaced is not an easy task. HAProxy is generally used to solve this problem.

**HAProxy provides Clients with consistent End-points for accessing the Redis Master and Slaves.** In [Figure 1], Port X represents the Port for accessing the Master, and Port Y represents the Port for accessing the Slaves. HAProxy uses `tcp-check` to periodically determine whether each Redis is operating as a Master or a Slave, and dynamically sets Routing Rules accordingly. Therefore, even if the Master is replaced, HAProxy can provide consistent End-points to Clients. If only one HAProxy is configured, the HAProxy becomes a SPOF (Single Point of Failure) when it dies, hindering Redis's HA. Therefore, multiple HAProxies should be presented to Clients as a single HAProxy using an L4 Load Balancer and VRRP.

## 2. Redis Cluster

{{< figure caption="[Figure 2] Redis Cluster" src="images/redis-cluster.png" width="600px" >}}

Redis Cluster is the Replication and Sharding technique provided by Redis. [Figure 2] shows the Architecture of a Redis Cluster configuration. Each Redis that makes up the Cluster connects directly to all the other Redis instances and communicates through the gossip Protocol. Through the gossip Protocol, each Redis exchanges Redis state information. The gossip Protocol uses a Port number 10000 higher than the Port number used by Cluster Clients. Since the default Port number used by Cluster Clients is 6379, the default Port number used by the gossip Protocol is 16379. Cluster Clients also connect directly to all the Redis instances that make up the Cluster to exchange Data.

Redis Cluster has a Multi-master, Multi-slave structure, and each Redis operates as either a Master or a Slave. Each Master owns a Data storage region called a **Hash Slot**, divided among the Masters. Hash Slots have addresses from 0 to 16384. [Figure 2] shows the Hash Slots divided equally into 3 parts among the Masters. The Hash Slot that Data uses is determined by the result of Hashing the Data's Key. Hashing uses CRC16 and the Modulo operator so that Data is distributed evenly across the Hash Slots. Therefore, Data is stored in proportion to the size of each Master's Hash Slot.

The Hash Slots assigned to each Master can be changed dynamically by the Redis administrator. Therefore, it is also possible to dynamically add or remove Masters. Each Master can have multiple Slaves. [Figure 2] shows each Master having one Slave. **Replication between Master and Slave is performed in an Async manner, the same as in the Redis Master-slave configuration.** Therefore, Slaves can also be freely added or removed dynamically.

When a Master Redis dies, the dead Master's Slave Redis detects the Master's death through the gossip Protocol and promotes itself to Master to take the Master's place. Afterwards, if the dead Master comes back and operates again, it demotes itself to a Slave. Because Replication between Master and Slave is performed in an Async manner, the death of a Master can break Data consistency between the Master and the Slave. When a Data conflict occurs between Master and Slave due to broken Data consistency, consistency is always resolved **based on the Data of the Redis that became Master later.**

### 2.1. Cluster Client

When a Cluster Client first establishes a Connection with a Redis Cluster, it obtains the state information of each Redis that makes up the Redis Cluster. The state information includes IP, Port, Master/Slave Mode, and assigned Hash Slots. **Based on the state information obtained from the Redis Cluster, the Cluster Client establishes direct Connections with all the Redis instances that make up the Redis Cluster.** After that, the Cluster Client directly calculates the Hash Slot where Data will be Read/Written based on the Data's Key, and performs Read/Write directly against the Redis to which that Hash Slot is assigned.

If the Hash Slot placement changes and the Cluster Client delivers a Read/Write request to the wrong Redis, the Redis that receives the request redirects the request by delivering the connection information of the Redis that can handle the request along with the **`MOVED` command**. The Cluster Client delivers the request again to the Redis that can handle it, based on the connection information that came with the `MOVED` command. For example, if a Write request is sent to a Slave Redis, the Slave Redis passes the information of the Master Redis that can handle the request to the Cluster Client. Generally, when a Cluster Client receives the `MOVED` command, it obtains the Cluster state information from the Cluster again and refreshes the Hash Slot and Redis connection information. Because the Cluster Client must be able to handle the state information obtained from the Redis Cluster and the `MOVED` command in this way, existing Redis Master-slave Libraries cannot be used as-is, and a Library for Redis Cluster must be used.

Generally, even if a Slave Redis in a Redis Cluster receives a Read request that it can handle, it redirects the Read request to its Master. Only Read requests coming from a Client that has entered Read Mode through the **`READONLY`** command can be handled by the Slave Redis.

### 2.2. Cluster Proxy

As mentioned above, the Cluster Client of a Redis Cluster has the characteristic of needing to be directly connected via the Network to all the Redis instances that make up the Cluster. In other words, each Redis in the Redis Cluster must have at least one End-point for Cluster Clients. Because of this characteristic, as the number of Redis instances in the Cluster or the number of Cluster Clients increases, the number of Network Connections grows exponentially. It also becomes a factor that makes it difficult to configure a Redis Cluster in a Network environment that provided Clients with only 2 End-points, Master and Slave, in a Redis Master-slave setup. A Cluster Proxy must be used to solve these problems.

A Cluster Proxy provides Proxy Clients with consistent End-points. Cluster Proxies include Applications such as corvus and predixy. Because a Cluster Proxy requires additional behavior specific to Redis Cluster, such as request Redirection, general-purpose Proxies like HAProxy cannot be used as a Cluster Proxy. Like the HAProxy in Redis Master-slave, it is recommended to configure multiple Cluster Proxies with an L4 Load Balancer and VRRP to guarantee the HA of the Cluster Proxy.

## 3. References

* Redis Cluster and Sentinel Configuration and Operation : [https://www.letmecompile.com/redis-cluster-sentinel-overview/](https://www.letmecompile.com/redis-cluster-sentinel-overview/)
* Master-slave : [https://redis.io/topics/replication](https://redis.io/topics/replication)
* Sentinel : [https://redis.io/topics/sentinel](https://redis.io/topics/sentinel)
* Cluster : [https://redis.io/topics/cluster-spec](https://redis.io/topics/cluster-spec)
* Cluster : [http://redisgate.kr/redis/cluster/redis-cli-cluster.php](http://redisgate.kr/redis/cluster/redis-cli-cluster.php)

---
title: etcd Clustering
---

This post analyzes etcd's Clustering technique.

## 1. etcd Server Clustering

{{< figure caption="[Figure 1] etcd Server Cluster" src="images/etcd-cluster-architecture.png" width="700px" >}}

An etcd Server can provide HA (High Availability) through Clustering. [Figure 1] shows an etcd Server Cluster.

#### 1.1. Server Clustering

Servers operate as a **Leader** and **Followers** according to the Raft Algorithm. According to the Raft Algorithm, a Client's Request must be delivered to the Leader Server. A Server acting as a Follower performs a Proxy role that forwards a Client's request to the Leader Server when it receives one.

For Servers to perform Clustering, each Server must know the IP/Port of every Server participating in the Cluster. The IP/Port information of all Servers participating in the Cluster can be configured **Statically** through Server Parameters, or it can be configured so that each Server obtains it by itself using the **Discovery** feature. The Discovery feature provides two techniques: one provided by etcd itself and one that utilizes DNS.

```shell {caption="[Shell 1] Creating a Server Cluster"}
$ etcd --name infra0 --initial-advertise-peer-urls http://10.0.1.10:2380 \
  --listen-peer-urls http://10.0.1.10:2380 \
  --listen-client-urls http://10.0.1.10:2379,http://127.0.0.1:2379 \
  --advertise-client-urls http://10.0.1.10:2379 \
  --initial-cluster-token etcd-cluster-1 \
  --initial-cluster infra0=http://10.0.1.10:2380,infra1=http://10.0.1.11:2380,infra2=http://10.0.1.12:2380 \
  --initial-cluster-state new
```

[Shell 1] shows the command that builds a Server Cluster by Statically entering the IP/Port of all Servers when building a Cluster with 3 Servers. It shows the command that runs the first of the 3 Servers. You can see that the `--initial-cluster` Parameter includes the IP/Port information of not only the first Server but also the second and third Servers. When starting the second and third Servers, the IP/Port information of the remaining Servers must also be included, similarly to [Shell 1].

Communication inside the Server Cluster can be encrypted using TLS.

#### 1.2. Client Load Balancer

```shell {caption="[Shell 2] etcdctl"}
$ etcdctl --endpoints=http://10.0.1.10:2379,http://10.0.1.11:2379,http://10.0.1.12:2379 member list
```

To communicate with the Server Cluster, a Client only needs to know the IP/Port information of some of the Servers participating in the Cluster. If the Client knows the IP/Port information of multiple Servers, the Client distributes requests using a Load Balancer, and when a Server fails, it responds to the failure by itself by re-sending the request to another Server that has not failed. `etcdctl` is etcd's CLI Client. [Shell 2] shows the IP/Port of multiple Servers being passed through the `--endpoints` Parameter of `etcdctl`.

The Client does not know which Server is the Leader Server. Therefore, when the Client performs Load Balancing, the role of the Server is not considered. The Client initially used a method of establishing TCP Connections with all Servers in the Cluster simultaneously, later used a method of establishing one TCP Connection at a time, and currently uses a method of establishing logical Connections with all Servers through gRPC SubConnections.

#### 1.3. Adding/Removing Servers

```shell {caption="[Shell 3] Adding a Server"}
$ etcdctl member add infra2 --peer-urls=http://10.0.1.11:2380
```

```shell {caption="[Shell 4] Removing a Server"}
$ etcdctl member remove [Server ID]
```

Servers can be dynamically added to or removed from the Server Cluster. [Shell 3] shows a Server being added through `etcdctl`. After adding the Server to the Server Cluster through the `etcdctl` command, you just need to start the actual Server. [Shell 4] shows a Server being removed through `etcdctl`. After removing the Server from the Server Cluster through the `etcdctl` command, you just need to shut down the actual Server.

**The important point is that the Quorum changes not when the actual Server is started/removed, but when the Server is added/removed through the `etcdctl` command.** Therefore, the Server addition command must be executed very carefully. If the Server Cluster has 1 Server, the Quorum is 1, so when one Server is added to the Server Cluster through the `etcdctl` command, it is added without any problem. At this point, since the Server Cluster has 2 Servers, the Quorum becomes 2.

```shell {caption="[Shell 5] Unable to add/remove Servers"}
$ etcdctl member add infra2 --peer-urls=http://10.0.1.11:2380
Member 44e87d9a57243f90 added to cluster 35d99f7f50aa4509

ETCD-NAME="infra2"
ETCD-INITIAL-CLUSTER="infra2=http://10.0.1.11:2380,node01=http://192.168.0.61:2380"
ETCD-INITIAL-ADVERTISE-PEER-URLS="http://10.0.1.11:2380"
ETCD-INITIAL-CLUSTER-STATE="existing"

$ etcdctl member add infra3 --peer-urls=http://10.0.1.12:2380
{"level":"warn","ts":"2021-03-07T13:34:30.176Z","caller":"clientv3/retry-interceptor.go:61","msg":"retrying of unary invoker failed","target":"endpoint://client-28ab18bd-4710-44b1-a768-749b75f35c08/127.0.0.1:2379","attempt":0,"error":"rpc error: code = Unknown desc = etcdserver: re-configuration failed due to not enough started members"}

$ etcdctl member remove 44e87d9a57243f90
{"level":"warn","ts":"2021-03-07T13:48:57.530Z","caller":"clientv3/retry-interceptor.go:61","msg":"retrying of unary invoker failed","target":"endpoint://client-abf6cede-ae3d-439d-aded-a700d5ee1838/127.0.0.1:2379","attempt":0,"error":"rpc error: code = DeadlineExceeded desc = context deadline exceeded"}
Error: context deadline exceeded
```

The problem is that if a Server is added but the actual Server is not started, the Server Cluster will only operate in Read Only Mode from then on, and not only Server addition/removal operations but also Data Write operations cannot be performed. Since the Quorum is 2, Server addition/removal or Data Write is possible only when the added Server is running and able to vote. [Shell 5] shows this situation. You can see that after adding the `infra2` Server, the `infra3` Server cannot be added while the `infra2` Server has not actually been started. Even if you try to remove the `infra2` Server to return to the original state, it cannot be removed because the `infra2` Server is not actually running.

To prevent this situation, etcd recommends adding Servers one at a time, starting each one in turn, whenever possible. Also, when replacing a Server in the Server Cluster, it recommends not the method of first adding the new Server to the Server Cluster and then removing the Server to be replaced from the Server Cluster, but the method of first removing the Server to be replaced from the Server Cluster and then adding the new Server to the Server Cluster. This is because adding the new Server to the Server Cluster first unnecessarily increases the Quorum, which can cause the problem described above.

#### 1.3.1. Learner

```console {caption="[Shell 6] Adding a Server as a Learner"}
$ etcdctl member add infra2 --learner --peer-urls=http://10.0.1.11:2380

$ etcdctl member promote [Server ID]
```

With the Raft Algorithm, when a Server is added to the Server Cluster while some Servers in the Server Cluster are in an abnormal state, the added Server can cause availability problems for the Server Cluster while it catches up with the Leader Server's Log. To solve this problem, etcd created a state called Learner. If the `--learner` Option is specified when adding a Server to the Server Cluster, the added Server is added to the Server Cluster in the Learner state. [Shell 6] shows an `etcdctl` example of adding a Server as a Learner.

A Server in the Learner state is included in the Server Cluster, but it only performs the operations of replicating the Leader Server's Log and applying it to the State Machine, and does not participate in voting. When an etcd user judges that the Learner Server's Log replication has progressed sufficiently, the user can change the Learner Server to a Follower Server through the `promote` command.

## 2. References

* etcd FAQ : [https://etcd.io/docs/v3.4.0/faq/](https://etcd.io/docs/v3.4.0/faq/)
* etcd Clustering Guide : [https://etcd.io/docs/v3.4.0/op-guide/clustering/](https://etcd.io/docs/v3.4.0/op-guide/clustering/)
* etcd Client Design : [https://etcd.io/docs/v3.4.0/learning/design-client/](https://etcd.io/docs/v3.4.0/learning/design-client/)
* etcd Learner Design : [https://etcd.io/docs/v3.4.0/learning/design-learner/](https://etcd.io/docs/v3.4.0/learning/design-learner/)
* etcd Runtime Reconfiguration : [https://etcd.io/docs/v3.4.0/op-guide/runtime-configuration/](https://etcd.io/docs/v3.4.0/op-guide/runtime-configuration/)

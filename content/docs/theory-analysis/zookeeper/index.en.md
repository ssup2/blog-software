---
title: ZooKeeper
---

Analyzes Apache ZooKeeper.

## 1. ZooKeeper

ZooKeeper is a **distributed Coordinator** that performs various roles such as Leader election, Node status, and distributed Lock management in distributed system environments. It is recognized for its safety and performance and is used in various Open Source Projects such as Hadoop, HBase, Storm, and Kafka.

### 1.1. Architecture

{{< figure caption="[Figure 1] ZooKeeper Architecture" src="images/zookeeper-architecture.png" width="900px" >}}

Since distributed Coordinators operate as part of distributed systems, if a distributed Coordinator stops working, the distributed system also stops. ZooKeeper uses a **Server Cluster : Client** structure that utilizes multiple Servers to ensure safety. Server Cluster consists of one **Leader** and multiple **Followers**. It is advantageous to configure Server Cluster with an odd number. This is because when Consistency between Servers is broken, Consistency is adjusted based on data from more than half of the Servers.

Each Server consists of Request Processor, Atomic Broadcast, and In-memory DB. Request Processor is only used by Leader Server. All ZNode Write requests from Clients are delivered to Leader Server. Leader Server processes the received ZNode Write requests in Request Processor. Then, it creates and propagates **Transactions** through Atomic Broadcast to ensure that the ZNode Write process is correctly applied to all Servers. Transaction propagation between Atomic Broadcasts uses Zab (Zookeeper Atomic Broadcast Protocol). Zab is a Protocol similar to DB's 2-phase Commit and consists of Leader-Propose, Follower-Accept, and Leader-Commit stages. Transaction propagation through this Zab Protocol is one of Zookeeper's main overheads.

ZNode information is stored in In-memory DB. Replication of In-memory DB can be configured on Local Filesystem. Clients periodically send PING to Servers to inform them of Client's activity. If a Server does not receive PING from a Client for a certain period, it considers that a Client/Network Issue has occurred and terminates the Session. If a Client does not receive PING response from a Server, it considers that a Server/Network Issue has occurred and attempts to connect to another Server.

### 1.2. ZNode

{{< figure caption="[Figure 2] ZooKeeper ZNode" src="images/zookeeper-znode.png" width="700px" >}}

ZooKeeper stores Data and creates hierarchies in **ZNode** units. [Figure 2] shows the Data Model composed of ZNodes. ZNodes are structured in a Tree form based on Root, like a File System. Each ZNode can have Data (byte[]) and Child Nodes.

ZNodes are classified into **Persistent Nodes** and **Ephemeral Nodes**. Persistent Nodes are Nodes that remain even if Clients terminate. Ephemeral Nodes are Nodes that disappear when Clients terminate and cannot have Children. Also, ZNodes can be classified into **Sequence Nodes** and regular Nodes. Sequence Nodes have numbers appended after the Node name when created, and the numbers do not overlap. Both Persistent Nodes and Ephemeral Nodes can become Sequence Nodes. Through Server's Atomic Broadcast, ZNode create/change/delete operations show Sequential Consistency and Atomicity characteristics from the Client's perspective.

### 1.3. Watcher

{{< figure caption="[Figure 3] Zookeeper Watcher" src="images/zookeeper-watcher.png" width="900px" >}}

Watcher performs the role of first informing Clients of changes to ZNodes. Clients first register a Watcher for a specific ZNode. Then, when the ZNode's Data changes or Child Nodes are created/deleted, it delivers an Event to Clients indicating that changes have occurred.

### 1.4. Usage Example

Various functionalities required in distributed system environments can be implemented using ZNodes and Watchers. This section explains simple usage examples using ZooKeeper through the first figure.

#### 1.4.1. Machine Status Check

Ephemeral Nodes are Nodes that disappear when the Client that created the Ephemeral Node disconnects from the Server Cluster. Therefore, Machine status can be easily identified using Ephemeral Nodes.

* Install Clients on each Machine and connect them to Server Cluster.
* Connected Clients create an Ephemeral Node with a unique ID as the name under a specific Node, like the machine Node in the first figure. Then register a Watcher to detect machine Node.
* When Client connection terminates and Ephemeral Node disappears, Events are delivered to all Clients that registered machine Node Watcher.
* Clients that received Events can identify Machine termination status through other Clients' termination information.

#### 1.4.2. Distributed Lock

Distributed Locks can be implemented using the characteristic that Sequence Node numbers are not created with duplicates.

* Install Clients on each Node.
* Clients that want to acquire Lock connect to Server Cluster and then create an Ephemeral/Sequence Node under a specific Node, like the lock Node in the first figure, and check the created Sequence number. Then register a Watcher to detect lock Node and wait.
* When an Event comes from Watcher, Clients check whether the Node with the smallest Sequence number among lock Node's Child Nodes matches the Sequence number they created.
* If the numbers match, the Client acquires Lock and performs operations. After operations are completed, it disconnects.
* When connection is terminated, Ephemeral Node disappears, so lock Node Watcher generates Events again and delivers them to Clients.

## 2. References

* [https://www.slideshare.net/madvirus/zookeeper-34888385](https://www.slideshare.net/madvirus/zookeeper-34888385)
* [http://www.allprogrammingtutorials.com/tutorials/introduction-to-apache-zookeeper.php](http://www.allprogrammingtutorials.com/tutorials/introduction-to-apache-zookeeper.php)
* [https://www.slideshare.net/javawork/zookeeper-24265680](https://www.slideshare.net/javawork/zookeeper-24265680)


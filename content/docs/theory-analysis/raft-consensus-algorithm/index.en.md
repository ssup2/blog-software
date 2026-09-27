---
title: Raft Consensus Algorithm
---

This post analyzes the Raft Consensus Algorithm.

## 1. Raft Consensus Algorithm

{{< figure caption="[Figure 1] Raft Architecture" src="images/raft-architecture.png" width="800px" >}}

**Raft** is an Algorithm that performs the role of reaching **Consensus** among multiple Servers. Here, Consensus has the same meaning as the consistency of State (Data). [Figure 1] shows the Architecture of Raft and the flow of a State change request. Raft consists of a Server Cluster that stores the State, and Clients that deliver State-related requests to the Servers as needed. The Servers consist of a **Leader Server** and **Follower Servers**. Each Server consists of a **Consensus Module** that performs the role of reaching State Consensus, a **Log** that records the Client's State change requests, and a **State Machine** that stores the current State. The Log consists of a set of **Entries**, and one Entry represents one State change request from a Client.

All operations of Raft revolve around the Leader Server. Therefore, all Client requests are delivered to the Leader Server. When a State change request from a Client arrives, the Consensus Module of the Leader Server stores the request as an Entry in the Leader Server's Log. Then, the Consensus Module of the Leader Server delivers the Entry added to the Log (the Client's State change request) to the Follower Servers. The Consensus Module of each Follower Server stores the Entry delivered from the Leader Server in its own Log and notifies the Leader Server that storing the Entry is complete. This process of replicating the Leader Server's Log to the Follower Servers' Logs is called **Log Replication** in Raft.

The Consensus Module that has received responses from the Follower Servers indicating that the Entry has been added applies the added Entry information to the State Machine, actually applying the Client's State change request. This process is called **Commit** in Raft. After the Commit operation, the Consensus Module of the Leader Server notifies the Follower Servers that the Commit has been performed. Then, the Consensus Module of each Follower Server applies the added Entry to its State Machine.

It can be seen that, regardless of the Leader or Follower role, a Client's State change request in a Server is delivered to the Consensus Module, Log, and State Machine. It can also be seen that, although the State of each Server can temporarily differ, Raft is designed so that all Servers eventually have the same State through the Servers' Logs. A technique like Raft that replicates the State of a specific Server to the State of other Servers is called the **Replicated State Machine** technique.

The State Machine can be built **Disk-based** or **Memory-based**. When the State Machine is built Memory-based, the State stored in Memory is also removed when the Server restarts, but this is not a problem because the State Machine in its last state can be restored through Snapshots and the Log.

### 1.1. Quorum

{{< figure caption="[Figure 2] Quorum" src="images/quorum.png" width="400px" >}}

Quorum plays an important role in decision making in Raft. Quorum means the minimum number of **agreeing votes** required to maintain Consensus. It is also referred to by the word **Majority**. [Figure 2] shows the Quorum according to the number of Servers in a Server Cluster. It can be seen that the Quorum is the number of Servers divided in half plus one. In other words, the Quorum can be said to be the minimum value that guarantees that the number of agreeing Servers is greater than the number of disagreeing Servers.

The Quorum serves as the threshold for the number of responses the Leader must receive, indicating that the Entry with the State change has been stored in the Followers' Logs, before the Leader applies the State change stored in the Entry to the State Machine. That is, since the Server Cluster in [Figure 1] consists of 3 Servers, once the Leader receives an Entry storage response from just one Follower, the Leader has obtained a total of 2 agreeing votes including itself, which is the Quorum, and therefore applies the Entry to the State Machine.

For the same reason, if the number of running Servers in a Server Cluster is smaller than the Quorum, the Servers running in that Server Cluster can never obtain agreeing votes equal to or greater than the Quorum, so no State change can ever occur in that Server Cluster. The Quorum also serves as the threshold for the number of votes a Server must obtain from other Servers to become the Leader in the Leader Election process described next.

It can be seen that if one more Server is added to a Server Cluster with an odd number of Servers, the Quorum also increases by one. For example, when the number of Servers is 3, the Quorum is 2, but if one more Server is added to make the number 4, the Quorum also increases by 1 to become 3, as can be seen in [Figure 2]. This means that scaling a Server Cluster to an even number of Servers is inefficient from an availability perspective. Therefore, it is recommended to configure a Server Cluster with an odd number of Servers.

### 1.2. Term

{{< figure caption="[Figure 3] Raft Term" src="images/term.png" width="500px" >}}

A Term is a unit representing an arbitrary period of time used in Raft. When a Term starts, a Leader Election process to elect one Leader Server in the Server Cluster is always performed. If a Leader Server is elected, the Term is maintained as long as the elected Leader Server operates normally. If a Leader Server is not elected, the current Term is ended and a new Term is started to perform Leader Election again. In other words, one Term has the characteristic of having the same Life Time as one Leader Server. In [Figure 3], Terms 1, 2, and 4 represent Terms that succeeded in electing a Leader Server, and Term 3 represents a Term that failed to elect a Leader Server.

Each Term has a number, and whenever a new Term starts, a Term number one greater than the previous Term number is assigned. In [Figure 3], it can be seen that the Term number also increases by one whenever a new Term starts. If the Leader Server and all Follower Servers are operating without problems, the Leader Server and all Follower Servers operate within the same Term. However, when a failure occurs in some or all Servers, each Server can temporarily operate within a different Term.

For example, even though the Leader Server kept operating, a Follower Server may consider the Leader Server to be in an abnormal state due to a Network failure between the Leader Server and the Follower Server, and start a new Term. Such temporary Term mismatches are reconciled through the Leader Election process.

### 1.3. Leader Election

{{< figure caption="[Figure 4] Raft Server State" src="images/server-state.png" width="700px" >}}

When a new Term starts, Raft elects a new Leader Server through Leader Election. From the Leader Election perspective, a Server has 3 states: Leader, Follower, and Candidate. What was referred to earlier as the Leader Server and Follower Servers precisely means a Server in the Leader state and Servers in the Follower state. The Candidate state means the state in which a Server waits to receive votes from other Servers in order to become the Leader Server. [Figure 4] shows how the state of a Server changes.

When a Server first starts, it becomes a Follower Server. The process by which a Follower Server becomes the Leader Server is as follows.

1. A Follower Server does not receive a Heartbeat from the Leader Server for a certain period of time (Election Timeout).
1. The Follower Server judges that the Leader Server is dead and becomes a Candidate Server.
1. The Candidate Server starts a new Term and requests votes from the other Servers.
1. If, within a certain period of time after requesting votes, the Candidate Server receives votes equal to or greater than the Quorum from the other Servers including itself, the Candidate Server becomes the Leader Server.
1. The new Leader Server delivers Heartbeats to the other Servers to announce that it has become the new Leader.

In Raft, vote requests are made through **RequestVote** RPC calls. The vote request also carries the Candidate's current Term and Log information. If a Candidate Server requests votes and does not receive votes equal to the Quorum from the other Servers including itself within a certain period of time, the Candidate starts a new Term while remaining in the Candidate state and sends vote requests to the other Servers again. Alternatively, if the Candidate Server receives a Heartbeat from a new Leader Server or receives a vote request from another Candidate Server with a higher Term, the Candidate Server becomes a Follower.

The process by which a Follower Server votes and remains a Follower Server is as follows.

1. A Follower Server receives a vote request from a Candidate Server.
1. The Follower Server checks the Log information included in the vote request. If the Log information included in the vote request is older than its own Log information, it rejects the vote request. If the Log information included in the vote request is the same as or more up-to-date than its own Log information, and it has not sent a vote to another Candidate Server during the current Term, it responds to the vote request and sends its vote.
1. After voting or rejecting the vote, the Follower Server regards the Server that sends Heartbeats as the new Leader.

The reason a Follower Server checks the Log information included in the vote request is to prevent a Candidate Server that does not store the Entries stored in the Follower Server's Log from becoming the Leader Server. Since Raft reaches Consensus based on the Leader Server's Log, if an Entry not stored in the Leader Server's Log is stored only in a Follower Server, that Entry is removed by the Leader Server.

A Follower Server sends its vote only to the Candidate Server that requested the vote first among the vote requests from Candidate Servers that satisfy the Log condition. Therefore, if multiple Servers become Candidate Servers at the same time, the probability that a Leader Server is not elected by the vote increases. To prevent this problem, each Server has a Random Election Timeout. That is, since the waiting time for a Follower Server to become a Candidate Server differs for each Follower Server, multiple Follower Servers are prevented from becoming Candidate Servers at the same time.

### 1.4. Leader Transfer

When a Leader Server needs to restart, the safest way to restart is for the Leader Server to hand over the Leader role to another Server before restarting. The process in which the Leader Server hands over the Leader role to another Server and becomes a Follower Server is called **Step Down** in Raft. The process in which the Leader Server hands over the Leader role to another Server in Raft is as follows.

1. The previous Leader Server rejects Client requests.
1. The previous Leader Server synchronizes its Log with the Server that will perform the new Leader role.
1. The previous Leader Server calls the **TimeoutNow** RPC on the Server that will perform the new Leader role, forcing the Server that will perform the new Leader role from the Follower state into the Candidate state and making it perform Leader Election.
1. When the Leader Election ends, the previous Leader Server becomes a Follower, and the Server that will perform the new Leader role becomes the Leader, so the Leader role is handed over.

### 1.5. Log Replication, Commit

{{< figure caption="[Figure 5] Raft Log" src="images/log.png" width="600px" >}}

Once a Leader Server is elected, the Leader Server performs Log Replication to replicate its Log to the Follower Servers. Here, replicating the Log has the same meaning as replicating the Entries that make up the Log. [Figure 5] shows the Log composition of the Leader Server and Follower Servers. An Entry has an Index number, and each Entry stores the State change and the Term number at the time the State was changed.

The Leader Server sends an Entry replication request together with the information of the Entries to be replicated to the Follower Servers through **AppendEntries** RPC calls. A Follower Server that receives an Entry replication request checks whether the information of the Entries included in the request is valid. If the information of the Entries is valid, it adds the Entries to its own Log and notifies the Leader Server that the Entries have been replicated. If the information of the Entries is not valid, it notifies the Leader Server that the Entries have not been replicated.

A Follower Server judges the received Entries to be valid if they are Entries to be stored right after the Entry it stored last, and judges them to be invalid otherwise. The information of the Entries includes the Index numbers of the Entries and the current Term information, and the received Entries are regarded as valid Entries only when the Index numbers are consecutive and the current Term number matches.

The Leader Server that receives an Entry replication acceptance response from a Follower Server checks whether there are more Entries to be replicated next. If there are Entries to replicate, it attempts Entry replication to the Follower Server again through an Entry replication request. If there is no Entry to be replicated, the Leader Server keeps sending Entry replication requests with empty Entry information. This is because the Entry replication request performs the role of the Leader Server's **Heartbeat** even when there is no Entry to be replicated. In other words, the true nature of the Heartbeat that the Leader Server sends to the Follower Servers, mentioned earlier, is the Leader Server calling the AppendEntries RPC on the Follower Servers.

The Leader Server that receives an Entry replication rejection response from a Follower Server includes the Entries preceding the rejected Entries in the Entry replication request and sends it to the Follower Server again. In this way, whenever the Leader Server receives an Entry replication rejection response, it sends the Entry preceding the rejected Entry again. If this process is repeated continuously, at some point the Leader Server sends valid Entries to the Follower Server, and after that, Entry replication between the Leader Server and the Follower Server begins.

When the Leader Server receives Entry replication acceptance responses equal to or greater than the Quorum from the Follower Servers, it **Commits** the Entries and applies them to the State Machine. When a Follower Server receives the next Entry replication request or an empty Entry replication request from the Leader Server, it applies the Entries previously replicated to its Log to the State Machine.

### 1.6. Log Compaction, Snapshot

Raft uses **Snapshots** as the method for compacting the Log. This is because, after a Snapshot is taken, the Entries from before the Snapshot was taken are removed. State changes after the Snapshot remain as Entries in the Log as before.

### 1.7. Server Config Changes

In Raft, the Server Config is also managed as State in the State Machine. A changed Server Config sent by a Client is first stored in the Leader's Log, and is propagated to the Followers through Log replication. One difference is that the changed Server Config is applied not at the point of Commit after obtaining the Followers' agreeing votes, but at the moment the changed Server Config is stored in the State Machine.

### 1.8. Adding/Removing Servers in a Server Cluster

{{< figure caption="[Figure 6] Two Leaders Caused by Adding Servers to a Raft Server Cluster" src="images/cluster-member-add-2-leader.png" width="450px" >}}

Raft provides a method by which the process of adding/removing Servers in a Server Cluster, which can occur during operation, can be performed without stopping the operation of Raft. The reason such a non-disruptive Server addition/removal method is important in Raft is that two Leader Servers can temporarily operate normally in a single Server Cluster. [Figure 6] shows a situation where a problem can occur due to two Leader Servers when 2 Servers, Server 4 and 5, are added to a Server Cluster consisting of 3 Servers.

In [Figure 6], Old Conf represents the configuration in which only 3 Servers exist in the Server Cluster, and New Conf represents the configuration in which 5 Servers exist in the Server Cluster. Therefore, the Quorum of Old Conf is 2 and the Quorum of New Conf is 3. At the point of the red dotted line in [Figure 6], Servers 1 and 2 operate with Old Conf, and Servers 3, 4, and 5 operate with New Conf. At this time, since the Quorum of Old Conf is 2, one of Servers 1 and 2 can become the Leader Server and operate. At the same time, since the Quorum of New Conf is 3, one of Servers 3, 4, and 5 can become the Leader Server and operate. That is, it is a problem because two Leader Servers can operate at the same time.

To solve this problem, Raft provides two Server addition/removal methods. The first method is to add/remove strictly a single Server at a time. The second method is to use Joint Consensus, which applies Old Conf and New Conf at the same time.

#### 1.8.1. Single Server Addition/Removal

{{< figure caption="[Figure 7] Single Server Addition/Removal in a Raft Server Cluster" src="images/cluster-member-add-remove.png" width="500px" >}}

The first method to prevent the problem of two Leader Servers operating at the same time is to add/remove only a single Server at a time. [Figure 7] shows, in order, the temporary configuration state of the Server Cluster when adding 1 Server to 4 Servers, adding 1 Server to 2 Servers, removing 1 Server from 5 Servers, and removing 1 Server from 4 Servers. That is, it shows the temporary configuration state of the Server Cluster when a single Server is added/removed. It can be seen that in all 4 Cases, Old Conf and New Conf cannot satisfy the required number of Quorums at the same time. That is, the Leader Server of Old Conf and the Leader Server of New Conf cannot operate at the same time.

#### 1.8.2. Joint Consensus

> Old Server configuration -> Old Server configuration + New Server configuration (Joint Consensus) -> New Server configuration

The second method to prevent the problem of two Leader Servers operating at the same time is to use Joint Consensus, which applies Old Conf and New Conf at the same time. This is because, while Old Conf and New Conf are applied to the Server Cluster at the same time, only one Leader Server that satisfies both Confs operates.

#### 1.8.3 Log Catch Up

Adding a new Server with an empty Log can affect availability. For example, consider a situation where a Server Cluster has 3 Servers, one of which is broken, and one new Server is added. Before the Server is added, the Quorum is 2, so there is no problem with operation, but when one new Server is added, the Quorum increases to 3. The problem is that since the new Server's Log is empty, the Leader Server cannot obtain an agreeing vote from the new Server until the new Server's Log matches the Leader Server's Log. That is, the Leader Server cannot Commit Entries until the new Server's Log matches the Leader Server's.

A problem can also occur when multiple new Servers with empty Logs are added at short intervals. For example, consider a situation where a Server Cluster has 3 Servers and 4 new Servers are added. Before the Servers are added, the Quorum is 2, but when the 4 new Servers are added, the Quorum becomes 4. That is, the Leader Server cannot Commit Entries until 1 of the 4 new Servers matches the Leader Server.

To solve this Log Catch Up problem, Raft proposes a method in which a newly added Server initially performs only the Log replication operation with the Leader Server and does not participate in voting, so that it does not affect the Quorum. Later, when the newly added Server's Log matches the Leader Server's Log to some extent, the newly added Server participates in voting. The new Server performs Log replication divided into units called Rounds. If a Round finishes within the Election Timeout, it is assumed that the new Server's Log matches the Leader Server's Log to some extent, and the new Server obtains the right to vote.

### 1.9. Client Connection

To send State change requests to the Server Cluster and obtain the current State information from the Server Cluster, a Client must know the IP/Port information of the Servers in the Server Cluster. As methods for delivering the IP/Port information of the Servers in the Server Cluster to Clients, Raft proposes a method of configuring it using a configuration file, and a method in which the Client can dynamically obtain the IP/Port information of the Servers in the Server Cluster through a Directory Service such as DNS.

Even if a Client knows the IP/Port information of the Servers in the Server Cluster, the condition that the Client's requests must be delivered to the Leader Server, which can change dynamically, is also required. Raft proposes a method of establishing a Connection with the Client only when a Server is the Leader Server so that the Client's requests are delivered only to the Leader Server, and a method in which the Follower Servers perform the role of a Proxy for the Leader Server so that even if the Client establishes a Connection with a Follower Server and delivers a request, the request is forwarded to the Leader Server.

## 2. References

* Consensus: Bridging Theory and Practice (Ongaro PhD Thesis) : [https://web.stanford.edu/~ouster/cgi-bin/papers/OngaroPhD.pdf](https://web.stanford.edu/~ouster/cgi-bin/papers/OngaroPhD.pdf)
* Raft Consensus Algorithm : [https://raft.github.io/](https://raft.github.io/)

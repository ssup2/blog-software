---
title: In Search of Understandable Consensus Algorithm
---

## 1. Summary

This paper explains the Raft Algorithm used to achieve data consensus in distributed computing environments.

## 2. Replicated State Machine Architecture

Consensus algorithms generally operate based on Replicated State Machine Architecture. Replicated State Machine Architecture literally means an architecture composed of multiple servers including state machines with the same state. Each server in Replicated State Machine Architecture consists of the following components.

* Consensus Module : Communicates with other servers' Consensus Modules to understand the state of other servers and achieve consensus. It also receives client commands (requests), records commands in logs, reflects them in state machines, and propagates them to other servers' Consensus Modules.
* State Machine : Performs the role of a storage that stores the current state of the server.
* Log : A space that records client commands applied by the Consensus Module to the State Machine in the order they were applied. In other words, the history of the State Machine can be understood through logs. The Consensus Module achieves consensus based on command information stored in logs. One command information is stored in one entry in the log.

### 3. Consensus Algorithm Characteristics

Consensus algorithms must satisfy the following characteristics.

* Safety must be guaranteed even in non-Byzantine environments (Network Delay & Partition, Packet Loss & Duplication & Reordering). Here, safety means not returning incorrect results.
* If multiple servers are operating normally, there should be no problems in algorithm execution. Here, multiple means quorum. For example, if 3 or more out of 5 servers are operating normally, there should be no problems in algorithm execution.
* Even if timing problems occur due to faulty clocks and message delays, log consistency must be maintained.

## 4. Raft Algorithm

The Raft Algorithm was born to solve the problems of the Paxos Algorithm, which is well-known as an existing consensus algorithm. The Raft Algorithm has characteristics that are simpler, more intuitive, and easier to implement than the Paxos Algorithm. The Raft Algorithm also operates based on Replicated State Machine Architecture and satisfies the characteristics of consensus algorithms. The Raft Algorithm guarantees to satisfy the following 5 characteristics.

* Election Safety : Can safely elect one leader during one term.
* Leader Append-Only : The leader never overwrites or deletes entries (commands) in the log. The leader only adds entries to the next index in the log.
* Log Matching : If the index and term of the last entry of two logs are the same, the two logs are identical.
* Leader Completeness : Committed entries exist in the changed leader even if the leader changes later.
* State Machine Safety : If a specific index entry is reflected in the state machine on one server, it is reflected in the state machine only when other servers have the same entry at the same index. If entries with different contents exist at the same index, those entries are not reflected.

### 4.1. Leader Election

In the Raft Algorithm, each server has three states: Leader, Follower, and Candidate. The Raft Algorithm achieves consensus centered on the leader. Because of this leader-based approach, the Raft Algorithm has the advantage of being easier to understand and implement than other consensus algorithms. The explanation of the three states is as follows.

* Leader : Performs a central role in achieving consensus between servers.
* Follower : Stores entries in logs and states in state machines according to the leader's commands.
* Candidate : Refers to the state of receiving votes from other servers to become a leader.

All servers can become leaders, followers, or candidates depending on the situation. Therefore, the Raft Algorithm provides a method for electing leaders. The process of a follower becoming a leader is as follows.

1. A follower does not receive a heartbeat from the leader for a certain time (Election Timeout).
1. The follower determines that the leader is dead and becomes a candidate.
1. The candidate creates a new term and requests votes from other servers. After that, it waits for votes from other servers until the newly created term ends. The vote request (Request Vote) also includes the candidate's current log information.
1. If the candidate receives votes from quorum or more servers including itself during the term, that candidate becomes the leader. If the candidate does not receive votes from quorum or more servers including itself during the term, that candidate does not become the leader and conducts voting again in the next term.
1. The server that becomes the leader sends heartbeats to other servers to inform them that it has become the new leader.

Term is the logical time used in the Raft Algorithm. When the leader changes, a new term begins. In other words, one leader occupies the term during one term. Vote requests also send the candidate's log information. The process of a follower voting and becoming a follower again is as follows.

1. A follower receives a vote request from another server in candidate state.
1. The follower checks the log information in the vote request. If the log information included in the vote request is older than its own log information, it rejects the vote request. If the log information included in the vote request is the same as or newer than its own log information and it has not sent a vote to another candidate during the current term, it responds to the vote request and sends a vote.
1. The follower considers the server that sent the heartbeat after voting or rejecting the vote as the new leader.

The reason followers check the log information included in vote requests is to prevent candidates who do not store entries stored in their logs from becoming leaders. Since the Raft Algorithm achieves consensus based on the leader's log, if only followers store entries not stored in the leader's log, those entries are removed by the leader.

Followers send votes only to the candidate who requests votes first among candidates whose vote requests meet log conditions. Therefore, if multiple servers become candidates simultaneously, the probability of not electing a leader through voting increases. To prevent this problem, each server has a random election timeout. In other words, since the waiting time for followers to become candidates is different for each follower, it prevents multiple followers from becoming candidates simultaneously.

### 4.2. Log Replication

When a leader is elected, the leader performs log replication to replicate its log to followers. Here, replicating logs means the same as replicating entries stored in logs. In the process of replicating entries, the leader sends AppendEntries requests to followers. AppendEntries requests include information about entries to be replicated. Followers who receive AppendEntries requests check the information of entries included in the request. If the entry information is valid, they add those entries to their logs and inform the leader that the entries have been reflected. If the entry information is not valid, they inform the leader that those entries have not been reflected.

Followers determine that received entries are valid if they are entries to be stored at the next entry after the last entry they stored, and determine they are invalid otherwise. Entry information includes the entry's index number and current term information. Leaders who receive AppendEntries request reflection responses send the next entries to followers in AppendEntries requests if there are entries to be replicated. If there are no entries to be replicated, the leader sends an AppendEntries request with empty entry information. The reason for sending AppendEntries requests even when there are no entries to replicate is that AppendEntries requests serve as the leader's heartbeat.

Leaders who receive AppendEntries request rejection responses include the previous entry of the previously sent entry in AppendEntries requests and send them to followers again. Each time they receive AppendEntries request rejection responses, leaders send the previous entry of the previously sent entry again. If this process continues, the leader will eventually send valid entries to followers and receive AppendEntries request reflection responses from followers. After that, the leader performs log replication to followers by sending the next entry of the previously sent entry.

When leaders receive AppendEntries request response messages from quorum or more followers, they commit those entries and reflect them in the state machine. Followers reflect entries from AppendEntries requests sent by leaders in their logs while reflecting entries that were previously sent by leaders and reflected in logs in the state machine.

### 4.3. Server Configuration Changes

Servers that achieve consensus through the Raft Algorithm can be replaced or added depending on the situation. Accordingly, the server configuration settings of each server must also be changed. The problem is that the server configuration settings of all servers cannot be changed simultaneously at once. The easiest method is to stop all servers, change server configuration settings, and then start all servers again. However, this method has the major disadvantage that clients cannot use servers while server configuration settings are being changed.

To solve this problem, the Raft Algorithm changes server configuration settings in two phases. Server configuration settings are managed the same way as data stored by client commands (requests). When a leader changes server configuration settings, the changes are recorded in the leader's log entries and replicated to followers' log entries, and stored in the state machines of leaders and followers. At this time, server configuration settings do not change to new server configuration settings at once, but use a state called Joint Consensus where both old and new server configuration settings exist. Therefore, server configuration settings are made in the following stages.

* Old Server Configuration -> Old Server Configuration + New Server Configuration (Joint Consensus) -> New Server Configuration

The reason why old and new server configuration settings must exist simultaneously for a short time is to prevent two servers from becoming leaders simultaneously. When old and new server configuration settings are applied simultaneously, only one leader that satisfies both server configuration settings is elected. If old server configuration settings are changed to new server configuration settings at once, some servers return to old server configuration settings and some servers operate with new server configuration settings during the change, and at this time, two servers can become leaders simultaneously.

## 5. References

* [https://raft.github.io/](https://raft.github.io/)
* [https://web.stanford.edu/~ouster/cgi-bin/papers/OngaroPhD.pdf](https://web.stanford.edu/~ouster/cgi-bin/papers/OngaroPhD.pdf)

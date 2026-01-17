---
title: etcd Server Addition/Deletion
---

## 1. Execution Environment

The execution environment is as follows.
* etcd v3.4.0
* Node
    * Ubuntu 18.04
    * Node01 : 192.168.0.61
    * Node02 : 192.168.0.62

## 2. Single etcd Server Configuration

Configure a single etcd Server on Node01.

```shell
(Node01)$ export NODE01=192.168.0.61
(Node01)$ export REGISTRY=gcr.io/etcd-development/etcd

(Node01)$ docker run -d \
  --net=host \
  --name etcd ${REGISTRY}:v3.4.0 \
  /usr/local/bin/etcd \
  --data-dir=/etcd-data --name node01 \
  --initial-advertise-peer-urls http://${NODE01}:2380 --listen-peer-urls http://0.0.0.0:2380 \
  --advertise-client-urls http://${NODE01}:2379 --listen-client-urls http://0.0.0.0:2379 \
  --initial-cluster node01=http://${NODE01}:2380
```

Run a single etcd Server using Docker.

## 3. Server Addition

Run another etcd Server on Node02 and form a Cluster with Node01's etcd Server.

```shell
(Node01)$ docker exec -it etcd sh
(etcd Container)$ etcdctl member add node02 --peer-urls=http://192.168.0.62:2380
Member 4c0878749a891a5f added to cluster 35d99f7f50aa4509

ETCD-NAME="node02"
ETCD-INITIAL-CLUSTER="node02=http://192.168.0.62:2380,node01=http://192.168.0.61:2380"
ETCD-INITIAL-ADVERTISE-PEER-URLS="http://192.168.0.62:2380"
ETCD-INITIAL-CLUSTER-STATE="existing"
```

Add Node02's etcd Member to Node01's etcd Server.

```shell
(Node02)$ export NODE01=192.168.0.61
(Node02)$ export NODE02=192.168.0.62
(Node02)$ export REGISTRY=gcr.io/etcd-development/etcd

(Node02)$ docker run -d \
  --net=host \
  --name etcd ${REGISTRY}:v3.4.0 \
  /usr/local/bin/etcd \
  --data-dir=/etcd-data --name node02 \
  --initial-advertise-peer-urls http://${NODE02}:2380 --listen-peer-urls http://0.0.0.0:2380 \
  --advertise-client-urls http://${NODE02}:2379 --listen-client-urls http://0.0.0.0:2379 \
  --initial-cluster node01=http://${NODE01}:2380,node02=http://${NODE02}:2380 \
  --initial-cluster-state existing
```

Form a Cluster with Node01's etcd Server.

```shell
(Node01)$ docker logs -f etcd
...
tcdserver/membership: set the initial cluster version to 3.4
2021-03-03 16:25:57.005589 I | embed: ready to serve client requests
2021-03-03 16:25:57.005633 I | etcdserver: published {Name:node01 ClientURLs:[http://192.168.0.61:2379]} to cluster 35d99f7f50aa4509
2021-03-03 16:25:57.005641 I | etcdserver/api: enabled capabilities for version 3.4
2021-03-03 16:25:57.006043 N | embed: serving insecure client requests on [::]:2379, this is strongly discouraged!
...
raft2021/03/03 16:27:23 INFO: 4eee438bb97e1153 switched to configuration voters=(5687557646807077203 7883063032017194716)
2021-03-03 16:27:23.856885 I | etcdserver/membership: added member 6d66440fb5660edc [http://192.168.0.62:2380] to cluster 35d99f7f50aa4509
2021-03-03 16:27:23.856932 I | rafthttp: starting peer 6d66440fb5660edc...
2021-03-03 16:27:23.856952 I | rafthttp: started HTTP pipelining with peer 6d66440fb5660edc
2021-03-03 16:27:23.857507 I | rafthttp: started streaming with peer 6d66440fb5660edc (writer)
2021-03-03 16:27:23.857752 I | rafthttp: started streaming with peer 6d66440fb5660edc (writer)
2021-03-03 16:27:23.859022 I | rafthttp: started peer 6d66440fb5660edc
2021-03-03 16:27:23.859053 I | rafthttp: added peer 6d66440fb5660edc
2021-03-03 16:27:23.859079 I | rafthttp: started streaming with peer 6d66440fb5660edc (stream MsgApp v2 reader)
2021-03-03 16:27:23.859114 I | rafthttp: started streaming with peer 6d66440fb5660edc (stream Message reader)
raft2021/03/03 16:27:25 WARN: 4eee438bb97e1153 stepped down to follower since quorum is not active
raft2021/03/03 16:27:25 INFO: 4eee438bb97e1153 became follower at term 2
raft2021/03/03 16:27:25 INFO: raft.node: 4eee438bb97e1153 lost leader 4eee438bb97e1153 at term 2
raft2021/03/03 16:27:26 INFO: 4eee438bb97e1153 is starting a new election at term 2
raft2021/03/03 16:27:26 INFO: 4eee438bb97e1153 became candidate at term 3
raft2021/03/03 16:27:26 INFO: 4eee438bb97e1153 received MsgVoteResp from 4eee438bb97e1153 at term 3
raft2021/03/03 16:27:26 INFO: 4eee438bb97e1153 [logterm: 2, index: 5] sent MsgVote request to 6d66440fb5660edc at term 3
raft2021/03/03 16:27:28 INFO: 4eee438bb97e1153 is starting a new election at term 3
raft2021/03/03 16:27:28 INFO: 4eee438bb97e1153 became candidate at term 4
raft2021/03/03 16:27:28 INFO: 4eee438bb97e1153 received MsgVoteResp from 4eee438bb97e1153 at term 4
raft2021/03/03 16:27:28 INFO: 4eee438bb97e1153 [logterm: 2, index: 5] sent MsgVote request to 6d66440fb5660edc at term 4
2021-03-03 16:27:28.859259 W | rafthttp: health check for peer 6d66440fb5660edc could not connect: dial tcp 192.168.0.62:2380: connect: connection refused
2021-03-03 16:27:28.859309 W | rafthttp: health check for peer 6d66440fb5660edc could not connect: dial tcp 192.168.0.62:2380: connect: connection refused
raft2021/03/03 16:27:29 INFO: 4eee438bb97e1153 is starting a new election at term 4
raft2021/03/03 16:27:29 INFO: 4eee438bb97e1153 became candidate at term 5
raft2021/03/03 16:27:29 INFO: 4eee438bb97e1153 received MsgVoteResp from 4eee438bb97e1153 at term 5
raft2021/03/03 16:27:29 INFO: 4eee438bb97e1153 [logterm: 2, index: 5] sent MsgVote request to 6d66440fb5660edc at term 5
raft2021/03/03 16:27:30 INFO: 4eee438bb97e1153 is starting a new election at term 5
raft2021/03/03 16:27:30 INFO: 4eee438bb97e1153 became candidate at term 6
raft2021/03/03 16:27:30 INFO: 4eee438bb97e1153 received MsgVoteResp from 4eee438bb97e1153 at term 6
raft2021/03/03 16:27:30 INFO: 4eee438bb97e1153 [logterm: 2, index: 5] sent MsgVote request to 6d66440fb5660edc at term 6
raft2021/03/03 16:27:32 INFO: 4eee438bb97e1153 is starting a new election at term 6
raft2021/03/03 16:27:32 INFO: 4eee438bb97e1153 became candidate at term 7
raft2021/03/03 16:27:32 INFO: 4eee438bb97e1153 received MsgVoteResp from 4eee438bb97e1153 at term 7
raft2021/03/03 16:27:32 INFO: 4eee438bb97e1153 [logterm: 2, index: 5] sent MsgVote request to 6d66440fb5660edc at term 7
raft2021/03/03 16:27:33 INFO: 4eee438bb97e1153 is starting a new election at term 7
raft2021/03/03 16:27:33 INFO: 4eee438bb97e1153 became candidate at term 8
raft2021/03/03 16:27:33 INFO: 4eee438bb97e1153 received MsgVoteResp from 4eee438bb97e1153 at term 8
raft2021/03/03 16:27:33 INFO: 4eee438bb97e1153 [logterm: 2, index: 5] sent MsgVote request to 6d66440fb5660edc at term 8
2021-03-03 16:27:33.859469 W | rafthttp: health check for peer 6d66440fb5660edc could not connect: dial tcp 192.168.0.62:2380: connect: connection refused
2021-03-03 16:27:33.859602 W | rafthttp: health check for peer 6d66440fb5660edc could not connect: dial tcp 192.168.0.62:2380: connect: connection refuse
...
2021-03-03 16:28:50.446253 I | rafthttp: peer 6d66440fb5660edc became active
2021-03-03 16:28:50.446282 I | rafthttp: established a TCP streaming connection with peer 6d66440fb5660edc (stream Message writer)
2021-03-03 16:28:50.446748 I | rafthttp: established a TCP streaming connection with peer 6d66440fb5660edc (stream MsgApp v2 writer)
2021-03-03 16:28:50.460719 I | rafthttp: established a TCP streaming connection with peer 6d66440fb5660edc (stream MsgApp v2 reader)
2021-03-03 16:28:50.460880 I | rafthttp: established a TCP streaming connection with peer 6d66440fb5660edc (stream Message reader)
raft2021/03/03 16:28:52 INFO: 4eee438bb97e1153 is starting a new election at term 60
raft2021/03/03 16:28:52 INFO: 4eee438bb97e1153 became candidate at term 61
raft2021/03/03 16:28:52 INFO: 4eee438bb97e1153 received MsgVoteResp from 4eee438bb97e1153 at term 61
raft2021/03/03 16:28:52 INFO: 4eee438bb97e1153 [logterm: 2, index: 5] sent MsgVote request to 6d66440fb5660edc at term 61
raft2021/03/03 16:28:52 INFO: 4eee438bb97e1153 received MsgVoteResp from 6d66440fb5660edc at term 61
raft2021/03/03 16:28:52 INFO: 4eee438bb97e1153 has received 2 MsgVoteResp votes and 0 vote rejections
raft2021/03/03 16:28:52 INFO: 4eee438bb97e1153 became leader at term 61
raft2021/03/03 16:28:52 INFO: raft.node: 4eee438bb97e1153 elected leader 4eee438bb97e1153 at term 6
```

When Node02's etcd Server is added, Node01's etcd Server leaves logs as shown above. Node01's etcd Server waits until a Connection is established with Node02's etcd Server after Node02's etcd Server is added. Afterward, Node01's etcd Server establishes a Connection with Node02's etcd Server, and then becomes the Leader through the Leader Election process.

## 4. Server Deletion

### 4.1. Leader Server Deletion

Remove Node01's etcd Server, which is operating as Leader.

```shell
(Node02)$ docker exec -it etcd sh
(etcd Container)$ etcdctl endpoint status --cluster -w table
+--------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|         ENDPOINT         |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+--------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| http://192.168.0.61:2379 | 4eee438bb97e1153 |   3.4.0 |   20 kB |      true |      false |        61 |          7 |                  7 |        |
| http://192.168.0.62:2379 | 6c9f385ab14331a2 |   3.4.0 |   20 kB |     false |      false |        61 |          7 |                  7 |        |
+--------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+

(etcd Container)$ etcdctl member remove 4eee438bb97e1153
```

Remove the Leader etcd Server from the etcd Cluster.

```shell
(Node02)$ docker logs -f etcd
...
raft2021/03/03 16:46:41 INFO: 6c9f385ab14331a2 switched to configuration voters=(7827036639565394338)
2021-03-03 16:46:41.520426 I | etcdserver/membership: removed member 4eee438bb97e1153 from cluster 35d99f7f50aa4509
2021-03-03 16:46:41.520470 I | rafthttp: stopping peer 4eee438bb97e1153...
2021-03-03 16:46:41.521156 I | rafthttp: closed the TCP streaming connection with peer 4eee438bb97e1153 (stream MsgApp v2 writer)
2021-03-03 16:46:41.521191 I | rafthttp: stopped streaming with peer 4eee438bb97e1153 (writer)
2021-03-03 16:46:41.522150 W | rafthttp: rejected the stream from peer 4eee438bb97e1153 since it was removed
2021-03-03 16:46:41.523061 I | rafthttp: closed the TCP streaming connection with peer 4eee438bb97e1153 (stream Message writer)
2021-03-03 16:46:41.523166 I | rafthttp: stopped streaming with peer 4eee438bb97e1153 (writer)
2021-03-03 16:46:41.523369 I | rafthttp: stopped HTTP pipelining with peer 4eee438bb97e1153
2021-03-03 16:46:41.523436 W | rafthttp: lost the TCP streaming connection with peer 4eee438bb97e1153 (stream MsgApp v2 reader)
2021-03-03 16:46:41.523458 E | rafthttp: failed to read 4eee438bb97e1153 on stream MsgApp v2 (context canceled)
2021-03-03 16:46:41.523462 I | rafthttp: peer 4eee438bb97e1153 became inactive (message send to peer failed)
2021-03-03 16:46:41.523485 I | rafthttp: stopped streaming with peer 4eee438bb97e1153 (stream MsgApp v2 reader)
2021-03-03 16:46:41.523525 W | rafthttp: lost the TCP streaming connection with peer 4eee438bb97e1153 (stream Message reader)
2021-03-03 16:46:41.523534 I | rafthttp: stopped streaming with peer 4eee438bb97e1153 (stream Message reader)
2021-03-03 16:46:41.523538 I | rafthttp: stopped peer 4eee438bb97e1153
2021-03-03 16:46:41.523548 I | rafthttp: removed peer 4eee438bb97e1153
2021-03-03 16:46:41.524312 W | rafthttp: rejected the stream from peer 4eee438bb97e1153 since it was removed
raft2021/03/03 16:46:43 INFO: 6c9f385ab14331a2 is starting a new election at term 5
raft2021/03/03 16:46:43 INFO: 6c9f385ab14331a2 became candidate at term 6
raft2021/03/03 16:46:43 INFO: 6c9f385ab14331a2 received MsgVoteResp from 6c9f385ab14331a2 at term 6
raft2021/03/03 16:46:43 INFO: 6c9f385ab14331a2 became leader at term 6
raft2021/03/03 16:46:43 INFO: raft.node: 6c9f385ab14331a2 changed leader from 4eee438bb97e1153 to 6c9f385ab14331a2 at term 6
```

When Node01's etcd Server is removed, Node02's etcd Server leaves logs as shown above. Since the Leader Server was removed, you can see that Node02's etcd Server becomes the Leader through the Leader Election process.

### 4.2. Follower Server Deletion

Remove Node02's etcd Server, which is operating as Follower.

```shell
(Node01)$ docker exec -it etcd sh
(etcd Container)$ etcdctl endpoint status --cluster -w table
+--------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|         ENDPOINT         |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+--------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| http://192.168.0.61:2379 | 4eee438bb97e1153 |   3.4.0 |   20 kB |      true |      false |        11 |          7 |                  7 |        |
| http://192.168.0.62:2379 | 9035c191246d362c |   3.4.0 |   20 kB |     false |      false |        11 |          7 |                  7 |        |
+--------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+

(etcd Container)$ etcdctl member remove 9035c191246d362c
```

Remove the Follower etcd Server from the etcd Cluster.

```shell
(Node01)$ docker logs -f etcd
...
raft2021/03/03 17:04:23 INFO: 4eee438bb97e1153 switched to configuration voters=(5687557646807077203)
2021-03-03 17:04:23.420808 I | etcdserver/membership: removed member 9035c191246d362c from cluster 35d99f7f50aa4509
2021-03-03 17:04:23.420843 I | rafthttp: stopping peer 9035c191246d362c...
2021-03-03 17:04:23.421311 I | rafthttp: closed the TCP streaming connection with peer 9035c191246d362c (stream MsgApp v2 writer)
2021-03-03 17:04:23.421346 I | rafthttp: stopped streaming with peer 9035c191246d362c (writer)
2021-03-03 17:04:23.421918 I | rafthttp: closed the TCP streaming connection with peer 9035c191246d362c (stream Message writer)
2021-03-03 17:04:23.421951 I | rafthttp: stopped streaming with peer 9035c191246d362c (writer)
2021-03-03 17:04:23.422194 W | rafthttp: rejected the stream from peer 9035c191246d362c since it was removed
2021-03-03 17:04:23.422338 I | rafthttp: stopped HTTP pipelining with peer 9035c191246d362c
2021-03-03 17:04:23.422612 W | rafthttp: lost the TCP streaming connection with peer 9035c191246d362c (stream MsgApp v2 reader)
2021-03-03 17:04:23.422620 W | rafthttp: rejected the stream from peer 9035c191246d362c since it was removed
2021-03-03 17:04:23.422657 E | rafthttp: failed to read 9035c191246d362c on stream MsgApp v2 (context canceled)
2021-03-03 17:04:23.422667 I | rafthttp: peer 9035c191246d362c became inactive (message send to peer failed)
2021-03-03 17:04:23.422679 I | rafthttp: stopped streaming with peer 9035c191246d362c (stream MsgApp v2 reader)
2021-03-03 17:04:23.422729 W | rafthttp: lost the TCP streaming connection with peer 9035c191246d362c (stream Message reader)
2021-03-03 17:04:23.422739 I | rafthttp: stopped streaming with peer 9035c191246d362c (stream Message reader)
2021-03-03 17:04:23.422747 I | rafthttp: stopped peer 9035c191246d362c
2021-03-03 17:04:23.422757 I | rafthttp: removed peer 9035c191246d362c
```

When Node02's etcd Server is removed, Node01's etcd Server leaves logs as shown above. You can see that Leader Election is not performed because a Follower Server was removed.

## 5. Server Addition Using Learner Feature

Run another etcd Server on Node03 and form a Cluster with Node01 and Node02's etcd Servers using the Learner feature.

```shell
(Node01)$ docker exec -it etcd sh
(etcd Container)$ etcdctl member add node03 --learner --peer-urls=http://192.168.0.63:2380
Member aa9ac53bcb1de8c6 added to cluster 35d99f7f50aa4509

ETCD-NAME="node03"
ETCD-INITIAL-CLUSTER="node02=http://192.168.0.62:2380,node01=http://192.168.0.61:2380,node03=http://192.168.0.63:2380"
ETCD-INITIAL-ADVERTISE-PEER-URLS="http://192.168.0.63:2380"
ETCD-INITIAL-CLUSTER-STATE="existing"
```

Add Node03's etcd Member as a Learner to Node01's etcd Server.

```shell
(Node03)$ export NODE01=192.168.0.61
(Node03)$ export NODE02=192.168.0.62
(Node03)$ export NODE03=192.168.0.63
(Node03)$ export REGISTRY=gcr.io/etcd-development/etcd

(Node03)$ docker run -d \
  --net=host \
  --name etcd ${REGISTRY}:v3.4.0 \
  /usr/local/bin/etcd \
  --data-dir=/etcd-data --name node03 \
  --initial-advertise-peer-urls http://${NODE03}:2380 --listen-peer-urls http://0.0.0.0:2380 \
  --advertise-client-urls http://${NODE03}:2379 --listen-client-urls http://0.0.0.0:2379 \
  --initial-cluster node01=http://${NODE01}:2380,node02=http://${NODE02}:2380,node03=http://${NODE03}:2380 \
  --initial-cluster-state existing
```

Form a Cluster with Node01's etcd Server.

```shell
(Node01)$ docker exec -it etcd sh
(etcd Container)$ etcdctl endpoint status --cluster -w table
+--------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|         ENDPOINT         |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+--------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| http://192.168.0.63:2379 | aa9ac53bcb1de8c6 |   3.4.0 |   20 kB |     false |       true |        36 |         10 |                 10 |        |
| http://192.168.0.62:2379 | 341224f3422176dd |   3.4.0 |   20 kB |     false |      false |        36 |         10 |                 10 |        |
| http://192.168.0.61:2379 | 4eee438bb97e1153 |   3.4.0 |   20 kB |      true |      false |        36 |         10 |                 10 |        |
+--------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+

(etcd Container)$ etcdctl member promote aa9ac53bcb1de8c6
Member aa9ac53bcb1de8c6 promoted in cluster 35d99f7f50aa450
(etcd Container)$ etcdctl endpoint status --cluster -w table
+--------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|         ENDPOINT         |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+--------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| http://192.168.0.63:2379 | aa9ac53bcb1de8c6 |   3.4.0 |   20 kB |     false |      false |        36 |         12 |                 12 |        |
| http://192.168.0.62:2379 | 341224f3422176dd |   3.4.0 |   20 kB |     false |      false |        36 |         12 |                 12 |        |
| http://192.168.0.61:2379 | 4eee438bb97e1153 |   3.4.0 |   20 kB |      true |      false |        36 |         12 |                 12 |        |
+--------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
```

You can see that Node03's etcd Server was in Learner state and then became a Follower through the promote command.

```shell
(Node01)$ docker logs -f etcd
...
2021-03-06 13:41:09.130322 W | rafthttp: health check for peer aa9ac53bcb1de8c6 could not connect: dial tcp 192.168.0.63:2380: connect: connection refused
2021-03-06 13:41:09.130381 W | rafthttp: health check for peer aa9ac53bcb1de8c6 could not connect: dial tcp 192.168.0.63:2380: connect: connection refused
2021-03-06 13:41:09.786452 W | etcdserver: failed to reach the peerURL(http://192.168.0.63:2380) of member aa9ac53bcb1de8c6 (Get http://192.168.0.63:2380/version: dial tcp 192.168.0.63:2380: connect: connection refused)
2021-03-06 13:41:09.786492 W | etcdserver: cannot get the version of member aa9ac53bcb1de8c6 (Get http://192.168.0.63:2380/version: dial tcp 192.168.0.63:2380: connect: connection refused)
2021-03-06 13:41:13.787721 W | etcdserver: failed to reach the peerURL(http://192.168.0.63:2380) of member aa9ac53bcb1de8c6 (Get http://192.168.0.63:2380/version: dial tcp 192.168.0.63:2380: connect: connection refused)
2021-03-06 13:41:13.787755 W | etcdserver: cannot get the version of member aa9ac53bcb1de8c6 (Get http://192.168.0.63:2380/version: dial tcp 192.168.0.63:2380: connect: connection refused)
2021-03-06 13:41:14.130602 W | rafthttp: health check for peer aa9ac53bcb1de8c6 could not connect: dial tcp 192.168.0.63:2380: connect: connection refused
2021-03-06 13:41:14.130679 W | rafthttp: health check for peer aa9ac53bcb1de8c6 could not connect: dial tcp 192.168.0.63:2380: connect: connection refused
...
2021-03-06 13:41:25.492675 I | rafthttp: peer aa9ac53bcb1de8c6 became active
2021-03-06 13:41:25.492718 I | rafthttp: established a TCP streaming connection with peer aa9ac53bcb1de8c6 (stream Message writer)
2021-03-06 13:41:25.492901 I | rafthttp: established a TCP streaming connection with peer aa9ac53bcb1de8c6 (stream MsgApp v2 writer)
2021-03-06 13:41:25.493739 I | rafthttp: established a TCP streaming connection with peer aa9ac53bcb1de8c6 (stream Message reader)
2021-03-06 13:41:25.493797 I | rafthttp: established a TCP streaming connection with peer aa9ac53bcb1de8c6 (stream MsgApp v2 reader)
raft2021/03/06 13:42:07 INFO: 4eee438bb97e1153 switched to configuration voters=(3752102066758186717 5687557646807077203) learners=(12293354993462667462)
raft2021/03/06 13:42:15 INFO: 4eee438bb97e1153 switched to configuration voters=(3752102066758186717 5687557646807077203 12293354993462667462)
...
2021-03-06 13:42:15.610651 N | etcdserver/membership: promote member aa9ac53bcb1de8c6 in cluster 35d99f7f50aa4509
```

When Node03's etcd Server is added as a Learner and promoted to Follower, Node01's etcd Server leaves logs as shown above.

## 6. References

* [https://etcd.io/docs/v3.4.0/op-guide/container/](https://etcd.io/docs/v3.4.0/op-guide/container/)
* [https://etcd.io/docs/v3.4.0/op-guide/runtime-configuration/](https://etcd.io/docs/v3.4.0/op-guide/runtime-configuration/)
* [https://etcd.io/docs/v3.4.0/learning/design-learner/](https://etcd.io/docs/v3.4.0/learning/design-learner/)


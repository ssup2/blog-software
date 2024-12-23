---
title: etcd Clustering
---

etcd의 Clustering 기법을 분석한다.

## 1. etcd Server Clustering

{{< figure caption="[Figure 1] etcd Server Cluster" src="images/etcd-cluster-architecture.png" width="700px" >}}

etcd Server는 Clustering을 통해서 HA(High Availability)를 제공할 수 있다. [Figure 1]은 etcd Server의 Cluster를 나타내고 있다.

#### 1.1. Server Clustering

Server는 Raft Algorithm에 따라서 **Leader**와 **Follower**로 동작한다. Raft Algorithm에 따라서 Client의 Request는 반드시 Leader Server에게로 전달되어야 한다. Follower 역할을 수행하는 Server는 Client의 요청을 받을 경우 Leader Server에게 전달하는 Proxy 역할을 수행한다.

Server들이 Clustering을 수행하기 위해서는 각 Server는 Cluster에 참여하는 모든 Server의 IP/Port를 알고 있어야한다. Cluster에 참여하는 모든 Server의 IP/Port 정보는 Server의 Parameter를 통해서 **Static**하게 설정될 수도 있고, **Discovery** 기능을 활용하여 각 Server가 스스로 얻어올 수 있도록 설정할 수도 있다. Discovery 기능은 etcd 자체적으로 제공하는 기법과 DNS를 활용한 기법 2가지를 제공하고 있다. 

```shell {caption="[Shell 1] Server Cluster 생성"}
$ etcd --name infra0 --initial-advertise-peer-urls http://10.0.1.10:2380 \
  --listen-peer-urls http://10.0.1.10:2380 \
  --listen-client-urls http://10.0.1.10:2379,http://127.0.0.1:2379 \
  --advertise-client-urls http://10.0.1.10:2379 \
  --initial-cluster-token etcd-cluster-1 \
  --initial-cluster infra0=http://10.0.1.10:2380,infra1=http://10.0.1.11:2380,infra2=http://10.0.1.12:2380 \
  --initial-cluster-state new
```

[Shell 1]은 3개의 Server를 이용하여 Cluster를 구축할때 Static하게 모든 Server의 IP/Port를 입력하여 Server Cluster를 구축하는 명령어를 보여주고 있다. 3개의 Server 중에서 첫번째 Server를 실행하는 명령어를 보여주고 있다. --initial-cluster Parameter에 첫번째 Server 뿐만 아니라 두번째, 세번째 Server의 IP/Port 정보가 포함되어 있는것을 확인할 수 있다. 두번째, 세번째 Server를 구동할 때도 [Shell 1]과 유사하게 나머지 Server의 IP/Port 정보가 포함되어 있어야 한다.

Server Cluster 내부의 통신은 TLS를 이용하여 암호화 될 수 있다.

#### 1.2. Client Load Balancer

```shell {caption="[Shell 2] etcdctl"}
$ etcdctl --endpoints=http://10.0.1.10:2379,http://10.0.1.11:2379,http://10.0.1.12:2379 member list
```

Server Cluster와 통신하기 위해서는 Client는 Cluster에 참여하는 일부 Server의 IP/Port 정보를 알고 있으면 된다. 이때 Client가 다수의 Server의 IP/Port 정보를 알고 있다면 Client는 Load Balancer를 활용하여 요청을 분배하고, Server 장애시 장애가 발생하지 않는 다른 Server에게 요청을 다시 전송하여 스스로 장애에 대응한다. etcdctl은 etcd의 CLI Client이다. [Shell 2]는 etcdctl의 endpoints Parameter를 통해서 다수의 Server의 IP/Port를 전달하는 모습을 보여주고 있다.

Client는 어느 Server가 Leader Server인지 알고있지 못한다. 따라서 Client가 Load Balancing을 수행할 때는 Server의 역활은 고려되지 않는다. Client는 처음에는 Cluster의 모든 Server와 동시에 TCP Connection을 맺는 방법을 이용하다가, 이후에 한번에 하나의 TCP Connection을 맺는 방법을 이용하다가 현재는 gRCP의 SubConnection을 통해서 모든 Server와 논리적 Connection을 맺는 방식을 이용하고 있다.

#### 1.3. Server 추가/삭제

```shell {caption="[Shell 3] Server 추가"}
$ etcdctl member add infra2 --peer-urls=http://10.0.1.11:2380
```

```shell {caption="[Shell 4] Server 삭제"}
$ etcdctl member remove [Server ID]
```

Server Cluster에는 동적으로 Server를 추가하거나 제거할 수 있다. [Shell 3]은 etcdctl을 통해서 Server를 추가하는 모습을 나타내고 있다. etcdctl 명령어를 통해서 Server Cluster에 Server를 추가한 다음, 실제 Server를 구동하면 된다. [Shell 4]는 etcdctl을 통해서 Server를 제거하는 모습을 나타내고 있다. etcdctl 명령어를 통해서 Server Cluster에서 Server를 제거한 다음, 실제 Server를 내리면된다.

**중요한 점은 Quorum은 실제 Server가 구동/제거 될때가 아니라, etcdctl 명령어를 통해서 Server가 추가/제가 될때 변경된다는 점이다.** 따라서 Server 추가 명령어는 매우 신중하게 실행되어야 한다. 만약 Server Cluster에 Server가 1대일 경우에는 Quorum은 1이기 때문에, Server Cluster에 etcdctl 명령어를 통해서 Server 한대를 추가할 경우 문제업이 추가가 된다. 이때 Server Cluster에는 Server가 2대이기 때문에 Quorum은 2가 된다.

```shell {caption="[Shell 5] Server 추가/제거 불가능"}
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

문제는 Server를 추가하고 실제 Server를 구동하지 않는다면 해당 Server Cluster는 앞으로 Read Only Mode로만 동작할 뿐, Server 추가/삭제 동작 뿐만 아니라 Data Write 동작도 수행할 수 없게 된다. Quorum이 2이기 때문에 추가된 Server가 동작하여 투표할 수 있는 상황이 되어야, Server 추가/삭제 또는 Data Write가 가능하기 때문이다. [Shell 5]는 이러한 상황을 나타내고 있다. infra2 Server를 추가한 다음에 infra2 Server를 실제로 구동하지 않은 상태에서 infra3 Server가 추가되지 않는것을 알 수 있다. 원래의 상태로 돌리기 위해서 infra2 Server를 제거하려고 해도 infra2 Server가 실제로 동작하고 있지는 않기 때문에 제거되지도 않는다.

이러한 상황을 막기 위해서 etcd에서는 가능하면 Server 추가는 한대씩 차례차례 동작을 시키면서 추가하는 방법을 권장하고 있다. 또한 Server Cluster의 Server 교체시, 새로운 Server를 먼저 Server Cluster에 추가하고 교체할 Server를 Server Cluster에서 제거하는 방법이 아니라, 먼저 Server Cluster에서 교체할 Server를 제거한 다음 새로운 Server를 Server Cluster에 추가시키도록 권장하고 있다. 새로운 Server를 Server Cluster에 먼저 추가하면 불필요하게 Quorum이 증가하여 위의 문제가 발생할 수 있기 때문이다.

#### 1.3.1. Learner

```console {caption="[Shell 6] Learner로 Server 추가"}
$ etcdctl member add infra2 --learner --peer-urls=http://10.0.1.11:2380

$ etcdctl member promote [Server ID]
```

Raft Algorithm은 Server Cluster에 Server 추가시 Server Cluster의 일부 Server가 비정상 상태라면, 추가된 Server가 Leader Server의 Log를 쫒는 동안 Server Cluster의 가용성의 문제를 일으킬 수 있다. 이러한 문제를 해결하기 위해서 etcd는 Learner라는 상태를 만들었다. Server Cluster에 Server 추가시 learner Option을 명시하면, 추가된 Server는 Learner 상태로 Server Cluster에 추가된다. [Shell 6]은 Learner로 Server를 추가하는 etcdctl의 예제를 보여주고 있다.

Learner 상태의 Server는 Server Cluster에는 포함되어 있지만, Leader Server의 Log를 복제 및 State Machine에 반영하는 동작만을 수행하고 투표에는 참여하지 않는다. etcd 사용자는 Learner Server의 Log 복제가 어느정도 이루어졌다고 판단되면 promote 명령어를 통해서 Learner Server를 Follower Server로 변경할 수 있다.

## 2. 참조

* [https://etcd.io/docs/v3.4.0/faq/](https://etcd.io/docs/v3.4.0/faq/)
* [https://etcd.io/docs/v3.4.0/op-guide/clustering/](https://etcd.io/docs/v3.4.0/op-guide/clustering/)
* [https://etcd.io/docs/v3.4.0/learning/design-client/](https://etcd.io/docs/v3.4.0/learning/design-client/)
* [https://etcd.io/docs/v3.4.0/learning/design-learner/](https://etcd.io/docs/v3.4.0/learning/design-learner/)
* [https://etcd.io/docs/v3.4.0/op-guide/runtime-configuration/](https://etcd.io/docs/v3.4.0/op-guide/runtime-configuration/)
* [https://github.com/etcd-io/etcd/blob/master/Documentation/faq.md](https://github.com/etcd-io/etcd/blob/master/Documentation/faq.md)
---
title: MySQL Replication
---

MySQL의 HA(High Availabilty)를 위한 Replicaiton 기법들을 분석한다.

## 1. Master-Slave Replication

{{< figure caption="[Figure 1] MySQL Master-Slave Replication" src="images/master-slave-replication.png" width="600px" >}}

Master-Slave Replication은 하나의 Master DB와 다수의 Slave DB들을 통해 Replication을 수행하는 방식이다. [Figure 1]은 Master-Slave Replication을 나타내고 있다. Master는 Client로부터 받은 DB 변경 Query에 따라 DB를 변경하고, 변경 내용을 Slave DB에게 전달하여 Replication을 수행한다. 따라서 Master는 Read/Write Mode로 동작하고 Slave들은 Read Mode로 동작한다. Client는 Write 요청을 반드시 Master에게 전달해야 하고, Read 요청은 적절한 Master 또는 적절한 Slave에 전달하면 된다. 일반적으로 Slave앞에는 LB(Load Balancer)를 두어 Slave로 오는 Read 요청을 분산시키고, Read 성능을 높인다.

Replication 방식에는 Async, Semi-sync 2가지 방식을 지원한다. 두 방식 모두 완전히 동기화가 되는 Sync 방식은 아니기 때문에 Slave DB는 짧은 순간 Master DB와 동기화되지 않는 상태일 수 있다. Slave DB의 개수가 늘어날수록 동시에 Read를 수행할 수 있는 DB도 증가하기 때문에 Read 성능을 높일 수 있다. 하지만 Slave DB의 개수가 늘어나도 DB 변경 Query는 Master DB에서부터 전파되는 방식이기 때문에 Write 성능은 개선되지 않는다.

Master DB에 장애가 발생한다면 DB 관리자는 장애가 발생한 Master DB를 다시 기동하여 장애에 대응하거나 Slave DB를 새로운 Master DB로 승격시키는 방법으로 장애에 대응할 수 있다. 2가지 대응 방법 모두 DB 관리자가 개입하여 **수동**으로 이루어진다. Master DB를 다시 기동하여 장애에 대응하는 방법은 Data 손실의 염려가 없는 가장 안전한 방법이지만, Master DB가 복구될때까지 DB에 Write를 요청하지 못한다는 단점을 갖고 있다.

Slave DB를 승격시켜 새로운 Master를 이용하는 장애 대응 방법은 Master의 Downtime을 최소화 할 수 있는 장점이 있지만, Master DB와 Slave DB가 완전한 동기방식의 Replication을 이용하지 않기 때문에 Data 손실이 발생 할 수 있다. 또한 App이 새로운 Master DB로 요청을 전달 할 수 있게 App의 설정을 변경하거나 App과 Master DB 사이의 Network 설정의 변경도 필요하다는 단점도 갖고 있다. Slave DB에 장애가 발생할 경우에는 어떠한 Replication 방식을 적용했는지에 따라서 대응이 달라진다.

### 1.1. Async Replication

{{< figure caption="[Figure 2] MySQL Master-Slave Async Replication 과정" src="images/master-slave-async-replication.png" width="550px" >}}

Replication 동작 과정을 이해하기 위해서는 **Binary Log**, **Relay Log**를 이해해야한다. Binary Log는 모든 MySQL에서 이용되며 DB 변경 내용을 기록하는데 이용하는 Log이다. Binary Log는 MySQL의 DB Engine인 InnoDB가 기록하는 Redo Log와는 다른 별도의 Log이다. Binary Log는 MySQL의 전반적인 동작을 기록하는 Log이고, Redo Log는 InnoDB에서 내부적으로 Query 재실행, Query Rollback을 위해 Query를 기록하는 Log이다. Relay Log는 Slave DB에만 위치하며, Master DB의 Binary Log를 복사해 저장하는데 이용하는 Log이다.

[Figure 2]는 Async Replication 과정을 나타내고 있다. Master DB는 Slave DB에 관계없이 DB를 변경하고 DB 변경 내용을 Binary Log에 기록한다. Slave DB가 Replication을 위해 Master에 Connection을 맺으면, Master DB에는 Dump Thread 하나가 생성되고 Slave에는 I/O Thread, SQL Thread 2개의 Thread가 생성된다. Master DB의 Dump Thread와 Slave DB I/O Thread는 Connection을 맺고 있다. Slave DB의 I/O Thread는 Master DB의 Dump Thread를 통해서 Master DB의 Binary Log를 요청하고, 전달받아 자신의 Relay Log에 복사한다. Slave DB의 SQL Thread는 Relay Log 내용을 바탕으로 자신의 DB를 변경하고 변경 내용을 자신의 Binary Log에 기록한다.

Master DB는 Transaction 수행 중 Slave DB로 인한 추가적인 동작을 수행하지 않는다. Replication은 Transaction과 별도로 진행된다. 따라서 Master DB는 Slave DB로 인한 성능 저하가 거의 발생하지 않는다. Async 방식이기 때문에 Master DB에서 Transaction이 완료된 DB 변경 내용이더라도 Slave에는 바로 반영되지 않는다. 이는 Master DB의 갑작스러운 장애가 Data 손실로 이어질 수 있다는 의미이다. Slave DB의 장애는 Master DB의 Transaction에 아무런 영향을 주지 않는다. 장애가 발생했던 Slave DB는 복구 된 후 자신의 Relay Log, Binary Log 및 Master DB의 Binary Log를 바탕으로 중단되었던 Replication을 이어서 진행한다.

### 1.2. Semi-sync Replication

{{< figure caption="[Figure 3] MySQL Master-Slave Semi-sync Replication 과정" src="images/master-slave-semi-sync-replication.png" width="900px" >}}

[Figure 3]은 Semi-sync Replication 과정을 나타내고 있다. Semi-sync Replication은 Master DB가 Slave DB로부터 Relay Log 기록이 완료되었다는 ACK를 받고 Transaction을 진행하는 방식이다. 따라서 Async Replication 방식에 비해서 좀더 많은 DB 성능저하가 발생하지만, Master-Slave DB 사이의 동기화를 좀더 보장해준다. Semi-sync Replicaiton 방식에는 Master DB가 Slave DB에게 DB 변경 내용을 언제 전달하냐에 따라서 AFTER-COMMIT, AFTER-SYNC 2가지 방식으로 구분된다.

만약 Master DB가 Slave DB로부터 Relay Log를 받지 못하면 Transaction은 중단된다. 이러한 Transcation 중단은 다수의 Slave DB를 두어 최소화 할 수 있다. Master DB는 모든 Slave DB에게 DB 변경 내용을 전달하지만 하나의 Slave DB로부터 Relay Log ACK를 받으면 Transaction을 진행하기 때문이다.

## 2. Group Replication

Group Replication은 다수의 DB Instance를 Group으로 구성하여 Replication을 수행하는 방식이다. Client는 MySQL Router를 통해서 DB로 접근한다. MySQL Router는 Proxy, LB등의 역할을 수행한다. Group Replication은 **Single-primary**, **Multi-primary** 2가지 Mode를 지원한다.

### 2.1. Single-primary

{{< figure caption="[Figure 4] MySQL Group Single-primary Replication" src="images/group-replication-single-primary.png" width="600px" >}}

[Figure 4]는 Single-primary Mode를 나타내고 있다. Master-slave Replication과 유사하게 동작하는 Mode이다. 하나의 DB만 Primary DB로 동작하며 MySQL Router로부터 유일하게 Read/Write 요청을 받아 처리하는 DB이다. 나머지 DB는 Secondary DB로 동작하며 MySQL Router로부터 Read 요청만을 받아 처리한다. Primary-Secondary DB 사이의 Replication은 Master-Slave Replication와 동일하게 Async, Semi-Sync 2가지 방식을 지원한다. 

MySQL Router는 Read/Write 요청을 받는 Read/Write Port, Read 요청을 받는 Read Port 2개의 Port를 제공한다. Read/Write Port로 전달되는 Read/Write 요청은 Primary DB에게 전달되며, Read Port로 전달된는 Read 요청은 Load Balancing을 통해서 적절한 Secondary DB에게 전달된다. 따라서 App은 필요에 따라서 적절한 MySQL Router의 Port에 요청을 전달 해야한다. Master-Slave Replication과 다른 점 중 하나는 Primary DB에 장애가 발생시 **자동**으로 Secondary DB가 Primary DB로 승격된다는 점이다.

### 2.1. Multi-primary

{{< figure caption="[Figure 5] MySQL Group Multi-primary Replication" src="images/group-replication-multi-primary.png" width="600px" >}}

[Figure 5]는 Multi-primary Mode를 나타내고 있다. Multi-primary Mode는 모든 DB가 Primary Node로 동작한다. 따라서 App의 Read/Write 요청은 모든 DB에게 전달이 가능하다. MySQL Router는 DB의 부하에 따라서 적절한 DB에게 요청을 전달한다. 만약 서로다른 Primary DB에서 같은 Row을 동시에 변경하여 Commit 충돌이 발생하였다면, **먼져 Commit**한 Primary DB는 변경 내용이 반영되고 나중에 Commit한 Primary DB는 Abort된다. Single-primary Mode와 동일하게 DB 장애가 발생해도 Primary DB 및 MySQL Router를 **자동**으로 Failover하여 DB 관리자의 개입없이 계속 DB 사용이 가능하다.

{{< figure caption="[Figure 6] MySQL Group Multi-primary Replication, Certify 과정" src="images/group-replication-multi-primary-certify-replication.png" width="550px" >}}

[Figure 6]은 Multi-primary Mode의 Certify 및 Replication 과정을 나타내고 있다. Certify는 Commit 충돌 검사 과정을 의미한다. App에게 Commit 요청을 받은 첫번째 Primary DB는 자신의 DB를 변경하고, Replication를 수행할 두번째 Primary DB에게 Certify 요청 및 DB 변경 내용을 전달한다. 두번째 Primary DB는 Certify 진행 및 Certify 결과를 첫번째 Primary DB에게 전달한 뒤 자신의 DB를 변경한다. 첫번째 Primary는 두번째 Primary로부터 Certify 완료를 전달받은 뒤에나 App에게 Commit 결과를 전달한다. 이러한 Certify 과정은 Commit Overhead의 주요 원인이 된다. Certify 및 Replication 과정은 완전한 Sync 방식이 아닌 Semi-sync 또는 2 Phase-Commit 방식과 유사하다.

## 3. Galera Cluster

{{< figure caption="[Figure 7] MySQL Galera Cluster" src="images/galera-cluster.png" width="600px" >}}

Galera Cluster는 Group Replication의 Multi-primary Mode와 매우 유사한 Multi-master Replication 기법이다. Galera Cluster 설명에는 Replication 과정이 Sync 또는 Virtual Sync 방식이라고 설명되어 있지만, 실제로는 Group Replication의 Multi-primary Mode처럼 Semi-sync 또는 2 Phase-Commit 방식과 유사하게 구현되어 있다. [Figure 7]은 Galera Cluster를 의미한다. Client는 LB를 통해서 DB에 접근한다. 각 DB는 wsrep(Write Set Replication) Plugin을 통하여 서로 wsrep API로 통신하며 Replication을 진행한다.

Galera Cluster와 Group Replication의 Multi-primary Mode은 유사하지만 몇가지 차이점을 가진다. Galera Cluster에서는 DB가 변경될 경우 모든 DB에 변경내용이 반영되어야 Commit을 성공한다. 만약 Galera Cluster가 3개의 DB로 이루어져 있다면 3개의 DB 모두 변경내용이 적용되어야 Commit에 성공한다는 의미이다. 반대로 Group Replication의 Multi-primary Mode의 경우 과반수 이상의 DB에만 변경내용이 반영되면 Commit을 성공한다. 만약 Group Replication의 Multi-primary Mode로 3개의 DB로 이루어져 있다면 3개의 DB 중에서 2개의 DB에만 변경내용이 반영되면 Commit을 성공한다. Galera Cluster는 MySQL기반인 MariaDB 및 Percona에서도 적용할 수 있지만 Group Replication은 현재 MySQL에서만 적용 할 수 있다.

## 4. 참조

* [http://skillachie.com/2014/07/25/mysql-high-availability-architectures/](http://skillachie.com/2014/07/25/mysql-high-availability-architectures/)
* [https://www.percona.com/blog/2017/02/07/overview-of-different-mysql-replication-solutions/](https://www.percona.com/blog/2017/02/07/overview-of-different-mysql-replication-solutions/)
* Master-Slave Replication : [https://blurblah.net/1505](https://blurblah.net/1505)
* Master-Slave Replication : [https://www.percona.com/blog/2013/01/09/how-does-mysql-replication-really-work/](https://www.percona.com/blog/2013/01/09/how-does-mysql-replication-really-work/)
* Semi-sync : [http://www.mysqlkorea.com/gnuboard4/bbs/board.php?bo-table=develop-03&wr-id=73](http://www.mysqlkorea.com/gnuboard4/bbs/board.php?bo-table=develop-03&wr-id=73)
* Semi-sync : [http://gywn.net/tag/semi-sync-replication/](http://gywn.net/tag/semi-sync-replication/)
* Replication, Master : [https://stackoverflow.com/questions/38036955/when-to-prefer-master-slave-and-when-to-cluster](https://stackoverflow.com/questions/38036955/when-to-prefer-master-slave-and-when-to-cluster)
* Group Replication : [https://www.percona.com/live/17/sessions/everything-you-need-know-about-mysql-group-replication](https://www.percona.com/live/17/sessions/everything-you-need-know-about-mysql-group-replication)
* Group Replication : [https://lefred.be/content/mysql-group-replication-synchronous-or-asynchronous-replication/](https://lefred.be/content/mysql-group-replication-synchronous-or-asynchronous-replication/)
* Group Replicaiton : [https://scriptingmysql.wordpress.com/category/mysql-replication/](https://scriptingmysql.wordpress.com/category/mysql-replication/)
* Group Replication : [https://dev.mysql.com/doc/mysql-router/8.0/en/mysql-router-innodb-cluster.html](https://dev.mysql.com/doc/mysql-router/8.0/en/mysql-router-innodb-cluster.html)
* Galera Cluster : [https://www.slideshare.net/MyDBOPS/galera-cluster-for-high-availability](https://www.slideshare.net/MyDBOPS/galera-cluster-for-high-availability)
* Group Replication, Galera Cluster : [https://www.percona.com/blog/2017/02/24/battle-for-synchronous-replication-in-mysql-galera-vs-group-replication/](https://www.percona.com/blog/2017/02/24/battle-for-synchronous-replication-in-mysql-galera-vs-group-replication/)
* Group Replicaiton, Galera Cluster : [https://severalnines.com/resources/tutorials/mysql-load-balancing-haproxy-tutorial](https://severalnines.com/resources/tutorials/mysql-load-balancing-haproxy-tutorial)


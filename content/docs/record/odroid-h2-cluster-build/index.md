---
title: ODROID-H2 Cluster 구축
---

Ceph, Openstack 설치를 위한 ODROID-H2 Cluster를 구축한다.

## 1. ODROID-H2 Cluster

{{< figure caption="[Photo 1] ODROID-H2 Cluster 구성 사진" src="images/cluster-photo.png" width="1000px" >}}

{{< figure caption="[Figure 1] ODROID-H2 Cluster 구성" src="images/cluster.png" width="1000px" >}}

[Photo 1]은 ODROID-H2 Cluster의 실제 모습을 보여주고 있다. [Figure 1]은 ODROID-H2 Cluster를 나타내고 있다. 모든 ODROID-H2의 Spec은 동일하다. 모든 Node의 Default Gateway는 NAT Network로 설정되어 있다. Node 04는 VM이며 Montoring 및 Deploy 용도로 이용한다. ODROID-H2 Cluster의 주요 사양은 아래와 같다.

* ODROID-H2 * 3
  * CPU : 4Core, Intel Celeron J4105 Processor
  * Memory : 8GB * 2, SAMSUNG DDR4 PC4-19200
  * Root Storage : 64GB, eMMC
  * Ceph Storage : 256GB, SAMSUNG PM981 M.2 2280 
* VM * 1
  * CPU : 2Core
  * Memory: 8GB
* Network
  * NAT Network : 192.168.0.0/24
  * Private Network : 10.0.0.0/24

### 1.1. Ceph

{{< figure caption="[Figure 2] Ceph 구성 on ODROID-H2 Cluster" src="images/ceph.png" width="1000px" >}}

[Figure 2]는 Ceph 구성시 필요한 구성 요소를 나타내고 있다. Node01은 Ceph의 Monitor, Manager, OSD Node로 이용한다. Node02, 03은 OSD Node로만 이용하고 Node04는 Deploy Node로 이용한다. 각 Node의 NVMe Storage를 OSD의 Block Storage로 이용한다. Ceph의 File Storage와 Object Storage는 이용하지 않을 예정이기 때문에 Ceph의 MDS (Meta Data Server)와 radosgw는 설치하지 않는다. Ceph Network로 Private Network를 이용한다.

### 1.2. OpenStack

{{< figure caption="[Figure 3] OpenStack 구성 on ODROID-H2 Cluster" src="images/openstack.png" width="1000px" >}}

[Figure 3]은 OpenStack 구성시 필요한 구성 요소를 나타내고 있다. Node01은 OpenStack의 Controller Node와 Network Node로 이용하고, Node02, Node03은 OpenStack의 Compute Node로 이용한다. Node01은 OpenStack의 Network Node 역할을 수행하기 때문에 OpenStack의 External Network를 위한 추가 Network Interface (enx88366cf9f9ed)를 갖고 있다. 해당 Network Interface에는 IP를 할당하지 않는다. External Network (Provider Network)로 NAT Network를 이용한다. Guest (Tenant Network), Management Network는 Private Network를 이용한다.

## 2. 참조

* [https://docs.openstack.org/devstack/stein/guides/neutron.html](https://docs.openstack.org/devstack/stein/guides/neutron.html)
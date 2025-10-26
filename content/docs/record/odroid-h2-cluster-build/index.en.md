---
title: ODROID-H2 Cluster Construction
---

Build an ODROID-H2 Cluster for Ceph and OpenStack installation.

## 1. ODROID-H2 Cluster

{{< figure caption="[Photo 1] ODROID-H2 Cluster Configuration Photo" src="images/cluster-photo.png" width="1000px" >}}

{{< figure caption="[Figure 1] ODROID-H2 Cluster Configuration" src="images/cluster.png" width="1000px" >}}

[Photo 1] shows the actual appearance of the ODROID-H2 Cluster. [Figure 1] represents the ODROID-H2 Cluster. All ODROID-H2 specifications are identical. The default gateway for all nodes is configured as a NAT network. Node 04 is a VM and is used for monitoring and deployment purposes. The main specifications of the ODROID-H2 Cluster are as follows.

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

{{< figure caption="[Figure 2] Ceph Configuration on ODROID-H2 Cluster" src="images/ceph.png" width="1000px" >}}

[Figure 2] shows the components required for Ceph configuration. Node01 is used as Ceph's Monitor, Manager, and OSD Node. Node02 and 03 are used only as OSD Nodes, and Node04 is used as a Deploy Node. Each node's NVMe storage is used as OSD's block storage. Since Ceph's file storage and object storage are not planned to be used, Ceph's MDS (Meta Data Server) and radosgw are not installed. Private network is used for Ceph network.

### 1.2. OpenStack

{{< figure caption="[Figure 3] OpenStack Configuration on ODROID-H2 Cluster" src="images/openstack.png" width="1000px" >}}

[Figure 3] shows the components required for OpenStack configuration. Node01 is used as OpenStack's Controller Node and Network Node, and Node02 and Node03 are used as OpenStack's Compute Nodes. Since Node01 performs the role of OpenStack's Network Node, it has an additional network interface (enx88366cf9f9ed) for OpenStack's external network. No IP is assigned to this network interface. NAT network is used as the external network (provider network). Private network is used for guest (tenant network) and management network.

## 2. References

* [https://docs.openstack.org/devstack/stein/guides/neutron.html](https://docs.openstack.org/devstack/stein/guides/neutron.html)

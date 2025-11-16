---
title: Ceph
---

Analyzes Ceph, which is widely used as distributed Storage.

## 1. Ceph

{{< figure caption="[Figure 1] Ceph Architecture" src="images/ceph-architecture.png" width="800px" >}}

Ceph is a distributed Storage based on Object Storage. Although it is Object Storage, it also provides File Storage and Block Storage functionality. Therefore, Ceph is used in various environments. The biggest characteristic of Ceph is that it adopts an Architecture that considers the **Single Point of Failure** problem. That is, Ceph uses a distributed processing method rather than a centralized processing method, and is designed so that Ceph operation is not affected even if problems occur in specific Nodes.

### 1.1. Storage Type

Ceph provides three types of Storage: Object Storage, Block Storage, and File Storage.

#### 1.1.1. Object Storage

When Ceph operates as Object Storage, RADOS Gateway performs the role of RADOS Cluster's Client and Object Storage's Proxy. RADOS Gateway stores and controls Objects using Librados, which helps control RADOS Cluster. Apps store Data using RADOS Gateway's REST API. REST API provides Account-related functionality and functionality to manage Buckets that perform the role of File System folders, and has characteristics compatible with AWS S3 and OpenStack's Swift.

Multiple RADOS Gateways can operate simultaneously, and it is good to operate multiple RADOS Gateways to prevent Single Point of Failure. Ceph does not provide Load Balancing between RADOS Gateways, and a separate Load Balancer must be used.

#### 1.1.2. Block Storage

When Ceph operates as Block Storage, Linux Kernel's RBD Module or Librbd based on Librados becomes RADOS Cluster's Client. Kernel can allocate and use Block Storage from RADOS Cluster through RBD Module. QEMU can allocate Block Storage to give to VMs through Librbd.

#### 1.1.3. File Storage

When Ceph operates as File Storage, Linux Kernel's Ceph File System or Ceph Fuse Daemon becomes RADOS Cluster's Client. Linux Kernel can mount Ceph File Storage through Ceph Filesystem or Ceph Fuse.

### 1.2. RADOS Cluster

RADOS Cluster consists of three components: OSD (Object Storage Daemon), Monitor, and MDS (Meta Data Server).

#### 1.2.1. OSD (Object Storage Daemon)

{{< figure caption="[Figure 2] Ceph Object" src="images/ceph-object.png" width="800px" >}}

OSD is a Daemon that stores Data on Disk in **Object form**. Storing in Object form means storing Data as **Key/Value/Metadata**. [Figure 2] shows how OSD stores Data. Data is stored in Namespace, which performs the role of File System folders. Bucket mentioned in the Object Storage explanation above is the same concept as OSD's Namespace. Namespace does not form a Tree hierarchy like File System folders. Metadata is again composed of Key/Value.

A separate OSD Daemon operates for each Disk of a Node. Disks mainly use Disks formatted with XFS Filesystem. However, ZFS and EXT4 Filesystem can also be used, and OSD of the latest version Ceph also directly uses Disks without using a separate Filesystem using BlueStore Backend.

#### 1.2.2. Monitor

**Cluster Map** is information necessary for operating and maintaining RADOS Cluster, and consists of Monitor Map, OSD Map, PG Map, CRUSH Map, and MDS Map. Monitor is a Daemon that manages and maintains these Cluster Maps. Monitor also manages Ceph's security or logs. Multiple Monitors can operate simultaneously, and it is good to operate multiple Monitors to prevent Single Point of Failure. When multiple Monitors operate, Monitor uses the **Paxos** algorithm to reach Consensus on Cluster Maps stored by each Monitor.

#### 1.2.3. MDS (Meta Data Server)

MDS is a Daemon that manages Meta Data necessary to provide POSIX-compatible File System, and is only needed when Ceph operates as File Storage. It stores and manages File Meta information such as Directory hierarchy, Owner, and Timestamp in Object form in RADOS Cluster.

{{< figure caption="[Figure 3] Ceph MDS Namespace" src="images/ceph-mds-namespace.png" width="700px" >}}

[Figure 3] shows the Namespace of Ceph File System. The Tree shape represents the Directory structure of File System. In Ceph, the entire Tree or Sub Tree is expressed as Namespace. Each MDS manages only one Namespace and manages only Meta Data related to the Namespace it manages. Namespace changes dynamically according to Tree load status and Replica status.

#### 1.2.4. Client (Librados, RBD Module, Ceph File System)

As mentioned above, Librados, Kernel's RBD Module, and Kernel's Ceph File System perform the role of RADOS Cluster's Client. Client directly connects to Monitor through **Monitor IP List** written by Ceph administrator in Config file to obtain Cluster Map information managed by Monitor. Then Client uses information such as OSD Map and MDS Map in Cluster Map to directly access OSD and MDS to perform necessary operations. Consensus of Cluster Maps stored by each Client and Monitor is also reached using the Paxos algorithm.

### 1.3. CRUSH, CRUSH Map

{{< figure caption="[Figure 4] Ceph PG, CRUSH" src="images/ceph-pg-crush.png" width="700px" >}}

**CRUSH** is an algorithm that determines which OSD to place Objects on. When Replica is configured, Replica's location is also determined through CRUSH. [Figure 4] shows the process of Objects being allocated to OSDs. Objects are allocated to specific PG (Placement Group) through Hashing of Object ID. And PG is again allocated to specific OSD through PG ID and CRUSH. [Figure 4] assumes that Replica is set to 3. Therefore, CRUSH allocates 3 OSDs per Object.

{{< figure caption="[Figure 5] Ceph CRUSH Map" src="images/ceph-crush-map.png" width="800px" >}}

CRUSH uses Storage Topology called **CRUSH Map**. [Figure 5] shows CRUSH Map. CRUSH Map is composed of a hierarchy of logical units called **Bucket**. Bucket consists of 11 types: root, region, datacenter, room, pod, pdu, row, rack, chassis, host, and osd. The Leaf of CRUSH Map must be an osd bucket.

Each Bucket has a **Weight** value, and Weight represents the proportion of Objects that each Bucket has. If Bucket A's Weight is 100 and Bucket B's Weight is 200, it means Bucket B has twice as many Objects as Bucket A. Therefore, generally, the Weight value of osd Bucket Type is set in proportion to the capacity of the Disk managed by OSD. The weight of the remaining Bucket Types is the sum of the Weights of all subordinate Buckets. The numbers inside Buckets in [Figure 5] represent Weight.

CRUSH starts from CRUSH Map's root Bucket, selects subordinate Buckets as many as the Replica count, and repeats the same operation in selected Buckets to find osd Bucket at Leaf. The Replica count of Objects is determined according to Replica set in Bucket Type. If 3 Replicas are set in Rack Bucket Type and 2 Replicas are set in Row Bucket Type, CRUSH selects 3 Rack Buckets and selects 2 Row Buckets per Rack Bucket, which are subordinate Buckets of selected Rack Buckets, so Object's Replica becomes 6. The criterion for selecting subordinate Buckets is determined according to Bucket algorithm set in each Bucket Type. Bucket algorithms include Uniform, List, Tree, Straw, and Straw2.

### 1.4. Read/Write

{{< figure caption="[Figure 6] Ceph Read/Write" src="images/ceph-read-write.png" width="600px" >}}

One of Ceph's characteristics is that Ceph Client directly accesses OSD to manage Objects. [Figure 6] shows Ceph's Read/Write process. **Ceph Client obtains CRUSH Map information from RADOS Cluster's Monitor before performing Read/Write.** Then Client can identify the location of OSD where the Object to access is located using CRUSH Map and CRUSH without separate external communication.

Among OSDs determined through CRUSH, the first OSD is expressed as **Primary OSD**. In the Read process, only Primary OSD is used to perform Read operations. In the Write process, Client sends Object along with information about additional OSDs where Object's Replicas will be stored to Primary OSD. After Primary OSD receives all Objects from Client, it sends received Objects to remaining OSDs. After all transfers are complete, Primary OSD sends Write Ack to Client.

## 2. References

* [http://docs.ceph.com/docs/master/architecture/](http://docs.ceph.com/docs/master/architecture/)
* [http://yauuu.me/ride-around-ceph-crush-map.html](http://yauuu.me/ride-around-ceph-crush-map.html)
* [http://docs.ceph.com/docs/jewel/rados/configuration/mon-config-ref/](http://docs.ceph.com/docs/jewel/rados/configuration/mon-config-ref/)
* [https://www.slideshare.net/sageweil1/20150222-scale-sdc-tiering-and-ec](https://www.slideshare.net/sageweil1/20150222-scale-sdc-tiering-and-ec)
* [http://140.120.7.21/LinuxRef/CephAndVirtualStorage/VirtualStorageAndUsbHdd.html](http://140.120.7.21/LinuxRef/CephAndVirtualStorage/VirtualStorageAndUsbHdd.html)
* [https://ceph.com/wp-content/uploads/2016/08/weil-crush-sc06.pdf](https://ceph.com/wp-content/uploads/2016/08/weil-crush-sc06.pdf)
* [https://www.slideshare.net/LarryCover/ceph-open-source-storage-software-optimizations-on-intel-architecture-for-cloud-workloads](https://www.slideshare.net/LarryCover/ceph-open-source-storage-software-optimizations-on-intel-architecture-for-cloud-workloads)
* [http://www.lamsade.dauphine.fr/~litwin/cours98/Doc-cours-clouds/ceph-2009-02%5B1%5D.pdf](http://www.lamsade.dauphine.fr/~litwin/cours98/Doc-cours-clouds/ceph-2009-02%5B1%5D.pdf)
* [https://thenewstack.io/software-defined-storage-ceph-way/](https://thenewstack.io/software-defined-storage-ceph-way/)


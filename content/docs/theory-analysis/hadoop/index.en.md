---
title: Hadoop
---

This post analyzes Hadoop and the HDFS, YARN, and MapReduce Framework that compose Hadoop.

## 1. Hadoop (High-Available Distribute Object-Oriented Platform)

{{< figure caption="[Figure 1] Hadoop" src="images/hadoop.png" width="400px" >}}

**Hadoop** is a Framework that helps easily process large amounts of Data distributed across a Compute Cluster concurrently. In Hadoop V2, it is separated into three Layers — HDFS, YARN, and MapReduce — as shown in [Figure 1].

HDFS is a Distributed Filesystem that guarantees Data Redundancy and Data Reliability. Through HDFS, large amounts of Data are stored safely within the Cluster. YARN is a Daemon that performs the Job Scheduling operation of deciding on which Node an App such as MapReduce runs, and manages the Computing Resources of each Node composing the Cluster. MapReduce is an App Framework that helps easily process large amounts of Data on top of HDFS and YARN.

## 2. HDFS

{{< figure caption="[Figure 2] HDFS Architecture" src="images/hdfs-architecture.png" width="700px" >}}

HDFS is a Distributed Filesystem that guarantees Data Redundancy and Data Reliability. HDFS has a Master/Slave Architecture, consisting of the **Name Node**, which plays the Master role, and the **Data Node**, which plays the Slave role. The Name Node manages the Meta Data for HDFS and provides Namespace functions such as File Open, Close, and Rename to the Client. A Data Node refers to any Node with attached Storage for storing Files, and it plays the role of storing Files split into Block units on its Storage and serving them to the Client.

The Meta Data stores Namespace information, File-Block Mapping information, and so on. The Name Node keeps the Meta Data in Memory and uses it. In addition, to preserve the Meta Data contents, the Name Node stores the Meta Data contents in the `fsimage` File and the `EditLog` File inside the Name Node. The Name Node periodically saves the Meta Data in Memory to the `fsimage` File through a Checkpoint operation. Then, after the Checkpoint operation, changes to the Meta Data are stored in the `EditLog` File. Therefore, the Meta Data can be recovered through the `fsimage` File and the `EditLog` File. The `fsimage` File and the `EditLog` File are used to recover the Meta Data when the Name Node restarts or when the Name Node fails.

#### 2.1. Read, Write

The red lines in [Figure 2] show the Read process of HDFS.

* 1,2 : The Client obtains the Block information of the File to read from the Name Node.
* 3,4 : Based on the Block information, the Client sends Block Read requests directly to the Data Nodes where the Blocks are located, and receives the Block Data. If the Blocks to read are located on multiple Data Nodes, the Block Reads are performed simultaneously. Therefore, HDFS can achieve high Read performance.

The blue lines in [Figure 2] show the Write process of HDFS.

* 1,2 : The Client obtains the information of the Blocks to be written from the Name Node. At this time, according to the Replication setting, the information of the Data Nodes where the Block replicas will be stored is also delivered to the Client.
* 3 : The Client sends the Block Data directly to one of the delivered Data Nodes. It also delivers to that Data Node the information of the other Data Nodes where the Block will be replicated and stored.
* 4,5 : The Data Node writes the received Block to its Disk. When the Write completes, it sends the Block again to the next Data Node where the written Block will be replicated and stored. The Block transfer and Block Write process is repeated as many times as the Replication setting of HDFS.
* 6,7,8 : When the Block is written to the last Data Node, ACK Messages are delivered in the reverse order of the Block replication, and finally the Client receives the ACK Message. This Block replication technique between Data Nodes is called **Replication Pipelining**. Because of Replication Pipelining, HDFS has low Write performance.

Since HDFS does not support modifying a Block once it has been written, a File once written to HDFS cannot be changed. Only the operation of appending Data (Blocks) to the end of a File is supported. To modify the contents of a File, the File must be deleted from HDFS and the entire changed File copied back. However, this limitation is not a big problem for using HDFS. As described above, HDFS has high Read performance and low Write performance, so mostly Read-Only Data is stored in HDFS.

#### 2.2 Replication

The Blocks composing a File are replicated and stored on multiple Nodes according to the Replication setting of HDFS or the Replication setting of the File. If Replication is set to 3, a Block is copied into 3 replicas and stored on Data Nodes. [Figure 2] also shows the Block state when Replication is set to 3. Blocks of the same color mean that they hold the same Data.

When selecting Data Nodes for Replication during a Block Write, the Name Node selects Data Nodes considering **Rack Awareness**, that is, the Rack Topology. As shown in [Figure 2], when the Replication setting is 3, if the Name Node selects Data Node B as the Data Node for the orange Block, the remaining 2 Data Nodes are selected from among the Data Nodes of Rack B, which does not contain Data Node B.

Since Data Nodes are not selected only within the same Rack, the Client can access all Files even if a failure occurs in one Rack. The reason the 2 Data Nodes are selected from the same Rack is to reduce Network Hops. This is because, due to Replication Pipelining during a Block Write, the larger the Network Hops between Data Nodes, the longer the Write takes.

#### 2.3. Namespace

HDFS uses the **Tree** structure used by most current Filesystems. Users can create Directories and Write and Remove Files inside Directories.

## 3. YARN

{{< figure caption="[Figure 3] YARN Architecture" src="images/yarn-achitecture.png" width="600px" >}}

YARN is a Daemon that performs the Job Scheduling operation of deciding on which Node an App such as MapReduce runs, and manages the Computing Resources of each Node composing the Cluster. YARN also has a Master/Slave Architecture, consisting of the **RM** (Resource Manager), which plays the Master role, and the **NM** (Node Manager), which plays the Slave role. The RM allocates Compute Resources (JVM), called **Containers**, to each Node through the NM. Some of the Containers run the **AM** (Application Master), which manages an App such as MapReduce overall.

The RM consists of the Scheduler and the Application Manager. The Scheduler allocates a Container on a Node to run the AM that manages the App delivered from the Client, or allocates the Containers requested by the AM. The Application Manager accepts Jobs delivered from the Client and helps the Scheduler launch the AM Container. It also monitors the AM Container and plays the role of restarting the AM Container when the AM Container dies. The NM runs on every Node except the Node where the RM runs, and periodically reports the status of the Nodes to the RM. It also creates or deletes Containers on the Node at the request of the RM or the AM.

In Hadoop 1.0, only MapReduce Apps could use the Compute Resources of the Hadoop Cluster, but with YARN added in Hadoop 2.0, not only MapReduce but also various Apps such as Spark and Hive can use the Compute Resources of the Hadoop Cluster simultaneously. When building YARN on the same Cluster as HDFS, the Resource Manager of YARN runs on the Name Node of HDFS, and the Node Manager of YARN runs on the Data Nodes of HDFS.

#### 3.1. App Submission

{{< figure caption="[Figure 4] YARN App Submission" src="images/yarn-app-submission.png" width="800px" >}}

[Figure 4] shows the process in which an App is submitted to YARN by the Client and executed.

* 1,2,3 : The Client obtains an App ID from the RM through the Job Object.
* 4 : The Job Object stores the Task Jar file containing the Task Code to be executed in a distributed manner, along with related information for running the App, in a Shared Filesystem such as HDFS.
* 5 : The Job Object submits the App to the RM using the obtained App ID.
* 6,7 : The RM decides through the Scheduler on which Node to launch the AM Container that will manage the delivered App. The RM then launches the AM Container through the NM of the selected Node.
* 8,9 : The AM investigates on which Nodes the Files needed for Task execution are located.
* 10,11 : The AM delivers the File locations and the Resource information for launching the Tasks to the RM, and obtains the information of the Nodes where the Task Containers will be launched.
* 12 : The AM delivers the Task-related information to the NM of the Node that will launch the Task Container.
* 13 : The NM launches the Task Container based on the delivered Task information.
* 14,15,16 : In the Task Container, the YARN Child Object obtains the Task-related information from the Shared Filesystem and then executes the Task.

#### 3.2. Data Locality

When processing Data, Hadoop does not process Data by moving the Data to a specific Node; instead, it processes Data by sending the processing Task to the Node where the Data resides. This is because moving the processing Task is faster than processing Data while moving large amounts of Data. This processing approach is described as an approach that considers Data Locality.

The AM can learn the Node locations of the Files (Input Splits) needed for Task execution through the `getSplits()` Method defined by the App. The AM delivers the information of the Nodes where the Files are located to the RM so that Tasks run on the Nodes with the Files if possible, performing Scheduling considering Data Locality.

## 4. MapReduce Framework

The MapReduce Framework is a Framework that helps perform MapReduce on top of HDFS and YARN. Using the MapReduce technique, large amounts of Data can be processed quickly in parallel.

## 5. References

* Hadoop : [https://noobergeek.wordpress.com/2012/11/12/why-is-hadoop-so-fast/](https://noobergeek.wordpress.com/2012/11/12/why-is-hadoop-so-fast/)
* HDFS : [https://hadoop.apache.org/docs/r1.2.1/hdfs_design.html](https://hadoop.apache.org/docs/r1.2.1/hdfs_design.html)
* HDFS : [http://www.waytoeasylearn.com/2018/01/hdfs-read-write-architecture.html](http://www.waytoeasylearn.com/2018/01/hdfs-read-write-architecture.html)
* HDFS : [https://www.quora.com/How-is-replication-done-in-Hadoop](https://www.quora.com/How-is-replication-done-in-Hadoop)
* YARN : [https://www.popit.kr/what-is-hadoop-yarn/](https://www.popit.kr/what-is-hadoop-yarn/)
* YARN : [http://blog.cloudera.com/blog/2015/09/untangling-apache-hadoop-yarn-part-1/](http://blog.cloudera.com/blog/2015/09/untangling-apache-hadoop-yarn-part-1/)
* YARN : [http://backtobazics.com/big-data/yarn-architecture-and-components/](http://backtobazics.com/big-data/yarn-architecture-and-components/)
* YARN : [https://stackoverflow.com/questions/34709213/hadoop-how-job-is-send-to-master-and-to-nodes-on-mapreduce](https://stackoverflow.com/questions/34709213/hadoop-how-job-is-send-to-master-and-to-nodes-on-mapreduce)
* YARN : [http://blog.cloudera.com/blog/2015/09/untangling-apache-hadoop-yarn-part-1/](http://blog.cloudera.com/blog/2015/09/untangling-apache-hadoop-yarn-part-1/)
* HDFS + YARN : [https://stackoverflow.com/questions/36215672/spark-yarn-architecture](https://stackoverflow.com/questions/36215672/spark-yarn-architecture)

---
title: AWS EFS
---

This post organizes AWS's EFS (Elastic File System) Service. **EFS Service** is a Managed NFS Server Service provided by AWS.

## 1. Storage Class

AWS EFS provides Storage Classes so that AWS EFS can be used cost-effectively for various Usecases. They are largely classified into Standard and One Zone, and an IA (Infrequent Access) Storage Class exists for each.

### 1.1. Standard

The standard Storage Class. The Meta and Data of AWS EFS are replicated synchronously across multiple AZs. Therefore, even if one or two AZ failures occur, no Data Loss occurs. Cost is incurred in proportion to the size of the Data stored in AWS EFS.

### 1.2. Standard-IA (Infrequent Access)

The Data storage cost is lower than that of the Standard Class, but additional cost is incurred when performing Data Reads. Therefore, its use is recommended when the Data access frequency is low. Like the Standard Class, the Meta and Data of AWS EFS are replicated synchronously across multiple AZs.

### 1.3. One Zone

The One Zone Class, as its name implies, is a Class that stores the Meta and Data of AWS EFS in only one Zone. Therefore, when a failure occurs in the AZ where the Meta and Data are stored, the Data may become inaccessible or Data Loss may occur, but the Data storage cost is lower than that of the Standard and Standard-IA Classes. The User can specify at creation time in which AZ the Meta and Data of AWS EFS are stored.

### 1.4. One Zone-IA (Infrequent Access)

The Data storage cost is lower than that of the One Zone Class, but additional cost is incurred when performing Data Reads. Therefore, its use is recommended when the Data access frequency is low. Like the One Zone Class, the Meta and Data of AWS EFS are stored in only one AZ.

## 2. Architecture

### 2.1. Standard

{{< figure caption="[Figure 1] AWS EFS Standard" src="images/aws-efs-standard.png" width="900px" >}}

[Figure 1] shows the Architecture of AWS EFS when using the Standard and Standard-IA Classes. The EFS Storage exists inside a separate VPC managed by AWS, and an EC2 Instance mounts and uses EFS through the ENI that exists in the same AZ. Since the EFS Meta, Data, and ENI all exist in every AZ, EFS can be used without Downtime in the remaining AZs even when a specific AZ fails.

The reason an EC2 Instance can use the ENI that exists in the same AZ is that Route 53 is utilized. When an EFS is created, Route 53 creates a Domain for the EFS Mount Point in the form of `xxx.efs.region.amazonaws.com`. Depending on which AZ the EC2 Instance is located in, Route 53 returns the ENI IP Address of the same AZ where the EC2 Instance is located. Therefore, when each EC2 Instance performs a Mount against the EFS Mount Point Domain, it naturally accesses EFS through the ENI that exists in the same AZ.

Since the EFS Storage and the EFS VPC are fully managed by AWS, the AWS User does not need to care about them, but ENI creation and the Security Group associated with the ENI must be managed directly by the AWS User. The ENI Security Group must be configured to allow access from the EC2 Instances that need to use EFS.

### 2.2. One Zone

{{< figure caption="[Figure 2] AWS EFS One Zone" src="images/aws-efs-one-zone.png" width="900px" >}}

[Figure 2] shows the Architecture of AWS EFS when using the One Zone and One Zone-IA Classes. It is similar to the Standard Architecture of [Figure 1], but it can be seen that the EFS Meta, Data, and ENI exist in only one AZ. Therefore, when the ENI and the EC2 Instance exist in different AZs, additional Data transfer cost is incurred because the Data must cross AZs. Route 53 returns the IP of the single existing ENI regardless of which AZ the EC2 Instance is in.

## 3. Performance

The performance of AWS EFS is determined by the combination of two settings: **Performance Mode** and **Throughput Mode**. The Performance Mode determines the Latency and IOPS ceiling of File operations, and the Throughput Mode determines the amount of available Throughput and the billing method.

### 3.1. Performance Mode

For the Performance Mode, one of the two Modes below is specified at EFS creation time, and it cannot be changed after creation.

* **General Purpose** : The default Mode, which provides the lowest File operation Latency and is therefore recommended for most Workloads. When using the One Zone and One Zone-IA Classes, only the General Purpose Mode can be used.
* **Max I/O** : Provides higher IOPS and Throughput than the General Purpose Mode, but the Latency of File operations is relatively high. It is suitable for highly parallel Workloads where hundreds or more EC2 Instances access EFS simultaneously.

### 3.2. Throughput Mode

For the Throughput Mode, one of the three Modes below is specified. It can be changed even after EFS creation, but it cannot be changed again for 24 hours after a change.

* **Bursting** : A Mode in which Throughput is determined in proportion to the size of the stored Data. A Baseline Throughput of 50MiB/s per 1TiB of stored Data is provided, and Burst Credits accumulated while using Throughput lower than the Baseline can be consumed to temporarily use Throughput higher than the Baseline.
* **Provisioned** : A Mode that provides a fixed Throughput specified by the User regardless of the size of the stored Data. Additional cost is incurred for the specified Throughput that exceeds the Baseline Throughput based on the Bursting Mode.
* **Elastic** : A Mode in which Throughput is automatically scaled up and down according to the demands of the Workload. Since cost is incurred in proportion to the amount of Data actually Read/Written, it is recommended for Workloads where traffic is difficult to predict. It can be used only with the General Purpose Performance Mode.

## 4. Replication

AWS EFS supports Cross-region Replication, which is **asynchronous replication between Regions**. The moment Cross-region Replication is configured on the original EFS Server, a separate replica EFS Server is created, and the replica EFS Server operates in Read-only Mode. Afterwards, the moment the Cross-region Replication configuration between the original EFS Server and the replica is removed, the replica operates as a **completely independent** EFS Server with no association with the original and switches to Writable Mode.

After the Cross-region Replication configuration is removed, both the original EFS Server and the replica EFS Server can each create a separate replica through Cross-region Replication configuration. A Cross-region Replication configuration can perform Replication targeting only one replica at a time.

## 5. Backup

AWS EFS does not provide its own Backup feature; Backup is performed through integration with the **AWS Backup Service**. When the Backup frequency and retention period are defined in an AWS Backup Plan, Backups are performed automatically according to the Plan. When Automatic Backup is enabled at EFS creation time, a default Backup Plan that performs a Backup once a day and retains it for 35 days is applied automatically.

Backup operates in an Incremental manner: only the first Backup copies the entire Data of the EFS, and subsequent Backups copy only the Data changed since the previous Backup. In addition, since Backup execution does not consume Burst Credits and is not counted against the File operation limits of the General Purpose Performance Mode, it does not affect the performance of Apps using EFS even while a Backup is being performed. Restore can be performed for the entire EFS or for specific Files and Directories, and the restore target can be a separate Directory inside the original EFS or a new EFS.

## 6. References

* How Amazon EFS works : [https://docs.aws.amazon.com/efs/latest/ug/how-it-works.html](https://docs.aws.amazon.com/efs/latest/ug/how-it-works.html)
* Amazon EFS performance : [https://docs.aws.amazon.com/efs/latest/ug/performance.html](https://docs.aws.amazon.com/efs/latest/ug/performance.html)
* Backing up Amazon EFS file systems : [https://docs.aws.amazon.com/efs/latest/ug/awsbackup.html](https://docs.aws.amazon.com/efs/latest/ug/awsbackup.html)
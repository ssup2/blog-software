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

TODO

## 4. Replication

AWS EFS supports Cross-region Replication, which is **asynchronous replication between Regions**. The moment Cross-region Replication is configured on the original EFS Server, a separate replica EFS Server is created, and the replica EFS Server operates in Read-only Mode. Afterwards, the moment the Cross-region Replication configuration between the original EFS Server and the replica is removed, the replica operates as a **completely independent** EFS Server with no association with the original and switches to Writable Mode.

After the Cross-region Replication configuration is removed, both the original EFS Server and the replica EFS Server can each create a separate replica through Cross-region Replication configuration. A Cross-region Replication configuration can perform Replication targeting only one replica at a time.

## 5. Backup

TODO

## 6. References

* How Amazon EFS works : [https://docs.aws.amazon.com/efs/latest/ug/how-it-works.html](https://docs.aws.amazon.com/efs/latest/ug/how-it-works.html)
---
title: AWS SysOps Administrator Associate Certificate Exam Summary
---

## 1. Base

Organize missing content based on the following organized content

* [AWS Solutions Architecture Assosicate](../certificate-aws-solutions-architect-associate)

## 2. EC2

* Placement Group
  * Determines how to place EC2 instances
  * Cluster
    * Place all EC2 instances in one server rack in one AZ if possible
    * Low network latency between EC2 instances possible, but most disadvantageous in terms of availability
  * Spread
    * Distribute EC2 instances considering AZ and server
    * High availability possible, but high network latency occurs
    * Maximum 7 EC2 instances per AZ in one Placement Group, can create AZ count * 7 EC2 instances
  * Partition
    * Place in logical group units called Partition
    * Partition failure does not affect other partitions
    * 7 Partitions exist per AZ, maximum 100 EC2 instances per partition
  * Launch Exception
    * InstanceLimitExceeded
      * vCPU count exceeded in region
      * Can request increase through Service Quota
    * InsufficientInstanceCapacity
      * No available instances in AZ
      * AWS resource shortage issue
      * Can work around by selecting different instance type or different AZ
    * Instance Terminates Immediately
      * EBS volume limit reached, EBS snapshot conflict, EBS volume encrypted but no KMS access permission
  * Metric
    * without CloudWatch Agent
      * Collect metrics at 5-minute intervals, can change to 1-minute intervals but additional cost
      * Can collect CPU usage, Network I/O, Disk I/O, Instance status information
    * with CloudWatch Agent
      * Memory usage, Disk usage, Process status (procstat Plugin)
      * Can set collection interval (minimum interval 1 second)
  * Status Check
    * System Status Check
      * Checks AWS system problems (Hypervisor, System Power..)
      * Can recover by stopping -> starting instance when problem occurs (migrates EC2 instance to new Hypervisor)
        * Can configure automatic recovery through integration with CloudWatch Alarm
        * Can configure automatic recovery through Auto Scaling Group
    * Instance Status Check
      * Checks EC2 instance configuration problems or problems inside EC2 instance
      * Recover by changing related settings and restarting instance when problem occurs

## 3. AMI

* Can create AMI without rebooting EC2 instance with No Reboot Option
* Can create images through EC2 Image Builder
* Can force use of only AMIs with Production tag in production environment using AMI tags
  * Using IAM permissions and AWS Config

## 4. Systems Manager

* Performs management functions for EC2 instances and on-premise systems
* Problem detection
* Patch execution
* Runs on Windows and Linux
* Operates integrated with CloudWatch metrics and dashboards
* Performs integration with AWS Config
* Free to use
* Requires agent installation on EC2 instances
  * Pre-installed on Amazon Linux2 and Ubuntu
* EC2 instances must have a role assigned with permissions to perform SSM actions

### 4.1. SSM Resource Group

* Can create resource groups based on tags

### 4.2. SSM Document & Run Command

* JSON, YAML format
* Specify parameters
* Define actions
* Run Command
  * Execute documents or commands
  * Can execute on multiple EC2 instances (with Resource Group)
  * Integrated with IAM and CloudTrail
  * SSH not required
  * Results stored in CloudWatch and S3
  * Can send status through SNS
  * Can execute through EventBridge

### 4.3. SSM Automation

* Service that helps with common maintenance and deployment tasks
  * Ex) Restart Instance, Create AMI, EBS Snapshot
* Automation Runbook
  * Document for automation
  * Pre-defined or user can create directly

### 4.4. SSM Parameter Store

* Storage for storing config or secrets encrypted (with KMS)
* Serverless
* Supports versioning
* Integrated with CloudFormation
* Forms hierarchy in directory format
* Advanced Tier (paid)
  * Can specify parameter policies
  * Can specify Expiration, ExpirationNotification, NoChangeNotification

### 4.5. SSM Inventory

* Collects metadata from EC2 instances and on-premise systems
* Metadata
  * Software, OS Driver, OS Update, Running Services
* Can store in S3 and visualize through Athena Query + QuickSight
* Can set metadata collection cycle

### 4.6. SSM Stage Manager

* Provides automation by grouping various management actions for EC2 instances and on-premise systems
* Can set time for when to perform management actions

### 4.7. SSM Patch Manager

* Performs patches on EC2 instances and on-premise systems
* Patches executed on-demand or during maintenance windows
* Issues result report after patch execution
* Patch Baseline
  * Defines patches to execute and patches not to execute
  * Users can create custom patch baselines
  * Critical patches and security-related patches are set to install by default

### 4.8. SSM Session Manager

* Provides shell access to EC2 instances and on-premise systems
* Not SSH method, no Bastion Host required, no SSH key required
* Session logs can be stored in S3 and CloudWatch Logs
* StartSession event records remain in CloudTrail

## 5. Cloud Formation

* Template Components
  * Resources : Define AWS resources
  * Parameters : Define template parameters
  * Mapping : Static variables
  * Output : Template execution results
  * Conditions : Set resource creation conditions
  * MetaData
* Stack Policy
  * Limits resources that the stack can change
  * Default All Deny when stack policy is set
* Resource Import
  * Used when resources created externally (not through CloudFormation) need to be managed through CloudFormation
* Helper Script
  * cfn-init : 
  * cfn-signal : 
  * cfn-get-metadata :
  * cfn-hup :

## 6. References

* [https://www.udemy.com/course/ultimate-aws-certified-sysops-administrator-associate](https://www.udemy.com/course/ultimate-aws-certified-sysops-administrator-associate)


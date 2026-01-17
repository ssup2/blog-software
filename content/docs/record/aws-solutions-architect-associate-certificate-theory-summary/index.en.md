---
title: AWS Solutions Architect Associate Certificate Theory Summary
---

## 1. Region, Availability Zone

### 1.1. Region

* Unit containing multiple availability zones

### 1.1. Availability Zone

* Means one or more data centers
* Each availability zone is designed considering fault isolation
  * Even if a failure occurs in AZ-1, it does not affect AZ-2

## 2. IAM

* Authentication/authorization service

### 2.1. User

* Represents a user
* One user can belong to multiple groups

### 2.2. Group

* Represents a group of users
* Can only contain users, cannot contain other groups

### 2.3. Role

* Can be assigned to AWS services and users, AWS services and users that receive roles acquire the policy permissions that the role has
  * The action of assigning a role to a user is called Assume

### 2.4. Policy

* Allow/deny policy assigned to users, groups, and roles
* Composed in JSON format
* Recommends Least Privilege Principle
  * Allow only minimum permissions
* Can simulate policies through IAM Policy Simulator

### 2.5. Root User

* User with all permissions
  * Billing information
  * Personal data
  * AWS
* Recommends avoiding root user usage and creating a separate administrator account
  * Create IAM administrator account
  * Lock root user credentials
  * Use IAM administrator account
* Recommends root user to authenticate using MFA (Multi Factor Authentication)

## 3. EC2

* Compute service

### 3.1. Instance Type (Flavor)

* Instance Type Format
  * <FamilyName><GenerationNum>.<Size>
    * t3.large / c5.xlarge / p3.2xlarge
* Instance Type
  * General Purpose : Starts with t
  * Compute Optimized : Starts with c
  * Memory Optimized : Starts with r, x, z
  * Storage Optimized : Starts with i, d, h
* Can scale up/down flavor
* Higher generation provides better cost-performance

### 3.2. User Data

* Script that runs only once when EC2 instance first boots
* Runs as root user

### 3.3. Security Group

* L4 firewall that exists in front of EC2 instances
* Can include multiple EC2 instances in one security group
* Can set inbound and outbound rules separately
* Can set traffic allow/deny in rules based on protocol, destination IP, destination port, and security group
* Default policy
  * Inbound : Deny all
  * Outbound : Allow all

### 3.4. Spot Instance

* Temporarily running instance
  * Current Spot Price changes in real-time based on available EC2 instances in AWS
  * Max Spot Price is set by user
  * Runs only when "Max Spot Price > Current Spot Price"
  * When "Max Spot Price < Current Spot Price" occurs, running instance becomes Stop or Terminate state
  * Spot Block type exists that can prevent Stop and Terminate states for a specific time (1 ~ 6 hours)
* Up to 90% cost savings compared to on-demand instances
* Suitable for processing batch jobs
* Spot Request Type
  * one-time : Runs spot instance and then does not intervene
  * persistent : Runs spot instance and continues to check if spot instance is working properly, recreates spot instance if not working
    * If persistent type, need to remove spot request first then remove persistent type
* Spot Fleets
  * Creates multiple spot instances based on instance type, OS, and AZ desired by user
    * Spot instance can only specify single AZ and single flavor
  * Spot Instance + On-Demand Instance (Optional)

### 3.5. Elastic IP

* Public IP that can be attached and detached from EC2 instances
* Elastic IP does not change unless removed
* Can use up to 5 per account by default
  * Can use more than 5 with quota increase
* Elastic IP usage not recommended
  * Recommends using random public IP + DNS name

### 3.6. Placement Group

* Placement strategy for EC2 instances
* Cluster : Placed in one rack (partition) within one availability zone for low latency
* Spread : Distributed across multiple availability zones to ensure availability (high availability)
* Partition : Distributed across multiple racks (partitions) in one availability zone

### 3.7. ENI (Elastic Network Interface)

* Represents one virtual network card in VPC
* Has one primary private IPv4 and multiple secondary IPv4s
* Can have one elastic IP per private IPv4
* Can have one public IP
* Can be included in one or more security groups
* Has one MAC address
* Can move between EC2 instances within the same availability zone without changing attributes. Useful feature for failover.

### 3.8. Hibernate

* When EC2 instance enters Stop state using Hibernate, saves EC2 instance memory contents to root EBS volume and terminates
* When EC2 instance becomes Running state later, can quickly recover to operation state before Stop state based on EC2 instance memory contents saved in root EBS volume
* Since EC2 instance memory contents are stored in root EBS volume, EC2 instance's root EBS volume must be encrypted

### 3.9. Nitro

* New virtualization technology
* Provides faster network and EBS volume performance

### 3.10. Metadata

* Can check EC2 instance meta information by accessing "http://169.254.169.254/latest" from inside EC2 instance
* Can check the following information
  * Instance-IP
  * Local-IPv4
  * IAM
  * ETC...

## 4. EC2 Instance Storage

* EC2 instance storage

### 4.1. EBS (Elastic Volume Service)

* Network-based volume storage
* One EBS volume can only be attached to one EC2 instance at a time
  * Exceptionally, io1 and io2 volumes can be attached to multiple EC2 instances simultaneously (Multi Attach)
* EBS volumes are tied to AZ and can only be attached to EC2 instances located in the same AZ

#### 4.1.1. EBS Snapshot

* Saves specific state of EBS
* EBS can be restored to created snapshot state
* Snapshot operation is possible even without detaching but not recommended
* Can create AMI based on EBS snapshot
  * Cannot create EC2 instance with EBS snapshot state, must create AMI based on EC2 snapshot and create EC2 instance using created AMI

#### 4.1.2. EBS Volume Type

* gp2, gp3 : General Purpose SSD, can be used as boot volume
* io1, io2 : Highest-performance SSD, can be used as boot volume, supports multi attach
* st : Low cost HDD
* sc : Lowest cost HDD

#### 4.1.3. EBS Encryption

* Can set encryption when creating EBS
* Automatically encrypts and decrypts when encryption is set
* Encryption overhead is low

### 4.2. AMI (Amazon Machine Image)

* Booting image for EC2 instances
* EC2 instance snapshot
* Create AMI through AMI creation functionality after configuring EC2 instance to desired state
  * Can also create snapshot while creating AMI
* Can include multiple EBS volumes in one AMI

### 4.3. EC2 Instance Store

* Physical disk-based volume storage
* Has faster performance than EBS but data can be lost at any time
* Used for cases where fast but temporary data storage is needed like cache
* Data is not lost in the following cases
  * EC2 instance reboot
* Data is lost in the following cases
  * When EC2 instance stops, terminates, or hibernates
  * When physical disk fails

### 4.4. EFS

* NFS server
* Uses NFSv4.1 protocol
* File system size automatically increases, cost based on usage
* Only available on Linux
* Can set Multi AZ or Single AZ

#### 4.4.1. EFS Storage Class

* Storage Tiers
  * Standard : Standard
  * Infrequent Access : Low cost for data storage but cost occurs when using stored data

## 5. ELB (Elastic Load Balancer)

* Load distribution
* Ensures high availability during failures (EC2 instance, AZ, network)
* Provides single endpoint for user apps
* Provides SSL termination
* Provides sticky session
* Managed load balancer
  * AWS ensures operation (upgrade, maintenance, HA guaranteed)
  * Provides some configuration options

### 5.1. CLB (Classic Load Balancer)

* Deprecated
* L4, L7 load balancer
  * Supports TCP + TCP health check, HTTP, HTTPS + HTTP health check
* Cross-Zone Load Balancing
  * Default disabled, can enable through settings
  * No additional cost
* Does not support SSL

### 5.2. ALB (Application Load Balancer)

* L7 load balancer
  * Supports HTTP/1.1, HTTP/2, WebSocket
  * Less latency : 400ms
* Supports redirect
* Routing policies
  * Based on path in URL
  * Based on hostname in URL
  * Based on query string and header
* ALB Target Group Types
  * EC2 Instance
  * ECS Task
  * Lambda Function
* Has fixed hostname
  * XXX.region.elb.amazonaws.com
* Cross-Zone Load Balancing
  * Always enabled and cannot be disabled
  * No additional cost
* App server cannot know client IP through packet source IP because source IP of packet received by app server is ALB IP
  * Delivers client IP to app server through X-Forwarded-For header
  * Delivers client port to app server through X-Forwarded-Port header
  * Delivers client protocol to app server through X-Forwarded-Proto header

### 5.3. NLB (Network Load Balancer)

* L4 load balancer
  * Supports TCP, UDP
  * Less latency : 100ms
* NLB Target Groups
  * EC2 Instance
  * Private IP Address
  * ALB
* Cross-Zone Load Balancing
  * Default disabled, can enable through settings
  * Additional cost occurs

### 5.4. GWLB (Gateway Load Balancer)

* L3 load balancer
* Performs role of intercepting packets before delivering to app server and sending to third-party network virtual appliances that perform actions like firewall and intrusion detection
* GWLB Target Group
  * EC2 Instance
  * Private IP Address

### 5.5. Sticky Session (Session Affinity)

* Technique to make the same client always connect to the same app server behind LB
  * Available in CLB and ALB
  * CLB and ALB decide which app to deliver packets to using cookie information
* Cookie Types
  * Application-based Cookie
    * Custom Cookie
      * TODO
    * Application Cookie
      * Uses cookie name AWSALBAPP
  * Duration-based Cookie
    * TODO

### 5.6. SSL

* Supports SSL termination
* Supports SNI (Server Name Indication)
  * Only available in ALB and NLB, not provided in CLB
* Certificates are managed in ACM (AWS Certificate Manager)

### 5.7. Connection Draining

* Called Connection Draining in CLB, Deregistration Delay in ALB/NLB
* Targets (EC2 instances) in DRAINING state maintain existing TCP connections but new TCP connections are not created
* Connection Draining functionality is disabled when draining timeout is set to 0 seconds

### 5.8. ASG (Auto Scaling Group)

* Can scale out and scale in
  * Can set EC2 instance count from three perspectives: Minimum, Desired, Maximum
  * Performs auto scale-out and scale-in based on CloudWatch metric information
* Automatically recovers when EC2 instance fails

#### 5.8.1. ASG Launch Template

* Provides template to easily create ASG
* Launch template includes the following information
  * AMI + Instance Type
  * EC2 User Data, EBS Volume
  * Security Group
  * SSH Key Pair
  * IAM Roles for EC2 Instance
  * Network + Subnet Info
  * Load Balancer Info

#### 5.8.2. Auto Scaling Policy

* Target Tracking Scaling
  * Performs scaling to maintain the following metrics of ASG group
    * Average CPU usage of ASG group
    * Average inbound traffic of ASG group (all EC2 network interfaces)
    * Average outbound traffic of ASG group (all EC2 network interfaces)
    * Average requests per second of ASG group

* Simple Scaling
  * Policy based on CloudWatch alarm
  * Adds or removes EC2 instances when metric reaches specific value
  * Ex) Add 5 EC2 instances when ASG group average CPU usage is 70% or higher, decrease 5 when below 40%

* Step Scaling
  * Policy based on CloudWatch alarm
  * Adds or removes EC2 instances based on metric ranges
  * Ex) Add 10 EC2 instances when ASG group average CPU usage is 70% or higher, add 5 when 60% or higher, decrease 5 when below 40%, decrease 10 when below 30%

* Predictive Scaling
  * Performs scaling by predicting based on the following past metrics
    * Average CPU usage of ASG group
    * Average inbound traffic of ASG group
    * Average outbound traffic of ASG group
    * Average requests per second of ASG group
    * Prediction based on custom metrics

* Scheduled Action
  * Performs scaling based on time periods

#### 5.8.3. Scaling Cooldown

* Wait time before performing next scaling after performing scaling
* Does not increase or decrease EC2 instances during cooldown period

## 6. RDS

* Managed RDB
  * Provides automatic provisioning and OS patches
  * Provides continuous backup and restore
  * Provides monitoring dashboards
  * Can easily configure read replicas
  * Can easily configure multi-AZ
  * Can easily scale
* Can use the following RDBs
  * Postgres
  * MySQL
  * MariaDB
  * Oracle
  * Microsoft SQL Server
  * Aurora

### 6.1. Storage Auto Scaling

* Automatically increases storage size when RDS storage is insufficient
* Must set maximum storage size through maximum storage threshold setting
* Performs storage auto scaling when the following conditions are met
  * When remaining storage capacity is less than 10% and persists for 5 minutes or more
  * 6 hours after last scale-up

### 6.2. Read Replica

* Read-only RDS instance
* Performs asynchronous replication with master RDS instance
* Can configure with master RDS instance in same AZ, cross-AZ, or cross-region
  * No network cost for same AZ or cross-AZ configuration
  * Network cost occurs for cross-region configuration
* Read replica RDS instance can be promoted to master RDS instance
  * Can be used as RDS instance for failure recovery
  * Data loss possible because asynchronous replication is performed

### 6.3. Multi-AZ

* Creates standby RDS instance in different AZ for failure recovery
* Performs synchronous replication between standby RDS instance and master RDS instance
  * No data loss because synchronous replication is performed
* Master RDS instance and standby RDS instance use the same DNS record
  * DNS record IP changes to standby RDS instance when master RDS instance fails
  * No need to reconfigure application DB
* Multi-AZ configuration is possible dynamically
  * Master RDS instance does not need to be down when configuring multi-AZ
  * Standby RDS instance is created based on snapshot then performs data synchronization with master RDS instance

### 6.4. Encryption

* Master RDS instance and read replica RDS instance can be encrypted with AWS KMS-based AES-256 encryption
* Read replica RDS instance is not encrypted if master RDS instance is not encrypted
* Snapshots are also encrypted only if master RDS instance performs encryption
* Unencrypted snapshots can be encrypted
* Method to encrypt unencrypted RDS instance
  * Create snapshot
  * Encrypt created snapshot
  * Create RDS instance based on encrypted snapshot
  * Configure app to use newly created RDS instance & delete existing RDS instance
* Encryption between client and RDS instance is performed using SSL

### 6.5. Network & Access Management

* Generally assigned to private subnet
  * Improve security using security groups
* Can use existing IP/password-based authentication
* Can use IAM-based authentication
  * Access RDS instance after obtaining token through RDS service

### 6.6. Aurora

* AWS cloud-optimized RDS
* Compatible with MySQL and PostgreSQL
* Storage size starts at 10GB and automatically increases up to 128TB
* Can have one master instance + up to 15 read replica instances
  * Only master can perform read/write
  * Read replicas auto-scale based on load
  * Read replicas support cross-region
* Fast failover (less than 30 seconds)
* Charges about 20% more than regular RDS

### 6.6.1. Storage HA

* Composed of 6 replicas across 3 AZs
  * Requires 4 replicas to perform writes
  * Requires 3 replicas to perform reads
  * Replicates data through self-healing during failures

### 6.6.2. Endpoint

* Writer Endpoint
  * DNS record pointing to master instance
* Reader Endpoint
  * DNS record pointing to read replica instances
  * Automatically adds/removes from read endpoint when read replica auto-scales
* Custom Endpoint
  * DNS record pointing to some read replica instances through user configuration
  * Used when using only high-performance read replica instances for data analysis

### 6.6.3. Serverless

* Clients access Aurora instance through proxy server (proxy fleet)
* Automatically initializes Aurora instance and performs auto-scaling as needed
* Advantageous for intermittent DB usage
  * Charges based on usage time per second

### 6.6.4. Multi-Master

* Multiple master instances exist and all master nodes perform read/write operations
* Can continue write operations through running master instances even if some master instances fail
* Client selects which instance to perform write operations among multiple master instances
  * Aurora does not provide master instance load balancing functionality

### 6.6.5. Global Aurora

* Cross-region read replica for disaster recovery
* Primary region (read/write) and secondary region (read-only) exist
  * Primary region and secondary region replicate asynchronously with replication time up to 1 second
  * Can configure up to 5 secondary regions
  * Secondary region can be promoted to primary region when primary region fails

### 6.6.6. Aurora Machine Learning

* Can obtain ML-based prediction information through SQL queries by integrating with AWS ML services
  * Ex) Intrusion detection, advertisement targeting, product recommendation

## 7. ElasticCache

* Managed Redis and Memcached
* Does not provide AWS IAM-based authentication functionality

### 7.1. Redis

* Supports auto-failover using multi-AZ
* Provides read scaling and HA using read replicas
* Provides data persistence using AOF (Append Only File)
* Provides backup & restore functionality
* Single-thread architecture
* Has various data types
* Uses ID/password-based authentication

### 7.2. Memcached

* Does not provide HA
* Does not provide data persistence
* Does not provide backup & restore functionality
* Multi-thread architecture
* Provides single string data type
* SASL-based authentication

### 7.3. ElasticCache Pattern

* Lazy Loading
  * Stores read data in cache
  * Data stored in cache may be invalid
* Write Through
  * Also stores in cache when storing data
  * Data stored in cache is valid
* Session Store
  * Stores session information
  * Utilizes TTL functionality

## 8. Route 53

* Managed DNS

### 8.1. Hosted Zones

* Public Hosted Zone : Public network
* Private Hosted Zone : VPC private network

### 8.2. CNAME vs Alias

* CNAME
  * Can specify non-root domain
    * Ex) ssup2.com (root domain) not possible
  * Cannot specify root domain
    * Ex) blog.ssup2.com (non-root domain) possible
* Alias
  * AWS internal protocol not provided in DNS protocol
  * Responds with A or AAAA record in query response for DNS clients
  * Can specify both non-root and root domains
  * Can only be set for some AWS resources
* Supported Alias Targets
  * Elastic Load Balancer
  * CloudFront Distributions
  * API Gateway
  * Elastic Beanstalk environments
  * S3 Websites
  * VPC Interface Endpoints
  * Global Accelerator
  * Route 53 record in the same hosted zone
* Not Supported Alias Targets
  * EC2 DNS record
  * RDS DNS record

### 8.3. Routing Policy

* Simple
  * Returns all IP addresses mapped in DNS record
  * Cannot use health check
* Weighted
  * Assigns weights to each IP address mapped in DNS record and determines ratio of returned IP addresses based on weight ratio
  * Can use health check
* Latency Based
  * Returns IP address with least latency based on client location
  * Can use health check
* Failover
  * Active-passive based policy
  * Returns IP address designated as primary if health check works, returns IP address designated as secondary if health check fails
* Geolocation
  * Returns configured IP address based on client location
  * Returns default IP address if client location is not in configured locations
  * Can use health check
* Geoproximity
  * Can configure to return specific IP address more biasedly based on client location and bias value
  * Higher bias value IP addresses have higher probability of being used by clients farther away
* Multi-Value Answer
  * Returns all IP addresses that respond through health check
  * Returns maximum 8 IP addresses only

### 8.4. Health Check

* Supports L4 and L7 health checks
* Health Check Target
  * Endpoint : Performs health check on app endpoint
  * Other Health Check (Calculated Health Check) : Determines health check result by logically combining (AND, OR, NOT) health check results of multiple other endpoints
  * CloudWatch : Route53 cannot perform health check on endpoints inside private VPC because Route53 exists in public network. In this case, configure CloudWatch monitoring endpoints inside private VPC, and Route53 performs health check on this CloudWatch

## 9. S3

* Unlimited capacity object storage
* Provides strong consistency
* Can allow specific origins or set all origins

### 9.1. Bucket

* Acts as top-level directory of S3
  * Cannot configure bucket under bucket
* Uses globally unique name
* Bucket is created in specific region (S3 is not a global service)
* Naming Convention
  * Only lowercase allowed
  * Cannot use _ (underscore)
  * 3~63 characters
  * Cannot use IP
  * Can only start with lowercase and numbers

### 9.2. Object

* Acts as file in S3
* Has one key and acts as full path
  * s3://<bucket-name>/<object-key>
  * Ex) s3://ssup2-bucket/root-folder/sub-folder/file.txt
    * ssup2-bucket : Bucket name
    * root-folder/sub-folder/file.txt : Object key
* One object is maximum 5TB
  * Can split and upload one file using multi-part upload functionality if file is 5TB or larger
* Metadata
  * Key-value based
  * Stores system or user meta information
* Tag
  * Key-value based
  * Can set up to 10
  * Mainly used for IAM-based authorization settings
* Version ID
  * Each object has version ID when bucket's versioning functionality is enabled

### 9.3. Versioning

* Can enable/disable per bucket
* Can recover from unexpected deletion and rollback to previous version
* Objects without version are marked as null version when versioning changes from disabled -> enabled

### 9.4. Encryption

* Encryption methods
  * SSE-S3 : Uses encryption key managed by AWS S3 service
    * Server-side encryption
    * AES-256 encryption
    * Set "x-amz-server-side-encryption":"AES256" in HTTP request header
  * SSE-KMS : Uses encryption key managed by AWS KMS service
    * Server-side encryption
    * Set "x-amz-server-side-encryption":"aws:kms" in HTTP request header
  * SSE-C : Uses own encryption key
    * AWS does not manage encryption key
    * Uses HTTPS
    * Sets encryption key in all HTTP headers and sends
  * Client-side encryption
    * Performs encryption directly in client before sending data
    * Performs decryption directly in client before receiving data
* Encryption in transit
  * Uses SSL/TLS through HTTPS
  * Can send without encryption through HTTP but recommends using HTTPS

### 9.5. Security

* User Base
  * Set using IAM policy
* Resource Base
  * Commonly applied to multiple accounts
  * Object Access Control List : Sets permissions per object
  * Bucket Access Control List : Sets permissions per bucket
* Must satisfy the following conditions to access S3 objects
  * (User IAM Role Allow OR Resource Policy Allow) AND explicit deny
* Provides endpoint within VPC
* S3 access logs can be stored in different S3 bucket
  * Because logging loop occurs if S3 access log is set to itself instead of different S3 bucket
  * Stored access logs can be analyzed through AWS Athena
* Uses S3 as log storage for AWS CloudTrail
* MFA Delete : Can force MFA usage when removing objects
* Pre-Signed URL : Generates URL valid for a certain time

### 9.6. Websites

* Provides static webserver functionality
* URL
  * <bucket-name>.s3-website-<AWS-region>.amazonaws.com
  * <bucket-name>.s3-website.<AWS-region>.amazonaws.com
* Error
  * Need to check permissions when 403 error occurs

### 9.7. Replication

* Provides replication functionality between regions
  * Performs asynchronous replication
  * CRR (Cross Region Replication)
  * SRR (Same Region Replication)
* Source S3 bucket must have versioning functionality enabled
* Must set IAM permissions for S3
* Only replicates newly created objects after replication is configured
  * Existing objects can be replicated through S3 batch replication
* Delete Action
  * Can configure whether to delete replica object when source object is deleted
  * Does not replicate when specific version of source object is deleted
* Cannot configure replication chain

### 9.8. Pre-signed URL

* Can generate temporary URL that allows temporary download and upload
  * Download : Can generate through CLI and SDK
  * Upload : Can only generate through SDK
* Has 3600 seconds validity by default, can set validity time when generating pre-signed URL

### 9.9. Storage Class

* Has different price, performance, and availability based on storage class
* All storage classes guarantee 99.999999999% durability
* Can set per object

#### 9.10.1. General Purpose

* Used when frequently accessing
* Guarantees 99.99% availability
* Low latency, high throughput
* Usage Example : Big data analysis, content distribution

#### 9.10.2. Infrequent Access

* Used when accessing infrequently but fast access is needed
* Lower cost than standard class
* Standard Infrequent Access Class (Standard-IA)
  * 99.9% availability
  * Usage Example : Disaster recovery, backup
* One Zone Infrequent Access Class (S3 One Zone-IA)
  * 95.9% availability
  * Data loss occurs when AZ is lost because it stores in single AZ
  * Usage Example : Temporary backup, reproducible data backup

#### 9.10.3. Glacier Storage Class

* Low-cost storage for archiving and backup
* Low object storage cost but cost occurs when retrieving objects

#### 9.10.4. Glacier Instant Retrieval Class

* Millisecond-level retrieval speed
* Minimum 90-day storage cost is charged

#### 9.10.5. Glacier Flexible Retrieval Class

* Takes long time for data retrieval, retrieval time varies based on the following settings
  * Expedited : 1~5 minutes, cost occurs
  * Standard : 3~5 hours, cost occurs
  * Bulk : 5~12 hours, free
* Minimum 90-day storage cost is charged

#### 9.10.6. Glacier Deep Archive

* Takes longest time for data retrieval, retrieval time varies based on the following settings
  * Standard : 12 hours
  * Bulk : 48 hours
* Minimum 180-day storage cost is charged

#### 9.10.7. Intelligent-Tiering

* Automatically changes tier based on object usage
* Free when tier changes
* The following tiers exist
  * Frequent Access Tier : Default tier, automatically set
  * Infrequent Access Tier : Automatically set when object is not accessed for 30 days
  * Archive Instant Access Tier : Automatically set when object is not accessed for 90 days
  * Archive Access Tier : Optional when not accessed for 90 to 700 days or more
  * Deep Archive Access Tier : Optional when not accessed for 180 to 700 days or more

#### 9.10.8. Storage Class Movement

* Transition Action : Automatically changes storage class based on time elapsed since object creation
* Expiration Action : Automatically deletes object after time elapsed since object creation
* Action Target : Actions can be set based on object tags or object path prefix (s3://mybucket/music/*)
* Can analyze when to change from standard class to standard IA class through S3 analytics functionality

### 9.11. Performance

* Performs automatic scaling within S3 to guarantee 100~200ms delay
* Provides 3500 PUT/COPY/POST/DELETE, 5500 GET/HEAD requests per second per prefix
  * No prefix limit within one bucket
  * Can increase performance by configuring to use multiple prefixes
* When performing encryption using SSE-KMS, S3 is also affected by SSE-KMS performance
  * Performance limits of 5500, 10000, 30000 requests per second exist depending on region
* Can upload to S3 faster through dedicated line of edge location
* Byte-Range Fetch
  * Can download only specific areas of object
  * Can increase download performance by performing byte-range fetch simultaneously on different areas
  * Can search only certain parts of object

### 9.12. Event

* Can generate and propagate S3 actions as events
* Can propagate to the following services
  * SNS, SQS, Lambda Function, Event Bridge

### 9.13. Athena

* Serverless query service for S3 objects
* Pays $5 per TB scanned
  * Can reduce scan cost by compressing objects or storing object data in column format

### 9.14. Glacier Vault Lock

* Implements WORM (Write Once Read Many)
* Can set lock after object creation
* For compliance fulfillment

## 10. CloudFront

* CDN service
* Can prevent DDoS attacks together with Shield service and WAF

### 10.1. Origin

* Can use the following origins
* S3
  * Performs S3 object caching
  * Can also be used as S3 upload path
  * Accesses S3 objects using OAI (Origin Access ID)
* Custom Origin : Can be used as origin if using HTTP protocol
  * ALB, EC2 Instance, S3 Website, HTTP Backend API
* Provides origin group functionality
  * Can configure to use secondary origin when primary origin is not working

### 10.2. Geo Restriction

  * Whitelist of countries that can access content and blacklist of countries that cannot access content exist
  * Country criteria are determined based on 3rd party Geo-IP database

### 10.3. Pricing

* Price varies by edge location
* Price Class
  * Can reduce cost by reducing number of edge locations performing caching
  * Class ALL : Uses all edge locations, highest cost
  * Class 200 : Includes all regions except the most expensive region
  * Class 100 : Includes only the cheapest region

### 10.4. Global Accelerator

* Quickly accesses other AWS regions through dedicated network of edge locations

## 11. Storage

### 11.1. AWS Snow Family

* Performs data migration and edge computing using portable devices
* Composed of the following equipment based on capacity functionality
  * Snowcone : Supports data migration and edge computing
  * Snowball : Supports data migration and edge computing
  * Snowmobile : Supports data migration
* Can easily manage equipment by installing OpsHub on laptop
* Must first store data in S3 then convert to Glacier to proceed with data migration to Glacier

### 11.2. FSx

* Service to provide 3rd party high-performance filesystems
  * for Windows File Server
  * for NetApp ONTAP

### 11.3. Storage Gateway

* Acts as bridge to help access S3 in on-premise environment
* Acts as bridge connecting on-premise files, volumes, and tapes with AWS EBS, S3, and Glacier
* Storage Gateway Type
  * VM-based : VMware, Hyper-V, Linux KVM, EC2
  * Hardware-based : Can lease dedicated hardware
* File Gateway
  * Can access S3 Standard, S3 Standard-IA, Glacier in on-premise environment through NFS and SMB protocols
* Volume Gateway
  * Can access S3 in on-premise environment through iSCSI
  * Provides 2 types of volumes
    * Cached Volume : Places only frequently accessed data in volume gateway and stores infrequently used data in S3
    * Stored Volume : Places all data in volume gateway and performs backup by periodically creating EBS snapshots
* Tape Gateway
  * Can access S3 and Glacier through iSCSI

### 11.4. Transfer Family

* Can use S3 and EFS through FTP protocol
* Supported protocols : FTP, FTPS, SFTP
* Managed service
* Charges based on number of endpoints + data transfer amount
* Supported authentication methods : Microsoft Active Directory, LDAP, Okta, Cognito
* Configured as User -> Route 53 -> Transfer Family --(IAM Role)--> S3, EFS

## 12. Messaging

### 12.1. SQS

* Queue service
* Unlimited throughput
* Low latency (< 10ms)
* Messages are stored for 4 days by default and can be retained up to 14 days through settings
* Maximum 256KB limit per message
* Guarantees At Least Once QoS
* Message order can change
* Supports delay functionality

#### 12.1.1. Consumer

* Checks message existence through polling (not event-based)
  * Short Polling
    * WaitTimeSeconds = 0 or ReceiveMessageWaitTimeSeconds = 0
    * Checks only some queues and returns empty message even if message does not exist
    * May not be immediately delivered to client even if message exists in queue because only some queues are checked
  * Long Polling
    * WaitTimeSeconds > 0 or ReceiveMessageWaitTimeSeconds > 0
    * Checks all queues and returns when at least one message exists, when max message count is reached, or when set timeout is reached
    * Can reduce cost by reducing number of receive message requests
* Can receive up to 10 messages at once
* Must delete message through DeleteMessage API after receiving message and performing action (ACK)
* Can configure consumer autoscaling by configuring CloudWatch Metric Queue Length -> CloudWatch Alarm -> ASG Scaling

#### 12.1.2. Security

* Encryption
  * In-flight encryption : Uses HTTPS
  * At-rest encryption : Uses KMS key
  * Client can perform encryption/decryption itself
* Access Control
  * IAM policy control
  * Provides SQS access policy : Useful when utilizing cross-account access

#### 12.1.3. Message Visibility Timeout

* Other consumers cannot check the message during message visibility timeout time even if specific consumer receives message and does not delete it
* Other consumers can check and process messages after message visibility timeout time passes
  * Can be considered as message being requeued to queue
  * If consumer that first received message does not process and delete message within message visibility timeout, other consumers can process message multiple times
* Default 30 seconds

#### 12.1.4. Dead Letter Queue

* Message is sent to dead letter queue when number of requeues due to message visibility timeout exceeds MaximumReceives
* Used for debugging and failure handling
* Redrive : Functionality to send messages stored in dead letter queue back to original queue

#### 12.1.5. FIFO Queue

* Guarantees message order
* Supports Exactly-Once QoS
* Performance limit of 300 msg/s receive, 3000 msg/s send
* Lower performance than regular queue but used when wanting to maintain message order and use Exactly-Once QoS

### 12.2. SNS

* Pub-sub service
* Only producer can send messages
* Can subscribe up to 12,500,000 per topic
* Possible Subscribers
  * SQS, Lambda, Kinesis Data, Firehose, Emails, SMS, Mobile Notification, HTTP Endpoints
* Can send messages to only some subscribers using filter functionality

#### 12.1. FIFO Topic

* Topic that guarantees order
* Performs ordering using group ID
* Performs deduplication using deduplication ID
* Can only subscribe SQS topics

### 12.3. Kinesis

* Real-time streaming data collect, process, and analyze service
  * Application logs, metrics, IoT telemetry
* Kinesis Data Stream : Composes data stream
* Kinesis Data Firehose : Stores data stream in data store
* Kinesis Data Analytics : Analyzes data stream using SQL and Apache Flink
* Kinesis Video Streams : Composes video stream

#### 12.3.1. Kinesis Data Stream

* Shard
  * Can increase performance through parallel processing based on shard count
  * One shard can receive 1MB/sec or 1000 msg/sec
  * One shard can send 2MB/sec
* Record
  * Input : Partition Key, Data Blob (maximum 1MB)
  * Output : Composed of Partition Key, Sequence Number, Data Blob
* Data retention period can be set from 1 day to 365 days
* Can reprocess data
* Cannot remove data once it enters Kinesis
* Data with the same partition key is sent to the same shard (ordering)
* Capacity Mode
  * Provisioned Mode
    * Can manually set number of shards
    * Charges based on number of shards and time shards are provisioned
  * On-demand Mode
    * No need to set capacity
    * Performs auto-scaling based on 30 days of usage
    * Charges based on stream count, time stream is used, and data send/receive amount

#### 12.3.2. Kinesis Data Firehose

* Managed service
* Near real time
  * Minimum 60 second delay
  * Sends minimum 32MB at once
* Store Target
  * AWS : Redshift, S3, ElasticSearch
  * 3rd Party : Splunk, MongoDB, DataDog, NewRelic
  * Can create custom HTTP endpoint
* Supports various data formats, conversion, transformation, and compression
* Can perform custom transformation using Lambda

## 13. Container

### 13.1. ECS

#### 13.1.1. ECS Launch Type

* EC2 Launch Type
  * Method where containers run on EC2 instances
  * Requires EC2 instance provisioning and maintenance
  * ECS agent runs internally in EC2 instance
  * IAM Role
    * EC2 Instance Profile : Role used by ECS agent, allows ECS service API calls/sending container logs to CloudWatch/allowing Docker image pull from ECR
    * ECS Task Role : Role for ECS tasks, can assign separate role per task
* Fargate Launch Type
  * No need for infra provisioning (serverless)
  * Runs using Fargate for CPU/memory needed by task

#### 13.1.2. Load Balancer

* ALB : Can be applied to most services using L7 protocol
* NLB : Used for high throughput, used to integrate with AWS Private Link
* CLB : Not recommended, cannot integrate with Fargate

#### 13.1.3. Volumes

* Generally recommends using EFS
  * Supports multiple AZs
  * Serverless characteristics
* Does not support FSx for Lustre

#### 13.1.4. Auto Scaling

* Service Auto Scaling
  * Functionality to automatically scale ECS tasks based on load
* EC2 Auto Scaling
  * Functionality to automatically scale EC2 instances based on ECS task load
  * ASG method : Performs scaling using auto scaling group
  * Cluster Capacity Provider method : Performs scaling out of new EC2 instance when there are no available resources to create ECS tasks on EC2 instance

#### 13.1.5. Rolling Update

* Can set minimum health percent and maximum percent separately
* Ex) Min 50%, Max 100% : If 4 tasks are running, remove 2 old versions, create 2 new versions, remove 2 old versions, create 2 new versions
* Ex) Min 100%, Max 150% : If 4 tasks are running, create 2 new versions, remove 2 old versions, create 2 new versions, remove 2 old versions

### 13.2. ECR (Elastic Container Registry)

* Container image storage
* Private and public repository : https://gallery.ecr.aws/
* Uses S3 as backend storage

## 14. Serverless

### 14.1. Lambda

* Virtual function : No need to manage servers
* Execution time limit : Can only perform short executions
* Can execute only when needed and charges based on execution time
* Supports autoscaling
* Supports integration with various AWS services
* Supports monitoring through CloudWatch
* Can allocate up to 10GB memory
  * CPU and network performance also increases as more memory size is allocated
* Supports the following languages
  * Node.js, Python, Java, C#, Golang, C#, Ruby, Custom API (Community Supported)
* Supports container images
  * Can run container image in Lambda if container image supports Lambda runtime API

##### 14.1.1. Lambda Integration

* Supports integration with various AWS services
* API Gateway : Calls Lambda as upstream
* Kinesis : Transforms data using Lambda
* DynamoDB : Calls Lambda when event occurs in DynamoDB
* S3 : Calls Lambda when event occurs in S3
* CloudFront : Lambda Edge
* EventBridge : Calls Lambda when event occurs in EventBridge
* CloudWatch : TODO
* SNS : Calls Lambda when event is sent in SNS
* SQS : Calls Lambda when message is sent in SQS
* Cognito : Calls Lambda when event occurs in Cognito

#### 14.1.2. Lambda Limit

* Execution
  * Memory : 128MB ~ 10GB
  * Maximum execution time : 15 minutes
  * Maximum env : 4KB
  * Disk capacity : tmp DIR : 512MB
  * Concurrency executions : 1000
* Deployment
  * Compressed deployment size (.zip): 50MB
  * Uncompressed deployment size : 250MB

#### 14.1.3. Lambda Edge

* Executes Lambda at edge location
* Can be used when developing applications requiring fast response
* Can customize CDN contents

### 14.2. DynamoDB

* Managed NoSQL database
* Provides multiple AZs
* Processes over 10,000 requests per second, 100TB storage space
* Provides authentication and authorization using IAM
* Can perform event-driven programming using DynamoDB streams
* Provides low-cost & auto-scaling functionality
* Provides standard and IA (infrequent access) table classes

#### 14.2.1. Table, Item, Attribute

* DynamoDB is composed of tables
* Table has one primary key
* Table can have infinite items
* Each item (row) can have attributes (columns)
  * Attributes can be continuously added dynamically
* Item size is maximum 400KB
* Data Type
  * Scalar : String, Number, Binary, Boolean, Null
  * Document : List, Map
  * Set : String Set, Number Set, Binary Set
* Table
  * Partition Key : TODO
  * Sort Key : TODO
* Provides TTL (Time To Live) functionality
* Index
  * Need to create index to query attributes other than partition key and sort key
  * GSI (Global Secondary Index), LSI (Local Secondary Indexes)
* Transaction
  * Can process multiple data change operations as one transaction

#### 14.2.2. Capacity Mode

* Provisioned Mode
  * Default mode
  * Specifies read/write count per second
  * Charges based on RCU (Read Capacity Units) and WCU (Write Capacity Units)
  * Can perform auto-scaling on RCU & WCU
  * Suitable for predictable workloads

* On-Demand Mode
  * Automatically performs scale up/down for read/write
  * No need to predict capacity
  * 2~3 times more expensive than provisioned mode
  * Suitable for unpredictable workloads

#### 14.2.3. DynamoDB Accelerator (DAX)

* Memory cache service for DynamoDB
* Supports microsecond latency
* Can be applied without modifying app logic
* Default 5-minute TTL
* vs ElasticCache
  * DAX : Object-level caching, query & scan caching
  * ElasticCache : Stores aggregation results

#### 14.2.4. DynamoDB Streams

* Can receive item-level changes (create/update/delete) as stream
* Stream Target
  * Kinesis Data Streams
  * AWS Lambda
  * Kinesis Client Library Application
* Stream lasts maximum 24 hours
* Usage Case
  * Logic processing based on item change events
  * Analysis
  * Store in various data stores (ElasticSearch)
  * Cross-region replication

#### 14.2.5. DynamoDB Global Tables

* Configures active-active replication across multiple regions
* Can perform read and write from DynamoDB in all regions
* DynamoDB streams functionality must be enabled

### 14.3. API Gateway

* Managed service
* Supports WebSocket protocol
* Supports API versioning
* Supports environments (Dev, Stage, Prod)
* Supports API key creation
* Supports request throttling
* Supports import and export functionality based on Swagger and Open API
* Can generate SDK based on API or create API spec
* Can modify and validate request and response as needed
* Can respond with response

#### 14.3.1. Integration

* Acts as reverse-proxy for Lambda
* Acts as backend server based on HTTP protocol
* Can expose all AWS APIs through API Gateway

#### 14.3.2. Endpoint Type

* Edge-Optimized
  * Type for global clients
  * API Gateway is located in one region and receives requests from external regions through edge locations
* Regional
  * Client is only located in same region as API Gateway
  * User sets edge location utilization policy
* Private
  * Can only access within VPC

#### 14.3.3. Security

* Can set API access authorization through IAM
* Lambda Authorizer
  * Receives authentication token in header in Lambda and performs authentication and authorization actions inside Lambda
  * Lambda returns IAM policy to apply to user
* Cognito User Pool
  * Can verify authentication through user information stored in Cognito
  * Can only perform authentication

### 14.4. Cognito

* User Pool
  * Pool storing user information
* Federated Identity Pool
  * TODO

### 14.5. SAM (Serverless Application Model)

* Framework for developing and deploying serverless applications
* Configured through YAML files
* Supports running Lambda, API Gateway, and DynamoDB locally to enable easy development
* Supports Lambda deployment using CodeDeploy

## 15. Database

* RDBMS : RDS, Aurora
* NoSQL : DynamoDB (JSON), ElasticCache (Key/Value), Neptune (Graphs)
* Object Store : S3 / Glacier
* Data Warehouse : Redshift, Athena
* Search : ElasticSearch (JSON)
* Graphs : Neptune

### 15.1. Redshift

* PostgreSQL-based OLAP database
* Columnar storage
* Parallel query processing using MPP (Massively Parallel Query)
* Loads data from separate databases like S3, DynamoDB, DMS
  * Data load using Amazon Kinesis
  * Data loading by directly copying from S3
  * Data loading using EC2 JDBC driver
* Can use from 1 node to 128 nodes, maximum 128TB per node
* Node Type
  * Leader Node : Performs query plan and result aggregation
  * Compute Node : Performs queries and sends results to leader node
* Redshift Spectrum : Performs queries directly on S3 objects
* VPC Routing : Can perform data copy and unload through VPC

#### 15.1.1. Snapshot & DR

* Multi-AZ mode does not exist
* Snapshots are stored in S3
* Can recover by creating new Redshift cluster through created snapshot
* Can configure to periodically copy created snapshot to different region

### 15.2. Glue

* ETL (Extract, Transform, Load) service
  * Load to Redshift
* Serverless service
* Glue Data Catalog
  * Crawler : Collects metadata from data stores like S3, RDS, DynamoDB
  * Glue Data Catalog : Stores metadata collected by crawler
  * Metadata : Table information, data type, column information
  * Stored metadata can be used in Athena, Redshift Spectrum, EMR

### 15.3. Neptune

* Graph database
  * High relation data
  * Social networking
  * Wikipedia
* Managed service
* Utilizes 3 AZs and supports up to 15 read replicas
* Supports backup through S3

### 15.4. OpenSearch

* Can search all fields
  * Often used for big data analysis
* Composed through EC2 cluster
  * Charges based on EC2 instance nodes
* Provides integration with Kinesis Data Firehose, AWS IoT, and CloudWatch Logs
* Provides security techniques using Cognito, IAM, KMS encryption, SSL & VPC
* Provides OpenSearch dashboard

## 16. Monitoring, Audit

### 16.1. CloudWatch Metric

* All AWS services own unique metric values
* Metrics are dependent on namespace
* Maximum 10 dimensions per metric
* EC2 instances collect metrics at 5-minute intervals by default
  * Can collect metrics at 1-minute intervals with additional cost
* Can define and directly push user's custom metrics through API

### 16.2. CloudWatch Dashboard

* Dashboard is a global resource
* Dashboard can include graphs from other accounts or other regions
* Can share with third parties without AWS accounts
  * Uses email address and Amazon Cognito
* Free up to 3 dashboards, $3 per month after that

### 16.2. CloudWatch Log

* Log collection service
* Log groups exist and group names are generally used as app/service names
* Can set log expiration period
  * 30 days, no expiration
* Log Target
  * S3, Kinesis Data Stream, Kinesis Data Firehose, AWS Lambda, ElasticSearch
* Log Source
  * SDK, CloudWatch Log Agent
    * CloudWatch Log is not installed on EC2 by default, user must install directly
  * Elastic Beanstalk, ECS, AWS Lambda, VPC Flow Logs, API Gateway

### 16.3. CloudWatch Alarms

* Can trigger any metric as alarm
  * Logs can also be converted to metric indicators and can set alarms through converted metrics
* Alarm Status
  * OK : Alarm is not triggered
  * INSUFFICIENT_DATA : Insufficient data to determine status
  * ALARM : Alarm is triggered
* Period
  * Can set cycle for checking metrics
  * Can set at 10-second, 30-second, and 60-second cycles
* Main Metric Targets
  * EC2 Instance
  * Auto Scaling
  * SNS

### 16.4. CloudWatch Events

* Can receive events from AWS services
* Event Source
  * Compute : Lambda, Batch, ECS Task
  * Integration : SQS, SNS, Kinesis Data Stream, Kinesis Data Firehose
  * Orchestration : Step Functions, CodePipeline, CodeBuild
  * Maintenance : SSM, EC2 Actions

### 16.5. EventBridge

* Extended service of CloudWatch Events
* Event Bus Type
  * Default Event Bus : Event bus created by AWS services
  * Partner Event Bus : Event bus from AWS-based SaaS services
  * Custom Event Bus : User app's event bus
* Can use event bus from other AWS accounts through permission settings
* Can archive events sent to event bus and replay archived events
* Schema Registry
  * EventBridge stores event schemas by inferring them
  * Schemas obtained through inference are provided as structs so apps can conveniently use event data
  * Supports schema version management
* Can apply resource-based policy
  * Can set policy per event bus
  * Can allow or block events sent from other accounts
  * Can also allow or block events based on AWS region

### 16.6. CloudTrail

* Logs user's AWS activity records
  * SDK, CLI, Console, IAM Users & Roles
* Can also store activity record logs in CloudWatch Logs or S3
* Can record for all regions or single region
* CloudTrail Event
  * Management Event : Enabled by default
  * Data Event : Disabled by default (because event recording requires much capacity)

#### 16.6.1. CloudTrail Insight

* Detects suspicious behavior based on CloudTrail activity record logs
* Detected behavior events are delivered to the following places
  * CloudTrail Console
  * S3 Bucket
  * EventBridge

### 16.7. Config

* Provides functionality to review whether current configuration is correct
  * User creates review rules
* Provides functionality to record configuration changes
* Can receive configuration changes through SNS
* Must configure for each needed region because it is a region-level service

## 17. Security, Encryption

### 17.1. KMS (Key Management Service)

* Key management service
* Most AWS services utilize KMS service when keys are needed
* Can also use through CLI and SDK
* CMK (Customer Master Key) Type
  * Symmetric (AES-256)
  * Asymmetric (RSA & ECC Key Pairs)
* CMK (Customer Master Key) Type
  * AWS Managed Service Default CMK : Free
  * User Keys created in KMS : $1 per month
  * User Keys imported : $1/month
* Key Management Actions : Create, set rotation policy, disable/enable
* Can monitor key usage through CloudTrail
* Must assign key policy to user and also need IAM settings to access KMS
* KMS keys are tied to specific region and cannot move between regions
  * If data copied between regions is encrypted with KMS, must re-encrypt with new KMS key after data copy

### 17.1.1. Key Rotate

* Automatic Key Rotate
  * Can use automatic key rotate functionality only for customer-managed CMKs
  * Performs key rotate at 1-year cycle
    * Cycle does not change
  * Has same CMK ID even after performing key rotate
  * Supports keys before rotate even after rotate for backward compatibility

* Manual Key Rotate
  * Creates new key and performs key rotate when user wants
  * Has different CMK ID because new key is created
  * Must keep existing key to decrypt previous data
  * Recommends apps to access through alias rather than CMK ID
    * Assigns alias attached to previous key to new key after creating new key
    * CMK ID changes when performing manual key rotate, but no app modification needed if app accesses key through alias

### 17.2. SSM Parameter Store

* Storage for parameters (configuration, secrets)
* Provides encryption functionality using KMS
* Has serverless, scalable, durable, and easy SDK
* Provides tracking functionality
* Can detect changes through CloudWatch events
* Can combine with CloudFormation
* Can manage parameters in directory format Ex) Vault
* Parameter Policies
  * Automatically deletes when expired
  * Sends event to CloudWatch when expired
  * Sends event to CloudWatch if parameter is not changed for specific period

### 17.3. Secret Manager

* Specialized for secret storage (vs SSM Parameter Store)
* Provides secret rotate functionality
  * Supports automatic password generation when performing rotate using Lambda
* Can be used for RDS secret management

### 17.4. CloudHSM

* Encryption hardware module
* Implements SSE-C type encryption

### 17.5. Shield

* Standard
  * L3/L4 layer-based DDoS protection
  * Prevents sync/UDP flooding and reflection attacks
  * Free
* Shield Advanced
  * Sophisticated DDoS attack protection for more diverse resources with additional cost
  * Protection Targets : Amazon EC2, ELB, CloudFront, Global Accelerator, Route 53
  * Can access DRP (DDoS Response Team)
  * Can receive refund for additional costs charged due to DDoS attacks

### 17.6. WAF (Web Application Firewall)

* Layer 7 firewall
* Targets : ALB, API Gateway, CloudFront
* Provides Web ACL functionality
  * ACL Rule : Includes IP address, HTTP header, HTTP body, URI
  * Prevents SQL injection and cross-site scripting attacks
  * Blocks specific countries
  * Can set rate-based rules

### 17.7. Firewall Manager

* Provides centralized management functionality for organization's Shield and WAF
* Provides common rule setting functionality

### 17.8. GuardDuty

* Service that protects AWS accounts
* Detects abnormal behavior based on machine learning
  * Performs detection based on CloudTrail event logs, VPC flow logs, DNS logs, and Kubernetes audit logs
* Can receive notifications through CloudWatch events when anomalies are detected
* Can protect against encryption attacks

### 17.9. Inspector

* Security evaluation service for configured AWS infrastructure
* Security Evaluation Targets
  * EC2 Instance
    * Performs security evaluation through SSM agent installed on EC2 instance
    * Can access unintended network
    * Checks OS vulnerabilities
  * Container Image in ECR
    * Performs image inspection when container image is pushed to ECR
* Inspection results are aggregated in Security Hub or sent to Event Bridge

### 17.10. Amazon Macie

* Searches for sensitive data through machine learning pattern matching algorithms
* Can send search results to CloudWatch Events and EventBridge

## 18. Network

### 18.1. VPC (Virtual Private Cloud)

* Default VPC exists per account
* Can create up to 5 VPCs per account (soft limit)
* CIDR
  * Min CIDR : /28 (16 IP addresses)
  * Max CIDR : /16 (65536 IP addresses)
* Only the following network ranges can be assigned because VPC is a private network
  * 10.0.0.0 ~ 10.255.255.255 (10.0.0.0/8)
  * 172.16.0.0 ~ 172.31.255.255 (172.16.0.0/12)
  * 192.168.0.0 ~ 192.168.255.255 (192.168.0.0/16)
* VPCs cannot have overlapping CIDRs
* One VPC router exists per VPC

### 18.2. Subnet

* Subnet Reserved IP
  * 5 reserved IPs exist for every subnet
  * When subnet CIDR is 10.0.0.0/24
  * 10.0.0.0 : Network address
  * 10.0.0.1 : VPC router
  * 10.0.0.3 : DNS server
  * 10.0.0.255 : Broadcast address, not actually used because broadcast is not supported inside VPC

### 18.3. Internet Gateway

* Gateway that helps resources (EC2) inside VPC communicate with external internet
* Managed service
* Can only attach one internet gateway to one VPC
* Performs NAT for IPv4, does not perform NAT for IPv6
  * NAT not needed because IPv6 addresses assigned by AWS are public IP addresses

### 18.4. Bastion Hosts

* Public host that exists in public subnet
* Helps access EC2 instances that exist in private subnet
* Must configure to allow only port 22 through security group

### 18.5. NAT Gateway

* Requires elastic IP allocation
* Managed service
* Generally placed in public subnet to configure so EC2 instances in private subnet can use internet through internet gateway
* NAT gateway only maintains resilience within one AZ and cannot operate when AZ fails
  * Therefore, configure separate NAT gateway per AZ to ensure high availability
* Only available for IPv4, must use egress-only internet gateway for IPv6

### 18.6. Reachability Analyzer

* Can analyze connectivity between 2 endpoints
* Performs analysis only through network settings, not by actually sending packets

### 18.7. VPC Peering

* Connects 2 VPCs
* CIDRs of connecting VPCs cannot overlap
* VPC peering is not transitive
  * Even if VPCs are connected through VPC peering in A - B - C form, need to also configure VPC between A - C to communicate between A - C VPCs

### 18.8. VPC Endpoint

* Gateway to access AWS services that do not exist inside VPC
  * Ex) DynamoDB, SNS
* Managed service
* Endpoint Type
  * Interface Endpoint
    * Provides endpoint by provisioning ENI
    * Can access most AWS services
    * Requires security group settings
  * Gateway Endpoint
    * Provides endpoint through gateway
    * Requires routing table settings
    * Used when accessing S3 and DynamoDB services

### 18.9. VPC Flow

* Logs packet flow in VPC
  * Can check VPC flow, subnet flow, ENI flow
* Useful for packet monitoring and troubleshooting
* Logs can be sent to S3 or CloudWatch

### 18.10. Site-to-Site VPN

* VPN that connects AWS VPC and enterprise private network through public network
* VGW (Virtual Private Gateway) : Gateway connected to VPN inside VPC
* Customer Gateway : Software application or physical device connected to VPN inside enterprise
* Must set route propagation option in VPC
* Multiple enterprises can connect to one VPC
  * Enterprises can also communicate through VGW in this case

### 18.11. Direct Connect

* Connects AWS VPC and enterprise private network through private network
  * VGW (Virtual Private Gateway) : Gateway connecting VPC and direct connection location inside VPC
  * Direct Connection Endpoint : Connects direct connection location and VPC at direct connection location
  * Customer, Partner Router : Connects direct connection location and enterprise network at direct connection location
  * When accessing public endpoints like S3, accesses from direct connection endpoint to public endpoint, not from direct connection endpoint to VGW path
  * Can configure high availability by placing two or more direct connection endpoints, customer, and partner routers at direct connection location
* Direct Connect Gateway : Used when wanting to access other regions through Direct Connect
* Connection Type
  * Dedicated Connection
    * 1Gbps, 10Gbps
    * Connected through dedicated Ethernet port allocated to customer
  * Hosted Connection
    * 50Mbps, 500Mbps to 10Gbps
    * Capacity can be changed based on requirements
* Does not perform encryption
  * Can set separate encryption through VPN + IPSec
  * Security improves but configuration becomes complex

### 18.12. PrivateLink

* Can expose desired VPC to other VPCs using PrivateLink
* Places NLB - ENI in different VPCs and connects through AWS Private Link
  * If NLB is located in multiple AZs, ENI must also be located in each AZ

### 18.13. Transit Gateway

* Can connect multiple VPCs to one transit gateway
  * Can also connect Direct Connect Gateway and Site-to-Site VPN
* Can control traffic
* Regional resource
* Can share with other accounts
  * Can share through RAM (Resource Access Manager)
  * Peer Transit
* Supports IP multicast
* Used to expand bandwidth of connections between enterprises and VPCs by connecting multiple Site-to-Site VPNs
  * Based on ECMP

### 18.14. IPv6

* Can enable dual stack mode by enabling IPv6 in VPC
  * Cannot disable IPv4
* When VPC operates as dual stack, can assign both IPv4 and IPv6 IPs when EC2 instance is attached to that VPC
* IPv6 addresses are assigned public IP addresses

### 18.15. Egress-only Internet Gateway

* Egress gateway only for IPv6
* Cannot use IPv4, performs similar role as NAT gateway for IPv4
* Assigned to VPC for use
  * Slightly different structure because NAT gateway is assigned to subnet
* Managed service
* Does not perform NAT
  * Does not perform NAT because AWS IPv6 is public IPv6

## 19. Migration

### 19.1. DMS (Database Migration Service)

* Can use source database even during migration
* Supports database migration between different types
  * Also supports schema conversion through SCT (Schema Conversion Tool)
* CDC (Continuous Data Replication) method
* Requires EC2 instance creation to perform migration tasks

### 19.2. Data Sync

* Performs data synchronization between on-premises and AWS
  * On-Premises Target : NFS, SMB
  * AWS Target : S3, EFS, FSx
  * Requires AWS DataSync agent installation on-premises
* Can set synchronization cycle as hourly, daily, or weekly
* Can also perform synchronization between AWS
  * EFS Region A - EFS Region B

### 19.3. Backup

* Backs up storage services to S3
  * Targets : EC2, EBS, S3, RDS, DynamoDB, DocumentDB, EFS, Aurora, Neptune, FSx, Storage Gateway
* Supports cross-account
* Supports cross-region
* Supports backup vault lock
  * WORM (Write Once Read Many) policy
  * Cannot delete backups with vault lock

## 20. Machine Learning

* Rekognition : Recognizes objects and people in photos or videos
* Transcribe : Converts voice to text
* Polly : Converts text to voice
* Translate : Language translation
* Lex : Provides Amazon Alexa functionality
* Connect : Phone consultation
* Comprehend : NLP (Natural Language Processing)
* SageMaker : Provides development and operation environment for building and applying ML models
* Forecast : Functionality to predict the future
* Kendra : Document search functionality
* Personalize : Personal recommendation functionality
* Textract : Extracts text from scanned documents

## 21. Reference

* [https://www.udemy.com/course/best-aws-certified-solutions-architect-associate](https://www.udemy.com/course/best-aws-certified-solutions-architect-associate)
* EC2 Instance vs AMI : [https://cloudguardians.medium.com/ec2-ami-%EC%99%80-snapshot-%EC%9D%98-%EC%B0%A8%EC%9D%B4%EC%A0%90-db8dc5682eac](https://cloudguardians.medium.com/ec2-ami-%EC%99%80-snapshot-%EC%9D%98-%EC%B0%A8%EC%9D%B4%EC%A0%90-db8dc5682eac)
* Route53 Alias : [https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resource-record-sets-choosing-alias-non-alias.html](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resource-record-sets-choosing-alias-non-alias.html)
* Route53 Alias : [https://serverfault.com/questions/906615/what-is-an-amazon-route53-alias-dns-record](https://serverfault.com/questions/906615/what-is-an-amazon-route53-alias-dns-record)
* Auto Scaling Policy : [https://tutorialsdojo.com/step-scaling-vs-simple-scaling-policies-in-amazon-ec2/](https://tutorialsdojo.com/step-scaling-vs-simple-scaling-policies-in-amazon-ec2/)


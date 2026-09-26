---
title: AWS Certified Developer Associate Certificate Theory Summary
---

## 1. Base

Summarizes the missing parts based on the following summary

* [AWS Solutions Architecture Associate](https://ssup2.github.io/record/%EC%9E%90%EA%B2%A9%EC%A6%9D_AWS_Solutions_Architect_Associate/)

## 2. AWS API & CLI

### 2.1. API Call Limit (Quota)

* API calls are limited
  * Ex) EC2 `DescribeInstance` : 100 Call Per Seconds
  * Ex) S3 `GetObject` 5500 : 5500 Call Per Seconds, Per Prefix
  * `ThrottlingException` error occurs when the limit is exceeded
  * Perform Exponential Backoff
* Exponential Backoff
  * When calling APIs with the AWS SDK, the Exponential Backoff Logic is included inside the AWS SDK
  * When calling AWS APIs directly, the Client must implement the Exponential Backoff Logic itself
    * Must be implemented to attempt Backoff only when 5XX Errors occur
    * Do not perform Backoff on 4XX Errors

### 2.2. Credential Provider Chain

* Credentials are found and applied in the following order
  * **CLI Option** : `--region`, `--output`, `--profile`
  * **Env** : `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`
  * **CLI Credential File** : `~/.aws/credentials`
  * **CLI Configuration File** : `~/.aws/config`
  * Container Credential
  * Instance Profile Credential

### 2.3. Signing Request

* Most API calls require Signing the request using the Access Key and Secret Access Key
* When calling AWS APIs through the SDK or CLI, the SDK and CLI perform Signing internally
* When calling AWS APIs directly, sign the request with the `SigV4` method and send it

## 3. CloudFront

* CDN Service
* DDoS protection

### 3.1. CloudFront Origin

* S3 Bucket
  * Can perform S3 Object Caching
  * Can strengthen Security using "OAI (Origin Access Identity)"
  * Can also upload S3 Objects through CloudFront
* Custom Origin
  * Resources that support the HTTP Protocol can be used as CloudFront Origins
  * Ex) ALB, EC2 Instance, HTTP Backend Server

### 3.2. Caching Invalidation

* How long cached information is kept can be configured through the TTL setting
* Cached information can be refreshed by explicitly calling the Invalid API

### 3.3. Security

* Blacklist and Whitelist can be configured per country
* Client -> Edge Location
  * HTTPS-based encryption available
  * Policy : HTTPS Only, HTTP usage can be suppressed through HTTP to HTTPS Redirect
* Edge Location -> Origin
  * HTTPS-based encryption available
  * Policy : HTTPS Only, Match Viewer (HTTP if Client -> Edge Location is HTTP, HTTPS if HTTPS)

### 3.4. Signed URL, Signed Cookie

* Signed URLs and Signed Cookies can be used when CloudFront Data should be exposed only to specific Users
* Signed URLs and Signed Cookies contain the following information
  * TTL, accessible IP Range, Signer
* Signed URL
  * One URL is required per File
* Signed Cookie
  * Multiple Files can be accessed with a single Cookie
* CloudFront Signed URL vs S3 Pre-Signed URL
  * TODO
* Signer Type
  * Trusted Key Group (currently recommended)
    * **Private Key** : Used by the Application for URL Signing
    * **Public Key** : Used by CloudFront to verify the Signed URL
  * Using an account that holds a CloudFront Key Pair (legacy method, not recommended)

## 4. ECS

* Container Orchestrator Service
* Supports ALB and NLB integration
* EFS usage recommended

### 4.1. Launch Type

* EC2 Launch Type
  * EC2 Instance management required
  * The ECS Agent runs inside the EC2 Instance
* Fargate Launch Type
  * Serverless
  * No EC2 Instance management required

### 4.2. IAM Role

* The ECS Agent calls ECS, ECR, and CloudWatch through IAM using the EC2 Instance Profile
  * Applies only to the EC2 Launch Type
* A dedicated Role can be assigned for ECS Tasks

### 4.3. Component

* Task
  * Means one or more Containers
  * Parameters can be passed to a Task through environment variables
    * Hardcoding
    * Values from SSM Parameter Store or Secret Manager can be read and passed as environment variables
  * Volumes can be configured for Data sharing between Containers inside a Task (Bind Mount)
    * **EC2 Launch Type** : Since Data is stored on the EC2 Instance, the Data Lifecycle follows the EC2 Lifecycle, and the Volume Size is also determined by the EC2 Instance Type
    * **Fargate Launch Type** : The Volume Size defaults to 20GB and up to 200GB can be used
* Service
  * A set of Tasks
  * Supports AutoScaling
  * Maintains the number of Tasks and supports Rolling Updates
  * Can be connected to a Load Balancer per Service

### 4.4. Auto Scaling

* Auto Scaling is supported for Services
* Operates based on AWS Application Auto Scaling
* Uses the following Metrics
  * Average CPU usage of the Tasks belonging to the ECS Service
  * Average Memory usage of the Tasks belonging to the ECS Service
  * Average number of requests sent by the ALB per Task belonging to the ECS Service
* Supports the following Algorithms
  * **Target Tracking** : Performs Scale In/Out so that the CloudWatch Metric meets a specific value
  * **Step Scaling** : Performs Scale In/Out step by step whenever a CloudWatch Alarm occurs
  * **Scheduled Scaling** : Performs Scale In/Out according to Date/Time
* When using the EC2 Launch Type, EC2 Instances must also be scaled
  * EC2 Instance Scaling is performed using ASG
    * Based on the average CPU utilization of the ASG Group
    * Based on the ECS Cluster Capacity Provider, Scaling Out is performed when the CPU/Memory required to run Tasks is insufficient

### 4.5. Rolling Update

* Minimum Health Percent and Maximum Percent can each be configured
* Ex) Min 50%, Max 100% : If 4 Tasks are running, the process proceeds as: remove 2 Old Versions, create 2 New Versions, remove 2 Old Versions, create 2 New Versions
* Ex) Min 100%, Max 150% : If 4 Tasks are running, the process proceeds as: create 2 New Versions, remove 2 Old Versions, create 2 New Versions, remove 2 Old Versions

### 4.6. Load Balancing Packet Flow

* EC2 Launch Type
  * Traffic flows through the path Client -> ELB -> EC2 Instance -> ECS Task
  * EC2 maps a Host Port to receive Traffic from the ELB
  * Each Task on the EC2 Instance uses a different Host Port, assigned at Random
  * Since Host Ports are assigned at Random, all Ports must be open between the ELB -> EC2 Instance, which is weak in terms of security
* Fargate Launch Type
  * Traffic flows through the path Client -> ELB -> ENI -> ECS Task
  * Since the ENI and ECS are mapped 1:1, each ENI can use a single Port, and only that single Port needs to be open, which is favorable for security

## 5. Elastic Beanstalk

* Deployment environment construction and deployment Service from the developer's perspective
* All commonly used Services such as EC2, ASG, ELB, and RDS can be quickly composed through Elastic Beanstalk
* Using Elastic Beanstalk is free, but the cost of the Services composed by Elastic Beanstalk must be paid
* Supports App Version management
* Various deployment environments can be composed : Ex) Dev, Stage, Prod...
* Supports various languages : Ex) Go, Java, Java with Tomcat, .Net Core, Node.js, PHP...
* Tier
  * Means the deployment shape
  * **Web Server Tier** : EC2 Instances are grouped in an ASG and receive and process Traffic from an ELB
  * **Worker Tier** : EC2 Instances are grouped in an ASG and receive and process Jobs from SQS
* Operates based on CloudFormation

### 5.1. Deployment Mode

* **All at once** : Deploys all New Version Apps at once, temporary App downtime occurs
* **Rolling** : Gradually replaces a small number of Old Version Apps with New Version Apps. The next Old Version App is deployed only after the deployed New Version App becomes healthy. Since Old Version Apps are removed first and New Version Apps are started as many as removed, the number of New Version Apps + Old Version Apps does not change
* **Rolling with Additional Batches** : Similar to the Rolling method, but since New Version Apps are created first and then Old Version Apps are removed, the number of New Version Apps + Old Version Apps temporarily increases
* **Immutable** : Creates a new ASG, runs all New Version Apps in the created ASG, and then replaces them all at once by Swap
* **Blue/Green** : Not a method supported by Elastic Beanstalk itself, but Blue/Green deployment can be performed manually. Create a separate deployment environment and run the New Version App in it. Then use Route53 to gradually shift Traffic to the New Version App

### 5.2. Configuration

* The Code to deploy is located in a zip file
* Elastic Beanstalk settings can also be configured inside the zip file
* Located under the `.ebextensions` Dir inside the zip file
* Supports both YAML and JSON Formats
* Must have the `.config` extension
  * Ex) `logging.config`
* Default settings can be changed through the `option_setting` file
* Since Elastic Beanstalk is based on CloudFormation, AWS Resources can be deployed by placing CloudFormation configuration files under the `.ebextensions` Dir

### 5.3. Cloning

* An identical environment can be built through Clone
  * Replicates all Resources as they are
* Useful when building a Test environment
* After Cloning, settings can be changed independently

### 5.4. Migration

* ELB Migration
  * After the ELB environment is composed, the ELB Type cannot be changed
  * To change the ELB Type, Clone only the Resources excluding the ELB, and then perform Traffic Migration through Route53
* RDS Migration
  * When RDS is created through Elastic Beanstalk, the problem occurs that RDS is also deleted when Elastic Beanstalk is deleted
  * To Migrate only the App to a separate environment while keeping RDS, perform the following process
    * Change the settings of the Elastic Beanstalk containing RDS so that RDS is not deleted on deletion
    * Create a new Elastic Beanstalk environment, configured not to create a new RDS but to use the existing RDS
    * Configure Route53 to deliver Traffic to the newly created Elastic Beanstalk
    * Delete the existing Elastic Beanstalk

### 5.5. with Docker

* Single Docker Mode
  * Installs Docker on the EC2 Instance and runs only a single Container
  * The Container Image and settings to run on the EC2 Instance can be configured through a Dockerfile or the `Dockerrun.aws.json` file
* Multi Docker Container
  * Runs multiple Containers on the EC2 Instance
  * Elastic Beanstalk creates and uses an ECS Cluster
  * ECS Tasks can be defined through the `Dockerrun.aws.json` file
  * Container Images must be stored in advance in a Registry such as ECR

### 5.6. HTTPS Certificate Configuration

* HTTPS can be used by specifying a Certificate on the ALB
* The Certificate can be specified in the Web Console or in the `.ebextensions/securelistner-alb.config` file
* The Certificate can be configured through ACM or the CLI

## 6. CI/CD

### 6.1. CodeCommit

* Git Repository Service
* Managed Service
* Exists inside a VPC
* Can integrate authentication/authorization with IAM
* Performs encryption with a KMS Key
* Repositories are shared through IAM Role + STS
* Events can be delivered externally through SNS or Chatbot

### 6.2. CodePipeline

* Workflow Service
* Stage Type
  * **Source** : CodeCommit, EC#, S3, Bitbucket, Github
  * **Build** : CodeBuild, Jenkins, CloudeBees, TeamCity
  * **Test** : CodeBuild, AWS Device Farm
  * **Deploy** : CodeDeploy, Elastic Beanstalk, CloudFormation, ECS, S3
* Each Stage can be executed serially or in parallel
* Also provides a Manual Approval feature
* Artifacts
  * The output of each Stage is called an Artifact
  * Artifacts are stored in S3 and can be passed to the next Stage
* The processing of each Stage can be received through CloudWatch Events and EventBridge

### 6.3. CodeBuild

* Code location : CodeCommit, S3, Bitbucket, Github
* Builds are performed through the `buildspec.yml` file in the Code
* Output Logs are stored in S3 or CloudWatch Logs for review
* Build-related statistics can be checked using CloudWatch Metrics
* Notifications for failed Builds are possible using CloudWatch Events
* Notifications for Builds exceeding Thresholds are possible using CloudWatch Alarms
* Builds are performed inside a Container, and the Image of the Container performing the Build can be customized
* Provided so that it can also run in a Local environment
  * Docker and CodeBuild-Agent installation required
* Builds are performed outside the VPC by default, but Builds inside a VPC are also possible by specifying the VPC
  * Used when access to Resources inside the VPC is needed

#### 6.3.1. buildspec.yml

* Defines the Build method
* Path
  * **Default** : `buildspec.yml` at the Code Root
  * A specific file can also be designated through User configuration
* `Env` : Environment variables
  * `variables` : Uses plaintext
  * `parameter-store` : Uses values stored in SSM Parameter Store
  * `secrets-manager` : Uses values stored in Secret Manager
* `Phases` : Command definitions
  * `install` : Commands for resolving Build Dependencies
  * `pre_build` : Last commands before performing the Build
  * `Build` : Commands for performing the Build
  * `post_build` : Commands executed after performing the Build
* `Artifacts` : Files that must be uploaded to S3
* `Cache` : Files that should be cached to improve Build performance

### 6.4. CodeDeploy

* Deploys Apps to multiple EC2 Instances and On-premise Servers
* CodeDeploy Agent installation required on EC2 Instances and On-premise Servers
* Deployment is performed through the `appspec.yml` file
* Deployment Group (EC2 Instances), deployment Type (Once At A Time, Half At A Time, All At Once, Custom), IAM Instance Profile, App Revision, etc. can be specified

#### 6.4.1. CodeDeploy Agent

* The CodeDeploy Agent checks with the CodeDeploy Service through Polling whether there is an App to deploy
* If there is an App to deploy, it downloads the Code + `appspec.yml` file and then performs the deployment

#### 6.4.2. appspec.yml

* `files` : Specifies where to get the Source Code
* `hooks` : Configures how to proceed with the deployment
  * `ApplicationStop`
  * `DownloadBundle`
  * `BeforeInstall`
  * `Install`
  * `AfterInstall`
  * `ApplicationStart`
  * `ValidateService` : Verifies that the deployment was successful, must be configured

### 6.5. CodeStar

* A Service that helps combine Services such as Github, CodeCommit, CodeBuild, CodeDeploy, CloudFormation, CodePipeline, and CloudWatch

### 6.6. CodeArtifact

* Software Package repository
* Located inside a VPC

### 6.7. CodeGuru

* ML-based Code Review Service
* Provides a Profiler feature

## 7. CloudFormation

* IaC Service
* Create a Stack, store the desired final Infra shape as Code in the created Stack, and CloudFormation automatically creates the Infra
* To change the Infra shape, store the changed final Infra shape in the Stack, and CloudFormation compares it with the existing Infra shape, automatically detects the changed parts, and performs the Infra change
  * The changed parts detected by CloudFormation are called a ChangeSet
* When a Stack is deleted, all Resources included in the Stack are also deleted
* Most AWS Resources can be created through CloudFormation
* Parameters can be used for variableization
* Mappings can be used for fixed values (Const)
* Supports outputs, and output values can be received and used by other Stacks
* Supports conditionals
* Supports built-in functions
* Supports Nested Stacks
  * A Stack can contain Stacks
  * Used for Stack reusability
* Users can directly change Resources created through CloudFormation
  * A changed Resource is called a Drift, and a feature to check Drifts is provided

### 7.1. Rollback

* If an Error occurs during Stack creation, all Resources are deleted and then it terminates
* If an Error occurs during a Stack Update, it reverts to the pre-Update state and terminates
* The Rollback Option can be Enabled/Disabled

## 8. X-Ray

* Tracing Service
* Supported Services : AWS Lambda, Elastic Beanstalk, ECS, ELB, API Gateway, EC2 Instances
* Application methods
  * Use the X-Ray SDK inside the App
  * Install the X-Ray Daemon on the EC2 Instance

### 8.1. X-Ray Concepts

* **Segments** : The minimum information that Applications and Services send to X-Ray
* **Subsegments** : Information attached under a Segment when more detailed information needs to be attached to the Segment
* **Trace** : Tracking information composed of a set of Segments
* **Sampling** : The frequency of sending information to X-Ray; the more information sent to X-Ray, the higher the cost
* **Annotation** : Key-Value Pairs used for Indexing Traces; Indexed Traces can be searched using Filters
* **Metadata** : Key-Value Pairs that are not Indexed and cannot be used for searching

### 8.2. Sampling Rules

* The more Traces sent to X-Ray, the higher the cost
* Sampling Rule changes are configured centrally in X-Ray, no changes needed in the App
* **Reservior** : The Trace information that must be sent to X-Ray per second
  * Ex) reservior 5 : Sends 5 Traces per second
* **Rate** : The ratio of Traces sent beyond the Reservior

### 8.3. with ECS

* The X-Ray Daemon can be configured in 2 forms
* **X-Ray Daemon Container** : Configures the X-Ray Daemon as one Container on every EC2 Instance
* **Sidecar** : Configures the X-Ray Daemon as a Sidecar of the App Container; when using Fargate, only the Sidecar form is supported

## 9. CloudTrail

* A Service that records all activities (Events) related to an AWS Account
  * Console, SDK, CLI, AWS Services
* Enabled by Default
* Activity records are stored for 90 days by default
* To store for more than 90 days, they must be sent to CloudWatch Logs or S3
* After storing activity records in S3, they can be analyzed using Athena

### 9.1. CloudTrail Event (Activity)

* Events stored by CloudTrail
* Management Event
  * Events that change the shape or configuration of AWS Resources
  * Management Events are recorded by CloudTrail by default
  * Ex) Subnet Create
* Data Event
  * Data CRUD Events on AWS Resources
  * Data Events are not recorded by CloudTrail by default (because many Events would be recorded if enabled)
  * Ex) S3 `GetObject`, S3 `DeleteObject`, S3 `PutObject`
* CloudTrail Insights Event
  * Events generated by CloudTrail Insights

### 9.2. CloudTrail Insights

* Performs abnormal behavior detection based on CloudTrail activity records
* Generates CloudTrail Insights Events when abnormal behavior is detected
* CloudTrail Insights Events can be sent to the CloudTrail Console, S3 Buckets, and EventBridge

## 10. Lambda

* Function as a Service
* Supports synchronous calls and asynchronous calls
* Provides Key-value String based environment variables
  * Up to 4KB
* Logs and Metrics can be collected through CloudWatch Logs and Metrics
* Tracing is possible through X-Ray integration
* The Timeout of a Lambda function is 3 seconds by default and can be set up to 15 minutes

### 10.1. with ALB, API Gateway

* Lambda can be added behind an ALB or API Gateway
* HTTP Requests are converted to JSON, and when Lambda returns JSON, it is converted back to HTTP and the Response is sent
* When multiple Values are set with the same Key in the URL Query or HTTP Headers, the Values are delivered to Lambda in Array form

### 10.2. Lambda Edge

* Runs Lambda at Edge Locations
* Enables implementation of fast-response Apps
* CDN Contents can be modified by placing Lambda at the following 4 positions
  * **Request** : Between User -> CloudFront
  * **Request** : Between CloudFront -> Origin
  * **Response** : Between Origin -> CloudFront
  * **Response** : Between CloudFront -> User

### 10.3. Async Invocation

* Async invocation is used by S3, SNS, CloudWatch Events, and other Services
* Invocation requests are stored in the EventQueue inside the Lambda Service and executed one by one
* When a Lambda function execution fails, up to 3 Retries are attempted, executed after waiting 1 minute and 2 minutes
  * Since it can be invoked multiple times due to Retries, Lambda functions must be developed to be idempotent
  * A Dead-letter Queue can be used (sends failed execution Events to SQS or SNS)
* Provides a Destination feature
  * Lambda function execution results can be sent externally
  * SQS, SNS, Lambda, EventBridge Bus
  * AWS currently recommends using the Destination feature over the Dead-letter Queue

### 10.4. with S3

* Sync based : S3 -> SQS -> Lambda
* Async based : S3 -> Lambda
* To receive all S3 Events, the S3 Versioning feature must be enabled

### 10.5. Event Source Mapping

* Used when Client Polling is required, such as Kinesis Data, SQS, and DynamoDB Streams
* Polling is performed inside Lambda, and Events are processed when they occur
* with Stream
  * For Kinesis Streams and DynamoDB Streams
  * A separate Iterator is created for each Shard to perform Polling
  * Up to 10 Batches can be performed per Shard
  * When an Error occurs, the Batch is repeated until it succeeds by default, and indefinite Retries can occur
    * Can be resolved with methods such as discarding Old Events, limiting the Retry count, and splitting Event processing
    * Discarded Events can be sent to SQS or SNS
* with Queue
  * For SQS and SQS FIFO
  * Lambda receives Events through Long Polling
  * SQS can be used as a Dead-letter Queue for Events that fail processing

### 10.6. Permissions

* IAM based
  * Used when an Account User executes the Lambda function
  * Create a Role for the Lambda function and attach it
* Resource Based Policy
  * Used when another Account User or an AWS Service must execute the Lambda function

### 10.7. Network

* Default
  * Lambda functions run in a dedicated Lambda Network managed internally by AWS
  * External Internet access is possible, access to VPCs inside the Account is not possible
* With VPC
  * Lambda functions can be configured to access the inside of a VPC through an ENI
  * Private Subnet and Public Subnet can be configured
  * Internet access goes through the NAT Gateway inside the VPC
    * Even if the Lambda function is located in a Public Subnet, Internet access goes through the NAT Gateway

### 10.8. Spec

* Lambda functions can use 128MB ~ 10GB
* The more Memory used, the more vCPU Credits can be allocated
  * Using 1729MB has the effect of being allocated one vCPU
  * Beyond 1729MB, more than one vCPU is used, so it is recommended to modify the Function to use Multi-threading

### 10.9. Context

* Provides a feature to share Context between executions of the same Lambda function
* Context Ex) DB Connection, HTTP Client, SDK Client
* Sharing Context can reduce Lambda function initialization time
* The `/tmp` Directory can also be used as Context
  * Up to 512MB available

### 10.10. Concurrency & Throttling

* Each account can execute up to 1000 concurrently per Region
  * The Quota can be increased beyond 1000 by opening a Support Ticket
* The maximum number of concurrent executions can be configured per function
* Throttling occurs when the maximum execution count is exceeded
  * On Sync invocation : 429 Error
  * On Async invocation : Sent to the Dead-letter Queue
* Provisioned Concurrency : Initializes Lambda functions in advance to prevent Cold Starts

### 10.11. Code Dependency

* Packages for building Lambda functions must also be provided together
  * **Node.js** : `node_modules`
  * **Python** : `pip --target`
  * **Java** : `.jar`
* Upload directly to Lambda via a ZIP file; use S3 when exceeding 50MB
* Native Libraries must be added to the ZIP file; the AWS SDK does not need to be added separately

### 10.12. with CloudFormation

* Lambda functions can be created through CloudFormation
* `Code.ZipFile` method
  * A method of specifying the Code directly in the CloudFormation Template
  * Since Dependencies cannot be specified, only simple Code without Dependencies is possible
* S3 method
  * A method of storing and using the Lambda function Code and Dependencies in S3
  * The S3 Bucket, S3 Key, and S3 Object Version (when the S3 Versioning feature is enabled) must be specified
  * Can be shared with other Accounts

### 10.13. Layer

* TODO
* Supports Custom Runtimes
* Used for Code reuse

### 10.14. Container Image

* Lambda functions composed of Container Images can be run
* Container Images can be up to 10GB
* The Base Image of the Container Image must support the Lambda Runtime

### 10.15. Version & Alias

* Provides a Versioning feature
  * Version = Code + Configuration
* Alias
  * An alias feature that points to a specific Version
  * Multiple Versions can be specified, and when specifying multiple Versions, Traffic Weights can be set per Version (Canary)
  * Lambda function developers can restrict Users to using only a specific Version of the Lambda function through Aliases

### 10.16. Limitation

* **Memory** : 128MB ~ 10GB
* **Exeuction Time** : 900seconds
* **Env** : 4KB
* **Disk Capacity (/tmp)** : 512MB
* **Concurreny Exeuction** : 1000
* Lambda function Deployment Size : 50MB
* **Uncompressed Deployment** : 250MB

## 11. DynamoDB

* Guarantees High Availability based on Multi-AZ
* Can handle 100,000 requests per second
* Guarantees fast and uniform performance
* Fully integrated with IAM
* Performs Auto Scaling
* Managed
* Supports a Query language called PartiQL
* Accessed through a VPC Endpoint inside a VPC
* Encryption of stored Data using KMS, encryption of transmitted Data using SSL/TLS
* Supports Point-in-time Recovery (no performance degradation)
* Supports DynamoDB Local, which allows using DynamoDB locally

### 11.1 Table, Primary Key, Item

* Primary Key
  * Each Table requires a Primary Key
  * Composed of only a Partition Key
    * The Partition Key must be Unique
  * Partition Key + Sort Key
    * The Partition Key + Sort Key combination must be Unique
* Item (Row)
  * Can be created without limit
  * Attributes (Columns) exist
    * Can be added continuously, and Null values can also be stored
  * Maximum size is 400 KB
  * Scalar (String, Number, Binary, Boolean, Null), Document Type (List, Map), Set (String, Number, Binary)
* Partition Key
  * Determines the physical location where the Item is stored
    * The Partition Key is Hashed to determine the actual physical location
  * Used as the Primary Key

### 11.2. Read/Write Capacity Modes

* Provisioned Mode (Default)
  * Specify the number of Read/Write requests per second
    * Configured in RCU and WCU units
  * Plan and use Capacity
  * When more requests than the configured RCU/WCU are performed, Burst Capacity can be used temporarily
  * When Burst Capacity is also exhausted, `ProvisionedThroughputExceededException` occurs
  * WCU
    * One write per second for an item up to 1 KB in size
    * Ex) 10 items per seconds with item size 2KB : 10 * (2/1) = 20 WCU
    * Ex) 6 items per seconds with item size 4.5KB : 6 * (5/1) = 30 WCU
  * RCU
    * One stronly consistent read per seconds up to 4KB
    * Ex) 10 stronly consistent read per second, with item size 4KB : 10 * (4/4) = 10 RCU
    * Two eventaully consistent reads per seconds up to 4KB
    * Ex) 16 eventually consistent read per second, with item size 12KB : (16/2) * (12/4) = 24 RCU
* On-Demand Mode
  * Performs Read/Write Automatic Scale Up/Down
  * No Capacity Plan required
  * Charges more than Provisioned Mode
    * About 2.5 times more expensive
  * Requests are performed in WRU and RRU units
    * The same units as WCU and RCU

### 11.3. Throttling

* Causes
  * **Hot Keys** : When requests are concentrated on a single Partition Key
  * **Hot Partitions** : When requests are concentrated on a single Partition
  * **Very Large Items** : When RCU or WCU is exceeded
* Solutions
  * Perform Exponential Backoff
  * Distribute Partition Keys
  * Use DynamoDB Accelerator (DAX)

### 11.4. Index

* LSI (Local Secondary Index)
  * Alternative Sort Key
    * Can only be created with String, Number, and Binary Types
  * Up to 5 can be created per Table
  * Can only be configured at Table creation
  * Queries can be performed against the LSI
* GSI (Global Secondary Index)
  * Alternative Primary Key
    * Can only be created with String, Number, and Binary Types
  * Improves Query performance
  * Can be added after Table creation

### 11.5. Optimistic Locking

* Optimistic Locking can be used through Conditional Writes requests.
* The Client obtains the Item's Version information through the `GetItem` command, and then performs a Conditional Writes request with the Version information
* The Write succeeds only if the Version included in the Conditional Writes request matches the current Item's Version; if different, the Write fails

### 11.6. DynamoDB Accelerator (DAX)

* Cache Server for DynamoDB
* Managed Service
* No Client changes required
* Can solve the Hot Key problem caused by too many Read requests
* Default TTL 5 minutes, changeable
* The DAX Cluster must be provisioned separately, and up to 10 Nodes can compose the Cluster
  * Multi-AZ configuration recommended for high availability
* vs ElastiCache
  * **DAX** : Performs Item Caching
  * **ElastiCache** : Caches query results

### 11.7. DynamoDB Streams

* Converts Item change history into a Stream and provides it
* Sent to Kinesis Data Streams
* Streams can be retained for up to 24 hours
* Usage Case
  * Detecting Item changes
  * Analytics
  * Storing Data in another Data Store
  * Storing and analyzing in ElasticSearch
  * Cross-region Replication

### 11.8. DynamoDB TTL

* Provides a TTL feature
* Does not use WCU
* The TTL time is configured as a Number Attribute with a Unix Epoch Timestamp value
* Expired Items are not deleted immediately, and up to 48 hours can elapse
* Expired but not-yet-deleted Items can still be queried, so Filtering must be performed on the Client

### 11.9. DynamoDB Transaction

* Implements Transactions by operating multiple Operations in an all-or-nothing manner
* Uses twice the WCU and RCU

### 11.10. With S3

* When storing Items larger than 400KB : Store the Item in S3 and store the S3 URL in DynamoDB
* Storing S3 Object Meta information : Compose S3 -> Lambda -> DynamoDB to store the Meta information of Objects stored in S3 into DynamoDB

## 12. API Gateway

* Supports WebSocket
* Supports Versioning
* Supports Stages (Dev, Test, Prod)
* Supports authentication and authorization
* Supports API Key creation and Throttling
* APIs can be defined quickly through Swagger and OpenAPI Import
* Request and Response transformation and validation
* SDK generation and API Spec generation
* Response Caching
* Supports Canary
* Serverless, Managed

### 12.1. Target

* Lambda
* HTTP
  * **Internal HTTP API**, **ALB** : To utilize API Gateway's Rate limiting, Caching, authentication/authorization, and API Key features
* AWS Service
  * Exposing AWS Step Functions, sending Messages to SQS

### 12.2. Endpoint Type (API Gateway Deployment Type)

* Edge-Optimized
  * Configuration for Global Clients
  * API Gateway is deployed in only one Region
  * Client requests are delivered to the deployed API Gateway through CloudFront Edge Locations
* Regional
  * Used when the Client and API Gateway are in the same Region
  * CloudFront configuration is performed separately as needed
* Private
  * Accessible only through an ENI inside a VPC

### 12.3. Integration Types

* AWS
  * Used when integrating with AWS Service APIs
  * Requests and Responses can be modified using Mapping Templates
  * Mapping Template configuration required
* AWS_PROXY
  * Used when integrating with Lambda
  * Sends Client requests to Lambda as is, Responses cannot be changed
  * No Mapping Template configuration needed
* HTTP
  * Used when integrating with internal HTTP Backend Servers
  * Requests and Responses can be modified using Mapping Templates
  * Mapping Template configuration required
* HTTP_PROXY
  * Used when integrating with internal HTTP Backend Servers
  * Sends Client requests as is, Responses cannot be changed
  * No Mapping Template configuration needed
* MOCK
  * Responds from API Gateway without delivering the request to the Backend
  * For development and Test purposes
* Mapping Template
  * Performs Request and Response modification
  * Query String Parameters can be changed
  * Body can be changed
  * Headers can be added
  * Provides Templates using the VTL (Velocity Template Language) language
  * Provides Output Filtering
  * JSON to XML conversion possible (for SOAP)

### 12.4. Caching

* **TTL** : 300 seconds (0 ~ 3600s)
* Configurable per Stage
* Can be overridden per Method
* Provides Caching information encryption
* Caching size can be 0.5GB ~ 237GB
* Expensive, recommended for use only in Production

### 12.5. API Key & Usage Plan

* API Key
  * An arbitrary string value
  * A request must include an allowed API Key value in the Header to succeed
  * Usage can be limited according to the Usage Plan configured for the API Key value
  * No Rotation feature
* Usage Plan
  * Available APIs can be configured
  * Usage can be limited (Throttling & Quota)

### 12.6. Monitoring

* **Logging** : Logs can be collected through CloudWatch Logs
* **Tracing** : Tracing information can be collected through X-Ray
* **Metric** : Metrics can be collected through CloudWatch Metrics
  * `CacheHitCount` & `CacheMissCount`
  * `Count`: Number of API calls
  * `IntegrationLatency`: Request/receive Latency between API Gateway and the Backend
  * `Latency` : Request/receive Latency between the Client and the Backend
  * `4XXError` & `5XXError`

### 12.7. Throttling

* Account Throttling
  * 10000 RPS limit
  * A Soft Limit that can be increased upon request
  * A 429 (`TooManyRequests`) Error occurs when the Limit is exceeded
* Stage Throttling & Method Throttling configurable
* Throttling configurable through Usage Plans

### 12.8. Authentication, Authorization

* IAM
  * IAM User and Role based configuration for authentication and authorization within the same Account
  * Resource Policy based configuration for Cross Account
  * Authentication and authorization configurable
* Cognito
  * Authentication based on Cognito User Pools
  * User Pools can be composed by integrating with Identity Providers that provide OIDC and SAML, such as Google and Facebook
  * Authorization must be implemented in the App
* Custom Authorizer
  * Implements authentication and authorization by processing Custom Tokens using Lambda
  * Advantage of excellent flexibility

### 12.9. API Type

* HTTP API
  * Cheaper than REST API
  * Provides OIDC-based authentication
  * No Usage Plan or API Key features
* REST API
  * Provides most features except OIDC-based authentication
  * Higher price than HTTP API
* WebSocket API
  * TODO

## 13. SAM

* Framework Service for Serverless Application development
* YAML-based Configuration
* Uses CloudFormation as the Backend
* Performs Lambda deployment using CodeDeploy
* Helps run Lambda, API Gateway, and DynamoDB locally to build a development environment
* Development and deployment are performed using the SAM CLI + AWS Toolkit

### 13.1. Deployment Process

* SAM Template + Code
* --(`sam build`)--> CloudFormation Template + App Code
* --(`sam package`)--> Zip in S3
* --(`sam deploy`)--> Lambda + API Gateway + DynamoDB via CloudFormation

## 14. CDK

* A Service that generates CloudFormation Templates through Programming Languages
* JavaScript, TypeScript, Python, Java, .NET

## 15. Cognito

* Identity Service for Services and Apps
* Provides the User Pool feature
* Provides the Identity Pool feature : Integration with external Identity Providers possible

### 15.1. User Pools

* Serverless User Database Service for Services and Apps
* Provides Simple Login
* Password Reset
* Email & Phone Number Verification
* Multi-factor Authentication
* **Federated Identities** : Facebook, Google, SAML, OIDC
* JWT-based authentication possible
* Authentication integration through ALB possible
* Custom authentication processes can be performed by invoking Lambda functions in between

### 15.2. Identity Pools

* The following Pools can be configured in an Identity Pool
  * Public Providers (Amazon, Facebook, Google, Apple)
  * Cognito User Pool
  * OIDC, SAML Identity Providers
* The User logs in to the place configured as the Identity Pool, obtains a Token, and delivers the obtained Token to the Cognito Identity Pool to be issued temporary Credentials from STS
  * The issued Credentials can be used to access AWS Services
* Integration methods using User Pools
  * Identity Pool -> Google, Apple, Amazon, OIDC, SAML, Cognito User Pool
  * Identity Pool -> Cognito User Pool -> Google, Apple, Amazon, OIDC, SAML

## 16. Step Functions

* Workflow composition Service
* A single Action is defined as a Task
* Tasks can be composed by integrating with the following Services
  * Lambda functions
  * AWS Batch Jobs
  * ECS Tasks
  * DynamoDB
  * SNS, SQS
  * Other Step Functions
* Written in JSON form
* Supports visualization
* Workflow execution target

### 16.1. Error Handling

* Retry
  * Try again
  * Default Retry Count 3, no Retry attempted when set to 0
* Catch
  * When an Error occurs, execute a separate Task for the Error

### 16.2. Step Functions Type

* Standard
  * Used for long and slow Workflows
  * Duration: 1 Year
  * Supports 2000 executions per second
  * More expensive than Express
  * Exactly-Once
* Express
  * Used for short and frequently executed Workflows
  * Duration: 5 min
  * Supports 100000 executions per second
  * Cheaper than Standard
  * At-least-once

## 17. AppSync

* GraphQL Service
* Uses DynamoDB as the Backend

## 18. Amplify

* TODO

## 19. Directory Service

* Managed Microsoft AD
  * The On-premise AD Server and the AWS AD Server form a Trust relationship
  * The On-premise AD Server handles authentication in the On-premise environment, and the AWS AD Server handles authentication in the AWS environment
* AD Connector
  * Creates a Proxy for the On-premise AD Server
  * The On-premise AD Server is used through the AD Connector in the AWS environment
* Simple AD
  * A standalone AD Server that does not consider On-premise Servers

## 20. Security

### 20.1. KMS

* Key Management Service
* Supports integration with IAM
* Most AWS Services use KMS when a Key is needed for encryption
* Supports encryption of Data up to 4KB only
  * For encrypting Data larger than 4KB, the Envelope Encryption technique is used through the `GeneratedDataKey` API call
* Regional Resource
* Users cannot see the Key value directly, and can only perform encryption/decryption by specifying a Key
  * Key specification required for encryption
  * Since the encrypted Data contains information about the Key used for encryption, no Key specification is needed for decryption
* Symmetric Key
  * AES-256 based
* Asymmetric Key
  * RSA & ECC based
  * Encrypt with the public key, decrypt with the private key
  * Generally used when an App that cannot access KMS performs encryption

### 20.2. SSM Parameter Store

* Configuration Management Service
* Provides encryption using KMS
* Provides Versioning
* Events can be received using CloudWatch
  * Events can be sent before expiration
  * Events can be sent when unchanged for a certain period
* TTL configurable
* Tier
  * **Free Tier** : Up to 10000, Max Size 4KB
  * **Advanced Tier** : Up to 100000, Max Size 8KB

### 20.3. Secrets Manager

* Secret storage Service
* Secret storage using KMS
* Provides Secret Rotation
  * Automatic generation & Rotation using Lambda functions (SSM Parameter has no Rotation feature)
* Provides integration with RDS, Redshift, and DocumentDB

### 20.4. Certificate Manager

* SSL/TLS certificate management Service
* Supports integration with ALB

## 21. Reference

* [https://www.udemy.com/course/best-aws-certified-developer-associate/](https://www.udemy.com/course/best-aws-certified-developer-associate/)

---
title: AWS EFS
---

AWS의 EFS (Elastic File System) Service를 정리한다. **EFS Service**는 AWS에서 제공하는 Managed NFS Server Service이다.

## 1. Storage Class

AWS EFS는 다양한 Usecase에 대비하여 비용 효율적으로 AWS EFS를 이용할 수 있도록 Storage Class를 제공한다. 크게 Standard와 One Zone으로 분류되며 각각 IA (Infrequent Access) Storage Class가 존재한다.

### 1.1. Standard

표준 Storage Class이다. AWS EFS의 Meta 및 Data는 다수의 AZ에 동기 방식으로 복제된다. 따라서 하나 또는 두개의 AZ 장애가 발생하더라도 Data Loss가 발생하지 않는다. AWS EFS에 저장된 Data의 크기에 비례하여 비용이 발생한다.

### 1.2. Standard-IA (Infrequent Access)

Data 저장 비용은 Standard Class에 비해 낮지만 Data Read 수행시 추가 비용이 발생한다. 따라서 Data 접근 빈도가 낮을경우 이용을 권장한다. Standard Class와 동일하게 AWS EFS의 Meta 및 Data는 다수의 AZ에 동기 방식으로 복제된다.

### 1.3. One Zone

One Zone Class는 의미 그대로 하나의 Zone에만 AWS EFS의 Meta 및 Data를 저장하는 Class이다. 따라서 Meta 및 Data가 저장된 AZ 장애시 Data를 접근할 수 없거나 Data Loss가 발생할 수 있지만, Data 저장 비용은 Standard, Standard-IA Class에 비해서 낮다. 어느 AZ에 AWS EFS의 Meta 및 Data를 저장할지 User가 생성시에 지정 가능하다.

### 1.4. One Zone-IA (Infrequent Access)

Data 저장 비용은 One Zone Class에 비해 낮지만 Data Read 수행시 추가 비용이 발생한다. 따라서 Data 접근 빈도가 낮을경우 이용을 권장한다. One Zone Class와 동일하게 AWS EFS의 Meta 및 Data는 하나의 AZ에만 저장된다.

## 2. Architecture

### 2.1. Standard

{{< figure caption="[Figure 1] AWS EFS Standard" src="images/aws-efs-standard.png" width="900px" >}}

[Figure 1]은 Standard, Standard-IA Class를 이용시 AWS EFS의 Architecture를 나타내고 있다. EFS Storage는 AWS가 관리하는 별도의 VPC 내부에 존재하며 EC2 Instance는 동일 AZ에 존재하는 ENI를 통해서 EFS를 Mount하고 이용한다. EFS Meta, Data, ENI 모두 AZ마다 존재하기 때문에 특정 AZ 장애시에도 나머지 AZ에서는 EFS를 Downtime 없이 이용 가능하다.

EC2 Instance가 동일 AZ에 존재하는 ENI를 이용할 수 있는 이유는 Route 53을 활용하기 때문이다. EFS를 생성하면 Route 53은 `xxx.efs.region.amazonaws.com` 형태의 EFS Mount Point에 대한 Domain을 생성한다. EC2 Instance가 어느 AZ에 위치하냐에 따라서 Route 53은 EC2 Instance가 위치하는 동일 AZ의 ENI IP 주소를 반환한다. 따라서 각 EC2 Instance는 EFS Mount Point Domain을 대상으로 Mount를 수행하면 자연스럽게 동일 AZ에 존재하는 ENI를 통해서 EFS에 접근하게 된다.

EFS Storage 및 EFS VPC의 경우에는 AWS에서 완전히 관리하기 때문에 AWS User는 신경쓸 필요가 없지만 ENI 생성 및 ENI와 연동되는 Security Group은 AWS User가 직접 관리해주어야 한다. ENI Security Group이 EFS를 이용 해야하는 EC2 Instance의 접근을 허용하도록 반드시 설정되어 있어야 한다.

### 2.2. One Zone

{{< figure caption="[Figure 2] AWS EFS One Zone" src="images/aws-efs-one-zone.png" width="900px" >}}

[Figure 2]는 One Zone, One Zone-IA Class를 이용시 AWS EFS의 Architecture를 나타내고 있다. [Figure 1]의 Standard Architecture와 유사하지만 EFS Meta, Data, ENI가 하나의 AZ에만 존재하는 것을 확인할 수 있다. 따라서 ENI와 EC2 Instance가 서로 다른 AZ에 존재하는 경우 Data가 AZ를 건너뛰어야 하기 때문에 추가 Data 송수신 비용이 발생한다. Route 53은 EC2 Instance가 존재하는 AZ에 관계 없이 한개 존재하는 ENI의 IP를 반환한다.

## 3. Performance

AWS EFS의 성능은 **Performance Mode**와 **Throughput Mode** 두 설정의 조합으로 결정된다. Performance Mode는 File 연산의 Latency와 IOPS 상한을 결정하고, Throughput Mode는 이용 가능한 Throughput의 크기와 과금 방식을 결정한다.

### 3.1. Performance Mode

Performance Mode는 아래의 두 Mode중 하나를 EFS 생성시에 지정하며, 생성 이후에는 변경이 불가능하다.

* **General Purpose** : 기본 Mode이며 가장 낮은 File 연산 Latency를 제공하기 때문에 대부분의 Workload에 권장된다. One Zone, One Zone-IA Class 이용시에는 General Purpose Mode만 이용 가능하다.
* **Max I/O** : General Purpose Mode에 비해서 더 높은 IOPS와 Throughput을 제공하지만 File 연산의 Latency가 상대적으로 높다. 수백대 이상의 EC2 Instance가 동시에 접근하는 고도의 병렬 Workload에 적합하다.

### 3.2. Throughput Mode

Throughput Mode는 아래의 세 Mode중 하나를 지정하며, EFS 생성 이후에도 변경 가능하지만 변경 이후 24시간 동안은 다시 변경할 수 없다.

* **Bursting** : 저장된 Data의 크기에 비례하여 Throughput이 결정되는 Mode이다. 저장된 Data 1TiB당 50MiB/s의 Baseline Throughput이 제공되며, Baseline보다 낮은 Throughput으로 이용하는 동안 적립된 Burst Credit을 소모하여 일시적으로 Baseline보다 높은 Throughput까지 이용할 수 있다.
* **Provisioned** : 저장된 Data의 크기와 무관하게 User가 지정한 고정 Throughput을 제공하는 Mode이다. Bursting Mode 기준의 Baseline Throughput을 초과하여 지정한 Throughput에 대해서는 추가 비용이 발생한다.
* **Elastic** : Workload의 요구량에 따라서 Throughput이 자동으로 확장, 축소되는 Mode이다. 실제 Read/Write를 수행한 Data의 양에 비례하여 비용이 발생하기 때문에 트래픽 예측이 어려운 Workload에 권장된다. General Purpose Performance Mode에서만 이용 가능하다.

## 4. Replication

AWS EFS는 **Region 사이의 비동기 복제**인 Cross-region Replication을 지원한다. 원본 EFS Server에 Cross-region Replication을 설정하는 순간 별도의 복제본 EFS Server가 생성되며, 복제본 EFS Server는 Read-only Mode로 동작한다. 이후에 원본 EFS Server와 복제본 사이의 Cross-region Replication 설정을 제거하는 순간 복제본은 원본과 연관성이 없는 **완전히 독립된** EFS Server로 동작하며 Writable Mode로 전환된다.

Cross-region Replication 설정을 제거한 이후에는 원본 EFS Server와 복제 EFS Server 모두 각각 Cross-region Replication을 설정을 통해서 별도의 복제본 생성이 가능하다. Cross-region Replication 설정은 동시에 하나의 복제본을 대상으로만 Replication을 수행할 수 있다.

## 5. Backup

AWS EFS는 자체 Backup 기능을 제공하지 않으며 **AWS Backup Service**와의 연동을 통해서 Backup을 수행한다. AWS Backup의 Backup Plan에 Backup 주기와 보관 기간을 정의하면 Plan에 따라서 자동으로 Backup이 수행된다. EFS 생성시 Automatic Backup을 활성화하면 매일 한번 Backup을 수행하고 35일 동안 보관하는 기본 Backup Plan이 자동으로 적용된다.

Backup은 Incremental 방식으로 동작하여 최초 Backup시에만 EFS의 전체 Data를 복사하고, 이후의 Backup에서는 직전 Backup 이후에 변경된 Data만 복사한다. 또한 Backup 수행은 Burst Credit을 소모하지 않고 General Purpose Performance Mode의 File 연산 제한에도 포함되지 않기 때문에, Backup이 수행되는 동안에도 EFS를 이용하는 App의 성능에 영향을 주지 않는다. 복원은 EFS 전체 또는 특정 File, Directory 단위로 수행할 수 있으며, 원본 EFS 내부의 별도 Directory 또는 새로운 EFS를 대상으로 복원할 수 있다.

## 6. 참고

* How Amazon EFS works : [https://docs.aws.amazon.com/efs/latest/ug/how-it-works.html](https://docs.aws.amazon.com/efs/latest/ug/how-it-works.html)
* Amazon EFS performance : [https://docs.aws.amazon.com/efs/latest/ug/performance.html](https://docs.aws.amazon.com/efs/latest/ug/performance.html)
* Backing up Amazon EFS file systems : [https://docs.aws.amazon.com/efs/latest/ug/awsbackup.html](https://docs.aws.amazon.com/efs/latest/ug/awsbackup.html)
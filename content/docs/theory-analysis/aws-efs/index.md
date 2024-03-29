---
title: AWS EFS (Elastic File System)
---

AWS의 EFS (Elastic File System) Service를 정리힌다. EFS Service는 AWS에서 제공하는 Managed NFS Server Service이다.

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

EC2 Instance가 동일 AZ에 존재하는 ENI를 이용할 수 있는 이유는 Route 53을 활용하기 때문이다. EFS를 생성하면 Route 53은 "xxx.efs.region.amazonaws.com" 형태의 EFS Mount Point에 대한 Domain을 생성한다. EC2 Instance가 어느 AZ에 위치하냐에 따라서 Route 53은 EC2 Instance가 위치하는 동일 AZ의 ENI IP 주소를 반환한다. 따라서 각 EC2 Instance는 EFS Mount Point Domain을 대상으로 Mount를 수행하면 자연스럽게 동일 AZ에 존재하는 ENI를 통해서 EFS에 접근하게 된다.

EFS Storage 및 EFS VPC의 경우에는 AWS에서 완전히 관리하기 때문에 AWS User는 신경쓸 필요가 없지만 ENI 생성 및 ENI와 연동되는 Security Group은 AWS User가 직접 관리해주어야 한다. ENI Security Group이 EFS를 이용 해야하는 EC2 Instance의 접근을 허용하도록 반드시 설정되어 있어야 한다.

### 2.2. One Zone

{{< figure caption="[Figure 2] AWS EFS One Zone" src="images/aws-efs-one-zone.png" width="900px" >}}

[Figure 2]는 One Zone, One Zone-IA Class를 이용시 AWS EFS의 Architecture를 나타내고 있다. [Figure 1]의 Standard Architecture와 유사하지만 EFS Meta, Data, ENI가 하나의 AZ에만 존재하는 것을 확인할 수 있다. 따라서 ENI와 EC2 Instance가 서로 다른 AZ에 존재하는 경우 Data가 AZ를 건너뛰어야 하기 때문에 추가 Data 송수신 비용이 발생한다. Route 53은 EC2 Instance가 존재하는 AZ에 관계 없이 한개 존재하는 ENI의 IP를 반환한다.

## 3. Performance

TODO

## 4. Replication

AWS EFS는 **Region 사이의 비동기 복제**인 Cross-region Replication을 지원한다. 원본 EFS Server에 Cross-region Replication을 설정하는 순간 별도의 복제본 EFS Server가 생성되며, 복제본 EFS Server는 Read-only Mode로 동작한다. 이후에 원본 EFS Server와 복제본 사이의 Cross-region Replication 설정을 제거하는 순간 복제본은 원본과 연관성이 없는 **완전히 독립된** EFS Server로 동작하며 Writable Mode로 전환된다.

Cross-region Replication 설정을 제거한 이후에는 원본 EFS Server와 복제 EFS Server 모두 각각 Cross-region Replication을 설정을 통해서 별도의 복제본 생성이 가능하다. Cross-region Replication 설정은 동시에 하나의 복제본을 대상으로만 Replication을 수행할 수 있다.

## 5. Backup

TODO

## 6. 참고

* [https://docs.aws.amazon.com/efs/latest/ug/how-it-works.html](https://docs.aws.amazon.com/efs/latest/ug/how-it-works.html)
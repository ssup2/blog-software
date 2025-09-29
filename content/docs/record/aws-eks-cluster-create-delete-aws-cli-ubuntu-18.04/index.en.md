---
title: AWS EKS Cluster Creation / Using aws CLI / Ubuntu 18.04
---

## 1. Execution Environment

* Ubuntu 18.04 LTS 64bit, root user
* EKS Cluster
  * Version 1.18
  * Subnet 10.0.0.0/16
* aws CLI
  * Region ap-northeast-2
  * Version 2.1.34

## 2. aws CLI Installation

```shell
$ curl "https://awscli.amazonaws.com/awscli-exe-linux-x86-64.zip" -o "awscliv2.zip"
$ unzip awscliv2.zip
$ sudo ./aws/install
```

Install aws CLI.

```shell
$ aws configure
AWS Access Key ID [None]: <Access Key>
AWS Secret Access Key [None]: <Secret Access Key>
Default region name [None]: ap-northeast-2
Default output format [None]:
```

Configure authentication information for aws CLI.

## 3. SSH Key Creation

```shell
$ aws ec2 create-key-pair --key-name ssup2-eks-ssh --query 'KeyMaterial' --output text > ssup2-eks-ssh.pem
```

Create SSH Key for SSH access to EKS Nodes.

## 4. IAM Role Creation

Create IAM roles for EKS Control Plane and EKS Nodes.

```shell
$ cat > ssup2-eks-control-plan-role.json << EOL
{
	"Version": "2012-10-17",
	"Statement": [{
		"Effect": "Allow",
		"Principal": {
			"Service": "eks.amazonaws.com"
		},
		"Action": "sts:AssumeRole"
	}]
}
EOL

$ aws iam create-role --role-name ssup2-eks-control-plan-role --assume-role-policy-document file://ssup2-eks-control-plan-role.json
{
    "Role": {
        "Path": "/",
        "RoleName": "ssup2-eks-control-plan-role",
        "RoleId": "AROAR5QOEZPU3PQIXQFVE",
        "Arn": "arn:aws:iam::132099918825:role/ssup2-eks-control-plan-role",
        "CreateDate": "2021-04-05T12:41:31+00:00",
        "AssumeRolePolicyDocument": {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Principal": {
                        "Service": "eks.amazonaws.com"
                    },
                    "Action": "sts:AssumeRole"
                }
            ]
        }
    }
}

$ aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy --role-name ssup2-eks-control-plan-role
```

Create and configure IAM role for EKS Control Plane.

```shell
$ cat > ssup2-eks-node-role.json << EOL
{
	"Version": "2012-10-17",
	"Statement": [{
		"Effect": "Allow",
		"Principal": {
			"Service": "ec2.amazonaws.com"
		},
		"Action": "sts:AssumeRole"
	}]
}
EOL

$ aws iam create-role --role-name ssup2-eks-node-role --assume-role-policy-document file://ssup2-eks-node-role.json
{
    "Role": {
        "Path": "/",
        "RoleName": "ssup2-eks-node-role",
        "RoleId": "AROAR5QOEZPUWVKVBMVDY",
        "Arn": "arn:aws:iam::132099918825:role/ssup2-eks-node-role",
        "CreateDate": "2021-04-05T12:51:06+00:00",
        "AssumeRolePolicyDocument": {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Principal": {
                        "Service": "ec2.amazonaws.com"
                    },
                    "Action": "sts:AssumeRole"
                }
            ]
        }
    }
}

$ aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy --role-name ssup2-eks-node-role
$ aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly --role-name ssup2-eks-node-role
$ aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/AmazonEKS-CNI-Policy --role-name ssup2-eks-node-role
```

## 5. Network Creation

Create network for EKS Cluster.

```shell
$ aws ec2 create-vpc --cidr-block 10.0.0.0/16
{
    "Vpc": {
        "CidrBlock": "10.0.0.0/16",
        "DhcpOptionsId": "dopt-acc065c5",
        "State": "pending",
        "VpcId": "vpc-0659954e192a97a59",
        "OwnerId": "132099918825",
        "InstanceTenancy": "default",
        "Ipv6CidrBlockAssociationSet": [],
        "CidrBlockAssociationSet": [
            {
                "AssociationId": "vpc-cidr-assoc-0a38b52f741e4eee8",
                "CidrBlock": "10.0.0.0/16",
                "CidrBlockState": {
                    "State": "associated"
                }
            }
        ],
        "IsDefault": false
    }
}

$ aws ec2 create-tags --resources vpc-0659954e192a97a59 --tags Key=Name,Value=ssup2-eks-vpc
```

Create VPC for EKS Cluster.

```shell
$ aws ec2 create-subnet --vpc-id vpc-0659954e192a97a59 --cidr-block 10.0.0.0/24 --availability-zone ap-northeast-2a
{
    "Subnet": {
        "AvailabilityZone": "ap-northeast-2a",
        "AvailabilityZoneId": "apne2-az1",
        "AvailableIpAddressCount": 251,
        "CidrBlock": "10.0.0.0/24",
        "DefaultForAz": false,
        "MapPublicIpOnLaunch": false,
        "State": "available",
        "SubnetId": "subnet-0c932dea08c167b2c",
        "VpcId": "vpc-0659954e192a97a59",
        "OwnerId": "132099918825",
        "AssignIpv6AddressOnCreation": false,
        "Ipv6CidrBlockAssociationSet": [],
        "SubnetArn": "arn:aws:ec2:ap-northeast-2:132099918825:subnet/subnet-0c932dea08c167b2c"
    }
}

$ aws ec2 create-tags --resources subnet-0c932dea08c167b2c --tags Key=Name,Value=ssup2-eks-subnet-1
$ aws ec2 modify-subnet-attribute --subnet-id subnet-0c932dea08c167b2c --map-public-ip-on-launch

$ aws ec2 create-subnet --vpc-id vpc-0659954e192a97a59 --cidr-block 10.0.1.0/24 --availability-zone ap-northeast-2b
{
    "Subnet": {
        "AvailabilityZone": "ap-northeast-2b",
        "AvailabilityZoneId": "apne2-az2",
        "AvailableIpAddressCount": 251,
        "CidrBlock": "10.0.1.0/24",
        "DefaultForAz": false,
        "MapPublicIpOnLaunch": false,
        "State": "available",
        "SubnetId": "subnet-075c6fee87669a6cd",
        "VpcId": "vpc-0659954e192a97a59",
        "OwnerId": "132099918825",
        "AssignIpv6AddressOnCreation": false,
        "Ipv6CidrBlockAssociationSet": [],
        "SubnetArn": "arn:aws:ec2:ap-northeast-2:132099918825:subnet/subnet-075c6fee87669a6cd"
    }
}

$ aws ec2 create-tags --resources subnet-075c6fee87669a6cd --tags Key=Name,Value=ssup2-eks-subnet-2
$ aws ec2 modify-subnet-attribute --subnet-id subnet-075c6fee87669a6cd --map-public-ip-on-launch
```

Create 2 subnets in the created VPC. Creating an EKS Cluster requires 2 subnets in different AZs. Therefore, each subnet is created in a different AZ.

```shell
$ aws ec2 create-internet-gateway
{
    "InternetGateway": {
        "Attachments": [],
        "InternetGatewayId": "igw-07a5c603d761223d3",
        "OwnerId": "132099918825",
        "Tags": []
    }
}

$ aws ec2 create-tags --resources igw-07a5c603d761223d3 --tags Key=Name,Value=ssup2-eks-gateway
$ aws ec2 attach-internet-gateway --vpc-id vpc-0659954e192a97a59 --internet-gateway-id igw-07a5c603d761223d3
```

Create a gateway for external network access from the created VPC and attach it to the VPC.

```shell
$ aws ec2 describe-route-tables --filters Name=vpc-id,Values=vpc-0659954e192a97a59
{
    "RouteTables": [
        {
            "Associations": [
                {
                    "Main": true,
                    "RouteTableAssociationId": "rtbassoc-0d2a01f5219d19ba4",
                    "RouteTableId": "rtb-0e980c78e53c372a3",
                    "AssociationState": {
                        "State": "associated"
                    }
                }
            ],
            "PropagatingVgws": [],
            "RouteTableId": "rtb-0e980c78e53c372a3",
            "Routes": [
                {
                    "DestinationCidrBlock": "10.0.0.0/16",
                    "GatewayId": "local",
                    "Origin": "CreateRouteTable",
                    "State": "active"
                }
            ],
            "Tags": [],
            "VpcId": "vpc-0659954e192a97a59",
            "OwnerId": "132099918825"
        }
    ]
}

$ aws ec2 create-tags --resources rtb-0e980c78e53c372a3 --tags Key=Name,Value=ssup2-eks-rtb
$ aws ec2 create-route --route-table-id rtb-0e980c78e53c372a3 --destination-cidr-block 0.0.0.0/0 --gateway-id igw-07a5c603d761223d3
{
    "Return": true
}
```

Set the default gateway of the created VPC's routing table to the gateway created earlier.

## 6. EKS Cluster, Node Group Creation

```shell
$ aws eks create-cluster --name ssup2-eks-cluster --kubernetes-version 1.18 --role-arn arn:aws:iam::132099918825:role/ssup2-eks-control-plan-role --resources-vpc-config subnetIds=subnet-0c932dea08c167b2c,subnet-075c6fee87669a6cd
{
    "cluster": {
        "name": "ssup2-eks-cluster",
        "arn": "arn:aws:eks:ap-northeast-2:132099918825:cluster/ssup2-eks-cluster",
        "createdAt": "2021-04-05T13:55:28.580000+00:00",
        "version": "1.18",
        "roleArn": "arn:aws:iam::132099918825:role/ssup2-eks-control-plan-role",
        "resourcesVpcConfig": {
            "subnetIds": [
                "subnet-0c932dea08c167b2c",
                "subnet-075c6fee87669a6cd"
            ],
            "securityGroupIds": [],
            "vpcId": "vpc-0659954e192a97a59",
            "endpointPublicAccess": true,
            "endpointPrivateAccess": false,
            "publicAccessCidrs": [
                "0.0.0.0/0"
            ]
        },
        "kubernetesNetworkConfig": {
            "serviceIpv4Cidr": "172.20.0.0/16"
        },
        "logging": {
            "clusterLogging": [
                {
                    "types": [
                        "api",
                        "audit",
                        "authenticator",
                        "controllerManager",
                        "scheduler"
                    ],
                    "enabled": false
                }
            ]
        },
        "status": "CREATING",
        "certificateAuthority": {},
        "platformVersion": "eks.4",
        "tags": {}
    }
}
```

Create EKS Cluster. When creating EKS Cluster, enter the Control Plane Role and Subnet information created above.

```shell
$ aws eks create-nodegroup --cluster-name ssup2-eks-cluster --nodegroup-name ssup2-eks-group --subnets subnet-0c932dea08c167b2c subnet-075c6fee87669a6cd --node-role arn:aws:iam::132099918825:role/ssup2-eks-node-role --remote-access ec2SshKey=ssup2-eks-ssh
{
    "nodegroup": {
        "nodegroupName": "ssup2-eks-group",
        "nodegroupArn": "arn:aws:eks:ap-northeast-2:132099918825:nodegroup/ssup2-eks-cluster/ssup2-eks-group/42bc512f-b9ca-c71c-acf4-730a69a260d3",
        "clusterName": "ssup2-eks-cluster",
        "version": "1.18",
        "releaseVersion": "1.18.9-20210329",
        "createdAt": "2021-04-05T14:11:10.465000+00:00",
        "modifiedAt": "2021-04-05T14:11:10.465000+00:00",
        "status": "CREATING",
        "capacityType": "ON-DEMAND",
        "scalingConfig": {
            "minSize": 1,
            "maxSize": 2,
            "desiredSize": 2
        },
        "instanceTypes": [
            "t3.medium"
        ],
        "subnets": [
            "subnet-0c932dea08c167b2c",
            "subnet-075c6fee87669a6cd"
        ],
        "remoteAccess": {
            "ec2SshKey": "ssup2-eks-ssh"
        },
        "amiType": "AL2-x86-64",
        "nodeRole": "arn:aws:iam::132099918825:role/ssup2-eks-node-role",
        "diskSize": 20,
        "health": {
            "issues": []
        },
        "tags": {}
    }
}
```

Create Node Group inside the created EKS Cluster.

## 7. EKS Cluster Operation Verification

Verify the operation of the created EKS Cluster.

```shell
$ aws eks update-kubeconfig --name ssup2-eks-cluster
Updated context arn:aws:eks:ap-northeast-2:132099918825:cluster/ssup2-eks-cluster in /root/.kube/config
```

Configure kubeconfig for the created EKS Cluster.

```shell
$ kubectl version
Client Version: version.Info{Major:"1", Minor:"20", GitVersion:"v1.20.5", GitCommit:"6b1d87acf3c8253c123756b9e61dac642678305f", GitTreeState:"clean", BuildDate:"2021-03-31T15:33:39Z", GoVersion:"go1.15.10", Compiler:"gc", Platform:"linux/amd64"}
Server Version: version.Info{Major:"1", Minor:"18+", GitVersion:"v1.18.9-eks-d1db3c", GitCommit:"d1db3c46e55f95d6a7d3e5578689371318f95ff9", GitTreeState:"clean", BuildDate:"2020-10-20T22:18:07Z", GoVersion:"go1.13.15", Compiler:"gc", Platform:"linux/amd64"}

$ kubectl get nodes
NAME                                            STATUS   ROLES    AGE   VERSION
ip-10-0-0-192.ap-northeast-2.compute.internal   Ready    <none>   63s   v1.18.9-eks-d1db3c
ip-10-0-1-79.ap-northeast-2.compute.internal    Ready    <none>   69s   v1.18.9-eks-d1db3c
```

Check the nodes and version of the created EKS Cluster.

## 8. EKS Cluster Deletion

Remove all created EKS Cluster and related resources.

```shell
$ aws eks delete-nodegroup --cluster-name ssup2-eks-cluster --nodegroup-name ssup2-eks-group
$ aws eks delete-cluster --name ssup2-eks-cluster

$ aws ec2 detach-internet-gateway --vpc-id vpc-0659954e192a97a59 --internet-gateway-id igw-07a5c603d761223d3
$ aws ec2 delete-internet-gateway --internet-gateway-id igw-07a5c603d761223d3
$ aws ec2 delete-subnet --subnet-id subnet-075c6fee87669a6cd
$ aws ec2 delete-subnet --subnet-id subnet-0c932dea08c167b2c
$ aws ec2 delete-vpc --vpc-id vpc-0659954e192a97a59

$ aws iam detach-role-policy --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy --role-name ssup2-eks-node-role
$ aws iam detach-role-policy --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly --role-name ssup2-eks-node-role
$ aws iam detach-role-policy --policy-arn arn:aws:iam::aws:policy/AmazonEKS-CNI-Policy --role-name ssup2-eks-node-role
$ aws iam delete-role --role-name ssup2-eks-node-role
$ aws iam detach-role-policy --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy --role-name ssup2-eks-control-plan-role
$ aws iam delete-role --role-name ssup2-eks-control-plan-role

$ aws ec2 delete-key-pair --key-name ssup2-eks-ssh
```

Delete created resources in reverse order of creation.

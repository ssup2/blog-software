---
title: AWS ARN
---

Organize AWS ARN (Amazon Resource Number).

## 1. AWS ARN

```text {caption="[Text 1] AWS ARN Format"}
arn:[Partition]:[Service]:[Region]:[Account-ID]:[Resource-ID]
arn:[Partition]:[Service]:[Region]:[Account-ID]:[Resource-Type]/[Resource-ID]
arn:[Partition]:[Service]:[Region]:[Account-ID]:[Resource-Type]:[Resource-ID]
```

AWS ARN represents the name of resources managed by AWS. [Text 1] shows the formats of AWS ARN. There are a total of 3 formats: one format with only Resource-ID and two formats with Resource-Type and Resource-ID. Depending on the need, some ARNs may omit Region and Account-ID. Each component of the AWS ARN format is as follows.

* Partition : Represents a group of AWS Regions. There are 3 Partitions: "aws", "aws-cn" (China), "aws-us-gov" (US Government), and in most cases they belong to the "aws" Partition.
* Service : Represents a Namespace for classifying AWS Services. Generally, AWS service names are converted to lowercase, such as "iam", "sns", "ec2".
* Region : Represents an AWS Region. Region codes such as "us-east-2" are included.
* Account-ID : Represents a unique Account ID assigned to each AWS Account.
* Resource-Type : Represents the Type of AWS Resource. AWS resources are converted to lowercase, such as "user", "vpc".
* Resource-ID : Represents a unique ID assigned to an AWS Resource.

```text {caption="[Text 2] AWS ARN Examples", linenos=table}
IAM User : arn:aws:iam::123456789012:user/ssup2
SNS Topic : arn:aws:sns:us-east-1:123456789012:example-sns-topic-name
VPC : arn:aws:ec2:us-east-1:123456789012:vpc/vpc-0e9801d129EXAMPLE
```

[Text 2] shows examples of AWS ARN.

### 1.1. Wildcard

```text {caption="[Text 3] AWS ARN Wildcard Examples", linenos=table}
ALL EC2 Volumes : arn:aws:ec2:*:*:volume/*
ALL EC2 Instances : arn:aws:ec2:*:*:instance/*
```

AWS ARN supports Wildcard syntax, and multiple ARNs can be expressed through Wildcard syntax. [Text 3] shows examples of Wildcard usage. It is mainly used when configuring AWS IAM Policies. Wildcards cannot be applied to only part of a specific component, such as "arn:aws:ec2:*:*:instance/s*".

## 2. References

* [https://docs.aws.amazon.com/general/latest/gr/aws-arns-and-namespaces.html](https://docs.aws.amazon.com/general/latest/gr/aws-arns-and-namespaces.html)
* [https://medium.com/harrythegreat/aws%EC%9D%98-arn-%EC%9D%B4%ED%95%B4%ED%95%98%EA%B8%B0-8c20d0ccbbfd](https://medium.com/harrythegreat/aws%EC%9D%98-arn-%EC%9D%B4%ED%95%B4%ED%95%98%EA%B8%B0-8c20d0ccbbfd)


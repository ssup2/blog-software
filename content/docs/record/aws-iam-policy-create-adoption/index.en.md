---
title: AWS IAM Policy Creation, Application / Using aws CLI / Ubuntu 18.04
---

## 1. Execution Environment

* Ubuntu 18.04 LTS 64bit, root user
* aws CLI
  * Region ap-northeast-2
  * Version 2.1.34

## 2. Policy Creation

```json {caption="[File 1] instance-describe-policy.json", linenos=table}
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInstances"
      ],
      "Resource": "*"
    }
  ]
}
```

```shell
$ aws iam create-policy --policy-name instance-describe-policy --policy-document file://instance-describe-policy.json
{
    "Policy": {
        "PolicyName": "instance-describe-policy",
        "PolicyId": "ANPAUB2QWPR63Z4G22AZE",
        "Arn": "arn:aws:iam::278805249149:policy/instance-describe-policy",
        "Path": "/",
        "DefaultVersionId": "v1",
        "AttachmentCount": 0,
        "PermissionsBoundaryUsageCount": 0,
        "IsAttachable": true,
        "CreateDate": "2022-03-18T13:08:18+00:00",
        "UpdateDate": "2022-03-18T13:08:18+00:00"
    }
}
```

## 3. Policy Application

```shell
$ aws iam create-user --user-name instance-describe-user
{
    "User": {
        "Path": "/",
        "UserName": "instance-describe-user",
        "UserId": "AIDAUB2QWPR6Y2ZWFY6HT",
        "Arn": "arn:aws:iam::278805249149:user/instance-describe-user",
        "CreateDate": "2022-03-26T16:11:16+00:00"
    }
}
```

Create an instance-describe-user User and create a Secret.

```shell
$ aws iam attach-user-policy --user-name instance-describe-user --policy-arn arn:aws:iam::278805249149:policy/instance-describe
```

Attach the created instance-describe-policy Policy to the created instance-describe-user User.

## 4. Policy Operation Verification

```shell
$ aws configure
AWS Access Key ID [None]: <Access Key>
AWS Secret Access Key [None]: <Secret Access Key>
Default region name [None]: ap-northeast-2
Default output format [None]:
```

Configure aws CLI with the created instance-describe-user User.

```shell
$ aws ec2 describe-instances
{
    "Reservations": [
        {
            "Groups": [],
            "Instances": [
                {
                    "AmiLaunchIndex": 0,
                    "ImageId": "ami-033a6a056910d1137",
                    "InstanceId": "i-07f4fc518eb984bd9",
                    "InstanceType": "t2.micro",
                    "KeyName": "ssup2",
                    "LaunchTime": "2022-03-18T14:08:53+00:00",
...

$ aws ec2 describe-vpcs
An error occurred (UnauthorizedOperation) when calling the DescribeVpcs operation: You are not authorized to perform this operation.
```

You can see that the Describe Instance operation is possible, but the Describe VPC operation cannot be executed due to lack of permissions.

## 5. References

* [https://www.youtube.com/watch?v=iPKaylieTV8](https://www.youtube.com/watch?v=iPKaylieTV8)


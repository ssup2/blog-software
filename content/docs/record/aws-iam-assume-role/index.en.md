---
title: AWS IAM Assume Role / Using aws CLI / Ubuntu 18.04
---

## 1. Execution Environment

* Ubuntu 18.04 LTS 64bit, root user
* aws CLI
  * Region ap-northeast-2
  * Version 2.1.34

## 2. Assume Role Policy Creation

```json {caption="[File 1] assume-role-policy.json", linenos=table}
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sts:AssumeRole"
      ],
      "Resource": "*"
    }
  ]
}
```

Create a Policy file with only AssumeRole permissions as shown in [File 1].

```shell
$ aws iam create-policy --policy-name assume-role-policy --policy-document file://assume-role-policy.json
{
    "Policy": {
        "PolicyName": "assume-role-policy",
        "PolicyId": "ANPAUB2QWPR6YRY6MHBEV",
        "Arn": "arn:aws:iam::278805249149:policy/assume-role-policy",
        "Path": "/",
        "DefaultVersionId": "v1",
        "AttachmentCount": 0,
        "PermissionsBoundaryUsageCount": 0,
        "IsAttachable": true,
        "CreateDate": "2022-03-24T16:45:27+00:00",
        "UpdateDate": "2022-03-24T16:45:27+00:00"
    }
}
```

Create a Policy with the name assume-role-policy using [File 1].

## 3. User Creation, Configuration

```shell
$ aws iam create-user --user-name assume-role-user
{
    "User": {
        "Path": "/",
        "UserName": "assume-role-user",
        "UserId": "AIDAUB2QWPR6RY232NBJV",
        "Arn": "arn:aws:iam::278805249149:user/assume-role-user",
        "CreateDate": "2022-03-26T14:47:24+00:00"
    }
}
```

Create an assume-role-user User to perform Role Assume.

```shell
$ aws iam create-access-key --user-name assume-role-user
{
    "AccessKey": {
        "UserName": "assume-role-user",
        "AccessKeyId": "XXXXXXXXXXXXXXXXXXXX",
        "Status": "Active",
        "SecretAccessKey": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
        "CreateDate": "2022-03-26T14:47:46+00:00"
    }
}
```

Create an Access Key for assume-role-user.

```shell
$ aws iam attach-user-policy --user-name assume-role-user --policy-arn arn:aws:iam::278805249149:policy/assume-role-policy
```

Grant the assume-role-policy Policy to the assume-role-user User.

## 4. Role Creation, Configuration

```json {caption="[File 2] assume-role-trust-relationship.json", linenos=table}
{
	"Version": "2012-10-17",
	"Statement": [{
		"Effect": "Allow",
		"Action": "sts:AssumeRole",
		"Principal": {
			"AWS": "278805249149"
		},
		"Condition": {}
	}]
}
```

Create [File 2] to configure the Trust Relationship of the Role. The AWS in Principal refers to **the ID of the account receiving the Role**.

```shell
$ aws iam create-role --role-name assume-role-role --assume-role-policy-document file://assume-role-trust-relationship.json
{
    "Role": {
        "Path": "/",
        "RoleName": "assume-role-role",
        "RoleId": "AROAUB2QWPR6Y7YWJMVWY",
        "Arn": "arn:aws:iam::278805249149:role/assume-role-role",
        "CreateDate": "2022-03-26T14:50:41+00:00",
        "AssumeRolePolicyDocument": {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Action": "sts:AssumeRole",
                    "Principal": {
                        "AWS": "278805249149"
                    },
                    "Condition": {}
                }
            ]
        }
    }
}
```

Create assume-role-role, the Role to Assume.

```shell
$ aws iam attach-role-policy --role-name assume-role-role --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess
```

Grant EC2 control permissions to the assume-role-role Role.

## 5. Assume Role

```shell
$ aws configure
AWS Access Key ID [None]: <Access Key>
AWS Secret Access Key [None]: <Secret Access Key>
Default region name [None]: ap-northeast-2
Default output format [None]:

$ aws ec2 describe-instances
An error occurred (UnauthorizedOperation) when calling the DescribeInstances operation: You are not authorized to perform this operation.
```

After configuring AWS CLI with assume-role-user, perform an EC2 Instance Describe operation. Since the assume-role-user User only has Assume Role permissions, you can see that the EC2 Describe operation cannot be performed.

```shell
$ aws sts assume-role --role-arn arn:aws:iam::278805249149:role/assume-role-role --role-session-name assume-role-session
{
    "Credentials": {
        "AccessKeyId": "<Access Key>",
        "SecretAccessKey": "<Secret Access Key>",
        "SessionToken": "<SessionToken>",
        "Expiration": "2022-03-26T16:22:29+00:00"
    },
    "AssumedRoleUser": {
        "AssumedRoleId": "AROAUB2QWPR6Y7YWJMVWY:assume-role-session",
        "Arn": "arn:aws:sts::278805249149:assumed-role/assume-role-role/assume-role-session"
    }
}
```

Perform an Assume Role operation to obtain temporary AccessKeyID, SecretAccessKey, and SessionToken.

```shell
$ export AWS-ACCESS-KEY-ID=<Access Key>
$ export AWS-SECRET-ACCESS-KEY=<Secret Access Key>
$ export AWS-SESSION-TOKEN=<SessionToken>

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
```

Configure aws CLI using the obtained AccessKeyID, SecretAccessKey, and SessionToken. Afterward, when performing an EC2 Describe operation, you can see that it works.

## 6. References

* [https://aws.amazon.com/ko/premiumsupport/knowledge-center/iam-assume-role-cli/](https://aws.amazon.com/ko/premiumsupport/knowledge-center/iam-assume-role-cli/)


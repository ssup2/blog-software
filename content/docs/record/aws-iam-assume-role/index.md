---
title: AWS IAM Assume Role / aws CLI 이용 / Ubuntu 18.04
---

## 1. 실행 환경

* Ubuntu 18.04 LTS 64bit, root user
* aws CLI
  * Region ap-northeast-2
  * Version 2.1.34

## 2. Assume Role Policy 생성

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

[File 1]의 내용과 같이 AssumeRole 권한만 갖고 있는 Policy 파일을 작성한다.

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

[File 1]을 이용하여 assume-role-policy 이름을 갖는 Policy를 생성한다.

## 3. User 생성, 설정

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

Role을 Assume을 수행할 assume-role-user User를 생성한다.

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

assume-role-user의 Access Key를 생성한다.

```shell
$ aws iam attach-user-policy --user-name assume-role-user --policy-arn arn:aws:iam::278805249149:policy/assume-role-policy
```

assume-role-user User에 assume-role-policy Policy를 부여한다.

## 4. Role 생성, 설정

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

Role의 Trust Relationship을 설정하는 [File 2]을 생성한다. Principal의 AWS는 **Role을 부여받는 계정의 ID**를 의미한다.

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

Assume할 Role인 assume-role-role을 생성한다.

```shell
$ aws iam attach-role-policy --role-name assume-role-role --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess
```

assume-role-role Role에 EC2 제어 권한을 부여한다.

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

assume-role-user로 AWS CLI를 설정한 이후에, EC2 Instance Describe 동작을 수행한다. assume-role-user User는 Assume Role 권한만 가지고 있기 때문에, EC2 Desribe 동작이 수행되지 못하는 것을 확인 할 수 있다.

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

Assume Role 동작을 수행하여 임시 AccessKeyID, SecretAccessKey, SessionToken을 얻는다.

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

획득한 AccessKeyID, SecretAccessKey, SessionToken을 이용하여 aws CLI를 설정한다. 이후에 EC2 Describe 동작을 수행하면, 동작하는 것을 확인 할 수 있다.

## 6. 참조

* [https://aws.amazon.com/ko/premiumsupport/knowledge-center/iam-assume-role-cli/](https://aws.amazon.com/ko/premiumsupport/knowledge-center/iam-assume-role-cli/)
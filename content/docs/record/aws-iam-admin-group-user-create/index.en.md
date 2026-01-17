---
title: AWS IAM Admin Group, User Creation / Using aws CLI / Ubuntu 18.04
---

## 1. Execution Environment

* Ubuntu 18.04 LTS 64bit, root user
* aws CLI
  * Region ap-northeast-2
  * Version 2.1.34

## 2. Admin Group Creation, Configuration

```shell
$ aws iam create-group --group-name admins
{
    "Group": {
        "Path": "/",
        "GroupName": "admins",
        "GroupId": "AGPAUB2QWPR6TMUEMIBQI",
        "Arn": "arn:aws:iam::278805249149:group/admins",
        "CreateDate": "2022-03-17T15:51:18+00:00"
    }
}
```

Create an Admin Group with the name admins.

```shell
$ aws iam attach-group-policy --group-name Admins --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

Attach the AdministratorAccess Policy to the admins Group to configure users belonging to the admins Group to have Admin permissions.

## 3. Admin User Creation, Configuration

```shell
$ aws iam create-user --user-name admin
{
    "User": {
        "Path": "/",
        "UserName": "admin",
        "UserId": "AIDAUB2QWPR6T3VCZQUUD",
        "Arn": "arn:aws:iam::278805249149:user/admin",
        "CreateDate": "2022-03-17T15:52:39+00:00"
    }
}
```

Create an admin User.

```shell
$ aws iam add-user-to-group --group-name admins --user-name admin
```

Add the created admin User to the admin Group.

```shell
$ aws iam create-access-key --user-name admin
{
    "AccessKey": {
        "UserName": "admin",
        "AccessKeyId": "XXXXXXXXXXXXXXXXXXXX",
        "Status": "Active",
        "SecretAccessKey": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
        "CreateDate": "2022-03-17T16:06:25+00:00"
    }
}
```

Create an Access Key for the created admin User.

## 4. References

* [https://docs.aws.amazon.com/IAM/latest/UserGuide/getting-started-create-admin-group.html](https://docs.aws.amazon.com/IAM/latest/UserGuide/getting-started-create-admin-group.html)


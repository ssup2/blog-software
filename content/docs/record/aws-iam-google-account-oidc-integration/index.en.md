---
title: AWS IAM Google OIDC Integration / Using aws CLI / Ubuntu 18.04
---

## 1. Execution Environment

* Ubuntu 18.04 LTS 64bit, root user
* aws CLI
  * Region ap-northeast-2
  * Version 2.1.34

## 2. Google Project Creation, OIDC Configuration

Configuration is required to obtain OIDC-based ID Tokens from Google Cloud Platform.

{{< figure caption="[Figure 1] Project Creation" src="images/google-create-project.png" width="600px" >}}

Access [https://console.developers.google.com](https://console.developers.google.com/) and create a Project as shown in [Figure 1].

{{< figure caption="[Figure 2] OAuth Addition" src="images/google-create-oidc-1.png" width="900px" >}}

Go to the "APIs and Services" item and select "OAuth Client ID" addition to add OAuth authentication as shown in [Figure 2].

{{< figure caption="[Figure 3] OAuth Client ID Creation" src="images/google-create-oidc-2.png" width="800px" >}}

Create a Client ID of "Web Application" type as shown in [Figure 3]. The "Name" can be set arbitrarily. Set the "Redirect URI" to "http://127.0.0.1:3000/auth/google/callback". After creation is complete, check the **Client ID** and **Client Secret**.

## 3. Role Creation, Configuration

```json {caption="[File 1] google-oidc-role-trust-relationship.json", linenos=table}
{
  "Version": "2012-10-17",
  "Statement":
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "accounts.google.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "accounts.google.com:aud": "448771483088-25fslbvr9thmmi3acvo3omu0v1j6lqab.apps.googleusercontent.com"
        }
      }
    }
  ]
}
```

Create the google-oidc-role Role, which is the Role to Assume. Configure the Trust Relationship of the google-oidc-role Role as shown in [File 1]. The accounts.google.com:aud value in Condition must be set to **Client ID**. This is because the Client ID is set in the Audience Claim of ID Tokens issued by Google Cloud Platform.

```shell
$ aws iam create-role --role-name google-oidc-role --assume-role-policy-document file://google-oidc-role-trust-relationship.json
{
	"Role": {
		"Path": "/",
		"RoleName": "google-oidc-role",
		"RoleId": "AROAUB2QWPR6X3BYU2DG7",
		"Arn": "arn:aws:iam::278805249149:role/google-oidc-role",
		"CreateDate": "2022-03-27T14:46:36+00:00",
		"AssumeRolePolicyDocument": {
			"Version": "2012-10-17",
			"Statement": [{
				"Effect": "Allow",
				"Principal": {
					"Federated": "accounts.google.com"
				},
				"Action": "sts:AssumeRoleWithWebIdentity",
				"Condition": {
					"StringEquals": {
						"accounts.google.com:aud": "448771483088-25fslbvr9thmmi3acvo3omu0v1j6lqab.apps.googleusercontent.com"
					}
				}
			}]
		}
	}
}
```

Create the google-oidc-role Role.

```shell
$ aws iam attach-role-policy --role-name google-oidc-role --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess
```

Grant AmazonEC2FullAccess permissions to the created google-oidc-role Role.

## 4. User Creation, Configuration

```shell
$ aws iam create-user --user-name no-policy-user
{
    "User": {
        "Path": "/",
        "UserName": "no-policy-user",
        "UserId": "AIDAUB2QWPR6TCGK6DHFZ",
        "Arn": "arn:aws:iam::278805249149:user/no-policy-user",
        "CreateDate": "2022-03-27T15:20:35+00:00"
    }
}
```

Create a no-policy-user User that does not have all permissions.

```shell
$ aws iam create-access-key --user-name no-policy-user
{
    "AccessKey": {
        "UserName": "no-policy-user",
        "AccessKeyId": "AKIAUB2QWPR62XXMIF5W",
        "Status": "Active",
        "SecretAccessKey": "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",
        "CreateDate": "2022-03-27T15:21:37+00:00"
    }
}
```

Create an Access Key for the created no-policy-user User.

## 5. ID Token Acquisition

Execute the Program from the repository below to obtain an ID Token.

* [https://github.com/ssup2/golang-Google-OIDC](https://github.com/ssup2/golang-Google-OIDC)

```shell
$ export GOOGLE-OAUTH2-CLIENT-ID=XXX
$ export GOOGLE-OAUTH2-CLIENT-SECRET=XXX
$ go run main.go
```

```json {caption="[Text 1] http://127.0.0.1:3000 Result", linenos=table}
{
	"OAuth2Token": {
		"access-token": "ya29.A0ARrdaM-Y-JCmxefKPNfi8Q26hzrCu1nDKiV-UYKAjDud-N3MnksWdxS3SlfyTUwi9IB1z-N2KyZRTgBS-BdEXXrLKQi3ZQMrDvZOAx2dwXvkknN7dJS6HM1-gpB7JMHk2SzRTi23eldSqjEG8P4NueCamROX-w",
		"token-type": "Bearer",
		"expiry": "2022-03-28T01:17:07.510546947+09:00"
	},
	"IDToken": "eyJhbGciOiJSUzI1NiIsImtpZCI6IjU4YjQyOTY2MmRiMDc4NmYyZWZlZmUxM2MxZWIxMmEyOGRjNDQyZDAiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FjY291bnRzLmdvb2dsZS5jb20iLCJhenAiOiI0NDg3NzE0ODMwODgtMjVmc2xidnI5dGhtbWkzYWN2bzNvbXUwdjFqNmxxYWIuYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJhdWQiOiI0NDg3NzE0ODMwODgtMjVmc2xidnI5dGhtbWkzYWN2bzNvbXUwdjFqNmxxYWIuYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJzdWIiOiIxMTM2MzI0NTgzMjQwNTY4MzY2MjEiLCJlbWFpbCI6InN1cHN1cDU2NDJAZ21haWwuY29tIiwiZW1haWxfdmVyaWZpZWQiOnRydWUsImF0X2hhc2giOiJfaEo3RFREQmJORWlsX3E2S21WLWlBIiwibm9uY2UiOiJMZXpsQWNYTlZ6Y3R0bGVPV0hYaVVBIiwibmFtZSI6InNzcyBzc3MiLCJwaWN0dXJlIjoiaHR0cHM6Ly9saDMuZ29vZ2xldXNlcmNvbnRlbnQuY29tL2EtL0FPaDE0R2otLXUybVgtOEFITkNyeGJ4ZmJOR1R6YnJ4QmJSbExoT2dpM3M0dFE9czk2LWMiLCJnaXZlbl9uYW1lIjoic3NzIiwiZmFtaWx5X25hbWUiOiJzc3MiLCJsb2NhbGUiOiJrbyIsImlhdCI6MTY0ODM5NDIzMCwiZXhwIjoxNjQ4Mzk3ODMwfQ.lAikNJYXUJ7U1JEotxRK5-4OqODZX8tWBAEzBKKtze10nadkH3mu0JRHNhqdg6UMFKZdWMfp15iKghn5KxwBubKSn030cSWI8Y6trnkLNz7EZ-kNvVX6eetseloAzQmvxTCR188tz2baYFWguzIYAB0eCJx-qFePn3G2tirGJYrPaEwB8qdMxkFqYz5jQAAYYzPwjPS4MXFPlm2CcAS4da9k0eSmQ-nESPi2u-P-3NYVqRYhnpAxPruVd08S8mRLC9ljnOnqMx-tD3MbUWs0eOk8dkgL8Pfu92JfNAcaiaksHJ7dRENO0tEFEKpLaRr4-F7Ev2lGrA-7HbmN4eIHow",
	"IDTokenClaims": {
		"iss": "https://accounts.google.com",
		"azp": "448771483088-25fslbvr9thmmi3acvo3omu0v1j6lqab.apps.googleusercontent.com",
		"aud": "448771483088-25fslbvr9thmmi3acvo3omu0v1j6lqab.apps.googleusercontent.com",
		"sub": "113632458324056836621",
		"email": "supsup5642@gmail.com",
		"email-verified": true,
		"at-hash": "-hJ7DTDBbNEil-q6KmV-iA",
		"nonce": "LezlAcXNVzcttleOWHXiUA",
		"name": "sss sss",
		"picture": "https://lh3.googleusercontent.com/a-/AOh14Gj--u2mX-8AHNCrxbxfbNGTzbrxBbRlLhOgi3s4tQ=s96-c",
		"given-name": "sss",
		"family-name": "sss",
		"locale": "ko",
		"iat": 1648394230,
		"exp": 1648397830
	}
}
```

Access "http://127.0.0.1:3000" and perform Google Login to check the **ID Token** as shown in [Text 1].

## 6. Assume Role with Web Identity

```shell
$ aws configure
AWS Access Key ID [None]: <Access Key>
AWS Secret Access Key [None]: <Secret Access Key>
Default region name [None]: ap-northeast-2
Default output format [None]:

$ aws ec2 describe-instances
An error occurred (UnauthorizedOperation) when calling the DescribeInstances operation: You are not authorized to perform this operation.
```

Configure aws CLI with the no-policy-user User. Since the no-policy-user User has no permissions, you can see that the EC2 Describe operation cannot be performed.

```shell
$ aws sts assume-role-with-web-identity --role-arn arn:aws:iam::278805249149:role/google-oidc-role --role-session-name google-oidc-session --web-identity-token eyJhbGciOiJSUzI1NiIsImtpZCI6IjU4YjQyOTY2MmRiMDc4NmYyZWZlZmUxM2MxZWIxMmEyOGRjNDQyZDAiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FjY291bnRzLmdvb2dsZS5jb20iLCJhenAiOiI0NDg3NzE0ODMwODgtMjVmc2xidnI5dGhtbWkzYWN2bzNvbXUwdjFqNmxxYWIuYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJhdWQiOiI0NDg3NzE0ODMwODgtMjVmc2xidnI5dGhtbWkzYWN2bzNvbXUwdjFqNmxxYWIuYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJzdWIiOiIxMTM2MzI0NTgzMjQwNTY4MzY2MjEiLCJlbWFpbCI6InN1cHN1cDU2NDJAZ21haWwuY29tIiwiZW1haWxfdmVyaWZpZWQiOnRydWUsImF0X2hhc2giOiJfaEo3RFREQmJORWlsX3E2S21WLWlBIiwibm9uY2UiOiJMZXpsQWNYTlZ6Y3R0bGVPV0hYaVVBIiwibmFtZSI6InNzcyBzc3MiLCJwaWN0dXJlIjoiaHR0cHM6Ly9saDMuZ29vZ2xldXNlcmNvbnRlbnQuY29tL2EtL0FPaDE0R2otLXUybVgtOEFITkNyeGJ4ZmJOR1R6YnJ4QmJSbExoT2dpM3M0dFE9czk2LWMiLCJnaXZlbl9uYW1lIjoic3NzIiwiZmFtaWx5X25hbWUiOiJzc3MiLCJsb2NhbGUiOiJrbyIsImlhdCI6MTY0ODM5NDIzMCwiZXhwIjoxNjQ4Mzk3ODMwfQ.lAikNJYXUJ7U1JEotxRK5-4OqODZX8tWBAEzBKKtze10nadkH3mu0JRHNhqdg6UMFKZdWMfp15iKghn5KxwBubKSn030cSWI8Y6trnkLNz7EZ-kNvVX6eetseloAzQmvxTCR188tz2baYFWguzIYAB0eCJx-qFePn3G2tirGJYrPaEwB8qdMxkFqYz5jQAAYYzPwjPS4MXFPlm2CcAS4da9k0eSmQ-nESPi2u-P-3NYVqRYhnpAxPruVd08S8mRLC9ljnOnqMx-tD3MbUWs0eOk8dkgL8Pfu92JfNAcaiaksHJ7dRENO0tEFEKpLaRr4-F7Ev2lGrA-7HbmN4eIHow

{
    "Credentials": {
        "AccessKeyId": "ASIAUB2QWPR6ZMNNER6X",
        "SecretAccessKey": "eCy8W3DtDFQ3H3s0GVKzeaaMDOmoJjsICkl5tXc9",
        "SessionToken": "IQoJb3JpZ2luX2VjECAaDmFwLW5vcnRoZWFzdC0yIkcwRQIgLFvzWmsRW+Hi6Wfvausj4AopclJ+N9S/1tWBowjQI1cCIQCHqPbWK61jnA9V1kZUIGVUzJd2MVms4wLbA3+zPSmEDCqBAwip//////////8BEAMaDDI3ODgwNTI0OTE0OSIMP8bP+U8sEuV8NkQDKtUC9/DPj4rz7hZDFgGUzpIGTmf1OQjkLQmSgCEdOXhWvIwzVPG2nq0YoeeZoEjiOWO2MoK2Dgi26f6AkOnUcffxnpCnil8zV+odFdMXX4+meOf2K40i8/4UQHYMf+CDJQbgNVNAT/5zxUcLdFn5QJwARnPusuNEZufiMs+TilN3j2fRrTOY+jWF2GRiCIZKVO55AH2naSFQukB5nXjKKlbJR2evZlhoEAm1TWPMjnW2KatDx/sGWgxD69uw6TWGe72WJQ+KerX4R2usLuTBfG08RrY6+QVuj3TXRmzL31k3lTeDhxgi7j2taTguehoyr33qRjObMzc57DQW7iDe4Gd15U9o30iNXuGHAK0M3t1E6dviyQ72+zFcrqqYFSU/F9MuZsWUCDB9T5EQ4g5Sk6cTRrK2Z+stPpxh3JPVAo4IAeNtXUNt30NXHVpN4Iz4S121IT+DfKswy4qCkgY6yAF80yMiCaF+42I93OBbtNPS9jkLkhpGNgMumssl+O1O6gv2lAd0kK82z9uYxhbAPmEkCWvvmPny0Y3Vr6jaAShSuqu0Yz3eG0ViAZseGUHb0OJMo7RwfsCpJEaGXUAB04RfbPu5Gd0SjEg5aLnBixUknnx2IoOaZLgnowq1GjS5grdI+9jeSFVl8vkPxIEVrsPvdFlQWdN3/ECMea+V1cTT0rjDnUGtTdYgHuNz+mEt/H/4WDin9k7g5X5xtQhnnWHrtFPhkdDCtA==",
        "Expiration": "2022-03-27T16:39:55+00:00"
    },
    "SubjectFromWebIdentityToken": "113632458324056836621",
    "AssumedRoleUser": {
        "AssumedRoleId": "AROAUB2QWPR6X3BYU2DG7:google-oidc-session",
        "Arn": "arn:aws:sts::278805249149:assumed-role/google-oidc-role/google-oidc-session"
    },
    "Provider": "accounts.google.com",
    "Audience": "448771483088-25fslbvr9thmmi3acvo3omu0v1j6lqab.apps.googleusercontent.com"
}
```

Perform an Assume Role with Web Identity operation along with the obtained ID Token to obtain temporary AccessKeyID, SecretAccessKey, and SessionToken.

```shell
$ export AWS-ACCESS-KEY-ID=ASIAUB2QWPR6ZMNNER6X
$ export AWS-SECRET-ACCESS-KEY=eCy8W3DtDFQ3H3s0GVKzeaaMDOmoJjsICkl5tXc9
$ export AWS-SESSION-TOKEN=IQoJb3JpZ2luX2VjECAaDmFwLW5vcnRoZWFzdC0yIkcwRQIgLFvzWmsRW+Hi6Wfvausj4AopclJ+N9S/1tWBowjQI1cCIQCHqPbWK61jnA9V1kZUIGVUzJd2MVms4wLbA3+zPSmEDCqBAwip//////////8BEAMaDDI3ODgwNTI0OTE0OSIMP8bP+U8sEuV8NkQDKtUC9/DPj4rz7hZDFgGUzpIGTmf1OQjkLQmSgCEdOXhWvIwzVPG2nq0YoeeZoEjiOWO2MoK2Dgi26f6AkOnUcffxnpCnil8zV+odFdMXX4+meOf2K40i8/4UQHYMf+CDJQbgNVNAT/5zxUcLdFn5QJwARnPusuNEZufiMs+TilN3j2fRrTOY+jWF2GRiCIZKVO55AH2naSFQukB5nXjKKlbJR2evZlhoEAm1TWPMjnW2KatDx/sGWgxD69uw6TWGe72WJQ+KerX4R2usLuTBfG08RrY6+QVuj3TXRmzL31k3lTeDhxgi7j2taTguehoyr33qRjObMzc57DQW7iDe4Gd15U9o30iNXuGHAK0M3t1E6dviyQ72+zFcrqqYFSU/F9MuZsWUCDB9T5EQ4g5Sk6cTRrK2Z+stPpxh3JPVAo4IAeNtXUNt30NXHVpN4Iz4S121IT+DfKswy4qCkgY6yAF80yMiCaF+42I93OBbtNPS9jkLkhpGNgMumssl+O1O6gv2lAd0kK82z9uYxhbAPmEkCWvvmPny0Y3Vr6jaAShSuqu0Yz3eG0ViAZseGUHb0OJMo7RwfsCpJEaGXUAB04RfbPu5Gd0SjEg5aLnBixUknnx2IoOaZLgnowq1GjS5grdI+9jeSFVl8vkPxIEVrsPvdFlQWdN3/ECMea+V1cTT0rjDnUGtTdYgHuNz+mEt/H/4WDin9k7g5X5xtQhnnWHrtFPhkdDCtA==

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


---
title: AWS Certificate Manager Certificate Creation / Using certbot
---

## 1. Execution Environment

* Macbook, Monterey
* Domain
  * aws-playground.dev
  * *.aws-playground.dev

## 2. certbot, certbot-dns-route53 Plugin Installation

```shell
$ sudo python3 -m venv /opt/certbot/
$ sudo /opt/certbot/bin/pip install --upgrade pip
$ sudo /opt/certbot/bin/pip install certbot
$ sudo ln -s /opt/certbot/bin/certbot /usr/local/bin/certbot
$ sudo /opt/certbot/bin/pip install certbot-dns-route53
```

Install certbot and certbot-dns-route53 Plugin for certificate creation.

## 3. letsencrypt IAM User Creation & Configuration, Access Key Generation

```shell
$ aws iam create-user --user-name letsencrypt
{
    "User": {
        "Path": "/",
        "UserName": "letsencrypt",
        "UserId": "AIDA2S2LVTEOIYTEXDCLM",
        "Arn": "arn:aws:iam::727618787612:user/letsencrypt",
        "CreateDate": "2022-12-05T03:37:20+00:00"
    }
}

$ aws iam create-access-key --user-name letsencrypt
{
    "AccessKey": {
        "UserName": "letsencrypt",
        "AccessKeyId": "{AWS-Access-ID}",
        "Status": "Active",
        "SecretAccessKey": "{AWS-Secret-Key}",
        "CreateDate": "2022-12-05T03:38:49+00:00"
    }
}
```

Create the letsencrypt IAM account used by certbot and the Access Key for the letsencrypt IAM account.

## 4. Policy Application to letsencrypt IAM User

```json {caption="[File 1] letsencrypt-policy.json", linenos=table}
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "route53:ListHostedZones",
        "route53:GetChange",
        "route53:ChangeResourceRecordSets"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
```

Create the letsencrypt-policy.json file with the contents of [File 1] for the Policy for the letsencrypt IAM account.

```shell
$ aws iam create-policy --policy-name letsencrypt-policy --policy-document file://letsencrypt-policy.json
{
    "Policy": {
        "PolicyName": "letsencrypt-policy",
        "PolicyId": "ANPA2S2LVTEOK36NCEQX6",
        "Arn": "arn:aws:iam::727618787612:policy/letsencrypt-policy",
        "Path": "/",
        "DefaultVersionId": "v1",
        "AttachmentCount": 0,
        "PermissionsBoundaryUsageCount": 0,
        "IsAttachable": true,
        "CreateDate": "2022-12-05T04:03:02+00:00",
        "UpdateDate": "2022-12-05T04:03:02+00:00"
    }
}

$ aws iam attach-user-policy --user-name letsencrypt --policy-arn arn:aws:iam::727618787612:policy/letsencrypt-policy
```

Create a Policy using [File 1] and configure it for the letsencrypt IAM account.

## 5. Certificate Creation Using certbot

```text {caption="[File 2] ~/.aws/credentials", linenos=table}
[letsencrypt]
aws-access-key-id={AWS-Access-ID}
aws-secret-access-key={AWS-Secret-Key}
```

Create the ~/.aws/credentials file used by certbot with the contents of [File 2].

```shell
$ cd ~ && mkdir certbot && cd certbot
$ certbot certonly --dns-route53 -n -d "aws-playground.dev" -d "*.aws-playground.dev" --email supsup5642@gmail.com --agree-tos --config-dir . --work-dir . --logs-dir .
Saving debug log to /Users/ssup2/certbot/letsencrypt.log
Account registered.
Requesting a certificate for aws-playground.dev and *.aws-playground.dev

Successfully received certificate.
Certificate is saved at: /Users/ssup2/certbot/live/aws-playground.dev/fullchain.pem
Key is saved at:         /Users/ssup2/certbot/live/aws-playground.dev/privkey.pem
This certificate expires on 2023-03-05.
These files will be updated when the certificate renews.

NEXT STEPS:
- The certificate will need to be renewed before it expires. Certbot can automatically renew the certificate in the background, but you may need to take steps to enable that functionality. See https://certbot.org/renewal-setup for instructions.

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
If you like Certbot, please consider supporting our work by:
 * Donating to ISRG / Let's Encrypt:   https://letsencrypt.org/donate
 * Donating to EFF:                    https://eff.org/donate-le
```

Create a certificate using certbot.

## 6. Register Created Certificate in AWS Certificate Manager

```shell
$ cd ~/certbot/live/aws-playground.dev/live/aws-playground.dev
$ aws acm import-certificate --region ap-northeast-2 --certificate fileb://cert.pem --private-key fileb://privkey.pem --certificate-chain fileb://chain.pem
```

Register the certificate in AWS Certificate Manager.

## 7. References

* [https://certbot.eff.org/instructions?ws=other&os=pip](https://certbot.eff.org/instructions?ws=other&os=pip)
* [https://www.skyer9.pe.kr/wordpress/?p=823](https://www.skyer9.pe.kr/wordpress/?p=823)


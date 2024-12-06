---
title: HMAC (Hash based Message Authentication Code)
---

## 1. HMAC

{{< figure caption="[Figure 1] HMAC" src="images/hmac.png" width="700px" >}}

HMAC (Hash based Message Authentication Code)은 Hashing 기법을 통해서 Data의 무결성을 보장하는 기법이다. [Figure 1]은 HMAC 과정을 나타내고 있다. Message를 보내는 발신자와 수신자 모두 동일한 MAC 알고리즘과 Secret Key를 가지고 있다. 여기서 MAC Algorithm은 Hashing 함수를 의미하며, 일반적으로 `SHA-256` 알고리즘을 많이 이용한다. Secret Key는 원본 Message에 추가되어 Message와 같이 Hashing 되는 값이며, 외부에 노출되면 안되는 값이다.

송신자는 MAC Algorithm과 Secret Key를 이용하여 MAC을 생성한 다음 원본 Message와 함께 MAC을 같이 전송한다. 수신자는 수신한 Message를 이용하여 발신자와 동일한 MAC Algorithm과 Secret Key를 활용하여 MAC을 생성하고, 수신받은 MAC과 비교하여 Message의 무결성을 검증한다.

### 1.1. with Rest API

HMAC은 Rest API에서도 Message의 `무결성 보장`과 `인증` 과정을 HMAC을 활용한다. MAC 값은 일반적으로 HTTP, GRPC의 Header 값에 포함되어 발신자에서 수신자로 같이 전송된다. HMAC을 포함하는 Header는 아직까지 표준이 정해져 있지 않으며 API마다 별도로 지정하여 이용한다.

```text

```

## 2. 참조

* HMAC : [https://m.blog.naver.com/techtrip/221723355441](https://m.blog.naver.com/techtrip/221723355441)
* HMAC : [https://velog.io/@stop7089/HMAC-%EC%9D%B4%EB%9E%80](https://velog.io/@stop7089/HMAC-%EC%9D%B4%EB%9E%80)
* HMAC : [https://haneepark.github.io/2018/04/22/hmac-authentication/](https://haneepark.github.io/2018/04/22/hmac-authentication/)
* HMAC : [https://stackoverflow.com/questions/22683952/security-issue-hmac-in-header-vs-https-or-both](https://stackoverflow.com/questions/22683952/security-issue-hmac-in-header-vs-https-or-both)
* AWS Authentication : [https://docs.aws.amazon.com/ko_kr/IAM/latest/UserGuide/reference_sigv-create-signed-request.html](https://docs.aws.amazon.com/ko_kr/IAM/latest/UserGuide/reference_sigv-create-signed-request.html)
* Azure Authentication : [https://learn.microsoft.com/ko-kr/azure/azure-app-configuration/rest-api-authentication-hmac](https://learn.microsoft.com/ko-kr/azure/azure-app-configuration/rest-api-authentication-hmac)

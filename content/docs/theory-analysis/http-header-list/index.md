---
title: HTTP Header 목록
draft: true
---

## 1. HTTP Header

### 1.1. General Header

General Header는 요청과 응답 모두에서 사용되는 Header를 의미한다.

#### 1.1.1. Date

``` {caption="[Text 1] Date Header Format"}
Date: <day-name>, <day> <month> <year> <hour>:<minute>:<second> GMT
```

Date Header는 **요청 또는 응답 메세지의 생성 날짜와 시간**을 나타낸다. [Text 1]은 Date Header의 Format을 나타낸다.

* `<day-name>` : 요일을 나타내며, `Mon`, `Tue`, `Wed`, `Thu`, `Fri`, `Sat`, `Sun` 문자열을 이용한다.
* `<day>` : 일을 나타낸다.
* `<month>` : 월을 나타내며, `Jan`, `Feb`, `Mar`, `Apr`, `May`, `Jun`, `Jul`, `Aug`, `Sep`, `Oct`, `Nov`, `Dec` 문자열을 이용한다.
* `<year>` : 년을 나타낸다.
* `<hour>` : 시간을 나타낸다.
* `<minute>` : 분을 나타낸다.
* `<second>` : 초를 나타낸다.
* `GMT` : 그리니치 표준시를 의미하며, 항상 GMT 시간을 사용한다.

``` {caption="[Text 2] Date Header Example"}
Date: Wed, 21 Oct 2015 07:28:00 GMT
Date: Mon, 19 Oct 2015 07:28:00 GMT
Date: Tue, 20 Oct 2015 07:28:00 GMT
```

[Text 2]는 Date Header의 몇가지 예시를 나타낸다.

#### 1.1.2. Connection

``` {caption="[Text 3] Connection Header Format"}
Connection: <connection-option>
```

Connection Header는 연결 제어 정보를 나타낸다. [Text 3]은 Connection Header의 Format을 나타낸다.

* `<connection-option>` : 연결 제어 설정을 나타낸다.
  * `close` : 요청 처리 후 연결을 닫는다.
  * `keep-alive` : 요청 처리 후 연결을 유지한다.
  
Connection Header가 없는 경우 **HTTP/1.0**에서는 `close` 설정을 기본으로 사용하며, **HTTP/1.1**에서는 `keep-alive` 설정을 기본으로 사용한다. 일반적으로 Client가 요청하는 연결 제어 설정에 맞추어 Server가 동작한다. 즉 요청과 응답의 Connection Header는 일반적으로 같은 설정 값을 갖는다. 하지만 Server의 상황에 따라서 Client가 `keep-alive` 설정으로 요청을 보내어 계속해서 연결을 유지하고 싶어도, Server가 `close` 설정 값으로 응답하고 연결을 종료하는 경우도 발생할 수 있다.

#### 1.1.3. Cache-Control

``` {caption="[Text 4] Cache-Control Header Format"}
Cache-Control: <cache-directive>
```

Cache-Control Header는 Cache 정책을 지시하기 위한 Header이다. 여기서 Cache는 Browser에 위치한 **Local Cache**와 CDN, Proxy Server에 위치한 **Shared Cache**를 의미한다. [Text 4]은 Cache-Control Header의 Format을 나타낸다. Client가 Cache-Control Header를 포함하여 요청을 보내는 경우 Shared Cache에 대한 정책 지시를 의미하며, 반대로 Server가 Cache-Control Header를 포함하여 응답을 보내는 경우 Local Cache에 대한 정책 지시를 의미한다. 따라서 Client와 Server가 이용하는 Cache Directive가 다르다.

* Client의 `<cache-directive>` : Shared Cache에 대한 정책 지시를 의미한다.
  * `max-age=<seconds>` : Shared Cache는 seconds 미만의 Caching된 데이터가 있을 경우에는 Caching된 데이터를 응답하고, seconds 이상의 Caching된 데이터가 있을 경우에는 Orgin Server로부터 새로운 Data를 다시 Caching후에 응답한다.
  * `max-stale=<seconds>` : Shared Cache는 `데이터의 유효기간 + seconds` 미만의 Caching된 데이터가 있을 경우에는 Caching된 데이터를 응답하고, `데이터의 유효기간 + seconds` 이상의 Caching된 데이터가 있을 경우에는 Orgin Server로부터 새로운 Data를 다시 Caching후에 응답한다.
  * `min-fresh=<seconds>` : Shared Cache는 `데이터의 유효기간 - seconds` 미만의 Caching된 데이터가 있을 경우에는 Caching된 데이터를 응답하고, `데이터의 유효기간 - seconds` 이상의 Caching된 데이터가 있을 경우에는 Orgin Server로부터 새로운 Data를 다시 Caching후에 응답한다.
  * `no-cache` : Shared Cache는 반드시 Orgin Server로부터 원본 Data를 검증한 다음 응답한다. `If-Modified-Since`, `If-None-Match` Header와 같이 이용된다.
  * `no-store` : Shared Cache는 Origin Server로 부터 받은 데이터를 저장하지 않는다. Client는 항상 Orgin Server로부터 새로운 Data를 받는다.
  * `no-transform` : Shared Cache는 데이터를 변환하지 않는다.
  * `only-if-cached` : Shared Cache는 Caching된 데이터가 있는지 확인하고 있으면 해당 데이터를 응답하고, 없으면 응답하지 않는다.

* Server의 `<cache-directive>` : Local Cache 또는 Shared Cache에 대한 정책 지시를 의미한다. 여러개의 Cache Directive를 사용될 수 있다.
  * `max-age=<seconds>` : Local Cache는 seconds 미만의 Caching된 데이터가 있을 경우에는 Caching된 데이터를 응답하고, seconds 이상의 Caching된 데이터가 있을 경우에는 Orgin Server로부터 새로운 Data를 다시 Caching후에 응답한다.
  * `s-maxage=<seconds>` : Shared Cache는 seconds 미만의 Caching된 데이터가 있을 경우에는 Caching된 데이터를 응답하고, seconds 이상의 Caching된 데이터가 있을 경우에는 Orgin Server로부터 새로운 Data를 다시 Caching후에 응답한다.
  * `no-cache` : Local Cache는 반드시 Orgin Server로부터 원본 Data를 검증한 다음 응답한다.
  * `no-store` : Local Cache는 데이터를 Caching하지 않는다. Client는 항상 Orgin Server로부터 새로운 Data를 받는다.
  * `no-transform` : Local Cache는 데이터를 변환하지 않는다.
  * `must-revalidate` : Local Cache는 데이터가 만료되었을 경우 반드시 Orgin Server로부터 원본 Data를 검증한 다음 응답한다.
  * `proxy-revalidate` : Shared Cache는 데이터가 만료되었을 경우 반드시 Orgin Server로부터 원본 Data를 검증한 다음 응답한다.
  * `private` : Local Cache에만 데이터를 Caching한다.
  * `public` : Local Cache와 Shared Cache에 데이터를 Caching한다.
  * `immutable` : Orgin Server로부터 받은 데이터가 변경되지 않는 것을 의미한다.
  * `stale-while-revalidate=<seconds>` : Local Cache는 데이터가 만료 되었을경우 seconds 시간 동안 Orgin Server로부터 원본 Data를 가져오며, Data를 가져오면서 캐시된 유요하지 않는 데이터로 임시 응답한다.
  * `stale-if-error=<seconds>` : Local Cache는 Origin Server가 5XX 응답을 보내는 경우 seconds 시간 동안 Caching된 데이터로 응답한다.

일반적으로 Client는 Request Header에서 `no-cache` 값을 사용하며, Server는 Response Header에서 `no-cache` 값을 사용한다.

### 1.2. Request Header

Request Header는 요청에서 사용되는 Header를 의미한다.

#### 1.2.1. Host

``` {caption="[Text 5] Host Header Format"}
Host: <host>[:<port>]
```

Host Header는 요청을 전송할 Host의 이름과 포트 번호를 나타낸다. [Text 5]는 Host Header의 Format을 나타낸다. HTTP 이용 시 `80`번 Port 또는 HTTPS 이용 시 `443`번 Port를 기본으로 사용하며, 기본 포트 번호를 사용하지 않는 경우 포트 번호를 생략할 수 있다.

``` {caption="[Text 6] Host Header Example"}
Host: example.com
Host: example.com:8080
```

[Text 6]은 Host Header의 몇가지 예시를 나타낸다.

#### 1.2.2. Authorization

``` {caption="[Text 7] Authorization Header Format"}
Authorization: <auth-scheme> <authorization-parameters>
```

Authorization Header는 요청을 보내는 Client의 인증 정보를 나타낸다. [Text 7]은 Authorization Header의 Format을 나타낸다.

* `<auth-scheme>` : 인증 방식을 나타낸다.
  * `Basic` : 사용자 이름과 비밀번호를 Base64 Encoding 방식으로 인코딩하여 전송한다.
  * `Bearer` : Token 인증 방식을 의미한다.
  * `Digest` : Digest 인증 방식을 의미한다. 요청의 Header와 Body를 Hashing 하여 인증 정보를 전송한다.
  * `AWS4-HMAC-SHA256` : AWS 인증 방식을 의미한다.
* `<authorization-parameters>` : 인증에 필요한 Parameter를 나타낸다.

``` {caption="[Text 8] Authorization Header Example"}
Authorization: Basic YWxhZGRpbjpvcGVuc2VzYW1l
Authorization: Bearer <token>
Authorization: Digest username="<username>", realm="<realm>", qop=<qop>, nonce="<nonce>", uri="<uri>", response="<response>", opaque="<opaque>"
Authorization: AWS4-HMAC-SHA256 Credential=<access_key_id>/<date>/<region>/<service>/aws4_request, SignedHeaders=<signed_headers>, Signature=<signature>
```

[Text 8]은 Authorization Header의 몇가지 예시를 나타낸다.

#### 1.2.3. User-Agent

``` {caption="[Text 9] User-Agent Header Format"}
User-Agent: <user-agent>
```

User-Agent Header는 요청을 보내는 Client의 정보를 나타낸다. [Text 9]은 User-Agent Header의 Format을 나타낸다.

``` {caption="[Text 10] User-Agent Header Example"}
User-Agent: curl/7.64.1
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36
```

[Text 10]은 User-Agent Header의 몇가지 예시를 나타낸다. curl Client와 MacOS의 Chrome Browser의 예시를 나타낸다.

#### 1.2.4. If-Modified-Since

``` {caption="[Text 11] If-Modified-Since Header Format"}
If-Modified-Since: <day-name>, <day> <month> <year> <hour>:<minute>:<second> GMT
```

If-Modified-Since Header는 Client가 특정 날짜, 시간 이후에 변경된 Resource만 받아오기 위해 사용되는 Header이다아 [Text 11]은 If-Modified-Since Header의 Format을 나타낸다.

* `<day-name>` : 요일을 나타내며, `Mon`, `Tue`, `Wed`, `Thu`, `Fri`, `Sat`, `Sun` 문자열을 이용한다.
* `<day>` : 일을 나타낸다.
* `<month>` : 월을 나타내며, `Jan`, `Feb`, `Mar`, `Apr`, `May`, `Jun`, `Jul`, `Aug`, `Sep`, `Oct`, `Nov`, `Dec` 문자열을 이용한다.
* `<year>` : 년을 나타낸다.
* `<hour>` : 시간을 나타낸다.
* `<minute>` : 분을 나타낸다.
* `<second>` : 초를 나타낸다.
* `GMT` : 그리니치 표준시를 의미하며, 항상 GMT 시간을 사용한다.

``` {caption="[Text 12] If-Modified-Since Header Example"}
If-Modified-Since: Wed, 21 Oct 2015 07:28:00 GMT
```

[Text 12]은 If-Modified-Since Header의 예시를 나타낸다. 2015년 10월 21일 오전 7시 28분 00초 이후에 변경된 Resource가 존재하는 경우에만 Server는 `200 OK` 응답을 보내며, 만약 Resource가 변경되지 않았을 경우에는 `304 Not Modified` 응답을 보낸다.

#### 1.2.5. If-None-Match

``` {caption="[Text 13] If-None-Match Header Format"}
If-None-Match: <etag>
``` 

If-None-Match Header는 요청을 보내는 Client가 특정 Resource의 Version을 확인하기 위해 사용되는 Header이다. [Text 13]은 If-None-Match Header의 Format을 나타낸다.

* `<etag>` : Resource의 Version을 나타낸다.

``` {caption="[Text 14] If-None-Match Header Example"}
If-None-Match: "v1.0"
If-None-Match: "v1.1", "v1.2", "v2.0"
```

[Text 14]은 If-None-Match Header의 몇가지 예시를 나타낸다. 첫번째 예제의 경우 Server는 Client가 요청한 `v1.0` 버전의 Resource가 갱신 되었을 경우 `200 OK` 응답을과 함께 갱신된 버전의 Etag를 `ETag` Header에 포함하여 응답한다. 만약 `v1.0` 버전의 Resource가 갱신되지 않았을 경우 `304 Not Modified` 응답을 보낸다. 두번째 예제와 같이 여러개의 Etag를 지정할 수도 있다. 여러개의 Etag를 지정할 경우 하나의 Etag만 일치해도 Server는 `304 Not Modified` 응답을 보낸다.

#### 1.2.6. Accept

``` {caption="[Text 15] Accept Header Format"}
Accept: <media-type>, <media-type>...
```

Accept Header는 요청을 보내는 클라이언트가 받을 수 있는 Media Type을 나타낸다. [Text 15]는 Accept Header의 Format을 나타낸다. 여러개의 Media Type을 지정할 수 있으며, 각 Media Type은 `,` 문자로 구분한다.

* `<media-type>` : Media Type을 나타낸다.
  * `text/html` : HTML 문서
  * `application/xhtml+xml` : XHTML 문서
  * `application/xml` : XML 문서
  * `*/*` : 모든 Media Type

``` {caption="[Text 16] Accept Header Example"}
Accept: text/html
Accept: text/html, application/xhtml+xml, application/xml;q=0.9, */*;q=0.8
```

[Text 16]은 Accept Header의 몇가지 예시를 나타낸다. `q` 값은 우선순위를 나타내며, 0에서 1 사이의 값을 갖는다. `q` 값이 높을수록 우선순위가 높다. `q` 값이 없는 경우 `1`로 간주한다. 따라서 [Text 16]의 두번째 예시에서는 `text/html`과 `application/xhtml+xml`의 우선순위가 가장 높으며, `application/xml`, `*/*` 순서대로 우선순위가 낮아진다.

#### 1.2.7. Accept-Encoding

``` {caption="[Text 17] Accept-Encoding Header Format"}
Accept-Encoding: <encoding-option>, <encoding-option>...
```

Accept-Encoding Header는 요청을 보내는 클라이언트가 받을 수 있는 Encoding을 나타낸다. [Text 17]은 Accept-Encoding Header의 Format을 나타낸다. 여러개의 Encoding을 지정할 수 있으며, 각 Encoding은 `,` 문자로 구분한다.

* `<encoding-option>` : Encoding을 나타낸다.
  * `gzip` : gzip Encoding
  * `deflate` : deflate Encoding
  * `br` : brotli Encoding
  * `identity` : Encoding을 사용하지 않는다.

``` {caption="[Text 18] Accept-Encoding Header Example"}
Accept-Encoding: gzip;q=0.9,deflate;q=0.8,br;q=1.0
Accept-Encoding: identity
```

[Text 18]은 Accept-Encoding Header의 몇가지 예시를 나타낸다. `q` 값은 우선순위를 나타내며, 0에서 1 사이의 값을 갖는다. `q` 값이 높을수록 우선순위가 높다. `q` 값이 없는 경우 `1`로 간주한다. 따라서 [Text 18]의 첫번째 예시에서는 `br`의 우선순위가 가장 높으며, `gzip`, `deflate` 순서대로 우선순위가 낮아진다.

#### 1.2.8. Accept-Language

``` {caption="[Text 19] Accept-Language Header Format"}
Accept-Language: <language-range>, <language-range>...
```

Accept-Language Header는 요청을 보내는 클라이언트가 받을 수 있는 언어를 나타낸다. [Text 19]은 Accept-Language Header의 Format을 나타낸다. 여러개의 언어를 지정할 수 있으며, 각 언어는 `,` 문자로 구분한다.

* `<language-range>` : 언어 범위를 나타낸다.
  * `en-US` : 미국 영어
  * `en-GB` : 영국 영어
  * `ko` : 한국어
  * `*` : 모든 언어

``` {caption="[Text 20] Accept-Language Header Example"}
Accept-Language: en-US,ko;q=0.8
Accept-Language: en-GB,en;q=0.9,ko;q=0.8
```

[Text 20]은 Accept-Language Header의 몇가지 예시를 나타낸다. `q` 값은 우선순위를 나타내며, 0에서 1 사이의 값을 갖는다. `q` 값이 높을수록 우선순위가 높다. `q` 값이 없는 경우 `1`로 간주한다. 따라서 [Text 16]의 첫번째 예시에서는 `en-US`의 우선순위가 가장 높으며, 다음으로 `ko`의 우선순위가 높다. 두번째 예시에서는 `en-GB`의 우선순위가 가장 높으며, 다음으로 `en`, `ko` 순서대로 우선순위가 낮아진다.

#### 1.2.9. X-Forwarded-For

``` {caption="[Text 21] X-Forwarded-For Header Format"}
X-Forwarded-For: <client-ip>, <proxy-ip>, <proxy-ip>, ...
```

X-Forwarded-For Header는 요청을 전송하는 Client의 IP 및 Proxy Server의 IP 정보를 나타낸다. [Text 21]은 X-Forwarded-For Header의 Format을 나타낸다. 하나의 Client IP와 다수의 Proxy Server의 IP 정보가 포함될 수 있다.

* `<client-ip>` : 요청을 보내는 클라이언트의 IP 주소를 나타낸다.
* `<proxy-ip>` : 요청을 처리하는 Proxy Server의 IP 주소를 나타낸다. 요청을 처리하는 Proxy Server가 여러개인 경우 여러개의 Proxy Server의 IP가 요청을 처리하는 순서대로 순차적으로 붙는다.

``` {caption="[Text 22] X-Forwarded-For Header Example"}
X-Forwarded-For: 203.0.113.45, 10.0.0.1, 192.168.10.2
```

[Text 22]는 X-Forwarded-For Header의 몇가지 예시를 나타낸다. Client의 IP 주소가 `203.0.113.45`, 첫번째 Proxy Server의 IP 주소가 `10.0.0.1`, 두번째 Proxy Server의 IP 주소가 `192.168.10.2`인 것을 확인할 수 있다.

#### 1.2.10. X-Forwarded-Host

``` {caption="[Text 23] X-Forwarded-Host Header Format"}
X-Forwarded-Host: <host>
```

X-Forwarded-Host Header는 Client가 원래 요청한 Host 정보를 보존하기 위해 사용되는 Header이다. Host를 기반으로 요청을 라우팅하는 경우 Host Header가 변경될 수 있기 때문이다. [Text 23]은 X-Forwarded-Host Header의 Format을 나타낸다.

* `<host>` : Host 정보를 나타낸다.

``` {caption="[Text 24] X-Forwarded-Host Header Example"}
X-Forwarded-Host: example.com
X-Forwarded-Host: ssup2.com
```

[Text 24]은 X-Forwarded-Host Header의 몇가지 예시를 나타낸다.

#### 1.2.11. X-Forwarded-Port

``` {caption="[Text 25] X-Forwarded-Port Header Format"}
X-Forwarded-Port: <port>
```

X-Forwarded-Port Header는 Client가 원래 요청한 Port 정보를 보존하기 위해 사용되는 Header이다. 요청이 CDN, Load Balancer를 거치면서 Port가 변경될 수 있기 때문이다. [Text 25]는 X-Forwarded-Port Header의 Format을 나타낸다.

* `<port>` : Port 정보를 나타낸다.

``` {caption="[Text 26] X-Forwarded-Port Header Example"}
X-Forwarded-Port: 80
X-Forwarded-Port: 443
```

[Text 26]은 X-Forwarded-Port Header의 몇가지 예시를 나타낸다.

#### 1.2.12. X-Forwarded-Proto

``` {caption="[Text 27] X-Forwarded-Proto Header Format"}
X-Forwarded-Proto: <protocol>
```

X-Forwarded-Proto Header는 Client가 원래 요청한 프로토콜 정보를 보존하기 위해 사용되는 Header이다. 요청이 CDN, Load Balancer를 거치면서 프로토콜 정보가 변경될 수 있기 때문이다. [Text 27]는 X-Forwarded-Proto Header의 Format을 나타낸다.

* `<protocol>` : 프로토콜 정보를 나타낸다.

``` {caption="[Text 28] X-Forwarded-Proto Header Example"}
X-Forwarded-Proto: http
X-Forwarded-Proto: https
```

[Text 22]은 X-Forwarded-Proto Header의 몇가지 예시를 나타낸다.

#### 1.2.13. X-Forwarded-Server

``` {caption="[Text 23] X-Forwarded-Server Header Format"}
X-Forwarded-Server: <server>
```

X-Forwarded-Server Header는 요청을 처리한 Proxy Server의 이름을 나타낸다. [Text 23]는 X-Forwarded-Server Header의 Format을 나타낸다. 요청이 다수의 Proxy Server를 지나도 마지막 Proxy Server의 이름만 포함된다.

* `<server>` : 서버 이름을 나타낸다.

``` {caption="[Text 24] X-Forwarded-Server Header Example"}
X-Forwarded-Server: proxy1.example.com
```

[Text 24]은 X-Forwarded-Server Header의 몇가지 예시를 나타낸다.

#### 1.2.14. X-Forwarded-User

``` {caption="[Text 25] X-Forwarded-User Header Format"}
X-Forwarded-User: <user>
```

X-Forwarded-User Header는 요청을 전송한 사용자 정보를 나타낸다. [Text 25]는 X-Forwarded-User Header의 Format을 나타낸다.

* `<user>` : 사용자 정보를 나타낸다.

``` {caption="[Text 26] X-Forwarded-User Header Example"}
X-Forwarded-User: user1
X-Forwarded-User: user2
```

[Text 26]은 X-Forwarded-User Header의 몇가지 예시를 나타낸다.

#### 1.2.15. X-Real-IP

``` {caption="[Text 27] X-Real-IP Header Format"}
X-Real-IP: <ip-address>
```

X-Real-IP Header는 요청을 전송한 Client의 IP 주소를 나타낸다. [Text 27]는 X-Real-IP Header의 Format을 나타낸다. X-Forwarded-For Header와 유사하지만 Client의 IP 주소만 포함되며, Proxy Server의 IP 주소는 포함되지 않는다. Nginx나 HAProxy에서 사용되는 Header이다.

* `<ip-address>` : IP 주소를 나타낸다.

``` {caption="[Text 28] X-Real-IP Header Example"}  
X-Real-IP: 182.168.1.50
```

[Text 28]은 X-Real-IP Header의 몇가지 예시를 나타낸다.

#### 1.2.16. X-Request-ID

``` {caption="[Text 29] X-Request-ID Header Format"}
X-Request-ID: <request-id>
``` 

X-Request-ID Header는 요청을 나타내는 고유의 ID를 나타낸다. [Text 29]는 X-Request-ID Header의 Format을 나타낸다. 일반적으로 request ID는 UUID 형식으로 생성된다.

* `<request-id>` : 요청 ID를 나타낸다.

``` {caption="[Text 30] X-Request-ID Header Example"}
X-Request-ID: 550e8400-e29b-41d4-a716-446655440000
```

[Text 30]은 X-Request-ID Header의 몇가지 예시를 나타낸다.

#### 1.2.17. X-Trace-ID

``` {caption="[Text 31] X-Trace-ID Header Format"}
X-Trace-ID: <trace-id>
```

X-Trace-ID Header는 요청을 처리하는 서버의 트레이스 ID를 나타낸다. [Text 31]는 X-Trace-ID Header의 Format을 나타낸다.

* `<trace-id>` : 트레이스 ID를 나타낸다.

``` {caption="[Text 32] X-Trace-ID Header Example"} 
X-Trace-ID: 550e8400-e29b-41d4-a716-446655440000
```

[Text 32]은 X-Trace-ID Header의 몇가지 예시를 나타낸다.

### 1.3. Response Header

#### 1.3.1. Server

``` {caption="[Text 33] Server Header Format"}
Server: <server>
```

Server Header는 요청을 처리한 서버 소프트웨소의 이름을 나타낸다. [Text 33]은 Server Header의 Format을 나타낸다.

* `<server>` : 서버 소프트웨어 이름을 나타낸다.

``` {caption="[Text 34] Server Header Example"}
Server: nginx/1.23.의
Server: Apache/2.4.54
```

#### 1.3.2. Content-Type

``` {caption="[Text 35] Content-Type Header Format"}
Content-Type: <media-type>
```

Content-Type Header는 응답의 미디어 타입을 나타낸다. [Text 35]는 Content-Type Header의 Format을 나타낸다.

* `<media-type>` : 미디어 타입을 나타낸다.
 * text/html : HTML 문서
 * text/plain : 텍스트 문서
 * application/json : JSON 문서
 * image/png : PNG 이미지
 * image/jpeg : JPEG 이미지
 * image/gif : GIF 이미지
 * image/webp : WebP 이미지

``` {caption="[Text 36] Content-Type Header Example"}
Content-Type: text/html
Content-Type: text/plain
Content-Type: application/json
Content-Type: image/png
Content-Type: image/jpeg
```

#### 1.3.3. Content-Length

``` {caption="[Text 37] Content-Length Header Format"}
Content-Length: <length>
```

Content-Length Header는 응답의 길이를 나타낸다. [Text 37]는 Content-Length Header의 Format을 나타낸다.

* `<length>` : 길이를 나타낸다. 단위는 Byte이다.

``` {caption="[Text 38] Content-Length Header Example"}
Content-Length: 0
Content-Length: 1024
Content-Length: 512
```

[Text 38]은 Content-Length Header의 몇가지 예시를 나타낸다.

#### 1.3.4. Content-Encoding

``` {caption="[Text 39] Content-Encoding Header Format"}
Content-Encoding: <encoding>
```

Content-Encoding Header는 응답의 압축 방식을 나타낸다. [Text 39]는 Content-Encoding Header의 Format을 나타낸다.

* `<encoding>` : 압축 방식을 나타낸다.
 * `gzip` : gzip 압축
 * `deflate` : deflate 압축
 * `br` : brotli 압축
 * `identity` : 압축 없음

``` {caption="[Text 40] Content-Encoding Header Example"}
Content-Encoding: gzip
Content-Encoding: deflate
Content-Encoding: br
Content-Encoding: identity
```

[Text 40]은 Content-Encoding Header의 몇가지 예시를 나타낸다.

#### 1.3.5. Content-Language

``` {caption="[Text 40] Content-Language Header Format"}
Content-Language: <language>
```

Content-Language Header는 응답의 언어를 나타낸다. [Text 40]는 Content-Language Header의 Format을 나타낸다.

* `<language>` : 언어를 나타낸다.
  * `en-US` : 미국 영어
  * `en-GB` : 영국 영어
  * `ko` : 한국어

``` {caption="[Text 41] Content-Language Header Example"}
Content-Language: en-US
Content-Language: en-GB
Content-Language: ko
```

[Text 41]은 Content-Language Header의 몇가지 예시를 나타낸다.

#### 1.3.6. Content-Location

``` {caption="[Text 42] Content-Location Header Format"}
Content-Location: <location>
```

Content-Location은 Client가 요청한 Resource와 실제 Resource의 위치가 다른 경우, 실제 Resource의 위치를 나타낸다. [Text 42]는 Content-Location Header의 Format을 나타낸다.

* `<location>` : 실제 Resource의 위치를 나타낸다.

``` {caption="[Text 43] Content-Location Header Language Example"}
# Request
GET /about HTTP/1.1
Host: example.com
Accept-Language: ko

# Response
HTTP/1.1 200 OK
Content-Type: text/html; charset=UTF-8
Content-Location: /about_ko.html
```

``` {caption="[Text 44] Content-Location Header API Example"}
# Request
GET /api/v1/users/latest HTTP/1.1
Host: api.example.com

# Response
HTTP/1.1 200 OK
Content-Type: application/json
Content-Location: /api/v1/users/v5
```

[Text 43]은 Client가 `/about`을 Resource를 `Accept-Language: ko`로 요청하여, 한국어 버전의 `/about_ko.html`을 받아오는 경우를 나타낸다. [Text 44]는 Client가 `/api/v1/users/latest`를 Resource를 요청하였으며, 가장 최신 버전의 `/api/v1/users/v5`를 받아오는 경우를 나타낸다. 모두 원래 요청한 Resource의 위치가 변경되었음을 확인할 수 있다.

## 2. 참조

* HTTP Header : [https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers)
* HTTP Cache-Control : [https://toss.tech/article/smart-web-service-cache](https://toss.tech/article/smart-web-service-cache)
* HTTP Cache-Control : [https://hudi.blog/http-cache/](https://hudi.blog/http-cache/)

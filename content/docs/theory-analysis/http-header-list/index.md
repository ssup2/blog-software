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
Authorization: <credentials>
```

Authorization Header는 요청을 보내는 Client의 인증 정보를 나타낸다. [Text 7]은 Authorization Header의 Format을 나타낸다.

* `<credentials>` : 인증 정보를 나타낸다.

``` {caption="[Text 8] Authorization Header Example"}
Authorization: Basic YWxhZGRpbjpvcGVuc2VzYW1l
```

[Text 8]은 Authorization Header의 몇가지 예시를 나타낸다.

#### 1.2.2. User-Agent

``` {caption="[Text 9] User-Agent Header Format"}
User-Agent: <user-agent>
```

User-Agent Header는 요청을 보내는 Client의 정보를 나타낸다. [Text 7]은 User-Agent Header의 Format을 나타낸다.

``` {caption="[Text 10] User-Agent Header Example"}
User-Agent: curl/7.64.1
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36
```

[Text 10]은 User-Agent Header의 몇가지 예시를 나타낸다. curl Client와 MacOS의 Chrome Browser의 예시를 나타낸다.

#### 1.2.3. Accept

``` {caption="[Text 11] Accept Header Format"}
Accept: <media-type>, <media-type>...
```

Accept Header는 요청을 보내는 클라이언트가 받을 수 있는 Media Type을 나타낸다. [Text 9]는 Accept Header의 Format을 나타낸다. 여러개의 Media Type을 지정할 수 있으며, 각 Media Type은 `,` 문자로 구분한다.

* `<media-type>` : Media Type을 나타낸다.
  * `text/html` : HTML 문서
  * `application/xhtml+xml` : XHTML 문서
  * `application/xml` : XML 문서
  * `*/*` : 모든 Media Type

``` {caption="[Text 12] Accept Header Example"}
Accept: text/html
Accept: text/html, application/xhtml+xml, application/xml;q=0.9, */*;q=0.8
```

[Text 12]은 Accept Header의 몇가지 예시를 나타낸다. `q` 값은 우선순위를 나타내며, 0에서 1 사이의 값을 갖는다. `q` 값이 높을수록 우선순위가 높다. `q` 값이 없는 경우 `1`로 간주한다. 따라서 [Text 12]의 두번째 예시에서는 `text/html`과 `application/xhtml+xml`의 우선순위가 가장 높으며, `application/xml`, `*/*` 순서대로 우선순위가 낮아진다.

#### 1.2.4. Accept-Encoding

``` {caption="[Text 13] Accept-Encoding Header Format"}
Accept-Encoding: <encoding-option>, <encoding-option>...
```

Accept-Encoding Header는 요청을 보내는 클라이언트가 받을 수 있는 Encoding을 나타낸다. [Text 11]은 Accept-Encoding Header의 Format을 나타낸다. 여러개의 Encoding을 지정할 수 있으며, 각 Encoding은 `,` 문자로 구분한다.

* `<encoding-option>` : Encoding을 나타낸다.
  * `gzip` : gzip Encoding
  * `deflate` : deflate Encoding
  * `br` : brotli Encoding
  * `identity` : Encoding을 사용하지 않는다.

``` {caption="[Text 14] Accept-Encoding Header Example"}
Accept-Encoding: gzip;q=0.9,deflate;q=0.8,br;q=1.0
Accept-Encoding: identity
```

[Text 14]은 Accept-Encoding Header의 몇가지 예시를 나타낸다. `q` 값은 우선순위를 나타내며, 0에서 1 사이의 값을 갖는다. `q` 값이 높을수록 우선순위가 높다. `q` 값이 없는 경우 `1`로 간주한다. 따라서 [Text 14]의 첫번째 예시에서는 `br`의 우선순위가 가장 높으며, `gzip`, `deflate` 순서대로 우선순위가 낮아진다.

#### 1.2.5. Accept-Language

``` {caption="[Text 15] Accept-Language Header Format"}
Accept-Language: <language-range>, <language-range>...
```

Accept-Language Header는 요청을 보내는 클라이언트가 받을 수 있는 언어를 나타낸다. [Text 13]은 Accept-Language Header의 Format을 나타낸다. 여러개의 언어를 지정할 수 있으며, 각 언어는 `,` 문자로 구분한다.

* `<language-range>` : 언어 범위를 나타낸다.
  * `en-US` : 미국 영어
  * `en-GB` : 영국 영어
  * `en` : 영어
  * `ko` : 한국어
  * `*` : 모든 언어

``` {caption="[Text 16] Accept-Language Header Example"}
Accept-Language: en-US,ko;q=0.8
Accept-Language: en-GB,en;q=0.9,ko;q=0.8
```

[Text 16]은 Accept-Language Header의 몇가지 예시를 나타낸다. `q` 값은 우선순위를 나타내며, 0에서 1 사이의 값을 갖는다. `q` 값이 높을수록 우선순위가 높다. `q` 값이 없는 경우 `1`로 간주한다. 따라서 [Text 16]의 첫번째 예시에서는 `en-US`의 우선순위가 가장 높으며, 다음으로 `ko`의 우선순위가 높다. 두번째 예시에서는 `en-GB`의 우선순위가 가장 높으며, 다음으로 `en`, `ko` 순서대로 우선순위가 낮아진다.

#### 1.2.6. X-Forwarded-For

``` {caption="[Text 17] X-Forwarded-For Header Format"}
X-Forwarded-For: <ip-address>, <ip-address>...
```

X-Forwarded-For Header는 요청을 처리하는 서버의 정보를 나타낸다. [Text 17]는 X-Forwarded-For Header의 Format을 나타낸다. 여러개의 IP 주소를 지정할 수 있으며, 각 IP 주소는 `,` 문자로 구분한다.

* `<ip-address>` : IP 주소를 나타낸다.

``` {caption="[Text 18] X-Forwarded-For Header Example"}
X-Forwarded-For: 192.168.1.1, 192.168.1.2, 192.168.1.3
```

[Text 18]은 X-Forwarded-For Header의 몇가지 예시를 나타낸다. 첫번째 예시에서는 요청을 처리하는 서버의 IP 주소가 `192.168.1.1`, `192.168.1.2`, `192.168.1.3` 순서대로 처리되었음을 나타낸다.

#### 1.2.7. X-Forwarded-Host

``` {caption="[Text 19] X-Forwarded-Host Header Format"}
X-Forwarded-Host: <host>
```

X-Forwarded-Host Header는 요청을 처리하는 서버의 Host 정보를 나타낸다. [Text 19]은 X-Forwarded-Host Header의 Format을 나타낸다.

* `<host>` : Host 정보를 나타낸다.

``` {caption="[Text 20] X-Forwarded-Host Header Example"}
X-Forwarded-Host: example.com
```

[Text 20]은 X-Forwarded-Host Header의 몇가지 예시를 나타낸다.

#### 1.2.8. X-Forwarded-Port

``` {caption="[Text 21] X-Forwarded-Port Header Format"}
X-Forwarded-Port: <port>
```

X-Forwarded-Port Header는 요청을 처리하는 서버의 Port 정보를 나타낸다. [Text 21]는 X-Forwarded-Port Header의 Format을 나타낸다.

* `<port>` : Port 정보를 나타낸다.

``` {caption="[Text 20] X-Forwarded-Port Header Example"}
X-Forwarded-Port: 80
```

[Text 20]은 X-Forwarded-Port Header의 몇가지 예시를 나타낸다.

#### 1.2.9. X-Forwarded-Proto

``` {caption="[Text 21] X-Forwarded-Proto Header Format"}
X-Forwarded-Proto: <protocol>
```

X-Forwarded-Proto Header는 요청을 처리하는 서버의 프로토콜 정보를 나타낸다. [Text 21]는 X-Forwarded-Proto Header의 Format을 나타낸다.

* `<protocol>` : 프로토콜 정보를 나타낸다.

``` {caption="[Text 22] X-Forwarded-Proto Header Example"}
X-Forwarded-Proto: http
X-Forwarded-Proto: https
```

[Text 22]은 X-Forwarded-Proto Header의 몇가지 예시를 나타낸다.  

#### 1.2.10. X-Forwarded-Server

``` {caption="[Text 23] X-Forwarded-Server Header Format"}
X-Forwarded-Server: <server>
```

X-Forwarded-Server Header는 요청을 처리하는 서버의 이름을 나타낸다. [Text 23]는 X-Forwarded-Server Header의 Format을 나타낸다.

* `<server>` : 서버 이름을 나타낸다.

``` {caption="[Text 24] X-Forwarded-Server Header Example"}
X-Forwarded-Server: example.com
```

[Text 24]은 X-Forwarded-Server Header의 몇가지 예시를 나타낸다.

#### 1.2.11. X-Forwarded-User

``` {caption="[Text 25] X-Forwarded-User Header Format"}
X-Forwarded-User: <user>
```

X-Forwarded-User Header는 요청을 처리하는 서버의 사용자 정보를 나타낸다. [Text 25]는 X-Forwarded-User Header의 Format을 나타낸다.

* `<user>` : 사용자 정보를 나타낸다.

``` {caption="[Text 26] X-Forwarded-User Header Example"}
X-Forwarded-User: user1
X-Forwarded-User: user2
```

[Text 26]은 X-Forwarded-User Header의 몇가지 예시를 나타낸다.

#### 1.2.12. X-Real-IP

``` {caption="[Text 27] X-Real-IP Header Format"}
X-Real-IP: <ip-address>
```

X-Real-IP Header는 요청을 처리하는 서버의 실제 IP 주소를 나타낸다. [Text 27]는 X-Real-IP Header의 Format을 나타낸다.

* `<ip-address>` : IP 주소를 나타낸다.

``` {caption="[Text 28] X-Real-IP Header Example"}  
X-Real-IP: 192.168.1.1
X-Real-IP: 192.168.1.2
X-Real-IP: 192.168.1.3
```

[Text 28]은 X-Real-IP Header의 몇가지 예시를 나타낸다.

#### 1.2.13. X-Request-ID

``` {caption="[Text 29] X-Request-ID Header Format"}
X-Request-ID: <request-id>
``` 

X-Request-ID Header는 요청을 처리하는 서버의 요청 ID를 나타낸다. [Text 29]는 X-Request-ID Header의 Format을 나타낸다.

* `<request-id>` : 요청 ID를 나타낸다.

``` {caption="[Text 30] X-Request-ID Header Example"}
X-Request-ID: 1234567890
X-Request-ID: 1234567891
X-Request-ID: 1234567892
```

[Text 30]은 X-Request-ID Header의 몇가지 예시를 나타낸다.

#### 1.2.14. X-Trace-ID

``` {caption="[Text 31] X-Trace-ID Header Format"}
X-Trace-ID: <trace-id>
```

X-Trace-ID Header는 요청을 처리하는 서버의 트레이스 ID를 나타낸다. [Text 31]는 X-Trace-ID Header의 Format을 나타낸다.

* `<trace-id>` : 트레이스 ID를 나타낸다.

``` {caption="[Text 32] X-Trace-ID Header Example"} 
X-Trace-ID: 1234567890
X-Trace-ID: 1234567891
X-Trace-ID: 1234567892
```

[Text 32]은 X-Trace-ID Header의 몇가지 예시를 나타낸다.

### 1.3. Response Header

#### 1.3.1. Server

#### 1.3.2. Content-Type

#### 1.3.3. Content-Length

#### 1.3.4. Content-Encoding

#### 1.3.5. Content-Language



## 2. 참조

* HTTP Header : [https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers)
* HTTP Cache-Control : [https://toss.tech/article/smart-web-service-cache](https://toss.tech/article/smart-web-service-cache)
* HTTP Cache-Control : [https://hudi.blog/http-cache/](https://hudi.blog/http-cache/)

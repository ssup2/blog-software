---
title: HTTP Header
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

Cache-Control Header는 캐시 제어 정보를 나타낸다.

### 1.2. Request Header

Request Header는 요청에서 사용되는 Header를 의미한다.

#### 1.1.1. Host

Host Header는 Host의 이름과 

#### 1.2.1. Connection
청

### 1.3. Response Header

Response Header는 응답에서 사용되는 Header를 의미한다.

## 2. 참조

* HTTP Header : [https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers)
* HTTP Header : [https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers)

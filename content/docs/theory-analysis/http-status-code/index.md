---
title: HTTP Status Code
draft: true
---

## 1. HTTP Status Code

### 1.1. 1xx Informational

Server가 Client에게 요청의 중간 상태를 전달하는 용도로 활용된다.

#### 1.1.1. 100 Continue

Server가 Client에게 요청을 계속 진행해도 된다는 임시적인 정보를 전달하는 용도로 활용한다.

#### 1.1.2. 101 Switching Protocols

Server가 Client가 요청한 Protocol를 활용하겠다는 의미이다. 일반적으로 HTTP에서 WebSocket으로 Protocol을 전환할 때 사용한다.

### 1.2. 2xx Success

Server가 요청을 성공적으로 수신하였고, 성공적으로 요청을 처리했다는 의미이다.

#### 1.2.1. 200 OK

Server가 요청을 성공적으로 수신하였으며, Server가 요청을 처리후에 성공적으로 응답을 전송했다는 의미이다.

#### 1.2.2. 201 Created

Server가 요청을 성공적으로 수신하였으며, Server가 요청에 따라서 새로운 Resource를 생성했다는 의미이다.

#### 1.2.3. 202 Accepted

Server가 요청을 성공적으로 수신하였으며, Server가 현재 요청을 처리하고 있다는 의미이다. 비동기적으로 처리되는 요청에 대해서 사용된다.

#### 1.2.4. 203 Non-Authoritative Information

Server가 요청을 성공적으로 수신하였으며, Server가 요청 처리후에 응답을 전송했지만 중간의 Proxy Server에서 응답을 변경했다는 의미이다.

#### 1.2.5. 204 No Content

Server가 요청을 성공적으로 수신하였으며, Server가 요청도 잘 처리하였지만 응답할 내용이 없다는 의미이다. 주로 Resource 삭제 요청에 대한 응답으로 이용한다.

#### 1.2.6. 205 Reset Content

Server가 요청을 성공적으로 수신하였으며, Server가 요청을 잘 처리하였기 때문에 Client의 Form, View 같은 입력 양식을 초기화 해야 한다는 의미이다.

#### 1.2.7. 206 Partial Content

Server가 요청을 성공적으로 수신하였으며, Server가 요청한 Resource의 일부분만 응답하는 경우에 사용한다.

### 1.3. 3xx Redirection

Server가 요청을 성공적으로 수신하였지만, 요청 받은 Resource의 위치가 변경된 경우에 사용한다. 변경된 Resource의 위치는 `Location` Header에 전달된다.

#### 1.3.1. 301 Moved Permanently

Server가 요청을 성공적으로 수신하였지만, 요청 받은 Resource의 위치가 영구적으로 변경된 경우에 사용한다. 일반적으로 Server는 301 Status Code와 함께 이동된 Resource의 위치도 `Location` Header에 같이 전달하며, Client는 이동된 Resource를 위치를 대상으로 다시한번 요청을 보낸다. 영구적으로 Resource의 위치가 변경 되었기 때문에 Client는 이후에도 이동된 위치를 대상으로 요청을 보내야 한다. Client는 요청시 Method를 변경하지 않는게 원칙이지만 일부 브라우저에서는 Method가 `GET`으로 변경되어 요청을 보낼 수 있다.

#### 1.3.2. 302 Found

Server가 요청을 성공적으로 수신하였지만 요청 받은 Resource의 위치가 임시적으로 변경된 경우에 사용한다. 일반적으로 Server는 302 Status Code와 함께 이동된 Resource의 위치도 `Location` Header에 같이 전달하며, Client는 이동된 Resource를 위치를 대상으로 다시한번 요청을 보낸다. 임시적으로 Resource의 위치가 변경 되었기 때문에 Client는 이후에 원래의 Resource를 위치를 대상으로 요청을 보내야 한다. Client는 요청시 Method를 변경하지 않는게 원칙이지만 일부 브라우저에서는 Method가 `GET`으로 변경되어 요청을 보낼 수 있다.

#### 1.3.3. 303 See Other

Client가 Server에게 Resource 생성을 요청할 경우, Server는 요청받은 Resource를 생성하고 생성한 Resource의 위치를 303 Status Code와 함께 `Location` Header에 전달한다. 이후 Client는 이동된 Resource를 위치를 대상으로 반드시 `GET` Method를 사용하여 Resource를 얻는다.

#### 1.3.4. 307 Temporary Redirect

Server가 요청을 성공적으로 수신하였지만, 요청 받은 Resource의 위치가 임시로 변경된 경우에 사용한다. `302 Found`와 유사하나 Client의 요청 Method가 변경되지 않는다는 점이 다르다.

#### 1.3.5. 308 Permanent Redirec청

Server가 요청을 성공적으로 수신하였지만, 요청 받은 Resource의 위치가 영구적으로 변경된 경우에 사용한다. `301 Moved Permanently`와 유사하나 Client의 요청 Method가 변경되지 않는다는 점이 다르다.

### 1.4. 4xx Client Error

4XX Status Code는 요청이 잘못되어 서버가 요청을 처리하지 못했다는 의미이다.

#### 1.4.1. 400 Bad Request

Server가 요청을 성공적으로 수신하였지만, 요청이 잘못되어 서버가 요청을 처리하지 못했다는 의미이다. 일반적으로 요청의 Header, Query Parameter, Body 등이 잘못된 경우에 사용된다. 또한 요청의 길이가 너무 길거나 Encoding 문제가 있는 경우에도 사용된다.

#### 1.4.2. 401 Unauthorized

Server가 요청을 성공적으로 수신하였지만, 인증된 요청이 아니라는 의미이다.

#### 1.4.3. 403 Forbidden

Server가 요청을 성공적으로 수신하였고 인증도 완료된 요청이지만, 요청한 Resource에 대한 접근 권한이 없다는 의미이다.

#### 1.4.4. 404 Not Found

Server가 요청을 성공적으로 수신하였지만, 요청한 Resource가 존재하지 않는 경우에 사용된다.

#### 1.4.5. 405 Method Not Allowed

Server가 요청을 성공적으로 수신하였지만, 요청한 Resource에 대해서 사용 가능한 Method가 아닌 경우에 사용된다.

#### 1.4.6. 406 Not Acceptable

Server가 요청을 성공적으로 수신하였지만, 요청에 `Accept` Header에 지정된 Media Type을 지원하지 않는 경우에 사용된다.

#### 1.4.7. 407 Proxy Authentication Required

Proxy가 Server보다 먼저 요청을 성공적으로 수신하였지만, 인증된 요청이 아니라는 의미이다. Proxy에게 인증을 요구하는 경우에 사용된다.

#### 1.4.8. 408 Request Timeout

Server가 Client의 요청을 다 받지 못한 경우에 사용된다. 일반적으로 요청이 오래 걸려 Server의 Timeout 시간을 초과한 경우에 발생한다.

#### 1.4.9. 409 Conflict

Server가 요청을 성공적으로 수신하였지만, 다른 요청과 충돌이 발생한 경우에 사용된다. 다수의 Client가 동시에 하나의 Resource를 수정하거나, 동시에 Resource를 생성하는 경우에 발생한다.

### 1.5. 5xx Server Error

5XX Status Code는 Server에 오류가 발생하여 요청을 처리하지 못한 경우에 사용된다.

#### 1.5.1. 500 Internal Server Error

Server가 요청을 성공적으로 수신하였지만, 요청 처리 과정중에 Server에 오류가 발생하여 요청을 처리하지 못한 경우에 사용된다.

#### 1.5.2. 501 Not Implemented

Server가 요청을 성공적으로 수신하였지만, 서버에서 해당 요청을 지원하지 않아 요청을 처리하지 못한 경우에 사용된다.

#### 1.5.3. 502 Bad Gateway

Proxy가 Server로부터 잘못된 응답을 받은 경우에 사용된다. Server의 Error가 발생하거나, Proxy와 Server 사이의 네트워크 문제로 인해서 요청을 Proxy가 Server에 요청을 제대로 전달하지 못하거나, 반대로 Proxy가 Server의 응답을 제대로 전달하지 못하는 경우에 발생한다응

#### 1.5.4. 503 Service Unavailable

Server가 현재 요청을 제대로 처리할 수 없는 상태인 경우에 사용된다. 일반적으로 Server가 과부화 상태이거나 점검 상태인 경우에 발생한다.

#### 1.5.5. 504 Gateway Timeout

Proxy가 Server로부터 특정 시간동안 응답을 받지 못한 경우에 사용된다. 일반적으로 Server의 과부화나 Proxy와 Server 사이의 네트워크 문제로 인해서 발생한다.

#### 1.5.6. 505 HTTP Version Not Supported

Server가 요청받은 HTTP Version을 지원하지 않는 경우에 사용된다.

#### 1.5.7. 506 Variant Also Negotiates

Server가 `Accept`, `Accept-Language`, `Accept-Charset`, `Accept-Encoding` 등의 Header 정보를 참고하여 요청을 처리할 수 없는 경우에 사용된다.

#### 1.5.8. 507 Insufficient Storage

Server가 요청을 성공적으로 수신하였지만, Server의 Disk 공간이 부족하여 요청을 처리하지 못한 경우에 사용된다.

#### 1.5.9. 508 Loop Detected

Server가 요청을 성공적으로 수신하였지만, 요청을 처리하는 과정중에 순환 참조가 발생한 경우에 사용된다.

#### 1.5.10. 510 Not Extended

Server가 요청을 성공적으로 수신하였지만, 요청에 HTTP Extension 내용이 포함되어 있지 않아 요청을 처리하지 못한 경우에 사용된다.

## 2. 참고

* HTTP Status Code : [https://developer.mozilla.org/ko/docs/Web/HTTP/Reference/Status](https://developer.mozilla.org/ko/docs/Web/HTTP/Reference/Status)
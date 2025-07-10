---
title: HTTP Response Status Code 목록
draft: true
---

## 1. HTTP Response Status Code

### 1.1. 1xx Informational

1XX Response Code는 요청의 중간 상태를 Client에게 전달하는 용도로 활용된다.

#### 1.1.1. 100 Continue

Server가 Client에게 요청을 계속 진행해도 된다는 임시적인 정보를 전달하는 용도로 활용한다.

#### 1.1.2. 101 Switching Protocols

Client가 요청한 대로 Protocol을 변경한다는 의미로 활용한다. 일반적으로 HTTP에서 WebSocket 프로토콜로 전환할 때 사용된다.

### 1.2. 2xx Success

2XX Response Code는 요청이 성공적으로 수신되었으며, 서버가 성공적으로 요청을 처리했다는 의미이다.

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

3XX 응답 코드는 요청이 성공적으로 수신되었으며, 서버는 요청을 처리했다는 의미이다.

### 1.4. 4xx Client Error

4XX 응답 코드는 요청이 잘못되었으며, 서버는 요청을 처리하지 못했다는 의미이다.

### 1.5. 5xx Server Error

5XX 응답 코드는 서버에 오류가 발생했으며, 서버는 요청을 처리하지 못했다는 의미이다.

## 2. 참고

* 
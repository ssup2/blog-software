---
title: Envoy Header
---

Envoy가 HTTP, gRPC 요청을 처리하는 과정에서 활용하는 Envoy 고유의 Header를 정리한다.

## 1. Envoy Header

Envoy는 HTTP 요청을 처리하는 과정에서 `x-envoy-` Prefix를 갖는 Envoy 고유의 Header를 활용한다. Envoy Header는 역할에 따라서 **Envoy가 요청 또는 응답에 정보를 나타내기 위해서 설정하는 Header**와 **Downstream Client가 요청에 설정하여 Envoy의 동작을 제어하는 Header**로 구분할 수 있다. gRPC는 HTTP/2를 기반으로 동작하기 때문에 대부분의 Envoy Header는 gRPC 요청에도 동일하게 적용되며, gRPC 요청에만 적용되는 Header도 별도로 존재한다.

### 1.1. Request Header

Envoy가 Upstream Server로 요청을 전달하는 과정에서 설정하는 Header를 의미한다. Upstream Server는 이러한 Header를 통해서 요청 관련 정보를 얻을 수 있다.

#### 1.1.1. x-request-id

```text {caption="[Text 1] x-request-id Header Example"}
x-request-id: 3a1f6db0-4f21-4b6e-9d2f-8c25e8b3a9d1
```

[Text 1]과 같이 Envoy가 각 요청마다 생성하는 고유한 UUID 값을 나타낸다. `x-envoy-` Prefix를 갖지는 않지만 Envoy가 설정하는 대표적인 Header이며, Access Log와 Tracing에서 하나의 요청을 식별하는 용도로 활용된다. 요청에 이미 `x-request-id` Header가 존재하는 경우에는 설정에 따라서 기존 값을 유지하거나 새로운 값으로 교체한다.

#### 1.1.2. x-envoy-internal

```text {caption="[Text 2] x-envoy-internal Header Example"}
x-envoy-internal: true
```

[Text 2]와 같이 요청이 내부 네트워크에서 유입된 요청인지를 나타내며, Internal 요청인 경우 `true` 값이 설정된다. Envoy가 Internal 요청을 구분하는 이유는 요청의 출처에 따라서 **신뢰 수준을 다르게 적용**하기 위함이다. Timeout, Retry 제어 Header처럼 Downstream Client가 Envoy의 동작을 제어하는 Header를 External 요청에도 허용하면 외부의 악의적인 Client가 재시도 횟수나 Timeout을 임의로 조작할 수 있기 때문에, Envoy는 이러한 Header를 Internal 요청에서만 신뢰한다.

Envoy는 요청자를 직접 인증하는 대신 `x-forwarded-for` (XFF) Header와 직접 연결된 Downstream의 IP 주소로 요청이 유입된 네트워크 위치를 추정하며, 둘 중 무엇을 신뢰할지는 `use_remote_address` 설정으로 결정한다. Envoy가 외부와 맞닿은 Edge Proxy로 동작하여 직접 연결된 Downstream이 곧 실제 Client인 경우에는 `true`로, 앞단에 다른 Proxy가 존재하는 내부 Proxy로 동작하는 경우에는 `false`로 설정하며, 각 경우의 판단 기준은 다음과 같다.

* `use_remote_address` 설정이 `true`인 경우 : 요청에 **XFF Header가 존재하지 않으면서** Envoy에 직접 연결된 Downstream의 Source IP 주소가 Internal 주소인 경우에만 Internal 요청으로 판단한다. XFF Header가 존재한다는 것은 다른 Proxy를 한 번 이상 거쳐서 유입된 요청이라는 것을 의미하기 때문에 Internal 요청으로 판단하지 않는다.
* `use_remote_address` 설정이 `false`인 경우 (기본값) : Envoy는 직접 연결된 Downstream의 IP 주소를 신뢰하지 않고 XFF Header만을 기반으로 판단한다. **XFF Header에 정확히 하나의 주소만 존재**하고 해당 주소가 Internal 주소인 경우에만 Internal 요청으로 판단하며, XFF Header가 존재하지 않는 경우와 여러 개의 주소가 존재하는 경우는 모두 External 요청으로 판단한다.

Internal 주소는 기본적으로 RFC1918의 사설 IPv4 주소 대역 (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`)과 RFC4193의 IPv6 ULA 주소 대역을 의미하며, `internal_address_config` 설정을 통해서 변경할 수 있다. 단 Envoy `1.33` Version부터는 보안 강화를 위해서 기본 동작이 변경되어, `internal_address_config` 설정이 명시되어 있지 않으면 모든 주소를 External 주소로 판단한다.

한편 여러 개의 Internal Proxy를 거치면서 XFF Header에 두 개 이상의 Internal 주소가 누적된 경우에도 External 요청으로 판단되는데, 이는 XFF Header 파싱을 단순화하면서 발생한 Envoy의 알려진 한계이다.

#### 1.1.3. x-envoy-external-address

```text {caption="[Text 3] x-envoy-external-address Header Example"}
x-envoy-external-address: 203.0.113.10
```

[Text 3]과 같이 요청이 외부 네트워크에서 유입된 경우 신뢰할 수 있는 Client의 IP 주소 (Trusted Client Address)를 나타내며, Internal 요청의 경우에는 설정되지 않는다. XFF Header는 중간의 Proxy들이 임의로 조작할 수 있기 때문에, Envoy는 신뢰할 수 있는 Client의 IP 주소를 아래의 기준으로 별도로 결정하여 이 Header로 제공한다.

* `use_remote_address` 설정이 `true`인 경우 : Envoy에 직접 연결된 Downstream의 Source IP 주소를 신뢰할 수 있는 Client의 IP 주소로 판단한다.
* `use_remote_address` 설정이 `false`인 경우 (기본값) : XFF Header가 존재하면 XFF Header의 **가장 오른쪽 (마지막) 주소**를 신뢰할 수 있는 Client의 IP 주소로 판단한다. 가장 오른쪽 주소는 Envoy 바로 앞의 Proxy가 설정한 주소이기 때문에 Client가 임의로 조작할 수 없는 주소이다. XFF Header가 존재하지 않으면 Envoy에 직접 연결된 Downstream의 Source IP 주소를 이용한다.
* `xff_num_trusted_hops` 설정이 `N (> 0)`인 경우 : Envoy 앞에 신뢰할 수 있는 Proxy가 N개 존재한다는 것을 의미하며, 신뢰할 수 있는 Client의 IP 주소는 `use_remote_address` 설정이 `true`이면 XFF Header의 오른쪽에서 N번째 주소, `false`이면 오른쪽에서 N+1번째 주소로 판단한다. XFF Header에 필요한 개수보다 적은 주소가 존재하는 경우에는 Envoy에 직접 연결된 Downstream의 Source IP 주소를 이용한다.

#### 1.1.4. x-envoy-original-path

```text {caption="[Text 4] x-envoy-original-path Header Example"}
x-envoy-original-path: /api/v1/users   # path after rewrite: /v1/users
```

[Text 4]와 같이 Envoy의 Route 설정에 의해서 요청의 Path가 Rewrite된 경우, Rewrite 되기 전의 원본 Path를 나타낸다.

#### 1.1.5. x-envoy-attempt-count

```text {caption="[Text 5] x-envoy-attempt-count Header Example"}
x-envoy-attempt-count: 2
```

[Text 5]와 같이 요청의 시도 횟수를 나타낸다. 최초 요청은 `1`이며 재시도가 발생할 때마다 1씩 증가한다. Upstream Server는 이 Header를 통해서 수신한 요청이 재시도 요청인지 확인할 수 있다. 설정에 따라서 응답에도 설정될 수 있으며, 이 경우 응답을 받기까지 수행된 시도 횟수를 나타낸다.

#### 1.1.6. x-envoy-expected-rq-timeout-ms

```text {caption="[Text 6] x-envoy-expected-rq-timeout-ms Header Example"}
x-envoy-expected-rq-timeout-ms: 15000
```

[Text 6]과 같이 Envoy가 요청에 적용한 Timeout 값을 나타낸다. Upstream Server는 이 Header를 통해서 Timeout 발생 전까지 남은 시간을 파악하고, Timeout이 초과된 요청의 처리를 포기할 수 있다.

#### 1.1.7. x-envoy-force-trace

```text {caption="[Text 7] x-envoy-force-trace Header Example"}
x-envoy-force-trace: true
x-request-id: 3a1f6db0-4f21-b1e9-9d2f-8c25e8b3a9d1   # 13th character is set to b
```

Internal 요청에 이 Header가 설정되어 있는 경우, Envoy는 Sampling 정책과 무관하게 강제로 Trace를 수집한다. Envoy는 Trace 수집 여부를 별도의 Header가 아니라 **`x-request-id` Header의 UUID 값 내부에 저장**한다. UUID Version 4 형식 (`xxxxxxxx-xxxx-4xxx-xxxx-xxxxxxxxxxxx`)의 13번째 자리는 UUID의 Version을 나타내는 `4`로 고정되어 있는데, Envoy는 Version 정보가 실제로 활용되지 않는 점을 이용하여 이 자리를 다음과 같은 값으로 덮어써서 Trace 수집 여부를 표현한다.

* `4` : Trace를 수집하지 않는 상태를 나타낸다. UUID Version 4의 기본값이 그대로 유지된 상태이다.
* `9` : Sampling 정책에 의해서 Trace가 수집되는 상태를 나타낸다.
* `a` : Server 측의 설정에 의해서 강제로 Trace가 수집되는 상태를 나타낸다.
* `b` : Client가 전송한 `x-envoy-force-trace` Header에 의해서 강제로 Trace가 수집되는 상태를 나타낸다.

따라서 `x-envoy-force-trace` Header가 설정된 요청을 수신한 Envoy는 [Text 7]과 같이 13번째 자리가 `b`로 설정된 `x-request-id`를 생성하고, 응답에도 `x-request-id` Header를 설정하여 반환한다. 이후 App이 `x-request-id` Header를 다른 Upstream Server로 전파하면, 전파받은 Envoy들은 자체적으로 Sampling을 다시 수행하지 않고 `x-request-id`의 13번째 자리 값을 확인하여 동일하게 Trace를 수집한다. 이러한 방식을 통해서 전체 요청 흐름에 대한 일관된 Trace를 얻을 수 있다.

#### 1.1.8. x-envoy-decorator-operation

```text {caption="[Text 8] x-envoy-decorator-operation Header Example"}
x-envoy-decorator-operation: reviews.default.svc.cluster.local:9080/api/v1/*
```

[Text 8]과 같이 Tracing Span의 Operation 이름을 나타낸다. Span의 Operation 이름은 기본적으로 요청 대상 Service의 Host 이름이 이용되지만, Envoy의 Route 설정에 Decorator가 명시되어 있는 경우 Envoy는 Decorator에 설정된 Operation 이름을 이 Header에 설정하여 전파한다. 요청에 이 Header가 설정되어 있는 경우, 요청을 수신한 Envoy는 자신이 생성하는 **Server Span** (Downstream Client로부터 요청을 수신하면서 생성하는 Span Kind `SERVER`의 Span)의 Operation 이름을 이 Header의 값으로 덮어쓴다. 동일한 이름의 Header가 응답에서도 활용된다.

### 1.2. Timeout, Retry 제어 Request Header

Downstream Client가 요청에 설정하여 Envoy의 Timeout, Retry 동작을 요청 단위로 제어할 수 있는 Header를 의미한다. 이러한 Header는 Envoy가 **Internal 요청으로 판단한 경우에만 동작**하며, External 요청에 설정되어 있는 경우 Envoy는 해당 Header를 신뢰하지 않고 제거한다. Internal 요청의 판단 기준은 `x-envoy-internal` Header에서 설명한 기준과 동일하다.

#### 1.2.1. x-envoy-upstream-rq-timeout-ms

```text {caption="[Text 9] x-envoy-upstream-rq-timeout-ms Header Example"}
x-envoy-upstream-rq-timeout-ms: 5000
```

[Text 9]와 같이 요청 전체의 Timeout을 Millisecond 단위로 설정한다. Envoy의 Route 설정에 명시된 Timeout 값보다 우선하여 적용된다.

#### 1.2.2. x-envoy-upstream-rq-per-try-timeout-ms

```text {caption="[Text 10] x-envoy-upstream-rq-per-try-timeout-ms Header Example"}
x-envoy-upstream-rq-per-try-timeout-ms: 1000
```

[Text 10]과 같이 재시도를 포함한 각 시도별 Timeout을 Millisecond 단위로 설정한다.

#### 1.2.3. x-envoy-max-retries

```text {caption="[Text 11] x-envoy-max-retries Header Example"}
x-envoy-max-retries: 3
```

[Text 11]과 같이 최대 재시도 횟수를 설정한다.

#### 1.2.4. x-envoy-retry-on

```text {caption="[Text 12] x-envoy-retry-on Header Example"}
x-envoy-retry-on: gateway-error,connect-failure,reset
```

[Text 12]와 같이 HTTP 요청의 재시도 조건을 설정하며, 여러 조건을 `,`로 구분하여 함께 설정할 수 있다. 주요 조건은 다음과 같다.

* `5xx` : HTTP Status Code `5XX` 발생 시 재시도를 수행한다.
* `gateway-error` : HTTP Status Code `502`, `503`, `504` 발생 시 재시도를 수행한다.
* `reset` : Upstream Server가 응답을 보내지 못하는 상태가 된 경우 재시도를 수행한다. Connection 종료, Reset, Read Timeout이 발생한 경우를 포함한다.
* `connect-failure` : Upstream Server와 Connection 수립에 실패한 경우 재시도를 수행한다.
* `retriable-4xx` : 재시도 가능한 HTTP Status Code `4XX` 발생 시 재시도를 수행한다. 현재는 `409` Status Code만 포함된다.
* `refused-stream` : Upstream Server가 HTTP/2의 `REFUSED_STREAM` Error Code를 반환한 경우 재시도를 수행한다.
* `envoy-ratelimited` : 응답에 `x-envoy-ratelimited` Header가 포함된 경우 재시도를 수행한다.
* `retriable-status-codes` : `x-envoy-retriable-status-codes` Header에 명시된 Status Code 발생 시 재시도를 수행한다.
* `retriable-headers` : `x-envoy-retriable-header-names` Header에 명시된 Header가 응답에 포함된 경우 재시도를 수행한다.

#### 1.2.5. x-envoy-retriable-status-codes

```text {caption="[Text 13] x-envoy-retriable-status-codes Header Example"}
x-envoy-retry-on: retriable-status-codes
x-envoy-retriable-status-codes: 409,503
```

[Text 13]과 같이 `retriable-status-codes` 재시도 조건과 함께 활용되며, 재시도를 수행할 HTTP Status Code 목록을 `,`로 구분하여 설정한다.

#### 1.2.6. x-envoy-retriable-header-names

```text {caption="[Text 14] x-envoy-retriable-header-names Header Example"}
x-envoy-retry-on: retriable-headers
x-envoy-retriable-header-names: x-retry-needed
```

[Text 14]와 같이 `retriable-headers` 재시도 조건과 함께 활용되며, 응답에 포함되어 있는 경우 재시도를 수행할 Header 이름 목록을 `,`로 구분하여 설정한다.

#### 1.2.7. x-envoy-hedge-on-per-try-timeout

```text {caption="[Text 15] x-envoy-hedge-on-per-try-timeout Header Example"}
x-envoy-upstream-rq-per-try-timeout-ms: 500
x-envoy-hedge-on-per-try-timeout: true
```

[Text 15]와 같이 각 시도별 Timeout 발생 시 기존 요청을 종료하지 않고 유지한 상태로 동시에 재시도를 수행하는 Hedging 동작 여부를 설정한다. 가장 먼저 도착한 응답이 Downstream Client에게 전달된다.

### 1.3. Response Header

Envoy가 Downstream Client에게 응답을 전달하는 과정에서 설정하는 Header를 의미한다. Downstream Client는 이러한 Header를 통해서 응답 관련 정보를 얻을 수 있다.

#### 1.3.1. x-envoy-upstream-service-time

```text {caption="[Text 16] x-envoy-upstream-service-time Header Example"}
x-envoy-upstream-service-time: 42
```

[Text 16]과 같이 Envoy가 Upstream Server에게 요청을 전송한 이후 응답을 받을 때까지 소요된 시간을 Millisecond 단위로 나타낸다. Downstream Client는 전체 응답 시간과 이 Header의 값을 비교하여 Network Latency와 Upstream Server의 처리 시간을 구분할 수 있다.

#### 1.3.2. x-envoy-overloaded

```text {caption="[Text 17] x-envoy-overloaded Header Example"}
x-envoy-overloaded: true
```

[Text 17]과 같이 Envoy가 Circuit Breaking으로 인해서 요청을 Upstream Server에게 전달하지 못한 경우 설정된다.

#### 1.3.3. x-envoy-ratelimited

```text {caption="[Text 18] x-envoy-ratelimited Header Example"}
x-envoy-ratelimited: true
```

[Text 18]과 같이 Envoy가 Rate Limit으로 인해서 요청을 Upstream Server에게 전달하지 못한 경우 설정된다.

#### 1.3.4. x-envoy-immediate-health-check-fail

```text {caption="[Text 19] x-envoy-immediate-health-check-fail Header Example"}
x-envoy-immediate-health-check-fail: true
```

[Text 19]와 같이 Upstream Server가 응답에 설정하는 Header이며, Envoy는 이 Header가 포함된 응답을 받으면 해당 Upstream Server를 즉시 Health Check 실패 상태로 처리한다. Upstream Server가 Graceful Shutdown을 수행하는 경우 활용할 수 있다.

#### 1.3.5. x-envoy-decorator-operation

```text {caption="[Text 20] x-envoy-decorator-operation Response Header Example"}
x-envoy-decorator-operation: ratings.default.svc.cluster.local:9080/ratings/{id}
```

[Text 20]과 같이 요청 Header와 동일하게 Tracing Span의 Operation 이름을 나타내며, Server 측의 Envoy가 자신의 Route 설정에 명시된 Decorator의 Operation 이름을 응답에 설정하여 반환한다. 응답에 이 Header가 설정되어 있는 경우, 응답을 수신한 Envoy는 자신이 생성하는 **Client Span** (Upstream Server로 요청을 전송하면서 생성하는 Span Kind `CLIENT`의 Span)의 Operation 이름을 이 Header의 값으로 덮어쓴다. 요청을 전송하는 Client 측의 Envoy는 요청이 실제로 Server 측의 어떤 Route에 매칭되어 처리되는지 알 수 없기 때문에, Server 측의 Envoy가 자신의 Route 정보를 기반으로 결정한 정확한 Operation 이름을 응답을 통해서 Client 측의 Envoy에게 알려주는 용도로 활용된다.

### 1.4. gRPC Header

gRPC는 HTTP/2를 기반으로 동작하기 때문에 위에서 설명한 대부분의 Envoy Header는 gRPC 요청에도 동일하게 적용된다. 하나의 gRPC 요청 (RPC)은 HTTP/2 Connection 위에서 새로운 Stream을 하나 할당받아 처리되기 때문에, 모든 Header는 Connection 단위가 아닌 **RPC (Stream) 단위**로 설정된다. 요청 Header는 Stream을 시작하는 첫 HEADERS Frame에 설정되며, RPC의 최종 처리 결과를 나타내는 `grpc-status`, `grpc-message` Header는 Stream을 종료하는 마지막 HEADERS Frame (Trailer)에 설정된다.

#### 1.4.1. grpc-timeout

```text {caption="[Text 21] grpc-timeout Header Example"}
grpc-timeout: 3S
```

[Text 21]과 같이 gRPC Client가 설정하는 요청의 Deadline을 나타낸다. Envoy는 설정에 따라서 `grpc-timeout` Header 값을 Route의 Timeout으로 활용할 수 있다.

#### 1.4.2. x-envoy-retry-grpc-on

```text {caption="[Text 22] x-envoy-retry-grpc-on Header Example"}
x-envoy-retry-grpc-on: unavailable,deadline-exceeded
```

[Text 22]와 같이 gRPC 요청의 재시도 조건을 설정한다. `x-envoy-retry-on` Header와 동일하게 Internal 요청에서만 동작한다.

* `cancelled` : gRPC Status Code `CANCELLED (1)` 발생 시 재시도를 수행한다.
* `deadline-exceeded` : gRPC Status Code `DEADLINE_EXCEEDED (4)` 발생 시 재시도를 수행한다.
* `internal` : gRPC Status Code `INTERNAL (13)` 발생 시 재시도를 수행한다.
* `resource-exhausted` : gRPC Status Code `RESOURCE_EXHAUSTED (8)` 발생 시 재시도를 수행한다.
* `unavailable` : gRPC Status Code `UNAVAILABLE (14)` 발생 시 재시도를 수행한다.

#### 1.4.3. grpc-status, grpc-message

```text {caption="[Text 23] grpc-status, grpc-message Header Example"}
grpc-status: 14
grpc-message: upstream connect error or disconnect/reset before headers
```

[Text 23]과 같이 gRPC의 처리 결과를 나타내는 Header이며, 일반적으로 gRPC Server가 응답의 Trailer에 설정한다. Envoy가 Upstream Server로부터 정상적인 응답을 받지 못하고 자체적으로 Error 응답을 생성하는 경우에도 설정된다.

#### 1.4.4. Error 응답의 gRPC Status Code 변환

Envoy가 gRPC Server로부터 정상적으로 응답을 받은 경우에는 gRPC Server가 Trailer에 설정한 `grpc-status`가 그대로 Downstream Client에게 전달되며, Envoy는 별도의 변환을 수행하지 않는다. 반면 Envoy가 Upstream Server로부터 정상적인 응답을 받지 못한 경우에는 gRPC Server가 생성한 `grpc-status`가 존재하지 않기 때문에, Envoy가 자체적으로 Error 응답을 생성하여 Downstream Client에게 응답한다. Envoy가 Upstream Server로부터 정상적인 응답을 받지 못하는 경우는 다음과 같이 두 부류로 구분할 수 있다.

* 요청을 Upstream Server에게 전달하지 못한 경우 : 요청에 매칭되는 Route가 존재하지 않는 경우, Upstream Cluster에 Healthy 상태의 Upstream Server가 존재하지 않는 경우, Upstream Server와 연결에 실패한 경우, Circuit Breaking으로 인해서 요청이 거절된 경우
* 요청을 전달했지만 정상적인 응답을 받지 못한 경우 : Timeout이 발생한 경우, Upstream Server가 응답 도중에 연결을 종료하거나 Reset한 경우

{{< table caption="[Table 1] Envoy HTTP Status Code, gRPC Status Code Mapping" >}}
| HTTP Status Code | gRPC Status Code |
|---|---|
| 400 | INTERNAL (13) |
| 401 | UNAUTHENTICATED (16) |
| 403 | PERMISSION_DENIED (7) |
| 404 | UNIMPLEMENTED (12) |
| 429 | UNAVAILABLE (14) |
| 502 | UNAVAILABLE (14) |
| 503 | UNAVAILABLE (14) |
| 504 | UNAVAILABLE (14) |
| 기타 | UNKNOWN (2) |
{{</ table >}}

이와 같은 경우에는 Envoy가 [Table 1]의 Mapping을 활용하여 다음의 과정을 통해서 gRPC 형식의 Error 응답을 생성한다. 다음과 같은 순서로 진행된다.

1. Envoy는 Error 상황에 따라서 내부적으로 HTTP Status Code를 먼저 결정한다. (Upstream Server 연결 실패 시 `503`, Route 부재 시 `404` 등) HTTP 요청의 경우에는 결정된 HTTP Status Code가 그대로 응답에 설정된다.
2. gRPC 요청의 경우에는 결정된 HTTP Status Code를 [Table 1]의 Mapping에 따라서 gRPC Status Code로 변환한다.
3. 변환된 gRPC Status Code를 `grpc-status` Header에 설정하고, HTTP Status Code `200`과 함께 Trailers-Only 형태로 응답한다. 즉 [Table 1]의 HTTP Status Code는 gRPC 요청의 실제 응답에 설정되는 값이 아니라 Envoy 내부적으로 결정된 HTTP Status Code를 의미하며, gRPC 요청의 실제 응답에 설정되는 HTTP Status Code는 항상 `200`이다.

예외적으로 Timeout이 발생한 경우에는 [Table 1]의 Mapping을 이용하지 않고 `DEADLINE_EXCEEDED (4)` gRPC Status Code가 직접 설정된다. (동일한 상황에서 HTTP 요청의 경우 `504` Status Code가 응답된다.) [Text 23]의 예시가 바로 Envoy가 Upstream Server 연결 실패 시 자체 생성한 Error 응답으로, 내부적으로 결정된 `503`이 `UNAVAILABLE (14)`로 변환된 결과이다.

## 2. 참조

* Envoy HTTP Header Manipulation : [https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_conn_man/headers](https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_conn_man/headers)
* Envoy Router Filter Header : [https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/router_filter](https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/router_filter)
* gRPC HTTP Status Mapping : [https://github.com/grpc/grpc/blob/master/doc/http-grpc-status-mapping.md](https://github.com/grpc/grpc/blob/master/doc/http-grpc-status-mapping.md)
* Istio Proxy Header : [https://ssup2.github.io/blog-software/docs/theory-analysis/istio-proxy-header/](https://ssup2.github.io/blog-software/docs/theory-analysis/istio-proxy-header/)

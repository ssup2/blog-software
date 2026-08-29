---
title: HTTP/2
---

HTTP2를 분석한다.

## 1. HTTP2

HTTP/2는 기존 HTTP/1의 느린 성능 개선을 목적으로 탄생하게된 Protocol이다. HTTP/2가 HTTP/1에 비해서 개선된 점들은 다음과 같다.

### 1.1. Stream, Multiplexing

{{< figure caption="[Figure 1] HTTP/2 Components" src="images/http2-components.png" width="900px" >}}

[Figure 1]은 HTTP/2의 구성요소를 나타내고 있다. HTTP/2는 하나의 **Connection**안에서 논리적 Channel 역할을 수행하는 다수의 **Stream**을 두어 Multiplexing을 구현한다. 각 Stream 안에서는 Server와 Client는 다른 Stream에 관계 없이 독립적으로 **Message**를 주고 받는다. Message는 **Frame**이라고 불리는 전송 최소 단위로 쪼개져 구성된다.

{{< figure caption="[Figure 2] HTTP/2 Stream Multiplexing" src="images/http2-stream-multiplexing.png" width="900px" >}}

HTTP/2에서 Stream이라는 개념이 탄생한 이유는 Server와 Client의 전송 대기 시간 감소 및 HOL Blocking (Head of Line Blocking) 현상을 제거 하기 위해서 이다. [Figure 2]는 Stream Multiplexing을 나타내고 있다. 기존 HTTP/1에서는 하나의 Connection 내부에서 Server나 Client는 동시에 Message를 전송하지 못하고 Message를 Ping-pong 형태로 주고 받을수 밖에 없었다. 따라서 Server나 Client는 불필요한 대기시간이 길어지게 되고, 앞의 Message 전송이 느려지면 뒤의 Message 전송에 큰 영향을 미치게 된다. HTTP/2에서는 Stream 이라는 논리적인 Channel을 도입하여 HOL Blocking 문제를 해결하였다. HTTP/2는 각 Stream 단위로 Flow Control을 수행한다. HTTP/2의 Stream Flow Control은 TCP의 Flow Control처럼 Window를 생성하는 방식을 이용한다.

{{< figure caption="[Figure 3] HTTP/2 Frame Interleaving" src="images/http2-frame-interleaving.png" width="900px" >}}

[Figure 3]은 HTTP/2에서 Stream을 통해서 실제 어떻게 Multiplexing을 구현하는지를 나타내고 있다. Stream의 구현은 Frame Interleaving을 통해서 구현된다. 각 Stream에 소속되어 있는 Frame들은 시분활을 통해 동시에 전송된다. 목적지에 도착한 Frame들은 Frame Header에 포함된 Stream Number 정보를 통해서 재조합되어 Server 또는 Client에게 전달된다. Frame Header에는 Frame의 Type을 나타내는 정보도 포함되어 있으며 대표적인 Type에는 HTTP/2의 Header가 포함되어 있는 HEADER Type과 HTTP/2의 Body가 포함되어 있는 DATA Type이 존재한다.

### 1.2. 요청, 응답 처리와 Stream

```text {caption="[Text 1] Stream을 통한 요청, 응답 처리"}
TCP Connection 1개
├── Stream 0 : Connection 제어 Frame 전용 (SETTINGS, PING, GOAWAY)
├── Stream 1 (요청/응답 A) : HEADERS Frame → DATA Frame... → HEADERS Frame (Trailer)
├── Stream 3 (요청/응답 B) : HEADERS Frame → DATA Frame...
└── Stream 5 (요청/응답 C) : HEADERS Frame → ...
```

HTTP/2에서 **모든 요청과 응답은 반드시 Stream 위에서만 처리**되며, Stream 바깥에서 Header나 Body를 전송하는 방법은 존재하지 않는다. [Text 1]과 같이 하나의 요청/응답 쌍은 하나의 Stream에 1:1로 매핑되며, 요청이 시작될 때 Stream이 새로 생성되고 응답이 완료되면 해당 Stream은 닫히고 재사용되지 않는다. 요청, 응답 처리와 Stream의 관계는 다음과 같은 특징을 갖는다.

* Stream의 생성은 별도의 협상 과정 없이 **새로운 Stream ID를 부여한 HEADERS Frame을 전송하는 것 자체로 완료**된다. 즉 "Stream을 생성하는 단계"와 "Header를 전송하는 단계"가 분리되어 있지 않으며, 첫 HEADERS Frame 하나가 두 역할을 동시에 수행한다. 따라서 요청마다 Stream을 동적으로 생성하더라도 TCP Connection 수립과 같은 추가적인 왕복 (RTT) 비용은 발생하지 않는다.
* Client가 생성하는 Stream에는 홀수의 Stream ID (`1`, `3`, `5`...)가 단조 증가하며 부여되고, Server가 생성하는 Stream (Server Push)에는 짝수의 Stream ID (`2`, `4`, `6`...)가 단조 증가하며 부여된다. 이는 Client와 Server가 동시에 Stream을 생성해도 Stream ID가 충돌하지 않도록 하기 위함이다. Stream ID는 하나의 Connection 안에서 재사용되지 않으며, ID가 고갈되면 (2^31) 새로운 Connection을 생성하여 이후의 요청을 처리한다.
* Stream ID `0`은 Stream이 아니라 **Connection 전체에 적용되는 제어 Frame** (SETTINGS, PING, GOAWAY)을 위해서 예약되어 있으며, 이러한 제어 Frame은 Header를 담지 않는다.
* gRPC가 하나의 RPC마다 하나의 Stream을 생성하여 처리하는 것도 HTTP/2의 "요청/응답 1쌍 = Stream 1개" 규칙을 그대로 따르는 것이다.

### 1.3. Header, Trailer

HTTP Message는 **Header Section, Body, Trailer Section**의 세 구간으로 구성된다. Header와 Trailer는 모두 동일한 형식 (이름-값 쌍)의 Field 목록이며, Body 앞에 전송되면 Header, Body 뒤에 전송되면 Trailer라는 위치의 차이만 존재한다.

HTTP/2에서는 Header와 Trailer 모두 **HEADERS Frame**으로 전송된다. Trailer를 위한 별도의 Frame Type은 존재하지 않으며, Stream을 시작하는 첫 HEADERS Frame이 Header 역할을, Body (DATA Frame) 뒤에 전송되는 마지막 HEADERS Frame (END_STREAM Flag 포함)이 Trailer 역할을 수행한다.

* Header : 요청 또는 응답의 Meta Data를 나타낸다. HTTP/2에서는 HTTP/1.1의 Request Line (`GET /home HTTP/1.1`)과 Status Line (`HTTP/1.1 200 OK`)도 별도의 라인이 아니라 `:method`, `:path`, `:scheme`, `:authority`, `:status`와 같이 `:` Prefix를 갖는 **Pseudo-Header**로 변환되어 일반 Header와 함께 HEADERS Frame에 전송된다.
* Trailer : Body를 모두 전송한 이후에만 확정할 수 있는 정보를 나타낸다. 응답의 최종 처리 결과나 Body의 Checksum이 대표적이며, gRPC가 RPC의 최종 처리 결과인 `grpc-status` Header를 Trailer로 전송하는 것이 대표적인 활용 예시이다. Trailer는 Body를 모두 수신한 이후에 도착하기 때문에, `:status`와 같은 Pseudo-Header와 `content-length`처럼 Body 해석에 필요한 Field는 Trailer에 설정할 수 없다.

### 1.4. Header 압축

{{< figure caption="[Figure 4] HTTP/2 Header 압축" src="images/http2-header-compression.png" width="900px" >}}

일반적으로 HTTP Header에는 Cookie, User-Agent와 같은 많은 Meta Data를 저장하고 있기 때문에 HTTP Header의 길이는 HTTP Body의 길이와 비교해도 큰 차이가 나지 않는 경우가 많다. 문제는 Stateless한 HTTP의 특성 때문에 동일한 Server에게 동일한 HTTP Header 내용을 여러번 전송하는 경우가 빈번하게 발생한다는 점이다. 따라서 긴 HTTP Header는 HTTP 통신의 주요 Overhead 중 하나이다.

HTTP/2는 이러한 HTTP Header의 Overhead를 줄이기 위해서 Header 압축 기법을 제공한다. [Figure 4]는 Header 압축 기법을 나타내고 있다. HTTP/2의 Header 압축은 내부적으로 **HPACK**이라고 불리는 Module이 담당하는데 HPACK은 Huffman Algorithm과 Static Table, Dynamic Table을 통해서 압축을 수행한다. Huffman Algorithm은 자주 나오는 문자열 순서대로 짧은 Bitmap으로 Mapping하여 Data를 압축하는 기법이다. Static Table은 HTTP/2 Spec에 정의된 Table로 HTTP/2 Header로 자주 사용되는 Key-value 값 쌍을 저장하고 있는 Table이다. Dynamic Table은 한번 전송/수신한 Header의 Key-value 값을 임의로 저장하는 Buffer 역할을 수행하는 Table이다.

[Figure 4]는 동일한 HTTP/2 Header를 2번 전송 하였을때의 압축 과정을 나타내고 있다. 처음으로 Header 전송시 전송하려는 Header의 Key-value 중에서 Static Table의 Key-value와 일치하는 경우에는 해당 Key-value는 Static Table의 Index로 변경된다. [Figure 4]에서 ":method GET", ":scheme POST"가 각각 Static Table의 Index 2, 7로 변경되는 것을 확인할 수 있다.

Static Table을 이용하여 변경되지 않은 나머지 Key-value들은 각각 Huffman Algorithm을 이용해 압축된다. 그리고 Huffman을 통해서 압축된 Key-value는 Dynamic Table에 저장된다. [Figure 4]에서 ":host ssup.com", ":path /home", "user-agent Mozila/5.0"는 Dynamic Table의 62에 저장되는 것을 확인할 수 있다. 그 뒤 동일 Header를 한번더 전송하는 경우 Dynamic Table을 이용하여 첫번째 Header를 전송할때보다 효율적으로 압축한다. [Figure 4]에서 두번째 전송하는 Header의 경우에는 Huffman Algorithm을 이용하지 않고 Static, Dynamic Table만을 이용하여 Header를 압축하는걸 확인할 수 있다.

Static Table은 61번 Index까지 갖고 있기 때문에 Dynamic Table의 Index는 62번부터 시작한다. Dynamic Table은 FIFO 형태로 동작한다. 즉 Dynamic Table이 가득차 새로운 Key-value를 저장할 공간이 부족할 경우, 가장 오랜 기간 저장된 Key-value를 제거하고 새로운 Key-value를 저장한다. Dynamic Table은 Stream 단위가 아니라 **Connection 단위로 공유**되기 때문에, 서로 다른 Stream이 전송하는 요청이라도 동일한 Header는 효율적으로 압축된다.

### 1.5. Stream Priority

{{< figure caption="[Figure 5] HTTP/2 Stream Priority" src="images/http2-stream-priority.png" width="200px" >}}

HTTP/2의 Stream은 Weight 기반 Priority 기능을 제공한다. Stream Priority 기능을 통해서 우선순위가 높은 Message를 먼저 보낼수 있다. [Figure 5]는 각 Stream의 Weight 값과 Stream 사이의 Weight 관계를 나타내고 있다. Stream 사이의 Weight 관계는 Tree 형태를 이룬다. Weight는 1부터 256까지의 값을 가질수 있다. 기본적으로 Weight에 비례하여 Stream에 할당되는 Resource양이 결정된다. 여기서 Resource는 CPU, Memory, Network Bandwidth 같은 Message 전송에 필요한 자원을 의미한다.

[Figure 5]에서 Stream A의 Weight는 12, Stream B에는 4의 Weight가 설정되어 있기 때문에, Stream A와 Stream B의 Resource 비율은 3:1이 된다. Stream B의 하위 Stream은 Stream C 밖에 없기 때문에 Stream B와 Stream C의 Resource 비율은 1:1이 된다. Stream C의 하위 Stream은 Weight가 8인 Stream D와 Weight가 4인 Stream E가 존재하기 때문에 Stream D는 Stream C가 이용할 수 있는 Resource의 2/3만큼 쓸수 있고, Stream C는 Stream D가 이용할 수 있는 Resource의 1/3만큼 쓸수 있다. 따라서 Stream C, D, E의 비율은 3:2:1이 된다. 종합하면 Stream A, B, C, D, E의 Resource 비율은 9:3:3:2:1이 된다.

### 1.6. Server Push

{{< figure caption="[Figure 6] HTTP/2 Server Push" src="images/http2-server-push.png" width="450px" >}}

HTTP/2에서 Server는 Client의 요청 Message를 받으면 요청에 대한 응답 Message 뿐만 아니라, Client에서 아직 요청하지 않았지만 Client에게 필요할 걸로 예상되는 다른 Message도 함께 전송하는 Server Push 기능을 제공한다. [Figure 6]은 Server Push 동작을 나타내고 있다. Client는 /index.html 파일만 Server에게 요청했지만 Server는 /index.html을 그리는데 필요한 PNG 파일들도 별도의 Strema을 통해서 동시에 같이 Client에게 전송하는 것을 확인할 수 있다.

[Figure 3]에서 PUSH-PROMISE Type의 Frame을 확인할 수 있는데, Server Push의 시작을 Client에게 알리는 역할을 수행한다. PUSH-PROMISE Type의 Frame에는 Message를 전송할 Stream을 명시하여 Client가 해당 Stream을 통해서 Message를 수신할 수 있도록 만든다.

## 2. 참조

* [https://http2.github.io/http2-spec](https://http2.github.io/http2-spec)
* HTTP/2 RFC 9113 : [https://datatracker.ietf.org/doc/html/rfc9113](https://datatracker.ietf.org/doc/html/rfc9113)
* [https://developers.google.com/web/fundamentals/performance/http2?hl=ko](https://developers.google.com/web/fundamentals/performance/http2?hl=ko)
* [https://www.slideshare.net/eungjun/http2-40582114](https://www.slideshare.net/eungjun/http2-40582114)
* [https://b.luavis.kr/http2/](https://b.luavis.kr/http2/)
* [https://www.slideshare.net/BrandonK/http2-analysis-and-performance-evaluation-tech-summit-2017-86562049](https://www.slideshare.net/BrandonK/http2-analysis-and-performance-evaluation-tech-summit-2017-86562049)

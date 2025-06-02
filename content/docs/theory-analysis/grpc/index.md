---
title: gRPC
---

## 1. gRPC

{{< figure caption="[Figure 1] Forward Proxy" src="images/grpc-architecture.png" width="500px" >}}

gRPC는 다양한 환경에서 구동 가능한 RPC (Remote Procedure Call) Framework이다. [Figure 1]은 gRPC Architecture를 나타내고 있다. 요청을 처리하는 Service에서는 **gRPC Server**가 동작하며, Client에서는 **gRPC Stub**이 동작한다. gRPC Server와 gRPC Stub 사이의 Interface는 **ProtoBuf**를 이용하여 정의한다. gRPC Server와 gRPC Stub 사이에는 **HTTP/2**를 이용하여 통신한다. gRPC는 현재 Java, C++, Golang, Ruby, Python등 다양한 언어를 지원한다.

### 1.1. ProtoBuf

ProtoBuf는 Server와 Client 사이에서 구조화된 Data를 쉽게 주고 받을수 있도록, Interface를 정의하고 구조화된 Data를 Serialization하는 역할을 수행한다. REST API에서 Data의 형태로 이용되는 JSON을 대체한다고 이해하면 된다. 다만 JSON과 다르게 ProtoBuf는 Data를 Text 형태가 아닌 Binary 형태로 변환한다.

```protobuf {caption="[File 1] addressbook.proto ", linenos=table}
message Person {
  string name = 1;
  int32 id = 2;
  string email = 3;

  enum PhoneType {
    MOBILE = 0;
    HOME = 1;
    WORK = 2;
  }

  message PhoneNumber {
    string number = 1;
    PhoneType type = 2;
  }
}
```

[File 1]은 구조화된 Data인 Person Data를 ProtoBuf 규격에 맞게 저장하고 있는 .proto 파일을 나타내고 있다. ProtoBuf는 .proto 파일을 컴파일하여 gRPC Server와 gRPC Client에서 이용할 수 있는 Code를 생성한다. 생성된 Code를 이용하여 Server와 Client는 gRPC를 수행한다.

### 1.2. HTTP/2

gRPC는 HTTP/1.1 대비 HTTP/2의 장점들을 활용하며 동작한다.

* Multiplexing, Stream : HTTP/1.1에서는 하나의 TCP Connection에서 동시에 하나의 요청만 처리할 수 있었지만, HTTP/2는 하나의 TCP Connection에서 동시에 여러 요청을 처리할 수 있는 Multiplexing 기능을 지원한다. 하나의 TCP Connection에서 다수의 Stream을 생성하며 Client와 Server는 생성된 Stream을 이용하여 각각 요청을 독립적으로 처리한다. gRPC에서는 HTTP/2의 Stream을 이용하여 하나의 TCP Connection에서 동시에 여러 RPC을 처리한다.
* Header Compression : HTTP/1.1에서는 평문으로 전송되는 Header를 압축하는 기능이 없었지만, HTTP/2는 Header Compression 기능을 제공하여 Header 크기를 줄일 수 있다. gRPC의 Header도 HTTP/2의 Header Compression 기능을 이용하여 크기를 줄인다.

### 1.3. Status Code

{{< table caption="[Table 1] GRPC Status Code" >}}
| Status Code | Number | Description |
| --- | --- | --- |
| OK | 0 | 요청이 정상적으로 처리됨. 오류 아님. |
| CANCELLED | 1 | 작업이 취소됨. (Client의 요청 취소) |
| UNKNOWN | 2 | 원인을 알 수 없는 오류 발생. 상세 메시지를 통해 디버깅 필요. |
| INVALID_ARGUMENT | 3 | Client가 잘못된 요청 인자를 보냄. |
| DEADLINE_EXCEEDED | 4 | 요청 Timeout이 발생. 지정된 시간 내에 응답이 오지 않음. |
| NOT_FOUND | 5 | 요청한 Resource를 찾을 수 없음. |
| ALREADY_EXISTS | 6 | 요청한 Resource가 이미 존재함. (중복 생성 요청) |
| PERMISSION_DENIED | 7 | 권한 부족으로 접근 거부. (인증, 인가 실패) |
| RESOURCE_EXHAUSTED | 8 | 용량 초과, 메모리 부족 등 리소스 소진. |
| FAILED_PRECONDITION | 9 | 사전 조건이 충족되지 않음. (Lock이 걸린 상태에서 작업 요청) |
| ABORTED | 10 | 동시성 충돌로 인해 작업이 중단됨. |
| OUT_OF_RANGE | 11 | 요청 인자가 유효한 범위를 초과함. (자료형 범위 초과) |
| UNIMPLEMENTED | 12 | Server에 요청한 Method가 구현되어 있지 않음. |
| INTERNAL | 13 | 내부 Server 오류. 디버깅 필요. |
| UNAVAILABLE | 14 | Server가 다운되었거나 연결 불가. 재시도 가능. |
| DATA_LOSS | 15 | Data 손실 발생. |
| UNAUTHENTICATED | 16 | 인증 실패. 토큰 누락 또는 유효하지 않음. |
{{< /table >}}

[Table 1]은 gRPC의 Status Code를 나타내고 있다. gRPC에서 각각의 RPC 요청은 응답으로 돌아오는 **Status Code**를 통해 요청의 성공 여부를 판단한다. 

HTTP/2의 Status Code와 유사하지만 서로 다른 역할을 수행한다. gRPC의 Status Code는 각 RPC 요청에 대한 결과이지만, HTTP/2의 Status Code는 HTTP/2 관점에서의 Data 전송 및 라우팅 결과를 나타낸다. 예를들어 Client가 gRPC를 통해서 Server로 존재하지 않는 Method를 호출할 경우 Status Code는 **UNIMPLEMENTED**으로 응답되지만, HTTP/2의 Status Code는 **200**으로 응답될 수 있다. 왜냐하면 HTTP/2 관점에서는 Data를 성공적으로 주고 받았기 때문이다.

### 1.4. vs HTTP/1.1 + JSON

gRPC가 현재 주목받는 가장큰 이유는 기존의 HTTP/1.1 + JSON Protocol보다 빠르기 때문이다. HTTP/1.1과 JSON은 Text Protocol인 만큼 성능면에서는 불리하다. gRPC에서 이용하는 HTTP/2와 ProtoBuf는 Binray Protocol인 만큼 상대적을 적은양의 Packet을 주고 받는다. 또한 gRPC는 HTTP/2에서 지원하는 Connection Multiplexing, Server/Client Streaming을 이용하여 효율성을 좀더 끌어 올리고 있다.

## 2. 참조

* [https://grpc.io/docs/](https://grpc.io/docs/)
* [https://medium.com/@goinhacker/microservices-with-grpc-d504133d191d](https://medium.com/@goinhacker/microservices-with-grpc-d504133d191d)
* [https://github.com/HomoEfficio/dev-tips/blob/master/gRPC%20-%20Overview.md](https://github.com/HomoEfficio/dev-tips/blob/master/gRPC%20-%20Overview.md)
* [https://github.com/protocolbuffers/protobuf/blob/master/examples/addressbook.proto](https://github.com/protocolbuffers/protobuf/blob/master/examples/addressbook.proto)
* [https://tech.ktcloud.com/entry/gRPC%EC%9D%98-%EB%82%B4%EB%B6%80-%EA%B5%AC%EC%A1%B0-%ED%8C%8C%ED%97%A4%EC%B9%98%EA%B8%B0-HTTP2-Protobuf-%EA%B7%B8%EB%A6%AC%EA%B3%A0-%EC%8A%A4%ED%8A%B8%EB%A6%AC%EB%B0%8D](https://tech.ktcloud.com/entry/gRPC%EC%9D%98-%EB%82%B4%EB%B6%80-%EA%B5%AC%EC%A1%B0-%ED%8C%8C%ED%97%A4%EC%B9%98%EA%B8%B0-HTTP2-Protobuf-%EA%B7%B8%EB%A6%AC%EA%B3%A0-%EC%8A%A4%ED%8A%B8%EB%A6%AC%EB%B0%8D)
* GRPC Status Code : [https://grpc.io/docs/guides/status-codes/](https://grpc.io/docs/guides/status-codes/)
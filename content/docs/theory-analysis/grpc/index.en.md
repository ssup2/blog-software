---
title: gRPC
---

## 1. gRPC

{{< figure caption="[Figure 1] gRPC Architecture" src="images/grpc-architecture.png" width="500px" >}}

gRPC is an RPC (Remote Procedure Call) Framework that can run in various environments. [Figure 1] shows the gRPC Architecture. The **gRPC Server** runs on the Service that processes requests, and the **gRPC Stub** runs on the Client. The Interface between the gRPC Server and the gRPC Stub is defined using **ProtoBuf**. The gRPC Server and the gRPC Stub communicate using **HTTP/2**. gRPC currently supports various languages such as Java, C++, Golang, Ruby, and Python.

### 1.1. ProtoBuf

ProtoBuf defines the Interface and performs Serialization of structured Data so that the Server and Client can easily exchange structured Data. It can be understood as a replacement for JSON, which is used as the Data format in REST APIs. However, unlike JSON, ProtoBuf converts Data into Binary form rather than Text form.

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

[File 1] shows a .proto file that stores structured Person Data according to the ProtoBuf specification. ProtoBuf compiles the .proto file to generate Code that can be used by the gRPC Server and the gRPC Client. The Server and Client perform gRPC using the generated Code.

### 1.2. HTTP/2

gRPC operates by leveraging the advantages of HTTP/2 over HTTP/1.1.

* Multiplexing, Stream : In HTTP/1.1, only one request could be processed at a time on a single TCP Connection, but HTTP/2 supports Multiplexing, which allows multiple requests to be processed simultaneously on a single TCP Connection. Multiple Streams are created on a single TCP Connection, and the Client and Server process each request independently using the created Streams. gRPC uses HTTP/2 Streams to process multiple RPCs simultaneously on a single TCP Connection.
* Header Compression : HTTP/1.1 had no feature to compress Headers transmitted in plaintext, but HTTP/2 provides Header Compression to reduce Header size. gRPC Headers also use HTTP/2's Header Compression feature to reduce their size.

#### 1.2.1. RPC and Stream

```text {caption="[Text 1] Processing Multiple RPCs on a Single TCP Connection"}
1 TCP Connection
├── Stream 1 (RPC A) : HEADERS Frame → DATA Frame... → HEADERS Frame (Trailer)
├── Stream 3 (RPC B) : HEADERS Frame → DATA Frame... → HEADERS Frame (Trailer)
└── Stream 5 (RPC C) : HEADERS Frame → DATA Frame... → HEADERS Frame (Trailer)
```

A single RPC is **mapped 1:1** to a single HTTP/2 Stream. As shown in [Text 1], every time the Client calls an RPC, a new Stream is dynamically created on the TCP Connection, and when the RPC completes, the Stream is also terminated. A single Stream is never shared or reused by multiple RPCs, and only Connection-level state (HPACK Header compression state, SETTINGS, Connection Flow Control Window) is shared by multiple Streams. The relationship between RPC and Stream has the following characteristics.

* Stream creation is completed simply by the Client sending a HEADERS Frame with a new Stream ID, without any separate negotiation process. Therefore, even if a Stream is dynamically created for each RPC, no additional round-trip (RTT) cost such as TCP Connection establishment occurs.
* Streams created by the Client are assigned odd Stream IDs (`1`, `3`, `5`...) in monotonically increasing order, and Streams created by the Server (Server Push) are assigned even Stream IDs (`2`, `4`, `6`...) in monotonically increasing order. This is to prevent Stream ID collisions even when the Client and Server create Streams at the same time. Stream IDs are not reused within a single Connection, and when IDs are exhausted (2^31), a new Connection is created to process subsequent RPCs.
* gRPC RPCs are classified into the following four types according to the Message exchange pattern, and all types use a single Stream in the same way. The only differences are the number of Messages (DATA Frames) exchanged on the Stream and how long the Stream remains open, and Streaming RPCs keep a single Stream open for a long time while exchanging multiple Messages.
  * **Unary RPC** : The Client sends one Message and the Server responds with one Message. It is similar to a typical function call and is the most commonly used type.
  * **Server Streaming RPC** : When the Client sends one Message, the Server sends multiple Messages in succession. (e.g. real-time notification subscription, transmission of large query results)
  * **Client Streaming RPC** : The Client sends multiple Messages in succession, and then the Server responds with one Message. (e.g. File Upload, Metric transmission)
  * **Bidirectional Streaming RPC** : The Client and Server independently exchange multiple Messages on a single Stream. (e.g. chat)
* Each Stream operates independently. Even if a specific RPC is canceled or an error occurs and the Stream is forcibly terminated with an RST_STREAM Frame, other RPCs on the same Connection are not affected.

#### 1.2.2. Frame Structure and Trailer

```text {caption="[Text 2] Frame Structure of a gRPC Response"}
HEADERS Frame            :status: 200
                         content-type: application/grpc
DATA Frame(s)            Length-Prefixed Message (5 Byte Prefix + ProtoBuf Message)
HEADERS Frame (Trailer)  grpc-status: 0
                         grpc-message: ...
```

A single RPC (Stream) consists of a combination of HEADERS Frames and DATA Frames. A request starts with a HEADERS Frame containing the Method information (`:path /<Package>.<Service>/<Method>`) and the `content-type: application/grpc` Header, followed by DATA Frames containing ProtoBuf Messages. [Text 2] shows the Frame structure of a response, and the response ends with a **Trailer** containing the final processing result of the RPC (`grpc-status`, `grpc-message`) after the HEADERS Frame and DATA Frames.

A Trailer is a list of Fields in the same format as Headers (name-value pairs), and the only difference is its position: it is the last HEADERS Frame sent after the Body (DATA Frames). The reason gRPC sets the final processing result in the Trailer rather than at the beginning of the response is **Streaming**. In a Server Streaming RPC, an error can occur while the Server is sending multiple Messages, and since the first HEADERS Frame has already been sent at the start of the Stream, the final success of the RPC can only be determined after all Messages have been sent. In the case of an error response with no Messages to send, the Stream can also be terminated by setting `grpc-status` directly in the first HEADERS Frame without any DATA Frames, which is called a **Trailers-Only** response.

### 1.3. Status Code

{{< table caption="[Table 1] GRPC Status Code" >}}
| Status Code | Number | Description |
| --- | --- | --- |
| OK | 0 | The request was processed successfully. Not an error. |
| CANCELLED | 1 | The operation was canceled. (Request canceled by the Client) |
| UNKNOWN | 2 | An error of unknown cause occurred. Debugging through detailed messages is required. |
| INVALID_ARGUMENT | 3 | The Client sent invalid request arguments. |
| DEADLINE_EXCEEDED | 4 | Request Timeout occurred. No response was received within the specified time. |
| NOT_FOUND | 5 | The requested Resource could not be found. |
| ALREADY_EXISTS | 6 | The requested Resource already exists. (Duplicate creation request) |
| PERMISSION_DENIED | 7 | Access denied due to insufficient permissions. (Authentication, Authorization failure) |
| RESOURCE_EXHAUSTED | 8 | Resource exhaustion such as capacity exceeded or out of memory. (The Client sent too many requests, or the Server received too many requests) |
| FAILED_PRECONDITION | 9 | Preconditions were not met. (Operation requested while a Lock is held) |
| ABORTED | 10 | The operation was aborted due to a concurrency conflict. |
| OUT_OF_RANGE | 11 | Request arguments exceeded the valid range. (Data type range exceeded) |
| UNIMPLEMENTED | 12 | The requested Method is not implemented on the Server. |
| INTERNAL | 13 | An error occurred inside the Server. Debugging is required. |
| UNAVAILABLE | 14 | The Server is down or unreachable. Retry is possible. |
| DATA_LOSS | 15 | Data loss occurred. |
| UNAUTHENTICATED | 16 | Authentication failed. Token is missing or invalid. |
{{< /table >}}

[Table 1] shows the gRPC Status Codes. In gRPC, each RPC request determines its success through the **Status Code** returned in the response. The Status Code is delivered through the `grpc-status` Header in the Trailer that terminates the response Stream.

It is similar to the HTTP/2 Status Code but serves a different role. The gRPC Status Code is the result of each RPC request, while the HTTP/2 Status Code represents the result of Data transmission and routing from the HTTP/2 perspective. For example, if a Client calls a Method that does not exist on the Server through gRPC, the Status Code responds with **UNIMPLEMENTED**, but the HTTP/2 Status Code may respond with **200**. This is because, from the HTTP/2 perspective, Data was exchanged successfully.

### 1.4. vs HTTP/1.1 + JSON

The biggest reason gRPC is currently attracting attention is that it is faster than the existing HTTP/1.1 + JSON Protocol. HTTP/1.1 and JSON are Text Protocols, which puts them at a disadvantage in terms of performance. HTTP/2 and ProtoBuf used by gRPC are Binary Protocols, so relatively fewer Packets are exchanged. In addition, gRPC further improves efficiency by using Connection Multiplexing and Server/Client Streaming supported by HTTP/2.

## 2. References

* [https://grpc.io/docs/](https://grpc.io/docs/)
* [https://medium.com/@goinhacker/microservices-with-grpc-d504133d191d](https://medium.com/@goinhacker/microservices-with-grpc-d504133d191d)
* [https://github.com/HomoEfficio/dev-tips/blob/master/gRPC%20-%20Overview.md](https://github.com/HomoEfficio/dev-tips/blob/master/gRPC%20-%20Overview.md)
* [https://github.com/protocolbuffers/protobuf/blob/master/examples/addressbook.proto](https://github.com/protocolbuffers/protobuf/blob/master/examples/addressbook.proto)
* [https://tech.ktcloud.com/entry/gRPC%EC%9D%98-%EB%82%B4%EB%B6%80-%EA%B5%AC%EC%A1%B0-%ED%8C%8C%ED%97%A4%EC%B9%98%EA%B8%B0-HTTP2-Protobuf-%EA%B7%B8%EB%A6%AC%EA%B3%A0-%EC%8A%A4%ED%8A%B8%EB%A6%AC%EB%B0%8D](https://tech.ktcloud.com/entry/gRPC%EC%9D%98-%EB%82%B4%EB%B6%80-%EA%B5%AC%EC%A1%B0-%ED%8C%8C%ED%97%A4%EC%B9%98%EA%B8%B0-HTTP2-Protobuf-%EA%B7%B8%EB%A6%AC%EA%B3%A0-%EC%8A%A4%ED%8A%B8%EB%A6%AC%EB%B0%8D)
* GRPC Status Code : [https://grpc.io/docs/guides/status-codes/](https://grpc.io/docs/guides/status-codes/)

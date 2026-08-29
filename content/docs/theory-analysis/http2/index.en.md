---
title: HTTP/2
---

Analyzing HTTP/2.

## 1. HTTP/2

HTTP/2 is a protocol created to improve the slow performance of the existing HTTP/1. The improvements of HTTP/2 compared to HTTP/1 are as follows.

### 1.1. Stream, Multiplexing

{{< figure caption="[Figure 1] HTTP/2 Components" src="images/http2-components.png" width="900px" >}}

[Figure 1] shows the components of HTTP/2. HTTP/2 implements multiplexing by placing multiple **Streams** that serve as logical channels within a single **Connection**. Within each Stream, the server and client exchange **Messages** independently regardless of other streams. Messages are broken down and composed of the minimum transmission unit called **Frames**.

{{< figure caption="[Figure 2] HTTP/2 Stream Multiplexing" src="images/http2-stream-multiplexing.png" width="900px" >}}

The reason the Stream concept was born in HTTP/2 is to reduce transmission waiting time between server and client and eliminate HOL Blocking (Head of Line Blocking) phenomena. [Figure 2] shows Stream Multiplexing. In the existing HTTP/1, within a single connection, the server or client could not send messages simultaneously and had to exchange messages in a ping-pong format. Therefore, the server or client had unnecessarily long waiting times, and if the previous message transmission was slow, it greatly affected the subsequent message transmission. HTTP/2 solved the HOL Blocking problem by introducing logical channels called Streams. HTTP/2 performs Flow Control for each Stream unit. HTTP/2's Stream Flow Control uses a method of creating windows similar to TCP's Flow Control.

{{< figure caption="[Figure 3] HTTP/2 Frame Interleaving" src="images/http2-frame-interleaving.png" width="900px" >}}

[Figure 3] shows how multiplexing is actually implemented through Streams in HTTP/2. Stream implementation is achieved through Frame Interleaving. Frames belonging to each Stream are transmitted simultaneously through time division. Frames arriving at the destination are reassembled and delivered to the server or client through the Stream Number information included in the Frame Header. The Frame Header also includes information indicating the Frame's Type, and representative types include the HEADER Type containing HTTP/2 headers and the DATA Type containing HTTP/2 body.

### 1.2. Request, Response Processing and Stream

```text {caption="[Text 1] Request, Response Processing through Streams"}
1 TCP Connection
├── Stream 0 : Reserved for connection control frames (SETTINGS, PING, GOAWAY)
├── Stream 1 (Request/Response A) : HEADERS Frame → DATA Frame... → HEADERS Frame (Trailer)
├── Stream 3 (Request/Response B) : HEADERS Frame → DATA Frame...
└── Stream 5 (Request/Response C) : HEADERS Frame → ...
```

In HTTP/2, **all requests and responses are processed only on Streams**, and there is no way to send Headers or Body outside a Stream. As shown in [Text 1], a single request/response pair is mapped 1:1 to a single Stream, a new Stream is created when a request starts, and when the response completes, the Stream is closed and never reused. The relationship between request/response processing and Streams has the following characteristics.

* Stream creation is completed **simply by sending a HEADERS Frame with a new Stream ID**, without any separate negotiation process. In other words, "creating a Stream" and "sending Headers" are not separate steps; the first HEADERS Frame performs both roles at the same time. Therefore, even if a Stream is dynamically created for each request, no additional round-trip (RTT) cost such as TCP Connection establishment occurs.
* Streams created by the Client are assigned odd Stream IDs (`1`, `3`, `5`...) in monotonically increasing order, and Streams created by the Server (Server Push) are assigned even Stream IDs (`2`, `4`, `6`...) in monotonically increasing order. This is to prevent Stream ID collisions even when the Client and Server create Streams at the same time. Stream IDs are not reused within a single Connection, and when IDs are exhausted (2^31), a new Connection is created to process subsequent requests.
* Stream ID `0` is not a Stream but is reserved for **control Frames that apply to the entire Connection** (SETTINGS, PING, GOAWAY), and these control Frames do not carry Headers.
* gRPC creating one Stream per RPC also simply follows HTTP/2's "one request/response pair = one Stream" rule.

### 1.3. Header, Trailer

An HTTP Message consists of three sections: **Header Section, Body, and Trailer Section**. Headers and Trailers are both lists of Fields in the same format (name-value pairs), and the only difference is their position: fields sent before the Body are Headers, and fields sent after the Body are Trailers.

In HTTP/2, both Headers and Trailers are transmitted as **HEADERS Frames**. There is no separate Frame Type for Trailers; the first HEADERS Frame that starts the Stream serves as the Header, and the last HEADERS Frame (with the END_STREAM Flag) sent after the Body (DATA Frames) serves as the Trailer.

* Header : Represents the metadata of a request or response. In HTTP/2, the HTTP/1.1 Request Line (`GET /home HTTP/1.1`) and Status Line (`HTTP/1.1 200 OK`) are not separate lines but are converted into **Pseudo-Headers** with the `:` prefix, such as `:method`, `:path`, `:scheme`, `:authority`, and `:status`, and are transmitted in the HEADERS Frame together with regular Headers.
* Trailer : Represents information that can only be determined after the entire Body has been transmitted. Typical examples are the final processing result of a response or the checksum of the Body, and a representative use case is gRPC sending the `grpc-status` Header, the final processing result of an RPC, as a Trailer. Since Trailers arrive after the entire Body has been received, Pseudo-Headers such as `:status` and Fields required to interpret the Body such as `content-length` cannot be set in Trailers.

### 1.4. Header Compression

{{< figure caption="[Figure 4] HTTP/2 Header Compression" src="images/http2-header-compression.png" width="900px" >}}

Generally, HTTP headers store a lot of metadata such as cookies and user agents, so the length of HTTP headers often doesn't differ much compared to the length of HTTP body. The problem is that due to the stateless nature of HTTP, the same HTTP header content is frequently sent multiple times to the same server. Therefore, long HTTP headers are one of the major overheads in HTTP communication.

HTTP/2 provides header compression techniques to reduce this HTTP header overhead. [Figure 4] shows the header compression technique. HTTP/2's header compression is handled internally by a module called **HPACK**, which performs compression through the Huffman Algorithm, Static Table, and Dynamic Table. The Huffman Algorithm is a technique that compresses data by mapping frequently occurring strings to short bitmaps in order of frequency. The Static Table is a table defined in the HTTP/2 specification that stores key-value pairs frequently used in HTTP/2 headers. The Dynamic Table is a table that serves as a buffer for arbitrarily storing key-value pairs of headers that have been sent/received once.

[Figure 4] shows the compression process when the same HTTP/2 header is sent twice. When sending a header for the first time, if any key-value pairs in the header to be sent match those in the Static Table, those key-value pairs are replaced with the Static Table index. In [Figure 4], we can see that ":method GET" and ":scheme POST" are changed to Static Table indices 2 and 7, respectively.

The remaining key-value pairs that were not changed using the Static Table are each compressed using the Huffman Algorithm. The key-value pairs compressed through Huffman are stored in the Dynamic Table. In [Figure 4], we can see that ":host ssup.com", ":path /home", and "user-agent Mozilla/5.0" are stored in Dynamic Table index 62. When sending the same header again, it is compressed more efficiently than when sending the first header using the Dynamic Table. In [Figure 4], for the second header transmission, we can see that the header is compressed using only Static and Dynamic Tables without using the Huffman Algorithm.

Since the Static Table has indices up to 61, the Dynamic Table indices start from 62. The Dynamic Table operates in FIFO (First In, First Out) format. That is, when the Dynamic Table is full and there is insufficient space to store new key-value pairs, the longest-stored key-value pairs are removed and new key-value pairs are stored. Since the Dynamic Table is shared **per Connection**, not per Stream, identical Headers are compressed efficiently even for requests sent on different Streams.

### 1.5. Stream Priority

{{< figure caption="[Figure 5] HTTP/2 Stream Priority" src="images/http2-stream-priority.png" width="200px" >}}

HTTP/2's Stream provides a Weight-based Priority function. Through the Stream Priority function, messages with higher priority can be sent first. [Figure 5] shows the Weight values of each Stream and the Weight relationships between Streams. The Weight relationships between Streams form a tree structure. Weight can have values from 1 to 256. Basically, the amount of resources allocated to a Stream is determined proportionally to the Weight. Here, resources refer to resources necessary for message transmission such as CPU, Memory, and Network Bandwidth.

In [Figure 5], since Stream A has a Weight of 12 and Stream B has a Weight of 4, the resource ratio between Stream A and Stream B is 3:1. Since Stream B has only Stream C as its subordinate stream, the resource ratio between Stream B and Stream C is 1:1. Since Stream C has Stream D with Weight 8 and Stream E with Weight 4 as subordinate streams, Stream D can use 2/3 of the resources available to Stream C, and Stream C can use 1/3 of the resources available to Stream D. Therefore, the ratio of Stream C, D, E is 3:2:1. Overall, the resource ratio of Stream A, B, C, D, E is 9:3:3:2:1.

### 1.6. Server Push

{{< figure caption="[Figure 6] HTTP/2 Server Push" src="images/http2-server-push.png" width="450px" >}}

In HTTP/2, when the server receives a client's request message, it provides a Server Push function that not only sends a response message to the request but also sends other messages that the client has not yet requested but are expected to be needed by the client. [Figure 6] shows the Server Push operation. The client only requested the /index.html file from the server, but we can see that the server also sends the PNG files necessary for rendering /index.html to the client simultaneously through separate streams.

In [Figure 3], we can see PUSH-PROMISE Type frames, which serve to notify the client of the start of Server Push. PUSH-PROMISE Type frames specify the stream to send the message so that the client can receive the message through that stream.

## 2. References

* [https://http2.github.io/http2-spec](https://http2.github.io/http2-spec)
* HTTP/2 RFC 9113 : [https://datatracker.ietf.org/doc/html/rfc9113](https://datatracker.ietf.org/doc/html/rfc9113)
* [https://developers.google.com/web/fundamentals/performance/http2?hl=ko](https://developers.google.com/web/fundamentals/performance/http2?hl=ko)
* [https://www.slideshare.net/eungjun/http2-40582114](https://www.slideshare.net/eungjun/http2-40582114)
* [https://b.luavis.kr/http2/](https://b.luavis.kr/http2/)
* [https://www.slideshare.net/BrandonK/http2-analysis-and-performance-evaluation-tech-summit-2017-86562049](https://www.slideshare.net/BrandonK/http2-analysis-and-performance-evaluation-tech-summit-2017-86562049)

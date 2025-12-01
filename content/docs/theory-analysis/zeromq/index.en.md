---
title: ZeroMQ
---

## 1. ZeroMQ

ZeroMQ is a High-performance Async Messaging Library targeted at distributed and parallel Systems. It defines fundamental Message Patterns and helps easily implement the defined Message Patterns. It also has the advantage of supporting various languages.

### 1.1. Messaging Pattern

ZeroMQ defines 4 Message Patterns: Request-reply, Pub-sub, Pipeline, and Exclusive pair.

#### 1.1.1. Request-reply

{{< figure caption="[Figure 1] Request-reply Sync" src="images/request-reply-sync.png" width="150px" >}}

Request-reply Pattern refers to a general Pattern where Server replies to Client's Request. Both Sync and Async methods can be implemented with ZeroMQ. [Figure 1] shows the Sync method's Request-reply Pattern. Clients use REQ Type Socket to send Messages to Server. Server uses REP Type Socket to send received Messages back to Clients.

{{< figure caption="[Figure 2] Request-reply Async" src="images/request-reply-async.png" width="500px" >}}

[Figure 2] shows the Async method's Request-reply Pattern. A Broker exists between Server and Client. Broker's ROUTER Type Socket receives Messages from Client's REQ Type Socket on behalf of Server. Broker that received Messages sends Messages to Server's REP Type Socket through DEALER Type Socket.

#### 1.1.2. Pub-sub

{{< figure caption="[Figure 3] Pub-sub" src="images/pub-sub.png" width="500px" >}}

Pub-sub Pattern is a Pattern where Publisher delivers the same Message to all Subscribers. [Figure 3] shows the Pub-sub Pattern. Publisher uses PUB Type Socket to send Messages to all Subscribers. Subscribers use SUB Type Socket to receive Messages. Pub-sub operates in Async method.

#### 1.1.3. Pipeline

{{< figure caption="[Figure 4] Push-pull" src="images/push-pull.png" width="500px" >}}

Pipeline Pattern is a parallel processing Pattern that distributes Messages for processing and collects processed Messages again. [Figure 4] shows the Pipeline Pattern. Messages sent from Ventilator's Push Type Socket are evenly distributed to Workers' Pull Type Sockets. Conversely, Messages sent from Workers' Push Type Sockets are collected at Sink's Pull Type Socket.

#### 1.1.4. Exclusive pair

{{< figure caption="[Figure 5] Exclusive pair" src="images/exclusive-pair.png" width="150px" >}}

Exclusive pair Pattern is a Pattern used when exchanging Messages between 2 Threads in one Process. [Figure 5] shows the Exclusive pair Pattern among 3 Threads. Only PAIR Type Socket is used.

## 2. References

* [http://zguide.zeromq.org/page:all](http://zguide.zeromq.org/page:all)
* [https://blog.scottlogic.com/2015/03/20/ZeroMQ-Quick-Intro.html](https://blog.scottlogic.com/2015/03/20/ZeroMQ-Quick-Intro.html)


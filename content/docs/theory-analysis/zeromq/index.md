---
title: ZeroMQ
---

## 1. ZeroMQ

ZeroMQ는 분산, 병렬 System을 Target으로한 High-performance Async Messaging Library이다. 기초가 된는 Message Pattern을 정의하고 정의한 Message Pattern을 쉽게 구현할 수 있도록 도와준다. 다양한 언어를 지원한다는 장점도 갖고 있다.

### 1.1. Messaging Pattern

ZeroMQ에서는 Request-reply, Pub-sub, Pipeline, Exclusive pair 4가지 Message Pattern을 정의하고 있다.

#### 1.1.1. Request-reply

{{< figure caption="[Figure 1] Request-reply Sync" src="images/request-reply-sync.png" width="150px" >}}

Request-reply Pattern은 Client의 Request를 Server가 Reply하는 일반적인 Pattern을 의미한다. Sync방식 Async방식 둘다 ZeroMQ로 구현할 수 있다. [Figure 1]은 Sync 방식의 Request-reply Pattern을 나타내고 있다. Client에서는 REQ Type Socket을 이용하여 Message를 Server에게 전송한다. Server에서는 REP Type Socket을 이용하여 수신한 Message를 Client에게 다시 전송한다.

{{< figure caption="[Figure 2] Request-reply Async" src="images/request-reply-async.png" width="500px" >}}

[Figure 2]는 Async 방식의 Request-reply Pattern을 나타내고 있다. Server-Client 사이의 Broker가 존재한다. Broker의 ROUTER Type Socket은 Client의 REQ Type Socket으로 부터 Server 대신 Message를 전달 받는다. Message를 받은 Broker는 DEALER Type Socket을 통해서 Server의 REP Type Socket으로 Message를 전송한다.

#### 1.1.2. Pub-sub

{{< figure caption="[Figure 3] Pub-sub" src="images/pub-sub.png" width="500px" >}}

Pub-sub Pattern은 Publisher가 모든 Subscriber에게 동일한 Message를 전달하는 Pattern이다. [Figure 3]은 Pub-sub Pattern을 나타내고 있다. Publisher는 PUB Type Socket을 이용하여 모든 Subscriber에게 Message를 전송한다. Subscriber는 SUB Type Socket을 이용하여 Message를 수신한다. Pub-sub은 Async 방식으로 동작한다.

#### 1.1.3. Pipeline

{{< figure caption="[Figure 4] Push-pull" src="images/push-pull.png" width="500px" >}}

Pipeline Pattern은 Message를 분산하여 처리하고, 처리된 Message를 다시 모으는 병렬처리 Pattern이다. [Figure 4]는 Pipeline Pattern을 나타내고 있다. Ventilator의 Push Type Socket으로 전송된 Message는 Worker의 Pull Type Socket에게 균일하게 분산된다. 반대로 Worker의 Push Type Socket으로 전송된 Message는 Sink의 Pull Type Socket으로 모인다.

#### 1.1.4. Exclusive pair

{{< figure caption="[Figure 5] Exclusive pair" src="images/exclusive-pair.png" width="150px" >}}

Exclusive pair Pattern은 하나의 Process에서 2개의 Thread 사이의 Message를 주고 받을때 이용하는 Pattern이다. [Figure 5]는 3개의 Thread 사이에서의 Exclusive pair Pattern을 나타내고 있다. PAIR Type Socket만 이용된다.

## 2. 참고

* [http://zguide.zeromq.org/page:all](http://zguide.zeromq.org/page:all)
* [https://blog.scottlogic.com/2015/03/20/ZeroMQ-Quick-Intro.html](https://blog.scottlogic.com/2015/03/20/ZeroMQ-Quick-Intro.html)

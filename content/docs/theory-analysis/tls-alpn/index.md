---
title: TLS ALPN (Application Layer Protocol Negotiation)
---

TLS의 ALPN (Application Layer Protocol Negotiation)을 분석한다.

## 1. ALPN (Application Layer Protocol Negotiation)

ALPN은 TLS의 Handshake 과정중 가장 처음에 이루어지는 Hello 과정에 이용되는 TLS의 확장 기법이다. 이름에서 알 수 있는것 처럼 Server와 Client 사이에 어떤 Protocol을 이용하여 통신을 수행할지를 결정하는 역할을 수행한다. 

{{< figure caption="[Figure 1] ALPN을 이용한 TLS의 Handshake 과정" src="images/tls-alpn.png" width="600px" >}}

[Figure 1]은 ALPN 기법의 예시를 나타내고 있다. Client Hello Message의 ALPN Field에 Client가 이용 가능한 모든 Protocol을 명시하며 전달하며, Server는 이 중에서 통신에 이용할 하나의 Protocol을 선택하여 Client에게 전달한다. [Figure 1]에서는 HTTP/2.0 Protocol을 이용하기로 결정한 예시를 나타내고 있다. 만약 ALPN이 설정되어 있지 않는다면 HTTP/1.1 Protocol을 이용한다.

## 2. 참조

* [https://luavis.me/server/tls-101](https://luavis.me/server/tls-101)

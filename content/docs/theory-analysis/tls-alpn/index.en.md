---
title: TLS ALPN
---

This article analyzes TLS ALPN (Application Layer Protocol Negotiation).

## 1. ALPN (Application Layer Protocol Negotiation)

**ALPN** is a TLS extension technique used in the Hello process, which takes place at the very beginning of the TLS Handshake process. As the name suggests, it plays the role of deciding which Protocol the Server and Client will use to communicate.

{{< figure caption="[Figure 1] TLS Handshake process using ALPN" src="images/tls-alpn.png" width="600px" >}}

[Figure 1] shows an example of the ALPN technique. The Client specifies all Protocols it can use in the ALPN Field of the Client Hello Message and sends it, and the Server selects one Protocol to use for communication among them and delivers it to the Client. [Figure 1] shows an example where the HTTP/2.0 Protocol is chosen. If ALPN is not configured, the HTTP/1.1 Protocol is used.

## 2. References

* Useless but Fascinating TLS Knowledge : [https://luavis.me/server/tls-101](https://luavis.me/server/tls-101)

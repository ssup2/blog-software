---
title: TLS SNI
---

This post analyzes TLS SNI (Server Name Indication).

## 1. SNI (Server Name Indication)

**SNI** is a TLS extension technique used in the Hello process, which takes place first during the TLS Handshake. In the past, one Domain was registered and used per Server (IP). Nowadays, however, multiple Domains are registered and used on a single Server (IP). For this reason, when a Client requests a certificate over SSL without SNI from a Server that has multiple Domains, the Server cannot know exactly which Domain's certificate to deliver to the Client. TLS SNI solves this problem.

{{< figure caption="[Figure 1] TLS Handshake Process using SNI" src="images/tls-sni.png" width="600px" >}}

[Figure 1] shows the TLS Handshake process using SNI. The operation is simple. The Client specifies in the SNI Field of the Hello Message which Domain's certificate it wants to receive and sends it to the Server. The Server then sends an empty value in the SNI Field of the Hello Message to inform the Client that it has received the SNI request. It then sends the Client the certificate of the Domain requested by the Client. The rest of the Handshake process is the same as the TLS/SSL Handshake process.

Since the Client's Hello Message is sent to the Server without encryption, there is a problem that the SNI Field is also exposed as-is without encryption.

## 2. References

* SNI extension of the TLS handshake protocol (figure) : [https://www.researchgate.net/figure/SNI-extension-of-the-TLS-handshake-protocol-fig6-321580115](https://www.researchgate.net/figure/SNI-extension-of-the-TLS-handshake-protocol-fig6-321580115)

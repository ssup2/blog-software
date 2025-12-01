---
title: WebSocket
---

Analyzes WebSocket.

## 1. WebSocket

WebSocket is a Protocol that enables **Full-duplex** communication between Web Browser and Server. WebSocket uses HTTP Protocol during Handshaking, but after Handshaking, Web Browser and Server exchange Data using WebSocket's own Protocol over TCP/IP Stack without using HTTP. That is, Web Client and Server switch from HTTP Protocol to WebSocket Protocol.

{{< figure caption="[Figure 1] Websocket Handshaking" src="images/websocket-handshaking.png" width="600px" >}}

[Figure 1] shows the Handshaking process of WebSocket. The switch from HTTP Protocol to WebSocket Protocol is made through HTTP's **Upgrade** Protocol. Upgrade Protocol is a Protocol for switching from HTTP to another Protocol. In [Figure 1], you can see that Web Browser and Server exchange Upgrade Protocol-related Headers such as "Upgrade: websocket" and "Connection: Upgrade".

Sec-WebSocket-Key is a randomly generated value used to calculate the Sec-WebSocket-Accept value. Clients can verify through the Sec-WebSocket-Accept value whether it is a response to their requested WebSocket Handshaking.

The Sec-WebSocket-Accept value can be calculated by concatenating the Sec-WebSocket-Key value with the string `258EAFA5-E914-47DA-95CA-C5AB0DC85B11`, then performing SHA-1 Hashing and Base64 Encoding. Sec-WebSocket-Protocol represents the SubProtocol that the Application will use. After WebSocket Handshaking is completed, Clients and Server can freely exchange Messages with each other. Messages are split into small units called **Data Frames** for transmission. Data Frames consist of small-sized Headers and Payloads.

## 2. References
* [https://tools.ietf.org/html/rfc6455](https://tools.ietf.org/html/rfc6455)
* [https://en.wikipedia.org/wiki/WebSocket](https://en.wikipedia.org/wiki/WebSocket)
* [https://stackoverflow.com/questions/14133452/which-osi-layer-does-websocket-protocol-lay-on](https://stackoverflow.com/questions/14133452/which-osi-layer-does-websocket-protocol-lay-on)


---
title: Web Polling, Long Polling, Server-sent Events, WebSocket
---

HTTP/1.1 Protocol, which is still the most widely used between Web Browser and Server, is a unidirectional Protocol where Web Browser (Client) first sends a request to Server, and then Server sends a response to the request. In this limited Web environment, various workaround techniques exist for bidirectional real-time communication between Web Browser and Server. This document compares and analyzes Polling, Long Polling, Server-sent Events, and WebSocket related to this.

## 1. Polling

{{< figure caption="[Figure 1] Polling" src="images/polling.png" width="600px" >}}

Polling is the simplest technique to deliver Data from Server to Web Browser. [Figure 1] shows the Polling technique. Web Browser periodically checks with Server whether Events have occurred. If no Event has occurred, the response does not include Event information. On the other hand, if an Event has occurred, Event information is also sent in the response.

Since it is a method of periodically checking with Server whether Events have occurred from Web Browser, it has the disadvantage of poor real-time performance. Also, even if Events have not occurred, periodic request/response exchanges occur between Web Browser and Server, so it has the disadvantage of generating periodic Traffic.

However, it has advantages in terms of compatibility, as it can be used in most Web Browsers, and Event information can be obtained at once and processed in batches in Web Browser. It is generally implemented using Polling method based on HTTP Protocol and AJAX Timer.

## 2. Long Polling

{{< figure caption="[Figure 2] Long Polling" src="images/long-polling.png" width="600px" >}}

Long Polling is a technique that can compensate for the disadvantage of Polling method, which is insufficient real-time performance. [Figure 2] shows the Long Polling technique. When Web Browser sends a request, Server does not send a response until an Event occurs, and when an Event occurs, it sends a response along with the Event.

Due to this characteristic, it has the advantage of being able to send Server's Events to Web Browser almost in real-time. However, since Web Browser's request process is necessary to receive one Event from Server, if Server's Events occur frequently, inefficient Traffic waste can occur. Therefore, Long Polling should be used in environments where Server's Events do not occur frequently.

It is generally easily implemented using HTTP Protocol and JavaScript's `await` syntax, and also has the advantage of being usable in most Web Browsers.

## 3. Server-sent Events

{{< figure caption="[Figure 3] Server-sent Events" src="images/server-sent-events.png" width="600px" >}}

Server-sent Events technique is a technique that sends Events unidirectionally from Server to Web Browser without Web Browser's intervention. That is, it is a technique where Web Browser receives Server's Events through Subscription to Server's Events. Events cannot be sent from Web Browser to Server. [Figure 3] shows the Server-sent Events technique. Web Browser sends a request to Server to Subscribe to specific Events. Thereafter, when the Event occurs, Server sends the Event to Web Browser.

Server-sent Events is included in HTML5's standard and operates based on HTTP Protocol. It is possible to operate with HTTP 1.1 Protocol, but it is recommended to use it through HTTP 2.0 Protocol if possible. This is because most Web Browsers allow a maximum of 6 TCP Connections to one Server, so only up to 6 Events can be Subscribed through HTTP 1.1 Protocol. On the other hand, when using HTTP 2 Protocol, multiple Events can be Subscribed through one TCP Connection through HTTP 2 Protocol's TCP Connection Multiplexing functionality.

Generally, Server-sent Events can be used through JavaScript's `EventSource()` function. It also has the disadvantage of not being properly supported in some Web Browsers such as Internet Explorer. Server-sent Events is specialized for Event Subscription compared to WebSocket. It only supports unidirectional communication, but manages each Event through Event ID, and the Reconnection process during Network failures is better defined compared to WebSocket. Also, since it is HTTP Protocol-based, it has the advantage of being freer from Firewall policies compared to WebSocket.

## 4. WebSocket

{{< figure caption="[Figure 4] WebSocket" src="images/websocket.png" width="600px" >}}

WebSocket technique is a technique that supports bidirectional real-time communication between Web Browser and Server. [Figure 4] shows the WebSocket technique. Web Browser and Server use HTTP Protocol during the Handshake process, but after switching from HTTP Protocol to WebSocket Protocol through HTTP Upgrade Protocol, they do not use HTTP Protocol and only use WebSocket Protocol.

Generally, Events are exchanged through JavaScript's `WebSocket()` function. WebSocket has advantages compared to Server-sent Events in that it supports bidirectional real-time communication and is supported in more Web Browsers compared to Server-sent Events. However, it also has the disadvantage of being more restricted by Firewall policies since HTTP Protocol is not used when exchanging Messages and Events.

## 5. References

* [https://medium.com/system-design-blog/long-polling-vs-websockets-vs-server-sent-events-c43ba96df7c1](https://medium.com/system-design-blog/long-polling-vs-websockets-vs-server-sent-events-c43ba96df7c1)
* [https://codeburst.io/polling-vs-sse-vs-websocket-how-to-choose-the-right-one-1859e4e13bd9](https://codeburst.io/polling-vs-sse-vs-websocket-how-to-choose-the-right-one-1859e4e13bd9)
* [https://stackoverflow.com/questions/5195452/websockets-vs-server-sent-events-eventsource](https://stackoverflow.com/questions/5195452/websockets-vs-server-sent-events-eventsource)
* [https://ko.javascript.info/long-polling](https://ko.javascript.info/long-polling)
* [https://stackoverflow.com/questions/39274809/does-server-sent-events-utilise-http-2-pipelining](https://stackoverflow.com/questions/39274809/does-server-sent-events-utilise-http-2-pipelining)


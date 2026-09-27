---
title: Proxy Server
---

This post analyzes Forward Proxy and Reverse Proxy.

## 1. Proxy

{{< figure caption="[Figure 1] Forward Proxy, Reverse Proxy" src="images/proxy-server.png" width="900px" >}}

A **Proxy Server** refers to a Component that acts on behalf of the Server or the Client in a Server-Client relationship. The Proxy Server receives the Client's request on behalf of the Server, then forwards the received request to the Server on the Client's behalf, and receives the Server's response on its behalf. It then operates by delivering the response received from the Server back to the Client. Proxy Servers can be classified into Forward Proxy and Reverse Proxy depending on where they are located. [Figure 1] shows the Forward Proxy and the Reverse Proxy.

### 1.1. Forward Proxy

A Forward Proxy refers to a **Client Side Proxy** that acts on behalf of multiple Clients. The main role of the Forward Proxy is **Server response Caching**. When the Forward Proxy receives a Client's request, it searches its Cache for a valid response from the Server before forwarding the request to the Server. If a valid response exists in the Cache, the Forward Proxy obtains the Server's response from the Cache and delivers it to the Client. If no valid response exists in the Cache, it forwards the Client's request to the Server, receives the response from the Server, and then caches and utilizes the received response.

Through the Forward Proxy's Server response Caching, network usage is reduced and the Client can receive a fast response. It also plays a role in reducing the load on the Server.

### 1.2. Reverse Proxy

A Reverse Proxy refers to a **Server Side Proxy** that acts on behalf of multiple Servers. The main roles of the Reverse Proxy are **Server Load Balancing** and **Server response Caching**. Through Server Load Balancing, the Reverse Proxy evenly distributes Client requests across multiple Servers to spread the Server load, and even if some Servers are not operating, it delivers Client requests only to the operating Servers, providing high availability for the Servers. In addition, it can also perform the Server response Caching role like the Forward Proxy when needed.

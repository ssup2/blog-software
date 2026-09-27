---
title: Nginx Architecture
---

This post analyzes the Architecture of Nginx.

## 1. Nginx Architecture

{{< figure caption="[Figure 1] Nginx Architecture" src="images/nginx-architecture.png" width="900px" >}}

[Figure 1] shows the Architecture of Nginx. **Nginx** consists of a Master Process, Worker Processes, a Cache Loader Process, a Cache Manager Process, and a Config file.

### 1.1 Master Process

The Master Process is the Process that runs first when Nginx starts. Based on the configuration obtained from the Config file, it creates the Worker Processes, the Cache Loader Process, and the Cache Manager Process, and delivers the relevant configuration to the created Processes.

### 1.2. Worker Process

The Worker Process is the Process that actually receives and handles the Client's requests. Multiple Worker Processes run, and the Master Process creates as many Worker Processes as the number of Worker Processes configured in the Config file. The Client's requests are distributed to and handled by the multiple Worker Processes. A Worker Process basically uses a **single Thread** and handles the Client's requests **asynchronously** using Multiplexing functions provided by the Kernel, such as `select()`, `epoll()`, and `kqueue()`. That is, even if the number of Connections with Clients increases, the number of Worker Processes does not increase, and the requests are handled asynchronously by the already created Worker Processes.

Conventional Web Servers such as the Apache HTTP Server used a method of creating and using a dedicated Process/Thread responsible for the Connection with each Client. With this method, as the Connections with Clients increased, the number of Processes/Threads also increased, causing Memory waste and excessive Context Switching Overhead problems. Nginx solved these problems by using the Async method, and shows better performance than conventional Web Servers.

Since a Worker Process handles requests only within a single Thread, calling a function that takes a long time to process causes a Blocking problem in which the other requests the Worker Process must handle cannot be processed and have to wait. In particular, File Read/Write related functions that involve Disk operations can take a long processing time depending on the situation. To solve this Blocking problem, Nginx provides the Thread Pool technique, which handles File Read/Write operations in a separate Thread Pool.

The Master Process does not use a separate technique to distribute the Client's Connections (requests) to the Worker Processes, but uses the Kernel's functionality as-is. Each Worker Process registers the Listen Socket shared by all Worker Processes with a Multiplexing function such as `select()`, `epoll()`, or `kqueue()`, and waits on the Multiplexing function. Then, when a Connection request arrives from a Client, the Kernel wakes up an arbitrary Worker Process among the Worker Processes waiting on the Multiplexing function and makes it handle the Connection request.

That is, even if the same Socket is simultaneously registered with and waited on by Multiplexing functions in multiple Processes, the Kernel wakes up only one arbitrary Process when an Event occurs, and this characteristic is used to distribute the Client's Connections.

### 1.3. Cache

Nginx uses a Caching technique that stores the responses sent from the Backend in a Cache and then utilizes the Backend's responses stored in the Cache when the same request arrives from a Client. The Cache's Key and Meta information are stored in Shared Memory accessible to all of Nginx's Processes, and the Cache's Data is stored in Files.

Even though the Cache's Data is stored as Files, it is appropriately stored not only on Disk but also in Memory by the Filesystem Cache provided by the Kernel, so Nginx can mostly obtain the Cache's Data quickly. However, the Cache's Data may not exist in the Filesystem Cache and exist only on Disk, which can take a long time. One way to solve this problem is to use the Thread Pool technique mentioned above. In the case of Linux, the Page Cache is provided as the Filesystem Cache. Nginx does not store and use the Cache's Data in separate Memory of its own.

The Cache's Data basically remains and is used by Nginx unless it is deleted due to exceeding the Cache size. When the Cache size is exceeded, the Cache's Data is deleted starting from the least recently used Data according to the LRU (Least Recently Used) Algorithm. Alternatively, the Cache can be configured to expire and be deleted after a certain period of time. This Cache size and Expiration management is performed periodically by the Cache Manager Process. The Cache size and the Cache's Expiration time can be configured through the Config file.

The Cache Loader Process is executed only once by the Master Process when Nginx starts, and performs the role of setting the Cache's Keys and Meta in Shared Memory based on the Cache's Data stored as Files.

### 1.4. Client, Backend

Nginx performs the role of an L7 Web Server and Load Balancer based on HTTP/HTTPS. It can also perform the role of an L4 Load Balancer based on TCP/UDP. When Nginx operates as an L7 Web Server and Load Balancer, Nginx communicates with Clients over HTTP/HTTPS and communicates with the Backend using HTTPS/HTTPS or FastCGI. When Nginx operates as an L4 Load Balancer, Nginx communicates with Clients and the Backend using TCP/UDP. Key-Value Stores classified as NoSQL, such as Memcached and Redis, can also be used as Nginx's Backend.

## 2. References

* NGINX Architecture - SlideShare : [https://www.slideshare.net/jen6/nginx-architecture](https://www.slideshare.net/jen6/nginx-architecture)
* The Architecture of Open Source Applications - nginx : [http://www.aosabook.org/en/nginx.html](http://www.aosabook.org/en/nginx.html)
* NGINX Internals - SlideShare : [https://www.slideshare.net/joshzhu/nginx-internals](https://www.slideshare.net/joshzhu/nginx-internals)
* NGINX High Performance Caching : [https://www.nginx.com/blog/nginx-high-performance-caching/](https://www.nginx.com/blog/nginx-high-performance-caching/)
* Thread Pools in NGINX Boost Performance 9x : [https://www.nginx.com/blog/thread-pools-boost-performance-9x/](https://www.nginx.com/blog/thread-pools-boost-performance-9x/)
* Can I call accept() for one socket from several threads simultaneously : [https://stackoverflow.com/questions/11488453/can-i-call-accept-for-one-socket-from-several-threads-simultaneously](https://stackoverflow.com/questions/11488453/can-i-call-accept-for-one-socket-from-several-threads-simultaneously)

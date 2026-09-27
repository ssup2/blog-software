---
title: Nginx Thread Pool
---

This post analyzes the Thread Pool technique of Nginx.

## 1. Nginx Thread Pool

{{< figure caption="[Figure 1] Nginx Worker Process without Thread Pool" src="images/nginx-worker-process-without-thread-pool.png" width="300px" >}}

This post analyzes Nginx's Thread Pool technique. [Figure 1] shows the operation of the conventional Worker Process without Nginx's Thread Pool technique applied. Nginx's Worker Process runs an Event Loop within a single Thread using Multiplexing functions provided by the Kernel, such as `select()`, `epoll()`, and `kqueue()`. The Event Loop repeats the process of waiting for, monitoring, and processing Events.

This single-Thread Event Loop technique prevents the excessive creation of Processes/Threads, bringing performance benefits such as Kernel Memory savings and reduced Context Switching Overhead. However, it has a major problem: if an Event takes a long time to process and occupies the single Thread, a Blocking phenomenon occurs in which the processing of other Events is also delayed. File Read/Write operations that involve Disk operations can occupy the Thread for a long time depending on the situation, so they are the main cause of the Blocking phenomenon. Functions of Nginx Third-party Modules with long processing times can also be a cause.

Since Nginx Caches Backend responses as Files, File Read/Write operations occur very frequently. If the same requests come frequently, Disk access is minimized through the Memory-based Filesystem Cache, so fast File Read/Write operations are possible. However, when exchanging large Data Streams such as Video Streaming Data, the benefit of the Filesystem Cache cannot be obtained, so most File Read/Write operations end up accessing the Disk and inevitably become slow. Nginx's Thread Pool technique was devised to solve the Blocking problem caused by such File Read/Write operations.

{{< figure caption="[Figure 2] Nginx Worker Process with Thread Pool" src="images/nginx-worker-process-with-thread-pool.png" width="900px" >}}

[Figure 2] shows the Worker Process with the Thread Pool technique applied. The Main Thread, where the Event Loop runs, either processes Events directly or puts Events into the Event Queue. The Worker Threads of the Thread Pool take the Events in the Event Queue one by one and process them, and when the processing is complete, they send an Event processing completion message to the Main Loop. In this Thread Pool technique, even if one Worker Thread is Blocked by Event processing, it does not affect the remaining Worker Threads, so the Blocking problem can be solved.

Currently, Nginx processes only File Read/Write operations in the Threads of the Thread Pool, and the remaining Events are processed in the Main Thread as before. The number of Threads in the Thread Pool can be changed through configuration. Nginx's Thread Pool technique is available in Nginx Versions 1.7.11 and later.

## 2. References

* Thread Pools in NGINX Boost Performance 9x : [https://www.nginx.com/blog/thread-pools-boost-performance-9x/](https://www.nginx.com/blog/thread-pools-boost-performance-9x/)

---
title: Serverless Architecture, BaaS, FaaS
---

This document analyzes Serverless Architecture and BaaS (Backend as a Service) and FaaS (Function as a Service), which are services based on Serverless Architecture.

## 1. Serverless Architecture

{{< figure caption="[Figure 1] Serverless Architecture" src="images/serverless-architecture.png" width="700px" >}}

Serverless Architecture means an architecture that minimizes server functionality by transferring server functionality to clients. Since servers in Serverless Architecture mostly perform only small functions without side effects, server management, deployment, and Scale Out are easier compared to general servers. Using these characteristics, Cloud Service Providers provide an environment that completely automates server management to help app developers focus only on app logic when developing apps based on Serverless Architecture. BaaS (Backend as a Service) and FaaS (Function as a Service) are representative techniques utilizing Serverless Architecture.

### 1.1. BaaS (Backend as a Service)

BaaS means a technique that provides Backend functions such as DB, Storage, and authentication as services, as the name suggests. Google's Firebase is a representative BaaS. Backend Services are automatically managed and recovered by BaaS and automatically Scale In/Out according to usage. Therefore, app developers can focus on app logic development. In [Figure 1], clients can be considered to use BaaS's DB Service and authentication Service. Since clients directly access BaaS's DB, Backend Logic that was implemented in servers moves to clients and must be implemented in clients.

Since most BaaS charges fees proportional to DB or Storage usage, BaaS can enable fast and low-cost app development when storing small amounts of data in apps. However, when storing large amounts of data in apps, BaaS usage can be inefficient because high fees must be paid and detailed DB and Storage configuration is impossible.

### 1.2. FaaS (Function as a Service)

FaaS means a technique that provides Functions as services, as the name suggests. AWS's Lambda and Google's Cloud Function are representative FaaS. Developers develop Functions and hand them over to FaaS. Developed Functions are automatically deployed, managed, and recovered on servers by FaaS and automatically Scale In/Out according to usage. Therefore, developers can focus only on Function development and app development without worrying about servers.

Functions are written in the form of **Event Handlers** that are executed when events are delivered. Events can be client requests that passed through API Gateway, or requests from services or functions that passed through Message Queue. Event and Function Mapping is configured by developers. Since Functions can access DBs using APIs provided by FaaS or send events to Message Queue, some Backend Logic that was implemented in servers can be implemented in Functions. However, since FaaS is a service that provides Functions as the name suggests, overall app logic is included in clients. In [Figure 1], clients can also be considered to use FaaS's Functions through API Gateway and Message Queue.

Functions are not always running, but rather instances (containers) having those Functions are started each time events occur. Therefore, FaaS's billing method is proportional to the number of times Functions are called. Due to these characteristics, FaaS incurs lower costs compared to existing Cloud Services that keep instances running continuously. Therefore, FaaS can enable fast and low-cost app development when developing apps that are not frequently used. However, FaaS also has disadvantages.

Since Functions are implemented in Event Handler form, they must be Stateless. Also, since Functions are considered units that perform small functions, the maximum execution time of Functions is limited to be short. Therefore, logic that takes a long time cannot be implemented in Functions. Since Function instances are newly started each time events occur, Start Latency occurs due to Runtime initialization before Function execution. Performance degradation due to Start Latency must be considered as Functions are called more frequently. Since servers and containers running Functions are automatically managed, there is also a disadvantage that detailed server, container, and network configuration is impossible.

### 2. References

* [https://martinfowler.com/articles/serverless.html](https://martinfowler.com/articles/serverless.html)
* [https://hackernoon.com/what-is-serverless-architecture-what-are-its-pros-and-cons-cc4b804022e9](https://hackernoon.com/what-is-serverless-architecture-what-are-its-pros-and-cons-cc4b804022e9)
* [https://velopert.com/3543](https://velopert.com/3543)


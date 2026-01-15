---
title: Service Mesh Architecture
---

This document analyzes Service Mesh Architecture.

## 1. Service Mesh Architecture

{{< figure caption="[Figure 1] Service Mesh Architecture" src="images/service-mesh-architecture.png" width="900px" >}}

Service Mesh Architecture is an **Infra Level** Architecture designed to overcome the disadvantage that **centralized control** is not easy in MSA (Micro Service Architecture) that uses multiple services. Google's Istio is a representative implementation of Service Mesh Architecture. [Figure 1] shows Service Mesh Architecture.

Service and Proxy have a 1:1 relationship, and Services perform most functions except Business Logic in Proxy mapped to Service, not in Service (Offloading). Such Proxy is called **Sidecar Proxy** with Sidecar Pattern applied. Since most functions of Services are Offloaded to Proxy, Services can be indirectly controlled through Proxy control. The core of Service Mesh Architecture is to conveniently control multiple services through Control Plane that centrally controls these Proxies.

Since requests from Services to other Services must be delivered outside through Proxy, functions such as Service Discovery, Circuit Breaker, Client-side LB, authentication/authorization, Timeout, Retry, Logging, etc. can be performed through Proxy. Also, since Services receiving requests also receive requests through Proxy, functions such as request filtering and logging can be performed in Proxy. Proxy supports various protocols such as HTTP, gRPC, and TCP. These Proxy functions are functions commonly performed regardless of Services and are called Application Network Functions.

Services consist of Business Logic and Primitive Network Functions. Business Logic handles Business Functions, data calculation/processing, and integration with other Services/Systems. Primitive Network Functions refer to High-level Library/Interface roles that enable Services to communicate with Proxy.

### 1.1. Advantages and Disadvantages

The biggest advantage of Service Mesh Architecture is that various requirements of MSA such as Access Control, Logging, and Security can be easily controlled centrally through Proxy and Control Plane. Another major advantage is high freedom in language selection when implementing Services. Spring Cloud's Hystrix, Ribbon, Eureka, etc. are Frameworks/Libraries that help solve MSA problems when configuring MSA, but have the disadvantage that they can only be used in Java-based Services. Since Service Mesh Architecture uses Proxy that has no dependency on language, language selection freedom is high. This high language selection freedom enables reuse of previously developed Services.

The disadvantage of Service Mesh Architecture is Proxy Overhead. Since the same number of Proxies as Services must also operate, at least 2 times the runtime is required compared to existing Architecture. Also, since additional Network Hops occur due to Proxy, network performance degradation also occurs.

## 2. References

* [https://medium.com/microservices-in-practice/service-mesh-for-microservices-2953109a3c9a](https://medium.com/microservices-in-practice/service-mesh-for-microservices-2953109a3c9a)
* [http://tech.cloudz-labs.io/posts/service-mesh/](http://tech.cloudz-labs.io/posts/service-mesh/)
* [https://waspro.tistory.com/432](https://waspro.tistory.com/432)


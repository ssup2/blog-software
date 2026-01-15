---
title: Spring Cloud Hystrix,Ribbon,Eureka
---

This document analyzes Spring Cloud.

## 1. Spring Cloud

Spring Cloud is a tool that helps with **building and operating Cloud-native Apps** in distributed environments like Cloud. It helps developers easily use configuration, deployment, Discovery, Routing, Load-balancing, etc. of Services that make up Cloud-native Apps. Core modules that enable these operations, such as Hystrix, Eureka, Ribbon, and Zuul, are Projects of Netflix's OSS (Open Source Software).

## 2. Hystrix

{{< figure caption="[Figure 1] Spring Cloud Hystrix" src="images/circuit-breaker.png" width="500px" >}}

Hystrix is a Library that controls Service calls by inserting a **Circuit Breaker** between distributed Services and provides Isolation Points between Services. [Figure 1] shows a Circuit Breaker created and inserted using Hystrix. When Service D is unavailable or the Circuit is Open due to slow response from Service D, the Circuit Breaker blocks Service D calls performed from Service A or Service B to prevent failure propagation and unnecessary Resource usage. It also executes the registered Fallback Service, Service E, to enable flexible failure handling. The Open/Close criteria of the Circuit Breaker are determined through developer settings.

### 2.1. Flow

{{< figure caption="[Figure 2] Spring Cloud Hystrix Operation Process" src="images/hystrix-flow.png" width="900px" >}}

[Figure 2] shows the operation process of Hystrix. A HystrixCommand Instance is an Instance that **wraps Service call Logic**, and Service calls are controlled through the HystrixCommand Instance.

* 1 : Check if the Circuit is Open. If the Circuit is Open, the Service call is stopped and the Fallback Service is called.
* 2 : Even if the Circuit is not Open, if there are no Threads in the Thread Pool required for Service calls or no remaining Semaphores, the Service call is stopped and the Fallback Service is called.
* 3 : After the Service call, check if the Service was called properly. If the Service call was not successful, call the Fallback Service.
* 4 : The Service call is completed, but check if a Timeout occurred. If a Timeout occurred, call the Fallback Service. If a Timeout did not occur, return the Service call result.
* 5 : Through the results (Metrics) of processes 2, 3, 4, Hystrix decides whether to Close or Open the Circuit. It also collects results and reports to developers to help easily understand the current state of Hystrix.
* 6 : If processes 2, 3, 4 fail, call the Fallback Service. If the Fallback Service is not defined or the Fallback Service call fails, return an Error. If the Fallback Service call succeeds, return the Fallback Service result.

### 2.2. Thread

Hystrix uses two Thread policies: **Thread Pool** and **Semaphore**.

#### 2.2.1. Thread Pool

The Thread Pool policy is a method where HystrixCommand Instances call Services using available Thread Pools, as the name suggests. Since it uses Threads from Thread Pools assigned to each HystrixCommand Instance, **high Isolation** is a characteristic. This is because even if Threads assigned within a HystrixCommand Instance are wasted, it does not affect User Request Threads managed by WAS or Thread Pools used by other HystrixCommand Instances. On the other hand, the low performance compared to the Semaphore policy can be considered a disadvantage due to Thread Pool management Overhead and Thread Context Switching Overhead that occurs during Service calls.

In the Thread Pool policy, the maximum number of Services that can be called simultaneously is determined by the number of Threads in the Thread Pool. Therefore, you must predict how many Services will be called simultaneously and assign an appropriate number of Threads to the Thread Pool. Multiple HystrixCommand Instances can also be configured to share and use one Thread Pool. Netflix recommends the Thread Pool policy for Service Isolation.

#### 2.2.2. Semaphore

The Semaphore policy is a method that uses the Thread that requests Service calls through the HystrixCommand Instance as-is, rather than using a separate dedicated Thread for the HystrixCommand Instance. Therefore, since Thread Context Switching does not occur during Service calls, fast performance compared to the Thread Pool policy is an advantage. However, low Isolation is a disadvantage because Threads are shared.

In the Semaphore policy, the maximum number of Services that can be called simultaneously is determined by the number of Semaphores. Therefore, you must predict how many Services will be called simultaneously and set an appropriate number of Semaphores. Netflix guides to use this for Non-network calls that cause enormous load, i.e., when calling Services or functions that do not go through the Network.

## 3. Ribbon

{{< figure caption="[Figure 3] Spring Cloud Ribbon" src="images/ribbon.png" width="450px" >}}

Ribbon is a **Client-side Load Balancer**, a Library that performs Server Load Balancing at the Client, as the name suggests. [Figure 3] shows Ribbon. Ribbon consists of three components: Rule, Ping, and ServerList.

### 3.1. Rule

Rule refers to the Load Balancing algorithm used in Ribbon. Rules can use Rules provided by Ribbon or Rules directly defined by developers. The following 3 Rules are Rules provided by Ribbon.

* RoundRobinRule : A method that uses the Round Robin algorithm.
* AvailabilityFilteringRule : A method that skips Servers that are not operating. Servers where Errors occur consecutively above a certain number of times are excluded from Load Balancing target Servers for a certain period of time. The number of Error occurrences and Load Balancing exclusion time can be freely set by developers.
* WeightedResponseTimeRule : A method that assigns Weights inversely proportional to the average response time of Servers.

### 3.2. Ping

Ping is a component that determines the survival of Servers. Ping can use the DummyPing Class provided by Ribbon or a Ping Class defined by developers.

### 3.3. ServerList

It refers to a Server List that can perform Load Balancing. Methods to obtain Server Lists can use methods provided by Ribbon or methods directly defined by developers. The following 3 methods are methods provided by Ribbon.

* Adhoc static server list : A method that directly puts the Server List in the Code that configures Ribbon.
* ConfigurationBasedServerList : A method that directly puts the Server List in the Config file that configures Ribbon.
* DiscoveryEnabledNIWSServerList : A method that obtains the Server List from the Eureka Client. This is generally the most commonly used method.

Ribbon also provides functionality to filter Server Lists. Server List Filtering methods can also use methods provided by Ribbon or methods defined by developers. The following 2 methods are methods provided by Ribbon.

* ZoneAffinityServerListFilter : Provides only Server Lists in the same Zone as Ribbon.
* ServerListSubsetFilter : Provides only Server Lists that meet conditions set by developers.

## 4. Eureka

{{< figure caption="[Figure 4] Spring Cloud Eureka" src="images/eureka.png" width="600px" >}}

Eureka is a Service that provides **Service Discovery**. [Figure 4] shows Eureka. The Service Registry that manages Services operates as an Eureka Server. And Services that use Eureka operate as Eureka Clients. Service Instances that start operation transmit Service information such as Service name, IP, Port, etc. to the Eureka Server through the Eureka Client. The Eureka Server stores the Service information received from Clients and then transmits Service information to Eureka Clients that request Service Discovery.

Eureka Clients periodically request Service information from Eureka Servers and Cache it. Service information Cache is used to improve Client performance or for HA (High Availability). It also periodically transmits Heartbeats to inform the Eureka Server of the operation state of the Eureka Client. If Heartbeats are not transmitted to the Eureka Server for a certain period of time, Services using that Eureka Client are considered abnormal by the Eureka Server and are excluded from Server information managed by the Eureka Server.

### 4.1. HA(High Availability)

Since Eureka is an important Service that manages all Service information, Eureka's HA must be considered. Generally, for Eureka's HA, Eureka Servers are configured to run multiple Eureka Servers rather than one. When running multiple Eureka Servers, consistency of Service information between Eureka Servers is achieved through Eureka Clients embedded in Eureka Servers. Assuming there are 3 Eureka Servers A, B, C, the Eureka Client of Eureka Server A has URLs of Eureka Servers B, C configured, and periodically obtains Service information from Eureka B, C.

Similarly, Eureka Clients of Services that use Eureka periodically obtain Service information using URLs of configured Eureka Servers A, B, C. If all configured Eureka Servers are not operating, Eureka Clients use cached Service information.

## 5. Hystrix + Ribbon + Eureka

{{< figure caption="[Figure 5] Spring Cloud Hystrix + Ribbon + Eureka" src="images/hystrix-ribbon-eureka.png" width="800px" >}}

When Services are configured using Hystrix, Ribbon, and Eureka of Spring Cloud analyzed so far, the structure becomes like [Figure 5]. Hystrix of Service A recognizes that Service B is not operating properly, opens the Circuit of Service B, and calls Service C, the Fallback Service. Eureka of Service A obtains Service information from the Eureka Server and transmits it to Ribbon. The Eureka Server is running 2 Instances, and the Eureka Client of the first Eureka Server is obtaining Service information from the second Eureka Server. Ribbon of Service A performs Load Balancing based on Instance information of Service D obtained from Eureka. Since the first Instance of Service D is not operating, it calls Service D to the second Instance.

Zuul performs the role of Service End-point as an API Gateway. Zuul also uses Hystrix, Ribbon, and Eureka to provide stable Service end-points.

## 6. References

* Spring Cloud : [https://readme.skplanet.com/?p=13782](https://readme.skplanet.com/?p=13782)
* Hystrix : [https://github.com/Netflix/Hystrix/wiki](https://github.com/Netflix/Hystrix/wiki)
* Hystrix : [http://woowabros.github.io/experience/2017/08/21/hystrix-tunning.html](http://woowabros.github.io/experience/2017/08/21/hystrix-tunning.html)
* Ribbon : [https://github.com/Netflix/ribbon/wiki/Working-with-load-balancers](https://github.com/Netflix/ribbon/wiki/Working-with-load-balancers)
* Ribbon : [https://www.baeldung.com/spring-cloud-rest-client-with-netflix-ribbon](https://www.baeldung.com/spring-cloud-rest-client-with-netflix-ribbon)
* Eureka : [https://www.todaysoftmag.com/article/1429/micro-service-discovery-using-netflix-eureka](https://www.todaysoftmag.com/article/1429/micro-service-discovery-using-netflix-eureka)


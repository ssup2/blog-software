---
title: MSA
---

This post analyzes MSA (Micro Service Architecture).

## 1. MSA (Micro Service Architecture)

**MSA** (Micro Service Architecture) refers to an Architecture composed by combining **multiple small, independent Services** (functions) with **clear boundaries**. The small, independent Services within clear boundaries give MSA flexibility. This flexibility brings many advantages to the development and operation process.

### 1.1. Monolithic Architecture vs MSA

{{< figure caption="[Figure 1] Monolithic Architecture vs MSA" src="images/monolithic-msa.png" width="800px" >}}

[Figure 1] shows the traditional Monolithic Architecture and MSA. **Monolithic Architecture** is composed of a set of Modules responsible for specific functions, and each Module shares a single DB. In [Figure 1], it can be seen that all Modules are gathered in the API Server, and all Modules share a single DB.

In Monolithic Architecture, the boundaries between Modules are generally ambiguous, and multiple Modules often share and use a single Schema. Therefore, when some Modules or the DB change, many related Modules must also change together. This **Side Effect** is one of the main causes of reduced development efficiency. In addition, ambiguous Module boundaries also make the composition and roles of the teams developing the Modules ambiguous, which prevents teams from developing proactively.

In Monolithic Architecture, when only a specific Module receives concentrated load during operation and needs to Scale Out, Modules that do not need to Scale Out must also Scale Out together, causing unnecessary resource waste. Even in situations where only a specific Module needs to be replaced, all Modules must be replaced together, unnecessarily affecting other Modules.

However, Monolithic Architecture has the characteristic of enabling fast development and easy deployment due to its simple structure. In addition, since a single DB is shared, it has the advantage of easily handling Race Condition prevention, Service Rollback, and so on by using the DB Transaction feature. Therefore, for development that is not large-scale, Monolithic Architecture is generally advantageous.

**MSA** is composed of multiple Services that perform Business Logic and multiple DBs. Each Service generally uses a separate DB. Therefore, each DB does not necessarily have to be the same kind of DB, and a DB (RDBMS, NoSQL) suitable for the Business Logic performed by the Service can be selected and used. Of course, different Services can also share a single DB if necessary. The technology Stack composing a Service can also be selected and configured in various ways.

A Service can call other Services as needed. Service calls are made through the Interface provided by each Service. Generally, Network-based REST API and GRPC are widely used as Service Interfaces. These Network-based Service Interfaces make the boundaries between Services clear. In [Figure 1], Service A represents a Service provided through the combination of Service B and Service C.

MSA also has the advantage of making team composition and team roles clear because the boundaries and roles of Services are clear, enabling each team to develop actively. In MSA, when load is concentrated on a specific Service, only the Service with concentrated load can Scale Out. Therefore, other Services do not need to Scale Out unnecessarily. It also has the advantage that replacing a specific Service does not affect the remaining Services.

MSA has the advantage of being flexible as it is composed of multiple Services, but it has the disadvantage of being complex in terms of maintenance because multiple Services must be managed. To overcome this disadvantage, separate Tools or Platforms must be used rather than developers directly managing Services one by one. When configuring MSA, each Service is generally **Container**ized and managed through a **Container Orchestrator** such as Kubernetes.

In addition, MSA has the disadvantage that Transaction processing becomes difficult because each Service uses a different DB. To process Transactions in MSA, the DB's **Two-Phase Commit** or the **SAGA Pattern** must be used. When a Service is composed of a combination of Services, it has the disadvantage that Debugging is not easy due to Service dependencies. This disadvantage can be resolved to some extent through the introduction of a **Service Mesh**.

### 1.2. Service Type

{{< figure caption="[Figure 2] Service Type" src="images/service-type.png" width="800px" >}}

As mentioned above, MSA can also provide new Services by combining multiple Services. Services can be classified according to their roles and positions. [Figure 2] classifies Services into the Core/Atomic Service, Composite/Integration Service, and API/Edge Service Service Types and shows the relationship diagram for each Service Type. Each Service Type has the following meaning.

* **Core/Atomic Service** : A Service that performs Core Business Logic or Atomic Business Logic.
* **Composite/Integration Service** : A Service composed by combining Core/Atomic Services.
* **API/Edge Service** : A Service exposed to the App by combining Core/Atomic Services and Composite/Integration Services. When the load on the API Gateway is high, it can also perform some of the roles of the API Gateway.

### 1.3. with API Gateway

{{< figure caption="[Figure 3] MSA with API Gateway" src="images/msa-architecture-api-gateway.png" width="600px" >}}

A Component that should be introduced together when introducing MSA is the API Gateway. As the meaning suggests, the API Gateway performs the Gateway role of receiving external Client requests on behalf of Services and delivering them to the Services. [Figure 2] shows MSA with an API Gateway introduced. Since the API Gateway is the Component through which all Client requests pass, the **common Logic of Services** that all Services must commonly process can be handled in the API Gateway.

Generally, **Authentication/Authorization** and **Encryption/Decryption** processes are performed in the API Gateway. When the API Gateway performs Authentication/Authorization and Encryption/Decryption processing as in the case of [Figure 2], each Service does not need to perform Authentication/Authorization and Encryption/Decryption processing. The API Gateway also performs the **Load Balancer** role of distributing Client requests.

### 1.4. with Message Queue

{{< figure caption="[Figure 4] MSA with Message Queue" src="images/msa-architecture-mq.png" width="500px" >}}

A Component worth considering for introduction together when introducing MSA is the Message Queue. In MSA, the Message Queue is used as an Event Bus. An Architecture that uses a Message Queue as an Event Bus is called **EDA** (Event Driven Architecture). Generally, Kafka is used to build the Message Queue. [Figure 3] shows MSA with a Message Queue introduced. When calling Service B and Service C, Service A does not call them directly but Publishes an Event to the Message Queue. Then, Service B and Service C, which Subscribe to the created Event, receive the Event and process the Business Logic.

Before the Message Queue is introduced, Service A must know of the existence of Service B and Service C. However, with the introduction of the Message Queue, Service A simply needs to deliver the Event to the Message Queue. Service A does not need to know the information that Service B and Service C use the Event it created. From the perspective of Service B and Service C, they only need to receive the Event they need when it is created. In this way, using a Message Queue can lower the **dependency** between Services.

In addition, when Service A directly calls Service B and Service C while the load on Service B and Service C is temporarily high, the load on Service B and Service C increases further. With the introduction of the Message Queue, Service B and Service C can fetch and process the next Event from the Message Queue after the Event they are currently processing is completed, so temporary load can be avoided. In this way, using a Message Queue can avoid temporary Service load through Event Queuing.

## 2. References

* Microservice Architecture (SlideShare) : [https://www.slideshare.net/Byungwook/msa-52918441](https://www.slideshare.net/Byungwook/msa-52918441)
* Microservice Architecture (Joinc) : [https://www.joinc.co.kr/w/man/12/MicroserviceArchitecture](https://www.joinc.co.kr/w/man/12/MicroserviceArchitecture)
* Building Micro Service Architecture (SlideShare) : [https://www.slideshare.net/saltynut/building-micro-service-architecture](https://www.slideshare.net/saltynut/building-micro-service-architecture)
* The Scale Cube : [http://microservices.io/articles/scalecube.html](http://microservices.io/articles/scalecube.html)
* 모놀리틱 시스템에서 MSA로 전환 : [http://cyberx.tistory.com/64](http://cyberx.tistory.com/64)
* Microservice Architecture (MSA) and Integration Microservices (WSO2Con EU 2017) : [https://www.slideshare.net/wso2.org/wso2con-eu-2017-microservice-architecture-msa-and-integration-microservices-81654363](https://www.slideshare.net/wso2.org/wso2con-eu-2017-microservice-architecture-msa-and-integration-microservices-81654363)

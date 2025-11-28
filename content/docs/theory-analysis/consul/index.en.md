---
title: Consul
---

## 1. Consul

Consul performs roles such as Service Discovery, Service Health Check, Service status/configuration information management, and Key-value Store that **Control Plane** performs in Service Mesh Architecture. These functions provided by Consul are based on Consul's **Key-value Store**. Consul's Key-value Store is composed of multiple Consul Clusters and focuses on High Availability using Raft Algorithm and gossip Protocol.

Service registration is performed through Consul API, and registered Services can be discovered through DNS or HTTP Request. Service information includes Health Check methods for that Service, and Consul periodically checks the Health of that Service through Health Check methods of registered Services. If Consul discovers a Service that is not in normal state, that Service is excluded from Discovery targets so that Traffic is not delivered to Services that are not in normal state.

### 1.1. Architecture

{{< figure caption="[Figure 1] Consul Architecture" src="images/consul-architecture.png" width="900px" >}}

[Figure 1] shows the Architecture of Consul operating in Multi-data Center. Consul operates as a Cluster composed of multiple Servers/Clients. Consul Cluster internally forms multiple gossip Pools through **gossip Protocol** and manages Cluster Members. There are two types of gossip Pools: WAN gossip Pool and LAN gossip Pool. WAN gossip Pool is composed of Servers existing in all Data Centers. LAN gossip Pool is composed of Servers/Clients existing within the same Data Center.

Members forming the Cluster through gossip Protocol can quickly check each other's Health status. Also, Consul Client can access other Servers even if it only knows information about one Server among Servers in LAN gossip Pool through gossip Protocol. gossip Protocol internally uses an Algorithm called Serf.

Data Consensus between Servers existing in the same Data Center is matched through **Raft Algorithm**. Server operates composed of Leader that actually processes Data and Follower that only performs Proxy role between Client and Leader according to Raft Algorithm. Data stored in Server according to Raft Algorithm are Replicated to other Servers in the same LAN gossip Pool. If the number of Servers operating among Servers participating in Raft Algorithm is above Quorum, Data Loss does not occur. Replication is not performed between Servers existing in different Data Centers.

Client (Agent) operates on all Nodes and performs Health Check of each Service based on Health Check information of Services registered in Consul. Client can send requests to an arbitrary Server among Servers belonging to the LAN gossip Pool it belongs to when sending requests to Server. Server that receives requests from Client judges whether the request should be processed in the LAN gossip Pool it belongs to or should be processed in Server existing in external Data Center. If it should be processed in LAN gossip Pool, Client's request is delivered to Leader Server and processed.

If it should be processed in Server existing in external Data Center, Server that receives Client request identifies whether there is a Server in WAN gossip Pool that can process Client request, and if Server exists, it forwards the request to an arbitrary Server in the Data Center where that Server exists. If Server in external Data Center that receives Client request is Follower, Client request is forwarded to Follower's Leader and processed.

## 2. References

* [https://www.consul.io/intro/index.html](https://www.consul.io/intro/index.html)
* [https://www.consul.io/docs/internals/architecture.html](https://www.consul.io/docs/internals/architecture.html)
* [https://www.consul.io/docs/internals/gossip.html](https://www.consul.io/docs/internals/gossip.html)


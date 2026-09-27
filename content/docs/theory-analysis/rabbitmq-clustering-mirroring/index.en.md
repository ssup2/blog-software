---
title: RabbitMQ Clustering, Mirroring
---

This post analyzes RabbitMQ's Clustering and Mirroring techniques for RabbitMQ HA (High Availability).

## 1. RabbitMQ Clustering

{{< figure caption="[Figure 1] RabbitMQ Cluster" src="images/cluster.png" width="900px" >}}

**RabbitMQ Clustering** is a technique that bundles multiple RabbitMQs together so they are used like a single RabbitMQ. [Figure 1] shows a RabbitMQ Cluster. **The RabbitMQs that make up a RabbitMQ Cluster have the characteristic of sharing all information except Queues.** Therefore, every RabbitMQ in the same Cluster has the same Exchange. In [Figure 1], it can be seen that every RabbitMQ has Exchange A. In addition, **a RabbitMQ Cluster also has the characteristic that basically only one instance of each Queue exists.** In [Figure 1], it can be seen that only one Queue A and one Queue B exist in the Cluster. All RabbitMQs in the same Cluster share a secret key called the **Erlang Cookie**. Through the Erlang Cookie, a RabbitMQ verifies whether the other RabbitMQ belongs to the same Cluster. Also, a CLI Tool that controls the Cluster must have the Cluster's Erlang Cookie to be able to control that Cluster.

A Client generally does not establish Connections with every RabbitMQ in the Cluster, but establishes a Connection with only one RabbitMQ. That is, each Producer/Consumer establishes a Connection with one RabbitMQ among the RabbitMQs in the Cluster. Since every RabbitMQ in the Cluster has the same Exchange, it does not matter which RabbitMQ a Producer establishes a Connection with. This is because the Exchange forwards the Message again, without the Producer's knowledge, to the RabbitMQ that has the Queue the Message must be delivered to. Similarly, a Subscriber also does not need to establish a Connection directly with the RabbitMQ that has the Queue it will use. This is because the RabbitMQ that has established the Connection with the Consumer obtains the Message from the RabbitMQ that has the Queue and delivers it to the Subscriber.

Although a Client establishes a Connection with only one RabbitMQ among the RabbitMQs in the Cluster, for HA the Client must be in an environment where it can establish Connections with every RabbitMQ in the Cluster. This is because, when a specific RabbitMQ in the Cluster dies, the Client can establish a Connection with another RabbitMQ and continue to use RabbitMQ. Generally, a Load Balancer is placed between the Client and the RabbitMQ Cluster to provide the Client with an environment where it can access every RabbitMQ in the Cluster and to perform Connection Load Balancing. Alternatively, the Client holds the IP (Domain) and Port access information of every RabbitMQ in the Cluster, and the Client itself performs RabbitMQ failure detection and Connection Load Balancing.

Each RabbitMQ that makes up the Cluster can use one of two Modes: Disk and RAM. Disk Mode is the Default Mode. RAM Mode is a Mode that stores and runs with all information only in Memory (RAM), except Messages, Message Indexes, Queue Indexes, and the state information of other RabbitMQs. Since Message-related information is still stored on Disk even in RAM Mode, using RAM Mode does not increase Message throughput. However, in an environment where there is a great deal of information such as Exchanges, Queues, and Bindings and the configuration changes frequently, RAM Mode can be used to change the configuration quickly. When configuring a Cluster, at least one RabbitMQ must run in Disk Mode. This is because a RabbitMQ in RAM Mode initializes itself on restart by receiving the RabbitMQ information held by the Disk Mode RabbitMQ.

Even though the Client can establish Connections with every RabbitMQ in the Cluster and thus can always use RabbitMQ, since only one instance of each Queue exists in the Cluster, the loss of Messages in the Queue of a failed RabbitMQ cannot be prevented. Mirroring is the technique applied to prevent such Message loss.

## 2. RabbitMQ Mirroring

{{< figure caption="[Figure 2] RabbitMQ Mirroring" src="images/cluster-mirroring.png" width="900px" >}}

RabbitMQ Mirroring is a technique that copies and stores Messages on multiple RabbitMQs within a RabbitMQ Cluster. RabbitMQ HA (High Availability) can be built by using the RabbitMQ Cluster technique and the RabbitMQ Mirroring technique. [Figure 2] shows a state where RabbitMQ Cluster and Mirroring are applied together. When Mirroring is configured, a Queue consists of a Master Queue and Slave Queues, and they have a 1:N relationship. The Master Queue means the original Queue, and a Slave Queue means a Queue that replicates the Master Queue. A different number of Slave Queues can be configured for each Master Queue. The Master Queue is called the Queue Master in the RabbitMQ documentation.

Mirroring between the Master Queue and Slave Queues is basically done in a **Sync** manner. That is, when a Producer sends a Message to a Mirrored Queue, RabbitMQ does not put the received Message only into the Master Queue and send an ACK to the Producer; it sends the ACK to the Producer only after Mirroring with all Slave Queues is complete. Therefore, as the number of Slave Queues increases, Message throughput actually decreases. RabbitMQ recommends configuring only as many Slave Queues as needed for a quorum. For example, if the Cluster consists of 5 RabbitMQs, configure 1 Master Queue and 2 Slave Queues to meet the quorum of 3.

**Slave Queues through Mirroring are a technique for HA, not a technique for improving Message throughput.** Even with Slave Queues, every Message from the Producer is delivered only to the Master Queue, and the Messages delivered to Consumers are only the Messages sent from the Master Queue. Slave Queues only perform the operation of Mirroring with the Master Queue. Therefore, increasing the number of Slave Queues does not distribute Message throughput. Since the Master Queue is always the reference point, it can be seen that Messages are delivered to Consumers in the order the Producer sent them.

A new Slave Queue may be added when the Mirroring policy changes or when a new RabbitMQ is added to the Cluster. The new Slave Queue initially stays in an empty state with no Messages. That is, a Slave Queue does not copy over the existing Messages held by the Master Queue. It copies over only the new Messages that the Master Queue receives after the Slave Queue is created. Therefore, at first, the Messages held by the new Slave Queue differ from the Messages held by the Master Queue. RabbitMQ describes this state as **Unsynchronised**. As time passes, since Consumers consume the existing Messages of the Master, the Unsynchronised Slave Queue eventually becomes a Synchronised Slave Queue.

When the RabbitMQ that has the Master Queue dies, generally the oldest Slave Queue among the Slave Queues is promoted to the Master Queue. At this point, RabbitMQ by default excludes Unsynchronised Slave Queues from promotion candidates. If the RabbitMQ of the Master Queue dies while every Slave Queue is in the Unsynchronised state, that Queue cannot be used until the RabbitMQ of the Master Queue is recovered. If the RabbitMQ of the Master Queue cannot be recovered, Message loss occurs. RabbitMQ can be configured to promote an Unsynchronised Slave Queue to Master, but Message loss cannot be avoided.

## 3. RabbitMQ Cluster Expansion

A RabbitMQ Cluster allows RabbitMQs to be added even while running. Through the **Peer Discovery Plugin**, RabbitMQ automatically discovers RabbitMQs added to the Cluster and even performs Clustering automatically. The Peer Discovery Plugin currently supports 4 kinds, based on Consul, etcd, Kubernetes, and AWS respectively. Even if a RabbitMQ is added to the RabbitMQ Cluster, if the added RabbitMQ has no Queues, the load is not properly distributed to the added RabbitMQ. Therefore, after adding a RabbitMQ to the Cluster, the Cluster load must be distributed through **Queue Rebalancing**. Queue Rebalancing can be performed by running the Script provided by RabbitMQ or through a Queue Rebalancing Third-party Plugin.

## 4. References

* Clustering Guide : [https://www.rabbitmq.com/clustering.html](https://www.rabbitmq.com/clustering.html)
* Classic Queue Mirroring : [https://www.rabbitmq.com/ha.html](https://www.rabbitmq.com/ha.html)
* Cluster Formation and Peer Discovery : [https://www.rabbitmq.com/cluster-formation.html](https://www.rabbitmq.com/cluster-formation.html)
* Distributed RabbitMQ : [https://www.rabbitmq.com/distributed.html](https://www.rabbitmq.com/distributed.html)
* Reliability Guide : [https://www.rabbitmq.com/reliability.html](https://www.rabbitmq.com/reliability.html)
* Consumer Acknowledgements and Publisher Confirms : [https://www.rabbitmq.com/confirms.html](https://www.rabbitmq.com/confirms.html)
* RabbitMQ로 메시지 손실 최소화 하는 법(1) : [https://m.blog.naver.com/tmondev/221051503100](https://m.blog.naver.com/tmondev/221051503100)
* RabbitMQ Fairly In-depth - SlideShare : [https://www.slideshare.net/visualdensity/rabbit-fairlyindepth](https://www.slideshare.net/visualdensity/rabbit-fairlyindepth)
* rabbitmq-queue-master-balancer - GitHub : [https://github.com/Ayanda-D/rabbitmq-queue-master-balancer](https://github.com/Ayanda-D/rabbitmq-queue-master-balancer)

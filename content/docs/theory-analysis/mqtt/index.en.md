---
title: MQTT
---

This post analyzes MQTT (Message Queuing Telemetry Transport), a MQ (Message Queue) Protocol.

## 1. MQTT (Message Queuing Telemetry Transport)

{{< figure caption="[Figure 1] MQTT Architecture" src="images/mqtt-architecture.png" width="700px" >}}

**MQTT** is a **PUB (Publish)/SUB (Subscribe) based** Messaging Protocol **used in resource-constrained environments** such as IoT environments. [Figure 1] briefly shows MQTT. PUB/SUB operates based on a **Topic**. When a Publisher delivers a Message to the Broker with a specific Topic, the Broker delivers the Message to all Subscribers subscribing to that Topic. Therefore, unlike AMQP, MQTT performs only Multicast operations.

### 1.1. Topic

{{< figure caption="[Figure 2] MQTT Topic" src="images/mqtt-topic.png" width="600px" >}}

[Figure 2] shows the Topic structure of MQTT. Like a Directory structure, a Topic has a hierarchical structure based on `/`.

### 1.2. QoS

{{< figure caption="[Figure 3] MQTT QoS" src="images/mqtt-qos.png" width="900px" >}}

MQTT provides three levels of QoS. [Figure 3] shows the Message delivery and ACK process according to the QoS level.

* **Level 0** : The Publisher deletes the Message after delivering it to the Broker without receiving an ACK.
* **Level 1** : The Publisher delivers the Message to the Broker. The Broker receives an ACK after delivering the Message to the Subscriber. The Broker then delivers an ACK (PUBACK) to the Publisher and deletes the Message. The Publisher that receives the ACK deletes the Message.
* **Level 2** : Similar to Level 1, but the difference is that the Broker does not delete the Message immediately after delivering the ACK (PUBREC) to the Publisher, but receives an ACK (PUBREL) for the ACK (PUBREC) from the Publisher.

Level 0 does not guarantee that the Message is delivered to the Subscriber. Level 1 guarantees that the Subscriber receives the Message, but the Subscriber may receive the same Message multiple times. This is because, in Level 1, the Broker does not check that the ACK (PUBACK) has been delivered to the Publisher, so if the Publisher does not receive the ACK (PUBACK), it sends the same Message to the Broker once more. Level 2 guarantees that the Subscriber receives the Message exactly once because the problem of Level 1 is solved.

## 2. References

* RabbitMQ Intro and Messaging Patterns - SlideShare : [https://www.slideshare.net/javierarilos/rabbitmq-intromsgingpatterns](https://www.slideshare.net/javierarilos/rabbitmq-intromsgingpatterns)
* RabbitMQ - 이해하기 : [http://gjchoi.github.io/rabbit/rabbit-mq-%EC%9D%B4%ED%95%B4%ED%95%98%EA%B8%B0/](http://gjchoi.github.io/rabbit/rabbit-mq-%EC%9D%B4%ED%95%B4%ED%95%98%EA%B8%B0/)
* MQTT Tutorial - Joinc : [https://www.joinc.co.kr/w/man/12/MQTT/Tutorial](https://www.joinc.co.kr/w/man/12/MQTT/Tutorial)
* MQTT QoS(Quality of Service) : [http://dalkomit.tistory.com/111](http://dalkomit.tistory.com/111)

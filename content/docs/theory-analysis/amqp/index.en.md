---
title: AMQP
---

Analyze AMQP (Advanced Message Queuing Protocol), an MQ (Message Queue) protocol.

## 1. AMQP (Advanced Message Queuing Protocol)

AMQP is a **standard MQ protocol** that defines how to queue and route messages when transferring messages between applications. Because AMQP defines various message delivery options, many applications use AMQP to design and use message delivery rules. RabbitMQ is a representative MOM (Message-Oriented Middleware) that provides AMQP and is used in many places.

{{< figure caption="[Figure 1] AMQP Architecture" src="images/amqp-architecture.png" width="800px" >}}

[Figure 1] shows the architecture of AMQP. AMQP consists of Producer, Consumer, and Broker. Producer is the entity that produces and sends messages, and Consumer is the entity that receives and consumes messages produced by Producer. Broker performs the role of intermediating messages between Producer and Consumer. Broker is again composed of **Exchange** and **Queue**.

Producer can freely select any Exchange and send messages. Producer delivers a **Routing Key** along with the message to Exchange for message routing. Exchange uses the Routing Key to **Filter** the message or **Route** it to a Queue or another Exchange. Exchange can only deliver messages to Queues or Exchanges that are connected to it, and this connection process is called **Binding**.

Queue is a place that temporarily stores messages to be delivered to Consumer. Broker does not immediately delete messages from Queue after sending them to Consumer, but deletes them after receiving an ACK message from Consumer. If Broker does not receive an ACK message from Consumer, Broker retransmits the message a certain number of times as configured in Broker. If an ACK message is not received even after transmitting the message multiple times, the message can be deleted from Queue or sent back to Exchange to be delivered to another Consumer. If multiple Consumers are attached to one Queue, messages are delivered to Consumers according to a Round-Robin algorithm. This characteristic allows easy scale-out of Consumers.

### 1.1 Exchange Type

Exchange supports four types according to routing rules: Fanout, Direct, Topic, and Header.

#### 1.1.1. Direct

{{< figure caption="[Figure 2] Direct Type Exchange" src="images/amqp-exchange-direct.png" width="550px" >}}

Direct Exchange is an Exchange that unicasts messages to one Queue or Exchange. The criterion for unicast is the Routing Key delivered along with the message. To bind with Direct Exchange, you must provide a Routing Key to Direct Exchange. In [Figure 2], the Routing Key provided to Direct Exchange during binding is expressed as **Binding Key**. Direct Exchange delivers the message to a Queue or Exchange that has a Binding Key identical to the Routing Key that came with the message.

#### 1.1.2. Fanout

{{< figure caption="[Figure 3] Direct Type Exchange" src="images/amqp-exchange-direct.png" width="550px" >}}

Fanout Exchange is an Exchange that broadcasts messages to all Queues bound to it. In [Figure 3], Exchange A performs broadcasting by delivering all messages it receives to Queue A, Queue B, and Exchange B that are bound to it.

#### 1.1.3. Topic

{{< figure caption="[Figure 4] Topic Type Exchange" src="images/amqp-exchange-topic.png" width="550px" >}}

Topic Exchange is an Exchange that multicasts messages to multiple Queues or Exchanges. The criterion for multicast is the Routing Key delivered along with the message. To bind with Topic Exchange, you must provide a Routing Key containing a **pattern** to Topic Exchange. In [Figure 4], the Routing Key containing a pattern provided to Topic Exchange during binding is expressed as Binding Key. The patterns used are `*` and `#`. `*` means that one character can be substituted. `#` means that any characters, from nothing to a string, can be substituted. Topic Exchange delivers messages to all Queues or Exchanges that have a Binding Key matching the Routing Key that came with the message.

#### 1.1.4. Headers

{{< figure caption="[Figure 5] Headers Type Exchange" src="images/amqp-exchange-headers.png" width="650px" >}}

Headers Exchange is an Exchange that multicasts messages to multiple Queues or Exchanges. The criterion for multicast is the Key, Value included in the Message Header. To bind with Headers Exchange, you must provide the Key, Value to be included in the Message Header. In [Figure 5], the Message Header provided to Headers Exchange during binding is expressed as **Binding Header**. Headers Exchange delivers messages to all Queues or Exchanges that have a Binding Header identical to the Key, Value in the Message Header.

Headers Exchange provides an option called **x-match**, and x-match has two values: 'all' and 'any'. 'all' delivers messages to the Queue or Exchange only when all Key, Value values in the Message Header match the Key, Value values received during binding. 'any' delivers messages to the Queue or Exchange even if only some of the Key, Value values in the Message Header match the Key, Value values received during binding.

## 2. References

* [https://www.slideshare.net/javierarilos/rabbitmq-intromsgingpatterns](https://www.slideshare.net/javierarilos/rabbitmq-intromsgingpatterns)
* [http://gjchoi.github.io/rabbit/rabbit-mq-%EC%9D%B4%ED%95%B4%ED%95%98%EA%B8%B0/](http://gjchoi.github.io/rabbit/rabbit-mq-%EC%9D%B4%ED%95%B4%ED%95%98%EA%B8%B0/)
* [https://www.cloudamqp.com/blog/2015-09-03-part4-rabbitmq-for-beginners-exchanges-routing-keys-bindings.html](https://www.cloudamqp.com/blog/2015-09-03-part4-rabbitmq-for-beginners-exchanges-routing-keys-bindings.html)


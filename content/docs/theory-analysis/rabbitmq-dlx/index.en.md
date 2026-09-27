---
title: RabbitMQ DLX
---

This post analyzes RabbitMQ's DLX (Dead Letter Exchange).

## 1. RabbitMQ DLX (Dead Letter Exchange)

**RabbitMQ DLX** (Dead Letter Exchange) is a feature that sends Messages that have become Dead Letters to a designated Exchange. There are the following 3 conditions under which a Message becomes a Dead Letter.

* A Message rejected through a reject/nack response by a Consumer configured with Requeue False.
  * A Message rejected through a reject/nack response by a Consumer configured with Requeue True is requeued to the Queue where the Message existed, and the DLX feature does not operate.
* A Message whose Per-message TTL (Time to Leave) has expired.
* A Message dropped because the Queue is full.

{{< figure caption="[Figure 1] RabbitMQ DLX(Dead Letter Exchange)" src="images/rabbitmq-dlx.png" width="900px" >}}

[Figure 1] shows the processing flow of RabbitMQ's DLX feature when a Consumer rejects a Message. Exchange A and Exchange B are bound to Queue A. Queue A is configured with Exchange B as its DLX. Dead Letter Routing Key is an option that sets the Routing Key of the Message sent to the DLX. The Dead Letter Routing Key of Queue A is set to the string `ssup2`. The Dead Letter Routing Key does not necessarily have to be set on a Queue and can be set as needed. The Message processing flow is as follows.

* The Message sent by the Producer to the Consumer passes through Exchange A and Queue A and is delivered to the Consumer.
* The Consumer rejects the Message received from RabbitMQ through a reject or nack response without the Requeue setting.
* The Message is sent to Exchange B, which is designated as the DLX, along with the string `ssup2` as the Routing Key.
* Exchange B sends the Message to Queue A, which is bound to it.
* The Message is delivered to the Consumer again.

The `x-death` Header of a Message that has become a Dead Letter stores the reason the Message became a Dead Letter and related information. The main information stored in the `x-death` Header is as follows.

* `reason` : The reason the Message became a Dead Letter.
* `time` : The time the Message became a Dead Letter.
* `count` : The number of times the Message became a Dead Letter with the same `reason` and the same `queue`.
* `queue` : The Queue where the Message existed before it became a Dead Letter.
* `exchange` : The Exchange that last processed the Message that became a Dead Letter. For a Message processed multiple times by a DLX, DLX information may be stored.

## 2. References

* Dead Letter Exchanges : [https://www.rabbitmq.com/dlx.html](https://www.rabbitmq.com/dlx.html)

---
title: RabbitMQ ACK
---

This post analyzes the ACK of RabbitMQ.

## 1. RabbitMQ ACK

{{< figure caption="" src="images/rabbitmq-ack.png" width="750px" >}}

RabbitMQ provides ACK as a technique to guarantee Message delivery between Producer and Consumer. [Figure 1] shows the ACK process of RabbitMQ. In RabbitMQ, the technique in which the Producer sends a Message to RabbitMQ and then receives an ACK from RabbitMQ is called **Producer Confirm**. Similarly, in RabbitMQ, the technique in which RabbitMQ sends a Message to the Consumer and then receives an ACK from the Consumer is called **Consumer Acknowledgement**.

The ACK technique **guarantees that a Message is delivered at least once.** This property is called **"At Least Once"**. If the sender does not receive an ACK from the receiver after sending a Message, the sender must repeatedly send the Message until it receives an ACK from the receiver. Therefore, the Producer is implemented to retransmit the Message if it does not receive an ACK. Even if the sender processes a Message and then sends an ACK to the receiver, the ACK may not be delivered to the receiver due to a temporary Network failure. A sender that has not received an ACK may send the same Message to the receiver again. In other words, **the receiver may receive the same Message two or more times**. Therefore, the Consumer must be implemented with idempotency (Idempotent) in mind so that it operates correctly even if it receives the same Message.

### 1.1. Producer Confirm

When the Producer sends a Message to RabbitMQ, RabbitMQ delivers the received Message to the Exchange. The Exchange discards the received Message or delivers it to a Queue or another Exchange according to the rules configured on the Exchange. If the Message is discarded, RabbitMQ immediately sends an ACK to the Producer. If the Message is sent to a Queue, the ACK is sent to the Producer after the Queue stores the Message. In this case, if the Queue is Mirrored, the ACK is sent to the Producer after the Message is copied to all Mirrored Queues.

If the ACK sent by RabbitMQ to the Producer fails to be delivered to the Producer due to a temporary Network failure, the Producer retransmits the Message for which it did not receive an ACK after the connection with RabbitMQ is re-established. Therefore, RabbitMQ may receive the same Message from the Producer in duplicate, and the duplicated Message is sent to the Consumer multiple times as-is. Depending on the Producer's configuration, the Producer may not wait for the ACK from RabbitMQ.

### 1.2. Consumer Acknowledgement

When RabbitMQ sends a Message to the Consumer, the Consumer processes the received Message and then sends an ACK to RabbitMQ. The Consumer does not have to send an ACK within a specific time after receiving a Message. In other words, there is no Timeout for the ACK. Instead, if the connection with the Consumer is lost while RabbitMQ has not received an ACK from the Consumer to which it sent the Message, RabbitMQ considers that the Consumer did not process the Message properly and retransmits the Message to the Consumer after the connection with the Consumer is re-established.

Even if the Consumer receives a Message normally, the Message can be `reject`ed or `nack`ed by the Consumer. `reject` is a response that rejects only a single Message, and `nack` is a response that rejects all Messages for which an ACK has not been sent to RabbitMQ. The handling of a rejected Message differs depending on the `requeue` option sent along with the `reject`/`nack` response.

If the `requeue` option is set, the Message returns to the Queue where it originally was. The Message returned to the Queue is retransmitted to the Consumer. If the `requeue` option is not set, the handling of the Message differs depending on the DLX (Dead Letter Exchange) option of the Queue where the Message originally was. If the DLX option is set, the Message is sent to the DLX, and if the DLX option is not set, the Message is discarded. Depending on the Consumer's configuration, RabbitMQ may not wait for the ACK from the Consumer.

## 2. References

* RabbitMQ Reliability Guide : [https://www.rabbitmq.com/reliability.html](https://www.rabbitmq.com/reliability.html)
* Consumer Acknowledgements and Publisher Confirms : [https://www.rabbitmq.com/confirms.html](https://www.rabbitmq.com/confirms.html)
* Is there a timeout for acking RabbitMQ messages : [https://stackoverflow.com/questions/30546977/is-there-a-timeout-for-acking-rabbitmq-messages](https://stackoverflow.com/questions/30546977/is-there-a-timeout-for-acking-rabbitmq-messages)
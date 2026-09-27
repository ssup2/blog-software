---
title: Event Sourcing Pattern
---

This post analyzes the Event Sourcing Pattern.

## 1. Event Sourcing Pattern

{{< figure caption="[Figure 1] Event Sourcing vs Normal CRUD" src="images/event-sourcing-normal-crud.png" width="600px" >}}

The **Event Sourcing Pattern** is a Pattern that **stores all Events** that occur and performs Data manipulation based on the stored Events. [Figure 1] shows the normal CRUD approach using a DB and the Event Sourcing approach using an Event Store when storing order information. The normal CRUD approach stores only the current order state information in the DB. In contrast, the Event Sourcing approach stores all order information that occurs.

Projecting the order information stored in the Event Store of [Figure 1] shows that it is identical to the current order state stored in the DB. In the Event Sourcing technique, Create, Update, and Delete operations work simply by adding a single Event to the Event Store. On the other hand, a Read operation must project all Events stored in the Event Store. Therefore, there is a problem that the more Events are stored in the Event Store, the longer the Read operation takes. The methods that can solve this problem are using a **Snapshot** and the **CQRS Pattern**.

#### 1.1. Snapshot

A Snapshot is an operation performed in the Event Store. When a Snapshot is taken, Event Projection is performed and the current state information is stored. Afterwards, when performing Event Projection, instead of projecting all Events, only the Snapshot and the Events after the Snapshot are projected, reducing the load of Read operations.

#### 1.2. CQRS Pattern

{{< figure caption="[Figure 2] Event Sourcing Pattern" src="images/event-sourcing-pattern.png" width="700px" >}}

The CQRS Pattern is a Pattern that separates Command Responsibility and Query Responsibility. That is, it is a Pattern that separates Create, Update, Delete operations (Model) from Read operations (Model). Applying the Event Sourcing Pattern to the CQRS Pattern results in the configuration shown in [Figure 2]. [Figure 2] shows the CQRS Pattern applied to an Order Service that uses the Event Sourcing Pattern.

The Create, Update, and Delete operations of the Order Service only perform the operation of storing Events in the Event Store. Afterwards, the Event Deliver, which asynchronously monitors the Event Store, delivers the added Events to the Event Processing Handler through a Message Queue. The Event Processing Handler applies the Events to the Read Database to perform the Projection operation. The Read operation of the Order Service only performs the operation of obtaining the **current state** from the Read Database.

Since Events recorded in the Event Store are not immediately reflected in the Read Database, the consistency between Create, Update, Delete operations and Read operations can be temporarily broken. However, since the Read Database is used, fast Read operations become possible. When using the Event Sourcing Pattern, the CQRS Pattern can be applied to Services that are not affected by temporary Data inconsistency.

## 2. References

* Event Sourcing Pattern - Azure Architecture Center : [https://docs.microsoft.com/en-us/azure/architecture/patterns/event-sourcing](https://docs.microsoft.com/en-us/azure/architecture/patterns/event-sourcing)
* Microservices With CQRS and Event Sourcing : [https://dzone.com/articles/microservices-with-cqrs-and-event-sourcing](https://dzone.com/articles/microservices-with-cqrs-and-event-sourcing)
* Event Sourcing Pattern Summary : [https://edykim.com/ko/post/eventsourcing-pattern-cleanup/](https://edykim.com/ko/post/eventsourcing-pattern-cleanup/)
* Event Sourcing vs CRUD : [https://community.risingstack.com/event-sourcing-vs-crud/](https://community.risingstack.com/event-sourcing-vs-crud/)

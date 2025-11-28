---
title: CQRS Pattern
---

Analyze CQRS (Command and Query Responsibility Segregation) Pattern.

## 1. CQRS (Command and Query Responsibility Segregation) Pattern

{{< figure caption="[Figure 1] CORS Pattern" src="images/cqrs-pattern.png" width="700px" >}}

CQRS (Command and Query Responsibility Segregation) Pattern means a Pattern that separates Command Responsibility and Query Responsibility as the name implies. Here, Responsibility means Model. That is, it means a method where Command and Query operate using different **Models**.

[Figure 1] shows CQRS Pattern. **Command** means Create, Update, Delete operations that change **State, Report**, and **Query** means operations that Read State, Report. Command and Query operate with different Models, and Commands from Command Model propagate to Query Model to change Query Model's State, Report. Commands from multiple Command Models can propagate to one Query Model to change Query Model's State, Report.

It has the advantage of being able to separate Command Model and Query Model, but it also has disadvantages such as increased implementation complexity compared to general CRUD Model and **Replication Lag** problem where it takes time for Commands in Command Model to be reflected in Query Model.

{{< figure caption="[Figure 2] Event Sourcing Pattern" src="images/event-sourcing-pattern.png" width="700px" >}}

A representative place that uses CQRS Pattern is **Event Sourcing Pattern**. [Figure 2] shows CQRS Pattern applied to Order Service using Event Sourcing Pattern. In Event Sourcing Pattern, Event matches Command of CQRS Pattern. Events generated through Create, Update, Delete Order operations are stored in Event Store, and Events are asynchronously reflected (Projection) to Read Database through Message Queue. After that, Read Order operations use Order's state information stored in Read Database.

## 2. References

* [https://martinfowler.com/bliki/CQRS.html](https://martinfowler.com/bliki/CQRS.html)
* [https://dzone.com/articles/microservices-with-cqrs-and-event-sourcing](https://dzone.com/articles/microservices-with-cqrs-and-event-sourcing)
* [https://justhackem.wordpress.com/2016/09/17/what-is-cqrs/](https://justhackem.wordpress.com/2016/09/17/what-is-cqrs/)


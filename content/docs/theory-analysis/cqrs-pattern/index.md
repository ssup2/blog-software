---
title: CQRS (Command and Query Responsibility Segregation) Pattern
---

CQRS (Command and Query Responsibility Segregation) Pattern을 분석한다.

## 1. CQRS (Command and Query Responsibility Segregation) Pattern

{{< figure caption="[Figure 1] CORS Pattern" src="images/cqrs-pattern.png" width="700px" >}}

CQRS (Command and Query Responsibility Segregation) Pattern은 의미 그대로 Command Responsibility와 Query Responsibility을 분리하는 Pattern을 의미한다. 여기서 Responsibility는 Model을 의미한다. 즉 Command와 Query가 다른 **Model**을 이용하여 동작하는 방식을 의미한다. 

[Figure 1]은 CQRS Pattern을 나타내고 있다. **Command**는 **State, Report**를 변경하는 Create, Update, Delete 동작을 의미하고, **Query**는 State, Report를 Read하는 동작을 의미한다. Command와 Query는 서로 다른 Model로 동작하며, Command Model의 Command가 Query Model로 전파되어 Query Model의 State, Report를 변경한다. 다수의 Command Model의 Command들이 하나의 Query Model로 전파되어 Query Model의 State, Report를 변경할 수도 있다. 

Command Model과 Query Model을 분리할 수 있다는 장점을 가지고 있지만, 일반적인 CRUD Model에 비해서 구현의 복잡도가 올라가고 Command Model에 Command가 Query Model까지 반영하는데 시간이 걸리는 **Replication Lag** 문제가 발생한다는 단점도 존재한다.

{{< figure caption="[Figure 2] Event Sourcing Pattern" src="images/event-sourcing-pattern.png" width="700px" >}}

CQRS Pattern을 이용하는 대표적인 곳이 **Event Sourcing Pattern**이다. [Figure 2]는 Event Sourcing Pattern을 이용하는 Order Service에 적용한 CQRS Pattern을 나타내고 있다. Event Soucing Pattern에서 Event는 CQRS Pattern의 Command와 일치한다. Create, Update, Delete Order 동작을 통해서 생성된 Event는 Event Store에 저장되며, Message Queue를 통해서 Read Database에 비동기 적으로 Event가 반영(Projection)된다. 이후에 Read Order 동작은 Read Database에 저장된 Order의 상태 정보를 이용한다.

## 2. 참조

* [https://martinfowler.com/bliki/CQRS.html](https://martinfowler.com/bliki/CQRS.html)
* [https://dzone.com/articles/microservices-with-cqrs-and-event-sourcing](https://dzone.com/articles/microservices-with-cqrs-and-event-sourcing)
* [https://justhackem.wordpress.com/2016/09/17/what-is-cqrs/](https://justhackem.wordpress.com/2016/09/17/what-is-cqrs/)
---
title: MSA Transaction
---

Micro Service Architecture (MSA)를 분석한다.

## 1. MSA Transaction

MSA는 다수의 DB를 이용하기 때문에 DB의 Transaction 기능을 제대로 활용하기 어렵다. 따라서 MSA 설계시 Service 사이의 Consistency 유지를 위한 Transaction 처리에 많은 고민이 필요하다. MSA에서 Transaction을 구현하는 방법에는 **Two-Phase Commit**을 이용하는 방식과 **SAGA Pattern**을 방식이 존재한다.

두 방식 모두 완전한 Transaction을 보장하지는 못한다. 만약 반드시 다수의 Service Logic들이 하나의 완전한 Transaction안에서 실행되어야 한다면, 다수의 Service들을 하나의 Service로 구성하고 하나의 DB를 공유하는 방식으로 변경하는 것이 좋다.

### 1.1. Two-Phase Commit

{{< figure caption="[Figure 1] Two-Phase Commit" src="images/two-phase-commit.png" width="550px" >}}

Two-Phase Commit은 분산 Transiaction 기법이다. 의미 그대로 **Prepare**, **Commit** 2단계로 나누어 Transaction을 진행한다. [Figure 1]은 MSA에 적용한 Two-Phase Commit을 나타내고 있다. Order Service가 Payment, Stock, Delivery Service와 함께 Transaction을 수행하고 싶다면, Order Service는 Payment, Stock, Delivery Service가 제공하는 Prepare API를 통해서 Transaction 준비를 요청한다.

이후에 Order Service가 Payment, Stock, Delivery Service에게 모두 준비가 완료되었다는 응답을 받으면 Payment, Stock, Delivery Service가 제공하는 Commit API를 통해서 실제 Transaction 수행을 요청한다. 이후에 Order Service가 Payment, Stock, Delivery Service에게 Commit 완료 응답을 받게되면 Transaction이 종료된다.

{{< figure caption="[Figure 2] Two-Phase Commit Failed" src="images/two-phase-commit-failed.png" width="550px" >}}

[Figure 2]는 Two-Phase Commit이 실패하는 경우를 나타내고 있다. Order Service가 Payment, Stock, Delivery Service의 Prepare API를 통해서 Prepare 요청을 전송하였지만, Delivery Service에게는 응답을 받지 못한 상황을 나타내고 있다. 이 경우 Order Service는 Payment, Stock Service가 제공하는 Abort Service를 통해서 Abort를 요청하여 Transaction을 중단한다.

Prepare 단계가 완료가 되었어도, Commit 단계에서 실패가 발생할 수 있다. 이 경우는 Commit에 실패한 서비스가 성공할때 까지 반복해서 호출하거나, 서비스 관리자가 직접 완료되지 못한 Transaction을 처리해야 한다. 이러한 이유 때문에 Two-Phases Commit은 완전한 Transaction을 보장하지는 못한다.

Two-Phase Commit을 구현하기 위해서는 DB가 제공하는 Two-Phase Commit 기능을 이용해야 한다. 문제는 하나의 Transaction으로 묶기는 Service들이 이용하는 모든 DB가 동일한 종류의 DB를 이용해야 하고, DB에서 Two-Phase Commit을 지원해야 한다. 일반적으로 RDBMS에서만 Two-Phase Commit을 지원하기 때문에 NoSQL DB를 이용하는 Service도 같이 하나의 Transaction에 묶여야 한다면 Two-Phase Commit을 적용할 수 없다.

또한 Two-Phase Commit은 Sync Call 기반의 방식이기 때문에 Service 사이의 강결합이 발생하고, Service의 Throughput을 낮추는 주요 원인이 되기도 한다. 따라서 대부분의 MSA에서는 Two-Phase Commit 보다는 SAGA Pattern을 많이 이용한다. Two-Phase Commit은 Eventually Consistency를 기반으로하는 SAGA Pattern 보다 강한 Consistency를 제공하기 때문에, Two-Phase Commit을 이용할 수 있는 환경에서는 강한 Consistency를 위해서 SAGA Pattern 대신 선택되어 이용될 수 있다.

### 1.2. SAGA Pattern

SAGA Pattern은 Eventually Consistency를 기반으로 한다. 즉 일시적으로 Consistency가 불일치 할 수 있지만. 시간이 지나면 Consistency를 맞추는 특징을 갖는다. 또한 SAGA Pattern은 Message Queue를 이용한 비동기 기반 Event를 기반의 Pattern이다. 따라서 SAGA Pattern을 적용하기 위해서는 Message Queue가 필요하다. Transaction 도중에 실패가 발생하는 경우 **Compensation Transaction**을 통해서 Transaction 수행 이전으로 되돌리는 Transaction을 이용하는것 또한 SAGA Pattern의 특징이다. SAGA Pattern은 **Choreography** 방식과 **Orchestration** 방식이 존재한다. 

#### 1.2.1. Choreography-base

{{< figure caption="[Figure 3] SAGA Choreography-base" src="images/saga-choreography.png" width="600px" >}}

Choreography 방식은 각 Service가 Local Transaction을 수행하고 수행결과를 다른 서비스에게 직접 전파하는 방식이다. [Figure 3]은 Choreography Pattern을 나타내고 있다. Message Queue를 통해서 Event가 Order, Payment, Stock, Delivery Service 순서대로 전파되면서 각 Service들이 Local Transaction을 수행한다. 각 Service들이 순서대로 Local Transaction을 수행하기 때문에 일시적으로 Consistency가 불일치 할 수 있다.

{{< figure caption="[Figure 4] SAGA Choreography-base Failed" src="images/saga-choreography-failed.png" width="600px" >}}

Choreography 방식에서 중간 Service의 Local Transaction이 실패하는 경우, Local Transaction에 실패한 Service가 직접 나머지 Service에게 Local Transaction 실패 Event를 직접 전송하여 Compensation Transaction이 발생하도록 만든다. [Figure 4]에서는 Stock Service에서 재고 물량 부족으로 Local Transaction이 실패할 경우를 나타내고 있다. Stock Service의 Local Transaction 실패 Event를 수신한 Order, Payment Service는 Compensation Transaction을 수행하도록 만든다.

Compensation Transaction까지 고려하면 Choreography 방식에서 각 Service는 다양한 Event Channel을 Subscribe하여 Event를 수신 해야한다는 사실을 알 수 있다. 즉 Service 사이의 의존성 및 Business Logic의 의존성이 높아지는 단점을 가지고 있다. 따라서 Transaction에 연관된 Service의 개수가 많다면, Choreography 방식보다는 Orchestration 방식 이용을 권장한다.

#### 1.2.2. Orchestration-base

{{< figure caption="[Figure 5] SAGA Orchestration-base" src="images/saga-orchestration.png" width="600px" >}}

Orchestration 방은 각 Service의 Local Transaction을 관리하는 Orchestrator가 존재하는 방식이다. [Figure 5]는 Orchestration 방식을 나타내고 있다. Order SAGA Orchestrator가 순서대로 각 Service에게 Event를 전달하여 Local Transaction을 수행하도록 만들고 Transaction 수행 결과를 얻어가면서 Global Transaction을 진행한다.

{{< figure caption="[Figure 6] SAGA Orchestration-base Failed" src="images/saga-orchestration-failed.png" width="600px" >}}

SAGA Orchestration Pattern에서 중간 Service의 Local Transaction이 실패하는 경우 SAGA Orchestrator가 Local Transaction 실패 Event를 다른 Server에게 전송하여 Compensation Transaction이 발생하도록 만든다. [Figure 6]에서는 Stock Service에서 재고 물량 부족으로 Local Transaction이 실패할 경우를 나타내고 있다. Local Transaction 실패 Event를 SAGA Orchestrator에게 전달하면 SAGA Orchestrator가 다시 Local Transaction 실패 Event를 Order, Payment Service에게 전달하여 Compensation Transaction을 수행하도록 만든다.

Orchestrator가 중앙에서 Transaction을 관리하는 구조기 때문에 Choreography 방식에 비해서 Transaction Tracking이 편리한 장점을 가지고 있다. 또한 Orchestrator를 제외한 나머지 Service는 Orchestator와 Event를 주고받기 위한 Event Channel만 Subscribe하면 되기 때문에 다른 Service 사이의 의존성 및 Business Logic의 의존성이 Choreography 방식보다 낮다. 단 Choreography 방식에 비해서 Transaction 과정중에 Message Queue를 더 많이 이용한다는 단점을 갖고 있다.

#### 1.2.3. Outbox Pattern

TODO

## 2. 참조

* [https://developers.redhat.com/blog/2018/10/01/patterns-for-distributed-transactions-within-a-microservices-architecture#possible-solutions](https://developers.redhat.com/blog/2018/10/01/patterns-for-distributed-transactions-within-a-microservices-architecture#possible-solutions)
* [https://developer.ibm.com/depmodels/microservices/articles/use-saga-to-solve-distributed-transaction-management-problems-in-a-microservices-architecture/](https://developer.ibm.com/depmodels/microservices/articles/use-saga-to-solve-distributed-transaction-management-problems-in-a-microservices-architecture/)
* [http://blog.neonkid.xyz/243](http://blog.neonkid.xyz/243)
* [https://microservices.io/patterns/data/saga.html](https://microservices.io/patterns/data/saga.html)
* [https://hyunsoori.tistory.com/9](https://hyunsoori.tistory.com/9)
* [https://www.howtodo.cloud/microservice/2019/06/19/microservice-transaction.html](https://www.howtodo.cloud/microservice/2019/06/19/microservice-transaction.html)
* [https://www.popit.kr/rest-%EA%B8%B0%EB%B0%98%EC%9D%98-%EA%B0%84%EB%8B%A8%ED%95%9C-%EB%B6%84%EC%82%B0-%ED%8A%B8%EB%9E%9C%EC%9E%AD%EC%85%98-%EA%B5%AC%ED%98%84-1%ED%8E%B8/](https://www.popit.kr/rest-%EA%B8%B0%EB%B0%98%EC%9D%98-%EA%B0%84%EB%8B%A8%ED%95%9C-%EB%B6%84%EC%82%B0-%ED%8A%B8%EB%9E%9C%EC%9E%AD%EC%85%98-%EA%B5%AC%ED%98%84-1%ED%8E%B8/)
* Outbox Pattern : [https://stackoverflow.com/questions/58476933/group-send-kafka-message-and-db-update-in-one-transaction-in-springboot](https://stackoverflow.com/questions/58476933/group-send-kafka-message-and-db-update-in-one-transaction-in-springboot)
* Outbox Pattern : [https://debezium.io/blog/2019/02/19/reliable-microservices-data-exchange-with-the-outbox-pattern/](https://debezium.io/blog/2019/02/19/reliable-microservices-data-exchange-with-the-outbox-pattern/)

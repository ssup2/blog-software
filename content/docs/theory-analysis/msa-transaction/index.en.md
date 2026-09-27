---
title: MSA Transaction
---

This post analyzes Micro Service Architecture (MSA).

## 1. MSA Transaction

Since MSA uses multiple DBs, it is difficult to properly utilize the Transaction feature of a DB. Therefore, when designing an MSA, much consideration is needed for Transaction handling to maintain Consistency between Services. Methods for implementing Transactions in MSA include the method using **Two-Phase Commit** and the method using the **SAGA Pattern**.

Neither method guarantees a complete Transaction. If multiple Service Logics must be executed within one complete Transaction, it is better to change the design so that the multiple Services are composed into a single Service sharing a single DB.

### 1.1. Two-Phase Commit

{{< figure caption="[Figure 1] Two-Phase Commit" src="images/two-phase-commit.png" width="550px" >}}

Two-Phase Commit is a distributed Transaction technique. As the name implies, the Transaction proceeds in two phases: **Prepare** and **Commit**. [Figure 1] shows Two-Phase Commit applied to MSA. If the Order Service wants to perform a Transaction together with the Payment, Stock, and Delivery Services, the Order Service requests Transaction preparation through the Prepare APIs provided by the Payment, Stock, and Delivery Services.

After that, when the Order Service receives responses from the Payment, Stock, and Delivery Services indicating that all preparations are complete, it requests the actual Transaction execution through the Commit APIs provided by the Payment, Stock, and Delivery Services. When the Order Service then receives Commit completion responses from the Payment, Stock, and Delivery Services, the Transaction ends.

{{< figure caption="[Figure 2] Two-Phase Commit Failed" src="images/two-phase-commit-failed.png" width="550px" >}}

[Figure 2] shows a case where Two-Phase Commit fails. It shows a situation where the Order Service sent Prepare requests through the Prepare APIs of the Payment, Stock, and Delivery Services, but did not receive a response from the Delivery Service. In this case, the Order Service requests Abort through the Abort Service provided by the Payment and Stock Services to stop the Transaction.

Even if the Prepare phase is completed, a failure can occur in the Commit phase. In this case, the Service that failed to Commit must be called repeatedly until it succeeds, or the service administrator must directly handle the incomplete Transaction. For this reason, Two-Phase Commit does not guarantee a complete Transaction.

To implement Two-Phase Commit, the Two-Phase Commit feature provided by the DB must be used. The problem is that all DBs used by the Services bound into one Transaction must be the same kind of DB, and the DB must support Two-Phase Commit. Since generally only RDBMS supports Two-Phase Commit, Two-Phase Commit cannot be applied if a Service using a NoSQL DB must also be bound into the same Transaction.

In addition, since Two-Phase Commit is a Sync Call based method, it causes tight coupling between Services and is also a major cause of lowering the Throughput of Services. Therefore, most MSAs use the SAGA Pattern rather than Two-Phase Commit. Since Two-Phase Commit provides stronger Consistency than the SAGA Pattern, which is based on Eventually Consistency, it can be chosen and used instead of the SAGA Pattern for strong Consistency in environments where Two-Phase Commit can be used.

### 1.2. SAGA Pattern

The SAGA Pattern is based on Eventually Consistency. That is, Consistency may temporarily mismatch, but it has the characteristic of matching Consistency as time passes. The SAGA Pattern is also an asynchronous Event based Pattern using a Message Queue. Therefore, a Message Queue is required to apply the SAGA Pattern. When a failure occurs in the middle of a Transaction, using a **Compensation Transaction**, a Transaction that reverts to the state before the Transaction was performed, is also a characteristic of the SAGA Pattern. The SAGA Pattern has a **Choreography** method and an **Orchestration** method.

#### 1.2.1. Choreography-base

{{< figure caption="[Figure 3] SAGA Choreography-base" src="images/saga-choreography.png" width="600px" >}}

The Choreography method is a method in which each Service performs a Local Transaction and directly propagates the execution result to the other Services. [Figure 3] shows the Choreography Pattern. As Events are propagated through the Message Queue in the order of the Order, Payment, Stock, and Delivery Services, each Service performs its Local Transaction. Since each Service performs its Local Transaction in order, Consistency may temporarily mismatch.

{{< figure caption="[Figure 4] SAGA Choreography-base Failed" src="images/saga-choreography-failed.png" width="600px" >}}

In the Choreography method, when the Local Transaction of an intermediate Service fails, the Service that failed its Local Transaction directly sends a Local Transaction failure Event to the remaining Services to make Compensation Transactions occur. [Figure 4] shows a case where the Local Transaction fails in the Stock Service due to insufficient stock. The Order and Payment Services that receive the Local Transaction failure Event of the Stock Service are made to perform Compensation Transactions.

Considering Compensation Transactions as well, it can be seen that in the Choreography method each Service must Subscribe to various Event Channels to receive Events. That is, it has the disadvantage that the dependency between Services and the dependency of Business Logic become high. Therefore, if the number of Services involved in a Transaction is large, using the Orchestration method rather than the Choreography method is recommended.

#### 1.2.2. Orchestration-base

{{< figure caption="[Figure 5] SAGA Orchestration-base" src="images/saga-orchestration.png" width="600px" >}}

The Orchestration method is a method in which an Orchestrator that manages the Local Transaction of each Service exists. [Figure 5] shows the Orchestration method. The Order SAGA Orchestrator delivers Events to each Service in order to make them perform Local Transactions, and proceeds with the Global Transaction while obtaining the Transaction execution results.

{{< figure caption="[Figure 6] SAGA Orchestration-base Failed" src="images/saga-orchestration-failed.png" width="600px" >}}

In the SAGA Orchestration Pattern, when the Local Transaction of an intermediate Service fails, the SAGA Orchestrator sends the Local Transaction failure Event to the other Servers to make Compensation Transactions occur. [Figure 6] shows a case where the Local Transaction fails in the Stock Service due to insufficient stock. When the Local Transaction failure Event is delivered to the SAGA Orchestrator, the SAGA Orchestrator delivers the Local Transaction failure Event again to the Order and Payment Services to make them perform Compensation Transactions.

Since it is a structure in which the Orchestrator manages Transactions centrally, it has the advantage that Transaction Tracking is more convenient compared to the Choreography method. Also, since the Services other than the Orchestrator only need to Subscribe to the Event Channel for exchanging Events with the Orchestrator, the dependency between the other Services and the dependency of Business Logic are lower than in the Choreography method. However, it has the disadvantage of using the Message Queue more during the Transaction process compared to the Choreography method.

#### 1.2.3. Outbox Pattern

TODO

## 2. References

* Patterns for distributed transactions within a microservices architecture : [https://developers.redhat.com/blog/2018/10/01/patterns-for-distributed-transactions-within-a-microservices-architecture#possible-solutions](https://developers.redhat.com/blog/2018/10/01/patterns-for-distributed-transactions-within-a-microservices-architecture#possible-solutions)
* [MSA] 6. MSA의 트랜잭션 이야기 2 - Two-Phase commit과 Saga : [http://blog.neonkid.xyz/243](http://blog.neonkid.xyz/243)
* Pattern: Saga : [https://microservices.io/patterns/data/saga.html](https://microservices.io/patterns/data/saga.html)
* MSA 분산 트랜잭션 : [https://hyunsoori.tistory.com/9](https://hyunsoori.tistory.com/9)
* REST 기반의 간단한 분산 트랜잭션 구현 - 1편 : [https://www.popit.kr/rest-%EA%B8%B0%EB%B0%98%EC%9D%98-%EA%B0%84%EB%8B%A8%ED%95%9C-%EB%B6%84%EC%82%B0-%ED%8A%B8%EB%9E%9C%EC%9E%AD%EC%85%98-%EA%B5%AC%ED%98%84-1%ED%8E%B8/](https://www.popit.kr/rest-%EA%B8%B0%EB%B0%98%EC%9D%98-%EA%B0%84%EB%8B%A8%ED%95%9C-%EB%B6%84%EC%82%B0-%ED%8A%B8%EB%9E%9C%EC%9E%AD%EC%85%98-%EA%B5%AC%ED%98%84-1%ED%8E%B8/)
* Outbox Pattern : [https://stackoverflow.com/questions/58476933/group-send-kafka-message-and-db-update-in-one-transaction-in-springboot](https://stackoverflow.com/questions/58476933/group-send-kafka-message-and-db-update-in-one-transaction-in-springboot)
* Outbox Pattern : [https://debezium.io/blog/2019/02/19/reliable-microservices-data-exchange-with-the-outbox-pattern/](https://debezium.io/blog/2019/02/19/reliable-microservices-data-exchange-with-the-outbox-pattern/)

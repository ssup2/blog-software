---
title: CAP, ACID, BASE
---

Organizes CAP, ACID, BASE theories.

## 1. CAP

CAP theorem means the theory that distributed systems cannot satisfy all three properties: Consistency, Availability, and Partition-tolerance.

* **Consistency** : Refers to the property that the same response must be obtainable from multiple Nodes that make up a distributed system.
* **Availability** : Refers to the property that a distributed system must operate even if a failure occurs in a specific Node that makes up the distributed system.
* **Partition-tolerance** : Refers to the property that a distributed system must operate even if communication between Nodes is impossible due to Network failures.

Distributed systems designed considering Consistency and Partition-tolerance are called **CP systems**. In CP systems, if Consistency between Nodes does not match due to Node failures, operations stop until Consistency is achieved. Therefore, the Availability property is not satisfied. Distributed systems designed considering Availability and Partition-tolerance are called **AP systems**. In AP systems, operations continue even if Consistency between Nodes does not match due to Node failures. Therefore, the Consistency property is not satisfied.

Distributed systems designed considering Consistency and Availability are called CA systems. This means distributed systems that do not consider Network failures, but since there are no distributed systems where Network failures actually do not occur, it is correct to say that there are no actual CA systems. Systems operating on a single Node are generally classified as CA systems because Network failures do not occur.

## 2. ACID

It is a term that represents the four properties of Database Transactions. It is similar to the CP system properties of CAP theorem.

* **Atomicity** : Refers to the characteristic that the state of a Transaction from the outside can only be confirmed in two states: **success/failure**. That is, the intermediate process of a Transaction cannot be seen from the outside.
* **Consistency** : Refers to the characteristic that the state of DB before/after Transaction execution must maintain consistency without **contradiction**. Here, consistency means laws or rules. When transferring money from Account A to Account B, the total balance of Account A and Account B must be the same before/after the Transaction. When a Table's Column has FK (Foreign Key), FK rules must be maintained before/after Transaction execution.
* **Isolation** : Refers to the characteristic that Transactions must execute completely independently of each other. That is, when multiple Transactions execute simultaneously, each Transaction must operate as if it is performing the Transaction alone.
* **Durability** : After a Transaction is executed, the changes must be guaranteed until the next Transaction is executed.

## 3. BASE

Distributed systems are designed considering BASE properties for performance and availability. It is similar to the AP system properties of CAP theorem.

* **Basically Available** : Means guaranteeing availability. That is, distributed systems must always be able to respond to requests. However, it does not always guarantee correct responses.
* **Soft-State** : Means that the state of a distributed system can change at any time if Users do not maintain it separately. That is, the state of a distributed system can change at any time even without external requests.
* **Eventually Consistent** : Refers to the characteristic that consistency may be temporarily broken but is ultimately maintained. Consistency is temporarily broken until updated Data is delivered to other Nodes, but after a certain time passes and all Nodes are updated, consistency can be maintained again.

## 4. References

* [http://blog.thislongrun.com/2015/04/the-unclear-cp-vs-ca-case-in-cap.html](http://blog.thislongrun.com/2015/04/the-unclear-cp-vs-ca-case-in-cap.html)
* [https://bravenewgeek.com/cap-and-the-illusion-of-choice/](https://bravenewgeek.com/cap-and-the-illusion-of-choice/)
* [https://dba.stackexchange.com/questions/18435/cap-theorem-vs-base-nosql](https://dba.stackexchange.com/questions/18435/cap-theorem-vs-base-nosql)
* [https://stackoverflow.com/questions/4851242/what-does-soft-state-in-base-mean](https://stackoverflow.com/questions/4851242/what-does-soft-state-in-base-mean)


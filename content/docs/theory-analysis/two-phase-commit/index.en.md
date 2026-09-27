---
title: Two-Phase Commit
---

This post analyzes Two-Phase Commit (2PC).

## 1. Two-Phase Commit (2PC)

{{< figure caption="[Figure 1] Two-Phase Commit" src="images/two-phase-commit.png" width="400px" >}}

**Two-Phase Commit** is a technique used to bind the work that must be performed on multiple Nodes in a distributed system environment into a single Transaction. [Figure 1] shows the Two-Phase Commit process. It is called Two-Phase because a **Prepare Phase** exists in addition to the normal Commit process.

The Transaction Coordinator sends a Prepare command to all Nodes that must perform the Transaction. Here, Prepare means the state in which a Node can perform a Commit when a Commit request arrives. Once the Transaction Coordinator receives a Prepared Ack from all Nodes, it sends a Commit request to all Nodes again so that each Node performs the Commit operation. When the Transaction Coordinator receives a Done Ack from all Nodes, it finishes the Transaction.

If the Transaction Coordinator does not receive a Prepared Ack from a particular Node during the Prepare Phase, the Transaction Coordinator sends an Abort command to all Nodes. Nodes that receive the Abort command leave the Prepared state and are rolled back to their original state. If the Transaction Coordinator does not receive a Done Ack from a particular Node during the Commit Phase, the Transaction Coordinator leaves the Nodes that returned a Done Ack as they are and sends the Commit command multiple times to the Node that did not return a Done Ack. If a Done Ack is still not received after sending the Commit command multiple times, the Transaction remains unfinished. A DB administrator must perform the Commit directly on that Node and finish the Transaction to restore it to normal. As such, the Two-Phase Commit technique does not guarantee a complete Transaction.

## 2. References

* Two-Phase Commit : [http://swdev.tistory.com/2](http://swdev.tistory.com/2)
* Two phase commit - Stack Overflow : [https://stackoverflow.com/questions/7389382/two-phase-commit](https://stackoverflow.com/questions/7389382/two-phase-commit)

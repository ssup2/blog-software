---
title: Golang Goroutine Scheduling
---

This document analyzes Golang Goroutine Scheduling.

## 1. Goroutine Scheduling

{{< figure caption="[Figure 1] Goroutine Scheduling" src="images/golang-goroutine-scheduling.png" width="700px" >}}

Golang provides Goroutines, which are more lightweight threads than the threads provided by the OS. Goroutines are executed through **Golang Scheduler** included in the Golang Runtime, which performs Thread Scheduling. In other words, multiple Goroutines operate on a small number of Threads. [Figure 1] shows the Goroutine Scheduling process. **Goroutine is represented as G, Processor as P, and Thread as M**. Here, Processor refers to a virtual Processor (Virtual CPU Core), not the actual number of CPU Cores.

[Figure 1] shows 4 **CPU Cores** and multiple Threads being scheduled and operated by the **OS Scheduler**. **Network Poller** refers to a separate independent Thread that handles Network. There are two types of Run Queues: **GRQ (Global Run Queue)** and **LRQ (Local Run Queue)**. GRQ performs the role of a global Goroutine Queue as its name suggests, and LRQ performs the role of a local Goroutine Queue as its name suggests.

#### 1.1. Goroutine State

Goroutines actually have more diverse states, but they can be simplified into the following 3 states:

* **Waiting**: This refers to the state where a Goroutine is waiting for external Events. Here, external Events refer to OS Events that notify that Goroutines can be executed, such as I/O Device request processing completion and Lock release.
* **Runnable**: This refers to the state where a Goroutine can be executed.
* **Executing**: This refers to the state where a Goroutine is being executed.

In [Figure 1], Goroutines in the Network Poller and Goroutines in Blocking state refer to Goroutines in Waiting state. Goroutines in GRQ and LRQ are Goroutines in Runnable state. Goroutines that exist together with Processor(P) and Thread(M) are Goroutines in Executing state.

Goroutines can only be in Executing state when they exist together with Processor(P) and Thread(M). Therefore, the maximum number of Goroutines that can be run simultaneously is determined by the number of Processors(P). The number of Processors(P) can be determined by the value of the **GOMAXPROCS** environment variable, and if the GOMAXPROCS environment variable is not set, the default value is set to the number of CPU Cores so that Goroutines can be run simultaneously on all CPU Cores. In [Figure 1], the GOMAXPROCS value is "3".

#### 1.2. Run Queue

**LRQ** is a Run Queue that exists for each Processor(P). The Processor takes Goroutines one by one from its own LRQ and runs them. LRQ reduces Race Conditions that occur in GRQ. The reason why LRQ does not exist in Thread(M) is that if Thread owns LRQ, the number of LRQs increases as the number of Threads(M) increases. If the number of LRQs becomes too large, the Overhead of processes such as Work Stealing also increases, so Processor(P) owns LRQ. The reason for introducing the concept of Processor(P) is to reduce the number of LRQs.

{{< figure caption="[Figure 2] LRQ" src="images/lrq.png" width="600px" >}}

LRQ has a form that combines FIFO (First In, First Out) and LIFO (Least In, First Out), not a general Queue. The LIFO part has a Size of "1", so only one Goroutine can be stored. [Figure 2] shows the operation of LRQ. When a Goroutine is enqueued to LRQ, it is first stored in the LIFO part and then stored in the FIFO part. Conversely, when a Goroutine is dequeued from LRQ, the Goroutine in the LIFO part comes out first, and then the Goroutine in the FIFO part comes out.

The reason LRQ is designed this way is to give Locality to Goroutines. When a new Goroutine is created from a Goroutine and the created Goroutine waits for termination, high performance can be achieved only when the newly created Goroutine is executed and terminated quickly. Considering the Cache perspective, the newly created Goroutine should be executed on the same Processor. The newly created Goroutine is basically stored in the LRQ of the Processor that created the Goroutine. Therefore, through the LIFO part of LRQ, the newly created Goroutine can be executed quickly on the same Processor.

**GRQ** is a Run Queue where most Goroutines that could not be assigned to LRQ are gathered. Goroutines in Executing state can operate for a maximum of 10ms at a time. Goroutines that have operated for 10ms become Waiting state and move to GRQ. Also, when a Goroutine is created, if the LRQ of the Processor that created the Goroutine is full, the created Goroutine is stored in GRQ.

#### 1.3. System Call

Each System Call operates in two ways: Sync and Async. When an App calls a Sync System Call, the App cannot perform any operation until the Sync System Call operation is completed, and it becomes Blocking. In other words, the Thread that runs the App temporarily suspends the App operation and performs System Call processing. Conversely, when an App calls an Async System Call, the App can perform desired operations after calling the Async System Call. However, the App must separately receive and process the completion Event of the called Async System Call.

When a Sync System Call is called within a Goroutine, the Thread that was running the Goroutine temporarily suspends the Goroutine operation and performs Sync System Call processing. Therefore, during Sync System Call processing, the Thread cannot run other Goroutines. This becomes a cause of not being able to properly utilize CPU Cores. The Golang Scheduler uses a separate Thread to solve this problem.

{{< figure caption="[Figure 3] Sync System Call" src="images/sync-system-call.png" width="500px" >}}

[Figure 3] shows how the Golang Scheduler processes the Goroutine when a Sync System Call is called from a Goroutine. A new Thread(M) is assigned to the Processor(P) where the Goroutine that called the Sync System Call was executed, and the Processor(P) runs the next Goroutine in its LRQ. After that, when the Goroutine's Sync System Call is completed, the Goroutine enters LRQ again and is executed later. The remaining Thread(M) is left for cases where other Goroutines call Sync System Calls.

{{< figure caption="[Figure 4] Async System Call" src="images/async-system-call.png" width="500px" >}}

[Figure 4] shows how the Golang Scheduler processes the Goroutine when an Async System Call is called from a Goroutine. The Goroutine that called the Async System Call enters the **Network Poller** and waits for the completion Event of the Async System Call. After that, the Network Poller receives the completion Event of the Async System Call and makes the Goroutine that is the target of the Event enter LRQ again to be executed later. The Network Poller operates in a separate Background Thread and receives Async System Call completion Events through the **epoll()** function in Linux environments.

#### 1.4. Work Stealing

```cpp {caption="[Code 1] Goroutine Scheduling Algorithm", linenos=table}
runtime.schedule() {
    // only 1/61 of the time, check the global runnable queue for a G.
    // if not found, check the local queue.
    // if not found,
    //     try to steal from other Ps.
    //     if not, check the global runnable queue.
    //     if not found, poll network.
}
```

When there are no Goroutines in LRQ, the Golang Scheduler brings Goroutines from other places. [Code 1] shows the Goroutine Scheduling Algorithm performed by the Golang Scheduler. If there are no Goroutines in LRQ, it checks if Goroutines exist in other LRQs, and if Goroutines exist in LRQ, it takes half of the Goroutines.

If no Goroutines exist in other LRQs, it checks if Goroutines exist in GRC and brings Goroutines if they exist. If no Goroutines exist in GRC, it checks if Goroutines exist in Net Poller and brings Goroutines if they exist. However, for the Locality of Goroutines, newly created Goroutines are restricted from being stolen for 3ms.

#### 1.5. Fairness

One of the important elements in Goroutine Scheduling is that all Goroutines must be executed fairly. This characteristic is called Fairness. The Golang Scheduler applies various techniques to ensure Goroutine Fairness.

* **Thread**: Goroutines can continue to use the Thread they are using without returning it. To prevent Goroutines from monopolizing Threads, the Golang Scheduler times out and preempts Goroutines that run for more than 10ms when executed once, and forcibly moves them to GRQ.
* **LRQ**: If two Goroutines are alternately stored and executed in LRQ, Goroutines in the FIFO part may not be executed due to the LIFO part of LRQ. To prevent this problem, the Golang Scheduler made it so that Goroutines stored in the LIFO part inherit the 10ms Timeout without being reset. Therefore, one Goroutine cannot occupy the LIFO part of LRQ for more than 10ms.
* **GRQ**: If only Goroutines in LRQ are executed, Goroutines in GRQ may not be executed. To prevent this problem, the Golang Scheduler made it so that when performing Goroutine Scheduling "61 times", it first checks and executes Goroutines in GRQ rather than LRQ. The upper part of [Code 1] shows this content.
* **Network Poller**: Network Poller is an independent Background Thread. Therefore, its operation is guaranteed according to the OS Scheduler.

## 2. References

* [https://developpaper.com/deep-decryption-of-the-scheduler-of-go-language/](https://developpaper.com/deep-decryption-of-the-scheduler-of-go-language/)
* [https://www.ardanlabs.com/blog/2018/08/scheduling-in-go-part2.html](https://www.ardanlabs.com/blog/2018/08/scheduling-in-go-part2.html)
* [https://www.youtube.com/watch?v=-K11rY57K7k](https://www.youtube.com/watch?v=-K11rY57K7k)
* [https://morsmachine.dk/netpoller](https://morsmachine.dk/netpoller)
* [https://www.timqi.com/2020/05/15/how-does-gmp-scheduler-work/](https://www.timqi.com/2020/05/15/how-does-gmp-scheduler-work/)
* [https://rakyll.org/scheduler/](https://rakyll.org/scheduler/)
* [https://www.programmersought.com/article/42797781960/](https://www.programmersought.com/article/42797781960/)
* [https://livebook.manning.com/book/go-in-action/chapter-6/11](https://livebook.manning.com/book/go-in-action/chapter-6/11)
* [https://blog.puppyloper.com/menus/Golang/articles/Goroutine%EA%B3%BC%20Go%20scheduler](https://blog.puppyloper.com/menus/Golang/articles/Goroutine%EA%B3%BC%20Go%20scheduler)
* [https://rokrokss.com/post/2020/01/01/go-scheduler.html](https://rokrokss.com/post/2020/01/01/go-scheduler.html)

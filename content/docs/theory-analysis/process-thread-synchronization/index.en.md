---
title: Process/Thread Synchronization
---

This post analyzes Process/Thread synchronization techniques.

## 1. Process/Thread Syncronization

### 1.1. Mutex

```cpp {caption="[Code 1] Mutex CPP Example on Linux", linenos=table}
#include <pthread.h>  

pthread-mutex-t mutex = PTHREAD-MUTEX-INITIALIZER; // mutex instance
int count; // shared resource

void IncreaseCount() {
    pthread-mutex-lock(&mutex); // lock
    count++;
    pthread-mutex-unlock(&mutex); // unlock
}
```

Mutex is the most basic Process/Thread synchronization technique. The Critical Section, which is the area accessing a Shared Resource, is wrapped with the Mutex's Lock function and Unlock function. [Code 1] shows a CPP-based Mutex example running on Linux. The `pthread-mutex-lock()` function performs the role of the Lock function, and the `pthread-mutex-unlock()` function performs the role of the Unlock function.

The Mutex's Lock function checks whether the state of the Mutex is Lock/Unlock. If the Mutex is in the Unlock state, the Lock function terminates immediately, allowing the Process/Thread to enter the Critical Section. If the Mutex is in the Lock state, the Lock function waits until the Mutex becomes the Unlock state, and when it becomes the Unlock state, it terminates and allows the Process/Thread to enter the Critical Section.

The Lock state of a Mutex becomes the Unlock state through calling the Mutex's Unlock function. At this point, the Mutex's Unlock function must be called by the Process/Thread that made the Mutex the Lock state through the Mutex's Lock function. In other words, the Lock state of a Mutex cannot be changed to the Unlock state by an external Process/Thread. This characteristic is the biggest difference from a Binary Semaphore.

A Process/Thread that calls the Mutex's Lock function while the Mutex is in the Lock state is changed to the Sleep state and Scheduled Out, waiting for the Mutex to become the Unlock state. Afterwards, when the Mutex becomes the Unlock state, the Process/Thread in the Sleep state wakes up, and as the Lock function terminates, it enters the Critical Section. If multiple Processes/Threads are waiting on the same Mutex, in the case of the Linux Mutex, only the one Process/Thread with the highest priority wakes up.

### 1.2. Spinlock

Spinlock is a Process/Thread synchronization technique that has a Lock function and an Unlock function, the same as Mutex. The difference from Mutex is that Spinlock's Lock function does not change to the Sleep state and keeps checking until the Spinlock is in the Unlock state. Since the Process/Thread does not enter the Sleep state, it has the advantage that the Context Switching Overhead of the Process/Thread does not occur, but it has the disadvantage that unnecessary CPU waste can occur if the Lock state lasts a long time.

Therefore, Spinlock should be used only when the execution time of the Critical Section is very short so that the Lock state can last very briefly. It is mainly used at the Kernel Level rather than the App Level. In the case of the Linux Kernel's Spinlock, it temporarily Disables all Interrupts to prevent Context Switching.

### 1.3. Condition Variable

```cpp {caption="[Code 2] Condition Variable CPP Example on Linux", linenos=table}
#include <pthread.h>  

pthread-mutex-t mutex = PTHREAD-MUTEX-INITIALIZER; // mutex instance
pthread-cond-t cond = PTHREAD-COND-INITIALIZER; // condition variable instance
queue<request*> req-queue; // shared resource

void ProduceReqWakeupOne(request* req) {
    pthread-mutex-lock(&mutex); // lock
    req-queue.enqueue(req);
    pthread-mutex-unlock(&mutex); // unlock
    pthread-cond-signal(&cond); // wake up one thread
}

void ProduceReqWakeupAll(request* req) {
    pthread-mutex-lock(&mutex); // lock
    req-queue.enqueue(req);
    pthread-mutex-unlock(&mutex); // unlock
    pthread-cond-broadcast(&cond); // wake up all thread
}

request* ConsumeReq() {
    pthread-mutex-lock(&mutex); // lock
    while(req-queue.empty()) {
        pthread-cond-wait(&cond, &mutex);
    }
    request* req = req-queue.dequeue();
    pthread-mutex-unlock(&mutex); // unlock
    return req;
}
```

Condition Variable is used when a Process/Thread that has entered the Critical Section waits until a specific condition is met. It is used together with a Mutex and cannot be used alone. [Code 2] shows a CPP-based Condition Variable running on Linux. It can be seen that in the `ConsumeReq()` function, if no Request exists in the Request Queue where Requests are stored, the wait operation is performed through the `pthread-cond-wait()` function.

A Process/Thread that performs a wait operation using a Condition Variable makes the Mutex used when entering the Critical Section the Unlock state and enters the Sleep state. In [Code 2], the reason the `pthread-cond-wait()` function receives not only the Condition Variable Instance but also the Mutex Instance as a Parameter is to make the Mutex received as a Parameter the Unlock state. This is because if the Mutex is not made the Unlock state, other Processes/Threads cannot enter the Critical Section.

When a separate Process/Thread, not the Process/Thread waiting on the Condition Variable, completes a specific condition, it can wake up the waiting Process/Thread to make it operate. The Process/Thread waiting on the Condition Variable wakes up, makes the Mutex used when entering the Critical Section the Lock state, and enters the Critical Section again. When there are multiple Processes/Threads waiting on the Condition Variable, it is possible to wake up only one Process/Thread or wake up all Processes/Threads.

In [Code 2], the `pthread-cond-signal()` function is a function that wakes up only one Process/Thread, and the `pthread-cond-broadcast()` function is a function that wakes up all Processes/Threads. The `pthread-cond-signal()` function wakes up the one Process/Thread with the highest Scheduling priority.

### 1.4. Monitor

```cpp {caption="[Code 3] Monitor CPP Example on Linux", linenos=table}
#include <pthread.h>  

class ReqQueue {
    pthread-mutex-t mutex = PTHREAD-MUTEX-INITIALIZER; // mutex instance
    pthread-cond-t cond = PTHREAD-COND-INITIALIZER; // condition variable instance
    queue<request*> req-queue; // shared resource

    void ProduceReq(request* req) {
        pthread-mutex-lock(&mutex); // lock
        req-queue.enqueue(req);
        pthread-mutex-unlock(&mutex); // unlock
        pthread-cond-signal(&cond); // wake up one thread
    }

    request* ConsumeReq() {
        pthread-mutex-lock(&mutex); // lock
        while(req-queue.empty()) {
            pthread-cond-wait(&cond, &mutex);
        }
        request* req = req-queue.dequeue();
        pthread-mutex-unlock(&mutex); // unlock
        return req;
    }
}
```

Monitor is a Process/Thread synchronization technique abstracted by utilizing Mutex and Condition Variable. Using a Monitor, developers can easily control Shared Resources without considering the Mutex and Condition Variable. It is generally widely used in object-oriented languages such as CPP and Java. Every Object in Java has a built-in Monitor, which is used to synchronize Objects between Processes/Threads. The `synchronized` Keyword and the `wait()`, `notify()`, and `notifyAll()` functions are all based on the Monitor.

[Code 3] shows a CPP-based Monitor example running on Linux. Similar to [Code 2], it performs Request Procduce/Consume operations, but a developer using the `ReqQueue` Class of [Code 3] can perform Request Procduce/Consume operations through the `ProduceReq()` and `ConsumeReq()` functions without being aware of the existence of the Mutex and Condition Variable.

### 1.5. Semaphore

```cpp {caption="[Code 4] Semaphore CPP Example on Linux", linenos=table}
#include <semaphore.h>

queue<request*> req-queue; // shared resource
sem-t sem; // semaphore instance

void ProduceReq(request* req) {
    sem-wait(sem); // wait and decrease value
    req-queue.enqueue(req);
}

request* ConsumeReq() {
    request* req = req-queue.dequeue();
    sem-post(sem); // increase value
    return req;
}

int main() {
    sem-init(&sem, 0, 5); // initial value 5
    ...
}
```

Mutex is a synchronization technique that allows only one Process/Thread to access the Critical Section at a time. To allow only a limited number of Processes/Threads, not just one, to access the Critical Section at the same time, a Semaphore must be used. Each Semaphore has a Value, and the Value means the number of Processes/Threads that can enter the Critical Section. When a Process/Thread enters the Critical Section, the Value decreases, and when it leaves the Critical Section, the Value increases. The Value increases and decreases Atomically.

[Code 4] shows a CPP-based Semaphore example running on Linux. The `sem-wait()` function decreases the Value by one and terminates if the Semaphore's Value is not `0`, allowing entry into the Critcal Section. If the Value is not `0`, it waits until it becomes `0`, and when the Value increases, it wakes up, decreases the Value, and terminates, allowing entry into the Critical Section. When a Process/Thread waits for the Value, it enters the Sleep state, the same as with a Mutex.

The `sem-post()` function increases the Semaphore's Value by one, allowing one Process/Thread waiting on the Semaphore to enter the Critical Section. It can be seen that the value is initialized to `5` in the `main()` function of [Code 4]. Therefore, when Enqueueing Requests into the Request Queue through the `ProduceReq()` function, only up to 5 Requests can be stored in the Request Queue.

When a Semaphore uses only the Values 0 and 1, it can allow only one Process/Thread to access the Critical Section at a time, the same as a Mutex. However, the difference from a Mutex is that while changing a Mutex to the Unlock state can only be done by the Thread that made the Mutex the Lock state, the Unlock operation of a Semaphore (decreasing the Value by one) can be performed by any Process/Thread. 

## 2. References

* Mutex : [https://www.joinc.co.kr/w/Site/Thread/Beginning/Mutex](https://www.joinc.co.kr/w/Site/Thread/Beginning/Mutex)
* Mutex : [http://www.qnx.com/developers/docs/6.5.0/index.jsp?topic=%2Fcom.qnx.doc.neutrino-lib-ref%2Fp%2Fpthread-mutex-unlock.html](http://www.qnx.com/developers/docs/6.5.0/index.jsp?topic=%2Fcom.qnx.doc.neutrino-lib-ref%2Fp%2Fpthread-mutex-unlock.html)
* Condition Variable : [https://stackoverflow.com/questions/49281906/which-thread-would-be-notified-by-pthread-cond-signal](https://stackoverflow.com/questions/49281906/which-thread-would-be-notified-by-pthread-cond-signal)
* Condition Variable : [https://elecs.tistory.com/135](https://elecs.tistory.com/135)
* Semaphore : [https://yebig.tistory.com/305](https://yebig.tistory.com/305)
* Semaphore : [https://www.joinc.co.kr/w/Site/system-programing/IPC/semaphores](https://www.joinc.co.kr/w/Site/system-programing/IPC/semaphores)

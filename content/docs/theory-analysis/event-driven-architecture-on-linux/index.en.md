---
title: Event Driven Architecture on Linux
---

This post analyzes Event Driven Architecture and designs an Event Driven Architecture that runs on Linux.

## 1. Event Driven Architecture

{{< figure caption="[Figure 1] Event Driven" src="images/event-driven-architecture.png" width="400px" >}}

**Event Driven Architecture** consists of **Events** and **Event Handlers** that process those Events. It is also characterized by using only a Single Thread called the **Main Loop**. The Main Loop Thread is normally Blocked, and when an Event occurs, it identifies which Event it is and then executes the corresponding Event Handler. After that, it becomes Blocked again and waits until the next Event arrives. The function that stays Blocked like this and notifies which Event has occurred is called an **I/O Multiplexer**. Since the Main Loop Thread executes Event Handlers very quickly in the order the Events occur, the program behaves like a Concurrent program.

```cpp {caption="[Code 1] Event Driven Architecture Example", linenos=table}
int event-handler1(event *ev){
  // Non-blocking
}

int event-handler2(event *ev){
  // Non-blocking
}

int main()
{
  // Init I/O multiplexer
  IOMultiplexer multiplexer;

  // Registe event to multiplexer
  multiplexer.Add(ev1)
  multiplexer.Add(ev2)

  // Run main loop
  while(ture){
    ev-list = multiplexer.wait() // Only blocked here

    for(ev:ev-list){
      switch(ev){
        case: ev1
          event-handler1();
          break;
        case: ev2
          event-handler2();
          break;    
      }
    }
  }
}
```

Since Event Driven Architecture uses a Single Thread called the Main Loop, Race Conditions do not occur. It has the big advantage that programming is simple because resource synchronization using Locks is unnecessary. However, it also has several drawbacks.

First, the Main Loop must not become Blocked inside an Event Handler. It must become Blocked only at the point where it waits for Events. If it becomes Blocked inside an Event Handler, Events that occur in the meantime cannot be processed, so the program's responsiveness drops significantly. Most Blocking behavior that occurs inside Event Handlers comes from System Calls such as `read()` and `write()` for I/O operations. To prevent such Blocking, System Calls must be invoked with the Non-blocking Option or AIO (Async I/O) must be used.

Another drawback is that, because it operates with a Single Thread, it cannot utilize 100% of the CPU in a Multi-Core environment. Therefore, CPU Bound work cannot be properly handled using Event Driven Architecture alone.

## 2. On Linux

#### 2.1. I/O Multiplexer

Linux provides three I/O Multiplexers: `select()`, `poll()`, and `epoll()`. On Linux, every program processes I/O using fds (File Descriptors). Taking advantage of this characteristic, an I/O Multiplexer performs Multiplexing by detecting fd state changes and notifying the program. In general, `epoll()`, which has the best performance, is used the most. However, since `epoll()` is not a POSIX standard and is supported only on Linux Kernel 2.6 and later, `select()` or `poll()` must be chosen depending on the development environment.

#### 2.2. fd Heler functions

The I/O Multiplexers supported on Linux all operate based on fds. Because of this characteristic, Events delivered to a program must be receivable as fds or transferable to fds. The Linux Kernel provides the `timerfd()`, `signalfd()`, and `eventfd()` functions that help with this Event / fd conversion.

The `timerfd()` function changes an fd to the readable state at regular intervals. Therefore, `timerfd()` can be used to execute an Event Handler at regular intervals. `signalfd()` plays the role of converting Signals coming from the Linux Kernel into fd changes. Through `signalfd()`, Signal handling can be performed in an Event Handler.

`eventfd()` helps Events be exchanged through an fd. `eventfd()` allocates only **a single 8Byte Counter variable** in the Kernel area each time an Object is created. Performing a Write on `eventfd()` adds the written value to the Counter value. Performing a Read either sets the Counter value to 0 or decreases the Counter value by 1 depending on the `eventfd()` Option.

Since `eventfd()` delivers Events only by manipulating the Counter value, it has low Overhead. It can also deliver Events between User/User Threads and User/Kernel Threads. Unlike `pipe()`, Events are exchanged through a single fd. To exchange Messages through `eventfd()`, a separate Memory sharing technique such as the Shared Memory technique must be used together.

#### 2.3. Architecture Design

{{< figure caption="[Figure 2] Event Driven Architecture running on Linux" src="images/event-driven-architecture-on-linux.png" width="500px" >}}

Using `epoll()` and the fd Helper Functions, an Architecture design like [Figure 2] is possible. For communication between Handlers, `eventfd()` and a Queue in the global space are used. Communication is performed by putting a Message into the Queue and then delivering the Event to the Handler through `eventfd()`.

## 3. References

* timerfd_create man page : [http://man7.org/linux/man-pages/man2/timerfd_create.2.html](http://man7.org/linux/man-pages/man2/timerfd_create.2.html)
* signalfd man page : [http://man7.org/linux/man-pages/man2/signalfd.2.html](http://man7.org/linux/man-pages/man2/signalfd.2.html)
* eventfd man page : [http://man7.org/linux/man-pages/man2/eventfd.2.html](http://man7.org/linux/man-pages/man2/eventfd.2.html)
* eventfd : [http://lethean.github.io/2011/07/07/eventfd/](http://man7.org/linux/man-pages/man2/signalfd.2.html)

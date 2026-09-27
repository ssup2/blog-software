---
title: Thread-safe Function, Reentrant Function
---

## 1. Thread-safe Function

A function that can be executed by multiple Threads simultaneously without problems. When multiple Threads execute the same function at the same time, the biggest problem is the shared resources between Threads that the function uses. The integrity of shared resources must be guaranteed by protecting them with synchronization techniques such as Locks. A function that guarantees the integrity of shared resources in this way is called a **Thread-safe function**. Since a Thread-safe function may use shared resources between Threads, the call result may vary depending on when each Thread calls the Thread-safe function.

```c {caption="[Code 1] Thread-safe Function Example", linenos=table}
pthread-mutex-t mutex = PTHREAD-MUTEX-INITIALIZER;
int global-var = 0;

int thread-safe-function()
{
    pthread-mutex-lock(&mutex);
    ++global-var;
    pthread-mutex-unlock(&mutex);
    return global-var;
}
```

[Code 1] shows a Thread-safe function. It uses a Mutex to safely increment the Global variable `global-var`. Therefore, the value of `global-var` increases by the number of times each Thread calls the `thread-safe-function()` function. Each Thread gets a different return value depending on the value of `global-var`.

## 2. Reentrant Function

Like a Thread-safe function, it is a function that can be executed by multiple Threads simultaneously, but does not use shared resources between Threads. Since it does not use shared variables, each Thread can always get the same call result. This property is expressed as Reentrancy (able to re-enter), so it is called a Reentrant function. A Reentrant function is a Thread-safe function, but a Thread-safe function cannot be said to be a Reentrant function.

```c {caption="[Code 2] /Reentrant Function Example", linenos=table}
int reentrant-function()
{
    int local-var = 0;
    ++local-var;
    return global-var;
}
```

[Code 2] shows a Reentrant function. It uses only the local variable `local-var`. Therefore, even if multiple Threads call the `reentrant-function()` function simultaneously, each Thread always receives 1 as the return value.

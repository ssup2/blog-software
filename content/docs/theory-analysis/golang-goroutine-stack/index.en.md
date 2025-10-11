---
title: Golang Goroutine Stack
---

This document analyzes Golang Goroutine Stack.

## 1. Goroutine Stack

The Golang Runtime manages Goroutine's Stack independently. A newly created Goroutine can use a Stack of **1KB** size by default, and dynamically allocates more Stack as needed. Before executing a function, a Goroutine compares the size of the Stack available to the Goroutine with the current Stack Pointer. If the Stack Pointer exceeds the size of the available Stack, it dynamically allocates more Stack to use.

```asm {caption="[Code 1] Goroutine Function Call", linenos=table}
foo:
mov %fs:-8, %RCX     // load G descriptor from TLS
cmp 16(%RCX), %RSP   // compare the stack limit and RSP (stack pointer)
jbe morestack        // jump to slow-path if not enough stack
sub $64, %RSP
...
mov %RAX, 16(%RSP)
...
add $64, %RSP
retq
...
morestack:           // call runtime to allocate more stack
callq <runtime.morestack>
```

[Code 1] shows this Logic in Assembly Code. At the beginning of the function, it compares the size (Limit) of the Stack available to the Goroutine stored in TLS (Thread Local Storage) with RSP that stores the Stack Pointer. If RSP exceeds the size of the Stack, it dynamically allocates Stack through the morestack function.

{{< figure caption="[Figure 1] Goroutine Split Stack" src="images/split-stack.png" width="600px" >}}

{{< figure caption="[Figure 2] Goroutine Growable Stack" src="images/growable-stack.png" width="550px" >}}

There are two techniques for dynamically allocating Stack: the **Split Stack** technique that maintains the existing Stack as is and allocates a new Stack of 1KB size, and the **Growable Stack** technique that allocates a new Stack of 1KB or more and copies the contents of the existing Stack. [Figure 1] shows the Split Stack technique, and [Figure 2] shows the Growable Stack technique.

The **Split Stack** technique has the biggest advantage of fast Stack Memory allocation. However, since it's difficult to know when a new Stack will be allocated just from the code content, it has the major disadvantage of being difficult to predict when performance degradation due to Stack allocation will occur. For example, in [Figure 1], if the `func1()` function is changed to use more local variables, the size of the Stack used by the `func1()` function becomes larger, and the `func2()` function may not be able to use the same Stack as the `func1()` function and may use a separate Stack.

In this case, every time the `func1()` function calls the `func2()` function, a new Stack is allocated inside the `func2()` function, causing performance degradation of the `func2()` function. This performance degradation may not be a big problem if the `func1()` function rarely calls `func2()`, but if it is called frequently, it will have a significant impact on performance. As a result, changing the `func1()` function can cause unexpected performance degradation where the `func2()` function becomes slower. In this way, the Split Stack technique can be a cause of unpredictable performance degradation.

The **Growable Stack** technique takes longer to allocate Stack compared to Split Stack because it needs to copy the contents of the existing Stack every time the Stack increases. However, since a once-increased Stack does not decrease, unexpected performance degradation due to Stack allocation does not occur after the Stack has sufficiently increased. For this reason, Goroutines use Growable Stack.

## 2. References

* [https://www.youtube.com/watch?v=-K11rY57K7k](https://www.youtube.com/watch?v=-K11rY57K7k)
* [https://assets.ctfassets.net/oxjq45e8ilak/48lwQdnyDJr2O64KUsUB5V/5d8343da0119045c4b26eb65a83e786f/100545-516729073-DMITRII-VIUKOV-Go-scheduler-Implementing-language-with-lightweight-concurrency.pdf](https://assets.ctfassets.net/oxjq45e8ilak/48lwQdnyDJr2O64KUsUB5V/5d8343da0119045c4b26eb65a83e786f/100545-516729073-DMITRII-VIUKOV-Go-scheduler-Implementing-language-with-lightweight-concurrency.pdf)
* [https://kuaaan.tistory.com/449](https://kuaaan.tistory.com/449)

---
title: Barrier
---

### 1. Barrier

It is one of the synchronization techniques in parallel programming. In a Process/Thread group, when any one Process/Thread reaches a specific Barrier, it blocks until all other Processes/Threads reach that Barrier. After all Processes/Threads reach that Barrier, the next command is executed. Barrier can be said to be a technique for controlling the flow of Processes/Threads.

Compilers sometimes change the order of commands while performing optimization, and Barrier can prevent such Reordering techniques of the Compiler.

#### 1.1. Example

```text {caption="[Text 1] Before Barrier Application"}
A -> B -> C -> D -> E
```

Even if code is written to execute commands in alphabetical order as above, the Compiler can change the execution order of commands through optimization. Let's assume that due to hardware characteristics, command A must be executed before command C. The compiler does not know these hardware characteristics and can change the execution order of commands A and C through Reordering.

```text {caption="[Text 2] After Barrier Application"}
A -> [Barrier] -> B -> C -> D -> E
```

If a Barrier is placed between command A and command B as above, all Processes/Threads within a specific Process/Thread group execute command A and then execute command B. Since there is a Barrier between command A and command C, the Compiler cannot change the execution order of commands A and C.

### 2. References

* [https://en.wikipedia.org/wiki/Barrier_(computer_scienc)](https://en.wikipedia.org/wiki/Barrier_(computer_science))
* [http://forum.falinux.com/zbxe/index.php?document_srl=534002&mid=Kernel_API](http://forum.falinux.com/zbxe/index.php?document_srl=534002&mid=Kernel_API)


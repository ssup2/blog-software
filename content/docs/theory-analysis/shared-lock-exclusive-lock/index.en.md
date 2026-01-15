---
title: Shared Lock, Exclusive Lock
---

This document analyzes Shared Lock and Exclusive Lock techniques.

## 1. Shared Lock, Exclusive Lock

### 1.1. Shared Lock

Also called Read Lock, it is used when only Read operations are performed after entering Critical Section. Even if Shared Lock is locked when entering Critical Section, Shared Lock can be held to enter Critical Section and read data. That is, multiple Threads can simultaneously enter Critical Section and perform Read operations. When Exclusive Lock is locked when entering Critical Section, wait until Exclusive Lock is released.

### 1.2. Exclusive Lock

Also called Write Lock, it is used when Write operations are performed after entering Critical Section. Exclusive Lock can be held to enter Critical Section only when Shared Lock and Exclusive Lock are not locked when entering Critical Section. That is, only one Thread can simultaneously enter Critical Section and perform Write during Write execution.

## 2. Advantages

General Lock techniques allow only one Thread to access Critical Section simultaneously. Therefore, only one Thread could perform Read operations in Critical Section simultaneously. Through Shared Lock and Exclusive Lock techniques, multiple Threads can perform Read operations in Critical Section simultaneously, so bottlenecks can be reduced compared to general Locks when there are many Read operations in Critical Section.

## 3. References

* [http://jeong-pro.tistory.com/94](http://jeong-pro.tistory.com/94)


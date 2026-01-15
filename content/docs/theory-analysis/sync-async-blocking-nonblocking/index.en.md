---
title: Sync/Async, Blocking/Non-blocking
---

This document organizes the concepts of Sync/Async and Blocking/Non-blocking.

## 1. Sync/Async, Blocking/Non-blocking

### 1.1. Sync/Async

Sync and Async are determined by whether the request result can be obtained **at the point when the request is completed**.

* Sync - The request result can be obtained at the point when the request is completed.
* Async - The request result cannot be obtained at the point when the request is completed. The request result can be confirmed through a separate Action performed later or Event reception.

### 1.2. Blocking/Non-blocking

Blocking and Non-blocking are determined by whether the subject that sent the request can do **other things** until it receives the request result.

* Blocking - The subject that sent the request cannot do other things until it receives the request result.
* Non-blocking - Other things can be performed even without receiving the request result.

### 1.3. Cases

Linux I/O related functions can be classified into 4 types depending on whether they are Sync/Async and Blocking/Non-blocking.

* Sync + Blocking
  * I/O function - read(), write() without O_NONBLOCK
  * The I/O processing result can be obtained when the I/O function call is completed, and the Thread that called the I/O function cannot perform other things until I/O processing is completed.

* Sync + Non-blocking
  * I/O function - read(), write() with O_NONBLOCK
  * The I/O processing result can be obtained when the I/O function call is completed, and the Thread that called the I/O function can perform other things even if I/O processing is not completed.
  * The Thread that called the I/O function must continue to call the I/O function again until I/O processing is completed.

* Async + Blocking
  * I/O function - select(), epoll() (Multiplexing) with read(), write() and O_NONBLOCK
  * The I/O processing result cannot be obtained even when the I/O function call is completed, and the Thread that called the I/O function cannot perform other things until I/O processing is completed.
  * After calling the I/O function, it calls the Multiplexing function and Blocks until an I/O processing completion Event occurs.

* Async + Non-blocking
  * I/O function - aio()
  * The I/O processing result cannot be obtained even when the I/O function call is completed, and the Thread that called the I/O function can perform other things even if I/O processing is not completed.

## 2. References

* [https://developer.ibm.com/articles/l-async/](https://developer.ibm.com/articles/l-async/)
* [https://interconnection.tistory.com/141](https://interconnection.tistory.com/141)
* [https://jh-7.tistory.com/25](https://jh-7.tistory.com/25)


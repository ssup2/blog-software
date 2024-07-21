---
title: Concurrency, Parallelism
---

유사 의미를 갖고 있는 Concurreny와 Parallelism을 비교한다. 

## 1. Concurrency (병행성)

Concurrency는 **프로그램의 성질**이다. 어떤한 프로그램이나 알고리즘이 여러 부분으로 나누어 동시에 처리된다면 있다면 Concurrent하다고 표현한다. Single Core의 CPU 위에서 Concurrent 프로그램이나 알고리즘이 동작해도, Lock을 통해 공유 자원을 관리해야 정상적인 동작을 수행한다.

## 2. Parallelism (병렬성)

Parallelism은 **기계의 성질**이다. CUDA, OpenMP, MPI 같은 프로그래밍 기법은 실제 CPU나 GPU가 가지고 있는 여러개의 Core를 이용하는 기법이다. 따라서 병렬 프로그래밍 기법이라고 불린다.

## 3. 참조

* [http://egloos.zum.com/minjang/v/2517211](http://egloos.zum.com/minjang/v/2517211)
---
title: Thread-safe 함수, Reentrant 함수
---

## 1. Thread-safe 함수

여러 Thread에서 동시에 실행해도 문제 없는 함수를 의미한다. 여러 Thread가 같은 함수를 동시에 실행할 경우 가장 큰 문제는 함수가 이용하는 Thread간 공유자원이다. 공유자원을 Lock같은 동기화 기법으로 보호하여 공유 자원의 무결성을 보장해야한다. 이렇게 공유 자원의 무결성을 보장하는 함수를 Thread-safe 함수라고 한다. Thread-safe 함수는 Thread간 공유자원을 이용할 수도 있기 때문에 각 Thread가 Thread-safe 함수를 호출하는 시간에 따라 호출 결과가 달라질 수 있다.

```c {caption="[Code 1] Thread-safe 함수 예제", linenos=table}
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

[Code 1]은 Thread-safe 함수를 나타내고 있다. Global 변수인 global-var를 안전하게 증가시키기 위해서 Mutex를 이용한다. 따라서 각 Thread가 thread-safe-function() 함수를 호출하는 횟수만큼 global-var 값이 증가할 것이다. 각 Thread는 global-var값에 따라서 다른 반환값을 얻게 된다.

## 2. Reentrant 함수

Thread-safe 함수와 마찬가지로 여러 Thread에서 동시에 실행이 가능하지만 Thread간 공유 자원를 이용하지 않는 함수를 의미한다. 공유 변수를 이용하지 않기 때문에 각 Thread는 언제나 같은 호출 결과를 얻을 수 있다. 이러한 성질을 Reentrancy(재진입 가능한) 하다라고 표현하기 때문에 Reentrant 함수라고 한다. Reentrant 함수는 Thread-safe 함수이지만 Thread-safe 함수는 Reentrant 함수라고 말할 수 없다.

```c {caption="[Code 2] /Reentrant 함수 예제", linenos=table}
int reentrant-function()
{
    int local-var = 0;
    ++local-var;
    return global-var;
}
```

[Code 2]는 Reentrant 함수를 나타내고 있다. 지역변수인 local-var만을 이용하고 있다. 따라서 여러 Thread들이 동시에 reentrant-function() 함수를 호출해도 각 Thread는 언제나 1을 반환 받는다.

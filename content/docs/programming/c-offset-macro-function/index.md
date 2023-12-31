---
title: C offsetof() Macro 함수
---

`offsetof()` Macro 함수를 분석한다.

## 1. offsetof()

```c {caption="[Code 1] offsetof() Macro 함수", linenos=table}
#define offsetof(TYPE, MEMBER) ((sizet) &((TYPE *)0)->MEMBER)
```

`offsetof()` Macro 함수는 Struct를 구성하는 **Member 변수의 Memory Offset**을 구하는 함수이다. [Code 1]은 `offsetof()` Macro 함수를 나타내고 있다. `offsetof()` Macro 함수는 다음과 같이 동작한다.

* (TYPE *)0 : 주소는 0이고 이 주소는 TYPE 구조체의 포인터이다.
* &((TYPE *)0)->MEMBER : MEMBER의 Offset을 구한다.
* ((sizet) &((TYPE *)0)->MEMBER) : 구한 Offset을 sizet로 Type Casting한다.

## 2. 예제

```c {caption="[Code 2] offsetof() MACRO 함수 예제", linenos=table}
#include <stdio.h>
#define offsetof(TYPE, MEMBER) ((size_t) &((TYPE *)0)->MEMBER)

struct offset{
    int a;
    int b;
    char c;
    double d;
    int e;
};

int main(void)
{
    printf("a : %d\n", offsetof(struct offset, a));
    printf("b : %d\n", offsetof(struct offset, b));
    printf("c : %d\n", offsetof(struct offset, c));
    printf("d : %d\n", offsetof(struct offset, d));
    printf("e : %d\n", offsetof(struct offset, e));

    return 0;
}
```

```shell {caption="[Shell 1] offsetof() MACRO 함수의 예제 출력"}
a : 0
b : 4
c : 8
d : 12
e : 20
```

`offsetof()` Macro 함수를 통해서 offset Struct의 각 Member 변수의 Memory Offset을 확인할 수 있다.
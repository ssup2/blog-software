---
title: C offsetof() Macro Function
---

This document analyzes the `offsetof()` macro function.

## 1. offsetof()

```c {caption="[Code 1] offsetof() Macro Function", linenos=table}
#define offsetof(TYPE, MEMBER) ((sizet) &((TYPE *)0)->MEMBER)
```

The `offsetof()` macro function calculates the **memory offset** of member variables that make up a struct. [Code 1] shows the `offsetof()` macro function. The `offsetof()` macro function works as follows:

* (TYPE *)0 : The address is 0, and this address is a pointer to a TYPE struct.
* &((TYPE *)0)->MEMBER : Gets the offset of MEMBER.
* ((sizet) &((TYPE *)0)->MEMBER) : Casts the obtained offset to sizet.

## 2. Example

```c {caption="[Code 2] offsetof() MACRO Function Example", linenos=table}
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

```shell {caption="[Shell 1] offsetof() MACRO Function Example Output"}
a : 0
b : 4
c : 8
d : 12
e : 20
```

You can check the memory offset of each member variable of the offset struct through the `offsetof()` macro function.


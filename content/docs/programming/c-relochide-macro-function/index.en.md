---
title: C RELOC_HIDE() Macro Function
---

This document analyzes the `RELOC_HIDE()` macro function.

## 1. Macro

```c {caption="[Code 1] RELOC_HIDE() Macro Function", linenos=table}
#define RELOC_HIDE(ptr, off)                    \
  ({ unsigned long __ptr;                       \
    __asm__ ("" : "=r"(__ptr) : "0"(ptr));      \
    (typeof(ptr)) (__ptr + (off)); })
```

The `RELOC_HIDE()` macro function calculates the sum of ptr and off passed as parameters. It is used to remove errors that can occur due to compiler optimization techniques. [Code 1] shows the `RELOC_HIDE()` macro function. Due to the inline assembly on line 3 of [Code 1], the compiler cannot perform optimization. `__asm__ ("" : "=r"(__ptr) : "0"(ptr))` is equivalent to `__ptr = ptr`.

## 2. References

* [http://studyfoss.egloos.com/viewer/5374731](http://studyfoss.egloos.com/viewer/5374731)


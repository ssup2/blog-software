---
title: C Macro Syntax
---

This document summarizes C language macro syntax.

## 1. Stringification Operator (#)

```c {caption="[Code 1] # Macro Example", linenos=table}
#include <stdio.h>
#define PRINT(s)    printf(#s)

int main()
{
    PRINT(THIS IS TEST CODE);                          
    return 0;
}
```

```shell {caption="[Shell 1] # Macro Example Output"}
THIS IS TEST CODE
```

The stringification operator (#) converts macro parameters to strings. It has the same effect as adding `" "`. [Code 1] shows an example where the `THIS IS TEST CODE` macro parameter is passed as a string to the `printf()` function.

## 2. Token Pasting Operator (##)

```c {caption="[Code 2] ## Macro Example", linenos=table}
#include <stdio.h>

#define INT_i(n)        int i##n = n;
#define PRINT(n)        printf("i%d = %d\n", n, i##n)

int main()
{
    INT_i(0);
    PRINT(0);

    return 0;
}
```

```shell {caption="[Shell 2] ## Macro Example Output"}
i0 = 0
```

The token pasting operator (`##`) combines separate tokens into one. In [Code 2], the `INT_i()` macro function is replaced with `int i0 = 0`, and the `PRINT()` macro function is replaced with `printf("i%d = %d\n", 0, i0)`.

## 3. Variadic Macro

```c {caption="[Code 3] 1999 Standard Variadic Macro", linenos=table}
#define debug(format, ...) fprintf (stderr, format, __VA_ARGS__)
```

```c {caption="[Code 4] GCC Variadic Macro", linenos=table}
#define debug(format, args...) fprintf (stderr, format, args)
```

The 1999 C standard uses `...` and `__VA_ARGS__` to represent variadic arguments. [Code 3] shows the usage of variadic macros in the 1999 C standard syntax. GCC uses `[name]...` and `[name]` to represent variadic arguments. [Code 4] shows the usage of GCC variadic macros.

## 4. References

* [http://msdn.microsoft.com/en-us/library/7e3a913x.aspx](http://msdn.microsoft.com/en-us/library/7e3a913x.aspx)
* [https://www.google.co.kr/?gfe_rd=cr&ei=HzoMVIOrEYTN8ge3oYGgDw&gws_rd=ssl#newwindow=1&q=c+macro+%EB%AC%B8%EB%B2%95](https://www.google.co.kr/?gfe_rd=cr&ei=HzoMVIOrEYTN8ge3oYGgDw&gws_rd=ssl#newwindow=1&q=c+macro+%EB%AC%B8%EB%B2%95)
* [https://gcc.gnu.org/onlinedocs/cpp/Variadic-Macros.html](https://gcc.gnu.org/onlinedocs/cpp/Variadic-Macros.html)


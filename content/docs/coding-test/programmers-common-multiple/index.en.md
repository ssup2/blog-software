---
title: Programmers / Common Multiple
---

## Problem

* Link
  * [https://school.programmers.co.kr/learn/courses/30/lessons/181936](https://school.programmers.co.kr/learn/courses/30/lessons/181936)
* Description
  * Write a function that returns 1 if a number is a common multiple of two numbers, otherwise returns 0
* Type
  * Simple Operation

## Solution 1

```java {caption="Solution 1", linenos=table}
class Solution {
    public int solution(int number, int n, int m) {
        if ((number % n == 0) && (number % m == 0)) {
            return 1;
        }
        return 0;
    }
}
```

* Description
  * Check for common multiple using the modulo operator
* Time Complexity
  * O(1)
  * Always performs the same operation
* Space Complexity
  * O(1)
  * Function parameters and local variables


---
title: LeetCode / Reverse Integer
---

## Problem

* Link
  * [https://leetcode.com/problems/reverse-integer/](https://leetcode.com/problems/reverse-integer/)
* Description
  * Reverse the digits of a number
* Type
  * Brute Force

## Solution 1

```python {caption="Solution 1", linenos=table}
class Solution:
    def reverse(self, x: int) -> int:
        # Init vars
        digit_list = []
        positive = True if x > 0 else False
        if not positive:
            x = -x

        # Store each digits to stack
        while x != 0:
            digit = x % 10
            digit_list.append(digit)
            x = int(x / 10)

        # Make up result
        result = 0
        while len(digit_list) != 0:
            result = result * 10
            digit = digit_list.pop(0)
            result = result + digit

        if result > 2147483647:
            return 0
        if positive:
            return result
        else:
            return -result
```

* Description
  * Extract digits one by one from the end using the modulo operator and store them in a queue
  * Then retrieve digits from the queue one by one to construct the reversed number
* Time Complexity
  * O(len(s))
* Space Complexity
  * O(len(s))


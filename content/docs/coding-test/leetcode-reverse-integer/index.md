---
title: LeetCode / Reverse Integer
---

## Problem

* Link
  * [https://leetcode.com/problems/reverse-integer/](https://leetcode.com/problems/reverse-integer/)
* Description
  * 숫자를 역순으로 배열
* Type
  * 완전 탐색

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
  * 나머지 연산자를 활요하여 끝자리부터 하나씩 숫자를 추출하고 Queue에 저장
  * 이후에 하나씩 Queue에서 숫자를 얻어와 역순으로 숫자 구성
  * 역순
* Time Complexity
  * O(len(s))
* Space Complexity
  * O(len(s))

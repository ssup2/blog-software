---
title: Programmers / 공배수
---

## Problem

* Link
  * [https://school.programmers.co.kr/learn/courses/30/lessons/181936](https://school.programmers.co.kr/learn/courses/30/lessons/181936)
* Description
  * 두 수의 공배수 일 경우에 1을 반환하고 아니면 0을 반환하는 함수 작성
* Type
  * 단순 연산

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
  * 나머지 연산자를 활용하여 공배수 확인
* Time Complexity
  * O(1)
  * 언제나 동일한 연산 수행
* Space Complexity
  * O(1)
  * 언제나 동일한 메모리 이용
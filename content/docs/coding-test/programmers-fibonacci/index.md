---
title: Programmers / 피보나치 수
---

## Problem

* Link
  * [https://programmers.co.kr/learn/courses/30/lessons/12945](https://programmers.co.kr/learn/courses/30/lessons/12945)
* Description
  * 피보나치 수를 구하고 1234567로 나눈 나머지 값 반환
* Type
  * 동적 프로그래밍

## Solution 1

```java {caption="Solution 1", linenos=table}
class Solution {
    private static final int[] sumArray = new int[100000 + 1];
    
    public int solution(int n) {
        // Retrun for 0, 1
        if (n == 0) {
            return 0;
        } else if (n == 1) {
            return 1;
        }
        
        // Check sumArray and Sum
        if (sumArray[n] != 0) {
            return sumArray[n] % 1234567;
        } else {
        	int sum = solution(n-1) + solution(n-2);
            sumArray[n] = sum;
            return sum % 1234567;
        }
    }
}
```

* Description
* Time Complexity
* Space Complexity

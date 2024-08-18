---
title: Programmers / 길이에 따른 연산
---

## Problem

* Link
  * [https://school.programmers.co.kr/learn/courses/30/lessons/181879](https://school.programmers.co.kr/learn/courses/30/lessons/181879)
* Description
  * 배열의 길이에 따라서 덧샘 연산을 수행하거나 곱셈 연산을 수행
* Type
  * 단순 연산

## Solution 1

```java {caption="Solution 1", linenos=table}
class Solution {
    public int solution(int[] num_list) {
        int answer = 0;
        
        if (num_list.length >= 11) {
            for (int i = 0; i < num_list.length; i++) {
                answer += num_list[i];
            }
        } else {
            answer = 1;
            for (int i = 0; i < num_list.length; i++) {
                answer *= num_list[i];
            }
        }
        
        return answer;
    }
}
```

* Description
  * 배열의 길이를 확인한 이후에 연산 수행
* Time Complexity
  * O(1)
  * 언제나 동일한 연산 수행
* Space Complexity
  * O(1)
  * 함수의 Paramater 및 지역 변수
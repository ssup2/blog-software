---
title: Programmers / Operation Based on Length
---

## Problem

* Link
  * [https://school.programmers.co.kr/learn/courses/30/lessons/181879](https://school.programmers.co.kr/learn/courses/30/lessons/181879)
* Description
  * Perform addition or multiplication based on the array length
* Type
  * Simple Operation

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
  * Check the array length and then perform the operation
* Time Complexity
  * O(1)
  * Always performs the same operation
* Space Complexity
  * O(1)
  * Function parameters and local variables


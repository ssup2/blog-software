---
title: Programmers / 폰켓몬
---

## Problem

* Link
  * [https://programmers.co.kr/learn/courses/30/lessons/1845](https://programmers.co.kr/learn/courses/30/lessons/1845)
* Description
  * 폰캣몬의 종류를 확인
* Type
  * Set 활용

## Solution 1

```java {caption="Solution 1", linenos=table}
import java.util.Set;
import java.util.HashSet;

class Solution {
    public int solution(int[] nums) {
        Set<Integer> set = new HashSet<Integer>();

        // Create existing phonecatmon set
        for (int i = 0; i < nums.length; i++) {
            set.add(nums[i]);
        }
        
        // Return
        if (set.size() > (nums.length / 2)) {
            return nums.length / 2;
        }
        return set.size();
    }
}
```

* Description
  * 폰캣몬 종류의 개수는 Set을 활용하여 검사
  * 폰캣몬 종류의 개수가 전체 폰캣몬 개수의 절반 이상인 경우에는, 전체 폰캣몬 개수의 절반을 반환
  * 폰캣몬 종류의 개수가 전체 폰캣몬 개수의 절반 이하인 경우에는, 폰캣몬 종류의 개수 반환
* Time Complexity
  * O(len(nums))
  * nums 길이에 따라서 비례하여 연산 수행
* Space Complexity
  * O(1)
  * 함수의 Paramater 및 지역 변수
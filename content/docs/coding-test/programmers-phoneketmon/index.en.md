---
title: Programmers / Pokemon
---

## Problem

* Link
  * [https://programmers.co.kr/learn/courses/30/lessons/1845](https://programmers.co.kr/learn/courses/30/lessons/1845)
* Description
  * Identify the types of Pokemon
* Type
  * Set Usage

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
  * Use Set to check the number of Pokemon types
  * If the number of Pokemon types is greater than or equal to half of the total Pokemon count, return half of the total count
  * If the number of Pokemon types is less than or equal to half of the total Pokemon count, return the number of Pokemon types
* Time Complexity
  * O(len(nums))
  * Operations proportional to nums length
* Space Complexity
  * O(1)
  * Function parameters and local variables


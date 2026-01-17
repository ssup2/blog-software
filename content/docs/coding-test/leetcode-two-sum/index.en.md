---
title: LeetCode / Two Sum
---

## Problem

* Link
  * [https://leetcode.com/problems/two-sum/](https://leetcode.com/problems/two-sum/)
* Description
  * Find two numbers that sum to the target number and return their indices
* Type
  * Brute Force

## Solution 1

```java {caption="Solution 1", linenos=table}
class Solution {
    public int[] twoSum(int[] nums, int target) {
        int i = 0, j = 0;
        
        loop:
        for (i = 0; i < nums.length; i++) {
            for (j = i + 1; j < nums.length; j++) {
                if (nums[i] + nums[j] == target) {
                   break loop; 
                }
            }
        }
        
        return new int[] {i, j};
    }
}
```

* Description
  * Performs brute force search without duplicates
* Time Complexity
  * O(len(nums)^2)
  * Two nested for loops of size len(nums)
* Space Complexity
  * O(len(nums))
  * Memory usage proportional to len(nums) for function input


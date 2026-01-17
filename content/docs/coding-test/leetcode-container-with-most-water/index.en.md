---
title: LeetCode / Container With Most Water
---

## Problem

* Link
  * [https://leetcode.com/problems/container-with-most-water/](https://leetcode.com/problems/container-with-most-water/)
* Description
  * Find the container that can hold the most water
* Type
  * Two Pointers Pattern

## Solution 1

```python {caption="Solution 1", linenos=table}
class Solution:
    def maxArea(self, height: List[int]) -> int:
        # Init vars
        max_area = 0
        start_index = 0
        end_index = len(height) - 1

        while start_index != end_index:
            # Get height
            start_height = height[start_index]
            end_height = height[end_index]

            # Find min height
            min_height = 0
            if start_height > end_height:
                min_height = end_height
            else:
                min_height = start_height
            
            # Get area and compare with max_area
            area = min_height * (end_index - start_index)
            if area > max_area:
                max_area = area

            # Move index of min height
            if start_height > end_height:
                end_index = end_index - 1
            else:
                start_index = start_index + 1
            
        return max_area
```

* Description
  * Search for the widest area by adjusting indices from both sides of the list one by one
  * Move the index with smaller height one by one to search for the area
* Time Complexity
  * O(n)
* Space Complexity
  * O(1)


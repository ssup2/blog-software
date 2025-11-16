---
title: LeetCode / Container With Most Water
---

## Problem

* Link
  * [https://leetcode.com/problems/container-with-most-water/](https://leetcode.com/problems/container-with-most-water/)
* Description
  * 가장 많은 양의 물이 달길 Container 찾기
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
  * List의 양쪽으로 부터 하나씩 Index를 조정하면서 가장 넓은 영역을 탐색
  * Height가 작은 Index를 하나씩 움직이며 넓이를 탐색
* Time Complexity
  * O(n)
* Space Complexity
  * O(1)

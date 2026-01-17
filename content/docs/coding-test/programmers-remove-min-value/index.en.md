---
title: Programmers / Remove Smallest Number
---

## Problem

* Link
  * [https://programmers.co.kr/learn/courses/30/lessons/12935](https://programmers.co.kr/learn/courses/30/lessons/12935)
* Description
  * Return an array with the smallest value removed from a number array
* Type
  * X

## Solution 1

```java {caption="Solution 1", linenos=table}
class Solution {
    public int[] solution(int[] arr) {
        // Check array size and return -1
        if (arr.length == 0 || arr.length == 1) {
            return new int[] {-1};
        }
        
        // Find min value
        int min = Integer.MAX_VALUE;
        for (int i = 0; i < arr.length; i++) {
            if (min > arr[i]) {
                min = arr[i];
            }
        }
        
        // Set result
        int j = 0;
        int[] result = new int[arr.length-1];
        for (int i = 0; i < arr.length; i++) {
            if (min != arr[i]) {
                result[j] = arr[i];
                j++;
            }
        }
        
        return result;
    }
}
```

* Description
  * First find the smallest value, then remove it from the array
* Time Complexity
  * O(len(arr))
  * Two for loops of size len(arr)
* Space Complexity
  * O(len(arr))
  * Memory usage proportional to len(arr) for function input


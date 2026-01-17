---
title: Programmers / Maximum and Minimum Values
---

## Problem

* Link
  * [https://programmers.co.kr/learn/courses/30/lessons/12939?language=java](https://programmers.co.kr/learn/courses/30/lessons/12939?language=java)
* Description
  * Find and return the maximum and minimum values among numbers in a space-separated string
* Type
  * X

## Solution 1

```java {caption="Solution 1", linenos=table}
class Solution {
    public String solution(String s) {
        // Convert string to int
        String[] splits = s.split(" ");
        int[] integers = new int[splits.length];
        for (int i = 0; i < splits.length; i++) {
            integers[i] = Integer.parseInt(splits[i]);
        }
        
        // Find min
        int min = Integer.MAX_VALUE;
        for (int i = 0; i < integers.length; i++) {
            if (integers[i] < min) {
                min = integers[i];
            }
        }
        
        // Find max
        int max = Integer.MIN_VALUE;
        for (int i = 0; i < integers.length; i++) {
            if (integers[i] > max) {
                max = integers[i];
            }
        }
        
        return min + " " + max;
    }
}
```

* Description
  * Split the string by spaces and convert to integers
  * Return the maximum and minimum values of the converted numbers
* Time Complexity
  * O(spaceCount(s))
  * For loop iterates as many times as the number of numbers in the string
* Space Complexity
  * O(spaceCount(s))
  * Array size allocation proportional to the number of numbers in the string


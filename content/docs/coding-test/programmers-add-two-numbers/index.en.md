---
title: Programmers / Pick Two and Add
---

## Problem

* Link
  * [https://programmers.co.kr/learn/courses/30/lessons/68644](https://programmers.co.kr/learn/courses/30/lessons/68644)
* Description
  * Pick two numbers from different indices in a number array and return all possible sums sorted in ascending order
* Type
  * Brute Force

## Solution 1

```java {caption="Solution 1", linenos=table}
import java.util.TreeSet;
import java.util.Iterator;

class Solution {
    public int[] solution(int[] numbers) {
        // Init treeset
        TreeSet<Integer> set = new TreeSet<>();
        
        // Add
        for (int i = 0; i < numbers.length - 1; i++) {
            for (int j = i + 1; j < numbers.length; j++) {
                int sum = numbers[i] + numbers[j];
           		set.add(sum);
            }
        }
        
        // Set result
        Iterator<Integer> it = set.iterator();
        int[] result = new int[set.size()];
        for (int i = 0; i < set.size(); i++) {
            result[i] = it.next();
        }
        return result;
    }
}
```

* Description
  * Uses TreeSet for deduplication and sorting functionality
* Time Complexity
  * O(len(numbers)^2)
  * Two nested for loops of size len(numbers)
* Space Complexity
  * O(len(numbers))
  * Memory usage proportional to len(numbers) for function input


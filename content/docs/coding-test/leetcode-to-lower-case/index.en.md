---
title: LeetCode / To Lower Case
---

## Problem

* Link
  * [https://leetcode.com/problems/to-lower-case/](https://leetcode.com/problems/to-lower-case/)
* Description
  * Convert uppercase letters in a string to lowercase
* Type
  * X

## Solution 1

```java {caption="Solution 1", linenos=table}
class Solution {
    public String toLowerCase(String str) {
        char[] charArry = str.toCharArray();
        for (int i = 0; i < charArry.length; i++) {
            charArry[i] = getLower(charArry[i]);
        }
        return new String(charArry);
    }
    
    private boolean isUpper(char c) {
        return (c >= 'A') && (c <= 'Z');
    }
    
    private char getLower(char c) {
        if (isUpper(c)) {
            return (char)((c - 'A') + 'a');
        } else {
            return c;
        }
    }
}
```

* Description
  * Check each character from the beginning of the string, and convert to lowercase if it's uppercase
* Time Complexity 
  * O(len(str))
  * For loop of size len(str)
* Space Complexity 
  * O(len(str))
  * Memory usage proportional to len(str) for function input


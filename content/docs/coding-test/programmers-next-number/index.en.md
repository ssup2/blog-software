---
title: Programmers / Next Bigger Number
---

## Problem

* Link
  * [https://programmers.co.kr/learn/courses/30/lessons/12911](https://programmers.co.kr/learn/courses/30/lessons/12911)
* Description
  * Find and return the next number that has the same number of 1s when converted to binary
* Type
  * Brute Force

## Solution 1

```java {caption="Solution 1", linenos=table}
class Solution {
    public int solution(int n) {
        // Get n's one count
        int nBinOneCount = getOneCount(n);
        
        // Find n's next
        for (int i = n + 1; i <= 1000000; i++) {
            if (nBinOneCount == getOneCount(i)) {
                return i;
            }
        }
        
        // Not found
        return 0;
    }
    
    private int getOneCount(int n) {
        String nBin = Integer.toBinaryString(n);
        int oneCount = 0;
        for (int i = 0; i < nBin.length(); i++) {
            if (nBin.charAt(i) == '1') {
                oneCount++;
            }
        }
        return oneCount;
    }
}
```

* Description
  * Convert n to binary and count the number of 1s
  * Increment one by one, count the number of 1s, and check if it matches n's count
* Time Complexity
  * O(1)
  * The size of n does not affect time complexity
* Space Complexity
  * O(1)
  * Function parameters and local variables


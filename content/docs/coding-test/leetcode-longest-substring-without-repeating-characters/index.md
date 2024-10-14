---
title: LeetCode / Longest Substring Without Repeating Characters
---

## Problem

* Link
  * [https://leetcode.com/problems/longest-substring-without-repeating-characters/description/](https://leetcode.com/problems/longest-substring-without-repeating-characters/description/)
* Description
  * 중복되지 않는 문자로 구성된 최대 길이의 문자열 탐색
* Type
  * 완전 탐색

## Solution 1

```python {caption="Solution 1", linenos=table}
class Solution:
    def lengthOfLongestSubstring(self, s: str) -> int:
        # Init vars
        result = 0
        char_dict = dict()

        # Find max char_dict
        index = 0
        while index < len(s):
            char = s[index]
            # If char not in char_dict, Add the char to char_dict
            if char not in char_dict:
                char_dict[char] = index
                if len(char_dict) > result:
                    result = len(char_dict)
                index = index + 1
            # If char in char_dict, remake char_dict from duplicated char index
            else:
                index = char_dict[char] + 1
                char_dict = dict()

        return result
```

* Description
  * Map을 만들고 문자열에 중복되는 문자가 존재하는지 확인하며 최대 길이의 문자열 탐색
  * Map에 문자열이 존재하지 않으면, 해당 문자가 위차한 Index와 함께 Map에 저장
  * Map에 문자열이 존재하면, 해당 문자가 존재한 Index부터 다시 탐색 시작
* Time Complexity
  * O(len(s))
* Space Complexity
  * O(len(s))

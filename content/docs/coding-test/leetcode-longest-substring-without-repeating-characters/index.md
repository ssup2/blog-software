---
title: LeetCode / Longest Substring Without Repeating Characters
---

## Problem

* Link
  * [https://leetcode.com/problems/longest-substring-without-repeating-characters/description/](https://leetcode.com/problems/longest-substring-without-repeating-characters/description/)
* Description
  * 중복되지 않는 문자로 구성된 최대 길이의 문자열 탐색
* Type
  * Brute Force
  * Sliding Window Pattern

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

## Solution 2

```python {caption="Solution 2", linenos=table}
class Solution:
    def lengthOfLongestSubstring(self, s: str) -> int:
        # Init vars
        left_index = 0              # left index of the sliding window
        max_length = 0              # maximum length of the substring
        last_seen_index = dict()    # last seen index of the character
        
        for right_index, char in enumerate(s):
            # if the character was seen and is inside the current window
            if char in last_seen_index and last_seen_index[char] >= left_index:
                # move the left pointer to avoid duplicates
                left_index = last_seen_index[char] + 1
            
            # update the last seen index of this character
            last_seen_index[char] = right_index
            
            # update the maximum window size
            max_length = max(max_length, right_index - left_index + 1)
        
        return max_length
```

* Description
  * Sliding Window와 문자 마지막을 위치를 Map에 저장
  * 중복된 문자가 나타난 경우 `left_index`를 이동시켜서 중복된 문자 제거
  * 각 단계에서 `right_index - left_index + 1` 값을 계산하여 `max_length`와 비교하여 최대 길이 갱신
* Time Complexity
  * O(len(s))
* Space Complexity
  * O(len(s))
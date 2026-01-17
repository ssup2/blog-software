---
title: LeetCode / Longest Substring Without Repeating Characters
---

## Problem

* Link
  * [https://leetcode.com/problems/longest-substring-without-repeating-characters/description/](https://leetcode.com/problems/longest-substring-without-repeating-characters/description/)
* Description
  * Find the longest substring without repeating characters
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
  * Create a map and check for duplicate characters while searching for the longest substring
  * If the character is not in the map, store it along with its index
  * If the character exists in the map, restart the search from the index where it was found
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
  * Use sliding window and store the last position of each character in a map
  * When a duplicate character appears, move `left_index` to remove the duplicate
  * At each step, calculate `right_index - left_index + 1` and compare with `max_length` to update the maximum length
* Time Complexity
  * O(len(s))
* Space Complexity
  * O(len(s))


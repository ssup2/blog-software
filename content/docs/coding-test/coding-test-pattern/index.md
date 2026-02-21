---
title: Coding Test Pattern
---

## 1. Backtracking

* Example Problems

## 2. Dynamic Programming

* Example Problems

## 3. Binary Tree Traversal

* Example Problems

## 4. DFS, BFS

* Example Problems

## 5. Top K Elements

* Example Problems

## 6. Prefix Sum

* 배열의 누적 합을 계산한 배열을 사용하는 패턴
* 배열의 부분 합을 빠르게 계산 가능
* 문제에 따라서 원본 배열을 Prefix Sum Array로 변환하여 추가 메모리없이 Prefix Sum Array를 사용가능
```python
def create_prefix_sum(nums: List[int]) -> List[int]:
    for i in range(1, len(nums)):
        nums[i] += nums[i - 1]
    return nums
```
* Example
  * Original Array : `[1, 2, 3, 4, 5]`
  * Prefix Sum Array : `[1, 3, 6, 10, 15]`
  * Sum of Subarray : `sum(i, j) = prefix_sum[j] - prefix_sum[i - 1]`
* Example Problems
  * [LeetCode / Range Sum Query - Immutable](../../coding-test/leetcode-range-sum-query-immutable/)

## 7. Sliding Window

* 연속적인 부분 배열을 찾는데 유용한 패턴
* 완전 탐색대비 시간의 복잡도를 `O(n * k)`에서 `O(n)`으로 감소 가능 (`k`는 부분 배열의 크기)
* 일반적으로 `start_index`와 `end_index`를 이용하여 Window의 시작과 끝을 표현
* Example Problems
  * [LeetCode / Longest Substring Without Repeating Characters](../../coding-test/leetcode-longest-substring-without-repeating-characters/)

## 8. Two Pointers

* 두 개의 Pointer를 서로를 향하여 움직이거나, 서로 반대 방향으로 움직이며 탐색하는 패턴
* 완전 탐색 대비 시간의 복잡도를 `O(n^2)`에서 `O(n)`으로 감소 가능
* Example Problems
  * [LeetCode / Container With Most Water](../../coding-test/leetcode-container-with-most-water/)

## 9. Fast and Slow Pointers

* Example Problems

## 10. Modified Binary Search

* Example Problems

## 11. Monotonic Stack

* Example Problems

## 12. Linked List In-Place Reversal

* Example Problems

## 13. Overlapping Intervals

* Example Problems

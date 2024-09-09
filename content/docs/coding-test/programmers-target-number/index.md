---
title: Programmers / 타겟 넘버
---

## Problem

* Link
  * [https://school.programmers.co.kr/learn/courses/30/lessons/43165](https://school.programmers.co.kr/learn/courses/30/lessons/43165)
* Description
  * 타겟 넘버를 만들수 있는 조합의 개수 찾기
* Type
  * 완전 탐색 / DFS, BFS

## Solution 1

```python {caption="Solution 1", linenos=table}
def solution(numbers, target):
    return addsub(numbers, 0, 0, target)

def addsub(numbers, depth, sum, target):
    # Check depth
    if depth == len(numbers):
        if target == sum: 
            return 1
        else:
            return 0
        
    # Check sum
    number = numbers[depth]
    result = 0
    
    result = addsub(numbers, depth + 1, sum + number, target)
    result += addsub(numbers, depth + 1, sum - number, target)
    return result
```

* Description
  * DFS를 이용하여 모든 경우의 수 탐색
* Time Complexity
* Space Complexity

## Solution 2

```python {caption="Solution 1", linenos=table}
from queue import Queue

def solution(numbers, target):
    result = 0
    number_queue = Queue()
    number_queue.put((0, 0)) # depth, sum
    
    while number_queue.qsize() > 0:
        current = number_queue.get()
        current_depth = current[0]
        current_sum = current[1]
    
        # Check sum
        if current_depth == len(numbers):
            if current_sum == target:
                result += 1
            continue
        
        current_number = numbers[current_depth]
        number_queue.put((current_depth + 1, current_sum + current_number))
        number_queue.put((current_depth + 1, current_sum - current_number))
            
    return result
```

* Description
  * BFS를 이용하여 모든 경우의 수 탐색
* Time Complexity
* Space Complexity
---
title: Recursive Algorithm Time/Space Complexity
---

This post summarizes how to calculate the time complexity and space complexity of recursive algorithms.

## 1. Recursive Algorithm Time Complexity/Space Complexity

### 1.1. Factorial

``` {caption="[Function 1] Factorial"}
f(0) = 1
f(n) = n * f(n - 1)
```

``` {caption="[Explanation 1] Factorial Time Complexity"}
T(n) = T(n - 1) + 1C
     = T(n - 2) + 2C
     = T(0) + nC
     = 1 + nC
     = O(n)
```

* Time Complexity
  * O(n)
  * Since the function is called n times and no operation other than the multiplication is performed inside the function, it can be estimated that it has roughly O(n) time complexity.
* Space Complexity
  * O(n)
  * Since the function is called n times and the function internally uses no Memory other than the Memory required for the function calls, it can be estimated that it has roughly O(n) space complexity.

### 1.2. Fibonacci Sequence


``` {caption="[Function 2] Fibonacci Sequence"}
f(0) = 1
f(1) = 1
f(n) = f(n - 1) + f(n - 2)
```

## 2. References

* 재귀함수의 시간복잡도 구하기 : [https://m.blog.naver.com/PostView.naver?isHttpsRedirect=true&blogId=wns7756&logNo=221568348621](https://m.blog.naver.com/PostView.naver?isHttpsRedirect=true&blogId=wns7756&logNo=221568348621)
* [시간복잡도] 재귀 알고리즘의 시간복잡도 : [https://justicehui.github.io/easy-algorithm/2018/03/11/TimeComplexity4/](https://justicehui.github.io/easy-algorithm/2018/03/11/TimeComplexity4/)

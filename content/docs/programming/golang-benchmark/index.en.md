---
title: Golang Benchmarking
---

This document summarizes the benchmarking functionality provided by Golang.

## 1. Golang Benchmarking

```golang {caption="[Code 1] benchmarking.go", linenos=table}
package benchmark

func SumRange01(n, m int) int {
	result := 0
	for i := n; i <= m; i++ {
		result += i
	}
	return result
}

func SumRange02(n, m int) int {
	return ((m - n) / 2) * (m - n)
}

func Append(n int) []int {
	var result []int
	for i := 0; i < n; i++ {
		result = append(result, 1)
	}
	return result
}
```

Golang's testing package provides not only functionality for unit tests but also benchmarking functionality. [Code 1] shows functions for benchmarking. In [Code 1], the `SumRange01()` and `SumRange02()` functions are functions that calculate the sum of numbers in a specific range. The `SumRange01()` function has O(n) time complexity and O(1) space complexity, and the `SumRange02()` function has O(1) time complexity and O(1) space complexity. The `Append()` function is a function that appends 1 to a slice. It has O(n) time complexity and O(1) space complexity.

```golang {caption="[Code 2] benchmarking_test.go", linenos=table}
package benchmark

import (
	"testing"
)

func BenchmarkSumRange01(b *testing.B) {
	for i := 0; i < b.N; i++ {
		_ = SumRange01(10, 10000)
	}
}

func BenchmarkSumRange02(b *testing.B) {
	for i := 0; i < b.N; i++ {
		_ = SumRange02(10, 10000)
	}
}

func BenchmarkAppend(b *testing.B) {
	for i := 0; i < b.N; i++ {
		_ = Append(10000)
	}
}
```

[Code 2] shows test code for benchmarking the functions in [Code 1]. Functions for benchmarking must start with the name "Benchmark". Functions that perform benchmarking must be written to run "b.N" times. "b.N" is not a fixed value, but a value that is dynamically assigned depending on options when performing benchmarking.

```shell {caption="[Shell 1] Benchmarking"}
# go test -bench .
goos: linux
goarch: amd64
pkg: ssup2.com/test
cpu: AMD Ryzen 5 3600X 6-Core Processor             
BenchmarkSumRange01-12            495760              2352 ns/op
BenchmarkSumRange02-12          1000000000               0.2337 ns/op
BenchmarkAppend-12                 28550             42003 ns/op
PASS
ok      ssup2.com/test  3.081s
```

[Shell 1] shows benchmarking being performed. Benchmarking is performed through the "-bench" option. The benchmarking function name appears with a "-12" number, which means the number of CPU cores used when performing benchmarking. This can be set through the GOMAXPROCS environment variable. The numbers without units in the middle (495760, 1000000000, 28550) mean the number of times each loop (function) was performed, and the numbers in ns/op units mean the time it takes for each loop to execute once. Since the `SumRange02()` function has lower time complexity than the `SumRange01()` function, you can see that it is faster in the benchmarking results as well.

```shell {caption="[Shell 2] Benchmarking with benchmem Option"}
# go test -bench . -benchmem
goos: linux
goarch: amd64
pkg: ssup2.com/test
cpu: AMD Ryzen 5 3600X 6-Core Processor             
BenchmarkSumRange01-12            502443              2344 ns/op               0 B/op          0 allocs/op
BenchmarkSumRange02-12          1000000000               0.2338 ns/op          0 B/op          0 allocs/op
BenchmarkAppend-12                 29546             42306 ns/op          357628 B/op         19 allocs/op
PASS
ok      ssup2.com/test  3.129s
```

[Shell 2] shows benchmarking being performed with the "-benchmem" option, which also shows memory-related benchmarking results. Compared to [Shell 1], you can see that numbers in B/op units and allocs/op units have been added. Numbers in B/op units mean the amount of memory allocated when performing the loop once, and numbers in allocs/op units mean the number of memory allocations when performing the loop once.

```shell {caption="[Shell 3] Benchmarking with count Option"}
# go test -bench . -count 5 
goos: linux
goarch: amd64
pkg: ssup2.com/test
cpu: AMD Ryzen 5 3600X 6-Core Processor             
BenchmarkSumRange01-12            500970              2352 ns/op
BenchmarkSumRange01-12            509751              2387 ns/op
BenchmarkSumRange01-12            494068              2366 ns/op
BenchmarkSumRange01-12            510322              2358 ns/op
BenchmarkSumRange01-12            456585              2364 ns/op
BenchmarkSumRange02-12          1000000000               0.2357 ns/op
BenchmarkSumRange02-12          1000000000               0.2348 ns/op
BenchmarkSumRange02-12          1000000000               0.2338 ns/op
BenchmarkSumRange02-12          1000000000               0.2344 ns/op
BenchmarkSumRange02-12          1000000000               0.2354 ns/op
BenchmarkAppend-12                 29409             42820 ns/op
BenchmarkAppend-12                 28377             41828 ns/op
BenchmarkAppend-12                 27708             45797 ns/op
BenchmarkAppend-12                 28015             42034 ns/op
BenchmarkAppend-12                 25623             43263 ns/op
PASS
ok      ssup2.com/test  15.482s
```

[Shell 3] shows the "-count" option being performed, which allows benchmarking functions to be run multiple times. Since the count value is 5, you can see that benchmarking functions are performed 5 times each.

```shell {caption="[Shell 4] Benchmarking with benchtime time Option"}
# go test -bench . -benchtime 10s
goos: linux
goarch: amd64
pkg: ssup2.com/test
cpu: AMD Ryzen 5 3600X 6-Core Processor             
BenchmarkSumRange01-12           5099930              2371 ns/op
BenchmarkSumRange02-12          1000000000               0.2372 ns/op
BenchmarkAppend-12                290082             42028 ns/op
PASS
ok      ssup2.com/test  27.354s
```

```shell {caption="[Shell 5] Benchmarking with benchtime time Option"}
# go test -bench . -benchtime 10x
goos: linux
goarch: amd64
pkg: ssup2.com/test
cpu: AMD Ryzen 5 3600X 6-Core Processor             
BenchmarkSumRange01-12                10              2362 ns/op
BenchmarkSumRange02-12                10                23.00 ns/op
BenchmarkAppend-12                    10             63439 ns/op
PASS
ok      ssup2.com/test  0.006s
```

[Shell 4] shows setting how many seconds to perform benchmarking through the benchtime option. If it ends with "s", it means seconds, so [Shell 4] performs benchmarking for 10 seconds. [Shell 5] shows setting how many times to perform the loop through the benchtime option. If it ends with "x", it means benchmarking loops, so you can see that each benchmarking function in [Shell 5] performs the loop only 10 times.

## 2. References

* [https://blog.logrocket.com/benchmarking-golang-improve-function-performance/](https://blog.logrocket.com/benchmarking-golang-improve-function-performance/)


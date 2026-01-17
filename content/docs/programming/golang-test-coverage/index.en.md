---
title: Golang Test Coverage
---

This document summarizes how to check Test Coverage in Golang.

## 1. Golang Test Coverage

Golang provides functionality to check Test Code Coverage. Here, Coverage means Coverage called **Statement Coverage** or **Line Coverage**. Statement Coverage means Coverage that is satisfied when one line of Code is executed at least once.

```go {caption="[Code 1] coverage.go", linenos=table}
{% highlight golang %}
package coverage

func TestFunc(n int) int {
	if n < 0 {
		return -1
	} else if n == 0 {
		return 0
	} else {
		return 1
	}
}
```

```go {caption="[Code 2] coverage_test.go", linenos=table}
package coverage

import (
	"testing"
)

func TestCover(t *testing.T) {
	result := TestFunc(-1)
	if result != -1 {
		t.Error("Wrong result")
	}

	result = TestFunc(0)
	if result != 0 {
		t.Error("Wrong result")
	}
}
```

[Code 1] shows a simple function `testFunc()` for testing, and [Code 2] shows simple Test Code using the `testFunct()` function from [Code 1].

### 1.1. Test with Coverage

```shell {caption="[Shell 1] Test with Coverage"}
$ go test -cover .                   
ok      ssup2.com/test  0.001s  coverage: 80.0% of statements
```

[Shell 1] shows checking Package-level Coverage using the cover Option when performing Tests from [Code 2]. You can check Package-level Coverage through the cover Option.

### 1.2. Test with Coverage Profile

```shell {caption="[Shell 2] Test with Coverage Profile"}
$ go test -coverprofile cover.prof ./...
ok      ssup2.com/test  0.001s  coverage: 80.0% of statements

$ go tool cover -html=cover.prof -o cover.html
```

{{< figure caption="[Figure 1] go tool cover Output" src="images/golang-test-coverage.png" width="600px" >}}

When you want to check Code-level Coverage in detail, you can create and use a Coverage Profile. [Shell 2] shows creating a Coverage Profile using the coverprofile Option when performing Tests from [Code 2].

The created Coverage Profile can be converted to an HTML file through the `go tool cover` command, and you can easily check Coverage in a Web Browser using the converted HTML file. [Figure 1] shows the generated HTML from [Code 2]. Since the Test Code does not have cases where `n` is greater than 1, the last part of the `testFunc()` function is not executed, so you can see that Coverage does not reach 100%. You can check Coverage by file.

## 2. References

* [https://err0rcode7.github.io/backend/2021/05/11/%ED%85%8C%EC%8A%A4%ED%8A%B8%EC%BB%A4%EB%B2%84%EB%A6%AC%EC%A7%80.html](https://err0rcode7.github.io/backend/2021/05/11/%ED%85%8C%EC%8A%A4%ED%8A%B8%EC%BB%A4%EB%B2%84%EB%A6%AC%EC%A7%80.html)


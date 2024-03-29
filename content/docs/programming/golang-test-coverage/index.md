---
title: Golang Test Coverage
---

Golang의 Test Coverage 확인 방법을 정리한다.

## 1. Golang Test Coverage

Golang에서는 Test Code의 Coverage를 확인하는 기능을 제공한다. 여기서 Coverage는 **Statement Coverage** 또는 **Line Coverage**라고 불리는 Coverage를 의미한다. Statement Coverage는 Code 한 줄이 한번 이상 실행되면 충족되는 Coverage를 의미한다.

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

[Code 1]은 Test를 위한 간단한 함수인 `testFunc()` 함수를 나타내며, [Code 2]는 [Code 1]의 `testFunct()` 함수를 활용한 간단한 Test Code를 나타내고 있다.

### 1.1. Test with Coverage

```shell {caption="[Shell 1] Test with Coverage"}
$ go test -cover .                   
ok      ssup2.com/test  0.001s  coverage: 80.0% of statements
```

[Shell 1]은 [Code 2]의 Test를 수행할 때 cover Option을 이용하여 Package 단위의 Coverage를 확인하는 모습을 나타내고 있다. cover Option을 통해서 Package 단위의 Coverage를 확인할 수 있다.

### 1.2. Test with Coverage Profile

```shell {caption="[Shell 2] Test with Coverage Profile"}
$ go test -coverprofile cover.prof ./...
ok      ssup2.com/test  0.001s  coverage: 80.0% of statements

$ go tool cover -html=cover.prof -o cover.html
```

{{< figure caption="[Figure 1] go tool cover Output" src="images/golang-test-coverage.png" width="600px" >}}

Code Level Coverage를 자세히 확인해 보고 싶을때는 Coverage Profile을 생성하여 이용하면 된다. [Shell 2]는 [Code 2]의 Test를 수행할 때 coverprofile Option을 이용하여 Coverage Profile을 생성하는 모습을 나타낸다.

생성된 Coverage Profile은 `go tool cover` 명령어를 통해서 HTML 파일로 변환이 가능하며, 변환된 HTML 파일을 이용하여 Web Browser에서 쉽게 Coverage를 확인할 수 있다. [Figure 1]은 [Code 2]의 생성된 HTML을 나타내고 있다. Test Code에서는 `n`이 1보다 큰 경우는 없기 때문에 `testFunc()` 함수의 마지막 부분은 실행되지 않아 Coverage가 100%가 되지 않는 것을 확인할 수 있다. 파일 단위로 Coverage를 확인할 수 있다.

## 2. 참조

* [https://err0rcode7.github.io/backend/2021/05/11/%ED%85%8C%EC%8A%A4%ED%8A%B8%EC%BB%A4%EB%B2%84%EB%A6%AC%EC%A7%80.html](https://err0rcode7.github.io/backend/2021/05/11/%ED%85%8C%EC%8A%A4%ED%8A%B8%EC%BB%A4%EB%B2%84%EB%A6%AC%EC%A7%80.html)
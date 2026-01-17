---
title: Golang Error Wrapping
---

This document summarizes Golang error wrapping techniques.

## 1. Golang Error Wrapping

```golang {caption="[Code 1] Golang Error Example", linenos=table}
package main

import (
	"fmt"
)

var (
	innerError = &innerErr{Msg: "innerMsg"}
)

// Custom error
type innerErr struct {
	Msg string
}

func (i *innerErr) Error() string {
	return "innerError"
}

// Functions
func innerFunc() error {
	return innerError
}

func middleFunc() error {
	if err := innerFunc(); err != nil {
		return fmt.Errorf("middleError")
	}
	return nil
}

func outerFunc() error {
	if err := middleFunc(); err != nil {
		return fmt.Errorf("outerError")
	}
	return nil
}

func main() {
	// Get a error
	outerErr := outerFunc()

	// Print a error
	fmt.Printf("error: %v\n", outerErr)
}
```

```shell {caption="[shell 1] Code 1 Output"}
$ go run main.go
error: outerError
```

Golang's error wrapping is literally a technique of wrapping errors with other errors. Through error wrapping, errors returned by internal functions can also be identified in external functions. [Code 1] and [shell 1] show a common way of handling errors in Golang without error wrapping. When the `main()` function calls the `outerFunc()` function, `outerFunc()`, `middleFunc()`, and `innerFunc()` functions are called in order, and since the `innerFunc()` function returns an error, the `outerFunc()` function also returns an error.

The problem is that the `main()` function can only check the "outerErr" error returned by the `outerFunc()` function, and cannot check the content of errors returned by the `middleFunc()` or `innerFunc()` functions. The most obvious way to solve this problem is to make the external function's error also differ depending on the error returned by the internal function. The problem is that implementing it this way makes the error handling part of the external function complex. This problem can be easily solved through error wrapping techniques.

### 1.1. with Standard errors Package

```golang {caption="[Code 2] Golang Error Wrapping Example with Standard errors Package", linenos=table}
package main

import (e
	"errors"
	"fmt"
)

var (
	innerError = &innerErr{Msg: "innerMsg"}
	myError    = &myErr{Msg: "myMsg"}
)

// Custom errors
type innerErr struct {
	Msg string
}

func (i *innerErr) Error() string {
	return "innerError"
}

type myErr struct {
	Msg string
}

func (i *myErr) Error() string {
	return "myError"
}

// Functions
func innerFunc() error {
	return innerError
}

func middleFunc() error {
	if err := innerFunc(); err != nil {
		return fmt.Errorf("middleError: %w", err)
	}
	return nil
}

func outerFunc() error {
	if err := middleFunc(); err != nil {
		return fmt.Errorf("outerError: %w", err)
	}
	return nil
}

func main() {
	// Get a wrapped error
	outerErr := outerFunc()
	
	// Unwrap
	fmt.Printf("--- Unwrap ---\n")
	fmt.Printf("unwrap x 0: %v\n", outerErr)
	fmt.Printf("unwrap x 1: %v\n", errors.Unwrap(outerErr))
	fmt.Printf("unwrap x 2: %v\n", errors.Unwrap(errors.Unwrap(outerErr)))

	// Is (Compare)
	fmt.Printf("\n--- Is ---\n")
	if errors.Is(outerErr, innerError) {
		fmt.Printf("innerError true\n") // Print
	} else {
		fmt.Printf("innerError false\n")
	}
	if errors.Is(outerErr, myError) {
		fmt.Printf("myError true\n")
	} else {
		fmt.Printf("myError false\n") // Print
	}

	// As (Assertion, Type Casting)
	fmt.Printf("\n--- As ---\n")
	var iErr *innerErr
	if errors.As(outerErr, &iErr) {
		fmt.Printf("innerError true: %v\n", iErr.Msg) // Print
	} else {
		fmt.Printf("innerError false\n")
	}
	var mErr *myErr
	if errors.As(outerErr, &mErr) {
		fmt.Printf("myError true: %v\n", mErr.Msg)
	} else {
		fmt.Printf("myError false\n") // Print
	}
}
```

```shell {caption="[shell 2] Code 2 Output"}
$ go run main.go
--- Unwrap ---
unwrap x 0: outerError: middleError: innerError
unwrap x 1: middleError: innerError
unwrap x 2: innerError

--- Is ---
innerError true
myError false

--- As ---
innerError true: innerMsg
myError false
```

From Golang 1.13 onwards, error wrapping is possible through the `fmt.Errorf()` function, and wrapped errors can be retrieved again through the `errors.Unwrap()` function. Also, comparison of wrapped errors is possible through the `errors.Is()` function, and assertion of wrapped errors is possible through the `errors.As()` function. Here, both the fmt package and errors package are standard packages of Golang. [Code 2] and [shell 2] show examples of using error wrapping using standard packages.

* Lines 37, 44: Error wrapping is performed through the `fmt.Errorf()` function. In this case, error wrapping must be performed through the `%w` syntax. You can see that innerError error is wrapped twice through the `middleFunc()` and `outerFunc()` functions.
* Lines 54~57: Wrapped errors are unwrapped one by one using the `errors.Unwrap()` function and output.
* Lines 60~70: Wrapped errors are compared using the `errors.Is()` function. Since the innerError error exists inside the error of the `outerFunc()` function, the result of line 61 becomes True. On the other hand, since the myError error does not exist inside the error of the `outerFunc()` function, the result of line 66 becomes False.
* Lines 73~85: Assertion is performed on the outerErr error using the `errors.As()` function. Since the innerError error exists inside the error of the `outerFunc()` function, the result of line 75 becomes True. On the other hand, since the myError error does not exist inside the error of the `outerFunc()` function, the result of line 78 becomes False.

### 1.2. with github.com/pkg/errors Package

```golang {caption="[Code 3] Golang Error Wrapping Example with Standard errors Package", linenos=table}
package main
package main

import (
	"fmt"

	"github.com/pkg/errors"
)

var (
	innerError = &innerErr{Msg: "innerMsg"}
	myError    = &myErr{Msg: "myMsg"}
)

// Custom errors
type innerErr struct {
	Msg string
}

func (i *innerErr) Error() string {
	return "innerError"
}

type myErr struct {
	Msg string
}

func (i *myErr) Error() string {
	return "myError"
}

// Functions
func innerFunc() error {
	return innerError
}

func middleFunc() error {
	if err := innerFunc(); err != nil {
		return errors.Wrap(err, "middleError")
	}
	return nil
}

func outerFunc() error {
	if err := middleFunc(); err != nil {
		return errors.Wrap(err, "outerError")
	}
	return nil
}

func main() {
	// Get a wrapped error
	outerErr := outerFunc()

	// Cause
	fmt.Printf("\n--- Cause ---\n")
	fmt.Printf("cause: %v\n", errors.Cause(outerErr))

	// Stack
	fmt.Printf("\n--- Stack ---\n")
	fmt.Printf("%+v\n", outerErr)

	// Is (Compare)
	fmt.Printf("\n--- Is ---\n")
	if errors.Is(outerErr, innerError) {
		fmt.Printf("innerError true\n") // Print
	} else {
		fmt.Printf("innerError false\n")
	}
	if errors.Is(outerErr, myError) {
		fmt.Printf("myError true\n")
	} else {
		fmt.Printf("myError false\n") // Print
	}

	// As (Assertion, Type Casting)
	fmt.Printf("\n--- As ---\n")
	var iErr *innerErr
	if errors.As(outerErr, &iErr) {
		fmt.Printf("innerError true: %v\n", iErr.Msg) // Print
	} else {
		fmt.Printf("innerError false\n")
	}
	var mErr *myErr
	if errors.As(outerErr, &mErr) {
		fmt.Printf("myError true: %v\n", mErr.Msg)
	} else {
		fmt.Printf("myError false\n") // Print
	}
}
```

```shell {caption="[shell 3] Code 3 Output"}
$ go run main.go
--- Cause ---
cause: innerError

--- Stack Trace ---
innerError
middleError
main.middleFunc
        /root/test/go_profile_http/main.go:38
main.outerFunc
        /root/test/go_profile_http/main.go:44
main.main
        /root/test/go_profile_http/main.go:52
runtime.main
        /usr/local/go/src/runtime/proc.go:250
runtime.goexit
        /usr/local/go/src/runtime/asm_amd64.s:1571
outerError
main.outerFunc
        /root/test/go_profile_http/main.go:45
main.main
        /root/test/go_profile_http/main.go:52
runtime.main
        /usr/local/go/src/runtime/proc.go:250
runtime.goexit
        /usr/local/go/src/runtime/asm_amd64.s:1571

--- Is ---
innerError true
myError false

--- As ---
innerError true: innerMsg
myError false
```

When using standard packages for error wrapping in Golang, the disadvantage is that it is difficult to identify where in the code the error occurred. This disadvantage can be overcome by using the github.com/pkg/errors package. [Code 3] and [shell 3] show examples of using error wrapping using the github.com/pkg/errors package. There is not much difference in usability from standard packages, but there are slight differences. When using the github.com/pkg/errors package, stack trace output is possible, so it is easy to identify where in the code the error occurred.

* Lines 38, 45: Wrapping is performed through the `github.com/pkg/errors.Wrap()` function. There is no need to use the fmt package for wrapping.
* Line 56: The github.com/pkg/errors package does not provide a function to unwrap wrapped errors one by one. Instead, it provides a `Cause()` function that returns the error that exists innermost. Note that the `github.com/pkg/errors.Unwrap()` function exists, but it is a function that unwraps errors wrapped using the fmt package, not errors wrapped through `github.com/pkg/errors.Wrap()`.
* Line 60: When outputting wrapped errors using the `fmt.Printf()` function along with the `%+v` syntax, the stack trace is also output.

## 2. References

* [https://adrianlarion.com/golang-error-handling-demystified-errors-is-errors-as-errors-unwrap-custom-errors-and-more/](https://adrianlarion.com/golang-error-handling-demystified-errors-is-errors-as-errors-unwrap-custom-errors-and-more/)
* [https://earthly.dev/blog/golang-errors/](https://earthly.dev/blog/golang-errors/)
* [https://gosamples.dev/check-error-type/](https://gosamples.dev/check-error-type/)
* [https://stackoverflow.com/questions/39121172/how-to-compare-go-errors](https://stackoverflow.com/questions/39121172/how-to-compare-go-errors)
* [https://www.popit.kr/golang-error-stack-trace%EC%99%80-%EB%A1%9C%EA%B9%85/](https://www.popit.kr/golang-error-stack-trace%EC%99%80-%EB%A1%9C%EA%B9%85/)
* [https://dev-yakuza.posstree.com/ko/golang/error-handling/](https://dev-yakuza.posstree.com/ko/golang/error-handling/)
* [https://github.com/pkg/errors/issues/223](https://github.com/pkg/errors/issues/223)


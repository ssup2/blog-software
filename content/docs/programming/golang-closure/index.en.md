---
title: Golang Closure
---

This document analyzes Golang closure techniques.

## 1. Golang Closure

Golang also provides closure functionality, just like Javascript. Closure is a technique that **allows functions to have state by objectifying functions**.

```golang {caption="[Code 1] Golang Closure", linenos=table}
package main

import (
    "fmt"
)

func nextFunc(i int) func() int {
	j := 0
	return func() int {
		j++
		return i + j
	}
}

func main() {
	next10 := nextFunc(10)
	fmt.Println(next10()) // 11
	fmt.Println(next10()) // 12
	fmt.Println(next10()) // 13

	next20 := nextFunc(20)
	fmt.Println(next20()) // 21
	fmt.Println(next20()) // 22
	fmt.Println(next20()) // 23
}
```

[Code 1] shows a Golang closure example. The `nextFunc()` function returns a function that adds the `i` parameter it received and a local variable `j` that keeps increasing by 1. This is a function that cannot work in general languages that do not support closures. This is because the `i` parameter and `j` local variable stored on the stack are released the moment the `nextFunc()` function ends, so they cannot be used in the function returned by `nextFunc()`.

However, since Golang supports closures, a closure is formed when the `nextFunc()` function ends, and the `i` parameter and `j` local variable are stored in the formed closure. Here, forming a closure means copying variables stored on the stack to the **heap** and storing and managing them. Therefore, the `i` parameter and `j` local variable are also stored on the heap. Therefore, the function returned by the `nextFunc()` function operates through variables stored in the closure.

In [Code 1], the next10 and next20 variables each store functions returned by the function nextFunc(), so separate closures are formed for each. They then operate using variables stored in each closure. The closure of the next10 variable has `j = 0, i = 10` stored. Since the value of j increases each time the next10 variable is called, the values `11, 12, 13` are output. The closure of the next20 variable has `j = 0, i = 20` stored. Since the value of j increases each time the next20 variable is called, the values `21, 22, 23` are output.

```golang {caption="[Code 2] Golang Closure to Replace Global Variables", linenos=table}
package main

import "fmt"

func arryFunc() func() []int {
	arry := []int{1, 2, 3, 4, 5}
	return func() []int {
		return arry
	}
}

func main() {
	arry := arryFunc()
	fmt.Println(arry()) // 1,2,3,4,5
}
```

[Code 2] shows how to replace global variables using closures. By storing variables in closures, you can reduce the use of global variables. [Code 2] shows an example of allocating and using an integer slice in the closure of the `arrayFunc()` function.

## 2. References

* [http://golang.site/go/article/11-Go-%ED%81%B4%EB%A1%9C%EC%A0%80](http://golang.site/go/article/11-Go-%ED%81%B4%EB%A1%9C%EC%A0%80)
* [https://medium.com/code-zen/why-gos-closure-can-be-dangerous-f3e5ad0b9fce](https://medium.com/code-zen/why-gos-closure-can-be-dangerous-f3e5ad0b9fce)
* [https://hwan-shell.tistory.com/339](https://hwan-shell.tistory.com/339)


---
title: Golang Receiver
---

This document summarizes Golang Receivers.

## 1. Golang Receiver

```go {caption="[Code 1] Golang Receiver Example", linenos=table}
type Point struct {
   x,y int
}

// Value Receiver
func (p Point) addValue(n int) {
   p.x += n
   p.y += n
}

// Pointer Receiver
func (p *Point) addPointer(n int) {
   p.x += n
   p.y += n
}

func main()  {
   p := Point{3,4}

   p.addValue(10)
   fmt.Println(p) // {3, 4}

   p.addPointer(10)
   fmt.Println(p) // {13, 14}
}
```

A Receiver is syntax used to create Methods for Structs. [Code 1] shows an example of a Golang Receiver. Functions with Receivers are considered Methods of that Struct, and can access the Struct's variables and Methods within the function.

Receivers include **Value Receiver** and **Pointer Receiver**. Value Receiver passes the Struct by Call-by-value, while Pointer Receiver passes it by Call-by-reference. Therefore, even if you change a Struct's variables using the Receiver in a function that uses Value Receiver, the Struct's variables are not changed. Conversely, when using Pointer Receiver, if you change Struct variables using the Receiver, the Struct's variables are also changed.

In [Code 1], you can see that even if you add 10 using the `addValue()` function that uses Value Receiver, the Point struct's Value does not change. Conversely, if you add 10 using the `addPointer()` function, you can see that the Point struct's Value changes.

## 2. References

* [https://kamang-it.tistory.com/entry/Go15%EB%A9%94%EC%86%8C%EB%93%9CMethod%EC%99%80-%EB%A6%AC%EC%8B%9C%EB%B2%84Receiver](https://kamang-it.tistory.com/entry/Go15%EB%A9%94%EC%86%8C%EB%93%9CMethod%EC%99%80-%EB%A6%AC%EC%8B%9C%EB%B2%84Receiver)


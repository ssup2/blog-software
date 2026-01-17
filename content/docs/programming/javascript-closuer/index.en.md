---
title: JavaScript Closure
---

This document analyzes JavaScript Closures.

## 1. JavaScript Closure

Closure is a technique that makes functions have state by **objectifying functions**. It is called Closure because the space where function state is stored is a space that absolutely cannot be accessed from outside. Closure is generally a technique supported in functional languages, but JavaScript also supports Closure.

```javascript {caption="[Code 1] JavaScript Closure", linenos=table}
function outerFunc(i) {
    var j = 0;
    var innerFunc = function () {
        j++;
        return i + j;
    };
    return innerFunc;
}
  
var next10 = outerFunc(10);
console.log(next10()); // 11
console.log(next10()); // 12
console.log(next10()); // 13

var next20 = outerFunc(20);
console.log(next20()); // 21
console.log(next20()); // 22
console.log(next20()); // 23
```

[Code 1] shows a JavaScript Closure example. The function `outerFunc()` returns an `innerFunc()` function that adds the `i` Parameter it received and a local variable `j` that keeps increasing by 1. This is a function that cannot work in general languages that do not support Closure. This is because the `i` Parameter and `j` local variable stored on the Stack are released the moment the `outerFunc()` function ends, so they cannot be used in the `innerFunc()` function.

However, since JavaScript supports Closure, when the `innerFunc()` function is objectified along with the end of the `outerFunc()` function, Closure is formed and the `i` Parameter and `j` local variable are stored in the Closure. Here, forming Closure means copying variables stored on the Stack to the **Heap** and storing and managing them. Therefore, the `i` Parameter and `j` local variable are also stored on the Heap. And the objectified `innerFunc()` function operates using the `i` Parameter and `j` local variable stored in the Closure (Heap).

In [Code 1], the `next10` and `next20` variables store the function `innerFunc()` objectified by the function `outerFunc()`. Since there are 2 objectified `innerFunc` functions, 2 Closures are formed. The Closure of the `next10` variable stores the values `j = 0, i = 10`. Since the value of `j` increases each time the `next10` variable is called, the values `11, 12, 13` are output. The Closure of the `next20` variable stores the values `j = 0, i = 20`. Since the value of the `j` variable increases each time the `next20` variable is called, the values `21, 22, 23` are output.

Through [Code 1], you can see that Closure can also be used when **information hiding** is needed. In [Code 1], you can see that the `next10` and `next20` variables storing the objectified function `innerFunc()` only use values stored in the Closure, and do not explicitly access values stored in the Closure.

```javascript {caption="[Code 2] JavaScript Shared Closure", linenos=table}
function outerFunc() {
    var funcs = [];

    for (var i = 0; i < 5; i++) {
      funcs[i] = function () {
        return i;
      };
    }

    return funcs;
}

var innerFuncs = outerFunc();
for (var j = 0; j < innerFuncs.length; j++) {
  console.log(innerFuncs[j]()); // 5, 5, 5, 5, 5
}
```

Since Closure is a space that cannot be accessed from outside, you might think that Closure cannot be shared. However, Closure can be shared by multiple objectified functions. [Code 2] shows an example of shared Closure. The `outerFunc()` function returns 5 functions that return a local variable `i` that increases by 1.

The `innerFuncs` variable stores 5 functions objectified through the `outerFunc()` function. Then the functions stored in the `innerFuncs` variable are called one by one in order. You might expect it to output `1, 2, 3, 4, 5` because the local variable `i` was used for function objectification while increasing by 1, but it actually outputs `5, 5, 5, 5, 5`. Since the 5 objectified functions share one Closure, all 5 objectified functions use the same local variable `i`. When the 5 objectified functions are executed, the local variable `i` stored in the Closure has become 5 after performing the for loop, so 5 is output 5 times.

## 2. References

* [https://developer.mozilla.org/ko/docs/Web/JavaScript/Guide/Closures](https://developer.mozilla.org/ko/docs/Web/JavaScript/Guide/Closures)
* [https://hyunseob.github.io/2016/08/30/javascript-closure/](https://hyunseob.github.io/2016/08/30/javascript-closure/)
* [https://poiemaweb.com/js-closure](https://poiemaweb.com/js-closure)
* [https://www.w3schools.com/js/js_function_closures.asp](https://www.w3schools.com/js/js_function_closures.asp)
* [https://stackoverflow.com/questions/750486/javascript-closure-inside-loops-simple-practical-example](https://stackoverflow.com/questions/750486/javascript-closure-inside-loops-simple-practical-example)
* [https://stackoverflow.com/questions/16959342/javascript-closures-on-heap-or-stack](https://stackoverflow.com/questions/16959342/javascript-closures-on-heap-or-stack)


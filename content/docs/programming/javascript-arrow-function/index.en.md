---
title: JavaScript Arrow Function
---

This document summarizes JavaScript Arrow Functions.

## 1. Arrow Function

```javascript {caption="[Code 1] JavaScript Arrow Function", linenos=table}
{% highlight javascript %}
// Parameter
() => { ... }      // No parameter
x => { ... }       // One parameter
(x, y) => { ... }  // Multi parameters

// Body
(x, y) => { return x + y }  // Single line body
(x, y) => x + y             // Single line body without parentheses and return
(x, y) => {                 // Multi lines body
  z = x + y
  return z + z;
};

// Call
((x, y) => x + y)(10, 20)      // Define and call
const adder = (x, y) => x + y; // Define, assign and call
adder(10, 20)
```

Arrow Function is syntax that allows you to define and use anonymous functions concisely. It is syntax defined in JavaScript ES6. You can easily put Logic into JavaScript Objects and use them with Arrow Functions. [Code 1] shows how to define and call Arrow Functions.

### 1.1. this

```javascript {caption="[Code 2] this with regular function and arrow function", linenos=table}
// Regular function
var regularObject = {
  value: "regular",
  callFunction: function() {
    (function() {console.log(this)})()
  }
}
regularObject.callFunction()
// Print windows object

// Arrow Function
var arrowObject = {
  value: "arrow",
  callFunction: function() {
    (() => console.log(this))()
  }
}
arrowObject.callFunction()
// Print arrow ojbect
```

`this` inside regular functions and `this` inside Arrow functions mean different values. [Code 2] is Code that outputs `this` in regular functions and `this` in Arrow functions to see what value `this` represents. Inside the `callFunction()` function of regularObject, it outputs `this` information using a regular function. Inside the `callFunction()` function of arrowObject, it outputs `this` information using an Arrow function.

`this` in regular functions stores information about the Object that called the function. Therefore, `this` output through the `callFuncton()` function of regularObject outputs information about the Window Object that calls the `callFuncton()` function. On the other hand, `this` in Arrow functions stores information about the Object that owns the function. Therefore, `this` output through the `callFuncton()` function of arrowObject outputs information about arrowObject that owns the `callFuncton()` function.

## 2. References

* [https://poiemaweb.com/es6-arrow-function](https://poiemaweb.com/es6-arrow-function)
* [https://www.w3schools.com/js/js_arrow_function.asp](https://www.w3schools.com/js/js_arrow_function.asp)


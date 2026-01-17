---
title: Golang Context
---

This document analyzes Golang Context.

## 1. Golang Context Type

Golang's Context is a variable used to store context that must be maintained while processing a single request passed from a client. It is used to store context that must be shared within a single request (Request-Scope), not context that must be maintained between requests. Through Context, you can obtain storage space for values that must be maintained during a request, and easily implement cancellation signal transmission and deadline functionality.

### 1.1. Declaration and Passing

```golang {caption="[Code 1] Context Declaration and Passing Example", linenos=table}
package main

import (
    "context"
    "fmt"
)

func function(ctx context, n int) {
...
}

func main() {
    ctx := context.Background()
    function(ctx, 0)
}
```

[Code 1] shows how to declare a Context object and pass it to a function. Context objects are obtained through the `context.Background()` function. The Context object obtained through Context.Background() is empty with no values. In Golang, it is recommended to pass Context objects as function parameters themselves, not by including them in structs.

### 1.2. Value Storage

```golang {caption="[Code 2] Context Value Storage Example", linenos=table}
package main

import (
    "context"
    "fmt"
)

func function(ctx context.Context, k var key string) {
    // Print key and value
    fmt.Printf("key:%s, value:%s\n", key, ctx.Value(key))
}

func main() {
    // Set key, value
    key := "key"
    value := "value"

    // Init context with key, value
    ctx := context.Background()
    ctxValue := context.WithValue(ctx, key, value)

    // Call function
    function(ctxValue, key)
}
```

```shell {caption="[Shell 1] Context Value Storage Example Output"}
key:key, value:value
```

Context objects provide space for storing Key-Value based values. [Code 2] is an example that stores Key and Value in Context and then outputs the stored Key and Value in a function. Once a Context object is created, the values in the object cannot be changed. You must create a new Context object based on the contents of the existing Context object and use it. Because of this characteristic, the context package provides `WithXXXX()` functions. `WithXXX()` functions receive a Context object and return a new Context object with the necessary values set.

In [Code 2], you can see that a new Context object with Key and Value set is created through the `WithValue()` function, and then passed as a parameter to the `function()` function. When [Code 2] is executed, it outputs the key and value strings as shown in [Shell 1].

### 1.3. Cancellation Signal

```golang {caption="[Code 3] Cancellation Signal Transmission Example Using Context", linenos=table}
package main

import (
    "context"
    "fmt"
    "time"
)

func function(ctx context.Context) {
    n := 1
    go func() {
        for {
            select {
            // Get cancellation signal and exit goroutine 
            case <-ctx.Done():
                fmt.Printf("err:%s\n", ctx.Err())
                return

            // Increase and Print n
            default:
                fmt.Printf("n:%d\n", n)
                time.Sleep(1 * time.Second)
                n++
            }
        }
    }()
}

func main() {
    // Init context with Cancellation
    ctx := context.Background()
    ctxCancel, cancel := context.WithCancel(ctx)

    // Call function
    function(ctxCancel)

    // Sleep and call cancel()
    go func() {
        time.Sleep(5 * time.Second)
        cancel()
    }()

    // Sleep to wait cancel goroutine
    time.Sleep(10 * time.Second)
}
```

```shell {caption="[Shell 2] Cancellation Signal Transmission Example Output Using Context"}
n:1
n:2
n:3
n:4
n:5
err:context canceled
```

You can send cancellation signals using Context objects. [Code 3] is an example of sending cancellation signals using Context objects. Through the `WithCancel()` function, you get a new Context object configured to receive cancellation signals and a `cancel()` function that sends cancellation signals to that Context object. You can get a channel through which cancellation signals are delivered through the `Done()` function of the obtained Context object. Here, a cancellation signal does not mean that some value is delivered through a channel, but rather that the channel is closed.

[Shell 2] shows the output when [Code 3] is executed. In [Code 3], the Main function calls the `cancel()` function after 5 seconds. The Goroutine created by the `function()` function outputs variable n 5 times at 1-second intervals for 5 seconds and then terminates. The `Err()` function of the Context object returns an Error object that tells why the channel delivered through the `Done()` function was closed. In [Shell 2], you can see that it also outputs that the Context object was canceled (the `cancel()` function was called) and the channel was closed.

### 1.4. Deadline, Timeout

```golang {caption="[Code 4] Deadline Example Using Context", linenos=table}
package main

import (
    "context"
    "fmt"
    "time"
)

func function(ctx context.Context) {
    n := 1
    go func() {
        for {
            select {
            // Get cancellation signal and exit goroutine 
            case <-ctx.Done():
                fmt.Printf("err:%s\n", ctx.Err())
                return

            // Increase and Print n
            default:
                fmt.Printf("n:%d\n", n)
                time.Sleep(1 * time.Second)
                n++
            }
        }
    }()
}

func main() {
    // Set deadline
    deadline := time.Now().Add(5 * time.Second)

    // Init context with deadline
    ctx := context.Background()
    ctxDeadline, cancel := context.WithDeadline(ctx, deadline)

    // Call function
    function(ctxDeadline)

    // Sleep to wait deadline
    time.Sleep(10 * time.Second)
    cancel() // Although not required, it is recommended to call cancel()
}
```

```shell {caption="[Shell 3] Request Cancellation Code Output Using Context"}
n:1
n:2
n:3
n:4
n:5
```

You can easily implement deadline functionality using Context objects. [Code 4] is an example of implementing a deadline using Context objects. Through the `WithDeadline()` function, you get a new Context object configured to receive deadline expiration signals and cancellation signals, and a `cancel()` function that sends cancellation signals to that Context object.

You can get a channel through which deadline expiration signals or cancellation signals are delivered through the `Done()` function of the obtained Context object. Here, a deadline expiration signal or cancellation signal does not mean that some value is delivered through a channel, but rather that the channel is closed. When the deadline expires, the channel obtained through the `Done()` function is closed even if a separate `cancel()` function is not called. Or, even if the deadline is not imminent, you can close the channel obtained through the `Done()` function by calling the `cancel()` function.

[Shell 3] shows the output when [Code 4] is executed. In [Code 4], the deadline is set to 5 seconds after the current time. Therefore, the Goroutine created by the `function()` function outputs variable n 5 times at 1-second intervals for 5 seconds and then terminates. The `cancel()` in the `main()` function does not need to be called, but Golang recommends calling the `cancel()` function at an appropriate time for various situations. You can also see that it outputs that the Context object's deadline expired and the channel was closed through the Context object's `Err()` function.

```golang {caption="[Code 5] Timeout Example Using Context", linenos=table}
package main

import (
    "context"
    "fmt"
    "time"
)

func function(ctx context.Context) {
    n := 1
    go func() {
        for {
            select {
            // Get cancellation signal and exit goroutine 
            case <-ctx.Done():
                fmt.Printf("err:%s\n", ctx.Err())
                return

            // Increase and Print n
            default:
                fmt.Printf("n:%d\n", n)
                time.Sleep(1 * time.Second)
                n++
            }
        }
    }()
}

func main() {
    // Set timeout
    timeout := 5 * time.Second

    // Init context with timeout
    ctx := context.Background()
    ctxDeadline, cancel := context.WithTimeout(ctx, timeout)

    // Call function
    function(ctxDeadline)

    // Sleep to wait timeout
    time.Sleep(10 * time.Second)
    cancel() // Although not required, it is recommended to call cancel()
}
```

Context also provides timeout functionality using deadline functionality. [Code 5] is an example of implementing a timeout using Context objects. Using the `WithTimeout()` function, you get a new Context object configured to receive timeout expiration signals and cancellation signals, and a cancel() function that sends cancellation signals to that Context object. `WithTimeout(ctx Context, timeout time.Duration)` is equivalent to `WithDeadline(ctx Context, time.Now().Add(timeout))`. Therefore, [Code 5] performs the same operation as [Code 4].

## 2. Context Example

```golang {caption="[Code 6] HTTP Server Example Using Context", linenos=table}
package main

import (
    "fmt"
    "net/http"
    "time"
)

func hello(w http.ResponseWriter, req *http.Request) {
    // Get context from request and set Request ID
    ctx := context.WithValue(req.Context(), "requestID", req.Header.Get("X-Request-Id"))

    select {
    // Write response
    case <-time.After(5 * time.Second):
        fmt.Fprintf(w, "hello\n")
    // Process error
    case <-ctx.Done():   
        err := ctx.Err()
        fmt.Printf("requestID:%s err:%s", ctx.Value("requestID"), err)
        http.Error(w, err.Error(), http.StatusInternalServerError)
    }
}

func main() {
    // Set HTTP handler
    http.HandleFunc("/hello", hello)

    // Serve
    http.ListenAndServe(":8080", nil)
}
```

[Code 6] shows an example of an HTTP server using Context. Since Context objects are only used during the process of processing a single client's request, Context objects are generally declared and initialized at the very top of HTTP request handlers. The http.Request object returns a Context object that can receive cancellation signals through the `Context()` function. If the client closes the connection first, the Context object receives a cancellation signal.

In [Code 6], you can see that the http.Request object receives a Context object through the `Context()` function at the first part of the HTTP handler `hello()` function, and then stores the value of the "X-Request-Id" HTTP header in the received Context object. The `hello()` function waits 5 seconds after receiving a client request and then returns the "hello" string. However, if the client closes the connection before 5 seconds, it logs an error and stops processing the request.

## 3. References

* [https://golang.org/pkg/context/](https://golang.org/pkg/context/)
* [https://www.popit.kr/go%EC%96%B8%EC%96%B4%EC%97%90%EC%84%9C-context-%EC%82%AC%EC%9A%A9%ED%95%98%EA%B8%B0/](https://www.popit.kr/go%EC%96%B8%EC%96%B4%EC%97%90%EC%84%9C-context-%EC%82%AC%EC%9A%A9%ED%95%98%EA%B8%B0/)
* [https://devjin-blog.com/golang-context/](https://devjin-blog.com/golang-context/)
* [https://gobyexample.com/context](https://gobyexample.com/context)


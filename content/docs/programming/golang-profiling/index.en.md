---
title: Golang Profiling
---

This document summarizes Golang Profiling techniques.

## 1. Profiling Methods

This document summarizes available Profiling methods in Golang. Through Profiling, you can obtain Resource (CPU, Memory, Mutex, Goroutine, Thread) usage rates by function.

### 1.1. net/http/pprof Package

```go {caption="[Code 1] net/http/pprof Package Example", linenos=table}
package main

import (
    "http"
	_ "net/http/pprof"
    ...
)

func main() {
    // Run http server with 6060 port
	go func() {
		http.ListenAndServe("localhost:6060", nil)
	}()
    ...
}
```

The net/http/pprof Package is a Package used for Profiling Apps that continue to run like Servers. Using the pprof Package, you can easily create HTTP Endpoints in Apps to obtain Profiles. [Code 1] shows how to use the net/http/pprof Package. Initialize the net/http/pprof Package and run the HTTP Server through the http Package.

```go {caption="[Code 2] net/http/pprof init() Function", linenos=table}
func init() {
	http.HandleFunc("/debug/pprof/", Index) // Profile Endpoint for Heap, Block, ThreadCreate, Goroutine, Mutex
	http.HandleFunc("/debug/pprof/cmdline", Cmdline)
	http.HandleFunc("/debug/pprof/profile", Profile) // Profile Endpoint for CPU
	http.HandleFunc("/debug/pprof/symbol", Symbol)
	http.HandleFunc("/debug/pprof/trace", Trace)
}
```

[Code 2] shows the `init()` function called when initializing the net/http/pprof Package. You can see that 5 HTTP Endpoints are registered with the HTTP Server. Although not shown in [Code 2], there are also various Endpoints under the Index Handler to obtain Profiles. You can obtain the following Profiles through "Get" requests to the following Endpoints.

* CPU : http://localhost:6060/debug/pprof/profile
* Memory Heap : http://localhost:6060/debug/pprof/heap
* Block : http://localhost:6060/debug/pprof/block
* Thread Create : http://localhost:6060/debug/pprof/threadcreate
* Goroutine : http://localhost:6060/debug/pprof/goroutine
* Mutex : http://localhost:6060/debug/pprof/mutex

You can set how many seconds to perform Profiling using the **seconds** Query String on all HTTP Endpoints.

* seconds : http://localhost:6060/debug/pprof/profile?seconds=30

```shell {caption="[Shell 1] Get Profile File Example"}
$ curl http://localhost:6060/debug/pprof/profile\?seconds\=30 --output cpu.prof
$ curl http://localhost:6060/debug/pprof/heap\?seconds\=30 --output heap.prof
$ curl http://localhost:6060/debug/pprof/block\?seconds\=30 --output heap.prof
$ curl http://localhost:6060/debug/pprof/threadcreate\?seconds\=30 --output heap.prof
$ curl http://localhost:6060/debug/pprof/goroutine\?seconds\=30 --output heap.prof
$ curl http://localhost:6060/debug/pprof/mutex\?seconds\=30 --output mutex.prof
```

[Shell 1] shows an example of obtaining Profiles using HTTP Endpoints.

### 1.2. runtime/pprof Package

```go {caption="[Code 3] runtime/profile Package Example", linenos=table}
package main

import (
	"flag"
	"log"
	"runtime"
	"runtime/pprof"
)

var cpuprofile = flag.String("cpuprofile", "", "write cpu profile `file`")
var memprofile = flag.String("memprofile", "", "write memory profile to `file`")

func main() {
    flag.Parse()

	// Set CPU profile
    if *cpuprofile != "" {
        f, err := os.Create(*cpuprofile)
        if err != nil {
            log.Fatal("could not create CPU profile: ", err)
        }
        if err := pprof.StartCPUProfile(f); err != nil {
            log.Fatal("could not start CPU profile: ", err)
        }
        defer pprof.StopCPUProfile()
    }

	// Set memory (heap) profile
    if *memprofile != "" {
        f, err := os.Create(*memprofile)
        if err != nil {
            log.Fatal("could not create memory profile: ", err)
        }
        runtime.GC() // Get up-to-date statistics
        if err := pprof.WriteHeapProfile(f); err != nil {
            log.Fatal("could not write memory profile: ", err)
        }
        f.Close()
    }
	...
}
```

The runtime/profile Package is a Package used for Profiling Apps that run once and terminate like CLI (Command Line Interface). [Code 3] shows an example of the runtime/profile Package. The runtime/profile Package can only obtain two Profiles: CPU and Memory Heap. CPU Profile Files are created at the path specified through the cpuprofile Option, and Memory Heap Profiles are created at the path specified through the memprofile Option.

To obtain a CPU Profile, call the `StartCPUProfile()` function at the beginning of Profiling and call the `StopCPUProfile()` function at the end of Profiling. To obtain a Memory Profile, call the `GC()` function and then call the `WriteHeapProfile()` function.

### 1.3. Unit Test

```shell {caption="[Shell 2] Test Profile Example"}
$ go test ./... -cpuprofile cpu.out -memprofile mem.out -blockprofile block.out -mutexprofile mutex.out
```

In Golang, Profiling can also be performed along with Unit Tests. [Shell 2] shows an example of performing Tests along with Profile creation. You can obtain CPU, Memory, Block, and Mutex Profiles. You can see that the path for each Profile is set.

### 1.4. github.com/google/gops Package & gops CLI

```go {caption="[Code 4] github.com/google/gops Package Example", linenos=table}
package main

import (
	"github.com/google/gops/agent"
)

func main() {
    // Run gops agent
	go func() {
		agent.Listen(agent.Options{})
	}()
	...
}
```

```shell {caption="[Shell 3] gops CLI Example"}
$ gops
23469 23364 gopls  go1.18.1 /root/go/bin/gopls
23846 23395 go     go1.18.1 /usr/local/go/bin/go
23968 23846 main   go1.18.1 /tmp/go-build306237982/b001/exe/main
24262 23995 gops   go1.18.1 /root/go/bin/gops

$ gops pprof-cpu 23968
Profiling CPU now, will take 30 secs...gops
Profiling CPU now, will take 30 secs...
Profile dump saved to: /tmp/cpu_profile2976012992
Binary file saved to: /tmp/binary3401790069
File: binary3401790069
Type: cpu
Time: Jun 12, 2022 at 11:44pm (KST)
Duration: 30.18s, Total samples = 85.70s (283.97%)
Entering interactive mode (type "help" for commands, "o" for options)
(pprof) 

$ gops pprof-heap 23968
Profile dump saved to: /tmp/heap_profile2558761742
Binary file saved to: /tmp/binary2141405164
File: binary2141405164
Type: inuse_space
Time: Jun 12, 2022 at 11:48pm (KST)
Entering interactive mode (type "help" for commands, "o" for options)
(pprof) 
{% endhighlight %}
```

Profiling of Apps that continue to run like Servers can also be performed through the github.com/google/gops Package and gops CLI. Only CPU and Memory Heap Profiles can be obtained. [Code 4] shows how to use the github.com/google/gops Package. Start the gops Agent. Then, as shown in [Shell 3], query the PID through the gops command and then acquire CPU and Memory Profiles and run pprof through the gops pprof-cpu and gops pprof-heap commands.

## 2. pprof

Obtained Profiles can be visualized through the [pprof](https://github.com/google/pprof) tool installed along with Golang. If you set the `-http [Port]` Option together, you can access "localhost:[Port]" through a Web Browser to obtain visualized Profiles. It provides visualization in forms such as Top, Graph, Flame Graph, and Peek.

```shell {caption="[Shell 4] Run pprof with CPU profile"}
$ go tool pprof -http :8080 [Profile File]
$ go tool pprof -http :8080 [Profile HTTP Endpoint]
```

[Shell 4] shows how to use pprof. Specify the Profile HTTP Endpoint set through the net/http/pprof Package or the Profile File obtained through the runtime/pprof Package or Tests along with the `-http` Option.

### 2.1. Flat, Cum

```go {caption="[Code 5] Flat, Cum Example", linenos=table}
func OutterFunc() {
	InnerFunc() // step1
	InnerFunc() // step2
	i := 0      // step3
	i++         // step4
}
```

To understand Profiles visualized through pprof, you must know the concepts of **Flat** and **Cum**. [Code 4] shows example Code for explaining Flat and Cum. Flat represents the load of Actions directly performed by a function. Therefore, in [Code 4], the Flat of the `OutterFunc()` function includes only Step3 and Step4. Cum represents the load of all Actions required for a function to execute. Loads caused by calls to other functions are also included in Cum. Therefore, in [Code 5], the Cum of the `OutterFunc()` function includes Step1 ~ Step4.

## 3. Profile Types and Analysis

Profile types and analysis are conducted through the example App below. Profiles are set to be exposed through port 6060 through the net/http/pprof Package, and various functions have been developed to apply load.

* Example App : [https://github.com/ssup2/golang-profiling-example](https://github.com/ssup2/golang-profiling-example)

### 3.1. CPU

```go {caption="[Code 6] CPU Profiling Example Code", linenos=table}
package cpu

func IncreaseInt() {
	i := 0
	for {
		i = increase1000(i)
		i = increase2000(i)
	}
}

func IncreaseIntGoroutine() {
	go func() {
		i := 0
		for {
			i = increase1000(i)
			i = increase2000(i)
		}
	}()
}

func increase1000(n int) int {
	for n := 0; n < 1000; n++ {
		n = n + 1
	}
	return n
}

func increase2000(n int) int {
	for n := 0; n < 1000; n++ {
		n = n + 1
	}
	return n
}
```

```shell {caption="[Shell 5] Run pprof with CPU profile for 30 seconds"}
$ go tool pprof -http :8080 http://localhost:6060/debug/pprof/profile\?seconds\=30
```

You can obtain CPU usage rates by function through CPU Profiles. [Code 6] shows example Code for CPU Profiling, and [Shell 5] shows obtaining a 30-second CPU Profile through the Example App and then running pprof.

{{< figure caption="[Figure 1] CPU Profile Top" src="images/profile-cpu-top.png" width="800px" >}}

[Figure 1] shows functions with high CPU usage in order. You can see that the `Increase2000()` function has 2 times higher Cum than the `Increase1000()` function, as it performs 2 times more increment operations. Since both the `Increase2000()` and `Increase1000()` functions do not call functions internally, you can see that each function's Flat and Cum are the same. On the other hand, functions executed inside the `IncreaseInt()` function and `IncreaseIntGoroutine()` function have very low Flat but high Cum because Goroutines do not perform separate operations and depend on the `Increase2000()` and `Increase1000()` functions.

Since a 30-second CPU Profile was obtained, functions executed inside the `IncreaseInt()` function and `IncreaseIntGoroutine()` function are each performed for 30 seconds in separate Goroutines during Profiling. Therefore, Goroutines are performed for a total of 60 seconds, and you can see that the total Cum of the `Increase2000()` and `Increase1000()` functions is approximately 60 seconds.

{{< figure caption="[Figure 2] CPU Profile Graph" src="images/profile-cpu-graph.png" width="750px" >}}

[Figure 2] shows CPU usage rates and dependencies between functions.

### 3.2. Memory Heap

### 3.3. Block

### 3.4. Thread Create

### 3.5. Goroutine

### 3.6. Mutex

## 4. References

* [https://github.com/DataDog/go-profiler-notes/blob/main/guide/README.md](https://github.com/DataDog/go-profiler-notes/blob/main/guide/README.md)
* [https://hackernoon.com/go-the-complete-guide-to-profiling-your-code-h51r3waz](https://hackernoon.com/go-the-complete-guide-to-profiling-your-code-h51r3waz)
* [https://go.dev/doc/diagnostics](https://go.dev/doc/diagnostics)
* [https://pkg.go.dev/net/http/pprof](https://pkg.go.dev/net/http/pprof)
* [https://github.com/google/pprof](https://github.com/google/pprof)
* [https://github.com/google/gops](https://github.com/google/gops)
* [https://jvns.ca/blog/2017/09/24/profiling-go-with-pprof/](https://jvns.ca/blog/2017/09/24/profiling-go-with-pprof/)
* [https://medium.com/a-journey-with-go/go-how-does-gops-interact-with-the-runtime-778d7f9d7c18](https://medium.com/a-journey-with-go/go-how-does-gops-interact-with-the-runtime-778d7f9d7c18)
* [https://riptutorial.com/go/example/25406/basic-cpu-and-memory-profiling](https://riptutorial.com/go/example/25406/basic-cpu-and-memory-profiling)
* [https://stackoverflow.com/questions/32571396/pprof-and-golang-how-to-interpret-a-results](https://stackoverflow.com/questions/32571396/pprof-and-golang-how-to-interpret-a-results)


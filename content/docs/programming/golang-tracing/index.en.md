---
title: Golang Tracing
---

This document summarizes Golang Tracing techniques.

## 1. Tracing Methods

This document summarizes available Tracing methods in Golang. Through Tracing, you can understand the state of Threads, Goroutines, Heap, Garbage Collector, etc. over time.

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

The `net/http/pprof` Package is a Package used for Tracing Apps that continue to run like Servers. Using the `net/http/pprof` Package, you can easily create HTTP Endpoints in Apps to obtain Traces. [Code 1] shows how to use the `net/http/pprof` Package. Initialize the `net/http/pprof` Package and run the HTTP Server through the `http` Package.

```go {caption="[Code 2] net/http/pprof init() Function", linenos=table}
{% highlight golang linenos %}
func init() {
	http.HandleFunc("/debug/pprof/", Index)
	http.HandleFunc("/debug/pprof/cmdline", Cmdline)
	http.HandleFunc("/debug/pprof/profile", Profile)
	http.HandleFunc("/debug/pprof/symbol", Symbol)
	http.HandleFunc("/debug/pprof/trace", Trace) // Trace Endpoint
}
```

[Code 2] shows the `init()` function called when initializing the `net/http/pprof` Package. You can see that 5 HTTP Endpoints are registered with the HTTP Server. Among them, Traces can be obtained through the `/debug/pprof/trace` Endpoint. You can set how many seconds to perform Tracing using the `seconds` Query String.

* http://localhost:6060/debug/pprof/trace?seconds=30

```shell {caption="[Shell 1] Get Trace File Example"}
$ curl http://localhost:6060/debug/pprof/trace\?seconds\=30 --output trace.out
```

[Shell 1] shows an example of obtaining Traces using HTTP Endpoints.

### 1.2. runtime/trace Package

```go {caption="[Code 3] runtime/trace Package Example", linenos=table}
package main

import (
	"flag"
	"log"
	"os"
	"runtime/trace"
)

var traceFile = flag.String("trace", "", "write trace `file`")

func main() {
	flag.Parse()

	// Set trace file
	if *traceFile != "" {
		f, err := os.Create(*traceFile)
		if err != nil {
			log.Fatal("could not create trace: ", err)
		}
		if err := trace.Start(f); err != nil {
			log.Fatal("could not start trace: ", err)
		}
		defer trace.Stop()
	}

    ...
}
```

The `runtime/trace` Package is a Package used for Tracing Apps that run once and terminate like CLI (Command Line Interface). [Code 3] shows an example of the `runtime/trace` Package. To obtain a Trace, call the `Start()` function at the beginning of Tracing and call the `Stop()` function at the end of Profiling. Traces are created at the path specified through the `trace` Option.

### 1.3. Unit Test

```shell {caption="[Shell 2] Test Profile Example"}
$ go test ./... -trace trace.out 
```

In Golang, Tracing can also be performed along with Unit Tests. [Shell 2] shows an example of performing Tests along with Trace creation. You can see that the Trace path is specified.

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

$ gops trace 23968
Tracing now, will take 5 secs...
Trace dump saved to: /tmp/trace2991957244
2022/06/15 00:05:14 Parsing trace...
2022/06/15 00:05:15 Splitting trace...
2022/06/15 00:05:17 Opening browser. Trace viewer is listening on http://127.0.0.1:42519
```

Tracing of Apps that continue to run like Servers can also be performed through the `github.com/google/gops` Package and `gops` CLI. [Code 4] shows how to use the `github.com/google/gops` Package. You can see that the `gops` Agent is started. Then, as shown in [Shell 3], query the PID through the `gops` command and then acquire Traces and run pprof through the `gops trace` command.

## 2. trace CLI

```shell {caption="[Shell 4] gops CLI Example"}
$ go tool trace trace.out
2022/07/10 23:38:41 Parsing trace...
2022/07/10 23:38:50 Splitting trace...
2022/07/10 23:38:59 Opening browser. Trace viewer is listening on http://127.0.0.1:36181
```

Obtained Profiles can be visualized through the `trace` CLI installed along with Golang. [Shell 4] shows how to use the `trace` CLI. When you run the `trace` CLI, a Web URL is exposed. The App used for Trace extraction used the example Code below.

* Example App : [https://github.com/ssup2/golang-tracing-example](https://github.com/ssup2/golang-tracing-example)

{{< figure caption="[Figure 1] trace CLI Web Trace" src="images/trace-cli-web-trace.png" width="1000px" >}}

[Figure 1] shows the Trace UI screen of the `trace` CLI Web. In the STATS section, from top to bottom, it shows the number of Goroutines, the size of Memory Heap, and the number of Threads. In the PROCS section, from top to bottom, you can see Garbage Collection execution time, Network Blocking time, and System Call execution time performed in each Proc. Proc means a virtual Process managed by the Golang Scheduler, and Goroutines are assigned to Procs and operate.

{{< figure caption="[Figure 2] trace CLI Web Mutex Goroutine" src="images/trace-cli-web-goroutine-mutex01.png" width="1000px" >}}

The `trace` CLI Web can also check state ratios by Goroutine. [Figure 2] shows the results of Mutex Goroutines from the Example App. In addition, the `trace` CLI Web can also obtain Network Blocking, Synchronization Blocking, System Call Block, and Scheduler Latency Profiling results.

## 3. References

* [https://pkg.go.dev/cmd/trace](https://pkg.go.dev/cmd/trace)
* [https://programmer.ink/think/golang-performance-test-trace-planing-goang-trace.html](https://programmer.ink/think/golang-performance-test-trace-planing-goang-trace.html)


---
title: Golang Tracing
---

Golang의 Tracing 기법을 정리한다.

## 1. Tracing 수행 방법

Golang에서 이용 가능한 Tracing 수행 방법을 정리한다. Tracing을 통해서 시간별 Thread, Goroutine, Heap, Garbage Collector등의 상태를 파악할 수 있다.

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

`net/http/pprof` Package는 Server와 같이 계속 동작중인 App의 Tracing을 위해서 이용되는 Package이다. `net/http/pprof` Package를 이용하면 App의 Trace를 얻을 수 있는 HTTP Endpoint를 간단하게 생성할 수 있다. [Code 1]은 `net/http/pprof` Package의 사용 방법을 나타내고 있다. `net/http/pprof` Package를 초기화 하고, `http` Package를 통해서 HTTP Server를 구동하면 된다.

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

[Code 2]는 `net/http/pprof` Package 초기화시 호출되는 `init()` 함수를 나타내고 있다. 5개의 HTTP Endpoint를 HTTP Server에 등록하는 것을 확인할 수 있다. 이중에 `/debug/pprof/trace` Endpoint를 통해서 Trace를 얻을 수 있다. `seconds` Query String을 이용하면 몇 초 동안 Tracing을 수행할지 설정할 수 있다.

* http://localhost:6060/debug/pprof/trace?seconds=30

```shell {caption="[Shell 1] Get Trace File Example"}
$ curl http://localhost:6060/debug/pprof/trace\?seconds\=30 --output trace.out
```

[Shell 1]은 HTTP Endpoint를 활용하여 Trace를 얻는 예제를 나타내고 있다.

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

`runtime/trace` Package는 CLI (Command Line Interface)와 같이 한번 실행이되고 종료되는 App의 Tracing을 위해서 이용되는 Package이다. [Code 3]은 `runtime/trace` Package의 예제를 나타내고 있다. Trace를 얻기 위해서는 Tracing의 시작 부분에서 `Start()` 함수를 호출하고, Profile의 끝 부분에서 `Stop()` 함수를 호출하면 된다. Trace는 `trace` Option을 통해서 지정한 경로에 생성된다.

### 1.3. Unit Test

```shell {caption="[Shell 2] Test Profile Example"}
$ go test ./... -trace trace.out 
```

Golang에서는 Unit Test를 수행할때 같이 Tracing 수행도 가능하다. [Shell 2]는 Trace 생성과 함께 Test를 수행하는 예제를 나타내고 있다. Trace의 경로를 지정하는 것을 확인할 수 있다.

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

`github.com/google/gops` Package와 `gops` CLI를 통해서도 Server와 같이 계속 동작중인 App의 Tracing을 수행할 수 있다. [Code 4]는 `github.com/google/gops` Package의 사용법을 나타내고 있다. `gops` Agent를 구동시키는것을 확인할 수 있다. 이후에 [Shell 3]의 내용과 같이 `gops` 명령어를 통해서 PID를 조회한 다음 `gops trace` 명령어를 통해서 Trace 획득 및 pprof를 실행한다.

## 2. trace CLI

```shell {caption="[Shell 4] gops CLI Example"}
$ go tool trace trace.out
2022/07/10 23:38:41 Parsing trace...
2022/07/10 23:38:50 Splitting trace...
2022/07/10 23:38:59 Opening browser. Trace viewer is listening on http://127.0.0.1:36181
```

얻은 Profile은 Golang 설치시 같이 설치되는 `trace` CLI를 통해서 시각화가 가능하다. [Shell 4]는 `trace` CLI의 사용법을 나타내고 있다. `trace` CLI를 실행하면 Web URL이 노출된다. Trace 추출을 위해서 이용한 App은 아래의 예제 Code를 이용하였다.

* Example App : [https://github.com/ssup2/golang-tracing-example](https://github.com/ssup2/golang-tracing-example)

{{< figure caption="[Figure 1] trace CLI Web Trace" src="images/trace-cli-web-trace.png" width="1000px" >}}

[Figure 1]은 `trace` CLI Web의 Trace UI 화면을 나타내고 있다. STATS 항목에서는 위에서 부터 Goroutine의 개수, Memory Heap의 크기, Thread의 개수를 나타내고 있다. PROCS 항목에서는 위에서 부터 Garbage Collection 수행 시간, Network Blocking 시간, 각 Proc에서 수행한 System Call의 수행 시간을 알 수 있다. Proc은 Golang Scheduler에서 관리하는 가상의 Process를 의미하며, Goroutine은 Proc에 할당되어 동작한다.

{{< figure caption="[Figure 2] trace CLI Web Mutex Goroutine" src="images/trace-cli-web-goroutine-mutex01.png" width="1000px" >}}

`trace` CLI Web에서는 각 Goroutine별 상태 비율도 확인할 수 있다. [Figure 2]는 Example App의 Mutex Goroutine의 결과를 나타내고 있다. 이외에 `trace` CLI Web은 Network Blocking, Synchronization Blocking, System Call Block, Scheduler Latency Profiling 결과도 얻을 수 있다.

## 3. 참조

* [https://pkg.go.dev/cmd/trace](https://pkg.go.dev/cmd/trace)
* [https://programmer.ink/think/golang-performance-test-trace-planing-goang-trace.html](https://programmer.ink/think/golang-performance-test-trace-planing-goang-trace.html)
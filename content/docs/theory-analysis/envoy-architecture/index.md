---
title: "Envoy Architecture"
---

## 1. Envoy Architecture

{{< figure caption="[Figure 1] Envoy Architecture" src="images/envoy-architecture.png" width="1100px" >}}

[Figure 1]은 Envoy Architecture를 나타내고 있다. Envoy Architecture는 **libevent**와 **io_uring**을 기반으로 동작하는 **Dispatcher**를 활용하여 **Event Driven Architecture**를 구현하고 있으며, 성능 최적화를 위해서 각 Thread마다 전용 저장소인 **TLS** (Thread Local Storage)를 활용하여 Lock 활용을 최소화하며 동작한다. Thread 관점에서는 **Main Thread**, **Worker Thread**, **Flush Thread**로 구분된다.

### 1.1. Main Thread

Main Thread는 Envoy 초기화 및 Worker Thread의 Control Plane 역할을 수행한다. Dispatcher를 통해서 OS Signal, Timer, Socket, inotify 등의 다양한 Event를 수신하고, 해당 Event를 적절한 Module에 전달하여 처리한다. 각 Module은 상태 저장이 필요한 경우 Main Thread의 TLS에 저장하며, Worker Thread에 Data를 전달이 필요한 경우에도 TLS와 Dispatcher를 통해서 전달한다. Main Thread에서 동작하는 Module은 다음과 같다.

#### 1.1.1. Runtime

**Runtime**은 재시작 없이 동적으로 바꿀수 있는 설정 값인 Feature Flag를 관리하는 역할을 수행한다. Feature Flag는 **Snapshot** 형태로 TLS Slot에 저장되어 이용된다. Feature Flag는 JSON 형태의 파일로 구성하는 **Static Bootstrap** 방식, Directory와 File을 활용하여 계층으로 구성하는 **File System Layout** 방식, `/runtime_modify` Admin Endpoint를 통해서 관리하는 **Admin Console** 방식, xDS중 하나인 RTDS (Runtime Discovery Service)를 활용하는 **Runtime Discovery Service** 방식으로 관리된다.

**Static Bootstrap** 방식을 제외하고는 모두 Envoy 재시작 없이 동적으로 Feature Flag를 변경할 수 있으며, File System Layout 방식을 이용할 경우 파일의 변화를 Dispatcher와 inotify를 통해서 감지하여 Feature Flag를 동적으로 변경한다.

#### 1.1.2. xDS (eXtensible Discovery Service)

xDS (eXtensible Discovery Service)는 Envoy가 Envoy를 관리하는 Control Plane으로부터 필요한 설정 정보를 동적으로 가져오는 역할을 수행한다. xDS는 역할에 따라서 다음과 같은 종류가 존재한다.

* **LDS (Listener Discovery Service)** : Listener의 Port, Listener/Network Filter Chain 설정 정보를 가져온다.
* **RDS (Route Discovery Service)** : HTTP 기반으로 어느 Cluster로 요청을 전달할지 결정하는 HTTP 기반 라우팅 설정 정보를 가져온다.
* **CDS (Cluster Discovery Service)** : Cluster의 정보를 가져온다. 여기서 Cluster는 Endpoint (Upstream Server)의 집합을 의미한다.
* **EDS (Endpoint Discovery Service)** : Cluster의 실제 Endpoint 정보를 가져온다.
* **SDS (Secret Discovery Service)** : TLS 인증서 정보를 가져온다.
* **RTDS (Runtime Discovery Service)** : Runtime Feature Flag 정보를 가져온다.

#### 1.1.3. Listener Manager, Cluster Manager, Secret Manager, Route Config Manager

Listener Manager, Cluster Manager, Secret Manager, Route Config Manager는 xDS를 통해서 가져온 설정 정보를 관리하고, 필요에 따라서 Worker Thread에 **TLS**와 **Dispatcher**를 통해서 전달한다.

* **Listener Manager** : LDS를 통해서 가져온 Listener 및 Listenter/Network Filter Chain 설정 정보를 Worker Thread에 전달하여, Worker Thread가 Listener 설정 및 Listenter/Network Filter Chain을 생성하도록 만든다.
* **Cluster Manager** : CDS, EDS를 통해서 가져온 Cluster, Endpoint의 Worker Thread에 TLS에 설정하여 Network Filter의 Router Filter가 적절한 Upstream으로 요청을 전달하도록 만든다.
* **Secret Manager** : SDS를 통해서 가져온 TLS 인증서 정보를 Worker Thread의 TLS Transport Socket에 전달한다.
* **Route Config Manager** : RDS를 통해서 가져온 Route Config 정보를 HCM (HTTP Connection Manager)에 전달하여, HCM Router Filter가 적절한 Cluster로 요청을 전달하도록 만든다.

#### 1.1.3. Stats Flush

Stats Flush는 Dispatcher와 Timer를 활용하여 주기적으로 깨어나며 Envoy 관련 통계/Metric 정보를 TLS에 저장하고, 설정에 따라서 StatsD Server로 통계/Metric 정보를 전송하는 역할을 수행한다.

#### 1.1.4. Drain Manager

Drain Manager는 Dispatcher를 통해서 SIGTERM Signal을 수신하면, 곧바로 Envoy를 종료하는게 아니라 현재 처리중인 Request를 종료하고 종료 완료 후에 Envoy를 종료하는 역할을 수행한다.

#### 1.1.5. Admin

Admin은 Envoy 관리 및 상태 정보 조회를 위한 Endpoint를 제공하는 역할을 수행한다. 주요 Endpoint는 다음과 같다.

* `/stats` : Envoy 관련 통계/Metric 정보를 조회하는 Endpoint. 내부적으로 Stats Flush Module이 TLS에 저장한 정보를 조회하여 제공한다.
* `/stats/prometheus` : Prometheus Exporter 형태로 Envoy 관련 통계/Metric 정보를 제공한다.
* `/reset_counters` : 통계/Metric 정보를 초기화하는 기능을 제공한다.
* `/clusters` : Cluster 정보를 제공한다.
* `/listeners` : Listener 정보를 제공한다.
* `/memory` : Envoy 메모리 사용 정보를 제공한다.
* `/ready` : Envoy 준비 상태를 제공한다. (Readiness Probe)
* `/runtime` : 현재 Runtime Feature Flag 정보를 제공한다.
* `/runtime_modify` : Runtime Feature Flag를 동적으로 변경하는 Endpoint.
* `/server_info` : Envoy 서버 정보를 제공한다.
* `/config_dump` : Envoy 서버의 전체 설정 정보를 제공한다.
* `/logging` : Logging Level을 변경하는 기능을 제공한다.
* `/drain_listeners` : Listener를 종료하는 기능을 제공한다.
* `/quitquitquit` : Envoy를 종료하는 기능을 제공한다.
* `/cpuprofile` : CPU Profile을 수집하는 기능을 제공한다.
* `/memoryprofile` : Memory Profile을 수집하는 기능을 제공한다.

#### 1.1.6. GuardDog

Main/Worker Thread가 동작하는지 검사하는 역할을 수행한다. GuardDog는 Main/Worker Thread가 동작하지 않는다라고 판단하면 Envoy를 종료하는 역할을 수행한다.

#### 1.1.7. Hot Restart

Hot Restart는 Envoy 재시작시 Downtime 없이 새로운 Envoy 프로세스로 교체하는 기능을 의미한다. 일반적으로 Systemd와 같이 프로세스/Daemon을 관리하는 Component가 필요에 따라서 UDS (Unix Domain Socket)을 통해서 Envoy Hot Restart를 요청한다. Hot Restart는 다음과 같은 과정을 통해서 진행된다.

1. 새로운 Envoy 프로세스를 생성한다.
2. 기존의 Envoy 프로세스의 Listen Socket을 새로운 Envoy 프로세스에서 UDS (Unix Domain Socket)을 통해서 전달한다.
3. 새로운 Envoy 프로세스는 전달받은 Listen Socket을 통해서 Client의 신규 Connection을 수락한다.
4. 기존의 Envoy 프로세스는 Drain Manager를 통해서 현재 처리중인 Request를 종료하고 종료 완료 후에 Envoy를 종료한다.

#### 1.1.8. Access Logger Notification

Access Logger Notification은 Dispatcher와 Timer를 통해서 주기적으로 깨어나 Flush Thread를 깨우는 역할을 수행한다.

### 1.2. Worker Thread

Worker Thread는 **Downstream** (Client)의 요청을 받아 처리 이후에 **Upstream** (Server)로 요청을 전달하는 Thread이다. Main Thread와 유사하게 Dispatcher를 통해서 Socket, Timer Event를 수신하며, 상태 저장이 필요한 경우에 각 Worker Thread마다 가지고 있는 전용 TLS에 저장한다.

하나의 Downstream은 하나의 Worker Thread와 Connection을 맺는다. 반면에 모든 Worker Thread는 모든 Upstream과 Connection을 맺는다. 이러한 이유는 Worker Thread 사이에는 상태 정보를 공유하지 않기 때문에, Downstream이 어떤 Worker Thread와 Connection을 맺더라도 Upstream으로 요청을 전달할 수 있어야 하기 때문이다. 이 의미는 Worker Thread의 개수에 비례하여 Upstream과의 Connection 개수도 증가하는걸 의미하며, 따라서 너무 많은 Worker Thread를 생성하면 Upstream과의 Connection 유지를 위한 Memory 낭비가 발생하게 된다.

[Figure 1]에서는 Downstream A/B가 각기 다른 Worker Thread와 Connnection을 맺고 있으며, 4개의 Worker Thread가 존재하기 때문에 모든 Worker Thread가 Upstream과의 Connection을 유지하기 위해서 Worker Thread의 개수인 4개의 Connection을 유지하고 있는것을 확인할 수 있다. Worker Thread에서 동작하는 Module은 다음과 같다.

#### 1.2.1. Listener

Listener는 TCP/UDP Listening을 수행하여 Downstream의 Connection 수락하고, Connection을 수학하며 생성된 Socket을 Dispatcher에 등록하는 역할을 수행한다. Listener는 각 Worker Thread 마다 별도로 존재하며 `SO_REUSEPORT` Option을 통해서 모든 Listener는 동일한 IP/Port를 Listening 하도록 설정된다. 다수의 Listener가 동시에 Listening 하는 경우에는 Kernel은 임의의 Listener를 선택하여 Connection을 수락하게 된다. 따라서 Client가 어떤 Thread와 Connection을 맺을지는 Envoy가 아니라 Kernel에 의해서 결정된다.

#### 1.2.2. Listener Filter Chain

Listener Filter Chain은 SNI (Server Name Indication)와 같이 Connection의 Metadata를 추출하여 Connection의 추가 정보를 알아내는 역할을 수행한다. 각 Connection 또는 HTTP/2 Stream마다 별도의 Listener Filter Chain 생성된다.

#### 1.2.3. TLS Transport Socket

Listner Filter Chain을 통해서 추출된 Metadata를 이용하여 TLS로 암호화된 Data를 복호화하여 원본 Data로 변환 및 Network Chain Filter로 전달하는 역할을 수행한다. 만약 TLS로 암호화된 Data가 아닌 경우에는 복호화 과정을 거치지 않고 바로 원본 Data를 그대로 Network Chain Filter로 전달한다. 각 Connection 또는 HTTP/2 Stream마다 별도의 TLS Transport Socket이 생성된다.

#### 1.2.4. Network Filter Chain

Network Filter Chain은 복호화된 요청/응답을 변조, Rate Limiting 수행, Circuit Breaking 수행 또는 어느 Upstream으로 요청을 전송할지 결정하는 Routing 등의 역할을 수행한다. 마지막 Network Filter Chain에는 HCM (HTTP Connection Manager)이 존재한다. HCM은 HTTP 관련 Filter Chain을 소유하고 있으며, HTTP/2 Codec을 통해서 HTTP/2 요청/응답을 Encoding/Decoding하는 역할도 수행한다.

### 1.3. TLS (Thread Local Storage)

{{< figure caption="[Figure 2] Envoy TLS (Thread Local Storage)" src="images/envoy-tls.png" width="750px" >}}

[Figure 2]는 Envoy TLS (Thread Local Storage)를 나타내고 있다. Main Thread와 Worker Thread는 자신만의 TLS를 가지고 있으며, Envoy는 TLS를 이용하여 성능 최적화를 위해서 Lock 활용을 최소화하며 동작한다. TLS는 CPP STL의 vector 자료구조를 이용하여 Array 형태로 관리된다. [Figure 2]에서 알수 있는 것처럼 Index별로 용도가 정해져 있으며, Main/Worker Thread의 Index별 용도는 모두 동일하다. 이러한 이유는 Main Thread에서 Index별 용도를 할당하고 초기화한 다음에, Worker Thread도 동일하게 Index별 용도를 할당하고 초기화하기 때문이다.

{{< figure caption="[Figure 3] Envoy Run on All Threads" src="images/envoy-runonallthreads.png" width="900px" >}}

```cpp {caption="[Code 1] runOnAllThreads() Function", linenos=table}
void InstanceImpl::runOnAllThreads(std::function<void()> cb,
                                    std::function<void()> all_threads_complete_cb) {
  ASSERT_IS_MAIN_OR_TEST_THREAD();
  ASSERT(!shutdown_);
  cb();  // Run cb() function on Main Thread

  std::shared_ptr<std::function<void()>> cb_guard(
      new std::function<void()>(cb), [this, all_threads_complete_cb](std::function<void()>* cb) {
        main_thread_dispatcher_->post(all_threads_complete_cb);
        delete cb;
      });

  for (Event::Dispatcher& dispatcher : registered_threads_) {
    dispatcher.post([cb_guard]() -> void { (*cb_guard)(); });
  }
}
```

이러한 TLS 초기화 또는 변경 과정은 일반적으로 `runOnAllThreads()` 함수를 이용한다. [Figure 3]에서는 `runOnAllThreads()` 함수의 동작 과정을 나타내고 있으며, [Code 1]은 실제 `runOnAllThreads()` 함수의 코드를 나타내고 있다. `runOnAllThreads()` 함수는 첫번째 Parameter로 Main/Worker Thread에서 실행되는 `cb` Callback 함수를 받으며, 두번째 Parameter로 모든 Thread에서 `cb` Callback 함수가 수행된 다음에 Main Thread에서 마지막으로 한번만 수행되는 `all_threads_complete_cb` Callback 함수를 받는다. 다음과 같은 순서대로 동작한다.

1. Main Thread에서 먼저 전달 받은 `cb` Callback 함수를 실행한다. `cb` Callback 함수는 내부 로직에 따라서 Main Thread의 TLS를 초기화 또는 변경한다.
2. `cb` Callback 함수를 `cb_guard` Pointer에 저장한다. `cb_guard` Pointer는 `all_threads_complete_cb` Callback 함수를 Main Thread에 Posting 및 `cb` Callback 함수를 제거하는 Lambda를 Deleter로 등록하는 CPP STL의 `shared_ptr` 역할을 수행한다.
3. `cb_guard` Pointer에 저장된 `cb` Callback 함수를 실행하는 Lambda를 모든 Worker Thread에 Posting 한다. 이때 `cb_guard` Pointer는 Worker Thread의 개수만큼 Lambda가 생성되며 복사되어 저장되기 때문에, `cb_guard`의 Reference Count 역시 Worker Thread의 개수만큼 증가하게 된다.
4. Posting된 Worker Thread는 Dispatcher에 의해서 깨어나 `cb_guard` Pointer에 저장된 `cb` Callback 함수를 실행하는 Lambda를 실행하게 된다.
5. 실행이 완료된 Lambda는 종료되며 이때 `cb_guard` Pointer의 Reference Count가 1씩 감소하게 되며, 마지막 Lambda가 종료되면 `cb_guard` Pointer의 Reference Count가 0이 된다.
6. Reference Count가 `0`이 되면 `cb_guard` Pointer에 Deleter로 지정된 `all_threads_complete_cb` Callback 함수를 Main Thread에 Posting하는 Lambda가 실행된다.
7. Posting된 Main Thread에서 `all_threads_complete_cb` Callback 함수를 실행한다.

### 1.4. Flush Thread

Envoy에서는 처리한 요청을 기록하는 **Access Log** 기능을 제공하며, stdout/stderr를 포함하여 다수의 출력 경로(파일)를 설정할 수 있다. Envoy에서는 Access Log의 기록 요청은 Traffic을 실제로 처리하는 Worker Thread에서 발생한다. 하지만 Work Thread에 직접 Access Log를 기록하면 Lock, I/O Blocking이 발생하여 Traffic 처리를 방해하게 된다. Envoy에서는 이러한 이슈를 회피하기 위해서 Flush Thread를 도입하여 이용하고 있다.

Flush Thread는 Access Log를 기록하기 위한 전용 Thread이며, Envoy는 Access Log 기록 과정중에 Lock 구간을 최소화 하기 위해서 다양한 Buffer와 Lock을 활용하며 동작한다. Network Filter Chain에 설정에 의해서 Worker Thread가 Access Log를 기록하기 위해서는 모든 Worker Thread 사이에서 공유되는 **Access Logger**의 Write 함수를 호출한다.

Write 함수는 Access Log를 실제 파일에 기록하지 않고 **Flush Buffer**에 저장만 하고 종료하며, Flush Buffer는 Worker Thread 사이에 공유되는 Buffer이기 때문에 **Write Lock**에 의해서 보호된다. Flush Buffer를 이용하는 이유는 Write 함수에서 직접 Access Log를 남기면 느린 Disk I/O에 의해서 Worker Thread가 Traffic을 처리하는데 지연이 발생하는걸 막기 위해서이다.

Flush Thread는 Main/Worker Thread와 다르게 Dispatcher를 이용하지 않고, Condition Variable을 통해서 깨어나는 방식으로 동작한다. Main Thread에서 Dispatcher와 Timer에 의해서 주기적으로 Flush Thread를 깨우거나, Worker Thread에서 Write 함수를 통해서 Flush Buffer에 Access Log를 기록하다가 Flush Buffer가 가득찬 경우 Flush Thread를 깨운다.

깨어난 Flush Thread는 Access Logger를 통해서 Flush Buffer에 저장된 Access Log를 바로 기록하지 않고 **About to write Buffer**에 한번더 임시 저장한다. 이러한 이유는 Access Logger에서 바로 Access Log를 기록하면 Disk I/O에 의해서 Flush Buffer의 Write Lock을 오랜 시간동안 점유하게 되어, Worker Thread가 Flush Buffer 접근에 오랜 시간동안 대기하는걸 방지하기 위해서이다. About to write Buffer는 Flush Thread만 단독으로 접근하기 때문에 별도의 Lock이 존재하지 않는다.

이후에 Flush Thread의 Access Logger는 About to write Buffer에 저장된 Access Log를 stdout/stderr 또는 실제 파일에 기록한다. stdout/stderr 또는 파일에는 File Lock을 통해서 보호되며, File Lock이 존재하는 이유는 Hot Restart 과정에서 일시적으로 동시에 다수의 Envoy 프로세스가 동일한 파일에 접근하는 경우 발생할 수 있는 Race Condition을 방지하기 위해서이다.

Flush Thread/Buffer/Lock 세트는 Access Log의 출력 경로(파일)마다 독립적으로 존재한다. [Figure 1]에서는 stdout, File 2가지 출력 경로가 존재하기 때문에 2개의 Flush Thread/Buffer/Lock 세트가 존재하는 것을 확인할 수 있다. 이 의미 Worker Thread에서도 Access Log의 출력 경로만큼 여러번 Write 함수를 호출하는 것을 의미하며, 따라서 너무 많은 Access Log의 출력 경로가 설정되어 있을 경우 성능 저하가 발생할 수 있다.

## 2. 참조

* Life of a Request : [https://www.envoyproxy.io/docs/envoy/latest/intro/life_of_a_request](https://www.envoyproxy.io/docs/envoy/latest/intro/life_of_a_request)
* Envoy Architecture : [https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/arch_overview](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/arch_overview)
* Envoy Architecture : [https://cscscs.tistory.com/entry/Envoy-architecture-Introduction](https://cscscs.tistory.com/entry/Envoy-architecture-Introduction)
* Envoy Architecture : [https://www.youtube.com/watch?v=KsO4pw4tEGA](https://www.youtube.com/watch?v=KsO4pw4tEGA)
* Envoy Threading Model : [https://medium.com/envoyproxy/envoy-threading-model-a8d44b922310](https://medium.com/envoyproxy/envoy-threading-model-a8d44b922310)
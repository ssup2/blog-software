---
title: "Envoy Architecture"
---

## 1. Envoy Architecture

{{< figure caption="[Figure 1] Envoy Architecture" src="images/envoy-architecture.png" width="1100px" >}}

[Figure 1] shows the Envoy Architecture. Envoy Architecture implements an **Event Driven Architecture** using a **Dispatcher** based on **libevent** and **io_uring**, and minimizes Lock usage for performance optimization by using **TLS** (Thread Local Storage), a dedicated storage per Thread. From a Thread perspective, Envoy is divided into **Main Thread**, **Worker Thread**, and **Flush Thread**.

### 1.1. Main Thread

The Main Thread performs Envoy initialization and serves as the Control Plane for Worker Threads. Through the Dispatcher, it receives various Events such as OS Signals, Timers, Sockets, and inotify, and delivers those Events to the appropriate Module for processing. When state storage is required, each Module stores state in the Main Thread's TLS, and when Data needs to be delivered to Worker Threads, it is also delivered through TLS and the Dispatcher. The Modules that run on the Main Thread are as follows.

#### 1.1.1. Runtime

**Runtime** manages Feature Flags, which are configuration values that can be changed dynamically without restart. Feature Flags are stored and used in TLS Slots as **Snapshots**. Feature Flags are managed through **Static Bootstrap**, which configures them as JSON files; **File System Layout**, which organizes them hierarchically using Directories and Files; **Admin Console**, which manages them through the `/runtime_modify` Admin Endpoint; and **Runtime Discovery Service**, which uses RTDS (Runtime Discovery Service), one of the xDS protocols.

Except for **Static Bootstrap**, all approaches allow Feature Flags to be changed dynamically without restarting Envoy. When using the File System Layout approach, file changes are detected through the Dispatcher and inotify, and Feature Flags are updated dynamically.

#### 1.1.2. xDS (eXtensible Discovery Service)

xDS (eXtensible Discovery Service) fetches required configuration information dynamically from the Control Plane that manages Envoy. xDS has the following types depending on role.

* **LDS (Listener Discovery Service)** : Fetches Listener Port and Listener/Network Filter Chain configuration.
* **RDS (Route Discovery Service)** : Fetches HTTP-based routing configuration that determines which Cluster to forward requests to.
* **CDS (Cluster Discovery Service)** : Fetches Cluster information. Here, a Cluster means a set of Endpoints (Upstream Servers).
* **EDS (Endpoint Discovery Service)** : Fetches actual Endpoint information for a Cluster.
* **SDS (Secret Discovery Service)** : Fetches TLS certificate information.
* **RTDS (Runtime Discovery Service)** : Fetches Runtime Feature Flag information.

#### 1.1.3. Listener Manager, Cluster Manager, Secret Manager, Route Config Manager

Listener Manager, Cluster Manager, Secret Manager, and Route Config Manager manage configuration fetched through xDS and, when needed, deliver it to Worker Threads through **TLS** and the **Dispatcher**.

* **Listener Manager** : Delivers Listener and Listener/Network Filter Chain configuration fetched through LDS to Worker Threads so that Worker Threads create Listener and Listener/Network Filter Chain configuration.
* **Cluster Manager** : Sets Cluster and Endpoint configuration fetched through CDS and EDS in Worker Thread TLS so that the Router Filter in the Network Filter forwards requests to the appropriate Upstream.
* **Secret Manager** : Delivers TLS certificate information fetched through SDS to Worker Thread TLS Transport Sockets.
* **Route Config Manager** : Delivers Route Config information fetched through RDS to HCM (HTTP Connection Manager) so that the HCM Router Filter forwards requests to the appropriate Cluster.

#### 1.1.3. Stats Flush

Stats Flush wakes periodically using the Dispatcher and Timer, stores Envoy-related statistics and Metric information in TLS, and sends statistics and Metric information to a StatsD Server according to configuration.

#### 1.1.4. Drain Manager

When the Drain Manager receives a SIGTERM Signal through the Dispatcher, it does not terminate Envoy immediately. Instead, it waits for in-flight Requests to finish and then terminates Envoy after completion.

#### 1.1.5. Admin

Admin provides Endpoints for Envoy management and status lookup. The main Endpoints are as follows.

* `/stats` : Endpoint for querying Envoy-related statistics and Metric information. Internally, it queries and provides information stored in TLS by the Stats Flush Module.
* `/stats/prometheus` : Provides Envoy-related statistics and Metric information in Prometheus Exporter format.
* `/reset_counters` : Provides functionality to reset statistics and Metric information.
* `/clusters` : Provides Cluster information.
* `/listeners` : Provides Listener information.
* `/memory` : Provides Envoy memory usage information.
* `/ready` : Provides Envoy readiness status. (Readiness Probe)
* `/runtime` : Provides current Runtime Feature Flag information.
* `/runtime_modify` : Endpoint for dynamically changing Runtime Feature Flags.
* `/server_info` : Provides Envoy server information.
* `/config_dump` : Provides full configuration information of the Envoy server.
* `/logging` : Provides functionality to change Logging Level.
* `/drain_listeners` : Provides functionality to drain Listeners.
* `/quitquitquit` : Provides functionality to terminate Envoy.
* `/cpuprofile` : Provides functionality to collect CPU Profile.
* `/memoryprofile` : Provides functionality to collect Memory Profile.

#### 1.1.6. GuardDog

GuardDog checks whether Main/Worker Threads are running. If GuardDog determines that Main/Worker Threads are not running, it terminates Envoy.

#### 1.1.7. Hot Restart

Hot Restart means replacing the running Envoy process with a new Envoy process on restart without Downtime. Generally, a component that manages processes or Daemons, such as Systemd, requests Envoy Hot Restart through UDS (Unix Domain Socket) when needed. Hot Restart proceeds through the following steps.

1. Create a new Envoy process.
2. Transfer Listen Sockets from the existing Envoy process to the new Envoy process through UDS (Unix Domain Socket).
3. The new Envoy process accepts new Client Connections through the transferred Listen Sockets.
4. The existing Envoy process terminates in-flight Requests through the Drain Manager and terminates Envoy after completion.

#### 1.1.8. Access Logger Notification

Access Logger Notification wakes periodically through the Dispatcher and Timer and wakes the Flush Thread.

### 1.2. Worker Thread

The Worker Thread is the Thread that receives **Downstream** (Client) requests, processes them, and forwards requests to **Upstream** (Server). Similar to the Main Thread, it receives Socket and Timer Events through the Dispatcher, and when state storage is required, it stores state in dedicated TLS owned by each Worker Thread.

One Downstream establishes a Connection with one Worker Thread. In contrast, every Worker Thread establishes Connections with every Upstream. This is because Worker Threads do not share state information, so requests must be forwardable to Upstream regardless of which Worker Thread a Downstream Connection is bound to. This means the number of Connections to Upstream increases in proportion to the number of Worker Threads, so creating too many Worker Threads causes Memory waste for maintaining Connections to Upstream.

In [Figure 1], Downstream A/B each establish Connections with different Worker Threads, and because four Worker Threads exist, every Worker Thread maintains four Connections to Upstream, equal to the number of Worker Threads. The Modules that run on the Worker Thread are as follows.

#### 1.2.1. Listener

The Listener performs TCP/UDP Listening, accepts Downstream Connections, accepts Connections, and registers the created Socket with the Dispatcher. A separate Listener exists for each Worker Thread, and all Listeners are configured to listen on the same IP/Port through the `SO_REUSEPORT` Option. When multiple Listeners listen simultaneously, the Kernel selects one Listener arbitrarily to accept the Connection. Therefore, which Thread a Client Connection is bound to is determined by the Kernel, not Envoy.

#### 1.2.2. Listener Filter Chain

The Listener Filter Chain extracts Connection Metadata such as SNI (Server Name Indication) to obtain additional Connection information. A separate Listener Filter Chain is created for each Connection or HTTP/2 Stream.

#### 1.2.3. TLS Transport Socket

Using Metadata extracted through the Listener Filter Chain, the TLS Transport Socket decrypts TLS-encrypted Data, converts it to original Data, and delivers it to the Network Filter Chain. If the Data is not TLS-encrypted, it skips decryption and delivers the original Data directly to the Network Filter Chain. A separate TLS Transport Socket is created for each Connection or HTTP/2 Stream.

#### 1.2.4. Network Filter Chain

The Network Filter Chain performs roles such as modifying decrypted requests/responses, Rate Limiting, Circuit Breaking, and Routing that determines which Upstream to send requests to. The last Network Filter Chain contains HCM (HTTP Connection Manager). HCM owns HTTP-related Filter Chains and also performs Encoding/Decoding of HTTP/2 requests/responses through the HTTP/2 Codec.

### 1.3. TLS (Thread Local Storage)

{{< figure caption="[Figure 2] Envoy TLS (Thread Local Storage)" src="images/envoy-tls.png" width="750px" >}}

[Figure 2] shows Envoy TLS (Thread Local Storage). The Main Thread and Worker Threads each have their own TLS, and Envoy uses TLS to minimize Lock usage for performance optimization. TLS is managed as an Array using the C++ STL **vector Class**. As shown in [Figure 2], each Index has a fixed purpose, and the purpose per Index is the same for Main/Worker Threads. This is because the Main Thread assigns and initializes the purpose per Index first, and then Worker Threads assign and initialize the same purpose per Index.

The actual data stored in TLS is a `shared_ptr` Pointer, and Threads reference the actual object (data) by following the Pointer. Depending on TLS purpose, the object pointed to by the `shared_ptr` Pointer may be shared between Main/Worker Threads, or each Thread may hold an independent object without sharing. In [Figure 2], Runtime, RouteConfig, and DNS Cache represent the former case, while ClusterManager and Stats represent the latter case.

When updating objects shared between Threads, Envoy generally creates a new object reflecting the changes and a `shared_ptr` Pointer for it, then replaces the existing `shared_ptr` Pointer stored in TLS with the new `shared_ptr` Pointer to update atomically. However, because TLS exists per Thread, not all TLS entries are updated simultaneously, so each Thread may temporarily reference different objects. In [Figure 2], Runtime shows all Threads referencing the same object, while RouteConfig and DNS Cache show Threads temporarily referencing different objects while data is being changed. This update approach is similar to the Kernel's **RCU (Read Copy Update)** technique.

Even when a `shared_ptr` Pointer points to an independent object per Thread, that independent object may again reference objects shared between Threads. In [Figure 2], ClusterManager shows each Thread having its own ClusterEntry but referencing ClusterInfo shared between Threads, and Stats similarly shows each Thread having an independent ScopeCache but also having Counters shared between Threads.

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

TLS updates generally use the `runOnAllThreads()` function. [Figure 3] shows how the `runOnAllThreads()` function works, and [Code 1] shows the actual `runOnAllThreads()` function code. As the name suggests, `runOnAllThreads()` helps run the same logic on all Main/Worker Threads. Through `runOnAllThreads()`, all Main/Worker Threads perform TLS update work. Because `runOnAllThreads()` is generally called from the Main Thread, TLS updates propagate from the Main Thread to each Worker Thread.

The `runOnAllThreads()` function receives a `cb` Callback function executed on Main/Worker Threads as its first parameter, and an `all_threads_complete_cb` Callback function executed once on the Main Thread after `cb` has run on all Threads as its second parameter. It operates in the following order. The `cb` Callback function contains TLS update logic, and the `all_threads_complete_cb` Callback function contains logic that must run after TLS updates on all Worker Threads are complete.

1. The Main Thread first executes the received `cb` Callback function. Depending on its internal logic, the `cb` Callback function initializes or updates the Main Thread's TLS.
2. The `cb` Callback function is stored in the `cb_guard` Pointer. The `cb_guard` Pointer acts as a C++ STL `shared_ptr` that registers a Lambda as Deleter to post the `all_threads_complete_cb` Callback function to the Main Thread and remove the `cb` Callback function.
3. A Lambda that executes the `cb` Callback function stored in the `cb_guard` Pointer is posted to all Worker Threads. At this time, because a Lambda is created and copied for each Worker Thread, the Reference Count of `cb_guard` also increases by the number of Worker Threads.
4. A posted Worker Thread is woken by the Dispatcher and executes the Lambda that runs the `cb` Callback function stored in the `cb_guard` Pointer.
5. When execution completes, the Lambda terminates and the Reference Count of the `cb_guard` Pointer decreases by 1. When the last Lambda terminates, the Reference Count of the `cb_guard` Pointer becomes 0.
6. When the Reference Count becomes `0`, the Lambda registered as Deleter on the `cb_guard` Pointer runs and posts the `all_threads_complete_cb` Callback function to the Main Thread.
7. The posted Main Thread executes the `all_threads_complete_cb` Callback function.

### 1.4. Flush Thread

Envoy provides an **Access Log** feature that records processed requests and supports multiple output paths (files), including stdout/stderr. In Envoy, Access Log recording requests originate on the Worker Thread that actually handles Traffic. However, writing Access Logs directly on the Worker Thread causes Lock contention and I/O Blocking, which interferes with Traffic processing. Envoy introduces a Flush Thread to avoid this issue.

The Flush Thread is a dedicated Thread for writing Access Logs. To minimize Lock sections during Access Log recording, Envoy uses various Buffers and Locks. According to Network Filter Chain configuration, when a Worker Thread records Access Logs, it calls the Write function of **Access Logger**, which is shared across all Worker Threads.

The Write function does not write Access Logs directly to files; it only stores them in the **Flush Buffer** and returns. Because the Flush Buffer is shared between Worker Threads, it is protected by a **Write Lock**. The Flush Buffer is used so that slow Disk I/O in the Write function does not delay Worker Threads from processing Traffic.

Unlike Main/Worker Threads, the Flush Thread does not use a Dispatcher and wakes through a Condition Variable. The Main Thread periodically wakes the Flush Thread through the Dispatcher and Timer, or a Worker Thread wakes the Flush Thread when the Flush Buffer becomes full while recording Access Logs through the Write function.

When woken, the Flush Thread temporarily stores Access Logs in the Flush Buffer into the **About to write Buffer** through Access Logger instead of writing them immediately. This is because writing Access Logs directly from Access Logger would hold the Flush Buffer's Write Lock for a long time due to Disk I/O, causing Worker Threads to wait a long time to access the Flush Buffer. Because only the Flush Thread accesses the About to write Buffer, no separate Lock exists.

Afterward, the Flush Thread's Access Logger writes Access Logs stored in the About to write Buffer to stdout/stderr or actual files. stdout/stderr and files are protected by File Lock. File Lock exists to prevent Race Conditions that can occur when multiple Envoy processes temporarily access the same file during Hot Restart.

```yaml {caption="[File 1] Envoy Access Log Configuration", linenos=table}
access_log:
  - name: envoy.access_loggers.file
    typed_config:
      "@type": type.googleapis.com/envoy.extensions.access_loggers.file.v3.FileAccessLog
      path: /var/log/access.log
      log_format:
        text_format_source:
          inline_string: "[%START_TIME%] FORMAT-A ...\n"
      # Logger A (File)

  - name: envoy.access_loggers.stdout
    typed_config:
      "@type": type.googleapis.com/envoy.extensions.access_loggers.stream.v3.StdoutAccessLog
      log_format:
        text_format_source:
          inline_string: "[%START_TIME%] FORMAT-B ...\n"
      # Logger B (stdout)
```

Each Access Logger has its own independent Flush Thread/Buffer/Lock set. In [Figure 1], because [File 1] configures two Access Loggers that output to File and stdout respectively, two Flush Thread/Buffer/Lock sets exist. This means Worker Threads call the Write function as many times as there are Access Loggers, so performance degradation can occur when too many Access Loggers are configured.

## 2. References

* Life of a Request : [https://www.envoyproxy.io/docs/envoy/latest/intro/life_of_a_request](https://www.envoyproxy.io/docs/envoy/latest/intro/life_of_a_request)
* Envoy Architecture : [https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/arch_overview](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/arch_overview)
* Envoy Architecture : [https://cscscs.tistory.com/entry/Envoy-architecture-Introduction](https://cscscs.tistory.com/entry/Envoy-architecture-Introduction)
* Envoy Architecture : [https://www.youtube.com/watch?v=KsO4pw4tEGA](https://www.youtube.com/watch?v=KsO4pw4tEGA)
* Envoy Threading Model : [https://medium.com/envoyproxy/envoy-threading-model-a8d44b922310](https://medium.com/envoyproxy/envoy-threading-model-a8d44b922310)

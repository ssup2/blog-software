---
title: "Envoy Architecture"
---

## 1. Envoy Architecture

{{< figure caption="[Figure 1] Envoy Architecture" src="images/envoy-architecture.png" width="1000px" >}}

[Figure 1]은 Envoy Architecture를 나타내고 있다. Envoy Architecture는 **libevent**와 **io_uring**을 기반으로 동작하는 **Dispatcher**를 활용하여 **Event Driven Architecture**를 구현하고 있으며, 각 Thread마다 전용 저장소인 TLS (Thread Local Storage)를 활용하여 Lock 활용을 최소화하며 동작한다. Thread 관점에서는 **Main Thread**, **Worker Thread**, **Flush Thread**로 구분된다.

### 1.1. Main Thread

### 1.2. Worker Thread

### 1.3. TLS (Thread Local Storage)

{{< figure caption="[Figure 2] Envoy TLS (Thread Local Storage)" src="images/envoy-tls.png" width="800px" >}}

{{< figure caption="[Figure 3] Envoy Run on All Threads" src="images/envoy-runonallthreads.png" width="1000px" >}}

### 1.4. Flush Thread

## 2. 참조

* Life of a Request : [https://www.envoyproxy.io/docs/envoy/latest/intro/life_of_a_request](https://www.envoyproxy.io/docs/envoy/latest/intro/life_of_a_request)
* Envoy Architecture : [https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/arch_overview](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/arch_overview)
* Envoy Architecture : [https://cscscs.tistory.com/entry/Envoy-architecture-Introduction](https://cscscs.tistory.com/entry/Envoy-architecture-Introduction)
* Envoy Architecture : [https://www.youtube.com/watch?v=KsO4pw4tEGA]](https://www.youtube.com/watch?v=KsO4pw4tEGA)
* Envoy Threading Model : [https://medium.com/envoyproxy/envoy-threading-model-a8d44b922310](https://medium.com/envoyproxy/envoy-threading-model-a8d44b922310)
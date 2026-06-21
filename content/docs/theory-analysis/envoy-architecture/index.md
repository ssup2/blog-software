---
title: "Envoy Architecture"
---

## 1. Envoy Architecture

{{< figure caption="[Figure 1] Envoy Architecture" src="images/envoy-architecture.png" width="1000px" >}}

[Figure 1]은 Envoy Architecture를 나타내고 있다. Envoy Architecture는 **libevent**와 **io_uring**을 기반으로 동작하는 **Dispatcher**를 활용하여 **Event Driven Architecture**를 구현하고 있으며, 성능 최적화를 위해서 각 Thread마다 전용 저장소인 **TLS** (Thread Local Storage)를 활용하여 Lock 활용을 최소화하며 동작한다. Thread 관점에서는 **Main Thread**, **Worker Thread**, **Flush Thread**로 구분된다.

### 1.1. Main Thread

Main Thread는 Envoy 초기화 및 Worker Thread의 Control Plane 역할을 수행한다. Dispatcher를 통해서 OS Signal, Timer, Socket, inotify 등의 다양한 Event를 수신하고, 해당 Event를 적절한 Module에 전달하여 처리한다. 각 Module은 상태 저장이 필요한 경우 Main Thread의 TLS에 저장하며, Worker Thread에 Data를 전달이 필요한 경우에도 TLS와 Dispatcher를 통해서 전달한다. Main Thread에서 수행되는 Module은 다음과 같다.

* **Runtime** : 
* **xDS** : 
* **Stats Flush** : 
* **Drain Manager** : 
* **Admin** : 
* **GuardDog** : 
* **Hot Restart** : 
* **Access Logger Notification** : 

### 1.2. Worker Thread

Worker Thread는 실제 Client의 요청을 받아 처리하는 Thread이다. Main Thread와 유사하게 Dispatcher를 통해서 Socket, Timer Event를 수신하며, 상태 저장이 필요한 경우에 각 Worker Thread마다 가지고 있는 전용 TLS에 저장한다. Worker Thread에는 Client와의 Connection마다 다음의 Instance를 생성하여 Client의 요청을 처리한다.

* **Listener** : `SO_REUSEPORT`
* **Listener Filter Chain** : 
* **TLS Transport Socket** : 
* **Network Filter Chain** : 

쓰레드 이야기

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
---
title: "Envoy Architecture"
---

## 1. Envoy Architecture

{{< figure caption="[Figure 1] Envoy Architecture" src="images/envoy-architecture.png" width="1000px" >}}

[Figure 1]은 Envoy Architecture를 나타내고 있다. Envoy Architecture는 **libevent**와 **io_uring**을 기반으로 동작하는 **Dispatcher**를 활용하여 **Event Driven Architecture**를 구현하고 있으며, 성능 최적화를 위해서 각 Thread마다 전용 저장소인 **TLS** (Thread Local Storage)를 활용하여 Lock 활용을 최소화하며 동작한다. Thread 관점에서는 **Main Thread**, **Worker Thread**, **Flush Thread**로 구분된다.

### 1.1. Main Thread

Main Thread는 Envoy 초기화 및 Worker Thread의 Control Plane 역할을 수행한다. Dispatcher를 통해서 OS Signal, Timer, Socket, inotify 등의 다양한 Event를 수신하고, 해당 Event를 적절한 Module에 전달하여 처리한다. 각 Module은 상태 저장이 필요한 경우 Main Thread의 TLS에 저장하며, Worker Thread에 Data를 전달이 필요한 경우에도 TLS와 Dispatcher를 통해서 전달한다. Main Thread에서 동작하는 Module은 다음과 같다.

* **Runtime** : 
* **xDS** : 
* **Stats Flush** : 
* **Drain Manager** : 
* **Admin** : 
* **GuardDog** : 
* **Hot Restart** : 
* **Access Logger Notification** : 

### 1.2. Worker Thread

Worker Thread는 **Downstream** (Client)의 요청을 받아 처리 이후에 **Upstream** (Server)로 요청을 전달하는 Thread이다. Main Thread와 유사하게 Dispatcher를 통해서 Socket, Timer Event를 수신하며, 상태 저장이 필요한 경우에 각 Worker Thread마다 가지고 있는 전용 TLS에 저장한다. Worker Thread에서 동작하는 Module은 다음과 같다.

* **Listener** : Listener는 TCP/UDP Listening을 수행하여 Downstream의 Connection 수락하고, Connection을 수학하며 생성된 Socket을 Dispatcher에 등록하는 역할을 수행한다. Listener는 각 Worker Thread 마다 별도로 존재하며 `SO_REUSEPORT` Option을 통해서 모든 Listener는 동일한 IP/Port를 Listening 하도록 설정된다.

* **Listener Filter Chain** : 

* **TLS Transport Socket** : 

* **Network Filter Chain** : 

하나의 Downstream은 하나의 Worker Thread와 Connection을 맺는다. 반면에 모든 Worker Thread는 모든 Upstream과 Connection을 맺는다. 이러한 이유는 Worker Thread 사이에는 상태 정보를 공유하지 않기 때문에, Downstream이 어떤 Worker Thread와 Connection을 맺더라도 Upstream으로 요청을 전달할 수 있어야 하기 때문이다. 이 의미는 Worker Thread의 개수에 비례하여 Upstream과의 Connection 개수도 증가하는걸 의미하며, 따라서 너무 많은 Worker Thread를 생성하면 Upstream과의 Connection 유지를 위한 Memory 낭비가 발생하게 된다. 

[Figure 1]에서는 Downstream A/B가 각기 다른 Worker Thread와 Connnection을 맺고 있으며, 4개의 Worker Thread가 존재하기 때문에 모든 Worker Thread가 Upstream과의 Connection을 유지하기 위해서 Worker Thread의 개수인 4개의 Connection을 유지하고 있는것을 확인할 수 있다.

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
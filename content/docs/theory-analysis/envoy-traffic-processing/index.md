---
title: "Envoy Traffic Processing"
---

## 1. Envoy HTTP Traffic Processing

{{< figure caption="[Figure 1] Envoy HTTP Traffic Processing" src="images/envoy-traffic-processing.png" width="1000px" >}}

### 1.1. Listener

**Listener**는 커널이 TCP 3-way Handshake를 완료해 Accept Queue에 올려둔 Downstream 연결을 `accept()` 함수로 수락하여 새로운 Socket을 얻는다. 이후에 얻은 Socket을 Dispatcher에 등록하고, TCP Connection 관련 정보를 얻기위한 **Listener Filter Chain**을 Instance를 생성한다.

### 1.2. Listener Filter Chain

Listener Filter는 downstream과 TCP 연결이 맺어진 뒤, 들어온 트래픽의 앞부분을 소비하지 않고 `recv(..., MSG_PEEK)`로 엿보아 필요한 연결 정보를 얻는 데 사용된다. 일부 필터(`proxy_protocol`)는 앞쪽의 PROXY Protocol 헤더를 실제로 읽어 원래 클라이언트 주소를 복원하고 그 헤더를 소비(제거)하기도 한다. Listener는 새로운 연결마다 Listener Filter 인스턴스를 생성하므로, 각 TCP 연결별로 별도의 Listener Filter Chain이 존재한다. Envoy가 제공하는 대표적인 Listener Filter는 다음과 같다. 

* `original_dst` : iptables `REDIRECT` 등으로 가려진 원래 목적지 IP, Port를 `getsockopt(SO_ORIGINAL_DST)` System Call로 복원한다. Istio 같은 Mesh Network 환경에서 Envoy가 실제 목적지 정보를 얻기 위해 사용된다.
* `original_src` : 원래 Downstream의 출발지 IP, Port를 `setsockopt(IP_TRANSPARENT)` System Call로 보존하여 Upstream으로 전송한다.
* `proxy_protocol` : PROXY Protocol을 사용하는 경우, 맨 앞 PROXY Header를 읽어 원래 Client IP, Port를 Envoy에서 Downstream IP, Port로 설정하고 그 Header를 제거한다.
* `tls_inspector` : TLS를 사용하는 경우, ClientHello를 엿보아 SNI(Server Name Indication), ALPN(Application Layer Protocol Negotiation) 등 정보를 추출한다.
* `http_inspector` : TLS를 사용하지 않아 APLN 이용이 불가능한 경우, 앞쪽 Byte를 엿보아 HTTP 프로토콜 버전(HTTP/1.x인지 HTTP/2인지)을 감지한다.

Listener Filter Chain은 Envoy Config에 따라서 자유롭게 구성할 수 있지만, 일반적으로 목적지 IP, Port를 복원하기 위한 `original_dst` Filter를 첫 번째로 사용하며, Proxy Protocol을 사용하는 경우, Proxy Header를 제거하기 위한 `proxy_protocol` Filter를 두 번째로 구성한다. 단순히 TCP Connection의 Meta 정보를 얻기 위한 `tls_inspector`, `http_inspector` Filter는 뒤에 구성하며, 일반적으로 `tls_inspector`, `http_inspector` 순서대로 구성하여 TLS가 아닌 경우, `http_inspector` Filter가 HTTP 버전을 판별하도록 한다.

```cpp linenos {caption="[Code 1] Listener Filter Chain Interface", linenos=table}
virtual FilterStatus onAccept(ListenerFilterCallbacks& cb) PURE;
```

[Code 1]은 Listener Filter Chain이 구현해야하는 `onAccept()` Interface를 나타내고 있다. Parameter로 `onAccept()` 함수 내부에서 현재 TCP Connection을 제어할 수 있는 `ListenerFilterCallbacks` Callback 함수를 전달하며, 결과로 Listener Filter Chain을 계속 진행할지 또는 잠깐 중단할지를 결정하는 `FilterStatus`를 반환한다.

### 1.3. Selecting a Filter Chain

### 1.4. Downstream Transport Socket

### 1.5. Network Filter Chain

### 1.5.1. HTTP Connection Manager (HCM)

#### 1.5.1.1. HTTP Codec

#### 1.5.1.2. Downstream HTTP Filter

#### 1.5.1.3. Router

### 1.6. Upstream HTTP Filter

### 1.7. Upstream Codec Filter

### 1.8. Upstream transport socket

## 2. 참조

* Envoy Life of a Request : [https://www.envoyproxy.io/docs/envoy/latest/intro/life_of_a_request](https://www.envoyproxy.io/docs/envoy/latest/intro/life_of_a_request)
* Envoy Listener Filters : [https://www.envoyproxy.io/docs/envoy/latest/configuration/listeners/listener_filters/listener_filters](https://www.envoyproxy.io/docs/envoy/latest/configuration/listeners/listener_filters/listener_filters)
* Envoy Network Filters : [https://www.envoyproxy.io/docs/envoy/latest/configuration/listeners/network_filters/network_filters](https://www.envoyproxy.io/docs/envoy/latest/configuration/listeners/network_filters/network_filters)


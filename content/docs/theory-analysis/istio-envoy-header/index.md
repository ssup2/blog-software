---
title: Istio Envoy Header
draft: true
---

Istio 환경에서 Sidecar Proxy (Envoy)가 활용하는 Header를 정리한다. Envoy 자체의 Header는 [Envoy Header](https://ssup2.github.io/blog-software/docs/theory-analysis/envoy-header/) 글을 참조한다.

## 1. Istio Envoy Header

Istio는 Envoy를 Sidecar Proxy 및 Gateway로 활용하기 때문에 Envoy의 Header가 대부분 그대로 활용되며, Istio 환경에서만 활용되는 Header도 별도로 존재한다. 또한 Istio는 Mesh 내부/외부 트래픽 여부에 따라서 Envoy Header의 신뢰 여부를 결정한다.

### 1.1. Metadata Exchange Header

Istio의 Sidecar Proxy는 Telemetry (Metric, Access Log)에 상대 Workload의 정보를 나타내기 위해서 Sidecar Proxy 간의 Metadata 교환에 다음의 Header를 활용한다.

* `x-envoy-peer-metadata` : Workload의 이름, Namespace, Label, Owner 정보를 Protobuf로 직렬화한 다음 Base64로 Encoding한 값을 나타낸다.
* `x-envoy-peer-metadata-id` : Workload의 고유 ID를 나타낸다.

Client Pod의 Sidecar Proxy는 요청에 자신의 Metadata를 설정하여 전송하고, Server Pod의 Sidecar Proxy는 응답에 자신의 Metadata를 설정하여 전송한다. 이러한 Metadata 교환을 통해서 양쪽 Sidecar Proxy는 `source_workload`, `destination_workload`와 같은 Istio Metric의 Label을 설정할 수 있다. Metadata Exchange Header는 **Sidecar Proxy 사이에서만 교환**되며, App Container에게 요청을 전달하거나 Mesh 외부로 요청을 전달하기 전에 제거된다.

### 1.2. Identity Header

```text {caption="[Text 1] x-forwarded-client-cert Header Example"}
x-forwarded-client-cert: By=spiffe://cluster.local/ns/httpbin/sa/httpbin;Hash=1234abcd...;Subject="";URI=spiffe://cluster.local/ns/sleep/sa/sleep
```

Istio 환경에서 Sidecar Proxy 사이에 mTLS가 적용된 경우, Server Pod의 Sidecar Proxy는 Client의 인증서 정보를 `x-forwarded-client-cert` (XFCC) Header에 설정하여 App Container에게 전달한다. [Text 1]은 `x-forwarded-client-cert` Header의 예시를 나타내고 있으며, 각 Key의 의미는 다음과 같다.

* `By` : 현재 Proxy (Server Pod의 Sidecar Proxy) 인증서의 URI SAN (SPIFFE ID)을 나타낸다.
* `Hash` : Client 인증서의 SHA256 Hash 값을 나타낸다.
* `Subject` : Client 인증서의 Subject를 나타낸다. Istio가 발급하는 인증서에는 Subject가 존재하지 않기 때문에 일반적으로 빈 값이 설정된다.
* `URI` : Client 인증서의 URI SAN (SPIFFE ID)을 나타낸다. `spiffe://<Trust Domain>/ns/<Namespace>/sa/<Service Account>` 형태이며, 이를 통해서 요청을 전송한 Client의 Identity를 확인할 수 있다.

`URI` Key의 SPIFFE ID는 Istio Authorization Policy의 `source.principals` 조건의 매칭에 활용되며, App Container도 이 Header를 통해서 요청을 전송한 Client를 직접 확인할 수 있다.

### 1.3. Tracing Header

Istio의 Sidecar Proxy는 Tracing을 위해서 다음의 Header를 활용한다.

* `x-request-id` : 요청을 식별하는 고유한 UUID 값을 나타내며, Access Log와 Tracing에서 하나의 요청을 식별하는 용도로 활용된다.
* `x-b3-traceid`, `x-b3-spanid`, `x-b3-parentspanid`, `x-b3-sampled`, `x-b3-flags` : Zipkin의 B3 Format의 Trace Context를 나타낸다.
* `traceparent`, `tracestate` : W3C Trace Context Format의 Trace Context를 나타낸다.

Sidecar Proxy는 요청 단위로 Span을 생성할 수 있지만, App Container 내부에서 Inbound 요청과 Outbound 요청 사이의 연관 관계는 파악할 수 없다. 따라서 **App Container가 Inbound 요청에서 수신한 Tracing Header를 Outbound 요청에 직접 전파**해야 하나의 Trace로 연결된다.

### 1.4. App Container의 Envoy 동작 제어

```text {caption="[Text 2] Envoy 동작 제어 Header 설정 Example"}
GET /api HTTP/1.1
Host: httpbin
x-envoy-retry-on: 5xx
x-envoy-max-retries: 3
x-envoy-upstream-rq-timeout-ms: 3000
```

Sidecar Proxy는 App Container가 전송하는 Outbound 요청을 Internal 요청으로 판단한다. 따라서 App Container가 요청에 `x-envoy-retry-on`, `x-envoy-max-retries`, `x-envoy-upstream-rq-timeout-ms` Header를 설정하면, Virtual Service 설정 없이도 요청 단위로 Sidecar Proxy의 Retry, Timeout 동작을 제어할 수 있다. [Text 2]는 재시도와 Timeout을 제어하는 Header를 설정한 요청의 예시를 나타내고 있다. 설정 가능한 Header 목록은 [Envoy Header](https://ssup2.github.io/blog-software/docs/theory-analysis/envoy-header/) 글을 참조한다.

### 1.5. Header Sanitization

Envoy는 요청이 Internal 요청인지 External 요청인지에 따라서 `x-envoy-` Prefix Header의 신뢰 여부를 결정한다. Istio 환경에서는 다음과 같이 동작한다.

* **Ingress Gateway** : Mesh 외부에서 유입되는 요청은 External 요청으로 판단하기 때문에, 요청에 포함되어 있는 `x-envoy-` Prefix Header를 신뢰하지 않고 제거한다. 따라서 Mesh 외부의 Client는 `x-envoy-retry-on` Header와 같은 동작 제어 Header를 활용할 수 없다.
* **Sidecar Proxy** : App Container가 전송하는 Outbound 요청과 Mesh 내부의 다른 Sidecar Proxy로부터 수신하는 요청은 Internal 요청으로 판단하기 때문에, `x-envoy-` Prefix Header를 신뢰하고 유지한다.

## 2. 참조

* Istio Mesh Option : [https://istio.io/latest/docs/reference/config/istio.mesh.v1alpha1/](https://istio.io/latest/docs/reference/config/istio.mesh.v1alpha1/)
* Istio Distributed Tracing : [https://istio.io/latest/docs/tasks/observability/distributed-tracing/overview/](https://istio.io/latest/docs/tasks/observability/distributed-tracing/overview/)
* Istio Metadata Exchange : [https://istio.io/latest/docs/reference/config/proxy_extensions/metadata_exchange/](https://istio.io/latest/docs/reference/config/proxy_extensions/metadata_exchange/)
* Envoy Header Manipulation : [https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_conn_man/headers#http-header-manipulation](https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_conn_man/headers#http-header-manipulation)
* Envoy x-forwarded-client-cert : [https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_conn_man/headers#x-forwarded-client-cert](https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_conn_man/headers#x-forwarded-client-cert)
* Envoy Header 정리 : [https://ssup2.github.io/blog-software/docs/theory-analysis/envoy-header/](https://ssup2.github.io/blog-software/docs/theory-analysis/envoy-header/)

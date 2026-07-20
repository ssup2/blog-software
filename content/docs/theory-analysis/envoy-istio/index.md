---
title: "Envoy with Istio"
---

## 1. Envoy as Sidecar Proxy with Istio

{{< figure caption="[Figure 1] Sidecar Proxy with Istio" src="images/envoy-istio-sidecar.png" width="700px" >}}

[Figure 1]은 Istio 환경에서 Envoy가 Sidecar Proxy로 동작할 때 App Pod 내부의 구성 요소와 Traffic 흐름을 나타내고 있다. App Pod에는 App Container와 함께 istio-proxy Container가 배치되며, istio-proxy Container 안에서는 pilot-agent와 Envoy 두 Process가 동작한다. Pod 시작 시 istio-init Container가 설정한 iptables Rule에 의해 App Container의 모든 Traffic은 Envoy를 경유한다. 주요 흐름은 다음과 같다.

* **xDS 설정 전달 (하늘색)** : istiod의 `15012` Port xDS Server는 LDS, RDS, CDS, EDS, SDS, NDS 설정을 하나의 ADS Stream으로 pilot-agent에 전달한다. pilot-agent는 받은 설정을 `unix:///etc/istio/proxy/XDS` Socket을 통해 다시 ADS로 Envoy에 중계하며, Workload 인증서는 `unix:///var/run/secrets/workload-spiffe-uds/socket` Socket을 통해 SDS로 전달한다. 즉 Envoy는 istiod와 직접 통신하지 않으며, pilot-agent가 xDS Proxy 역할을 수행한다.
* **Outbound Traffic (주황색)** : App Container가 외부로 보내는 요청은 iptables에 의해 Envoy의 `15001` Port로 Redirect된 뒤, Envoy의 라우팅을 거쳐 상대 App Pod로 전달된다.
* **Inbound Traffic (노란색)** : 다른 App Pod로부터 들어오는 요청은 iptables에 의해 Envoy의 `15006` Port로 Redirect된 뒤, App Container의 `8080` Port로 전달된다.
* **DNS Lookup (초록색)** : DNS Capture가 활성화된 경우 App Container의 DNS 질의는 pilot-agent의 `15053` Port DNS Proxy로 Redirect되어 처리된다. 이때 DNS Proxy가 사용하는 Hostname 정보가 istiod로부터 NDS를 통해 전달되며, NDS가 Envoy로 중계되지 않고 pilot-agent에서 소비되는 이유이다.
* **Metrics 수집 (파란색)** : Prometheus Server는 pilot-agent의 `15020` Port `/stats/prometheus` 하나만 Scrape한다. pilot-agent는 Envoy의 `15090` Port `/stats/prometheus`와 App Container의 `8080` Port `/metrics`를 함께 수집하여 병합된 Metrics를 제공한다.
* **Health Check (빨간색)** : kubelet은 Envoy의 `15021` Port `/healthz/ready`로 istio-proxy Container의 Health Check를 수행하며, Envoy는 이 요청을 pilot-agent의 `15020` Port `/healthz/ready`로 전달한다.
* **Envoy Admin (검정색)** : istioctl은 Envoy의 `15000` Port Admin Interface에 접근하여 Envoy에 적용된 설정과 상태를 확인한다. `istioctl proxy-config` 명령어가 이 경로를 통해 Listener, Route, Cluster 등의 설정을 조회하는 대표적인 예이다.

이처럼 Envoy가 istiod와 직접 통신하지 않고 pilot-agent를 xDS Proxy로 경유하는 이유는 다음과 같다.

* **인증 위임** : Envoy가 istiod와 mTLS로 통신하려면 인증서가 필요하지만, 그 인증서는 다시 istiod로부터 발급받아야 하는 순환 문제가 존재한다. pilot-agent가 Pod의 Service Account Token을 이용해 CSR을 생성하고 istiod CA로부터 인증서를 발급받은 뒤 SDS Socket으로 Envoy에 공급하는 방식으로 이 문제를 해결하며, 인증서 갱신도 pilot-agent가 담당하므로 Envoy는 인증서 수명 주기를 신경 쓰지 않아도 된다.
* **Private Key 보호** : Workload의 Private Key는 pilot-agent가 Pod 내부에서 생성하고 istiod에는 CSR만 전달되므로, Private Key는 Pod 밖으로 나가지 않는다. 인증서를 xDS 설정과 분리된 전용 SDS Socket으로 Envoy에 공급하는 것도 같은 맥락으로, 민감 정보가 중앙 채널을 거치지 않도록 하기 위함이다.
* **xDS 가공 가능** : pilot-agent는 istiod가 내려준 xDS 설정을 단순히 중계하는 것이 아니라 중간에서 가공할 수 있다. 대표적으로 설정에 원격 Wasm 모듈이 포함된 경우 pilot-agent가 모듈을 대신 다운로드한 뒤 로컬 경로로 바꾸어 Envoy에 전달한다.
* **istiod 장애 대응** : pilot-agent는 istiod로부터 받은 마지막 설정을 캐시하고 있어, istiod 장애 중에도 Envoy가 재연결하면 캐시된 설정으로 응답할 수 있다. Envoy 입장에서 xDS Server는 항상 로컬의 pilot-agent이므로, Control Plane 장애가 Data Plane의 동작에 바로 전파되지 않는다.

## 2. Envoy as Ingress/Egress Gateway with Istio

## 3. Envoy Configuration with Istio and Kubernetes Resources 

## 4. 참조

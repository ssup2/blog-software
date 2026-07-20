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

## 2. Envoy as Ingress/Egress Gateway with Istio

## 3. Envoy Configuration with Istio and Kubernetes Resources 

## 4. 참조

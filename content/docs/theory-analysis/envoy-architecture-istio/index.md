---
title: "Envoy Architecture with Istio"
---

## 1. Envoy as Sidecar Proxy with Istio

{{< figure caption="[Figure 1] Sidecar Proxy with Istio" src="images/envoy-istio-sidecar.png" width="700px" >}}

[Figure 1]은 Istio 환경에서 Envoy가 Sidecar Proxy로 동작할 때 App Pod 내부의 구성 요소와 Traffic 흐름을 나타내고 있다. App Pod에는 App Container와 함께 istio-proxy Container가 배치되며, istio-proxy Container 안에서는 pilot-agent와 Envoy 두 Process가 동작한다. Pod 시작 시 istio-init Container가 설정한 iptables Rule에 의해 App Container의 **모든 Traffic은 Envoy를 경유**한다. 다음과 같은 동작으로 분류 할 수 있다.

### 1.1. xDS

istiod의 `15012` Port xDS Server는 LDS, RDS, CDS, EDS, SDS, NDS, ECDS 설정을 **하나의 ADS Stream**으로 pilot-agent에 전달한다 (하늘색). pilot-agent는 받은 설정 중 LDS, RDS, CDS, EDS, ECDS를 `unix:///etc/istio/proxy/XDS` Socket을 통해 **다시 ADS로 Envoy에 중계**하며, **Workload 인증서**는 `unix:///var/run/secrets/workload-spiffe-uds/socket` Socket을 통해 SDS로 전달한다. ECDS는 WasmPlugin CR로 정의된 Wasm Filter 설정을 전달하는 데 사용되며, Listener 전체를 갱신하지 않고 HTTP Filter 설정만 독립적으로 갱신할 수 있다.

인증서를 별도의 SDS Socket으로 분리하여 전달하는 이유는 Private Key와 같은 **민감 정보를 일반 설정과 분리**하기 위함이다. 즉 Envoy는 istiod와 직접 통신하지 않으며, **pilot-agent가 xDS Proxy 역할**을 수행한다. 이처럼 Envoy가 istiod와 직접 통신하지 않고 pilot-agent를 xDS Proxy로 경유하는 이유는 다음과 같다.

* **인증 위임** : Envoy가 istiod와 mTLS로 통신하려면 인증서가 필요하지만, 그 인증서는 다시 istiod로부터 발급받아야 하는 순환 문제가 존재한다. pilot-agent가 Pod의 Service Account Token을 이용해 CSR (Certificate Signing Request)을 생성하고 istiod CA로부터 인증서를 발급받은 뒤 SDS Socket으로 Envoy에 공급하는 방식으로 이 문제를 해결하며, 인증서 갱신도 pilot-agent가 담당하므로 Envoy는 인증서 수명 주기를 신경 쓰지 않아도 된다.
* **xDS 변조** : pilot-agent는 istiod가 내려준 xDS 설정을 단순히 중계하는 것이 아니라 중간에서 변조할 수 있다. 예를 들어 istiod가 ECDS로 "원격 저장소에서 Wasm 필터 모듈을 다운로드해서 사용하라"는 설정을 내려주면, pilot-agent가 모듈을 대신 다운로드해 두고 설정 안의 원격 주소를 로컬 파일 경로로 바꿔서 Envoy에 전달한다. Envoy는 로컬 파일만 읽으면 되므로, 저장소 인증이나 다운로드 실패 처리 같은 복잡한 일은 모두 pilot-agent가 담당한다.
* **istiod 장애 대응** : pilot-agent는 istiod로부터 받은 마지막 설정을 캐시하고 있어, istiod 장애 중에도 Envoy가 재연결하면 캐시된 설정으로 응답할 수 있다. Envoy 입장에서 xDS Server는 항상 로컬의 pilot-agent이므로, Control Plane 장애가 Data Plane의 동작에 바로 전파되지 않는다.

### 1.2. Outbound/Inbound Traffic

App Container가 **외부로 보내는 요청**은 iptables에 의해 Envoy의 `15001` Port로 Redirect된 뒤, Envoy의 라우팅을 거쳐 상대 App Pod로 전달된다 (주황색). 반대로 **다른 App Pod로부터 들어오는 요청**은 iptables에 의해 Envoy의 `15006` Port로 Redirect된 뒤, App Container의 `8080` Port로 전달된다 (노란색).

### 1.3. DNS Lookup

DNS Capture 활성화 여부에 따라 App Container의 DNS 질의 경로가 달라진다. **DNS Capture가 비활성화된 경우** App Container의 DNS 질의는 iptables를 거쳐 CoreDNS로 그대로 전달된다 (연두색). 반면 **DNS Capture가 활성화된 경우** DNS 질의는 iptables에 의해 pilot-agent의 `15053` Port DNS Proxy로 Redirect되어 처리된다 (초록색). 이때 DNS Proxy가 사용하는 Hostname 정보는 istiod로부터 NDS를 통해 전달되며, NDS가 Envoy로 중계되지 않고 pilot-agent에서 소비되는 이유이다.

### 1.4. Metrics 수집

Prometheus Server가 Metrics를 수집하는 경로는 두 가지가 존재한다. 하나는 App Container의 `8080` Port `/metrics`를 직접 Scrape하여 **App의 Metrics를 수집**하는 경로이고 (파란색), 다른 하나는 pilot-agent의 `15020` Port `/stats/prometheus`를 Scrape하여 **Envoy의 Metrics를 수집**하는 경로이다 (남색). pilot-agent는 Envoy의 `15090` Port `/stats/prometheus`에서 Envoy의 Metrics를 가져와 제공한다.

여기에 병합 수집이 활성화되면 **App의 Metrics가 Envoy Metrics 경로에 합류**한다. pilot-agent가 App Container의 `8080` Port `/metrics`까지 함께 수집하여 `15020` Port에서 병합된 Metrics를 제공하므로, Prometheus Server는 남색 경로 하나로 Envoy와 App의 Metrics를 모두 수집할 수 있다. 병합 수집은 App Pod에 `prometheus.io/scrape`, `prometheus.io/port`, `prometheus.io/path`와 같은 Prometheus Scrape Annotation이 붙어 있고, Istio에 `enablePrometheusMerge: true` 설정이 되어 있는 경우에만 동작한다.

병합 수집이 필요한 이유는 Annotation 기반 방식은 `prometheus.io/port` Annotation에 하나의 Port만 지정할 수 있어, **Pod당 하나의 Metrics Endpoint만 Scrape**할 수 있기 때문이다. 반면 Prometheus Operator의 PodMonitor/ServiceMonitor 방식은 하나의 Pod에 여러 Metrics Port를 지정할 수 있으므로 병합 수집이 필요 없다.

### 1.5. Health Check

kubelet이 수행하는 Probe는 대상에 따라 두 가지로 나뉜다. **istio-proxy Container의 Health Check**는 kubelet이 Envoy의 `15021` Port `/healthz/ready`로 수행하며, Envoy는 이 요청을 pilot-agent의 `15020` Port `/healthz/ready`로 전달한다 (빨간색).

반면 **App Container의 Probe**는 kubelet이 App Container로 직접 수행하지 않는다. Sidecar 주입 시 Probe 설정이 pilot-agent의 `15020` Port `/app-health/app/livez`, `/app-health/app/readyz`, `/app-health/app/startupz`로 변경되며, pilot-agent가 이 요청을 App Container의 `8080` Port `/livez`, `/readyz`, `/startupz`로 전달한다 (보라색). 경로 가운데의 `app`은 Probe 대상 Container의 이름을 나타낸다. Probe 요청이 iptables Redirect에 의해 Envoy를 경유하면서 mTLS 정책에 걸려 실패하는 것을 막기 위함이다.

### 1.6. Envoy Admin

istioctl은 Envoy의 `15000` Port Admin Interface에 접근하여 **Envoy에 적용된 설정과 상태를 확인**한다 (검정색). `istioctl proxy-config` 명령어가 이 경로를 통해 Listener, Route, Cluster 등의 설정을 조회하는 대표적인 예이다.

## 2. Envoy as Ingress/Egress Gateway with Istio

Istio는 Mesh의 경계에서 Traffic을 처리하기 위해 Envoy를 Gateway로도 배치한다. istio-ingressgateway는 외부에서 Mesh로 들어오는 **Traffic의 진입점** 역할을, istio-egressgateway는 Mesh에서 외부로 나가는 **Traffic의 통제된 출구** 역할을 수행한다.

Gateway Pod의 내부 구조는 [Figure 1]의 Sidecar와 거의 동일하다. istio-proxy Container 안에서 pilot-agent와 Envoy가 함께 동작하고, pilot-agent가 xDS Proxy와 인증서 공급을 담당하는 구조도 그대로 유지된다. 차이는 두 가지다. 첫째, App Container가 없으므로 **Envoy가 Pod의 유일한 Process** 역할을 하며, `proxy router` 모드로 실행된다. 둘째, 가로챌 App Traffic이 없으므로 **istio-init Container와 iptables Redirect도 없다**. Traffic은 Redirect가 아니라 Kubernetes Service를 통해 Envoy의 Listener Port로 직접 도착한다.

Gateway Pod의 Envoy는 **빈 상태로 시작**한다. 기본 Listener는 Health Check용 `15021`과 Prometheus Metrics용 `15090` 두 개뿐이며, Gateway CR이 `selector`로 해당 Pod를 선택하고 Server를 선언해야 비로소 Traffic을 수신할 Listener가 생성된다. 반면 Cluster는 Sidecar와 동일하게 Mesh 전체 서비스의 설정을 항상 받고 있으므로, **Listener만 열리면 어느 서비스로든 라우팅**할 수 있다. Gateway CR이 Listener를 만드는 과정은 Envoy Configuration with Istio 문서에서 실측 diff로 다룬다.

ingressgateway와 egressgateway는 **이 구조를 완전히 공유**한다. 두 Deployment는 동일한 이미지와 실행 인자를 사용하며, 기본 상태의 Envoy 설정(Listener, Cluster, Secret)도 동일하다. 둘을 구분 짓는 것은 Envoy가 아니라 **배치와 Traffic 방향**이다.

* **Service 노출** : istio-ingressgateway Service는 `LoadBalancer` Type으로 외부에 노출되고, istio-egressgateway Service는 `ClusterIP` Type으로 Mesh 내부에서만 접근할 수 있다.
* **Label** : Pod에 각각 `istio: ingressgateway`, `istio: egressgateway` Label이 있으며, Gateway CR의 `selector`가 어느 Label을 선택하느냐에 따라 어떤 Traffic을 받을지 정해진다.
* **Ingress Traffic 흐름** : 외부 Client의 요청은 LoadBalancer를 거쳐 istio-ingressgateway Service의 `80` Port로 들어오고, `targetPort` 매핑에 따라 Envoy의 `8080` Listener에 도착한다. Envoy는 Gateway에 연결된 VirtualService의 Route에 따라 요청을 Mesh 내부 서비스의 Cluster로 전달하며, Upstream Sidecar와는 mTLS로 통신한다.
* **Egress Traffic 흐름** : App이 외부로 보내는 요청을 Sidecar가 VirtualService Route에 따라 egressgateway로 먼저 전달하고, egressgateway가 이를 받아 외부 서비스로 내보낸다. 모든 Outbound Traffic이 하나의 지점을 거치므로, 고정된 출구 IP 확보, TLS Origination, 외부 접근 정책 집행을 한 곳에서 수행할 수 있다.

## 3. 참조

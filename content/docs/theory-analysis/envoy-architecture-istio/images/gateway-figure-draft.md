# Gateway Figure 초안 (pptx 작업용)

2장 Ingress/Egress Gateway Figure 스케치. kind 클러스터 실측(2026-08-15) 기반.
Pod 내부는 두 Gateway가 완전히 동일 — Service 계층과 Traffic 방향만 다르게 그린다.

## Ingress Gateway

```
                External Client                        ┌────────┐
                      │                                │ istiod │ :15012 xDS Server
                      ▼                                └───┬────┘
              ┌──────────────┐                             │ LDS, RDS, CDS, EDS,
              │ LoadBalancer │── Health Check ──┐          │ SDS, NDS, ECDS (ADS)
              └──────┬───────┘                  │          │
                     ▼                          │          │
  ┌─ istio-ingressgateway Service ────────────┐ │          │
  │ Type: LoadBalancer                        │ │          │
  │ status-port 15021 ─────────────────◄──────┼─┘          │
  │ http2 80 → 8080   https 443 → 8443        │            │
  │ tcp 31400         tls 15443               │            │
  └──────┬────────────────────────────────────┘            │
         ▼                                                 ▼
  ┌─ Pod (istio: ingressgateway) ────────────────────────────────────┐
  │ ┌─ istio-proxy Container ──────────────────────────────────────┐ │
  │ │  ┌─ pilot-agent ─────────────┐                               │ │
  │ │  │ :15020 /healthz/ready     │◄─── (kubelet Probe는          │ │
  │ │  │ :15020 /stats/prometheus  │      Envoy :15021 경유)       │ │
  │ │  └──────────┬────────────────┘                               │ │
  │ │             │ ADS (XDS Socket) / SDS (spiffe-uds Socket)     │ │
  │ │  ┌─ Envoy ──▼───────────────────────────────┐                │ │
  │ │  │ :15021 /healthz/ready    (기본 Listener) │                │ │
  │ │  │ :15090 /stats/prometheus (기본 Listener) │                │ │
  │ │  │ :8080, :8443 ◄── Gateway CR이 생성       │                │ │
  │ │  └──────────────┬───────────────────────────┘                │ │
  │ └─────────────────┼────────────────────────────────────────────┘ │
  └───────────────────┼──────────────────────────────────────────────┘
                      │ VirtualService Route, mTLS
                      ▼
              Mesh 내부 App Pod (Sidecar)
```

## Egress Gateway

```
       Mesh 내부 App Pod (Sidecar)                     ┌────────┐
                      │ Sidecar가 VirtualService       │ istiod │ :15012 xDS Server
                      │ Route로 egressgateway 지정     └───┬────┘
                      ▼                                    │ LDS, RDS, CDS, EDS,
  ┌─ istio-egressgateway Service ───────────────┐          │ SDS, NDS, ECDS (ADS)
  │ Type: ClusterIP                             │          │
  │ http2 80 → 8080   https 443 → 8443          │          │
  │ (status-port 없음 — 외부 LB가 없으므로)     │          │
  └──────┬──────────────────────────────────────┘          │
         ▼                                                 ▼
  ┌─ Pod (istio: egressgateway) ─────────────────────────────────────┐
  │ ┌─ istio-proxy Container ──────────────────────────────────────┐ │
  │ │  ┌─ pilot-agent ─────────────┐                               │ │
  │ │  │ :15020 /healthz/ready     │                               │ │
  │ │  │ :15020 /stats/prometheus  │                               │ │
  │ │  └──────────┬────────────────┘                               │ │
  │ │             │ ADS (XDS Socket) / SDS (spiffe-uds Socket)     │ │
  │ │  ┌─ Envoy ──▼───────────────────────────────┐                │ │
  │ │  │ :15021 /healthz/ready    (기본 Listener) │                │ │
  │ │  │ :15090 /stats/prometheus (기본 Listener) │                │ │
  │ │  │ :8080, :8443 ◄── Gateway CR이 생성       │                │ │
  │ │  └──────────────┬───────────────────────────┘                │ │
  │ └─────────────────┼────────────────────────────────────────────┘ │
  └───────────────────┼──────────────────────────────────────────────┘
                      │ TLS Origination, 출구 IP 고정, 정책 집행
                      ▼
                외부 서비스 (Mesh 밖)
```

## 작도 포인트

- **같게**: Pod 내부 전체(pilot-agent·Envoy·Socket 2개·기본 Listener `15021`/`15090`·Gateway CR Listener `8080`/`8443`), istiod→pilot-agent xDS 화살표. Figure 1과 달리 istio-init Container/iptables는 양쪽 다 없음.
- **다르게**: ① Traffic 방향, ② Service Type (`LoadBalancer` vs `ClusterIP`), ③ ingress에만 `status-port 15021` + LoadBalancer Health Check 화살표, ④ ingress에만 `31400`(tcp)/`15443`(tls) Port, ⑤ Label (`istio: ingressgateway` vs `istio: egressgateway`).
- 한 장에 좌우 배치 + 가운데 Mesh 공유 구성이면 "구조 동일, 배치·방향만 차이" 메시지와 부합.

# envoy-architecture-istio 문서 작업 컨텍스트

문서 제목: "Envoy Architecture with Istio" (구 "Envoy with Istio", 폴더명도 envoy-istio에서 2026-08-09에 변경).

Istio 환경에서 Envoy가 배치되는 구조를 다루는 문서.
CR별 Envoy 설정 변화(실측 diff)는 2026-08-09에 **envoy-configuration-istio** 문서로 분리했다
(../envoy-configuration-istio/ — 실험 환경, manifests/, envoy_configs/, 캡처 방법론도 함께 이동).

## 문서 구성 및 상태

- **1장 (Envoy as Sidecar Proxy)**: 완료. Pod 내부 Traffic 흐름 + pilot-agent를 xDS Proxy로 두는 이유.
- **2장 (Envoy as Ingress/Egress Gateway)**: 미작성.
- **3장 (참조)**: 링크 미채움.

## 폴더 구조

- `index.md` — 문서 본문.
- `images/` — Figure 이미지 (envoy-istio-sidecar.png).

## 문서 컨벤션

- 리소스 이름/설정값은 백틱, 일반 기술 용어는 영어 표기(Listener, Cluster 등).
- Istio 언급은 필요한 곳에만 최소화 (envoy-configuration-xds 문서와의 공통 방침).

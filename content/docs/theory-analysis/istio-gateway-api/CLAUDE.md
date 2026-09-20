# istio-gateway-api 문서 작업 컨텍스트

Istio의 Kubernetes Gateway API 구현을 분석하는 문서. 본문 기준 Version: Istio 1.31, Gateway API v1.6.
2026-09-20에 이론 초안 작성 완료. Test 섹션(환경 구성 + 실측 결과)은 추가 예정이며 Ambient Mode는 테스트 범위에서 제외한다 (사용자 지시).

## 문서 구성 및 상태

- **1장**: 이론 완료 (1.1 Gateway 배포(자동/수동), 1.2 Istio 설정 변환, 1.3 Istio API 비교, 1.4 Mesh Traffic 제어, 1.5 Ambient Mode Waypoint).
- **Test 섹션**: 미작성. 실측 완료 후 본문에 추가한다.
- **주의**: 본문 [Shell 1](Gateway 자동 배포 확인)은 현재 실측이 아닌 창작된 예시 출력이다.
  실측 후 실제 출력으로 교체해야 한다 (본문 출력 창작 금지 원칙).
- Figure 1 이미지 미제작.

## Test 환경 (재현 방법)

- 로컬 kind Cluster + OrbStack Docker (macOS arm64). OrbStack이 꺼져 있으면 `open -a OrbStack`으로 시작.
- 로컬 istioctl은 1.24.2로 오래됨 — Istio 1.31 테스트 시 별도 다운로드 필요:
  `curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.31.0 sh -` (임시 디렉토리에 받아서 사용).
- 설치 순서:
  1. `kind create cluster --name istio-gateway-api`
  2. Gateway API CRD (v1.6 Standard Channel):
     `kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.0/standard-install.yaml`
  3. `istioctl install --set profile=minimal -y` (Sidecar Mode, Ambient 불필요)
  4. `kubectl apply -f manifests/namespaces.yaml` → `manifests/base/` → `manifests/gateway/` → `manifests/mesh/`
- kind에는 LoadBalancer가 없으므로 gateway Service의 EXTERNAL-IP는 pending이 정상.
  curl 테스트는 `kubectl port-forward` 또는 gateway Pod IP로 수행하고, Host Header(`version.ssup2.com`)를 명시한다.

## Test 시나리오

1. **GatewayClass 확인**: `kubectl get gatewayclass` — istio, istio-remote, istio-waypoint 목록 (본문 [Table 1] 검증).
2. **Gateway 자동 배포**: `manifests/gateway/gateway.yaml` 적용 → `gateway-istio` Deployment/Service 생성 확인
   → 본문 [Shell 1]을 실측 출력으로 교체. gateway-options ConfigMap의 replicas 3, ClusterIP 반영 확인
   (`infrastructure.parametersRef` 검증).
3. **HTTPRoute Routing**: `manifests/gateway/httproute.yaml` 적용 → port-forward 후
   `curl -H "Host: version.ssup2.com"` 반복 → version-v1/v2 약 90:10 분배 확인.
4. **설정 변환 확인**: `istioctl proxy-config routes <gateway-istio pod> -n gateway-namespace` 등으로
   HTTPRoute가 내부 VirtualService로 변환되어 xDS에 반영된 것 확인 (본문 1.2 검증).
   `kubectl get virtualservice -A`가 비어 있음(in-memory 변환, Kubernetes 미저장)도 함께 확인.
5. **GAMMA Mesh Routing**: `manifests/mesh/httproute-mesh.yaml` 적용 → client Pod(Sidecar 주입됨)에서
   `curl version.version-namespace:8080` 반복 → 90:10 분배 확인. Sidecar 없는 요청과의 차이도 확인.
   client Pod의 `istioctl proxy-config routes`에서 규칙이 Client Sidecar의 outbound에 적용됨을 확인 (본문 1.4 검증).
6. Ambient Mode(Waypoint) 테스트는 하지 않는다.

## 폴더 구조

- `index.md` — 문서 본문.
- `manifests/namespaces.yaml` — gateway-namespace, version-namespace(istio-injection=enabled).
- `manifests/base/` — 테스트 Workload (version-v1/v2 = Deployment+Service, version = GAMMA parent Service, client = curl Pod).
- `manifests/gateway/` — Gateway, gateway-options ConfigMap, HTTPRoute (본문 [File 1], [File 2] 대응).
- `manifests/mesh/` — GAMMA Producer Route (본문 [File 4] 대응).
- 실측 후 Shell 출력 원본이나 proxy-config dump를 남길 경우 envoy-configuration-istio 문서의
  `envoy_configs/` 패턴을 따른다.

## 문서 컨벤션

- 본문 Shell/File 출력은 실측에서 발췌하며 창작하지 않는다 (현재 [Shell 1]만 예외 상태 — 교체 필요).
- Test 환경의 버전 명시는 도입부가 아니라 Test 환경 구성 섹션에 쓴다 (repo CLAUDE.md 스타일 규칙 참조).

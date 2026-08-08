# envoy-istio 문서 작업 컨텍스트

Istio 환경에서 Envoy의 동작을 다루는 문서. 1장은 Sidecar Proxy 구조(pilot-agent와의 관계),
3장은 Istio CR별 Envoy 설정 변화를 실측 diff로 기록한다.

## 문서 구성 및 상태

- **1장 (Envoy as Sidecar Proxy)**: 완료. Pod 내부 Traffic 흐름 + pilot-agent를 xDS Proxy로 두는 이유.
- **2장 (Envoy as Ingress/Egress Gateway)**: 미작성.
- **3장 (Envoy Configuration with Istio CR)**: 완료. 3장 도입부에 실험 환경 yaml([Config 1], 별도 소제목 없음),
  3.1~3.14 = Gateway, VirtualService, DestinationRule, ServiceEntry, Sidecar, EnvoyFilter, WorkloadEntry,
  WorkloadGroup, ProxyConfig, PeerAuthentication, RequestAuthentication, AuthorizationPolicy, Telemetry, WasmPlugin.
- **4장 (참조)**: 링크 미채움.

## 실험 환경 (3장 diff 재현 방법)

- kind Cluster (`kind-kind` context) + Istio **1.24.2** (istiod, ingress/egress gateway 설치됨).
- `default` Namespace: `istio-injection=enabled`. Pod 2개 상주:
  - `mock-server` (app=mock-server, Service `8080` Port) — 받는 쪽(inbound) 실험 대상.
    2026-08-02에 Service의 `9090`(grpc) Port를 제거하여 문서 예제와 클러스터를 일치시켰다
    (원본 백업: /tmp/istio-cr-exp2/backup-svc-mock-server.yaml, Pod의 containerPort 9090은 남아 있으나 무해).
  - `shell` (app=shell) — 보내는 쪽(outbound) 실험 대상.
- Gateway 실험은 `istio-system`의 istio-ingressgateway Pod 대상 (Pod 이름은 `kubectl get pods -n istio-system`으로 확인).
- **주의**: `default`에 상시 운영 중인 `mock-server` VirtualService/DestinationRule이 있다.
  실험 전 백업(`kubectl get vs/dr -o yaml`) 후 삭제하고, 실험이 끝나면 반드시 복원할 것.

## diff 캡처 방법론

1. baseline: `istioctl proxy-config all <pod> -o yaml > base.yaml`
2. CR 적용 → `sleep 4` → after 캡처 → CR 삭제.
3. 노이즈 정규화 (이거 없으면 diff가 수천 줄):
   - **EndpointsConfigDump 섹션 제거** — 캡처마다 순서가 뒤바뀜:
     `awk '/envoy.admin.v3.EndpointsConfigDump/{skip=1;next} skip && /^- .@type.:/{skip=0} !skip'`
   - **last_updated 라인 제거** — push마다 내용이 같아도 갱신됨: `grep -v '^\s*last_updated:'`
   - `version_info` 라인도 push마다 변하는 노이즈 (hunk 선별로 회피).
4. 정규화 후 self-diff(같은 상태 두 번 캡처)가 0줄임을 확인하고 진행.
5. CR 적용 직후 dump에는 **draining 상태의 구 Listener가 함께 남는다** (PeerAuthentication 실험에서
   raw_buffer chain이 남아 보였던 원인). active_state 기준으로 판단할 것. 무변화 검증(WorkloadGroup,
   ProxyConfig)은 직전 실험의 drain이 끝난 뒤(약 1분 대기) 새 baseline을 떠서 비교해야 diff 0이 나온다.
6. Gateway-bound VirtualService diff는 base가 아니라 **Gateway 적용 상태**와 비교한다
   (Gateway 적용 → 캡처 → VS 적용 → 캡처 → 두 캡처를 diff). blackhole → 실제 Virtual Host 교체가 핵심.

## 실험에서 확인된 특이사항

- 이 클러스터의 meshConfig에는 `accessLogFile: /dev/stdout`이 전역 설정되어 있어, Telemetry의
  `envoy` provider는 diff가 안 나온다. `otel` provider(extensionProviders에 정의됨)를 쓰되,
  provider가 가리키는 `opentelemetry-collector.observability.svc.cluster.local` Service가 실제로
  존재해야 istiod가 반영한다 (실험 시 dummy Service 임시 생성 후 삭제했음).
- WorkloadGroup, ProxyConfig는 proxy-config 변화가 없는 것이 정상 (WorkloadGroup은 WorkloadEntry의
  Template, ProxyConfig는 Bootstrap 설정이라 Pod 재생성 시 반영). 문서에 이유를 서술했다.
- RequestAuthentication의 `jwksUri`는 Envoy에 `local_jwks` 인라인으로 반영된다 (istiod가 미리 fetch).
- WasmPlugin은 `oci://ghcr.io/istio-ecosystem/wasm-extensions/basic_auth:1.12.0` 사용. Filter Chain에는
  `config_discovery` 참조가 들어가고 실제 설정은 EcdsConfigDump에 실린다.

## 폴더 구조

- `index.md` — 문서 본문.
- `manifests/<cr이름>/<cr이름>.yaml` — 3장 예제 CR (전부 클러스터에 적용해 검증된 상태).
  workloadentry는 ServiceEntry+WorkloadEntry 2개 리소스가 한 파일에 있음.
  virtualservice에는 mesh용(virtualservice.yaml)과 Gateway-bound용(virtualservice-gateway.yaml) 2개 파일.
- `manifests/base/` — 실험 환경 Workload (mock-server.yaml = Pod+Service, shell.yaml = Pod).
- `images/` — Figure 이미지.
- `envoy_configs/` — CR별 적용 상태의 proxy-config dump 저장소 (manifests와 같은 하위폴더 구조).
  질문/diff 요청 시 클러스터에 다시 실험하지 말고 여기 저장된 dump를 우선 활용할 것.
  - `base/{shell,mock-server,istio-ingressgateway}.yaml` — CR 미적용 baseline (상시 VS/DR 삭제 상태).
  - `<cr이름>/<관찰pod>.yaml` — 해당 CR만 적용된 상태의 dump. diff는 `base/<같은 pod>.yaml`과 뜬다.
    예외: `virtualservice/virtualservice-gateway_istio-ingressgateway.yaml`은 Gateway+VS 적용 상태라
    `gateway/istio-ingressgateway.yaml`과 diff.
  - 모든 dump는 정규화됨 (EndpointsConfigDump 섹션·last_updated·version_info 라인 제거).
  - **주의**: 캡처 간 Listener/Cluster 순서가 뒤바뀔 수 있어 파일 전체 diff에는 재배열 노이즈가 섞인다.
    특정 리소스 이름으로 해당 부분만 발췌해서 비교할 것 (무변화 검증은 `diff <(sort a) <(sort b)`로 가능).
  - `capture.sh` — 재캡처 스크립트 (상시 VS/DR 백업/복원 포함, 약 15분 소요). `_backup/`은 복원용.

## 문서 컨벤션

- Code Block caption: yaml은 `[Config N] <CR> Example`, diff는 `[Diff N] <CR> 적용 전후 <pod>의 proxy-config`.
  번호는 등장 순서 기준 — [Config 1] = 도입부 실험 환경,
  [Config 2] = 3.1의 istio-ingressgateway Service Port 매핑 발췌(diff 없음, 클러스터 실측, Gateway 예시보다 앞에 배치),
  [Config/Diff 3] = 3.1 Gateway, [Config/Diff 4~17] = 3.2~3.14 CR. Diff 2는 없음(Config/Diff 번호는 쌍 기준).
  3.2 VirtualService에는 mesh용([Config/Diff 4])과 Gateway-bound용([Config/Diff 5]) 두 쌍이 있고,
  3.8 WorkloadGroup, 3.9 ProxyConfig는 diff 블록 없음. 전체 diff는 2026-08-02에 8080-only 환경에서 재실측함.
- diff 블록은 unified diff 스타일: 변경 라인(+/-) 앞뒤로 context 라인을 남기고,
  무관한 부분은 `...`으로 표기. 내용은 실측 dump에서 발췌 (창작 금지).
- 리소스 이름/설정값은 백틱(`mock-server`, `lb_policy` 등), 일반 기술 용어는 영어 표기(Listener, Cluster 등).
- YAML 주석은 xDS 이름을 대문자로 (`# SDS: ...`, `# RDS: ...`), 간결하게.
- Istio 언급은 필요한 곳에만 최소화 (envoy-xds-configuration 문서와의 공통 방침).

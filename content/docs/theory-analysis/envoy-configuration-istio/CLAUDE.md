# envoy-configuration-istio 문서 작업 컨텍스트

Istio가 Envoy 설정을 어떻게 만드는지 실측으로 기록하는 문서 (envoy-architecture-istio 문서에서 2026-08-09에 분리됨).
1.1은 CR 없는 기본 Envoy 설정(baseline), 1.2는 Istio CR별 Envoy 설정 변화를 실측 diff로 기록한다.

## 문서 구성 및 상태

- **1장 (Envoy Configuration with Istio)**: 완료. 장 도입부에 실험 환경 yaml([Config 1])과 Workload 설명
  (1.1과 1.2가 공유하는 환경이라 장 바로 아래에 배치).
  - **1.1 (Default Configuration)**: 1.1.1 = Outbound 기본 설정(client Pod 발췌, 기본 HTTP Filter 목록 포함),
    1.1.2 = Inbound 기본 설정(server-a Pod 발췌, listener_filters·Filter Chain·기본 HTTP Filter 목록 포함).
    발췌는 envoy_configs/base/의 실측 dump 기반.
  - **1.2 (Envoy Configuration with Istio and Kubernetes Resources)**:
    1.2.1~1.2.14 = Gateway, VirtualService, DestinationRule, ServiceEntry, Sidecar, EnvoyFilter, WorkloadEntry,
    WorkloadGroup, ProxyConfig, PeerAuthentication, RequestAuthentication, AuthorizationPolicy, Telemetry, WasmPlugin.
- **2장 (참조)**: 링크 미채움.

## 실험 환경 (1.2 diff 재현 방법)

- kind Cluster (`kind-kind` context) + Istio **1.24.2** (istiod, ingress/egress gateway 설치됨).
- `default` Namespace: `istio-injection=enabled`. Pod 4개 상주 (2026-08-17에 mock-server/shell 환경에서 교체,
  구 환경 백업: envoy_configs/_backup/old-env/):
  - `server-a`, `server-b` (Service `8080` http Port) — 같은 Port를 노출하는 Service가 여럿일 때의 설정 확인용.
  - `server-c` (Service `9090` grpc Port) — 다른 Port를 노출하는 Service가 있을 때의 설정 확인용.
    (mock-go-server 이미지는 8080 HTTP·9090 gRPC를 모두 수신한다.)
  - `client` (app=client) — 보내는 쪽(outbound) 실험 대상. 자신은 아무 Port도 열지 않는다.
- 1.2의 CR은 서버 중 **server-a만을 대상으로 적용**한다. Inbound CR은 `server-a` Pod에서,
  Outbound CR은 `client` Pod에서 diff를 관찰한다. server-b/server-c는 CR을 적용하지 않는 대조군이다.
- Gateway 실험은 `istio-system`의 istio-ingressgateway Pod 대상 (Pod 이름은 `kubectl get pods -n istio-system`으로 확인).

## diff 캡처 방법론

1. baseline: `istioctl proxy-config all <pod> -o yaml > base.yaml`
2. CR 적용 → `sleep 4` → after 캡처 → CR 삭제.
3. 노이즈 정규화 (이거 없으면 diff가 수천 줄):
   - **EndpointsConfigDump 섹션 제거** — 캡처마다 순서가 뒤바뀜:
     `awk '/envoy.admin.v3.EndpointsConfigDump/{skip=1;next} skip && /^- .@type.:/{skip=0} !skip'`
   - **last_updated 라인 제거** — push마다 내용이 같아도 갱신됨 (`- last_updated:` 리스트 항목 형태 포함).
   - `version_info` 라인도 push마다 변하는 노이즈.
4. 정규화 후 self-diff(같은 상태 두 번 캡처)가 0줄임을 확인하고 진행.
5. CR 적용 직후 dump에는 **draining 상태의 구 Listener가 함께 남는다** (PeerAuthentication 실험에서
   raw_buffer chain이 남아 보였던 원인. Sidecar 실험에서도 제거된 Listener가 draining_state로 남는다).
   active_state 기준으로 판단할 것. 무변화 검증(WorkloadGroup, ProxyConfig)은 직전 실험의 drain이
   끝난 뒤(약 1분 대기) 새 baseline을 떠서 비교해야 diff 0이 나온다.
6. Gateway-bound VirtualService diff는 base가 아니라 **Gateway 적용 상태**와 비교한다
   (Gateway 적용 → 캡처 → VS 적용 → 캡처 → 두 캡처를 diff). blackhole → 실제 Virtual Host 교체가 핵심.

## 실험에서 확인된 특이사항

- 이 클러스터의 meshConfig에는 `accessLogFile: /dev/stdout`이 전역 설정되어 있어, Telemetry의
  `envoy` provider는 diff가 안 나온다. `otel` provider(extensionProviders에 정의됨)를 쓰되,
  provider가 가리키는 `opentelemetry-collector.observability.svc.cluster.local` Service가 실제로
  존재해야 istiod가 반영한다 (실험 시 dummy Service 임시 생성 후 삭제했음).
- WorkloadGroup, ProxyConfig는 proxy-config 변화가 없는 것이 정상 (WorkloadGroup은 WorkloadEntry의
  Template, ProxyConfig는 Bootstrap 설정이라 Pod 재생성 시 반영). 문서에 이유를 서술했다.
- RequestAuthentication의 `jwksUri`는 istiod가 JWKS를 대신 fetch하여 `local_jwks.inline_string`으로
  xDS 설정에 embed한다.
- WasmPlugin은 `oci://ghcr.io/istio-ecosystem/wasm-extensions/basic_auth:1.12.0` 사용. Filter Chain에는
  `config_discovery` 참조가 들어가고 실제 설정은 EcdsConfigDump에 실린다.
- EnvoyFilter 예시는 `subFilter: envoy.filters.http.router` 기준 INSERT_BEFORE
  (subFilter 미지정 시 배열 맨 앞에 삽입됨은 본문에 설명).
- Sidecar CR(egress를 server-a로 제한)의 제거 단위: Cluster는 Service 단위로 전부 제거,
  `9090`처럼 남는 Service가 없는 Port는 Listener 자체가 제거, `8080`처럼 server-a가 남는 Port는
  Listener는 유지되고 Route Table의 server-b Virtual Host만 제거된다 (1.2.5에 서술).

## 폴더 구조

- `index.md` — 문서 본문.
- `manifests/<cr이름>/<cr이름>.yaml` — 1.2 예제 CR (전부 클러스터에 적용해 검증된 상태).
  workloadentry는 ServiceEntry+WorkloadEntry 2개 리소스가 한 파일에 있음.
  virtualservice에는 mesh용(virtualservice.yaml)과 Gateway-bound용(virtualservice-gateway.yaml) 2개 파일.
- `manifests/base/` — 실험 환경 Workload (server-a/b/c.yaml = Pod+Service, client.yaml = Pod).
- `envoy_configs/` — CR별 적용 상태의 proxy-config dump 저장소 (manifests와 같은 하위폴더 구조).
  질문/diff 요청 시 클러스터에 다시 실험하지 말고 여기 저장된 dump를 우선 활용할 것.
  - `base/{client,server-a,server-b,server-c,istio-ingressgateway}.yaml` — CR 미적용 baseline.
    1.1의 [Config 2], [Config 3] 발췌 원본이기도 하다.
    예외: [Config 2]의 EDS 발췌는 저장된 dump에 없고(정규화로 EndpointsConfigDump 제거),
    2026-08-17에 `istioctl proxy-config all client` 라이브 출력에서 캡처한 것 (server-a Pod IP 10.244.2.4).
  - `<cr이름>/<관찰pod>.yaml` — 해당 CR만 적용된 상태의 dump. diff는 `base/<같은 pod>.yaml`과 뜬다.
    예외: `virtualservice/virtualservice-gateway_istio-ingressgateway.yaml`은 Gateway+VS 적용 상태라
    `gateway/istio-ingressgateway.yaml`과 diff.
  - 모든 dump는 정규화됨 (EndpointsConfigDump 섹션·last_updated·version_info 라인 제거).
  - **주의**: 캡처 간 Listener/Cluster 순서가 뒤바뀔 수 있어 파일 전체 diff에는 재배열 노이즈가 섞인다.
    특정 리소스 이름으로 해당 부분만 발췌해서 비교할 것 (무변화 검증은 `diff <(sort a) <(sort b)`로 가능).
  - `capture.sh` — 재캡처 스크립트 (약 15분 소요). `_backup/old-env/`는 2026-08-17 이전의
    mock-server/shell 환경 백업(복원용이 아니라 기록용).
- 전체 dump는 2026-08-17에 server-a/b/c + client 환경에서 재실측함.

## 문서 컨벤션

- Code Block caption: yaml은 `[Config N] <CR> Example`, diff는 `[Diff N] <CR> 적용 전후 <pod>의 proxy-config`.
  번호는 등장 순서 기준 — [Config 1] = 1장 도입부 실험 환경,
  [Config 2] = 1.1.1 Outbound 기본 설정 발췌, [Config 3] = 1.1.2 Inbound 기본 설정 발췌,
  [Config 4] = 1.2.1의 istio-ingressgateway Service Port 매핑 발췌(Gateway 예시보다 앞에 배치),
  [Config/Diff 5] = 1.2.1 Gateway, [Config/Diff 6~19] = 1.2.2~1.2.14 CR.
  Diff 2~4는 없음(발췌 블록, Config/Diff 번호는 쌍 기준).
  1.2.2 VirtualService에는 mesh용([Config/Diff 6])과 Gateway-bound용([Config/Diff 7]) 두 쌍이 있고,
  1.2.8 WorkloadGroup, 1.2.9 ProxyConfig는 diff 블록 없음.
- diff 블록은 unified diff 스타일: 변경 라인(+/-) 앞뒤로 context 라인을 남기고,
  무관한 부분은 `...`으로 표기. 내용은 실측 dump에서 발췌 (창작 금지).
- 리소스 이름/설정값은 백틱(`server-a`, `lb_policy` 등), 일반 기술 용어는 영어 표기(Listener, Cluster 등).
  단 잘 알려진 컴포넌트 고유명사(Envoy, istiod, pilot-agent, istio-ingressgateway 등)는 평문 — 백틱은 "이 클러스터/dump에 존재하는 리터럴 문자열"(사용자 정의 리소스 이름, 설정 Key/Value)에만.
  code block caption 안에서는 백틱을 쓰지 않는다 (mock-server Pod 등 평문 유지 → 현재는 server-a Pod 등).
- YAML 주석은 영어로, xDS 이름을 대문자로 (`# LDS: ...`, `# RDS: ...`), 간결하게.
- Istio 언급은 필요한 곳에만 최소화 (envoy-configuration-xds 문서와의 공통 방침).

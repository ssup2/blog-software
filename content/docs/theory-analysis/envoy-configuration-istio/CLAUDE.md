# envoy-configuration-istio 문서 작업 컨텍스트

Istio가 Envoy 설정을 어떻게 만드는지 실측으로 기록하는 문서 (envoy-architecture-istio 문서에서 2026-08-09에 분리됨).
1.1은 CR 없는 기본 Envoy 설정(baseline), 1.2는 Kubernetes 리소스별, 1.3은 Istio CR별 Envoy 설정 변화를 실측 diff로 기록한다.

## 문서 구성 및 상태

- **1장 (Envoy Configuration with Istio)**: 완료. 장 도입부에 실험 환경 yaml([Config 1])과 Workload 설명
  (1.1~1.3이 공유하는 환경이라 장 바로 아래에 배치).
  - **1.1 (Default Configuration)**: 1.1.1 = Outbound 기본 설정(client Pod 발췌, 기본 HTTP Filter 목록 포함),
    1.1.2 = Inbound 기본 설정(server-a Pod 발췌, listener_filters·Filter Chain·기본 HTTP Filter 목록 포함).
    발췌는 envoy_configs/base/의 실측 dump 기반.
  - **1.2 (Envoy Configuration with Kubernetes Resources)**: 2026-09-24 신설.
    1.2.1 = Service 신규 Port(LDS/RDS/CDS 생성 + EDS의 targetPort 매핑), 1.2.2 = Service 기존 Port 공유(VH/Cluster만 추가),
    1.2.3 = TCP Service(Port 이름 http→tcp, ClusterIP bind TCP Listener로 교체), 1.2.4 = Pod 증감(EDS만 변화, 무변화는 전체 dump diff 0으로 검증),
    1.2.5 = Headless Service(ORIGINAL_DST Cluster + Pod DNS wildcard domains),
    1.2.6 = ExternalName Service(대상 VH domains에 별칭 4형태 추가, 외부 Host 대상은 diff 0),
    1.2.7 = Selector 없는 Service + 수동 EndpointSlice(임의 IP가 Endpoint로, tlsMode 표식 없음 → Plaintext),
    1.2.8 = ServiceAccount(Cluster SAN 목록 +1줄, service-new-port 상태 위 diff),
    1.2.9 = Node Topology Label(EDS locality 반영, Pod 재등록 필요). 도입부에 [Table 1] 매핑 표.
  - **1.3 (Envoy Configuration with Istio Custom Resources)** (구 1.2, 2026-09-24 개명):
    1.3.1~1.3.14 = Gateway, VirtualService, DestinationRule, ServiceEntry, Sidecar, EnvoyFilter, WorkloadEntry,
    WorkloadGroup, ProxyConfig, PeerAuthentication, RequestAuthentication, AuthorizationPolicy, Telemetry, WasmPlugin.
- **2장 (참조)**: 링크 미채움.

## 실험 환경 (1.2/1.3 diff 재현 방법)

- kind Cluster (`kind-kind` context) + Istio **1.24.2** (istiod, ingress/egress gateway 설치됨).
- `default` Namespace: `istio-injection=enabled`. Pod 4개 상주 (2026-08-17에 mock-server/shell 환경에서 교체,
  구 환경 백업: envoy_configs/_backup/old-env/):
  - `server-a`, `server-b` (Service `8080` http Port) — 같은 Port를 노출하는 Service가 여럿일 때의 설정 확인용.
  - `server-c` (Service `9090` grpc Port) — 다른 Port를 노출하는 Service가 있을 때의 설정 확인용.
    (mock-go-server 이미지는 8080 HTTP·9090 gRPC를 모두 수신한다.)
  - `client` (app=client) — 보내는 쪽(outbound) 실험 대상. 자신은 아무 Port도 열지 않는다.
- 1.3의 CR은 서버 중 **server-a만을 대상으로 적용**한다. Inbound CR은 `server-a` Pod에서,
  Outbound CR은 `client` Pod에서 diff를 관찰한다. server-b/server-c는 CR을 적용하지 않는 대조군이다.
- Gateway 실험은 `istio-system`의 istio-ingressgateway Pod 대상 (Pod 이름은 `kubectl get pods -n istio-system`으로 확인).
- 1.2의 Kubernetes 리소스 실험은 모두 `client` Pod에서 관찰하며, 일시적 리소스(`server-d` Pod/Service,
  `server-a-2` Pod)를 적용→캡처→삭제한다. **2026-09-24 캡처 시점에는 클러스터에 문서 환경 외 잉여
  Workload(httpbin, mock-server 8080/9090/8081, my-shell, shell)가 상주**했기 때문에 1.2의 diff는 구
  envoy_configs/base/가 아니라 같은 시점에 뜬 envoy_configs/kubernetes/base/와 비교해야 한다.
  잉여 Service가 상수로 유지되므로 diff의 +/- 라인에는 나타나지 않고, 본문 발췌에서는 `...`으로 걸렀다.

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

- ExternalName Service는 alias 모드(1.24 기본)라 대상이 Mesh 내부 Service면 그 VH의 domains에만
  별칭이 추가되고, 대상이 Mesh에 없는 외부 Host면 설정 변화가 아예 없다 (diff 0 실측).
- Node Topology Label은 이미 등록된 Endpoint에 소급 반영되지 않는다 (Label 후 EDS diff 0 실측).
  Pod를 재생성해 Endpoint를 재등록해야 반영된다. 이때 한쪽 Node에만 Label을 붙이면 재생성된 Pod가
  Label 없는 다른 Node로 스케줄될 수 있으므로 (실제로 겪음), 두 Worker Node 모두에 Label을 붙인다
  (zone은 kind-worker=zone-a, kind-worker2=zone-b로 상이하게).
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
  Listener는 유지되고 Route Table의 server-b Virtual Host만 제거된다 (1.3.5에 서술).

## 폴더 구조

- `index.md` — 문서 본문.
- `manifests/istio/<cr이름>/<cr이름>.yaml` — 1.3 예제 CR (전부 클러스터에 적용해 검증된 상태, 2026-09-24에 istio/ 하위로 이동).
  workloadentry는 ServiceEntry+WorkloadEntry 2개 리소스가 한 파일에 있음.
  virtualservice에는 mesh용(virtualservice.yaml)과 Gateway-bound용(virtualservice-gateway.yaml) 2개 파일.
- `manifests/kubernetes/<실험이름>/<실험이름>.yaml` — 1.2 실험 리소스 (service-new-port, service-protocol-tcp,
  service-shared-port, pod-endpoint, service-headless, service-externalname, service-endpointslice,
  serviceaccount). service-protocol-tcp와 serviceaccount는 service-new-port 상태 위에 덮어 적용하는 파일이고,
  service-externalname에는 외부 Host 변형(service-externalname-external.yaml)이 함께 있다.
  1.2.9 Node 실험은 Manifest 없이 capture-kubernetes.sh의 kubectl label로 수행한다.
- `manifests/base/` — 실험 환경 Workload (server-a/b/c.yaml = Pod+Service, client.yaml = Pod).
- `envoy_configs/` — CR별 적용 상태의 proxy-config dump 저장소 (CR 폴더는 최상위에 그대로,
  manifests만 istio/ 하위로 이동한 상태라 계층이 1단계 다름).
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
  - `capture.sh` — 1.3(CR) 재캡처 스크립트 (약 15분 소요). `_backup/old-env/`는 2026-08-17 이전의
    mock-server/shell 환경 백업(복원용이 아니라 기록용).
  - `kubernetes/` — 1.2 실험 dump (2026-09-24 실측). `base/client.yaml`이 1.2 전용 baseline이고,
    `<실험이름>/client.yaml`은 정규화 dump, `client-eds*.yaml`은 raw dump의 EndpointsConfigDump 섹션
    (정규화가 EDS를 제거하므로 EDS 관찰 실험만 별도 저장). diff 상대는 `kubernetes/base/client.yaml`,
    단 service-protocol-tcp는 service-new-port/client.yaml과 diff.
  - `capture-kubernetes.sh` — 1.2 재캡처 스크립트 (약 20분 소요). service-new-port ↔ service-protocol-tcp는
    같은 Service 인스턴스에서 연속 캡처해야 ClusterIP/Pod IP가 일치한다 (본문 [Diff 4]/[Config 5]/[Diff 8]의
    IP 10.96.121.134, 10.244.2.11이 서로 맞물려 있음). Listener 교체/삭제 후에는 75s drain 대기.
    diff 상대: service-protocol-tcp와 serviceaccount는 각자의 직전 상태(service-new-port 캡처/client-before)와,
    node-locality는 client-eds-before ↔ client-eds-after끼리, 나머지는 kubernetes/base/client.yaml과 diff.
- 1.3 전체 dump는 2026-08-17에 server-a/b/c + client 환경에서 재실측함. 1.2 dump는 2026-09-24 실측
  (잉여 Workload 상주 환경, 위 실험 환경 절 참고).

## 문서 컨벤션

- Code Block caption: yaml은 `[Config N] <이름> Example/Manifest`, diff는 `[Diff N] <변경> 전후 <pod>의 proxy-config`.
  번호는 등장 순서 기준 — [Config 1] = 1장 도입부 실험 환경,
  [Config 2] = 1.1.1 Outbound 기본 설정 발췌, [Config 3] = 1.1.2 Inbound 기본 설정 발췌,
  [Config/Diff 4] = 1.2.1 Service 신규 Port, [Config 5] = 1.2.1의 EDS Endpoint 발췌,
  [Config/Diff 6] = 1.2.2 Service 기존 Port 공유, [Config/Diff 7] = 1.2.3 TCP Service,
  [Config/Diff 8] = 1.2.4 Pod, [Config/Diff 9] = 1.2.5 Headless Service,
  [Config/Diff 10] = 1.2.6 ExternalName, [Config 11/12] = 1.2.7 Selector 없는 Service의 Manifest/EDS 발췌,
  [Config/Diff 13] = 1.2.8 ServiceAccount, [Config/Diff 14] = 1.2.9 Node,
  [Config 15] = 1.3.1의 istio-ingressgateway Service Port 매핑 발췌(Gateway 예시보다 앞에 배치),
  [Config/Diff 16] = 1.3.1 Gateway, [Config/Diff 17~30] = 1.3.2~1.3.14 CR.
  Diff 2, 3, 5, 11, 12, 15는 없음(발췌 블록, Config/Diff 번호는 쌍 기준).
  1.3.2 VirtualService에는 mesh용([Config/Diff 17])과 Gateway-bound용([Config/Diff 18]) 두 쌍이 있고,
  1.3.8 WorkloadGroup, 1.3.9 ProxyConfig는 diff 블록 없음.
  [Table 1] = 1.2 Kubernetes 리소스 매핑 표, [Table 2] = 1.3 Istio CR 매핑 표.
- diff 블록은 unified diff 스타일: 변경 라인(+/-) 앞뒤로 context 라인을 남기고,
  무관한 부분은 `...`으로 표기. 내용은 실측 dump에서 발췌 (창작 금지).
- 리소스 이름/설정값은 백틱(`server-a`, `lb_policy` 등), 일반 기술 용어는 영어 표기(Listener, Cluster 등).
  단 잘 알려진 컴포넌트 고유명사(Envoy, istiod, pilot-agent, istio-ingressgateway 등)는 평문 — 백틱은 "이 클러스터/dump에 존재하는 리터럴 문자열"(사용자 정의 리소스 이름, 설정 Key/Value)에만.
  code block caption 안에서는 백틱을 쓰지 않는다 (mock-server Pod 등 평문 유지 → 현재는 server-a Pod 등).
- YAML 주석은 영어로, xDS 이름을 대문자로 (`# LDS: ...`, `# RDS: ...`), 간결하게.
- Istio 언급은 필요한 곳에만 최소화 (envoy-configuration-xds 문서와의 공통 방침).

# envoy-architecture-istio 문서 작업 컨텍스트

문서 제목: "Envoy Architecture with Istio" (구 "Envoy with Istio", 폴더명도 envoy-istio에서 2026-08-09에 변경).

Istio 환경에서 Envoy가 배치되는 구조를 다루는 문서.
CR별 Envoy 설정 변화(실측 diff)는 2026-08-09에 **envoy-configuration-istio** 문서로 분리했다
(../envoy-configuration-istio/ — 실험 환경, manifests/, envoy_configs/, 캡처 방법론도 함께 이동).

## 문서 구성 및 상태

- **1장 (Envoy as Sidecar Proxy)**: 완료. Pod 내부 Traffic 흐름 + pilot-agent를 xDS Proxy로 두는 이유.
  Metrics 수집(직접/병합)·DNS Lookup(Capture on/off)·Probe(Envoy/App)를 케이스별 하위 항목으로 서술 (2026-08-15, Figure 갱신 반영).
- **TODO**: `images.pptx`의 `/app-health/app/readys` 표기는 오타 — 실제 Istio Rewrite 경로는 `/app-health/<container>/readyz`. 문서 본문은 `readyz`로 적어둠. pptx 수정 후 PNG 재추출 필요.
- **2장 (Envoy as Ingress Gateway)**: 2026-08-16에 Ingress/Egress 통합 장에서 분리, Figure 2 추가. 공통 구조(router 모드) + Inbound Traffic 흐름 + status-port(외부 LB Health Check용)·`31400`·`15443` 설명.
  "빈 Envoy로 시작 + Gateway CR의 Listener 생성 + Port 결정 규칙(`targetPort` 번역, 실측 완료)" 문단은 2026-08-16에 본문에서 제거 — envoy-configuration-istio 문서로 옮길 후보.
- **3장 (Envoy as Egress Gateway)**: 2026-08-16 분리, Figure 3 추가. ingress와 내부 구조 동일(실측: Deployment args·Envoy bootstrap/Listener/Cluster diff 0) + `ClusterIP`·Port 축소 + Outbound Traffic 흐름.
  ingress/egress 차이는 노출 계층에만 존재: Service Type, Service Port 구성(ingress만 `15021` status-port·`31400`·`15443` 노출), containerPort 선언, Label.
  `31400`은 raw TCP 입구, `15443`은 SNI Passthrough 입구(Multi-cluster east-west). TCP Server는 Gateway CR만으로 Listener가 안 열리고 tcp VirtualService Route까지 있어야 열림(실측).
- **4장 (참조)**: 링크 미채움.

## 폴더 구조

- `index.md` — 문서 본문.
- `images/` — Figure 이미지 (envoy-istio-sidecar.png, envoy-istio-ingress-gateway.png, envoy-istio-egress-gateway.png). gateway-figure-draft.md는 Figure 2/3 작도용 초안으로 이제 삭제 가능.

## 문서 컨벤션

- 백틱 기준: "복사해서 붙여넣을 수 있는 리터럴 값"만 백틱 — Port 번호, Path, Socket 주소, 설정 Key/Value(`enablePrometheusMerge: true`, `selector`, `targetPort`), Annotation, Label, 명령어/인자. 문장의 구성 요소로 쓰이는 이름(istiod, pilot-agent, Envoy, istio-proxy Container 등)은 평문. 같은 단어라도 용법으로 구분 (예: Type 값 `LoadBalancer`는 백틱, 장비를 가리키는 LoadBalancer는 평문).
- 일반 기술 용어는 영어 표기(Listener, Cluster 등).
- 볼드 강조: 케이스를 구분 짓거나 문단의 결론이 되는 핵심 구절만 문단당 1~2개 (예: "**외부로 보내는 요청**은" ↔ "**다른 App Pod로부터 들어오는 요청**은"). 조사는 볼드 밖에 둔다.
- Istio 언급은 필요한 곳에만 최소화 (envoy-configuration-xds 문서와의 공통 방침).

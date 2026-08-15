# envoy-architecture-istio 문서 작업 컨텍스트

문서 제목: "Envoy Architecture with Istio" (구 "Envoy with Istio", 폴더명도 envoy-istio에서 2026-08-09에 변경).

Istio 환경에서 Envoy가 배치되는 구조를 다루는 문서.
CR별 Envoy 설정 변화(실측 diff)는 2026-08-09에 **envoy-configuration-istio** 문서로 분리했다
(../envoy-configuration-istio/ — 실험 환경, manifests/, envoy_configs/, 캡처 방법론도 함께 이동).

## 문서 구성 및 상태

- **1장 (Envoy as Sidecar Proxy)**: 완료. Pod 내부 Traffic 흐름 + pilot-agent를 xDS Proxy로 두는 이유.
  Metrics 수집(직접/병합)·DNS Lookup(Capture on/off)·Probe(Envoy/App)를 케이스별 하위 항목으로 서술 (2026-08-15, Figure 갱신 반영).
- **TODO**: `images.pptx`의 `/app-health/app/readys` 표기는 오타 — 실제 Istio Rewrite 경로는 `/app-health/<container>/readyz`. 문서 본문은 `readyz`로 적어둠. pptx 수정 후 PNG 재추출 필요.
- **2장 (Envoy as Ingress/Egress Gateway)**: 초안 작성됨 (2026-08-09). 공통 구조(router 모드, 빈 Envoy) + Ingress/Egress 차이(Service 노출·Label·Traffic 흐름)를 소절 없이 한 장에 서술. ingress/egress 동일성은 클러스터 실측으로 검증됨(Deployment args·Envoy bootstrap/Listener/Cluster diff 0, 2026-08-15 재확인).
  차이는 노출 계층에만 존재: Service Type, Service Port 구성(ingress만 `15021` status-port·`31400`·`15443` 노출), containerPort 선언, Label. status-port는 외부 LB Health Check용 — 본문 "Service 노출"에 반영됨. Figure 미추가.
- **3장 (참조)**: 링크 미채움.

## 폴더 구조

- `index.md` — 문서 본문.
- `images/` — Figure 이미지 (envoy-istio-sidecar.png).

## 문서 컨벤션

- 백틱 기준: "복사해서 붙여넣을 수 있는 리터럴 값"만 백틱 — Port 번호, Path, Socket 주소, 설정 Key/Value(`enablePrometheusMerge: true`, `selector`, `targetPort`), Annotation, Label, 명령어/인자. 문장의 구성 요소로 쓰이는 이름(istiod, pilot-agent, Envoy, istio-proxy Container 등)은 평문. 같은 단어라도 용법으로 구분 (예: Type 값 `LoadBalancer`는 백틱, 장비를 가리키는 LoadBalancer는 평문).
- 일반 기술 용어는 영어 표기(Listener, Cluster 등).
- 볼드 강조: 케이스를 구분 짓거나 문단의 결론이 되는 핵심 구절만 문단당 1~2개 (예: "**외부로 보내는 요청**은" ↔ "**다른 App Pod로부터 들어오는 요청**은"). 조사는 볼드 밖에 둔다.
- Istio 언급은 필요한 곳에만 최소화 (envoy-configuration-xds 문서와의 공통 방침).

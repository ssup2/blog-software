# istio-gateway-api-inference-extension 문서 작업 컨텍스트

Istio의 Gateway API Inference Extension 구현을 분석하는 문서. 본문 기준 Version: Istio 1.31, Gateway API Inference Extension v1.6.
2026-09-20 실측 완료. Test는 별도 섹션 없이 본문 각 섹션에 녹임 (istio-gateway-api 문서와 동일 포맷).

## 문서 구성 및 상태

- 1.1 Test 환경 구축: Shell 1(환경 구성), File 1(Test Workload — sim/EPP/Service/DestinationRule),
  File 2(InferencePool/HTTPRoute), Shell 2(Test Workload 목록 — Pod IP·Headless Shadow Service 포함),
  Shell 3(InferencePool 상태 — Accepted/ResolvedRefs Condition).
  본문 [File 1]은 manifests/ 원본에서 sim의 env(POD_NAME 등)·resources, EPP의 probe·9003/9090 Port, RBAC을 축약한 버전.
  재현은 manifests/ 원본 기준 (sim의 POD_NAME env가 없으면 응답의 x-inference-pod Header 값이 달라질 수 있음).
  1.2 InferencePool 변환: Shell 4(Shadow Cluster/Endpoint, 설명은 Shell 2의 Service 목록을 교차 참조).
  1.3 요청 처리 과정: Shell 5(ext-proc per-route 설정), Shell 6(curl 요청), Shell 7(Override Host Policy).
  1.4 Envoy Gateway 구현과 비교: 이론만.
  Shell 2의 AGE 21m, Shell 3의 AGE 40m은 각각의 캡처 시점 값.
- 본문 Shell 출력은 전부 실측 발췌. 초기 초안의 [File 1](ext-proc 설정 예시)은 창작이어서 Shell 3 실측으로 교체됨.
- 실측으로 확인·수정된 사실:
  - Shadow Service Cluster의 Port는 Target Port가 아니라 **고정 가상 Port 54321** (초안의 `outbound|[Target Port]||` 서술을 수정함). Target Port는 Endpoint에 반영.
  - Shadow Service는 istiod 내부 개념이 아니라 **실제 Headless Service(ClusterIP: None, Port 54321)로 Kubernetes에 생성됨** (`kubectl get svc -n llm-namespace`로 확인 가능).
  - EPP가 반환한 Endpoint는 Header가 아니라 `envoy.lb` Dynamic Metadata의 `x-gateway-destination-endpoint` Key로 Override Host Policy가 참조. Fallback은 Round Robin.
    Listener의 ext_proc Filter에 `metadataOptions.receivingNamespaces: [envoy.lb]`가 설정되어 EPP 응답의 Metadata가 수신됨 (2026-09-20 재검증에서 확인, 본문 도입부·1.2의 "Header로 반환" 서술을 Metadata로 수정함).
  - Shadow Service는 selector/Target Port가 InferencePool의 것으로 설정된 채 생성되며 ownerReference가 InferencePool로 걸려 있음. Endpoint 등록은 Service selector에 의한 표준 동작.
  - `FailOpen` → `failureModeAllow: true` 변환 확인.
  - v1.6부터 release image는 `epp`가 없고 `lwepp`(Lightweight EPP)만 존재 (registry.k8s.io/gateway-api-inference-extension/lwepp:v1.6.2, amd64 전용 — OrbStack Rosetta로 kind에서 실행됨).
- Figure 1(istio-inference-gateway.png, 2개 Model 구성) 제작 완료. Figure 2(요청 처리 과정)는 본문에서 제거됨.

## Test 환경 (재현 방법)

- istio-gateway-api 문서와 **동일한 kind Cluster 공유** (`kind-istio-gateway-api` context). 해당 문서의 CLAUDE.md 참조.
  istiod는 이 문서 실측 시 `SUPPORT_GATEWAY_API_INFERENCE_EXTENSION=true`, `ENABLE_GATEWAY_API_INFERENCE_EXTENSION=true`로 재설치된 상태.
- Inference Extension CRD: `kubectl apply -f https://github.com/kubernetes-sigs/gateway-api-inference-extension/releases/download/v1.6.2/manifests.yaml`
- 적용 순서: `manifests/namespace.yaml` → `manifests/base/`(vLLM Simulator, ghcr.io/llm-d/llm-d-inference-sim:v0.7.1 multi-arch)
  → `manifests/epp/`(lwepp Deployment+Service+DestinationRule+RBAC) → `manifests/inferencepool.yaml` → `manifests/httproute.yaml`
- Gateway는 istio-gateway-api 문서의 `gateway-namespace`/`gateway`(hostname `*.ssup2.com`)를 재사용. 요청 테스트는
  `kubectl -n gateway-namespace port-forward svc/gateway-istio 8080:80` 후 `curl -H "Host: llm.ssup2.com" http://127.0.0.1:8080/v1/completions -d '{"model": "reviews-1", ...}'`.
- EPP는 기본으로 TLS(secure-serving)라서 DestinationRule(SIMPLE, insecureSkipVerify)이 없으면 ext-proc 연결이 실패한다.
- Shadow Service 이름의 Hash(`vllm-llama3-8b-ip-22dc7de1`)와 Gateway Pod 이름은 재생성 시 달라지므로 재실측 시 본문 Shell 교체 필요.

## 폴더 구조

- `index.md` — 문서 본문.
- `manifests/namespace.yaml` — llm-namespace.
- `manifests/base/vllm-sim.yaml` — vLLM Simulator Deployment (app=vllm-llama3-8b, 3 replicas, port 8000, lora `reviews-1`).
- `manifests/epp/epp.yaml` — Lightweight EPP Deployment/Service(9002 http2)/DestinationRule(TLS)/RBAC.
- `manifests/inferencepool.yaml` — InferencePool vllm-llama3-8b (targetPorts 8000, endpointPickerRef 9002, FailOpen).
- `manifests/httproute.yaml` — llm-route (hostname llm.ssup2.com → InferencePool backendRef).

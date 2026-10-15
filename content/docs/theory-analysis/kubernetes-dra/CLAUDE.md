# kubernetes-dra 문서 작업 컨텍스트

Kubernetes DRA (Dynamic Resource Allocation)의 구조와 동작(Resource API, 등록, Scheduling, 준비)을 분석하는 문서.
kubernetes-hami 문서의 배경 글 (Device Plugin 한계와 그 표준 해결책 관점). kubernetes-scheduler 문서와 같은 시기에 작성됨.

## 문서 구성 및 상태

- **2026-10-13 이론 초안 작성** (Claude 작성, 사용자 검토 전, frontmatter `draft: true`). **실측 없음** — Shell 블록 없음,
  File 1(ResourceClaimTemplate+Pod 예제)은 문서 기반. index.en.md는 초안 확정 전이라 미작성.
- 1장 구성: 1. 개요(Device Plugin 한계와 DRA, Component 3종) / 1.1 Resource API(Table 1, File 1) /
  1.2 Device 등록 과정(ResourceSlice 게시) / 1.3 Device Scheduling 과정(DynamicResources Plugin, Structured Parameters) /
  1.4 Device 준비 과정(NodePrepareResources, CDI) / 1.5 Device Plugin 비교(Table 2, HAMi 연결).
- **사실 검증 필요 목록** (기억 기반 초안):
  - DRA GA 버전: Kubernetes 1.34에서 resource.k8s.io/v1 GA로 서술 — 재확인 필요.
  - [File 1]의 API 구조: ResourceClaimTemplate의 `spec.spec.devices.requests[].exactly{deviceClassName, selectors}` 필드와
    CEL 표현식(`device.capacity['gpu.nvidia.com'].memory.compareTo(quantity('40Gi')) >= 0`) 문법 — NVIDIA Driver의
    실제 attribute/capacity Key 이름 확인 필요.
  - ResourceClaim Controller의 소속 (kube-controller-manager) 확인.
  - kubelet Plugin gRPC 이름 `NodePrepareResources()`/`NodeUnprepareResources()`와 Plugin Registration 경로
    (/var/lib/kubelet/plugins_registry) 확인.
  - DynamicResources Plugin이 동작하는 Extension Point (PreFilter/Filter/Reserve/PreBind 등) — 본문은 Filter 중심으로
    단순화하여 서술함, 정확한 지점 확인 후 보강 여부 검토.
  - 초기 Alpha의 Control Plane Controller 방식("Classic DRA")이 제거된 버전 확인.
  - 참조의 DRA GA Blog URL(kubernetes.io/blog/2025/08/27/...)은 추정 — 유효성 확인 필요.
  - NVIDIA DRA Driver(k8s-dra-driver-gpu)의 MIG 동적 생성 지원 서술 확인 — 2026-10-15 웹 리서치로 확인됨
    (`DynamicMIG` Feature Gate Alpha, KEP-4815 기반). 저장소는 CNCF 기증으로 kubernetes-sigs/dra-driver-nvidia-gpu로
    이관되어 참조 URL 갱신함. 상세 분석은 kubernetes-nvidia-dra-driver 문서(2026-10-15 초안)에 있음.
- Figure 1~4 (dra-architecture/dra-device-registration/dra-device-scheduling/dra-device-preparation.png)는
  2026-10-13에 matplotlib로 생성한 **초안** — 사용자가 pptx 스타일로 다시 그릴 예정 (파일명 유지한 채 교체).
  images/images.pptx는 아직 없음.

## Test 계획 (미수행)

- GPU 없이도 kind + DRA example driver(https://github.com/kubernetes-sigs/dra-example-driver)로 실측 가능:
  ResourceSlice 내용, ResourceClaim의 status.allocation, Pod 환경에서 CDI 주입 결과 확인 등.
- NVIDIA GPU Node가 있으면 NVIDIA DRA Driver로 실측 (GPU 속성 기반 CEL Selector, MIG 동적 생성).
- 실측 완료 시 본문에 [Shell N] 블록을 실측 발췌로 추가하고 manifests/ 폴더에 재현 파일을 남길 것 (repo 컨벤션).

## 폴더 구조

- `index.md` — 문서 본문 (ko 초안).
- `images/` — matplotlib 초안 Figure 4종.

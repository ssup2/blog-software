# kubernetes-hami-dra 문서 작업 컨텍스트

HAMi의 vGPU 기능을 DRA 표준 위에서 제공하는 HAMi DRA의 구조와 동작(등록, Scheduling, 할당)을 분석하는 문서.
kubernetes-hami(Device Plugin 방식)와 kubernetes-dra(DRA 표준)의 후속 글이며, 두 글과 동일한 포맷(Architecture → 등록 → Scheduling → 할당 → 비교)으로 작성.
kubernetes-nvidia-dra-driver 문서와 같은 시기(2026-10-15)에 작성됨. 배경 글 모두 draft 상태 — 발행 시 상호 참조 링크 유지 여부 확인.
2026-10-16에 HAMi 글이 3부작으로 분리됨: kubernetes-hami(HAMi 자체) / kubernetes-hami-nvidia-gpu(NVIDIA GPU 기능 + MIG) /
kubernetes-hami-dra(이 글). HAMi-core 격리 상세는 kubernetes-hami-nvidia-gpu에 있음 (참조 링크 추가함).

## 문서 구성 및 상태

- **2026-10-15 이론 초안 작성** (Claude 작성, 사용자 검토 전, frontmatter `draft: true`). **실측 없음** — Shell 블록 없음,
  File 1~2는 HAMi 문서·k8s-dra-driver 소스 기반. index.en.md는 초안 확정 전이라 미작성.
- 1장 구성: 1. 개요(Component 4종, Consumable Capacity Table, ResourceClaim 예제) / 1.1 vGPU 등록 과정(ResourceSlice,
  allowMultipleAllocations) / 1.2 vGPU Scheduling 과정(DynamicResources Plugin, Webhook 변환, 제약) /
  1.3 vGPU 할당 과정(NodePrepareResources, CDI, ld.so.preload) / 1.4 Device Plugin 방식 비교(Table 2).
- 초안의 사실 관계는 2026-10-15 웹 리서치(HAMi 공식 문서/블로그, k8s-dra-driver 소스, 릴리스 노트) 기반. **사실 검증 필요 목록**:
  - 버전 타임라인: v2.8.0(2026-01) DRA 도입, v2.9.0(2026-05) NVIDIA ready for use, v2.10.0(2026-08) 본체 Chart에서 분리 — 릴리스 노트 재확인.
  - DeviceClass/Driver 이름 `hami-core-gpu.project-hami.io`, Device 이름 `hami-gpu-<minor>` — chart template 기반.
  - Capacity Key `cores`(총량 100, step 1, 기본값 100), `memory`(총량 = 물리 VRAM, step 1Mi, 기본값 전체) — requestPolicy 상세는 본문에서 생략함.
  - CDI 주입 환경 변수의 정확한 형태: 소스상 `CUDA_DEVICE_MEMORY_LIMIT_<idx>`, `CUDA_DEVICE_SM_LIMIT_<idx>` (Device index suffix)와
    `CUDA_DEVICE_MEMORY_SHARED_CACHE` — 본문은 suffix 없이 단순화하여 서술함, 실측 후 보강 여부 검토.
  - `LD_PRELOAD` 환경 변수 대신 `/etc/ld.so.preload` 파일 Mount 방식 — k8s-dra-driver의 cmd/hami-kubelet-plugin/hami_core.go 기반.
  - GPU Device File 주입이 NVIDIA Container Runtime의 `accept-nvidia-visible-devices-as-volume-mounts=true` 설정에 의존 — 본문에서 생략함.
  - `DRAConsumableCapacity` Feature Gate: 1.34 Alpha, 1.35 Alpha 유지, 1.36 Beta 기본 활성 — 본문은 "1.34 Alpha 도입"만 서술.
  - webhook의 ResourceClaimTemplate 변환 모드(`webhook.config.resourceClaimTemplate: true`, Kueue 연동용)와 다중 vendor
    (`deviceVendors`) 지원 — 본문에서 생략함.
  - Device Plugin 방식과 동시 운용 금지, binpack/spread·topology 정책 부재 — HAMi 블로그(does-kubernetes-dra-replace-hami) 기반.
  - Ascend NPU용 DRA Driver(ascend-dra-driver) 존재, Hygon은 자체 Driver를 webhook으로 연동 — 본문은 Ascend만 언급.
- Figure 1~4 (hami-dra-architecture/hami-dra-vgpu-registration/hami-dra-vgpu-scheduling/hami-dra-vgpu-allocation.png)는
  2026-10-15에 matplotlib로 생성한 **초안** — 사용자가 pptx 스타일로 다시 그릴 예정 (파일명 유지한 채 교체). images/images.pptx는 아직 없음.

## Test 계획 (미수행)

- GPU Node가 있는 환경 필요 (Kubernetes 1.34+ 및 `DRAConsumableCapacity` Feature Gate 활성화, CDI 지원 containerd,
  NVIDIA Container Runtime 기본 Runtime + `accept-nvidia-visible-devices-as-volume-mounts=true`, cert-manager).
- 설치: `helm repo add hami-dra https://project-hami.github.io/HAMi-DRA` → `helm install hami-dra hami-dra/hami-dra`
  (Host 설치 Driver는 `--set drivers.nvidia.containerDriver=false`). hami-system Namespace에 driver/webhook/monitor Pod 확인.
- 실측 시나리오 후보: `kubectl get resourceslices` 출력(allowMultipleAllocations, cores/memory capacity), ResourceClaim 생성 후
  `status.allocation`, 같은 GPU에 2개 Claim 할당, Container 환경 변수(`kubectl exec env`)와 `/etc/ld.so.preload`,
  `nvidia-smi` Memory 크기, webhook의 Extended Resource → ResourceClaim 변환 결과.
- 실측 완료 시 본문에 [Shell N] 블록을 실측 발췌로 추가하고 manifests/ 폴더에 재현 파일을 남길 것 (repo 컨벤션).

## 폴더 구조

- `index.md` — 문서 본문 (ko 초안).
- `images/` — matplotlib 초안 Figure 4종.

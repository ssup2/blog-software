# kubernetes-hami 문서 작업 컨텍스트

HAMi 자체(이기종 AI 가속기 가상화 Middleware)에 포커스를 두고 Architecture와 공통 동작 원리(등록 → Scheduling → 할당)를
분석하는 문서. NVIDIA GPU는 예시로만 이용한다. **2026-10-16에 글을 3개로 분리**:

- kubernetes-hami (이 글) — HAMi 자체, 벤더 중립 구조
- kubernetes-hami-nvidia-gpu — NVIDIA GPU 기능 (vGPU 설정, HAMi-core 격리, GPU 선택, Dynamic MIG)
- kubernetes-hami-dra — HAMi의 DRA 구현

세 글 모두 draft 상태. 분리 전 글(2026-10-09 초안)의 HAMi-core 격리 섹션과 vGPU Resource Table은 kubernetes-hami-nvidia-gpu로 이동함.

## 문서 구성 및 상태

- **2026-10-16 재작성** (Claude 작성, 사용자 검토 전, frontmatter `draft: true`). **실측 없음** — Shell 블록 없음.
  index.en.md는 초안 확정 전이라 미작성.
- **2026-10-31 Library 중심 구성 탈피** (사용자 피드백: Library 가상화 중심으로 나머지 기법이 끼어든 구성): ① 개요의 세 번째
  구성 요소를 "격리 Library"에서 **"격리 계층"**으로 일반화 (Library/Driver/Hardware 세 수준 명시, NVIDIA Library는 예시로 격하.
  "Component 3종" → "요소 3종") ② Table 1 문단의 세 계층 정의 문장을 "[Table 1]에 함께 표시" 한 줄로 축약 (정의는 개요
  개조식·상세는 1.3으로 일원화) ③ 1.3 할당 단계 3·4를 계층 중립으로 수정 (3: "격리 설정 반환, 내용은 계층에 따라 다름 —
  NVIDIA는 env+LD_PRELOAD" / 4: "격리 계층이 제한을 강제"). **Figure 1 재작도 시 세 번째 블록명도 "격리 Library" →
  "격리 계층"으로 변경 필요.**
- 1장 구성: 1. 개요(요소 3종: hami-scheduler/Device Plugin/격리 계층, 지원 가속기 Table(격리 계층 열 포함), vGPU Pod 예시) /
  1.1 Device 등록 과정(부풀리기 + Node Annotation) / 1.2 Device Scheduling 과정(Webhook, Extender, 정책) /
  1.3 Device 할당 과정(Pod Annotation 참조, 격리 Library 주입).
- 사실 관계는 2026-10-16 웹 리서치(HAMi master 소스 b385c82, charts/hami/values.yaml, 공식 docs) 기반. **사실 검증 필요 목록**:
  - CNCF 이력: Sandbox 2024-08, Incubating 2026-07 (TOC 통과 07-02, 발표 블로그 07-15). 최신 릴리스 v2.10.0 (2026-08-21).
  - [Table 1] 가속기별 Resource 이름 — v2.10.0 기준 14종 중 10종만 수록, Biren/Vastai(개수 전용)/Teco(검증 중)/원격 GPU는 생략.
    Iluvatar Resource 이름은 칩별(`MR-V100`, `BI-V150` 등)이며 Table에는 MR-V100만 예시로 수록.
  - Node Annotation 패턴: NVIDIA `hami.io/node-nvidia-register`, Ascend `hami.io/node-register-<칩>`, AMD `hami.io/node-amd-register` 등
    벤더마다 어순이 달라 본문은 "`hami.io/node-[가속기]-register` 계열"로 뭉뚱그림. Cambricon/Moore Threads는 Annotation 없이
    Node Capacity 참조 (소스 GetNodeDevices 기반).
  - Pod Annotation 패턴: `hami.io/<commonWord>-devices-allocated` (예: `hami.io/Ascend910B3-devices-allocated`),
    NVIDIA는 legacy 이름 `hami.io/vgpu-devices-allocated`. 공통 bookkeeping: `hami.io/vgpu-node`, `hami.io/bind-phase` (본문 생략).
  - 정책 기본값: Node `binpack`, Device `spread` (values.yaml 기준). v2.10의 조합 정책(mutex 등)은 NVIDIA 글에서 다룸.
  - Webhook 동작: 등록된 모든 벤더 Resource 검사, `hami.io/webhook: ignore` Label 제외, privileged Container 거부 — 본문은 일부 생략.
  - 가속기별 Resource 등록은 `hami-scheduler-device` ConfigMap(`device-config.yaml`)에 정의, Helm `devices.<vendor>.enabled`로 활성화.
  - 격리 방식 3분류 — **2026-10-31 웹 리서치로 검증·본문 1.3에 개조식 추가**. 분류 축은 사용자 피드백으로 "격리가 수행되는
    계층"(Library → Driver → Hardware, 아래로 갈수록 격리↑ 유연성↓)으로 재구성: ① API 가로채기(NVIDIA HAMi-core libvgpu.so,
    AMD libamvgpu.so — AMD 상세는 여전히 재확인 필요) ② Ascend vNPU Template: Project-HAMi/ascend-device-plugin의
    ascend-device-configmap.yaml 기준 910B3(aiCore 20, 64GB)는 vir05_1c_16g(5core/16G)·vir10_3c_32g(10core/32G) 2종,
    hamiVnpuMode: template, 요청 Memory를 수용하는 최소 Template으로 올림. libvnpu.so 기반 soft 분할 Mode도 존재(본문 미기재)
    ③ Cambricon dynamic-smlu: 제조사 device plugin의 mode=dynamic-smlu, Driver(neuware ≥5.0) 수준 quota 제한,
    min-dsmlu-unit=256MB, vmemory/vcore는 vmlu=1일 때만 유효(본문에는 Driver 제한·Instance 분할만 기재).
    1.3 마지막 문단에 일반화 한 문장 추가: 세 계층은 HAMi 밖 기법에도 적용 — Library: vCUDA·NVIDIA MPS /
    Driver: Alibaba cGPU·Tencent qGPU / Hardware: NVIDIA MIG·AMD MxGPU(SR-IOV). vGPU(Driver+HW 혼합)·MPS(Volta+ HW 지원)
    같은 경계 사례는 본문 미기재. 근거: Alibaba cGPU docs(kernel driver, MB 단위·2%+), 비교 글(MIG 전용 GPC/L2/HBM,
    MxGPU 균등 VF 분할).
  - [Table 1]에 "격리 계층" 열 추가 (2026-10-31). 분류 근거와 확신도:
    확실 — NVIDIA·AMD Library(HAMi 자체 Library), Ascend Hardware(vNPU Template), Cambricon Driver(sMLU),
    Iluvatar Library(/etc/ld.so.preload로 libvgpu.so 주입·kernel launch token-bucket, 웹 리서치),
    Kunlunxin Hardware(P800-OAM 1/4·1/2 고정 분할, 요청 Memory를 지원 규격으로 올림 — HAMi kunlun-vxpu-support.md),
    AWS Neuron Hardware(NeuronCore 물리 단위 연속 블록 할당 — dynamia v2.7 blog).
    **추정(재확인 필요)** — Hygon Driver(vDCU: hy-smi virtual로 가상 Device 생성, 격리 주체 명시 문서 못 찾음),
    Moore Threads Driver(sGPU: kernel 수준 Elastic Virtualization으로 소개되나 공식 상세 없음), MetaX Driver(sGPU 명명·동작
    유사성 기반 추정).
- Figure 1~4 (hami-architecture/hami-device-registration/hami-device-scheduling/hami-device-allocation.png)는
  2026-10-16에 matplotlib로 재생성한 **초안** — 사용자가 pptx 스타일로 다시 그릴 예정 (파일명 유지한 채 교체).
  기존 hami-vgpu-*.png 3종은 삭제, hami-core-isolation.png은 kubernetes-hami-nvidia-gpu/images/로 이동함. images/images.pptx는 아직 없음.

## Test 계획 (미수행)

- GPU 없는 로컬에서는 실측 불가. 실측 시 GPU Node가 있는 환경에서 Helm으로 설치
  (`helm repo add hami-charts https://project-hami.github.io/HAMi/` → `helm install hami hami-charts/hami -n kube-system`).
- 실측 시나리오 후보: Node Allocatable의 부풀려진 `nvidia.com/gpu` 개수, `hami.io/node-nvidia-register` Annotation 내용,
  vGPU Pod 생성 후 Pod Annotation(`hami.io/vgpu-devices-allocated`)과 schedulerName 변경 확인.
- 실측 완료 시 본문에 [Shell N] 블록을 실측 발췌로 추가하고 manifests/ 폴더에 재현 파일을 남길 것 (repo 컨벤션).

## 폴더 구조

- `index.md` — 문서 본문 (ko 초안).
- `images/` — matplotlib 초안 Figure 4종.

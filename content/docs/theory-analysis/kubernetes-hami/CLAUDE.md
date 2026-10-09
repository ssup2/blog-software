# kubernetes-hami 문서 작업 컨텍스트

Kubernetes HAMi (Heterogeneous AI Computing Virtualization Middleware)의 vGPU 동작을 분석하는 문서.
kubernetes-nvidia-device-plugin 문서를 참고하여 동일한 포맷(Architecture → 등록 → Scheduling → 할당 → 격리)으로 작성.

## 문서 구성 및 상태

- **2026-10-09 이론 초안 작성** (Claude 작성, 사용자 검토 전). **실측 없음** — Shell 출력 블록은 의도적으로 넣지 않았고
  File/Table/Figure만 존재 (창작 Shell 금지 컨벤션 준수). index.en.md는 초안 확정 전이라 미작성.
- 1장 구성: 1. 개요(Architecture, Component 3종, vGPU Resource Table, Pod 예제) / 1.1 vGPU 등록 과정 /
  1.2 vGPU Scheduling 과정 / 1.3 vGPU 할당 과정 / 1.4 Memory·SM 사용률 제한(HAMi-core).
- **사실 검증 필요 목록** (초안은 HAMi 문서·소스 기반의 기억으로 작성됨, 실측 또는 문서 재확인 필요):
  - `deviceSplitCount` 기본값 10 여부와 설정 위치 (hami-device-plugin ConfigMap).
  - Node Annotation 이름 `hami.io/node-nvidia-register`, handshake Annotation 동작.
  - Pod Annotation 이름 `hami.io/vgpu-devices-allocated` (유사 Annotation: vgpu-devices-to-allocate, vgpu-node, vgpu-time).
  - 환경 변수 이름: `CUDA_DEVICE_MEMORY_LIMIT`(Device별 suffix `_0` 형태 여부), `CUDA_DEVICE_SM_LIMIT`, `LD_PRELOAD` 경로(/usr/local/vgpu/libvgpu.so).
  - Scheduler Extender의 Filter/Score/Bind verb 구성 (Score를 Extender가 수행하는지 Filter 내부에서 계산하는지).
  - Mutating Webhook의 주체 (Scheduler Extender Container가 Webhook 서버 겸임 여부).
  - 다수 vGPU 요청 시 서로 다른 물리 GPU 배치 규칙.
  - vGPU Monitor의 Metric Port와 Shared Memory Region 경로(/usr/local/vgpu).
- Figure 1~5 (hami-architecture/hami-vgpu-registration/hami-vgpu-scheduling/hami-vgpu-allocation/hami-core-isolation.png)는
  2026-10-09에 matplotlib로 생성한 **초안** — 사용자가 pptx 스타일(기존 images.pptx 컨벤션)로 다시 그릴 예정.
  본문에 figure shortcode 삽입 완료 (파일명 유지한 채 교체하면 됨). images/images.pptx는 아직 없음.

## Test 계획 (미수행)

- GPU 없는 로컬에서는 실측 불가. 실측 시 GPU Node가 있는 환경에서 Helm으로 설치
  (`helm repo add hami-charts https://project-hami.github.io/HAMi/` → `helm install hami hami-charts/hami -n kube-system`).
- 실측 시나리오 후보: Node Allocatable의 부풀려진 `nvidia.com/gpu` 개수, `hami.io/node-nvidia-register` Annotation 내용,
  vGPU Pod 생성 후 Pod Annotation·환경 변수(`kubectl exec env`)·`nvidia-smi`의 Memory 크기 출력,
  Memory 제한 초과 시 OOM 동작, vGPU Monitor Metric.
- 실측 완료 시 본문에 [Shell N] 블록을 실측 발췌로 추가하고 manifests/ 폴더에 재현 파일을 남길 것 (repo 컨벤션).

## 폴더 구조

- `index.md` — 문서 본문 (ko 초안).
- `images/` — matplotlib 초안 Figure 5종.

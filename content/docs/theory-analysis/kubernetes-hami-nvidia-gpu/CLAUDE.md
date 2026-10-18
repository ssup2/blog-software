# kubernetes-hami-nvidia-gpu 문서 작업 컨텍스트

HAMi의 NVIDIA GPU 기능에 포커스를 두는 문서: vGPU Resource·설정, HAMi-core 격리(Memory/SM), GPU 선택·Scheduling 정책, Dynamic MIG.
kubernetes-hami(HAMi 자체, 벤더 중립 구조) 문서의 NVIDIA 상세 글이며, 2026-10-16에 기존 kubernetes-hami 글에서 분리하면서 작성됨
(HAMi-core 격리 섹션과 vGPU Resource Table을 이 글로 이동). kubernetes-hami-dra 문서와 3부작 구성.

## 문서 구성 및 상태

- **2026-10-16 이론 초안 작성** (Claude 작성, 사용자 검토 전, frontmatter `draft: true`). **실측 없음** — Shell 블록 없음.
  index.en.md는 초안 확정 전이라 미작성.
- 1장 구성: 1. 개요(hami-device-plugin/HAMi-core, vGPU Resource Table, Pod 예제) / 1.1 vGPU 설정(Table 2) /
  1.2 Memory·SM 사용률 제한(HAMi-core, 정책 환경 변수, Monitor) / 1.3 GPU 선택과 Scheduling 정책(Type/UUID Annotation,
  binpack/spread/mutex, Topology-aware) / 1.4 Dynamic MIG(Flexible MIG 예약 방식).
- 사실 관계는 2026-10-16 웹 리서치(HAMi master 소스 pkg/device/nvidia/device.go, charts/hami/values.yaml, HAMi-core README,
  공식 docs·릴리스 노트) 기반. **사실 검증 필요 목록**:
  - vGPU Resource: `nvidia.com/priority` (0 높음/1 낮음, 기본 1) — 같은 GPU에서 런타임 QoS로 동작(Scheduling 선점 아님).
    `gpucores: 100` = 전용 할당(WholeGPUUsedCores). gpumem 생략 시 defaultMemory 0 = 전체 Memory — 본문은
    "제한하지 않는 vGPU"로 서술(분리 전 글 표현 유지), 정확히는 "물리 Memory 전체 크기" — 실측으로 확인 필요.
  - 설정 위치: Cluster 공통은 `hami-scheduler-device` ConfigMap(`device-config.yaml`의 nvidia 섹션,
    deviceSplitCount 10/deviceMemoryScaling 1/deviceCoreScaling 1), Node별 재정의는 `hami-device-plugin` ConfigMap
    `config.json`의 `nodeconfig` (operatingmode: hami-core|mig 포함). 변경 후 Component 재시작 필요(본문 생략).
  - deviceMemoryScaling > 1 = virtual device memory (실험적, 물리 OOM 가능) — 공식 문서 기반.
  - HAMi-core: `GPU_CORE_UTILIZATION_POLICY` (default/force/disable), `CUDA_DISABLE_CONTROL`(본문 생략),
    공유 Cache 파일 경로(/tmp/cudevshr.cache 또는 /usr/local/vgpu/ 하위 — per-container 경로 UNVERIFIED, 본문 생략),
    LD_PRELOAD vs /etc/ld.so.preload 주입 방식(UNVERIFIED — 본문은 LD_PRELOAD로 서술, 분리 전 글 표현 유지).
  - Monitor Port: Node 31992(vGPU Monitor), Scheduler 31993. Metric 이름(Device_memory_desc_of_container 등)은 본문 생략.
  - GPU 선택 Annotation: `nvidia.com/use-gputype`/`nouse-gputype`/`use-gpuuuid`/`nouse-gpuuuid` (소스 상수 확인됨).
  - 정책: gpu-scheduler-policy 기본 spread, v2.10.0부터 조합(쉼표)과 `mutex` 추가. Topology-aware는 v2.7.0 도입,
    `ENABLE_TOPOLOGY_SCORE` 환경 변수 + `hami.io/node-nvidia-score` Annotation. NUMA(`nvidia.com/numa-bind`)는 본문 생략.
  - Dynamic MIG: v2.5.0 도입(knownMigGeometries 기반 Geometry 전환) → v2.10.0 Flexible MIG(Profile 예약 기반,
    `migProfileAllowlist`, Node Cordon 불필요, hami-device-plugin이 NVML로 GI/CI 생성·회수). `nvidia.com/vgpu-mode` Annotation.
    `adoptExistingMIGInstances` 설정(기본 false, 본문 생략). MIG Mode(`nvidia-smi -mig 1`) 사전 활성화 필요 여부 UNVERIFIED.
    GPU Operator MIG Manager/mig-parted 병행 불가. [File 3]의 "8000MB → A100 1g.10gb" 예시는 추정에 가까움 — Profile 선택
    로직(최소 수용 Profile) 실측 확인 필요.
- Figure: hami-nvidia-architecture.png, hami-nvidia-dynamic-mig.png는 2026-10-16 matplotlib 초안,
  hami-core-isolation.png는 분리 전 kubernetes-hami 글(2026-10-09 matplotlib 초안)에서 이동 — 모두 사용자가 pptx 스타일로
  다시 그릴 예정 (파일명 유지한 채 교체). images/images.pptx는 아직 없음.

## Test 계획 (미수행)

- GPU Node 필요 (Dynamic MIG는 Ampere/Hopper/Blackwell MIG-capable GPU 필요).
- 실측 시나리오 후보: vGPU Pod의 환경 변수(`kubectl exec env`로 CUDA_DEVICE_MEMORY_LIMIT_0, CUDA_DEVICE_SM_LIMIT, LD_PRELOAD 확인),
  `nvidia-smi`의 vGPU Memory 크기, Memory 제한 초과 시 CUDA OOM, 31992/31993 Metric,
  use-gputype Annotation 동작, mig 모드 Node에서 `nvidia-smi mig -lgi`로 동적 생성 확인, Pod 삭제 후 Instance 회수 확인.
- 실측 완료 시 본문에 [Shell N] 블록을 실측 발췌로 추가하고 manifests/ 폴더에 재현 파일을 남길 것 (repo 컨벤션).

## 폴더 구조

- `index.md` — 문서 본문 (ko 초안).
- `images/` — Figure 3종 (matplotlib 초안 2종 + 분리 전 글에서 이동한 hami-core-isolation.png).

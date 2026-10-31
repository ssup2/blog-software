# kubernetes-hami-nvidia-gpu 문서 작업 컨텍스트

HAMi의 NVIDIA GPU 기능에 포커스를 두는 문서: vGPU Resource·설정, HAMi-core 격리(Memory/SM), GPU 선택·Scheduling 정책, Dynamic MIG.
kubernetes-hami(HAMi 자체, 벤더 중립 구조) 문서의 NVIDIA 상세 글이며, 2026-10-16에 기존 kubernetes-hami 글에서 분리하면서 작성됨
(HAMi-core 격리 섹션과 vGPU Resource Table을 이 글로 이동). kubernetes-hami-dra 문서와 3부작 구성.

## 문서 구성 및 상태

- **2026-10-16 이론 초안 작성** (Claude 작성, 사용자 검토 전, frontmatter `draft: true`).
  index.en.md는 초안 확정 전이라 미작성.
- **2026-10-18 Memory·SM 격리 실측 추가** (Claude): 1.1 Test 환경 구축을 신설하고 1.3(Memory·SM) 섹션에 Shell 블록 2개(2500MB OOM, matmul 중 SM 샘플링) 추가. 실측 환경은 kubernetes-hami-vllm-gpu-ubuntu-26.04 Record 글의 Cluster 재사용. `GPU_CORE_UTILIZATION_POLICY=force` 설정으로 유휴 Burst를 꺼서 vgpu-monitor Metric이 ~31%에 수렴하는 모습 확인. 호스트 nvidia-smi dmon은 Token Bucket Burst 특성으로 99/0 번갈아 나오는 것 함께 수록.
- 1장 구성: 1. 개요(hami-device-plugin/HAMi-core, vGPU Resource Table, Pod 예제) / 1.1 Test 환경 구축 / 1.2 vGPU 설정(Table 2) /
  1.3 Memory·SM 사용률 제한(HAMi-core, 정책 환경 변수, Monitor, 실측 Shell 2종) / 1.4 GPU 선택과 Scheduling 정책(Type/UUID Annotation,
  binpack/spread/mutex, Topology-aware) / 1.5 Dynamic MIG(Flexible MIG 예약 방식).
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
    공유 Cache 파일: **2026-10-31 HAMi-core 소스로 Shared Memory 구성 검증·본문 보강** (multiprocess_memory_limit.h/.c) —
    CUDA_DEVICE_MEMORY_SHARED_CACHE(기본 /tmp/cudevshr.cache, HAMi 환경에선 CONTAINER_VGPU_MOUNT 기본 /usr/local/vgpu 하위에
    POD_UID/CONTAINER_NAME env로 경로 구성)의 파일을 open(O_CREAT) 후 mmap. shared_region_t 구조: initialized_flag(MAGIC
    19920718, 최초 Process가 초기화), process-shared sem_t, device별 limit[16]/sm_limit[16], procs[1024] Slot(pid/hostpid,
    Device별 used(context/module/data 분리)/monitorused/sm_util, seqlock). 제한값은 파일에 저장되어 변경 시 파일 삭제 필요
    (README, 본문 생략). vGPU Monitor가 Host에서 읽는 정확한 경로는 UNVERIFIED (본문은 "hostPath Volume 경로"로만 서술).
    주입 방식은 /etc/ld.so.preload로 실측 확인(2026-10-18, 아래 Test 상태). 2026-10-31 사용자 요청으로 preload 동작 원리 보강:
    [Shell 1] 문단에 LD_PRELOAD(상속 Process 한정, 환경 변수 정리 시 끊김) vs /etc/ld.so.preload(동적 링커가 모든 Process
    시작 시 읽음) 비교, [Figure 2] 문단에 동적 링커 Symbol 해석 원리(같은 이름 함수는 먼저 Load된 Library 우선 →
    libvgpu.so가 CUDA와 같은 이름 함수 정의 → 검사 후 실제 CUDA Library로 전달) 추가 — 일반 Linux 동작 기반.
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

## Test 수행 상태

- Memory·SM 격리 (1.1, 1.3): **완료 (2026-10-18)** — `manifests/hami-isolation-test.yaml` 재현 파일 보관.
  - RTX 5060 Ti 1장 (Blackwell) 환경이라 nvidia-smi 안에서 `LD_PRELOAD` 환경 변수는 안 보였고 `/etc/ld.so.preload` 파일 주입 방식 확인. 본문도 이에 맞춰 수정.
  - `CUDA_DEVICE_MEMORY_LIMIT_0=2000m` (단위: MiB), `CUDA_DEVICE_SM_LIMIT=30` 둘 다 Container 내 환경 변수로 주입.
- 미수행:
  - use-gputype Annotation 동작 (단일 GPU Node 환경이라 Type 선택 효과 관찰 불가).
  - Dynamic MIG (RTX 5060 Ti는 MIG 미지원).
  - 추가 실측 시 본문에 [Shell N] 블록을 실측 발췌로 추가하고 manifests/ 폴더에 재현 파일을 남길 것 (repo 컨벤션).

## 폴더 구조

- `index.md` — 문서 본문 (ko 초안).
- `images/` — Figure 3종 (matplotlib 초안 2종 + 분리 전 글에서 이동한 hami-core-isolation.png).

# kubernetes-hami-nvidia-gpu 문서 작업 컨텍스트

HAMi의 NVIDIA GPU 기능에 포커스를 두는 문서: vGPU Resource, 설정, HAMi-core 격리(Memory/SM), GPU 선택, Scheduling 정책, Dynamic MIG.
kubernetes-hami(HAMi 자체, 벤더 중립 구조) 문서의 NVIDIA 상세 글이며, 2026-10-16에 기존 kubernetes-hami 글에서 분리하면서 작성됨
(HAMi-core 격리 섹션과 vGPU Resource Table을 이 글로 이동). kubernetes-hami-dra 문서와 3부작 구성.

## 문서 구성 및 상태

- **2026-11-06 Time-slicing, MPS 서술 추가** (사용자 요청): 개요와 1.3 SM 문단 뒤에 추가. MPS 미지원 근거는 HAMi v2.10.0 plugin/mps.go(빈 구현), `MpsMode` 상수 미사용, Chart에 설정 없음.
  Driver Time-slicing 위에서 동작한다는 서술은 일반 GPU 동작 기반으로 Context 전환을 직접 관측하지 않음. `website` 저장소 문서는 미확인.
- **2026-11-06 1.6 GPU Health Check 추가** (사용자 요청, 소스 기반, 장애 동작 실측 없음): 근거는 HAMi v2.10.0 rm/health.go, plugin/server.go ListAndWatch,
  rm/devices.go GetPluginDevices, plugin/register.go(30초 주기), pkg/device/nvidia/device.go Fit(CardNotHealth). 무시 Xid 목록은 upstream과 동일.
  Allocatable 제외와 실행 중 Pod 유지는 Kubernetes 일반 동작 기반, Pod 재시작 후 복구는 Health 상태가 메모리에만 있다는 점에서 추정. Test Node는 정상 상태(`health:true`, Allocatable 10)이고
  현재 Plugin 로그에 `Using XIDs` 줄이 없어 Health Check 시작 여부는 미확인. DaemonSet에 `DP_*` 환경 변수 없음.
- **2026-11-06 Library 전달 경로 추가** (사용자 요청, 소스 기반, 같은 날 Test Node에서 실측 확인): 개요 Component 목록 뒤에 Driver Library
  (NVIDIA Container Toolkit)와 HAMi-core 파일(Allocate 응답 Mount 항목) 경로 구분 추가. 근거: HAMi v2.10.0 plugin/server.go Allocate,
  daemonsetnvidia.yaml postStart, docker/vgpu-init.sh, values.yaml(gpuHookPath, libPath, deviceListStrategy). `/tmp/vgpulock`의 용도는
  이름과 Mount 설정 기반 서술로 HAMi-core 소스 재확인 필요. CDI Strategy 동작은 본문 생략.
  같은 날 사용자 피드백으로 Library 3종 목록 + 경로별 문단으로 쉽게 재작성, Driver Library는 `jit-cdi` Mode로 명시
  (Toolkit v1.20.1 internal/info/auto.go, internal/modifier/cdi.go 기반). `deviceListStrategy: cdi-*`의 CDI와는 별개.
  Test Node 실측(qwen3 Pod의 containerd Bundle config.json, /proc/<pid>/mounts): Toolkit 1.20.1, `mode = "auto"`, CDI Annotation 없음,
  legacy prestart Hook 없이 `nvidia-ctk hook` createContainer Hook 사용, Driver Library Mount와 `NVIDIA_VISIBLE_DEVICES=void` 확인 → jit-cdi와 일치.
  HAMi Mount 4종과 Image 내 libcudart도 확인. `NVIDIA_VISIBLE_DEVICES=all`은 vLLM Image의 ENV, `=void`와 `NVIDIA_CTK_LIBCUDA_DIR`은 Toolkit이 생성하는 CDI
  containerEdits. Plugin이 넘긴 GPU UUID 값이 `void`로 교체된 것은 환경 변수 위치 기반 추정. `/var/run/cdi/nvidia.yaml`은 Toolkit Package의
  `nvidia-cdi-refresh.service`(`nvidia-ctk cdi generate`) 생성물이며, jit-cdi는 소스상 메모리에서 명세를 생성하므로 이 파일을 쓰지 않음.
- **2026-10-16 이론 초안 작성** (Claude 작성, 사용자 검토 전, frontmatter `draft: true`).
  index.en.md는 초안 확정 전이라 미작성.
- **2026-10-18 Memory, SM 격리 실측 추가** (Claude): 1.1 Test 환경 구축을 신설하고 1.3(Memory, SM) 섹션에 Shell 블록 2개(2500MB OOM, matmul 중 SM 샘플링) 추가. 실측 환경은 kubernetes-hami-vllm-gpu-ubuntu-26.04 Record 글의 Cluster 재사용. `GPU_CORE_UTILIZATION_POLICY=force` 설정으로 유휴 Burst를 꺼서 vgpu-monitor Metric이 ~31%에 수렴하는 모습 확인. 호스트 nvidia-smi dmon은 Token Bucket Burst 특성으로 99/0 번갈아 나오는 것 함께 수록.
- **2026-11-01 kubernetes-hami 글과의 상호 참조 제거** (사용자 피드백): 참조 섹션의 "Kubernetes HAMi" 자기 블로그 링크 제거.
  kubernetes-hami 글에서는 중복되는 NVIDIA 세부(Pod 예제, 환경 변수 열거)가 축소된 상태이므로 양 글을 각각 독립적으로 읽는 걸 전제로 함.
- **2026-11-01 Annotation 절 해체** (사용자 피드백, kubernetes-hami 글과 동일 방침): "1.6 HAMi Annotation 정리"를 삭제하고
  사용되는 절로 분배 — Pod Annotation(Extender 기록분: to-allocate/allocated/vgpu-node/bind-phase/bind-time)은
  [File 3]으로 1.1 Test 환경(Shell 1 뒤)에 배치해 "Scheduler가 Annotation 기록 → Device Plugin이 읽어 env 주입" 체인 완성.
  [File 3]의 Pod 이름, 값은 Test Pod(hami-isolation-test) 요청(2000/30)에 맞춰 구성한 예제 (기존 1.6의 값은 qwen3 Pod 실측,
  bind-time epoch은 그 캡처 값 유지). Node Annotation(node-nvidia-register, RTX 5060 Ti 실측 JSON)은 [File 4]로 1.2 vGPU
  설정(Table 2 뒤)에 배치해 count=deviceSplitCount, mode=operatingmode 대응 명시. node-handshake는 kubernetes-hami 글 담당이라
  이 글에서 제거, node-nvidia-score, use-gputype 계열, vgpu-mode, 정책 Annotation은 1.4~1.5 기존 서술로 일원화(중복 나열 제거).
  기존 File 3/4(GPU Type 예제, MIG 예제)는 File 5/6으로 재번호.
- 1장 구성: 1. 개요(hami-device-plugin/HAMi-core, vGPU Resource Table, Pod 예제 [File 1]) / 1.1 Test 환경 구축([File 2],
  [Shell 1], Pod Annotation [File 3]) / 1.2 vGPU 설정(Table 2, Node Annotation [File 4]) /
  1.3 Memory, SM 사용률 제한(HAMi-core, 정책 환경 변수, Monitor, 실측 Shell 2종) / 1.4 GPU 선택과 Scheduling 정책(Type/UUID Annotation,
  binpack/spread/mutex, Topology-aware, [File 5]) / 1.5 Dynamic MIG(Flexible MIG 예약 방식, [File 6]).
- 사실 관계는 2026-10-16 웹 리서치(HAMi master 소스 pkg/device/nvidia/device.go, charts/hami/values.yaml, HAMi-core README,
  공식 docs, 릴리스 노트) 기반. **사실 검증 필요 목록**:
  - vGPU Resource: `nvidia.com/priority` (0 높음/1 낮음, 기본 1) — 같은 GPU에서 런타임 QoS로 동작(Scheduling 선점 아님).
    `gpucores: 100` = 전용 할당(WholeGPUUsedCores). gpumem 생략 시 defaultMemory 0 = 전체 Memory — 본문은
    "제한하지 않는 vGPU"로 서술(분리 전 글 표현 유지), 정확히는 "물리 Memory 전체 크기" — 실측으로 확인 필요.
  - 설정 위치: Cluster 공통은 `hami-scheduler-device` ConfigMap(`device-config.yaml`의 nvidia 섹션,
    deviceSplitCount 10/deviceMemoryScaling 1/deviceCoreScaling 1), Node별 재정의는 `hami-device-plugin` ConfigMap
    `config.json`의 `nodeconfig` (operatingmode: hami-core|mig 포함). 변경 후 Component 재시작 필요(본문 생략).
  - deviceMemoryScaling > 1 = virtual device memory (실험적, 물리 OOM 가능) — 공식 문서 기반.
  - HAMi-core: `GPU_CORE_UTILIZATION_POLICY` (default/force/disable), `CUDA_DISABLE_CONTROL`(본문 생략),
    공유 Cache 파일: **2026-10-31 HAMi-core 소스로 Shared Memory 구성 검증, 본문 보강** (multiprocess_memory_limit.h/.c) —
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
    `migProfileAllowlist`, Node Cordon 불필요, hami-device-plugin이 NVML로 GI/CI 생성, 회수). `nvidia.com/vgpu-mode` Annotation.
    `adoptExistingMIGInstances` 설정(기본 false, 본문 생략). MIG Mode(`nvidia-smi -mig 1`) 사전 활성화 필요 여부 UNVERIFIED.
    GPU Operator MIG Manager/mig-parted 병행 불가. [File 3]의 "8000MB → A100 1g.10gb" 예시는 추정에 가까움 — Profile 선택
    로직(최소 수용 Profile) 실측 확인 필요.
- Figure: hami-nvidia-architecture.png, hami-nvidia-dynamic-mig.png는 2026-10-16 matplotlib 초안,
  hami-core-isolation.png는 분리 전 kubernetes-hami 글(2026-10-09 matplotlib 초안)에서 이동 — 모두 사용자가 pptx 스타일로
  다시 그릴 예정 (파일명 유지한 채 교체). images/images.pptx는 아직 없음.

## Test 수행 상태

- Memory, SM 격리 (1.1, 1.3): **완료 (2026-10-18)** — `manifests/hami-isolation-test.yaml` 재현 파일 보관.
  - RTX 5060 Ti 1장 (Blackwell) 환경이라 nvidia-smi 안에서 `LD_PRELOAD` 환경 변수는 안 보였고 `/etc/ld.so.preload` 파일 주입 방식 확인. 본문도 이에 맞춰 수정.
  - `CUDA_DEVICE_MEMORY_LIMIT_0=2000m` (단위: MiB), `CUDA_DEVICE_SM_LIMIT=30` 둘 다 Container 내 환경 변수로 주입.
- 미수행:
  - use-gputype Annotation 동작 (단일 GPU Node 환경이라 Type 선택 효과 관찰 불가).
  - Dynamic MIG (RTX 5060 Ti는 MIG 미지원).
  - 추가 실측 시 본문에 [Shell N] 블록을 실측 발췌로 추가하고 manifests/ 폴더에 재현 파일을 남길 것 (repo 컨벤션).

## 폴더 구조

- `index.md` — 문서 본문 (ko 초안).
- `images/` — Figure 3종 (matplotlib 초안 2종 + 분리 전 글에서 이동한 hami-core-isolation.png).

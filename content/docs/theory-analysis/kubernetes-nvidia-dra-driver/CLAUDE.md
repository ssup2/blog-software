# kubernetes-nvidia-dra-driver 문서 작업 컨텍스트

NVIDIA DRA Driver(kubernetes-sigs/dra-driver-nvidia-gpu)의 구조와 기능(GPU 등록·속성, 공유, Dynamic MIG, ComputeDomain)을 분석하는 문서.
kubernetes-dra(DRA 표준) 문서의 벤더 구현 글로, kubernetes-nvidia-device-plugin ↔ Device Plugin 표준의 관계와 같은 구도.
kubernetes-hami-dra 문서와 같은 시기(2026-10-15)에 작성됨. 배경 글(kubernetes-dra)은 draft 상태 — 발행 시 상호 참조 링크 유지 여부 확인.

## 문서 구성 및 상태

- **2026-10-15 이론 초안 작성** (Claude 작성, 사용자 검토 전, frontmatter `draft: true`). **실측 없음** — Shell 블록 없음,
  File 1~3은 공식 문서·Helm template 기반. index.en.md는 초안 확정 전이라 미작성.
- 1장 구성: 1. 개요(Driver 2종, DeviceClass Table) / 1.1 GPU 등록과 속성(Attribute/Capacity Table, CEL 예제) /
  1.2 GPU 공유(Shared Claim, GpuConfig Opaque Config) / 1.3 MIG Instance 할당(Static/Dynamic MIG, KEP-4815) /
  1.4 ComputeDomain(IMEX) / 1.5 Device Plugin 비교(GPUCluster, DRAExtendedResource).
- 초안의 사실 관계는 2026-10-15 웹 리서치(GitHub API로 릴리스 실측, main 브랜치 소스·Helm template, 공식 문서, GPU Operator 문서) 기반.
  **사실 검증 필요 목록**:
  - 프로젝트 이관: NVIDIA/k8s-dra-driver-gpu → kubernetes-sigs/dra-driver-nvidia-gpu (2026-03 CNCF 기증, 구 URL redirect),
    버전 체계 CalVer(v25.12.0) → SemVer(v0.4.0+), 최신 v0.5.1(2026-10-12).
  - GA 상태: GPU 할당 Plugin은 v25.12.0 릴리스 노트에서 GA 선언, ComputeDomain은 처음부터 공식 지원. 단 저장소 README(main)에는
    stale한 "not yet officially supported" 문구가 남아 있고, standalone chart는 여전히 `gpuResourcesEnabledOverride=true` 명시 필요.
  - DeviceClass 이름 4종(gpu/mig/vfio.gpu/compute-domain-default-channel.nvidia.com)과 compute-domain-daemon.nvidia.com —
    본문 Table 1은 daemon class를 생략함 (Workload가 직접 요청하지 않는 내부용).
  - Attribute/Capacity Key: deviceinfo.go와 공식 reference 문서 기반. MIG Device의 `profile`/`parentUUID`/`memorySlice[N]` Capacity.
  - Opaque Config API: `resource.nvidia.com/v1beta1`의 `GpuConfig`/`MigDeviceConfig`/`VfioDeviceConfig`, `sharing.strategy`,
    `timeSlicingConfig.interval`(Default/Short/Medium/Long), `mpsConfig.defaultActiveThreadPercentage` 등.
  - Feature Gate 이름: `DynamicMIG`, `TimeSlicingSettings`, `MPSSupport`, `ConsumableShares` (모두 Alpha, 기본 비활성).
    기본 Time-slicing(공유 Claim 참조 자체)은 Gate 불필요 — interval 변경에만 `TimeSlicingSettings` 필요.
  - Dynamic MIG: KEP-4815 Partitionable Devices 기반, K8s 1.34~1.35는 `DRAPartitionableDevices` Gate 필요, 1.36+ 기본 활성.
    시작 시 기존 MIG Instance 제거(소유권 독점), Ampere는 MIG Mode 사전 활성화 필요, `PassthroughSupport`/`MPSSupport` 등과 상호 배타.
  - ComputeDomain CRD: `computedomains.resource.nvidia.com` v1beta1 + `computedomaincliques`. `numNodes`는 deprecated —
    File 3 예제에서 의도적으로 생략함. Device File 경로 `/dev/nvidia-caps-imex-channels/channel[N]`.
  - GPU Operator 통합: v26.7부터 GPUCluster CR(singleton, 이름 gpu-cluster)로 설치, ClusterPolicy와 동시 존재 불가 (공식 문서 명시).
    Device Plugin과 DRA Driver의 Node 레벨 동시 실행 금지의 공식 문구는 못 찾음 — 본문은 GPUCluster/ClusterPolicy 양자택일로만 서술.
  - `DRAExtendedResource`: K8s 1.36.0+ 기본 활성(1.37 GA 예정), standalone chart의 gpu.nvidia.com DeviceClass는
    `extendedResourceName: nvidia.com/gpu` 설정, GPU Operator 관리형 설치는 미설정.
  - 요구사항: K8s 1.34.2+(GPU 할당), CDI 필수(containerd 2.0+/CRI-O 1.27+), NVIDIA Container Toolkit 1.18.0+,
    GPU Driver v565+(ComputeDomain은 v570.158.01+) — 본문에서 생략함, Test 환경 구축 시 명시.
- Figure 1~4 (nvidia-dra-driver-architecture/-gpu-sharing/-dynamic-mig/-compute-domain.png)는 2026-10-15에 matplotlib로 생성한
  **초안** — 사용자가 pptx 스타일로 다시 그릴 예정 (파일명 유지한 채 교체). images/images.pptx는 아직 없음.

## Test 계획 (미수행)

- GPU 할당·공유·MIG 실측은 NVIDIA GPU Node 필요 (MIG는 Ampere+ MIG-capable, ComputeDomain은 MNNVL 환경이라 실측 현실성 낮음).
- 설치: `helm install dra-driver-nvidia-gpu oci://registry.k8s.io/dra-driver-nvidia/charts/dra-driver-nvidia-gpu
  --version 0.5.1 -n dra-driver-nvidia-gpu --create-namespace --set gpuResourcesEnabledOverride=true`
  (GPU Operator 관리 Driver 환경은 `--set nvidiaDriverRoot=/run/nvidia/driver`, Device Plugin 비활성화 필요).
- 실측 시나리오 후보: `kubectl get resourceslices -o yaml`의 GPU Attribute/Capacity, CEL Selector 기반 ResourceClaim 할당,
  공유 Claim으로 2개 Pod 동일 GPU 확인, GpuConfig TimeSlicing/MPS 적용 결과(환경 변수, MPS Pipe), Dynamic MIG 활성화 후
  미존재 MIG Device 게시와 `nvidia-smi mig` 생성 확인.
- 실측 완료 시 본문에 [Shell N] 블록을 실측 발췌로 추가하고 manifests/ 폴더에 재현 파일을 남길 것 (repo 컨벤션).

## 폴더 구조

- `index.md` — 문서 본문 (ko 초안).
- `images/` — matplotlib 초안 Figure 4종.

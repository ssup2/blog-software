# kubernetes-hami-nvidia-gpu 문서 작업 컨텍스트

HAMi의 NVIDIA GPU 기능에 포커스를 두는 문서: vGPU Resource, 설정, HAMi-core 격리(Memory/SM), GPU 선택, Scheduling 정책, Dynamic MIG.
kubernetes-hami(HAMi 자체, 벤더 중립 구조) 문서의 NVIDIA 상세 글이며, 2026-10-16에 기존 kubernetes-hami 글에서 분리하면서 작성됨
(HAMi-core 격리 섹션과 vGPU Resource Table을 이 글로 이동). kubernetes-hami-dra 문서와 3부작 구성.

## 문서 구성 및 상태

- **2026-11-24 Dynamic MIG 자동화 end-to-end 검증** (회사 Mac, KR/EN 동시): env-charts PR #1458 머지+sync 후 warmup Pod 없이 config8만
  적용 → NodeOverlay로 Karpenter가 p4d 자동 프로비저닝(gpumem 인식) → userData가 부팅 시 `nvidia-smi -mig 1` + reboot로 MIG Mode 자동 활성화
  (last reboot 2회 확인: 16:49 최초→user script enable+reboot→16:50) → 세 Pod 자동 할당 성공(GPU UUID c634460f, 위치 0/2/4). 수동 개입 0.
  본문 반영: 1.4 도입부 "placeholder Pod로 생성" → NodeOverlay 문단으로 교체, userData 문단에 EC2 reset 거부→reboot 설명 추가,
  [Shell 9](부팅 시 자동 활성화 + last reboot) 추가. dumps step5-automated. env-charts: node_overlay_capacity(node group 옵션)·mig_reboot 옵션으로 정리됨.
- **2026-11-24 Dynamic MIG 실측 2차 — MIG Instance 생성 성공** (회사 Mac, KR/EN 동시): 1.4.1에 [Shell 7](Config 8 구성),
  1.4.2에 [Shell 8](Config 9 전환) 추가, TODO 주석 제거. 실측 요지:
  - MIG Mode 활성화는 userData #1457로도 EC2에서 reset 거부(gpu-reset "In use by another client")라 pending 잔존 →
    수동 `reboot`로 적용 후 재등록(dumps step2-mig-enable-fix). 재부팅 후 MIG Mode 유지 확인.
  - Config 8: mig-2g-a/b, mig-3g가 binpack으로 같은 GPU(UUID a8f9e013)에, 위치 2g→0,2 / 3g→4 (예측 일치). 각 Pod `nvidia-smi -L`에 MIG Device 1개.
  - Config 9: mig-2g-b 삭제 → 1g×2 적용. mig-2g-a(54cc1df4)·mig-3g(d867d519) migUUID 유지(재생성 없음), 1g×2는 위치 2,3.
    device-plugin 로그 migmgr.go: created(664) → cached released=Idle(907) → reclaimed idle under placement pressure(739) → created 1g×2.
  - dumps: step3-config8, step4-config9 (migmgr-lifecycle.log 포함). [Shell 7]/[Shell 8]은 이 dump 발췌.
  - **후속 완료**: env-charts PR #1458(NodeOverlay+mig_reboot) 머지+sync 후 자동화 검증 완료 → 1.4 도입부를 NodeOverlay 방식으로 갱신,
    [Shell 9] 추가, warmup manifest 삭제 (위 2026-11-24 자동화 항목 참조).
- **2026-11-24 Dynamic MIG 실측 1차** (회사 Mac, KR/EN 동시): 1.4 도입부에 환경 문단 + Karpenter 우회 문단 + [Shell 6](실측) + 설명 2문단 추가.
  실측 확인 2건 — ① Karpenter는 `nvidia.com/gpumem`을 몰라 "no instance type has enough resources"로 프로비저닝 거부 →
  GPU Resource 없는 placeholder Pod(`manifests/mig/mig-node-warmup.yaml`)로 우회 (dumps/mig/step0-provision).
  ② MIG Mode 꺼진 Node에서 할당 시 `UnexpectedAdmissionError`("gpu 7 MIG enable is pending (current=0 pending=1)") —
  기존 1.4 Ampere 서술이 실측으로 확인됨 (dumps/mig/step1-mig-enable-pending, device plugin 로그 포함).
  해결은 Node Group userData 부팅 시점 `nvidia-smi -mig 1` (env-charts PR #1457, nodegroup `mig_enable` 플래그).
  수동 reset용 privileged Pod(mig-gpu-admin) 방식은 사용자 피드백으로 폐기(ephemeral 노드에 재현성 없음) — manifest 삭제.
  "Hopper부터 Reset 불필요" 문장은 NVIDIA MIG User Guide 기반(실측 아님). [Shell 7]/[Shell 8]은 PR 머지 후 실측 대기.
- **2026-11-23 Dynamic MIG 실측 준비** (사용자 요청, 회사 Mac에서 작성): 1.4.2 끝에 Test 설계 추가 (KR/EN 동시) — 환경 문단(EKS p4d.24xlarge,
  A100-SXM4-40GB 8장, `group=gpu-a100-hami` Node Group, nodeconfig nodelabelselector로 operatingmode mig), [File 10] mig-config8.yaml
  (2g.10gb ×2 + 3g.20gb, binpack + mig-profile-preference, A100 MIG Geometry Config 8), [File 11] mig-config9.yaml (mig-2g-b 삭제 후
  1g.5gb ×2 → Config 9 전환, Idle 2g 제거 + 기존 Instance 유지 관찰), 수집 문단. **[Shell 6]/[Shell 7]은 실측 후 작성** — KR 본문의
  TODO 주석 위치. 실측 절차와 blocker는 아래 "Dynamic MIG Test" 섹션 참조. (KR/EN): 근거 HAMi Issue #2834(즉시 제거 시 같은 Profile 재요청에 불필요한 Overhead), 병합 PR #3128
  (2026-10-10, 같은 Profile·위치 요청에 기존 Instance와 MIG UUID 재사용, Idle도 CDI 항목 유지). 미병합 PR #2910의 "~1.5s → 0ms"와 Idle TTL은 본문 미기재
  (측정 근거 없음, v2.11.0에 TTL 없음).
- **2026-11-22 MIG 위치 선택 + Idle 수명 주기** (사용자 요청, KR/EN 동시, 소스 기반·A100 실측 없음):
  1.4.1에 2문단 추가 — A100 40GB Placement 테이블(NVIDIA MIG User Guide `nvidia-smi mig -lgipp`: 1g {0..6}:1, 2g {0,2,4}:2, 3g {0,4}:4,
  4g {0}:4, 7g {0}:8)과 HAMi 위치 선택(pkg/device/nvidia/mig_topology.go migRegions/migReservedRegion/score: 두 절반, Placement가 적은 쪽을
  절반 크기 Profile용으로 예약, 작은 Profile은 다른 절반 바깥쪽부터). mig_topology_test.go TestSelectMigPlacementPacksEachHalfSeparately로
  확인: 1g×4 → 0,1,2,3 / 1g→3g→1g → 0,4,1 / 2g×3→1g → 0,2,4,6. 따라서 첫 1g/2g 이후 3g(위치 4)는 가능, 4g는 불가.
  1.4.2 4단계 정정("Pod 종료 시 회수"는 오류): plugin/migmgr.go — server.go runMigAnnotationReconciler(5s) → ReconcileActiveAllocations가
  Pod 없는 Instance를 Idle로 캐시, EnsureAllocation이 같은 위치·Slice 크기 Idle 재사용(compatibleIdleAllocationLocked), 겹치는 Idle은
  LastUsed 오래된 순 제거(reclaimBlockingIdle), Active와 겹치면 오류. Scheduler가 Idle을 빈 공간으로 보는 근거(사용자 요청으로 코드 확인):
  scheduler.go의 MigAllocationsInUse는 podManager.ListPodsInfo() Pod의 `hami.io/vgpu-mig-allocations`(mig_allocations.go 상수)로만 구성,
  종료 Pod는 onAddPod/onUpdatePod의 IsPodInTerminatedState → removePodAllocation으로 제외, 그 외 쓰기는 AddResourceUsage뿐.
  1단계에 Annotation Key 명시. [Figure 3] Annotation Key와 4번 문구(Idle 유지·재사용·필요 시 회수) 수정.
- **2026-11-22 [Figure 1]에 Node Annotation 추가** (사용자 요청): 각 Node에 `hami.io/node-nvidia-register` 박스(축약 값: id, count 10, mode)와
  HAMi Scheduler로 향하는 "Read GPU info" 점선 화살표 추가, `operatingmode` 표기를 Node 제목 옆으로 이동, 캔버스 1400×880. 본문 변경 없음
  (HAMi Scheduler bullet에 이미 Annotation 참조 서술 있음).
- **2026-11-22 operatingmode 혼용 + MIG 재시작 문단** (사용자 요청, KR/EN 동시, 소스 기반·A100 실측 없음): 1.2에 Node 단위 지정(name/nodelabelselector),
  Cluster 내 Node별 혼용 가능, Node 내 GPU별 불가, 변경 시 Plugin 재시작(Chart values.yaml nodeConfiguration 주석) 문장 추가.
  1.4 도입에 upstream(시작 시 MIG Instance를 Device로 등록 → 재구성 시 재시작) vs HAMi(rm/devices.go GetPluginDevices: 부모 GPU `<UUID>-<n>` 등록,
  plugin/util.go → migMgr.EnsureAllocation으로 Allocate 중 GI/CI 생성 후 MIG UUID 전달, CDI는 EnsureDynamicMIGDevice) 비교 + Ampere MIG Mode 사전 활성화
  (migmgr.go ensureMigModeEnabled/SetMigMode, ERROR_RESET_REQUIRED → errMigModeNeedsReset) 문단 추가. 이전 UNVERIFIED "MIG Mode 사전 활성화 필요 여부" 해소.
- **2026-11-22 남은 작업 일괄 처리** (사용자 요청 "모두 작업해줘"):
  ① 1.3.3 우선순위 실측(qwen3 replicas 0 → 1 복구): `manifests/hami-priority-high.yaml`, `hami-priority-low.yaml`(gpumem 2000, gpucores 50, priority 0/1),
  `manifests/matmul-rate.py`. 결과: `CUDA_TASK_PRIORITY` 주입 확인, low 단독 ~880 matmul/s(gpucores 50이지만 default 정책 Switch off로 무제한),
  high 실행 중 low는 ~45초 출력 없음(Blocking), high ~875/s(같은 priority 다른 Container 없어 제한 해제), 종료 후 low 복귀 → 소스 분석과 일치.
  [File 6], [File 7], [Shell 5] 추가, 기존 File 6, 7 → 8, 9. Shell 5의 두 명령 출력은 시각순 정렬(본문 명시).
  `force` bullet과 [File 2] 문단의 "유휴 상태" 표현을 "같은 GPU를 이용하는 다른 Container 유무"로 정정.
  ② [Figure 2] 재작도(SVG → headless Chrome 1300×760, 소스 미보관): 기존 matplotlib 초안의 오류("via LD_PRELOAD", App → CUDA Library →
  libvgpu.so 순서) 수정 — App → HAMi-core(ld.so.preload) → libcuda.so → GPU, Shared Memory Region(usage.cache)과 vgpu-monitor의 양방향
  (사용량 읽기 → Metrics, Blocking/Switch 쓰기 5초). [Figure 3] 재작도(1300×700): ① Scheduler가 최소 수용 Profile + 위치 예약 → Pod Annotation
  ② kubelet Allocate() ③ Device Plugin이 Annotation 조회 ④ NVML로 GI/CI 생성(Pod 종료 시 회수). Pod Annotation 표기는 개념 표기(실제 Key 미확인).
  두 그림 width 900px로 통일.
  ③ `index.en.md` 작성(`draft: true` 유지 — 한글본도 draft라 영문만 공개되는 것 방지). 섹션 13, Table 4, Figure 3(src/width 동일), 코드 블록 14개
  (캡션 제외 바이트 동일), 목록 33, Bold 20을 1:1로 맞춤. 자기 블로그 링크는 영문본 존재하는 글이라 `/en/` 경로 사용.
- **2026-11-22 `#### 1.3.3. 우선순위` 추가** (사용자 요청, 소스 기반, 실측 없음). 근거: HAMi v2.11.0 pkg/device/nvidia/device.go MutateAdmission
  (limits의 `nvidia.com/priority` → env `CUDA_TASK_PRIORITY`), cmd/vGPUmonitor/feedback.go Observe(5초 ticker, recent_kernel 감소 후 >0인 Container를
  GPU UUID/priority별 집계, CheckBlocking: 더 작은 priority 활성 시 recent_kernel=-1, CheckPriority: 더 작은 priority 활성 또는 같은 priority 2개 이상이면
  utilization_switch=1), HAMi-core main multiprocess_memory_limit.c(초기 priority=1, env로 덮어씀, set_env_utilization_switch: force=1, disable=2가 switch 무시),
  multiprocess_utilization_watcher.c rate_limiter(sm_limit 0 또는 ≥100이면 즉시 return → 활동 표시도 안 함, recent_kernel<0이면 sleep(1) 반복, switch 0이면
  Token 차감 없이 통과). 1.3.2 `default` bullet을 Switch 동작 기준으로 수정. HAMi-core는 main 기준(v2.11.0 Image 커밋 미대조).
- **2026-11-22 MIG Mode 하위 절 분리 + Figure 1 Mode별 Resource** (사용자 요청): 1.4를 도입(Dynamic MIG, Flexible MIG, MIG Manager 병행 불가) /
  1.4.1 MIG Profile 선택([File 6]) / 1.4.2 MIG Instance 할당([Figure 3] 4단계)으로 분리. 근거 v2.11.0(clone): pkg/device/nvidia/device.go
  AddResourceUsage(MIG는 selectMigCandidate(…, ctr.Usedmem, preference) 후 Usedmem/Usedcores를 Profile 값으로 덮어씀), Fit에서 memreq 해석 후
  CustomFilterRule(실패 시 CardMigTopologyInfeasible), mig_preference.go(`nvidia.com/mig-profile-preference`: Allowlist Profile 이름 또는 Slice 접두사,
  선호 Profile을 Memory 순 후보 앞으로 배치), Chart values.yaml migProfileAllowlist(A100 80GB: 1g.10gb, 2g.20gb, 3g.40gb, 4g.40gb, 7g.79gb),
  Scaling 2종은 mig에 미적용, deviceSplitCount 대신 MIG Instance 수가 공유 제한(values 주석). examples/nvidia/dynamic_mig_example.yaml 주석
  "gpumem 8000 → A100-80GB에서 1g.10gb" → [File 6] 예시 근거 확보(기존 '추정' 해소). 1단계의 "Memory 크기와 SM 사용률 요청" 서술은 오류라 정정,
  [Table 1] 문단과 HAMi Scheduler bullet에 MIG는 gpucores 미이용/Memory 기준 명시. 참고: `nvidia.com/mig-<profile>` Resource는 upstream
  migStrategy(mixed, 기본 none) 경로라 HAMi MIG Mode와 별개 — 본문 미기재.
  [Figure 1] HAMi Scheduler 박스를 Mode별로 분리: HAMi-core(gpu, gpumem(-percentage), gpucores) / MIG(gpu, gpumem(-percentage),
  Annotation mig-profile-preference). [Figure 3]은 아직 matplotlib 초안이라 1단계 문구 확인 필요.
- **2026-11-22 두 Mode 중심 재구성** (사용자 요청): 개요를 `operatingmode`의 HAMi-core Mode / MIG Mode 두 방식 비교 bullet로 재작성
  (16GiB 예시, Memory 크기 제한, SM 사용률 제한 bold는 HAMi-core Mode bullet로 이동), 구성 요소에 **HAMi Scheduler** 추가(NVIDIA Resource +
  node-nvidia-register 비교로 Node/GPU 선택, MIG는 Profile과 위치), [Table 1] 문단에 Scheduler의 Resource 해석 문장 추가.
  목차: 1.3 HAMi-core Mode(1.3.1 HAMi-core 주입, 1.3.2 Memory, SM 사용률 제한) / 1.4 MIG Mode(구 1.6 Dynamic MIG) / 1.5 GPU 선택 /
  1.6 GPU Health Check. File 6(GPU 선택) ↔ File 7(MIG) 번호 교환. 1.2에 `operatingmode` 역할 + `remote`는 다루지 않는다는 문장.
  [Figure 1] Claude 초안 재작도(SVG → headless Chrome 1400×820, 소스 미보관): HAMi Scheduler(NVIDIA GPU Resource 4종, Mode별 선택 기준),
  Node A `hami-core`(Pod A 4096/30, Pod B 8192/50, GPU 16GiB Memory/SM 막대, Time-slicing), Node B `mig`(Pod C 8000 → 1g.10gb,
  Pod D 30000 → 3g.40gb, A100 80GB). Pod C/D의 Profile 대응은 "최소 수용 Profile" 가정의 예시(실측 아님). 사용자가 pptx로 재작도 예정.
- **2026-11-22 HAMi 2.11.0 재실측** (사용자 허락으로 qwen3 Deployment를 replicas 0으로 내렸다가 1로 복구, 재기동 Ready 확인):
  [Shell 1] Cache 경로가 `/usr/local/vgpu/usage.cache`로 변경(2.10.0은 UUID.cache), [File 3] epoch 1795279541, [Shell 3] Memory OOM 로그
  (allocator.c:40, OOM 줄 2회, HAMi-core Cleanup Msg 출력), [Shell 4] Metric 32, `nvidia-smi dmon` 12~39%로 2.10.0의 99/0 교차 패턴이 사라져
  Token Bucket Burst 설명을 "제한값 위아래 변동, 평균은 제한값" 서술로 교체(원인은 미조사). 1.1 버전 2.11.0으로, 측정 중 다른 Workload 중지 명시.
  whole GPU 실측 추가: `manifests/hami-wholegpu-test.yaml`(`nvidia.com/gpu: 1`만) → allocated `...,NVIDIA,16311,100:;`, `CUDA_DISABLE_CONTROL=true`,
  `CUDA_DEVICE_SM_LIMIT=100`, `/etc/ld.so.preload` 없음, `/usr/local/vgpu/libvgpu.so`는 Mount됨 → 1.3에 [File 5] + [Shell 2] 추가.
  번호 이동: File 5, 6 → 6, 7, Shell 2, 3 → 3, 4. 측정 스크립트는 남기지 않음(Shell 블록 명령과 동일, SM 측정은 부하 시작 후 40초 대기 후 샘플).
- **2026-11-22 전면 재검토** (사용자 요청: 발행된 kubernetes-hami 글과 중복 제거, NVIDIA 특화 내용 위주). 변경:
  ① 중복 삭제 — [File 3] 아래 Pod Annotation 6종 일반 설명 목록(오류 3개 포함: to-allocate가 allocated로 "옮겨짐", Record 사이 `;`,
  vgpu-time = Bind 시각)을 NVIDIA 특유 사항(키의 `vgpu`, Type `NVIDIA`, 완료 후 `;;`, `success`) 한 문단으로 교체, [Table 2] 문단의
  Allocatable 부풀림 원리, [File 4] 문단의 Scheduler 참조 설명, 1.4 binpack/spread 정의, 1.6 Health의 ListAndWatch/Annotation 두 경로 +
  ignoredByScheduler 문단, 1.3 끝 Port 31992/31993 문장 삭제.
  ② 오류 정정 — [File 1] "gpumem 생략 시 제한 없는 vGPU" → 물리 Memory 전체 요청 = 전용 할당(defaultMemory 0), `operatingmode`에
  `remote`(Lupine GPU server, Chart values.yaml:390) 추가, MPS 문단 "두 가지" 문구 수정. MiB 단위로 통일(Table 1, File 1, File 2, File 6 설명).
  ③ 명칭 — 서술의 hami-device-plugin/hami-scheduler → HAMi Device Plugin/HAMi Scheduler, Container는 `device-plugin`/`vgpu-monitor`.
  ④ 구성 — 개요의 Library 3종 + Mount 경로 + ld.so.preload 원리(구 [Shell 1] 문단)를 신설 `### 1.3. HAMi-core 주입`으로 이동,
  이후 1.4 Memory, SM 사용률 제한 / 1.5 GPU 선택 / 1.6 Dynamic MIG / 1.7 GPU Health Check. Figure/Table/File/Shell 번호는 등장 순서 그대로.
  ⑤ 추가 — 1.3 끝 whole GPU 문단: v2.11.0 nvinternal/plugin/server.go wholeGPUDisableHAMiCoreAllowed(env DISABLE_HAMI_CORE_FOR_WHOLE_GPU
  && DeviceMemoryScaling == 1 && DeviceCoreScaling == 1), isWholeGPUAllocation(모든 GPU Usedmem == 전체 MiB, Usedcores 0 또는 100) →
  ld.so.preload 대신 `CUDA_DISABLE_CONTROL=true`. Chart `devicePlugin.monitor.disableHAMiCoreForWholeGPU: true`(values.yaml:340), env는
  device-plugin, vgpu-monitor 두 Container 모두. Metric 합성은 kubernetes-hami-metrics/CLAUDE.md의 wholegpu.go 근거.
  ⑥ 재실측 시도 실패 — Test Node는 HAMi 2.11.0(Helm revision 5)이지만 qwen3 Pod가 GPU Memory 15000/16311 MiB를 점유해 2000 MiB Test Pod가
  `CardInsufficientMemory`로 Pending → Pod 삭제. qwen3는 건드리지 않음. 1.1의 "HAMi 2.10.0"과 Shell 1~3, File 3은 2026-10-18 2.10.0 실측 그대로 유지.
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

- Memory, SM 격리 (1.1, 1.4): **완료 (2026-10-18), 2026-11-22 2.11.0 재실측** — `manifests/hami-isolation-test.yaml` 재현 파일 보관.
  - RTX 5060 Ti 1장 (Blackwell) 환경이라 nvidia-smi 안에서 `LD_PRELOAD` 환경 변수는 안 보였고 `/etc/ld.so.preload` 파일 주입 방식 확인. 본문도 이에 맞춰 수정.
  - `CUDA_DEVICE_MEMORY_LIMIT_0=2000m` (단위: MiB), `CUDA_DEVICE_SM_LIMIT=30` 둘 다 Container 내 환경 변수로 주입.
- 미수행:
  - use-gputype Annotation 동작 (단일 GPU Node 환경이라 Type 선택 효과 관찰 불가).
  - Dynamic MIG — RTX 5060 Ti는 MIG 미지원이라 회사 A100 환경에서 수행. **준비 완료, 실측 대기** (아래 "Dynamic MIG Test" 섹션).
  - 추가 실측 시 본문에 [Shell N] 블록을 실측 발췌로 추가하고 manifests/ 폴더에 재현 파일을 남길 것 (repo 컨벤션).

## Dynamic MIG Test — 준비 완료, 실측 대기 (2026-11-23)

- 환경: 회사 Alpha EKS Cluster `alpha-kr-dev`의 `gpu-a100-hami` Node Group (p4d.24xlarge, A100-SXM4-40GB 8장), HAMi 2.11.0, `addon-hami` namespace.
  공개 저장소라 AWS 계정/ARN은 여기 기재하지 않음 — `aws sso login --profile alpha-sre` 후 `kubectl config get-contexts | grep alpha-kr-dev`로 context 확인.
- 진행 상태 (2026-11-24): **완전 자동화 end-to-end 검증 완료.** env-charts PR #1456(MIG 전환)·#1457(userData MIG)·#1458(NodeOverlay+mig_reboot)
  모두 머지·sync됨. warmup Pod 없이 config8만 적용 → 자동 프로비저닝 → 자동 MIG 활성화(reboot) → 할당 성공까지 확인. 본문 [Shell 6~9] 모두 실측 반영.
- 재현 절차 (warmup 불필요, 최종):
  1. `export KUBE_CONTEXT=<alpha-kr-dev context>`
  2. `kubectl apply -f manifests/mig/mig-config8.yaml` — NodeOverlay로 Karpenter가 p4d 자동 프로비저닝. 노드는 user script MIG enable+reboot로
     부팅이 평소보다 길다(최초 부팅→reboot→재부팅, ~5분). 고가 인스턴스 — Test 후 회수 확인.
  3. 세 Pod Running 후 `manifests/mig/capture.sh step3-config8` (또는 새 step 이름)
  4. `kubectl delete pod mig-2g-b` → 5초 reconciler 주기 후 `kubectl apply -f manifests/mig/mig-config9.yaml`
  5. `manifests/mig/capture.sh step4-config9`
  6. 정리: 모든 mig Pod delete, Karpenter 노드 회수 확인, dumps 커밋
- 검증된 사실: ① NodeOverlay(node_overlay_capacity)로 gpumem만 요청하는 Pod으로 프로비저닝됨 ② userData mig_reboot로 부팅 시 MIG Mode 자동 Enabled
  (last reboot 2회) ③ binpack으로 세 Pod 같은 GPU, 위치 2g→0,2 / 3g→4 ④ Config 9 전환 시 mig-2g-a/mig-3g migUUID 유지, Idle 2g는
  cached released→reclaimed under placement pressure로 제거 후 1g×2 생성(위치 2,3). mig_topology_test.go 예측과 일치.

## 폴더 구조

- `index.md`, `index.en.md` — 문서 본문 (둘 다 draft).
- `manifests/` — hami-isolation-test, hami-wholegpu-test, hami-priority-high/low, matmul-rate.py.
- `manifests/mig/` — Dynamic MIG Test: `mig-config8.yaml`(2g ×2 + 3g), `mig-config9.yaml`(1g ×2), `capture.sh`(단계별 Log·상태 수집, `KUBE_CONTEXT` 필요).
  (초기 warmup/gpu-admin manifest는 NodeOverlay·userData 자동화로 불필요해져 삭제)
- `dumps/mig/<step>/` — 단계별 수집 결과. step0-provision(Karpenter gpumem 거부), step1-mig-enable-pending(Ampere MIG pending 실측),
  step2-mig-enable-fix(수동 reset 거부·reboot 진단), step3-config8·step4-config9(MIG Instance 생성/전환), step5-automated(end-to-end 자동화).
- `images/` — Figure 3종, 2026-11-22 모두 Claude SVG 초안으로 교체(사용자 pptx 재작도 가능, SVG 소스 미보관).

## 2026-11-14 [Table 3] 추가

- 사용자 요청으로 1.2의 [File 4] 설명 문단을 [Table 3] "NVIDIA GPU의 Node Register Annotation 값"으로 대체 (kubernetes-hami 글의
  벤더 중립 [Table 3]과 짝). 근거: HAMi v2.11.0 nvinternal/plugin/register.go — count=DeviceSplitCount, devmem=MiB×DeviceMemoryScaling,
  devcore=100×DeviceCoreScaling(MIG는 100), type=NormalizeDeviceModel(`NVIDIA` 접두사), numa=sysfs, mode=operatingMode, health.
  기존 문단의 "Core 수 (`devcore`)"는 부정확(실제는 %)이라 수정됨. `index`, `numa` 0 생략(omitempty), devmem이 표기 용량보다 작은 점
  ([File 4] 16311 MiB) 한 문장 추가.
- 같은 날 kubernetes-hami 글에서 옮겨 온 내용으로 [Table 2] 설명 문단 보강 후 2문단 분할: Allocatable = 물리 GPU 개수 × `deviceSplitCount`,
  `deviceCoreScaling` > 1이면 SM 사용률 초과 할당 가능.

- 2026-11-21 kubernetes-hami 글 1.4에서 옮긴 설정을 정정하여 1.2에 [Table 3] "Pod 요청을 보정하는 vGPU 설정" 추가(기존 [Table 3] → [Table 4]).
  근거 v2.11.0 pkg/device/nvidia/device.go: MutateAdmission — runtimeClassName(spec.runtimeClassName이 nil일 때), defaultGPUNum(Memory/Core만
  요청 시 개수 보충), overwriteEnv(GPU 미요청 Container에 `NVIDIA_VISIBLE_DEVICES=none`, Pod/Container별 OverwriteEnvDecision 우선);
  GenerateResourceRequests — defaultMemory(0이면 mempnum=100 즉 전체), defaultCores. 기본값은 Test Node ConfigMap 실측(0, 0, 1, false, "").

# kubernetes-hami 문서 작업 컨텍스트

HAMi 자체(이기종 AI 가속기 가상화 Middleware)에 포커스를 두고 Architecture와 공통 동작 원리(등록 → Scheduling → 할당)를
분석하는 문서. NVIDIA GPU는 예시로만 이용한다. **2026-10-16에 글을 3개로 분리**:

- kubernetes-hami (이 글) — HAMi 자체, 벤더 중립 구조
- kubernetes-hami-nvidia-gpu — NVIDIA GPU 기능 (vGPU 설정, HAMi-core 격리, GPU 선택, Dynamic MIG)
- kubernetes-hami-dra — HAMi의 DRA 구현

세 글 모두 draft 상태. 분리 전 글(2026-10-09 초안)의 HAMi-core 격리 섹션과 vGPU Resource Table은 kubernetes-hami-nvidia-gpu로 이동함.

## 문서 구성 및 상태

- **2026-11-11 HAMi v2.11.0 기준으로 전환** (사용자 요청): Test Node(192.168.1.32, kubeadm v1.34.12)의 HAMi를 Chart 2.10.0 → 2.11.0으로
  upgrade(values `prometheus.enabled=true` 유지, 최종 revision 5, qwen3 Pod 무중단)하고 [Shell 1], [Shell 2], [Shell 3]을 재실측으로 교체.
  v2.11.0 변화: ① hami-scheduler HTTP Listener 분리 — `--http_bind=0.0.0.0:9443`(`/webhook`, `/refit`, Probe, Service 443 → 9443)와
  `--extender-bind=127.0.0.1:9444`(`/filter`, `/bind`, Loopback 전용 — 호출자 미인증이라 분리), Extender `urlPrefix: https://127.0.0.1:9444`
  ② `hami-scheduler` Service NodePort → ClusterIP(443/TCP, 31993/TCP — 31993은 Metric Port 9395로 연결)
  ③ Webhook rules에 `UPDATE` 추가 — 생성 후 `hami.io/` 할당 Annotation 변경 방지(pkg/scheduler/webhook.go handleUpdate)
  ④ device-config Section 13종(nvidia, cambricon, hygon, metax, enflame, mthreads, iluvatars, kunlun, awsneuron, amd, vastai, biren, vnpus)
  — 본문의 "2.10.0 총 14종" 문장을 "2.11.0 ConfigMap 13종 설정"으로 교체. Hygon은 `hcunum/hcumem/hcucores`(옛 Shell 2의 dcunum은 오기였음).
  같은 날 사용자 요청으로 1.3에 **NUMA Refit** 과정 추가 (v2.11.0 소스 기반, 실측 없음 — Test Node는 기본값이라 비활성): Device Plugin이
  표준 `GetPreferredAllocation()` 처리 중 Annotation GPU가 Topology Manager 허용 목록에 없으면 hami-scheduler `/refit`(9443, Device Plugin
  ServiceAccount Token 인증) 호출 → 허용 GPU 안에서 동일 정책으로 재선택, Annotation/할당 내역 갱신 후 반환. Kubernetes 표준 API 아님(HAMi 자체
  프로토콜). Helm `devicePlugin.numaRefit.enabled: false` 기본, `devices.nvidia.enableNumaTopology` + Node `enablegetpreferredallocation` +
  Pod `hami.io/numa-alignment`(best-effort/strict) 필요, NVIDIA만(MIG 제외), Issue #2080. 근거: pkg/device/numa_refit.go,
  pkg/scheduler/numa_refit.go(fitInRestrictedDevices), nvinternal/plugin/server.go(GetPreferredAllocation → tryNumaRefit), charts values.yaml.
  벤더 중립 방침의 예외로 "현재 NVIDIA GPU만 지원"을 본문에 명시.
  이어서 사용자 요청으로 `#### 1.3.1. NUMA Refit`으로 분리하고 배경 문단 추가: Guaranteed Pod의 CPU는 Bind 이후 kubelet CPU Manager가
  결정하고 kube-apiserver에 공개되지 않아 hami-scheduler가 Scheduling 시점에 CPU의 NUMA를 알 수 없음(근거: Issue #2080 실측 — CPU NUMA 0,
  Scheduler 선택 GPU NUMA 14). hami-scheduler가 재선택하는 이유(할당 내역 관리, 과할당 방지)는 둘째 문단으로 이동.
- **2026-11-17 한계 문단을 [Table 1]로 전환** (사용자 요청): "Device Plugin 방식의 한계 | HAMi의 해결 방식" 4행 표 + 설명 문단.
  기존 Table 1~3은 Table 2~4로 재번호(본문 참조 모두 갱신).
- **2026-11-17 개요에 Device Plugin 방식 한계 문단 추가** (사용자 요청): 첫 문단 뒤에 한계 4가지(정수 개수 Resource, kube-scheduler는
  Node별 개수만 인지, Accelerator 선택이 Bind 이후 kubelet/Device Plugin에서 일어나 Cluster 할당 내역 미반영, 사용량 제한 수단 없음)와
  HAMi의 해결 구조를 서술. 첫 문단의 "개수 단위로만 할당할 수 있지만" 문구는 중복이라 제거, 1.3 도입의 Device Plugin 비교 2문장 삭제.
- **2026-11-21 [Figure 5] NUMA Refit 그림 추가** (사용자 요청, Claude 초안): images/hami-numa-refit.png(SVG → headless Chrome, 1310×700,
  Figure 3/4 스타일, 소스 미보관). 1.4.1 맨 앞 배치, 단계 5개로 분리(③ 재선택 + Annotation 갱신 ④ Device Plugin에 반환 ⑤ GPA 응답).
  실행 시점 문장 "[Figure 4]의 1번 Allocate()보다 먼저"와 1단계 "Kubernetes Device Plugin 규격의 표준 API인 GetPreferredAllocation()" 추가.
- **2026-11-21 1.4.1 배경 문단 조건 명시** (사용자 요청, 소스 확인 후): HAMi 코드(numa_refit*.go, plugin server.go)는 QoS를 직접 검사하지 않고
  Topology Manager 허용 목록에 선택 GPU가 없으면 동작. Guaranteed 조건은 Kubernetes CPU Manager `static` 정책(Guaranteed + 정수 CPU에 전용
  CPU 할당) 동작이며 Issue #2080 재현 환경(CPU Manager static, Topology Manager single-numa-node, Guaranteed QoS + 8 whole CPUs)과 일치.
  본문에 `static` 정책과 정수 CPU 조건, Topology Manager `single-numa-node` 예시를 명시.
- **2026-11-21 1.4 설정 문단 삭제** (사용자 지적): "`Allocate()` 응답으로 반환하는 Container 설정은 … defaultMemory/defaultCores/defaultGPUNum,
  overwriteEnv, runtimeClassName으로 조정" 문단은 사실과 다름 — v2.11.0 pkg/device/nvidia/device.go 확인 결과 runtimeClassName, defaultGPUNum,
  overwriteEnv(GPU 미요청 Container에 `NVIDIA_VISIBLE_DEVICES=none` 주입)는 Mutating Webhook(MutateAdmission), defaultMemory/defaultCores는
  HAMi Scheduler(GenerateResourceRequests)에서 적용. 벤더 설정이라 kubernetes-hami-nvidia-gpu [Table 3]으로 이동.
- **2026-11-21 격리 Library 전달 경로를 개요로 이동** (사용자 요청): 1.4의 2문단(Library 전달 경로, NVIDIA `/usr/local/vgpu`,
  `/etc/ld.so.preload`)을 삭제하고, 개요의 [Figure 1] 예시 문단 뒤에 벤더 중립 문단 하나로 이동 — Figure 1의 Copy/Bind Mount 화살표와 연결.
  NVIDIA 전용 세부(`/usr/local/vgpu`, `ld.so.preload` Mount, Dynamic Linker 선적재)는 본문에서 제외 — 근거는 아래 2026-11-12 기록에 유지.
- **2026-11-21 Figure 4 사용자 재작도 + 1.4 8단계로 재작성**: ⑤ `bind-phase: success` ⑥ `mutex.lock` 삭제(Lock 해제) ⑦ `Allocate()` 응답 반환
  ⑧ kubelet이 Pod 생성(Device Manager는 Pod Admission 시 Container별 Allocate, 응답은 Container 생성 시 적용). 할당 완료 후
  `devices-to-allocate` 실측 값은 `;;` — DecodePodDevices가 끝 `;` 뒤 빈 구간도 Container로 보존(주석 "Do NOT skip empty"), 재인코딩 시
  빈 구간마다 `;` → Container 1개 Pod도 `;;`. (Claude가 처음에 `;`라고 잘못 판단했다가 사용자 실측으로 정정.)
- **2026-11-17 예시 값 원칙** (사용자 합의): 벤더마다 달라지는 값(`[accelerator]` 키, `[UUID-N]`, `[Type]`)만 자리 표시, 벤더 무관 값은
  Figure 1과 맞춘 실제 값 — Node `gpu-node`, Pod `poda`(Namespace `default`), Pod A 할당량 GPU 2개 × 80%. [File 3] Lock 값은
  `…,default,poda`. `hami.io/mutex.lock` bullet에 값 형식, Lock 동안 Bind 불가, 할당 완료 시 삭제(ReleaseNodeLock이 `null` patch) 보강.
- **2026-11-16 Pod `devices-*` 값 형식 보강**: Type 값 = 벤더 Device 타입 상수(v2.11.0 — NVIDIA `NVIDIA`, AMD `AMD`, Cambricon `MLU`,
  Hygon `HCU`, Mthreads `Mthreads`, Ascend는 `CommonWord()` Chip 이름). Container 매핑은 이름 없이 `;` 구간 순서(Init Container 먼저) —
  popNextContainerDevices. 형식 표기는 공백 없이 `UUID,Type,Memory,Core`.
- **2026-11-16 [File 1], [File 2] 자리 표시 방식으로 통일** (사용자 선택): 키는 `hami.io/node-[accelerator]-register`,
  `hami.io/[accelerator]-devices-*`, 값의 UUID/Type은 `[UUID-1]`, `[UUID-2]`, `[Type]`. 근거: v2.11.0 Pod `devices-*` 키 이름만 벤더별
  (NVIDIA `vgpu`, AMD `amd`, Cambricon `cambricon-mlu`, Hygon `hcu`, Ascend `<commonWord>`, Kunlun은 `hami.io/kunlun-allocated` 하나뿐),
  값은 공통 EncodePodSingleDevice. `vgpu-node`, `vgpu-time`, `bind-phase`, `bind-time`, `mutex.lock`은 pkg/util 공통 상수라 모든 벤더 동일.
  [Table 3]의 예시 값 열은 사용자 요청으로 넣은 NVIDIA 구체 값 유지.
- **2026-11-16 [File 2] 예시 값 구체화** (사용자 요청, 실측 아님): 형식 근거 v2.11.0 pkg/device/devices.go EncodeContainerDevices
  (`UUID,Type,Usedmem,Usedcores` + `:`; Slots>1이면 5번째 필드) / EncodePodSingleDevice(Container 끝 `;`), Type은 NVIDIA `"NVIDIA"`.
  할당 완료 후 `devices-to-allocate`는 patchErasedAnnotation으로 빈 Container만 남아 `";"`. 이후 사용자 요청으로 예시를 Scheduling 완료 +
  할당 전 상태로 변경(`devices-to-allocate` = `devices-allocated` 동일 값, `bind-phase: allocating`). 예시는 Figure 1 Pod A(GPU 2개 × 80%,
  A100 80GB → 65536 MiB), UUID는 [File 1]과 동일, Node `gpu-node`(Figure 1), 시각은 2026-11-15 16:42:07 KST epoch.
- **2026-11-16 [File 2], [File 3] 연속 배치** (사용자 요청): 두 File을 붙이고 설명을 한 문단 + 하나의 bullet 목록으로 통합
  (`hami.io/mutex.lock` bullet 추가). 기존 [File 3] 단독 설명 문단은 통합 문단으로 흡수.
- **2026-11-16 `#### 1.3.1. Scheduling 정책` 신설** (사용자 요청): `hami.io/node-scheduler-policy`, `hami.io/gpu-scheduler-policy`를 [File 2]와
  bullet에서 제거하고 1.3.1로 이동. 구성: 정책 정의 문단 → [File 4] 정책 Annotation 예시 + bullet → 점수 계산 문단. [File 2]는 Scheduler
  Extender가 기록하는 Annotation만 남김(주석 줄 제거).
- **2026-11-15 1.3 순서 재배치** (사용자 요청): 단계 목록 → [File 2] Pod Annotation(+bullet) → [File 3] Lock Annotation →
  [Shell 3] KubeSchedulerConfiguration(+2문단) → Scheduling 정책 2문단. Annotation Key를 먼저 보여 주고 설정 설명이 뒤따르도록 함.
- **2026-11-15 Lock 설명 축소** (사용자 요청): 1.3 Lock 상세 문단 2개(만료 5분, 대기 중 Pod 보호, 삭제 Pod 해제) 삭제 → 8단계에
  "Lock이 이미 걸려 있으면 Bind 실패, kube-scheduler가 다시 Queue에 넣어 재Scheduling" 한 문장만 추가. Lock 예시는 1.3 끝(Pod Annotation
  File 뒤)으로 옮겨 [File 3], Pod Annotation은 다시 [File 2]. 아래 두 항목의 Lock 세부 근거는 기록으로만 유지.
- **2026-11-15 [File 2] Lock Annotation 예시 추가** (사용자 요청): 1.3 Lock 문단 앞에 `hami.io/mutex.lock` 예시 File 삽입, 기존 [File 2]
  (Pod Annotation)는 [File 3]으로 재번호. 값 형식은 `<RFC3339Nano 시각>,<namespace>,<pod>` (nodelock.go GenerateNodeLockKeyByPod) —
  예시 값은 형식에 맞춘 작성 예(Pod 이름은 Test Node의 qwen3 Pod 이름 차용), 실측 아님.
- **2026-11-15 Node Lock 동작 문단 추가** (사용자 요청, 1.3 단계 목록 뒤): 근거 v2.11.0 pkg/util/nodelock/nodelock.go LockNode —
  Lock 값에 시각과 Pod ns/name, 다른 Pod가 유효 Lock 보유 시 ErrNodeLockContention → Bind 실패 → kube-scheduler 재시도. 만료는
  `NodeLockTimeout`(기본 5분, Chart `scheduler.nodeLockExpire` → env `HAMI_NODELOCK_EXPIRE`). 만료돼도 보유 Pod가 아직 할당 대기 중이면
  넘기지 않음(issue #3096, podAwaitingAllocation), 보유 Pod가 없으면(NotFound) 즉시 해제 후 획득. PodGroup의 NodeLockRetryTimeout 재시도와
  같은 Pod의 다중 벤더 Lock 재진입은 본문 미기재. 같은 날 7단계에 `/bind` 요청의 Node와 Filter 선택 Node 일치 확인(verifyBindTarget) 추가,
  "Node Annotation (`x`)" 표기를 "`x` Node Annotation"으로 통일.
- **2026-11-15 Figure 3 사용자 재작도 반영** (pptx 스타일): 최종 10단계 (사용자가 9단계 묶음안을 거쳐 다시 10단계로 확정) — 1.3을 10단계로 재작성 — ③ Node Annotation 조회와 ④ 선택을 분리, ⑥ `/filter` 응답으로
  Node 반환, ⑧ Lock, ⑨ `bind-phase`/`bind-time`, ⑩ Binding API로 `spec.nodeName` 설정(Extender의 `s.kubeClient...Pods().Bind()`).
  사용자 그림 검토 시 지적: 8번 중복(Lock과 nodeName), nodeName 화살표가 kube-scheduler에서 출발(실제는 bindVerb 설정으로 Extender가
  Binding API 호출), 순서는 Lock → bind Annotation → Binding이므로 nodeName은 10번, "accelector" 오타, "gpu annotations" 벤더 표현.
- **2026-11-15 Figure 3, 4 재작도 + 1.3/1.4 단계 재작성** (사용자 요청: 사용되는 Annotation 모두 표현). Claude가 SVG → headless Chrome PNG로 작도
  (Figure 3 1400×720, Figure 4 1300×720, width 900px, 소스 미보관). YAML 줄 끝 `(N)`으로 단계 번호 표시. 근거(v2.11.0):
  Filter(scheduler.go) — `vgpu-node`(AssignedNode), `vgpu-time`(AssignedTime), PatchAnnotations로 `devices-to-allocate`(InRequestDevices)와
  `devices-allocated`(SupportDevices) 동일 값 기록. Bind — acquireNodeLocks(Node `hami.io/mutex.lock`, 값에 Pod ns/name) → `bind-phase: allocating`,
  `bind-time` → Bind. Allocate(nvinternal/plugin) — GetPendingPod가 Node `mutex.lock`에서 Pod 조회 → `devices-to-allocate` decode →
  patchErasedAnnotation(할당 마친 항목 삭제) → podAllocationTrySuccess(모두 지워지면 `bind-phase: success` + ReleaseNodeLock) → 응답 반환.
  1.3은 8단계, 1.4는 7단계. [File 2] bullet 정정: `vgpu-time`은 Bind 시각이 아니라 선택(Filter) 시각, `bind-phase` 값 3종, `devices-to-allocate` 의미.
- **2026-11-15 1.5 재구성** (사용자 요청): 제목 "Mutating Webhook 검증 동작" → "Pod 검증". 도입 문단에 [Figure 1]의 Mutating Webhook
  경로가 `UPDATE`에도 이용된다는 점 명시. 거부 항목 3개(할당 Annotation 보호, nodeName 지정, privileged) 개조식 + 보호 이유 문단 +
  "검증이 적용되지 않는 경우" 문단(ignore Label, `failurePolicy: Ignore`)으로 분리. 1.2 [Shell 2] 설명에서는 `UPDATE` 언급 제거,
  첫 문장을 "[Figure 1]의 Mutating Webhook 경로에 이용되는 …"으로 수정. 1.2 제목은 "HAMi Scheduler 지정", 1.1 끝에 제조사 Plugin 위임 문장 추가.
- **2026-11-15 절 제목 정리** (사용자 요청): 제목에서 "과정" 제거, "Device" → "Accelerator" (1.1 Accelerator 등록, 1.2 Scheduler 선택,
  1.3 Accelerator Scheduling, 1.4 Accelerator 할당). Figure 2~4 캡션과 각 절 도입 문장, [File 1]/[File 2] 설명도 함께 변경.
  1.1/1.4 도입 문장은 "X는 HAMi Device Plugin이 수행하며, …" 형태로 통일. HAMi 용어인 "Device Scheduling 정책"(Node/Device 정책 구분,
  `hami.io/gpu-scheduler-policy`)과 이미지 파일명(hami-device-*.png)은 유지.
- **2026-11-15 `### 1.5. Mutating Webhook 검증 동작` 신설** (사용자 요청): 1.2의 `UPDATE`/ignore Label 문장과 1.3 끝 Annotation 보호 문단을
  1.5로 모으고 검증 항목 추가 — 할당 Annotation 보호, `spec.nodeName` 사전 지정 거부("pod has node assigned"), privileged Container 거부
  (Accelerator 요청 Pod 한정), ignore Label 제외, `failurePolicy: Ignore`(Chart `scheduler.admissionWebhook.failurePolicy`). 근거:
  v2.11.0 pkg/scheduler/webhook.go Handle/handleUpdate. privileged 거부 이유("모든 Device 접근")와 nodeName 거부 이유는 코드 주석이 아닌
  추론 문장이므로 필요 시 재검토.
- **2026-11-15 1.3 단계에서 Webhook 제거** (사용자 요청, 1.2와 중복): 1.3을 4단계로 축소 — ① kube-scheduler가 `schedulerName: hami-scheduler`
  Pod의 Scheduling 시작 + Filter에서 Extender 호출 ② Node/Accelerator 선택 ③ Annotation 기록 + Node 하나 반환 ④ Bind.
  이어서 사용자 요청으로 Claude가 Figure 3을 새로 작도(SVG → headless Chrome PNG 1150×700, Figure 1/2 스타일, 소스 파일은 남기지 않음,
  사용자가 pptx로 재작도 가능)하고 1.3을 그림에 맞춰 7단계로 재작성: ① Watch pod(`schedulerName: hami-scheduler`) ② `/filter` 호출
  ③ Node Annotation 읽고 Node/Accelerator 선택 ④ Pod Annotation(`devices-allocated`, `vgpu-node`) 기록 ⑤ Node 하나 반환 ⑥ `/bind` 호출
  ⑦ `bind-phase: allocating` 기록 + Bind. 근거: v2.11.0 scheduler.go Filter(AssignedNodeAnnotations 등 patch), Bind(DeviceBindPhase
  allocating, BindTimeAnnotations). Figure 3 width 650px → 900px, 도입 문단에 "[Figure 1]의 Scheduler Extender 경로에 해당" 추가.
- **2026-11-15 1.1과 1.2 순서 교체** (사용자 요청): 시간 순서(설치 시 등록 → Pod 생성 시 Webhook → Scheduling → 할당)에 맞춰
  1.1 Device 등록 과정, 1.2 Scheduler 선택 과정으로 교체. Figure/File/Shell/Table 번호는 등장 순서가 그대로 유지되어 재번호 불필요
  (Shell 1 개요 → Figure 2, File 1, Table 3 → Shell 2 → Figure 3 …).
- **2026-11-15 handshake/존재 판단 문단 삭제** (사용자 요청): [Table 3] 뒤의 "HAMi Scheduler는 Allocatable > 0이면 Plugin 동작 중으로 판단,
  Annotation 변경 시에만 재조회, 옛 `hami.io/node-handshake` 계열은 2.11.0에서 미사용·발견 시 삭제" 문단 제거 (근거는 2026-11-14 기록에 유지).
  본문에 handshake 언급은 더 이상 없음.
- **2026-11-15 [Table 3] 정리** (사용자 요청): 표 아래 "예시 값은 NVIDIA GPU 2개, 분할 개수 2 기준" 문장 삭제. `mode` 예시에서 `"mps"` 제거 —
  v2.11.0에서 `nvidia.MpsMode = "mps"`는 pkg/device/nvidia/device.go:73에 상수로만 정의되고 사용처 없음. Chart values.yaml의 `operatingmode`
  허용 값은 `hami-core`, `mig`, `remote`(Lupine 원격 GPU). cmd/device-plugin/nvidia/main.go의 MPS 분기는 upstream NVIDIA Plugin의
  `sharing.mps` 설정 경로라 HAMi `mode` 값과 무관. kubernetes-hami-nvidia-gpu [Table 3]의 `mode` 값도 `mps` → `remote`로 수정.
- **2026-11-15 1.2 세부 문단 3개 삭제** (사용자 요청, 등록 흐름 중심으로 단순화): ① 장애 감지 방식 문단(Event 방식 NVIDIA / Polling 방식
  Ascend, AMD, 복구 동작 차이 — 근거는 아래 2026-11-06 기록) ② 장애 시 동작 문단 → 4단계에 한 문장으로 흡수(`Unhealthy` 재전달 +
  Annotation `health` 갱신) ③ Accelerator별 설정 문단(NVIDIA/Ascend `deviceSplitCount`, AMD Plugin 옵션 `splitCount`, Memory/Core 비율 설정).
  NVIDIA Health 세부는 kubernetes-hami-nvidia-gpu 1.6에 있음. 1.2 본문에 Event/Polling 구분은 더 이상 없음.
- **2026-11-14 분할 개수 설정 벤더 중립화** (사용자 요청): `deviceSplitCount`는 NVIDIA 전용이 아님 — HAMi 2.11.0 Chart device-configmap의
  `nvidia.deviceSplitCount`, `vnpus.deviceSplitCount`(Ascend, hami-core/ENPU Mode, 기본 10), AMD는 Plugin 옵션 `splitCount`(기본 10, gfx12+는 2,
  amd-device-plugin plugin.go splitCountFor). 본문 1.2 단계 1, 5와 [File 1] 기준 문장은 "분할 개수 (설정)"으로 일반화, 1.2 끝 설정 문단은
  "Accelerator별 설정, 이름과 위치가 다름 + NVIDIA/Ascend는 `deviceSplitCount`, AMD는 Plugin 옵션" 예시로 축약하고 scaling 기본값,
  과할당, OOM, nodeconfig 세부는 kubernetes-hami-nvidia-gpu 1.2로 이동. [Shell 1] 설명의 NVIDIA Section 설정 나열도 일반 문장으로 교체
  ([Shell 1] 출력의 `deviceSplitCount` 줄은 실측이라 유지). Figure 1, 2의 `deviceSplitCount: 2` 박스는 NVIDIA/Ascend 공통이라 유지.
- **2026-11-14 [File 1] 재작성 + [Table 3] 추가** (사용자 요청, v2.11.0 소스 기반): [File 1]에서 handshake 2줄 제거, register 값을
  축약 예시로 교체. 벤더 중립 [Table 3] (Register Annotation 항목: id, index, count, devmem, devcore, type, numa, mode, health) 추가.
  근거: 공통 구조체 pkg/device/devices.go `DeviceInfo`(json tag, omitempty) — Ascend(ascend-device-plugin register.go), AMD도 같은 구조체 사용.
  값은 벤더별로 다름: devcore NVIDIA 100×scaling(%) vs AMD CU 개수, Ascend numa 항상 0, type은 Ascend commonWord.
  인코딩: NVIDIA/AMD/Ascend/Biren/Vastai는 JSON(UnMarshalNodeDevices), Hygon/Iluvatar는 쉼표 구분(DecodeNodeDevices).
  **handshake 폐기 확인**: v2.11.0 `device.CheckHealth`는 `RemoveObsoleteHandshake`로 `hami.io/node-handshake*`를 삭제하고,
  Allocatable 개수 > 0 + register Annotation 변경 여부로만 판단 → 옛 handshake bullet(Requesting_, 60초)을 대체 문단으로 교체.
  참고: 별도 저장소 dcu-vgpu-device-plugin(master)은 `hami.io/node-dcu-register`(쉼표 형식) + `hami.io/node-handshake-dcu`("Reported …")를
  30초마다 함께 patch하지만, v2.11.0 Hygon은 `hami.io/node-hcu-register`를 읽음(키 불일치 — 구버전 Plugin으로 판단, 본문 미기재).
- **2026-11-14 1.2 등록 단계 재작성** (사용자가 Figure 2를 pptx 스타일로 재작도, 소스 기반): 단계 재구성 — ① Accelerator 탐색
  ② `/var/lib/kubelet/device-plugins/`에 Socket 생성 + gRPC Server 시작 (NVIDIA `nvidia-gpu.sock`) ③ `kubelet.sock`으로 `Register()`
  (Resource 이름 + Socket 파일 이름) ④ Health 확인 시작(그림 재수정 반영, 7단계로 확장) ⑤ 해당 Socket으로 `ListAndWatch()`, 부풀림 예시를 Figure 1, 2와 맞춰 물리 2개 × split 2 = 4로 변경
  ⑥ kubelet이 kube-apiserver에 Allocatable/Capacity 반영 ⑦ Node Annotation 기록(그림에는 없음). 근거: nvinternal/plugin/server.go Start()의 순서
  (deviceInventory → Serve → Register → CheckHealth goroutine → WatchAndRegister), getPluginSocketPath.
  Socket 이름 규칙 조사(본문 미기재): Kubernetes는 디렉터리만 규정, Register의 Endpoint는 파일 이름. NVIDIA `nvidia-<resource>.sock`,
  Ascend `<commonWord>.sock`, AMD/Biren은 kubevirt device-plugin-manager의 `<ResourceNamespace>_<PluginName>` (확장자 없음, dpm/plugin.go:54).
- **2026-11-13 Annotation 보호 문단 이동** (사용자 요청): 1.1 끝의 Annotation 보호 문단을 1.3 [File 2] Annotation 목록 바로 뒤로 이동
  (Annotation 정의 뒤에 보호 이유가 오도록). 1.1에는 `UPDATE` 용도 한 문장만 남김. 보호 대상 목록은 schedulerOwnedAnnotationKeys() 기준으로
  정확히 나열(`devices-to-allocate`, `devices-allocated`, `vgpu-node`, `bind-phase`, `bind-time` — `vgpu-time`은 보호 대상 아님).
  같은 날 1.1 Webhook 검사 대상 문장을 "`hami-scheduler-device` ConfigMap에 등록된 Accelerator Resource ([Table 1], [Table 2] 등)"로 수정.
- **2026-11-13 Component 명칭 통일** (사용자 요청): 본문 서술의 `hami-scheduler` → **HAMi Scheduler**, HAMi Protocol을 따르는
  Device Plugin → **HAMi Device Plugin**. 코드 표기(`hami-scheduler` Service/ConfigMap/`schedulerName` 값, Shell 출력)는 그대로 둠.
  일반 개념인 "Device Plugin 방식", "kubelet의 Device Plugin 규격/Unix Domain Socket", "제조사/벤더 Device Plugin", "일반적인 Device Plugin",
  [Table 1]/[Table 2] 캡션, 열 이름, 패키징 설명(개요 Table 문단)은 일반 명칭 유지.
- **2026-11-12 격리 Library 설치 경로 추가** (사용자 요청, v2.11.0 소스 기반, 실측 없음): 1.4 Library 전달 문단에 설치 과정 추가 후
  2문단으로 분할. Device Plugin DaemonSet이 Host `/usr/local/vgpu`(Helm `devicePlugin.libPath`)를 hostPath로 Mount → `postStart`의
  `vgpu-init.sh`가 Image의 `/k8s-vgpu/lib/nvidia/`를 MD5 비교 후 복사, `ld.so.preload`는 경로에 맞게 재생성 → `Allocate()` Mounts로
  `libvgpu.so`(RO)와 `/etc/ld.so.preload`를 Container에 Bind Mount(nvinternal/plugin/server.go). 주입은 `LD_PRELOAD` 환경 변수가 아니라
  `/etc/ld.so.preload` 파일 방식 — 아래 2026-10-31 기록의 "env+LD_PRELOAD"는 부정확. 벤더 중립 방침의 예외로 "NVIDIA GPU는" 명시.
- **2026-11-12 구성 변경** (사용자 요청): `### 1.1. Scheduler 선택 과정` 신설 → 기존 1.1~1.3은 1.2~1.4, NUMA Refit은 1.4.1.
  Webhook [Shell]과 설명 문단을 1.1로 이동하고 Annotation 보호 문단 추가(v2.11.0 pkg/scheduler/webhook.go: CREATE 시
  scheduler-owned Annotation(`hami.io/vgpu-node`, `bind-time`, `bind-phase`, 벤더별 devices-to-allocate/allocated) 사전 지정 거부,
  UPDATE 시 SubjectAccessReview로 nodes patch 권한 + `schedulerName == hami-scheduler`인 경우만 변경 허용. 변경 대상은
  `default-scheduler` Pod만 — `--force-overwrite-default-scheduler` 기본 true). Shell 번호를 등장 순서로 재정렬:
  ConfigMap = Shell 1, Webhook = Shell 2, KubeSchedulerConfiguration = Shell 3.
  같은 작업에서 1.3 단계 목록 정정(이전 미해결 항목 해소): Extender는 Filter 단계에서만 호출, Filter 안에서 점수 계산 후
  `devices-allocated`/`vgpu-node` Annotation 기록 + Node 하나 반환(scheduler.go Filter), Bind 단계에서 `bind-phase: allocating`,
  `bind-time` 기록 후 Bind(scheduler.go Bind). [Shell 3] 설명 문단에도 `prioritizeVerb` 부재 이유 한 문장 추가.
- **2026-11-06 Health 상태 추가** (사용자 요청, 소스 기반): 1.1에 Unhealthy 전달 문단 추가, kubelet 규격 문장을 "ID와 Health 상태 같은 제한된 정보"로 수정.
  Handshake bullet을 v2.10.0 pkg/device/devices.go CheckHealth 기준으로 정정 — 주기 갱신 아님. Test Node 실측: Allocatable 10에서 Timestamp가
  2026-10-17에 멈춰 있음. Scheduler 제외는 여러 벤더 코드의 CardNotHealth로, vGPU 전체 Unhealthy는 NVIDIA 코드로 확인. 다른 벤더 Plugin의 Unhealthy 전달은 미확인.
  같은 날 사용자 요청으로 감지 방식 추가 (벤더 중립 방침의 예외로 괄호에 벤더 이름 표기): NVIDIA는 NVML Event(rm/health.go), Ascend는 약 30초 주기 DCMI 조회와 양방향 갱신
  (ascend-device-plugin internal/server/register.go, master), AMD는 DRM과 Metrics Exporter 조회(amd-device-plugin master, `pulse` 기본 0으로 Chart 설정 미확인, 복구 동작은 코드 일부만 확인).
  Kunlun은 Scheduler 쪽 GetNodeDevices에서 `Health: true`로 고정되는 것만 확인해 본문 미기재. 제조사 Plugin(Table 2)은 개별 미확인.
- **2026-11-06 Library 전달 경로 추가** (사용자 요청, 소스 기반, 실측 없음): 1.3 단계 목록 뒤에 격리 Library(Allocate 응답 Mount 항목 →
  kubelet → Container Runtime이 Bind Mount)와 Driver Library(벤더별: Runtime 확장 주입 또는 Mount 항목) 문단 추가. 벤더 중립 유지.
  근거: HAMi v2.10.0 NVIDIA Allocate, ascend-device-plugin master eNPU Mount. AMD 등 다른 벤더 Plugin은 미확인.
- **2026-10-16 재작성** (Claude 작성, 사용자 검토 전, frontmatter `draft: true`). **실측 없음** — Shell 블록 없음.
  index.en.md는 초안 확정 전이라 미작성.
- **2026-10-31 Library 중심 구성 탈피** (사용자 피드백: Library 가상화 중심으로 나머지 기법이 끼어든 구성): ① 개요의 세 번째
  구성 요소를 "격리 Library"에서 **"격리 계층"**으로 일반화 (Library/Driver/Hardware 세 수준 명시, NVIDIA Library는 예시로 격하.
  "Component 3종" → "요소 3종") ② Table 1 문단의 세 계층 정의 문장을 "[Table 1]에 함께 표시" 한 줄로 축약 (정의는 개요
  개조식, 상세는 1.3으로 일원화) ③ 1.3 할당 단계 3, 4를 계층 중립으로 수정 (3: "격리 설정 반환, 내용은 계층에 따라 다름 —
  NVIDIA는 env+LD_PRELOAD" / 4: "격리 계층이 제한을 강제"). **Figure 1 재작도 시 세 번째 블록명도 "격리 Library" →
  "격리 계층"으로 변경 필요.**
- **2026-11-01 Annotation 절 해체** (사용자 피드백: 별도 절 대신 사용되는 절에 배치): "1.4 HAMi Annotation 정리"를 삭제하고
  [File 1] Node Annotation(+register/handshake 개조식)은 1.1 마지막으로, [File 2] Pod Annotation(+Extender 기록/사용자 지정
  개조식)은 1.2 마지막(정책 문단 뒤)으로 이동. 1.3 Step 2의 조회 대상을 `hami.io/[가속기]-devices-to-allocate` 계열로 명시.
  1.4 끝의 `hami.io/webhook: ignore` 문장은 1.2 [Shell 1] 문단과 중복이라 제거. File 번호는 1→1.1, 2→1.2로 순서 유지.
- 1장 구성: 1. 개요(요소 3종: hami-scheduler/Device Plugin/격리 계층, 지원 가속기 Table(격리 계층 열 포함)) /
  1.1 Device 등록 과정(부풀리기 + Node Annotation [File 1]) / 1.2 Device Scheduling 과정(Webhook [Shell 1], Extender, 정책,
  Pod Annotation [File 2]) / 1.3 Device 할당 과정(Pod Annotation 참조, 격리 설정 반환).
- **2026-11-01 NVIDIA 세부 축소** (사용자 피드백: 내용 중복, 벤더 중립 유지): ① 개요의 [File 1] vGPU Pod 예제 블록 제거
  (kubernetes-hami-nvidia-gpu에 동일 예제가 존재) ② 1.3 Step 3의 NVIDIA 환경 변수 열거(`NVIDIA_VISIBLE_DEVICES`,
  `CUDA_DEVICE_*`, `LD_PRELOAD`)를 "Library 수준은 Library Mount + 환경 변수, Driver/HW 수준은 가속기 Device 참조"로 중립화.
  두 글 사이의 상호 "참조" 링크도 제거(이 글 참조 섹션에 이미 kubernetes-hami-nvidia-gpu 링크 없음, 반대편의 Kubernetes HAMi 링크는 제거).
- **2026-11-01 벤더 맥락 전면 삭제** (사용자 피드백 "최대한 요 글에서는 vendor 관련 맥락은 삭제, 전반적인 컨셉정도만 명시"):
  ① ~~Table 1 제거~~ → **2026-11-01 사용자 요청으로 복원**. 표는 벤더 매트릭스지만 지원 범위를 한눈에 보여주는 가치가 있어 유지 ② 개요 Device Plugin
  bullet의 "NVIDIA GPU용 hami-device-plugin" 서술 → 벤더 중립 "가속기에 따라서 HAMi 포함/별도/제조사 Device Plugin 중 하나"
  ③ 1.1 Figure 2 캡션 "NVIDIA GPU를 예시로", "NVIDIA GPU는 NVML을 이용", "NVIDIA GPU는 hami.io/node-nvidia-register", 
  "Cambricon MLU처럼" 삭제 ④ 1.2 Step 5 "NVIDIA GPU는 초기 구현의 이름 hami.io/vgpu-devices-allocated 유지" 삭제 ⑤ 1.3
  격리 수준 3분류의 Library(HAMi-core libvgpu.so / AMD libamvgpu.so), Driver(Cambricon sMLU), Hardware(Ascend 910B3 Template)
  모든 벤더 예시 삭제 — 메커니즘만 서술 ⑥ 1.3 끝 "vCUDA, NVIDIA MPS, cGPU, qGPU, MIG, MxGPU" 산업 예시 삭제 ⑦ 참조 섹션에서
  Ascend/Cambricon/NVIDIA Device Plugin 벤더별 링크 제거, HAMi/Docs/지원 Device/CNCF 4개만 유지. 결과: 벤더 중립 Architecture
  분석과 공통 흐름(등록/Scheduling/할당) + 격리 계층 추상 설명만 남음.
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
  - 격리 방식 3분류 — **2026-10-31 웹 리서치로 검증, 본문 1.3에 개조식 추가**. 분류 축은 사용자 피드백으로 "격리가 수행되는
    계층"(Library → Driver → Hardware, 아래로 갈수록 격리↑ 유연성↓)으로 재구성: ① API 가로채기(NVIDIA HAMi-core libvgpu.so,
    AMD libamvgpu.so — AMD 상세는 여전히 재확인 필요) ② Ascend vNPU Template: Project-HAMi/ascend-device-plugin의
    ascend-device-configmap.yaml 기준 910B3(aiCore 20, 64GB)는 vir05_1c_16g(5core/16G), vir10_3c_32g(10core/32G) 2종,
    hamiVnpuMode: template, 요청 Memory를 수용하는 최소 Template으로 올림. libvnpu.so 기반 soft 분할 Mode도 존재(본문 미기재)
    ③ Cambricon dynamic-smlu: 제조사 device plugin의 mode=dynamic-smlu, Driver(neuware ≥5.0) 수준 quota 제한,
    min-dsmlu-unit=256MB, vmemory/vcore는 vmlu=1일 때만 유효(본문에는 Driver 제한, Instance 분할만 기재).
    1.3 마지막 문단에 일반화 한 문장 추가: 세 계층은 HAMi 밖 기법에도 적용 — Library: vCUDA, NVIDIA MPS /
    Driver: Alibaba cGPU, Tencent qGPU / Hardware: NVIDIA MIG, AMD MxGPU(SR-IOV). vGPU(Driver+HW 혼합), MPS(Volta+ HW 지원)
    같은 경계 사례는 본문 미기재. 근거: Alibaba cGPU docs(kernel driver, MB 단위, 2%+), 비교 글(MIG 전용 GPC/L2/HBM,
    MxGPU 균등 VF 분할).
  - [Table 1]에 "격리 계층" 열 추가 (2026-10-31). 분류 근거와 확신도:
    확실 — NVIDIA, AMD Library(HAMi 자체 Library), Ascend Hardware(vNPU Template), Cambricon Driver(sMLU),
    Iluvatar Library(/etc/ld.so.preload로 libvgpu.so 주입, kernel launch token-bucket, 웹 리서치),
    Kunlunxin Hardware(P800-OAM 1/4, 1/2 고정 분할, 요청 Memory를 지원 규격으로 올림 — HAMi kunlun-vxpu-support.md),
    AWS Neuron Hardware(NeuronCore 물리 단위 연속 블록 할당 — dynamia v2.7 blog).
    **추정(재확인 필요)** — Hygon Driver(vDCU: hy-smi virtual로 가상 Device 생성, 격리 주체 명시 문서 못 찾음),
    Moore Threads Driver(sGPU: kernel 수준 Elastic Virtualization으로 소개되나 공식 상세 없음), MetaX Driver(sGPU 명명, 동작
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

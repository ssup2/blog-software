# kubernetes-scheduler 문서 작업 컨텍스트

kube-scheduler의 구조(Scheduler 지정, Scheduling Queue, Scheduling Cycle, Binding Cycle, Extender)를 분석하는 문서.
kubernetes-hami 문서의 배경 글 (HAMi의 Scheduler Extender 방식 이해 목적). kubernetes-dra 문서와 같은 시기에 작성됨.

## 문서 구성 및 상태

- **2026-10-13 이론 초안 작성** (Claude 작성). **실측 없음** — Shell 블록 없음, File/Code 예제는 문서, 소스 기반.
  이후 2026-10-24~27에 사용자 피드백으로 여러 차례 보강, 재구성됨 (아래 이력).
- **2026-10-27 발행**: `draft: true` 제거, index.en.md 작성 (한글본과 동일 구성, 캡션 영문 번역, 코드/식별자 유지).
- **2026-10-26 전면 재구성** (사용자 요청): 목차를 Figure 1의 구역과 일치하도록 재편 — Figure 1만 남기고 matplotlib Figure 4종
  (scheduler-assignment/scheduling-queue/scheduling-framework/scheduler-extender.png) 삭제. Scheduling Queue 내용은 1.2로 통합,
  "Scheduler 확장" 절은 Extender 중심으로 재편(Framework Plugin 확장 문단은 1.2로, Custom Scheduler는 1.4 마지막 문단으로 이동).
- 2026-10-26 개요 간소화 (사용자 피드백: 개요가 너무 김): schedulerName 명시, 다수 Scheduler 운영 내용을 1.1의 File 2 설명
  문단으로 이동, Figure 1 아래에는 4개 절(지정/Scheduling Cycle/Binding Cycle/Extender)의 한 줄 요약 개조식만 둠.
- 2026-10-26 중복 제거 (사용자 피드백): ① 개요 도입부의 흐름 요약 문장 제거(개조식과 중복) ② 다수 Profile 문장을 File 2
  문단으로 일원화 ③ schedulerName 명시 문장을 File 3 문단으로 일원화 ④ Reserve 개조식의 비동기 공존 설명 제거(1.3 도입부로
  일원화) ⑤ 1.4.2의 "네 가지 Verb에 대응하는 Extension Point" 반복 축약, HAMi 언급은 1.4.3으로 일원화(1.1은 익명 Middleware로 서술).
- 2026-10-26 1.1 전개 개선 (사용자 피드백: 너무 딱딱함): 절 도입에 "각 Scheduler는 고유한 이름을 갖고 Pod가 `spec.schedulerName`으로
  지정, 이름 기준으로 다수 Scheduler 운영" 개념 문단을 신설하고, File 1 문단을 "기본 Scheduler인 kube-scheduler의 이름은 `--config`로
  전달받는 KubeSchedulerConfiguration의 profiles에 정의" 형태로 연결. File 3 문단에서 지정 방식, 다수 운영 문장 중복 제거.
  이어서 Pending 문장을 도입 문단으로 이동하고, File 3/Code 1/마지막 문단을 "File 3: Defaulting 단계에서 채워짐을 명시 →
  Code 1: Defaulting 동작(Decode 직후, SetDefaults_PodSpec) → 마지막: Mutating Admission 동작(이미 채워진 값을 Middleware가
  덮어씀, immutable)" 역할로 분리해 "kube-apiserver가 채운다/Defaulting이 먼저다" 반복 제거. Defaulting bold는 File 3 문단,
  Mutating Admission bold는 마지막 문단으로 이동.
- 문서 구성 (2026-11-08 사용자 요청으로 2개 장으로 재구성: 1장은 Kubernetes 수준의 Scheduler 배정, 2장은 kube-scheduler
  내부 동작 — Figure 1의 Scheduler Assignment 영역/kube-scheduler 영역과 대응. 같은 날 Scheduling Queue를 Scheduling Cycle에서
  독립 절로 분리(공식 문서상 Scheduling Cycle은 Queue에서 Pod를 꺼낸 시점부터)하고, Extension Point 정의 위치를 여러 차례
  옮긴 끝에 2장 도입부로 확정):
  1. Kubernetes Scheduler(Figure 1 "Kubernetes Scheduler Architecture" + 정의, 담당 Scheduler는 Defaulting/Mutating Admission에서
  결정되고 미지정 시 kube-scheduler가 담당 — 다수 Scheduler 운영은 1.1과 중복이라 도입부에서 뺌) /
  1.1 Scheduler 지정(Profile File 1, 다중 Profile File 2 — 공식 문서의 no-scoring-scheduler 예제 기반(PreScore/Score
  `disabled: '*'` 문법 재확인 필요), Pod Defaulting File 3, SetDefaults_PodSpec Code 1, Defaulting vs Mutating Admission) /
  2. kube-scheduler(도입: kube-scheduler 정의(bold) → Scheduling Framework 기반 → Extension Point 정의 "Scheduling Framework가
  Scheduling Queue부터 Binding Cycle까지 정해진 단계에서 Plugin을 호출하도록 열어 둔 지점" + 내장 Plugin 문장 → 4개 부분
  요약 개조식(Queue/Scheduling Cycle/Binding Cycle — 확장은 동작 단계가 아니고 2.4 도입부와 중복이라 2026-11-08 개조식에서 제거)) /
  2.1 Scheduling Queue(도입: 대기 Queue → Extension Point로 준비 여부/순서 결정 → 실패 시 복귀와 QueueingHint, 하위 제목
  키워드 bold) / 2.1.1 Queue 구조(3영역, 실패, 재이동 경로) /
  2.1.2 Extension Point(PreEnqueue, QueueSort — activeQ/unschedulablePods 용어로 서술) /
  2.1.3 QueueingHint(Code 2, 시나리오, 버전 이력, Pending backoff 생략) /
  2.2 Scheduling Cycle(도입: Queue에서 꺼내 직렬 처리 → Extension Point → Binding Cycle, 실패 시 Queue 복귀) /
  2.2.1 Extension Point(PreFilter~Permit) /
  2.3 Binding Cycle(도입: 비동기 수행 → Extension Point 통과 → 실패 시 Scheduling Cycle의 Reserve 되돌림(Unreserve) 후 Queue 복귀) /
  2.3.1 비동기 Binding(① 비동기 이유: Bind는 느린 작업 → 별도 Goroutine, 다음 Pod Scheduling 즉시 시작, ② 중복 배치 위험의
  원리(남은 Resource는 nodeName 설정된 Pod 요청량 제외로 계산 → Bind 전 Pod는 집계 누락)와 Reserve의 Cache 선반영으로 방지) /
  2.3.2 Extension Point(PreBind/Bind/PostBind) /
  2.4 Scheduler 확장(2026-11-08 도입부 확장: Extension Point에 확장 기능 연결 → Plugin 방식(모든 Extension Point, 빠름, 재빌드)
  vs Extender 방식(재빌드 없음, 일부 Extension Point, HTTP 지연) 비교. 2장 도입부에도 확장 가능 한 문장 추가, 2.4.2의 HTTP 지연
  문장은 도입부와 중복이라 제거) — 2026-10-26 사용자 피드백으로 하위 항목 분리 후 Custom Scheduler 항목은 다시 제거
  (메커니즘이 1.1과 중복): 2.4.1 Scheduling Framework Plugin(Code 3, Table 1 Extension Point/단계/Interface/Method, Code 4) /
  2.4.2 Scheduler Extender(File 4, 4 Verb와 Figure 1 강조 대응, managedResources, 마지막 문단에 Custom Scheduler 병용, HAMi 사례) /
  3. 참조.
- **Figure 1(scheduler-architecture.png)은 사용자가 pptx로 직접 그린 그림** (images/images.pptx 원본, 2026-10-26 최초,
  2026-11-08 사용자가 갱신). 캡션 "Kubernetes Scheduler Architecture".
  구성: 범례(Main Scheduling Flow/Failure & Requeue/Custom Scheduler Flow/Extender HTTP Call + 색상 2종: 회색-olive =
  Scheduling Framework Extension Point, 살구색 = Extension Point with Scheduler Extender) + Scheduler Assignment
  (apiserver: Decoding+Defaulting → Mutating → Validating → Create/Update etcd, Custom Scheduler Mutating Webhook Server) +
  kube-scheduler(Scheduling Queue: Informer → PreEnqueue → activeQ (QueueSort) ← backoffQ ← unschedulableEntities,
  Scheduling Cycle 2행, Binding Cycle) + Scheduler Extender HTTP Server (POST /filter /preempt /prioritize /bind) +
  Custom Scheduler(스택). 살구색 = Filter/PostFilter/Score/Bind (Extender 4 Verb 대응, 본문 2.4.2에 의미 명시).
  Binding Cycle 맨 앞에 흰색(비 Extension Point) "Wait on Permit" 박스 — Permit의 Wait 결과를 기다리는 WaitOnPermit 단계.
  Failure 화살표는 Extension Point별이 아니라 Cycle 단위: Scheduling Cycle → unschedulableEntities(거부)와 backoffQ(오류),
  Binding Cycle → unschedulableEntities(WaitOnPermit 거부/Timeout)와 backoffQ(PreBind/Bind 실패), PreEnqueue →
  unschedulableEntities(gated) — 본문 2.1.1/2.1.2/2.2.1/2.3 서술과 일치. 2.2.1 Permit 항목에서 Wait on Permit을 참조.
- **표기 컨벤션** (2026-11-08 사용자 요청): Extension Point 이름(`PreEnqueue`~`PostBind`)은 개조식 선두, Table 1, 본문 모두
  `code`로 표기. Queue 영역 이름(`activeQ`, `backoffQ`, `unschedulableEntities`)도 동일. 단 동작으로서의 Bind("Pod를 Bind하는", "Bind가 끝나기 전")와 Filtering/Scoring, figure/code 캡션은 일반 텍스트.
- **사실 검증 필요 목록** (문서, 기억 기반 초안):
  - Pod `spec.schedulerName`의 Defaulting 주체/위치: kube-apiserver의 API Defaulting
    (pkg/apis/core/v1/defaults.go의 SetDefaults_PodSpec, v1.DefaultSchedulerName = "default-scheduler") — 소스 재확인 필요.
  - KubeSchedulerConfiguration의 profiles 생략 시 기본 Profile 생성과 schedulerName 생략 시 default-scheduler 설정
    (SetDefaults_KubeSchedulerConfiguration) — 소스 재확인 필요.
  - kube-apiserver 처리 순서: Defaulting(요청 Decode 시점)이 Mutating Admission보다 선행 — 재확인 필요. Mutating Webhook의
    Patch 적용 후 Defaulting 재수행 여부 같은 세부 동작은 본문에서 의도적으로 다루지 않음.
  - [Code 1]은 SetDefaults_PodSpec **축약** (실제 코드는 hostNetwork Port, SecurityContext 등 더 많은 기본값 포함).
  - Pod `spec.schedulerName`의 생성 후 변경 불가(immutable) 여부 — validation 소스 재확인 필요.
  - backoffQ 기본 Backoff 1초(initial)~10초(max), unschedulablePods 체류 상한 기본 5분
    (podMaxInUnschedulablePodsDuration) 주기 flush — 소스/문서 재확인 필요.
  - ~~실패 Pod 이동 경로~~ **2026-10-26 1.32 소스로 검증 완료** (pkg/scheduler/backend/queue/scheduling_queue.go):
    Scheduling 도중 Event 무조건 backoffQ 직행은 QueueingHint 비활성 시의 옛 동작(moveRequestCycle >= podSchedulingCycle).
    QueueingHint 활성(1.32+ 기본) 시에는 in-flight 동안의 Event를 inFlightEvents에 기록해 두고 실패 시점에
    determineSchedulingHintForInFlightPod가 거부 Plugin의 QueueingHintFn으로 검사 — 전부 QueueSkip이면 unschedulablePods,
    Queue면 backoffQ(Backoff 만료 시 activeQ), Pending Plugin의 Queue면 activeQ 직행. 일시적 오류(rejectorPlugins 없음)는
    backoffQ 확인. 본문 1.2.1을 이 동작으로 수정함.
  - **실패 경로 2026-11-08 v1.37.2 소스로 검증** (pkg/scheduler/schedule_one.go, backend/queue/scheduling_queue.go,
    framework/types.go): unschedulablePods 여부는 실패 단계가 아니라 거부(Unschedulable/UnschedulableAndUnresolvable)로
    `UnschedulablePlugins`가 기록됐는지로 결정(`determineSchedulingHintForInFlightPod`: 기록 없으면 queueAfterBackoff).
    거부 → unschedulablePods: PreFilter, Filter(PostFilter Preemption 후 Unschedulable 반환), Reserve(assumeAndReserve),
    Permit(RunPermitPlugins + Binding Cycle의 WaitOnPermit), PreEnqueue(gated, moveToActiveQ).
    backoffQ: PreScore/Score(prioritizeNodes가 AsError로 반환), PreBind/Bind(소스 주석 "Permit is the last one"), 일시적 오류.
    본문 반영(사용자 피드백: 2.1.1에서 정의 전 Extension Point 이름이 나와 혼동): 2.1.1은 원리(거부 → unschedulablePods,
    오류 → backoffQ)만 서술하고, 단계별 경로는 2.2.1 목록 뒤 문단(PreFilter/Filter/Reserve/Permit 거부, PreScore/Score 오류)과
    2.3 도입부(WaitOnPermit 거부 vs PreBind/Bind 실패, 둘 다 Reserve 되돌림)에 둠. Figure 1의 PreScore→unschedulablePods 화살표는 소스와 불일치(→ backoffQ가 맞음),
    Reserve/Permit→unschedulablePods 화살표 누락 — 사용자에게 수정 제안함.
    v1.37.0에서 내부 구조 이름이 unschedulablePods → unschedulableEntities로 바뀜(v1.35.0/v1.36.0은 unschedulablePods,
    PodGroup 멤버도 함께 관리). 2026-11-08 사용자 결정으로 본문은 `unschedulableEntities`로 변경하고 개조식에 1.36까지 옛 이름 명시.
  - QueueingHint 버전 이력은 2026-11-09 사용자 요청으로 본문에서 삭제. 참고(v1.34/v1.36 kube_features.go): 1.28 Beta 기본 비활성,
    1.32 Beta 기본 활성, 1.34 GA LockToDefault, v1.37에서 Gate 제거. [Code 2]도 v1.37.2 기준 fwk 패키지로 수정.
  - backoffQ 1초~10초, unschedulableEntities 체류 상한 5분은 v1.37.2 기본값과 일치 확인(2026-11-09).
  - Pending 상태로 거부된 Pod의 재입장 시 backoffQ 생략 (DRA Plugin 사례) — scheduling framework 문서 기반, 재확인 필요.
  - [Code 2]는 NodeAffinity의 EventsToRegister/QueueingHintFn **축약** (실제 upstream은 UpdateNodeTaint ActionType, util.As 변환
    포함). framework package 타입 이름(ClusterEventWithHint, QueueingHintFn)의 최신 위치(fwk package 이동 여부) 확인 필요.
  - **[Code 3], [Code 4] 2026-11-08 v1.37.2 기준으로 수정**: Interface 위치는 staging/src/k8s.io/kube-scheduler/framework/interface.go
    (import 별칭 `fwk`), CycleState/NodeInfo는 interface 값 타입(포인터 아님), Score는 nodeName string 대신 nodeInfo NodeInfo.
    Code 4는 fwk.CycleState/fwk.NodeInfo/fwk.NewStatus/fwk.Handle/fwk.Plugin으로 수정, PluginFactory 시그니처와
    app.NewSchedulerCommand(app.WithPlugin(...)) 패턴은 v1.37.2 server.go/registry.go에서 확인. 아래 옛 메모는 이력.
  - [Code 3]은 pkg/scheduler/framework/interface.go의 Plugin/FilterPlugin/ScorePlugin Interface **축약** — 최신 버전에서
    CycleState/NodeInfo/Status가 fwk interface 타입으로 변경됐는지 확인 필요. [Code 4]의 등록 패턴
    (cmd/kube-scheduler/app의 NewSchedulerCommand + WithPlugin, New 함수 시그니처)도 재확인 필요.
  - PostFilter 기본 Plugin `DefaultPreemption`, QueueSort 기본 Plugin `PrioritySort` 확인.
  - PreEnqueue 거부 Pod의 unschedulablePods 대기와 `SchedulingGates` Plugin (KEP-3521, schedulingGates 1.30 GA) — 공식 문서
    기반, 소스 재확인 필요.
  - Extender Verb 4종 (KubeSchedulerConfiguration 필드명 filterVerb/prioritizeVerb/bindVerb/preemptVerb) 재확인 필요.
    Coscheduling 문장은 2026-11-07 사용자 요청으로 본문에서 삭제.
  - KubeSchedulerConfiguration API Version (kubescheduler.config.k8s.io/v1) 확인.

## Test 계획 (미수행)

- kind Cluster에서 실측 가능: schedulerName Defaulting 확인(kubectl get pod -o yaml), kube-scheduler 로그(v=4 이상)로
  Cycle 동작 확인, 간단한 HTTP Extender를 배포하여 filter/prioritize 호출 Payload 캡처, 다중 Profile/Custom Scheduler 동작 확인.
- 실측 완료 시 본문에 [Shell N] 블록을 실측 발췌로 추가하고 manifests/ 폴더에 재현 파일을 남길 것 (repo 컨벤션).

## 폴더 구조

- `index.md` — 문서 본문 (ko 초안).
- `images/` — scheduler-architecture.png (사용자 pptx 작성본) + images.pptx (원본).

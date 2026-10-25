# kubernetes-scheduler 문서 작업 컨텍스트

kube-scheduler의 구조(Queue, Scheduling Framework, 확장 방법)를 분석하는 문서.
kubernetes-hami 문서의 배경 글 (HAMi의 Scheduler Extender 방식 이해 목적). kubernetes-dra 문서와 같은 시기에 작성됨.

## 문서 구성 및 상태

- **2026-10-13 이론 초안 작성** (Claude 작성, 사용자 검토 전, frontmatter `draft: true`). **실측 없음** — Shell 블록 없음,
  File 예제는 모두 문서 기반. index.en.md는 초안 확정 전이라 미작성.
- **2026-10-24 개요 보강**: default-scheduler 이름이 설정되는 과정 추가 — File 1(기본 설정과 동일한
  KubeSchedulerConfiguration Profile), File 2(schedulerName 생략 Pod 생성 요청 vs 저장된 Pod, kube-apiserver Defaulting).
- **2026-10-24 QueueingHint 보강**: Code 1(NodeAffinity의 EventsToRegister/QueueingHintFn **축약** 코드 — 실제 upstream
  코드는 UpdateNodeTaint ActionType, util.As 변환, 세부 분기 포함. 교육용으로 단순화함) + 동작 설명, NodeAffinity 시나리오 예시,
  버전 이력(1.28 Alpha → 1.32 기본 활성화), Pending 거부 시 backoff 생략 문단.
- **2026-10-24 섹션 재구성** (사용자 피드백 2회 반영): Scheduler 이름 설정·지정 내용을 개요에서 분리하여 "1.1 Scheduler 지정"
  신설. 처음에는 Mutating Webhook 등록 예제(MutatingWebhookConfiguration yaml)를 넣었으나 사용자가 "커스텀 웹훅이 아니라
  변형(mutate) 관점에서 default-scheduler가 설정되는 내부 과정이 궁금하다"고 해서 제거하고, kube-apiserver의 Defaulting 함수
  Code 1(SetDefaults_PodSpec 축약)과 처리 파이프라인(Decode 시점 Defaulting → Mutating Admission) 설명으로 교체.
  schedulerName immutable, HAMi의 덮어쓰기 사례는 문장으로만 유지. 이후 섹션은 1.2~1.4로 번호 변경.
- 1장 구성: 1. 개요(Architecture) / 1.1 Scheduler 지정(Profile File 1, Pod Defaulting File 2, SetDefaults_PodSpec Code 1) /
  1.2 Scheduling Queue(activeQ/backoffQ/unschedulablePods) / 1.2.1 QueueingHint(Code 2, 시나리오, 버전 이력,
  Pending backoff 생략 — 2026-10-24 사용자 피드백으로 하위 항목 분리) / 1.3 Scheduling Framework(Extension Point 목록,
  대표 내장 Plugin) / 1.4 Scheduler 확장(Framework Plugin/Extender/Custom Scheduler 3종, Extender 설정 예제 File 3,
  HAMi 사례 연결).
- **사실 검증 필요 목록** (기억 기반 초안):
  - Pod `spec.schedulerName`의 Defaulting 주체/위치: kube-apiserver의 API Defaulting
    (pkg/apis/core/v1/defaults.go의 SetDefaults_PodSpec, v1.DefaultSchedulerName = "default-scheduler") — 소스 재확인 필요.
  - KubeSchedulerConfiguration의 profiles 생략 시 기본 Profile 생성과 schedulerName 생략 시 default-scheduler 설정
    (SetDefaults_KubeSchedulerConfiguration) — 소스 재확인 필요.
  - kube-apiserver 처리 순서: Defaulting(요청 Decode 시점)이 Mutating Admission보다 선행 — 본문 1.1의 "Webhook이 Pod를
    전달받는 시점에는 이미 default-scheduler가 설정되어 있다" 서술의 근거, 공식 문서/소스 재확인 필요. Mutating Webhook의
    Patch 적용 후 Defaulting 재수행 여부 같은 세부 동작은 본문에서 의도적으로 다루지 않음.
  - [Code 1]은 pkg/apis/core/v1/defaults.go의 SetDefaults_PodSpec **축약** (실제 코드는 hostNetwork Port, SecurityContext,
    TerminationGracePeriodSeconds 등 더 많은 기본값 포함). v1.DefaultSchedulerName 상수 위치(core/v1 types) 재확인 필요.
  - Pod `spec.schedulerName`의 생성 후 변경 불가(immutable) 여부 — validation 소스 재확인 필요.
  - QueueingHint 버전 이력: 1.28 Alpha 도입, 메모리 문제로 기본 비활성화 전환 후 1.32부터 기본 활성화 — 본문에 서술함,
    release note 재확인 필요.
  - Pending 상태로 거부된 Pod의 재입장 시 backoffQ 생략 동작 (DRA Plugin 사례) — scheduling framework 문서 기반, 재확인 필요.
  - [Code 1]의 framework package 경로와 타입 이름 (ClusterEventWithHint, QueueingHintFn, Queue/QueueSkip) — 최신 버전에서
    fwk package로 이동했는지 확인 필요.
  - backoffQ의 기본 Backoff 시간: 본문에 1초(initial)~10초(max)로 서술함 (2026-10-25 보강) — flag 기본값 재확인 필요.
  - 실패 Pod의 이동 경로 (2026-10-25 보강, 사용자 질문 "backoffQ vs unschedulablePods 차이" 반영): 기본은 unschedulablePods,
    Scheduling 도중 Event 발생 시(moveRequestCycle) 또는 일시적 오류 시 backoffQ 직행, unschedulablePods 체류 상한
    기본 5분(podMaxInUnschedulablePodsDuration) 주기 flush — 소스/문서 재확인 필요.
  - Extender verb 목록 — 본문은 filter/prioritize/bind만 서술했으나 `preemptVerb`도 존재함. 추가 여부 검토.
  - PostFilter 기본 Plugin 이름 `DefaultPreemption`, QueueSort 기본 Plugin 이름 `PrioritySort` 확인.
  - Permit의 Gang Scheduling 사례 (scheduler-plugins의 Coscheduling) 서술 수준.
  - KubeSchedulerConfiguration API Version (kubescheduler.config.k8s.io/v1) 확인.
- Figure 5종은 모두 matplotlib **초안** — 사용자가 pptx 스타일로 다시 그릴 예정 (파일명 유지한 채 교체). images/images.pptx는
  아직 없음. Figure 4(scheduling-framework)/5(scheduler-extender)는 2026-10-13 생성,
  Figure 2(scheduler-assignment: Client → Decode+Defaulting → Mutating Admission → Validation/Store → 저장된 Pod →
  kube-scheduler Watch)와 Figure 3(scheduling-queue: activeQ/backoffQ/unschedulablePods 이동과 QueueingHint)은
  2026-10-24에 목차 4개(1.1~1.4)마다 Figure를 두는 구성으로 추가함. 기존 Figure 2→4, 3→5로 번호 변경.
- Figure 1(scheduler-architecture)은 2026-10-24에 재생성 (사용자 피드백: 기존 그림에 지정·확장 내용 부재) —
  4개 목차 요소를 모두 포함: kube-apiserver(Defaulting+Mutating Admission → Pod schedulerName) + kube-scheduler
  (Informer → Queue → Scheduling/Binding Cycle + Framework Plugin) + Scheduler Extender/Custom Scheduler.

## Test 계획 (미수행)

- kind Cluster에서 실측 가능: kube-scheduler 로그(v=4 이상)로 Cycle 동작 확인, 간단한 HTTP Extender를 배포하여
  filter/prioritize 호출 Payload 캡처, schedulerName 기반 다중 Scheduler 동작 확인 등.
- 실측 완료 시 본문에 [Shell N] 블록을 실측 발췌로 추가하고 manifests/ 폴더에 재현 파일을 남길 것 (repo 컨벤션).

## 폴더 구조

- `index.md` — 문서 본문 (ko 초안).
- `images/` — matplotlib 초안 Figure 3종.

# kubernetes-scheduler 문서 작업 컨텍스트

kube-scheduler의 구조(Scheduler 지정, Scheduling Cycle/Queue, Binding Cycle, Extender)를 분석하는 문서.
kubernetes-hami 문서의 배경 글 (HAMi의 Scheduler Extender 방식 이해 목적). kubernetes-dra 문서와 같은 시기에 작성됨.

## 문서 구성 및 상태

- **2026-10-13 이론 초안 작성** (Claude 작성, frontmatter `draft: true`). **실측 없음** — Shell 블록 없음, File/Code 예제는 문서·소스
  기반. index.en.md는 초안 확정 전이라 미작성. 이후 2026-10-24~26에 사용자 피드백으로 여러 차례 보강·재구성됨 (아래 이력).
- **2026-10-26 전면 재구성** (사용자 요청): 목차를 Figure 1의 구역과 일치하도록 재편 — Figure 1만 남기고 matplotlib Figure 4종
  (scheduler-assignment/scheduling-queue/scheduling-framework/scheduler-extender.png) 삭제. Scheduling Queue 내용은 1.2로 통합,
  "Scheduler 확장" 절은 Extender 중심으로 재편(Framework Plugin 확장 문단은 1.2로, Custom Scheduler는 1.4 마지막 문단으로 이동).
- 2026-10-26 개요 간소화 (사용자 피드백: 개요가 너무 김): schedulerName 명시·다수 Scheduler 운영 내용을 1.1의 File 2 설명
  문단으로 이동, Figure 1 아래에는 4개 절(지정/Scheduling Cycle/Binding Cycle/Extender)의 한 줄 요약 개조식만 둠.
- 2026-10-26 중복 제거 (사용자 피드백): ① 개요 도입부의 흐름 요약 문장 제거(개조식과 중복) ② 다수 Profile 문장을 File 2
  문단으로 일원화 ③ schedulerName 명시 문장을 File 3 문단으로 일원화 ④ Reserve 개조식의 비동기 공존 설명 제거(1.3 도입부로
  일원화) ⑤ 1.4.2의 "네 가지 Verb에 대응하는 Extension Point" 반복 축약, HAMi 언급은 1.4.3으로 일원화(1.1은 익명 Middleware로 서술).
- 1장 구성: 1. 개요(Figure 1 Architecture + 4개 절 요약 개조식) /
  1.1 Scheduler 지정(Profile File 1, 다중 Profile File 2 — 공식 문서의 no-scoring-scheduler 예제 기반(PreScore/Score
  `disabled: '*'` 문법 재확인 필요), Pod Defaulting File 3, SetDefaults_PodSpec Code 1, Defaulting vs Mutating Admission) /
  1.2 Scheduling Cycle(Scheduling Framework 소개와 Custom Plugin) /
  1.2.1 Scheduling Queue(3영역과 실패·재이동 경로) / 1.2.2 QueueingHint(Code 2, 시나리오, 버전 이력, Pending backoff 생략) /
  1.2.3 Extension Point(PreFilter~Permit 목록) /
  1.3 Binding Cycle(PreBind/Bind/PostBind) /
  1.4 Scheduler 확장 — 2026-10-26 사용자 피드백으로 하위 항목 분리 후 Custom Scheduler 항목(1.4.3)은 다시 제거
  (메커니즘이 1.1과 중복): 1.4.1 Scheduling Framework Plugin(1.2에 있던 Custom Plugin 문단 이동) /
  1.4.2 Scheduler Extender(File 4, 4 Verb와 Figure 1 강조 대응, managedResources, 마지막 문단에 Custom Scheduler 병용·HAMi 사례).
- **Figure 1(scheduler-architecture.png)은 2026-10-26에 사용자가 pptx로 직접 그린 그림** (images/images.pptx 원본).
  구성: 범례(Main Scheduling Flow/Failure & Requeue/Custom Scheduler Flow/Extender HTTP Call) + Scheduler Assignment
  (apiserver: Decoding+Defaulting → Mutating → Validating → Create/Update etcd, Custom Scheduler Mutating Webhook Server) +
  kube-scheduler(Queue 3영역과 requeue 경로, Scheduling Cycle 2행, Binding Cycle) + Scheduler Extender HTTP Server
  (POST /filter /preempt /prioritize /bind) + Custom Scheduler(스택). olive 강조 = Filter/PostFilter/Score/Bind
  (Extender 4 Verb 대응, 본문 1.4에 의미 명시).
- **사실 검증 필요 목록** (문서·기억 기반 초안):
  - Pod `spec.schedulerName`의 Defaulting 주체/위치: kube-apiserver의 API Defaulting
    (pkg/apis/core/v1/defaults.go의 SetDefaults_PodSpec, v1.DefaultSchedulerName = "default-scheduler") — 소스 재확인 필요.
  - KubeSchedulerConfiguration의 profiles 생략 시 기본 Profile 생성과 schedulerName 생략 시 default-scheduler 설정
    (SetDefaults_KubeSchedulerConfiguration) — 소스 재확인 필요.
  - kube-apiserver 처리 순서: Defaulting(요청 Decode 시점)이 Mutating Admission보다 선행 — 재확인 필요. Mutating Webhook의
    Patch 적용 후 Defaulting 재수행 여부 같은 세부 동작은 본문에서 의도적으로 다루지 않음.
  - [Code 1]은 SetDefaults_PodSpec **축약** (실제 코드는 hostNetwork Port, SecurityContext 등 더 많은 기본값 포함).
  - Pod `spec.schedulerName`의 생성 후 변경 불가(immutable) 여부 — validation 소스 재확인 필요.
  - backoffQ 기본 Backoff 1초(initial)~10초(max), 실패 Pod 이동 경로(기본 unschedulablePods, Scheduling 도중 Event 발생 시
    moveRequestCycle로 backoffQ 직행, 일시적 오류 시 backoffQ), unschedulablePods 체류 상한 기본 5분
    (podMaxInUnschedulablePodsDuration) 주기 flush — 소스/문서 재확인 필요.
  - QueueingHint 버전 이력: 1.28 Alpha 도입, 메모리 문제로 기본 비활성화 전환 후 1.32부터 기본 활성화 — release note 재확인 필요.
  - Pending 상태로 거부된 Pod의 재입장 시 backoffQ 생략 (DRA Plugin 사례) — scheduling framework 문서 기반, 재확인 필요.
  - [Code 2]는 NodeAffinity의 EventsToRegister/QueueingHintFn **축약** (실제 upstream은 UpdateNodeTaint ActionType, util.As 변환
    포함). framework package 타입 이름(ClusterEventWithHint, QueueingHintFn)의 최신 위치(fwk package 이동 여부) 확인 필요.
  - [Code 3]은 pkg/scheduler/framework/interface.go의 Plugin/FilterPlugin/ScorePlugin Interface **축약** — 최신 버전에서
    CycleState/NodeInfo/Status가 fwk interface 타입으로 변경됐는지 확인 필요. [Code 4]의 등록 패턴
    (cmd/kube-scheduler/app의 NewSchedulerCommand + WithPlugin, New 함수 시그니처)도 재확인 필요.
  - PostFilter 기본 Plugin `DefaultPreemption`, QueueSort 기본 Plugin `PrioritySort` 확인.
  - Extender Verb 4종 (KubeSchedulerConfiguration 필드명 filterVerb/prioritizeVerb/bindVerb/preemptVerb),
    Coscheduling의 이용 Extension Point(QueueSort+Permit) 재확인 필요.
  - KubeSchedulerConfiguration API Version (kubescheduler.config.k8s.io/v1) 확인.

## Test 계획 (미수행)

- kind Cluster에서 실측 가능: schedulerName Defaulting 확인(kubectl get pod -o yaml), kube-scheduler 로그(v=4 이상)로
  Cycle 동작 확인, 간단한 HTTP Extender를 배포하여 filter/prioritize 호출 Payload 캡처, 다중 Profile/Custom Scheduler 동작 확인.
- 실측 완료 시 본문에 [Shell N] 블록을 실측 발췌로 추가하고 manifests/ 폴더에 재현 파일을 남길 것 (repo 컨벤션).

## 폴더 구조

- `index.md` — 문서 본문 (ko 초안).
- `images/` — scheduler-architecture.png (사용자 pptx 작성본) + images.pptx (원본).

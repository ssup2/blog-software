# kubernetes-scheduler 문서 작업 컨텍스트

kube-scheduler의 구조(Queue, Scheduling Framework, 확장 방법)를 분석하는 문서.
kubernetes-hami 문서의 배경 글 (HAMi의 Scheduler Extender 방식 이해 목적). kubernetes-dra 문서와 같은 시기에 작성됨.

## 문서 구성 및 상태

- **2026-10-13 이론 초안 작성** (Claude 작성, 사용자 검토 전, frontmatter `draft: true`). **실측 없음** — Shell 블록 없음,
  File 1(KubeSchedulerConfiguration extenders 예제)은 문서 기반. index.en.md는 초안 확정 전이라 미작성.
- 1장 구성: 1. 개요(Architecture, schedulerName/다중 Scheduler) / 1.1 Scheduling Queue(activeQ/backoffQ/unschedulablePods,
  QueueingHint) / 1.2 Scheduling Framework(Extension Point 목록, 대표 내장 Plugin) / 1.3 Scheduler 확장
  (Framework Plugin/Extender/Custom Scheduler 3종, Extender 설정 예제, HAMi 사례 연결).
- **사실 검증 필요 목록** (기억 기반 초안):
  - QueueingHint의 도입 버전과 기본 활성화 여부 (SchedulerQueueingHints Feature Gate).
  - backoffQ의 기본 Backoff 시간 (initial/max).
  - Extender verb 목록 — 본문은 filter/prioritize/bind만 서술했으나 `preemptVerb`도 존재함. 추가 여부 검토.
  - PostFilter 기본 Plugin 이름 `DefaultPreemption`, QueueSort 기본 Plugin 이름 `PrioritySort` 확인.
  - Permit의 Gang Scheduling 사례 (scheduler-plugins의 Coscheduling) 서술 수준.
  - KubeSchedulerConfiguration API Version (kubescheduler.config.k8s.io/v1) 확인.
- Figure 1~3 (scheduler-architecture/scheduling-framework/scheduler-extender.png)은 2026-10-13에 matplotlib로 생성한
  **초안** — 사용자가 pptx 스타일로 다시 그릴 예정 (파일명 유지한 채 교체). images/images.pptx는 아직 없음.

## Test 계획 (미수행)

- kind Cluster에서 실측 가능: kube-scheduler 로그(v=4 이상)로 Cycle 동작 확인, 간단한 HTTP Extender를 배포하여
  filter/prioritize 호출 Payload 캡처, schedulerName 기반 다중 Scheduler 동작 확인 등.
- 실측 완료 시 본문에 [Shell N] 블록을 실측 발췌로 추가하고 manifests/ 폴더에 재현 파일을 남길 것 (repo 컨벤션).

## 폴더 구조

- `index.md` — 문서 본문 (ko 초안).
- `images/` — matplotlib 초안 Figure 3종.

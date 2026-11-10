# CLAUDE.md

HAMi + Prometheus/Grafana GPU 모니터링 구성을 기록한 글 폴더다.

## 추적 상태

### Section 3 `honorLabels` patch 제거 완료 (2026-11-11)

HAMi Chart Template에 `honorLabels: true`를 추가하는 Upstream PR [#2934](https://github.com/Project-HAMi/HAMi/pull/2934)가 **v2.11.0**에 포함되었다
(chart211 templates/scheduler/servicemonitor.yaml, device-plugin/servicemonitor.yaml 확인). 2026-11-11 사용자 요청으로 Test Node(192.168.1.32)의
HAMi를 2.10.0 → 2.11.0으로 upgrade(`--set prometheus.enabled=true` 유지, ServiceMonitor 재생성까지 포함해 최종 revision 5)하고 글을 갱신함:

* `kubectl patch servicemonitor ... honorLabels` 두 줄과 설명 문단 삭제 → `-o jsonpath='{.spec.endpoints[0].honorLabels}'` 확인 Shell로 대체
* `honor_labels` 설명은 Section 3 도입 문단으로 이동
* 설치 환경 섹션 HAMi Chart Version 2.11.0
* 실측 재수행: `prometheus.enabled=false` → `true`로 ServiceMonitor를 새로 생성(AGE 10s), Prometheus Query 결과는 현재 qwen3 Pod(`...-tgrmb`) 기준
* KR / EN 동시 수정

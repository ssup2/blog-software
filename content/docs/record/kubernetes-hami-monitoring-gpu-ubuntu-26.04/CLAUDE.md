# CLAUDE.md

HAMi + Prometheus/Grafana GPU 모니터링 구성을 기록한 글 폴더다.

## 추적 상태

### Section 3 `honorLabels` patch 제거 예정

HAMi Chart Template에 `honorLabels: true`를 추가하는 Upstream PR [#2934](https://github.com/Project-HAMi/HAMi/pull/2934)가 2026-09-11에 master로 머지되었다. 2026-10-18 기준 Chart Release는 여전히 **v2.10.0** (2026-08-21 published) 이며 이 PR이 포함된 Release는 아직 없다.

PR이 포함된 Release (v2.11.0 또는 v2.10.1 추정) 가 배포되면 Section 3의 흐름을 아래와 같이 축소한다.

* 삭제 대상 : `kubectl patch servicemonitor ... honorLabels` 두 줄과 그 설명 문단
* 유지 대상 : `helm upgrade ... --set prometheus.enabled=true` (ServiceMonitor 생성 Trigger)
* 설치 환경 섹션의 **HAMi Chart Version** 도 함께 올려서 업데이트

변경할 때 KR / EN 양쪽을 동시에 수정한다.

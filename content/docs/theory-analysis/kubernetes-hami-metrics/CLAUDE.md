# kubernetes-hami-metrics 문서 작업 컨텍스트

HAMi 2.11.0이 노출하는 Prometheus Metric을 정리한 글. nvidia-dcgm-exporter-metrics 글의 구성(분류별 `### 1.N` + "Metric | Description |
Metric Type | Value Unit" 표)을 따르되, HAMi는 Label이 중요해서 Label 열을 추가함.

## 문서 상태

- 2026-11-17 사용자 요청으로 초안 작성 (`draft: true`, index.en.md 없음). **실측 없음** — 모든 내용은 HAMi v2.11.0 소스 확인 기반.
- 사용자 지시: "추측하지 말고 코드 확인하고 넣어줘" — Metric 이름, Label, Type, 값의 계산식은 아래 근거 파일에서 직접 확인한 것만 기재.

## 근거 (HAMi v2.11.0)

- cmd/scheduler/metrics.go — Node/Pod/Quota/RemoteGPU/State Collector. `prometheus.WrapRegistererWith({"zone": "vGPU"})`로 모든 Collector Metric에
  `zone="vGPU"` Label. Memory는 MiB × 1024 × 1024(mibToBytes). AMD Core는 normalizeAMDCoreMetrics로 100 기준 환산(legacy는 원값).
  `hami_node_gpu_memory_allocated_ratio`는 Usedmem/Totalmem(Totalmem > 0일 때만). MIG Instance Metric은 Mode `mig` + RuntimeReady만.
  Remote GPU 장치(remotegpu.RemoteGPUCommonWord)는 Node Metric에서 제외하고 collectRemoteGPUMetrics에서 Server 기준으로 한 번 노출.
  `hami_resource_quota_used`의 `limit` Label은 v2.11.0 Deprecated, v2.12.0 제거 예정(Help 문자열). `hami_resource_quota_limit`은 LimitSet일 때만.
  Pod Metric은 PodManager가 Pod 단위로 합산(CollapseInitContainerUsage)해서 Container Label 없음.
- pkg/metrics/scheduler.go — Counter 3종, Label `phase`/`device_type`/`failure_reason`. failure_reason 값 8종. phase 값은 pkg/scheduler/scheduler.go 호출부
  기준 `filter`(성공/실패), `bind`(실패, rollback).
- pkg/metrics/metrics.go — `hami_build_info` (zone Label 없음, Registry에 직접 등록).
- cmd/vGPUmonitor/metrics.go, main.go — `:9394`, Host Metric은 NVML(지원 안 하면 생략), ECC는 AGGREGATE + corrected/uncorrected Counter,
  Power는 mW/1000. Container Metric은 ContainerLister의 mmap Shared Memory(HAMi-core 기록) 기준, Node의 `hami.io/vgpu-node` Label Pod만.
  `hami_container_device_memory_bytes`는 v2.11.0 Deprecated(Help). last kernel은 lastKernelTime > 0일 때만. unknown process는
  `HAMI_MONITOR_UNKNOWN_PROCESSES=true`일 때만. collect_success는 HTTP 200이어도 부분 실패 감지용(주석).
- `--legacy-metrics` 기본 false, Chart `legacyMetrics: false` — Legacy 이름 대응표는 두 metrics.go의 legacy Desc 정의 기준.

## 구성 변경

- 2026-11-17 사용자 요청: Label 열 전체 제거, Component별로 재구성 — 1.1 HAMi Scheduler Metrics(공용, `device_type`으로 Accelerator 구분,
  1.1.1~1.1.5), 1.2 vGPU monitor Metrics(NVIDIA 전용, 1.2.1~1.2.3), 1.3 Build Info(두 Component 공통), 1.4 Legacy. 근거: Chart v2.11.0에서
  `vgpu-monitor` Container는 templates/device-plugin/daemonsetnvidia.yaml에만 존재. "vGPU"는 NVIDIA vGPU 제품이 아니라 HAMi 할당 단위
  (zone Label 고정값 "vGPU", 프로젝트 전신 k8s-vGPU-scheduler)라는 설명을 1.1 도입에 추가.

- 2026-11-17 사용자 요청: 2.11.0 기준으로만 서술하고 Deprecated 내용 삭제 — `hami_resource_quota_used`의 `limit` Label Deprecated 문장,
  [Table 7]의 `hami_container_device_memory_bytes` 행(2.11.0에 존재하지만 Deprecated) 제거. Legacy 대응표의 `Device_memory_desc_of_container`는
  같은 값(memoryTotal)을 내는 `hami_vgpu_memory_used_bytes`로 대응 변경. 최신 Release는 v2.11.0(2026-11-04), v2.12.0 미출시 확인.

- 2026-11-17 사용자 요청: DCGM Exporter 병행 검토 후 `## 2. DCGM Exporter와 함께 이용` 추가 → 사용자 요청으로 제목 `## 2. with DCGM Exporter`, [Table 11] 제거 후 개조식(HAMi Metric / DCGM Exporter) + 이유 문단, 참조는 3으로.
  근거: HAMi pkg/device-plugin/nvidiadevice/nvinternal/rm/devices.go GetPluginDevices — kubelet Device ID `fmt.Sprintf("%v-%v", dev.ID, i)`
  (MIG는 원 ID). dcgm-exporter(main) internal/pkg/transformation/kubernetes_mapping.go deviceIDAliases — `MIG-` 접두사, GKE
  `nvidiaN/giM(/vgpuK)`, `/vgpu`, `::`만 GPU 식별자로 변환 → HAMi의 `<UUID>-<n>`은 별칭 없음 → Pod 정보 미부착(코드 근거, 실측 아님).
  DCGM 쪽 Metric 범위는 블로그 nvidia-dcgm-exporter-metrics 글 기준.
- 같은 날 [Table 7] 설명 정정: whole GPU/MIG Container는 `devicePlugin.monitor.disableHAMiCoreForWholeGPU`(Chart 기본 true, env
  `DISABLE_HAMI_CORE_FOR_WHOLE_GPU`)로 HAMi-core 미주입 → pkg/monitor/nvidia/wholegpu.go wholeGPUUsage가 NVML로 합성(used=mem.Used,
  limit=mem.Total, SM=GetUtilizationRates.Gpu, MIG는 내장 DCGM GpuInstanceSmUtil), context/module/buffer 0, LastKernelTime 0 → last kernel 미노출.

## 미확인 / 주의

- `hami_container_device_utilization_ratio`: 값은 pkg/monitor/nvidia/v1/spec.go DeviceSmUtil의 활성 Process smUtil **합계**. 개별 smUtil은
  HAMi-core(main) src/multiprocess/multiprocess_utilization_watcher.c가 NVML `nvmlDeviceGetProcessUtilization()`의 Process별 `smUtil`(%)을
  shared region `device_util[dev].sm_util`에 기록한 값 → 단위 Percentage 확인(HAMi-core는 main 브랜치 기준, v2.11.0 Image의 HAMi-core 커밋과 대조 안 함).
- Quota Metric의 값 단위는 Resource 종류에 따라 다를 것으로 보이나 미확인이라 Value Unit 비움.
- 실측(Test Node `curl :9395/metrics`, `:9394/metrics`) 미수행.

---
title: "Kubernetes HAMi Metrics"
draft: true
---

HAMi 2.11.0이 노출하는 Prometheus Metric을 정리한다. HAMi의 Metric은 HAMi Scheduler와 HAMi Device Plugin의 vGPU monitor Container가 각각 노출한다.

* **HAMi Scheduler** : `hami-scheduler` Pod의 `9395` Port에서 `/metrics`로 노출하며, `hami-scheduler` Service의 `31993` Port로 수집한다. HAMi Scheduler가 관리하는 할당 내역을 기준으로 하며, 모든 Accelerator에 공통으로 적용된다.
* **vGPU monitor** : `hami-device-plugin` Pod의 `9394` Port에서 `/metrics`로 노출하며, `hami-device-plugin-monitor` Service의 `31992` NodePort로 수집한다. Node의 GPU와 Container가 실제로 이용하는 양을 기준으로 하며, NVIDIA GPU에만 적용된다.

## 1. Metric 목록

### 1.1. HAMi Scheduler Metrics

{{< table caption="[Table 1] HAMi Scheduler Metric의 공통 Label" >}}
| Label | Description | 예시 |
|---|---|---|
| `zone` | 모든 Metric에 붙는 고정 값. vGPU는 NVIDIA의 vGPU 제품이 아니라 HAMi가 하나의 Accelerator를 나누어 할당하는 단위를 의미 | `vGPU` |
| `node` | Accelerator가 위치한 Node 이름 | `gpu-node` |
| `device_uuid` | Accelerator의 UUID | `GPU-034026c4-...` |
| `device_index` | Node 안에서의 Accelerator 번호 | `0` |
| `device_type` | HAMi Device Plugin이 Node Annotation에 등록한 Accelerator 모델 이름 | `NVIDIA GeForce RTX 5060 Ti`, `Ascend910B3` |
| `namespace` | Accelerator를 할당받은 Pod의 Namespace | `default` |
| `pod` | Accelerator를 할당받은 Pod 이름 | `poda` |
{{</ table >}}

[Table 1]은 HAMi Scheduler Metric에 공통으로 붙는 Label을 나타내고 있다. HAMi Scheduler는 등록된 모든 Accelerator의 할당 내역을 관리하기 때문에, Accelerator 종류와 관계없이 같은 이름의 Metric을 노출하며 Accelerator 종류는 Label로 구분된다. `node`, `device_uuid`, `device_index`, `device_type`은 Accelerator 단위 Metric에, `namespace`와 `pod`는 Pod 단위 Metric에 붙는다. 특정 Metric에만 붙는 Label은 각 Metric 표의 추가 Label 열에 나타낸다.

#### 1.1.1. Accelerator Allocation Metrics

{{< table caption="[Table 2] HAMi Scheduler Accelerator Allocation Metrics" >}}
| Metric | Description | Metric Type | Value Unit | 추가 Label |
|---|---|---|---|---|
| `hami_gpu_memory_limit_bytes` | Node Annotation에 등록된 Accelerator의 할당 가능한 Memory 크기. `deviceMemoryScaling`이 1보다 크면 물리 Memory보다 크게 나타남 | Gauge | Byte |  |
| `hami_gpu_memory_allocated_bytes` | Accelerator에 할당된 Memory 크기. Pod Annotation에 기록된 할당량의 합 | Gauge | Byte | `device_cores`: 할당 가능한 Core 사용률 (예: `100`) |
| `hami_node_gpu_memory_allocated_ratio` | Accelerator의 할당 가능한 Memory 대비 할당된 Memory 비율 | Gauge | Ratio (0 ~ 1) |  |
| `hami_gpu_core_limit_ratio` | Accelerator의 할당 가능한 Core 사용률. AMD GPU는 물리 CU 개수를 100 기준으로 환산한 값 | Gauge | Percentage (0 ~ 100) |  |
| `hami_gpu_core_allocated_ratio` | Accelerator에 할당된 Core 사용률. AMD GPU는 물리 CU 개수를 100 기준으로 환산한 값 | Gauge | Percentage (0 ~ 100) |  |
| `hami_gpu_shared_count` | Accelerator를 공유하는 Container 개수 | Gauge | |  |
| `hami_node_gpu_overview` | Accelerator에 할당된 Memory 크기. Core 사용률과 Memory 크기 한도를 Label로 함께 제공 | Gauge | Byte | `device_cores`: 할당 가능한 Core 사용률 (예: `100`), `device_memory_limit`: 할당 가능한 Memory 크기 MiB (예: `16311`) |
| `hami_node_gpu_mig_instance_info` | 생성된 MIG Instance의 정보. MIG Mode로 동작하는 Accelerator에서만 노출되며 값은 항상 `1` | Gauge | | `mig_uuid`, `profile` (예: `1g.10gb`), `gpu_instance_id`, `compute_instance_id`, `placement_start`, `placement_size` |
{{</ table >}}

[Table 2]는 HAMi Scheduler의 할당 내역을 기준으로 한 물리 Accelerator별 할당 상태 Metric을 나타내고 있다.

#### 1.1.2. Pod Allocation Metrics

{{< table caption="[Table 3] HAMi Scheduler Pod Allocation Metrics" >}}
| Metric | Description | Metric Type | Value Unit |
|---|---|---|---|
| `hami_vgpu_memory_allocated_bytes` | Pod에 할당된 Accelerator Memory 크기 | Gauge | Byte |
| `hami_vgpu_core_allocated_ratio` | Pod에 할당된 Accelerator Core 사용률 | Gauge | Percentage (0 ~ 100) |
{{</ table >}}

[Table 3]은 HAMi Scheduler가 Pod에 할당한 Accelerator의 양을 나타내고 있으며, Pod에 할당된 Accelerator마다 하나씩 노출된다. [Table 3]의 Metric에는 Container를 구분하는 Label이 없는데, HAMi Scheduler는 Pod 단위로 합산된 할당 내역만 관리하기 때문이다.

#### 1.1.3. Quota Metrics

{{< table caption="[Table 4] HAMi Scheduler Quota Metrics" >}}
| Metric | Description | Metric Type | Value Unit | 추가 Label |
|---|---|---|---|---|
| `hami_resource_quota_used` | Namespace에서 사용 중인 Accelerator의 Memory 크기 또는 Core 사용률 | Gauge | MiB (Memory) 또는 Percentage (Core) | `quota_name`: 제한하는 Resource 이름 (예: `nvidia.com/gpumem`) |
| `hami_resource_quota_limit` | ResourceQuota에 설정된 Accelerator의 Memory 크기 또는 Core 사용률 한도. 한도가 설정된 Resource만 노출되며, 같은 Resource를 제한하는 ResourceQuota가 여러 개이면 가장 작은 한도 | Gauge | MiB (Memory) 또는 Percentage (Core) | `quota_name`: 제한하는 Resource 이름 (예: `nvidia.com/gpumem`) |
{{</ table >}}

[Table 4]는 Kubernetes의 ResourceQuota로 Namespace별 Accelerator 사용량을 제한할 때, HAMi Scheduler가 집계하는 사용량과 한도를 나타내고 있다. HAMi Scheduler는 ResourceQuota의 `spec.hard`에서 `limits.nvidia.com/gpumem`, `limits.nvidia.com/gpucores`처럼 `limits.` 접두사가 붙은 Accelerator의 Memory 크기, Core 사용률 Resource를 읽고, Scheduling할 때 Namespace의 사용량에 Pod의 요청량을 더한 값이 한도를 넘으면 Pod에 Accelerator를 할당하지 않는다.

#### 1.1.4. State Metrics

{{< table caption="[Table 5] HAMi Scheduler State Metrics" >}}
| Metric | Description | Metric Type | Value Unit | 추가 Label |
|---|---|---|---|---|
| `hami_scheduler_is_leader` | HAMi Scheduler Instance의 Leader 여부. Leader이면 `1`, 아니면 `0` | Gauge | |  |
| `hami_scheduler_cache_synced` | HAMi Scheduler 내부 Node, Accelerator Cache의 동기화 완료 여부. 완료되었으면 `1`, 아니면 `0` | Gauge | |  |
| `hami_scheduler_allocations_total` | 성공한 Accelerator 할당 횟수 | Counter | | `phase` (예: `filter`), `device_type`: Accelerator 종류 (예: `NVIDIA`), `failure_reason`: 항상 `none` |
| `hami_scheduler_allocation_failures_total` | 실패한 Accelerator 할당 횟수 | Counter | | `phase` (예: `filter`, `bind`), `device_type`: Accelerator 종류 (예: `NVIDIA`), `failure_reason` (예: `no_fit`, `lookup`, `identity`, `lock`, `annotation_patch`, `bind`, `internal`) |
| `hami_scheduler_bind_rollbacks_total` | Bind 실패로 예약된 Accelerator를 해제한 횟수 | Counter | | `phase` (예: `bind`), `device_type`: Accelerator 종류 (예: `NVIDIA`), `failure_reason`: `lock`, `annotation_patch`, `bind` 중 하나 |
{{</ table >}}

[Table 5]는 HAMi Scheduler의 상태와 할당 결과 Metric을 나타내고 있다.

### 1.2. HAMi Device Plugin NVIDIA Metrics

{{< table caption="[Table 6] HAMi Device Plugin NVIDIA Metric의 공통 Label" >}}
| Label | Description | 예시 |
|---|---|---|
| `zone` | 모든 Metric에 붙는 고정 값 | `vGPU` |
| `node` | GPU가 위치한 Node 이름 | `gpu-node` |
| `device_uuid` | GPU의 UUID | `GPU-034026c4-...` |
| `device_index` | Node 안에서의 GPU 번호 | `0` |
| `device_type` | NVML로 조회한 GPU 모델 이름 | `NVIDIA GeForce RTX 5060 Ti` |
| `namespace` | GPU를 할당받은 Pod의 Namespace | `default` |
| `pod` | GPU를 할당받은 Pod 이름 | `poda` |
| `container` | GPU를 할당받은 Container 이름 | `container` |
| `vdevice_index` | Container에 할당된 GPU 중의 번호 | `0` |
{{</ table >}}

[Table 6]은 HAMi Device Plugin NVIDIA Metric에 공통으로 붙는 Label을 나타내고 있다. `node`, `device_index`, `device_type`은 Host GPU Metric에, `namespace`, `pod`, `container`, `vdevice_index`는 Container Metric에 붙는다. 특정 Metric에만 붙는 Label은 각 Metric 표의 추가 Label 열에 나타낸다.

HAMi Device Plugin NVIDIA Metric은 HAMi Device Plugin의 `vgpu-monitor` Container가 노출한다. `vgpu-monitor` Container는 NVIDIA GPU용 HAMi Device Plugin DaemonSet에만 포함되며, NVML과 격리 Library의 Shared Memory를 통해서 사용량을 수집하기 때문에 **NVIDIA GPU 전용** Metric이다.

#### 1.2.1. Host GPU Metrics

{{< table caption="[Table 7] NVIDIA GPU Host Metrics" >}}
| Metric | Description | Metric Type | Value Unit | 추가 Label |
|---|---|---|---|---|
| `hami_host_gpu_memory_used_bytes` | GPU에서 사용 중인 Memory 크기 | Gauge | Byte |  |
| `hami_host_gpu_utilization_ratio` | GPU Core 사용률 | Gauge | Percentage (0 ~ 100) |  |
| `hami_host_gpu_memory_controller_utilization_ratio` | GPU Memory Controller 사용률 | Gauge | Percentage (0 ~ 100) |  |
| `hami_host_gpu_temperature_celsius` | GPU 온도 | Gauge | °C |  |
| `hami_host_gpu_power_usage_watts` | GPU 전력 소모량 | Gauge | Watt |  |
| `hami_host_gpu_ecc_errors_total` | GPU의 누적 ECC Error 개수 | Counter | | `error_type`: ECC Error 종류 (예: `corrected`, `uncorrected`) |
| `hami_host_gpu_unknown_process_count` | GPU에서 동작 중이지만 HAMi가 할당한 Container와 연결되지 않은 Process 개수. vGPU monitor에 `HAMI_MONITOR_UNKNOWN_PROCESSES=true`가 설정된 경우에만 노출 | Gauge | |  |
{{</ table >}}

[Table 7]은 vGPU monitor가 NVML을 통해서 조회한 Node의 물리 GPU 상태 Metric을 나타내고 있다. GPU가 지원하지 않는 항목은 노출되지 않는다.

#### 1.2.2. Container Metrics

{{< table caption="[Table 8] NVIDIA GPU Container Metrics" >}}
| Metric | Description | Metric Type | Value Unit | 추가 Label |
|---|---|---|---|---|
| `hami_vgpu_memory_used_bytes` | Container가 사용 중인 Accelerator Memory 크기 | Gauge | Byte |  |
| `hami_vgpu_memory_limit_bytes` | 격리 Library에 설정된 Container의 Memory 한도. GPU를 통째로 할당받은 Container는 GPU 전체 Memory 크기 | Gauge | Byte |  |
| `hami_vgpu_memory_context_bytes` | Container의 Process가 CUDA Primary Context를 생성하면서 사용한 Memory 크기. GPU를 통째로 할당받은 Container는 `0` | Gauge | Byte |  |
| `hami_vgpu_memory_module_bytes` | Module 용도로 정의된 Memory 크기. 격리 Library가 값을 기록하지 않아 항상 `0` | Gauge | Byte |  |
| `hami_vgpu_memory_buffer_bytes` | Application이 CUDA Memory 할당 API로 할당한 Memory 크기. GPU를 통째로 할당받은 Container는 `0` | Gauge | Byte |  |
| `hami_container_device_utilization_ratio` | Container의 SM 사용률. Container 안 Process들의 SM 사용률 합계 | Gauge | Percentage |  |
| `hami_container_last_kernel_elapsed_seconds` | Container에서 마지막 Kernel이 실행된 이후 경과 시간. Kernel이 한 번 이상 실행된 이후부터 노출되며, GPU를 통째로 할당받은 Container는 노출되지 않음 | Gauge | Second |  |
| `hami_mig_device_info` | Container에 할당된 MIG Instance의 정보. Pod Annotation에 MIG 할당 정보가 기록된 경우에만 노출되며 값은 항상 `1` | Gauge | | `mig_uuid`, `profile` (예: `1g.10gb`), `gpu_instance_id`, `compute_instance_id` |
{{</ table >}}

[Table 8]은 Container가 실제로 사용하는 GPU의 양을 나타내고 있으며, Container에 할당된 GPU마다 하나씩 노출된다. HAMi Scheduler가 할당한 양이 아니라 실제 사용량이라는 점이 [Table 3]과 다르다.

격리 Library가 주입된 Container는 격리 Library가 Shared Memory에 기록한 사용량을 vGPU monitor가 읽어서 노출한다. 반면 GPU를 통째로 할당받거나 MIG Instance를 할당받은 Container에는 기본값이 `true`인 Helm의 `devicePlugin.monitor.disableHAMiCoreForWholeGPU` 설정에 따라 격리 Library가 주입되지 않으며, vGPU monitor가 NVML로 조회한 값으로 Metric을 대신 만들어 노출한다. 이때 MIG Instance의 SM 사용률은 vGPU monitor에 내장된 DCGM으로 조회한다.

#### 1.2.3. State Metrics

{{< table caption="[Table 9] NVIDIA GPU vGPU monitor State Metrics" >}}
| Metric | Description | Metric Type | Value Unit |
|---|---|---|---|
| `hami_vgpumonitor_collect_success` | 마지막 Metric 수집의 성공 여부. 모두 성공하면 `1`, 일부라도 실패하면 `0`. vGPU monitor는 일부 수집에 실패해도 HTTP 응답은 정상으로 반환하기 때문에 수집 실패는 이 Metric으로 확인 | Gauge | |
{{</ table >}}

[Table 9]는 vGPU monitor의 Metric 수집 상태를 나타내고 있다.

### 1.3. Build Info Metrics

{{< table caption="[Table 10] Build Info Metrics" >}}
| Metric | Description | Metric Type | Value Unit |
|---|---|---|---|
| `hami_build_info` | HAMi의 Build 정보. 값은 항상 `1` | Gauge | |
{{</ table >}}

[Table 10]은 HAMi Scheduler와 vGPU monitor가 공통으로 노출하는 Build 정보 Metric을 나타내고 있다.

### 1.4. Legacy Metrics

{{< table caption="[Table 11] Legacy Metric과 현재 Metric의 대응" >}}
| Component | Legacy Metric | 현재 Metric |
|---|---|---|
| HAMi Scheduler | `GPUDeviceMemoryLimit` | `hami_gpu_memory_limit_bytes` |
| HAMi Scheduler | `GPUDeviceMemoryAllocated` | `hami_gpu_memory_allocated_bytes` |
| HAMi Scheduler | `GPUDeviceCoreLimit` | `hami_gpu_core_limit_ratio` |
| HAMi Scheduler | `GPUDeviceCoreAllocated` | `hami_gpu_core_allocated_ratio` |
| HAMi Scheduler | `GPUDeviceSharedNum` | `hami_gpu_shared_count` |
| HAMi Scheduler | `nodeGPUOverview` | `hami_node_gpu_overview` |
| HAMi Scheduler | `nodeGPUMemoryPercentage` | `hami_node_gpu_memory_allocated_ratio` |
| HAMi Scheduler | `nodeGPUMigInstance` | `hami_node_gpu_mig_instance_info` |
| HAMi Scheduler | `QuotaUsed` | `hami_resource_quota_used` |
| HAMi Scheduler | `vGPUMemoryAllocated` | `hami_vgpu_memory_allocated_bytes` |
| HAMi Scheduler | `vGPUCoreAllocated` | `hami_vgpu_core_allocated_ratio` |
| vGPU monitor | `HostGPUMemoryUsage` | `hami_host_gpu_memory_used_bytes` |
| vGPU monitor | `HostCoreUtilization` | `hami_host_gpu_utilization_ratio` |
| vGPU monitor | `vGPU_device_memory_usage_in_bytes` | `hami_vgpu_memory_used_bytes` |
| vGPU monitor | `vGPU_device_memory_limit_in_bytes` | `hami_vgpu_memory_limit_bytes` |
| vGPU monitor | `Device_memory_desc_of_container` | `hami_vgpu_memory_used_bytes` |
| vGPU monitor | `Device_utilization_desc_of_container` | `hami_container_device_utilization_ratio` |
| vGPU monitor | `Device_last_kernel_of_container` | `hami_container_last_kernel_elapsed_seconds` |
| vGPU monitor | `MigInfo` | `hami_mig_device_info` |
{{</ table >}}

[Table 11]은 Legacy Metric과 현재 Metric의 대응을 나타내고 있다. Helm의 `legacyMetrics` 설정을 `true`로 지정하면 HAMi Scheduler와 vGPU monitor는 현재 Metric과 함께 이전 이름의 Metric도 노출한다. 기본값은 `false`이며, 이전 버전 기준으로 작성된 Dashboard를 계속 이용할 때 활성화한다.

Legacy Metric은 Label 이름도 `nodeid`, `deviceuuid`, `podnamespace` 같은 이전 이름을 이용한다. 또한 `GPUDeviceCoreLimit`, `GPUDeviceCoreAllocated`, `vGPUCoreAllocated`는 AMD GPU의 Core 값을 사용률로 환산하지 않고 그대로 노출한다.

## 2. with DCGM Exporter

NVIDIA GPU 환경에서는 HAMi Metric과 DCGM Exporter를 함께 이용하는 것이 좋다. 두 Metric은 다음과 같이 역할을 나누어 이용한다.

* **HAMi Metric** : Accelerator별 할당 현황과 Container별 실제 GPU 사용량을 확인할 때 이용한다. GPU의 Memory 사용량, 사용률, 온도, 전력, ECC Error 같은 기본 상태도 함께 제공한다.
* **DCGM Exporter** : GPU의 상세 성능과 장애를 확인할 때 이용한다. SM과 Tensor Core의 동작 비율 같은 Profiling Metric과 NVLink, PCIe, Clock, XID Error, Throttling, Remapped Row 관련 Metric은 DCGM Exporter만 제공한다.

Container별 GPU 사용량을 DCGM Exporter로 확인할 수 없는 이유는 Pod 정보를 연결하는 방식에 있다. DCGM Exporter는 kubelet의 Pod Resources API에서 Pod에 할당된 Device ID를 조회하여 GPU Metric에 Pod 정보를 붙이는데, HAMi Device Plugin이 kubelet에 등록하는 Device ID는 `<GPU UUID>-<번호>` 형식이다. DCGM Exporter는 `::` 접미사가 붙은 ID, MIG UUID, GKE 형식의 ID만 GPU UUID로 변환하기 때문에 HAMi 환경에서는 GPU Metric에 Pod 정보가 붙지 않는다. 또한 하나의 GPU를 여러 Pod가 나눠 쓰기 때문에 GPU 단위의 Metric만으로는 Pod별 사용량을 구분할 수 없다.

## 3. 참조

* HAMi Scheduler Metrics Source : [https://github.com/Project-HAMi/HAMi/blob/v2.11.0/cmd/scheduler/metrics.go](https://github.com/Project-HAMi/HAMi/blob/v2.11.0/cmd/scheduler/metrics.go)
* HAMi Scheduler Outcome Metrics Source : [https://github.com/Project-HAMi/HAMi/blob/v2.11.0/pkg/metrics/scheduler.go](https://github.com/Project-HAMi/HAMi/blob/v2.11.0/pkg/metrics/scheduler.go)
* HAMi vGPU monitor Metrics Source : [https://github.com/Project-HAMi/HAMi/blob/v2.11.0/cmd/vGPUmonitor/metrics.go](https://github.com/Project-HAMi/HAMi/blob/v2.11.0/cmd/vGPUmonitor/metrics.go)
* HAMi Whole GPU Monitor Source : [https://github.com/Project-HAMi/HAMi/blob/v2.11.0/pkg/monitor/nvidia/wholegpu.go](https://github.com/Project-HAMi/HAMi/blob/v2.11.0/pkg/monitor/nvidia/wholegpu.go)
* DCGM Exporter Pod Mapping Source : [https://github.com/NVIDIA/dcgm-exporter/blob/main/internal/pkg/transformation/kubernetes_mapping.go](https://github.com/NVIDIA/dcgm-exporter/blob/main/internal/pkg/transformation/kubernetes_mapping.go)
* NVIDIA DCGM Exporter Metrics : [https://ssup2.github.io/blog-software/docs/theory-analysis/nvidia-dcgm-exporter-metrics/](https://ssup2.github.io/blog-software/docs/theory-analysis/nvidia-dcgm-exporter-metrics/)

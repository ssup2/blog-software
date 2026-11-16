---
title: "Kubernetes HAMi Metrics"
draft: true
---

HAMi 2.11.0이 노출하는 Prometheus Metric을 정리한다. HAMi의 Metric은 HAMi Scheduler와 HAMi Device Plugin의 vGPU monitor Container가 각각 노출한다.

* **HAMi Scheduler** : `hami-scheduler` Pod의 `9395` Port에서 `/metrics`로 노출하며, `hami-scheduler` Service의 `31993` Port로 수집한다. HAMi Scheduler가 관리하는 할당 내역을 기준으로 하며, 모든 Accelerator에 공통으로 적용된다.
* **vGPU monitor** : `hami-device-plugin` Pod의 `9394` Port에서 `/metrics`로 노출하며, `hami-device-plugin-monitor` Service의 `31992` NodePort로 수집한다. Node의 GPU와 Container가 실제로 이용하는 양을 기준으로 하며, NVIDIA GPU에만 적용된다.

## 1. Metric 목록

### 1.1. HAMi Scheduler Metrics

HAMi Scheduler가 노출하는 Metric이다. HAMi Scheduler는 등록된 모든 Accelerator의 할당 내역을 관리하기 때문에, Accelerator 종류와 관계없이 같은 이름의 Metric을 노출하며 Accelerator 종류는 `device_type` Label로 구분된다. 모든 Metric에는 `zone="vGPU"` Label이 붙으며, 여기서 vGPU는 NVIDIA의 vGPU 제품이 아니라 HAMi가 하나의 Accelerator를 나누어 할당하는 단위를 의미한다.

#### 1.1.1. Node Allocation Metrics

HAMi Scheduler의 할당 내역을 기준으로 물리 Accelerator별 할당 상태를 나타내는 Metric이다.

{{< table caption="[Table 1] HAMi Scheduler Node Allocation Metrics" >}}
| Metric | Description | Metric Type | Value Unit |
|---|---|---|---|
| `hami_gpu_memory_limit_bytes` | Accelerator의 할당 가능한 Memory 크기 | Gauge | Byte |
| `hami_gpu_memory_allocated_bytes` | Accelerator에 할당된 Memory 크기 | Gauge | Byte |
| `hami_node_gpu_memory_allocated_ratio` | Accelerator의 할당 가능한 Memory 대비 할당된 Memory 비율 | Gauge | Ratio (0 ~ 1) |
| `hami_gpu_core_limit_ratio` | Accelerator의 할당 가능한 Core 사용률 | Gauge | Percentage (0 ~ 100) |
| `hami_gpu_core_allocated_ratio` | Accelerator에 할당된 Core 사용률 | Gauge | Percentage (0 ~ 100) |
| `hami_gpu_shared_count` | Accelerator를 공유하는 Container 개수 | Gauge | |
| `hami_node_gpu_overview` | Accelerator에 할당된 Memory 크기. Core 사용률과 Memory 크기 한도를 Label로 함께 제공 | Gauge | Byte |
| `hami_node_gpu_mig_instance_info` | 생성된 MIG Instance의 정보. 값은 항상 `1` | Gauge | |
{{</ table >}}

[Table 1]의 Memory 값은 HAMi Device Plugin이 Node Annotation에 등록한 Memory 크기와 Pod Annotation에 기록된 할당량을 Byte로 환산한 값이다. 따라서 Memory 과할당 비율인 `deviceMemoryScaling`을 1보다 크게 설정하면 `hami_gpu_memory_limit_bytes`는 물리 Memory보다 크게 나타난다. AMD GPU의 Core 값은 물리 CU 개수가 아니라 100을 기준으로 환산한 사용률로 노출된다. `hami_node_gpu_mig_instance_info`는 MIG Mode로 동작하는 Accelerator에서만 노출된다.

#### 1.1.2. Pod Allocation Metrics

HAMi Scheduler가 Pod에 할당한 Accelerator의 양을 나타내는 Metric이다. Pod에 할당된 Accelerator마다 하나씩 노출된다.

{{< table caption="[Table 2] HAMi Scheduler Pod Allocation Metrics" >}}
| Metric | Description | Metric Type | Value Unit |
|---|---|---|---|
| `hami_vgpu_memory_allocated_bytes` | Pod에 할당된 Accelerator Memory 크기 | Gauge | Byte |
| `hami_vgpu_core_allocated_ratio` | Pod에 할당된 Accelerator Core 사용률 | Gauge | Percentage (0 ~ 100) |
{{</ table >}}

[Table 2]의 Metric에는 Container를 구분하는 Label이 없다. HAMi Scheduler는 Pod 단위로 합산된 할당 내역만 관리하기 때문이다.

#### 1.1.3. Quota Metrics

HAMi의 Resource Quota 사용량을 나타내는 Metric이다.

{{< table caption="[Table 3] HAMi Scheduler Quota Metrics" >}}
| Metric | Description | Metric Type | Value Unit |
|---|---|---|---|
| `hami_resource_quota_used` | Resource Quota의 사용량 | Gauge | |
| `hami_resource_quota_limit` | Resource Quota의 한도 | Gauge | |
{{</ table >}}

`hami_resource_quota_limit`은 한도가 설정된 Resource Quota만 노출된다.

#### 1.1.4. Remote GPU Metrics

네트워크를 통해서 GPU를 제공하는 Lupine Server의 GPU를 나타내는 Metric이다. Remote GPU 기능을 설정한 경우에만 노출되며, GPU를 보유한 Server 기준으로 한 번씩 노출된다.

{{< table caption="[Table 4] HAMi Scheduler Remote GPU Metrics" >}}
| Metric | Description | Metric Type | Value Unit |
|---|---|---|---|
| `hami_remote_gpu_memory_limit_bytes` | Remote GPU의 Memory 크기 | Gauge | Byte |
| `hami_remote_gpu_allocated` | Remote GPU의 할당 여부. Pod가 점유하면 `1`, 비어 있으면 `0` | Gauge | |
| `hami_remote_gpu_overview` | Remote GPU에 할당된 Memory 크기. Core와 Memory 크기를 Label로 함께 제공 | Gauge | Byte |
{{</ table >}}

Remote GPU는 GPU 단위로 통째로 할당되기 때문에 `hami_remote_gpu_overview`의 값은 GPU 전체 Memory 크기 또는 `0`이다.

#### 1.1.5. State Metrics

HAMi Scheduler의 상태와 할당 결과를 나타내는 Metric이다.

{{< table caption="[Table 5] HAMi Scheduler State Metrics" >}}
| Metric | Description | Metric Type | Value Unit |
|---|---|---|---|
| `hami_scheduler_is_leader` | HAMi Scheduler Instance의 Leader 여부. Leader이면 `1`, 아니면 `0` | Gauge | |
| `hami_scheduler_cache_synced` | HAMi Scheduler 내부 Node, Accelerator Cache의 동기화 완료 여부. 완료되었으면 `1`, 아니면 `0` | Gauge | |
| `hami_scheduler_allocations_total` | 성공한 Accelerator 할당 횟수 | Counter | |
| `hami_scheduler_allocation_failures_total` | 실패한 Accelerator 할당 횟수 | Counter | |
| `hami_scheduler_bind_rollbacks_total` | Bind 실패로 예약된 Accelerator를 해제한 횟수 | Counter | |
{{</ table >}}

`phase` Label은 할당이 수행된 단계를 나타내며 `filter` 또는 `bind` 값을 갖는다. `failure_reason` Label은 실패 원인을 나타내며 `none`, `no_fit`, `lookup`, `identity`, `lock`, `annotation_patch`, `bind`, `internal` 중 하나의 값을 갖는다. 성공한 할당은 `failure_reason="none"`으로 기록된다.

### 1.2. HAMi Device Plugin NVIDIA Metrics

HAMi Device Plugin의 `vgpu-monitor` Container가 노출하는 Metric이다. `vgpu-monitor` Container는 NVIDIA GPU용 HAMi Device Plugin DaemonSet에만 포함되며, NVML과 격리 Library의 Shared Memory를 통해서 사용량을 수집하기 때문에 **NVIDIA GPU 전용** Metric이다.

#### 1.2.1. Host GPU Metrics

vGPU monitor가 NVML을 통해서 조회한 Node의 물리 GPU 상태를 나타내는 Metric이다. GPU가 지원하지 않는 항목은 노출되지 않는다.

{{< table caption="[Table 6] NVIDIA GPU Host Metrics" >}}
| Metric | Description | Metric Type | Value Unit |
|---|---|---|---|
| `hami_host_gpu_memory_used_bytes` | GPU에서 사용 중인 Memory 크기 | Gauge | Byte |
| `hami_host_gpu_utilization_ratio` | GPU Core 사용률 | Gauge | Percentage (0 ~ 100) |
| `hami_host_gpu_memory_controller_utilization_ratio` | GPU Memory Controller 사용률 | Gauge | Percentage (0 ~ 100) |
| `hami_host_gpu_temperature_celsius` | GPU 온도 | Gauge | °C |
| `hami_host_gpu_power_usage_watts` | GPU 전력 소모량 | Gauge | Watt |
| `hami_host_gpu_ecc_errors_total` | GPU의 누적 ECC Error 개수 | Counter | |
| `hami_host_gpu_unknown_process_count` | GPU에서 동작 중이지만 HAMi가 할당한 Container와 연결되지 않은 Process 개수 | Gauge | |
{{</ table >}}

`hami_host_gpu_ecc_errors_total`의 `error_type` Label은 `corrected` 또는 `uncorrected` 값을 갖는다. `hami_host_gpu_unknown_process_count`는 vGPU monitor에 `HAMI_MONITOR_UNKNOWN_PROCESSES=true` 환경 변수가 설정된 경우에만 노출된다.

#### 1.2.2. Container Metrics

Container가 실제로 사용하는 GPU의 양을 나타내는 Metric이며, Container에 할당된 GPU마다 하나씩 노출된다. 격리 Library가 주입된 Container는 격리 Library가 Shared Memory에 기록한 사용량을 vGPU monitor가 읽어서 노출한다. 반면 GPU를 통째로 할당받거나 MIG Instance를 할당받은 Container에는 기본값이 `true`인 Helm의 `devicePlugin.monitor.disableHAMiCoreForWholeGPU` 설정에 따라 격리 Library가 주입되지 않으며, vGPU monitor가 NVML로 조회한 값으로 Metric을 대신 만들어 노출한다. 이때 MIG Instance의 SM 사용률은 vGPU monitor에 내장된 DCGM으로 조회한다.

{{< table caption="[Table 7] NVIDIA GPU Container Metrics" >}}
| Metric | Description | Metric Type | Value Unit |
|---|---|---|---|
| `hami_vgpu_memory_used_bytes` | Container가 사용 중인 Accelerator Memory 크기 | Gauge | Byte |
| `hami_vgpu_memory_limit_bytes` | Container의 Accelerator Memory 한도 | Gauge | Byte |
| `hami_vgpu_memory_context_bytes` | Container가 사용 중인 Memory 중 Context 크기 | Gauge | Byte |
| `hami_vgpu_memory_module_bytes` | Container가 사용 중인 Memory 중 Module 크기 | Gauge | Byte |
| `hami_vgpu_memory_buffer_bytes` | Container가 사용 중인 Memory 중 Buffer 크기 | Gauge | Byte |
| `hami_container_device_utilization_ratio` | Container의 SM 사용률. Container 안 Process들의 SM 사용률 합계 | Gauge | Percentage |
| `hami_container_last_kernel_elapsed_seconds` | Container에서 마지막 Kernel이 실행된 이후 경과 시간 | Gauge | Second |
| `hami_mig_device_info` | Container에 할당된 MIG Instance의 정보. 값은 항상 `1` | Gauge | |
{{</ table >}}

[Table 7]의 Metric은 HAMi Scheduler가 할당한 양이 아니라 Container가 실제로 사용하는 양을 나타낸다. `hami_vgpu_memory_limit_bytes`는 격리 Library에 설정된 Container의 Memory 한도이고, `hami_vgpu_memory_used_bytes`는 그 한도 안에서 실제로 사용 중인 양이다. GPU를 통째로 할당받은 Container는 GPU 전체 Memory 크기가 한도로 노출되며, Memory의 Context, Module, Buffer 크기는 `0`으로 노출되고 마지막 Kernel 경과 시간은 노출되지 않는다. `vdevice_index` Label은 Container에 할당된 Accelerator 중 몇 번째인지를 나타낸다. `hami_container_last_kernel_elapsed_seconds`는 Kernel이 한 번 이상 실행된 이후부터 노출되며, `hami_mig_device_info`는 Pod Annotation에 MIG 할당 정보가 기록된 경우에만 노출된다.

#### 1.2.3. State Metrics

vGPU monitor의 Metric 수집 상태를 나타내는 Metric이다.

{{< table caption="[Table 8] NVIDIA GPU vGPU monitor State Metrics" >}}
| Metric | Description | Metric Type | Value Unit |
|---|---|---|---|
| `hami_vgpumonitor_collect_success` | 마지막 Metric 수집의 성공 여부. 모두 성공하면 `1`, 일부라도 실패하면 `0` | Gauge | |
{{</ table >}}

vGPU monitor는 일부 Metric 수집에 실패해도 HTTP 응답은 정상으로 반환하기 때문에, 수집 실패는 `hami_vgpumonitor_collect_success`로 확인해야 한다.

### 1.3. Build Info Metrics

HAMi Scheduler와 vGPU monitor가 공통으로 노출하는 Build 정보 Metric이다.

{{< table caption="[Table 9] Build Info Metrics" >}}
| Metric | Description | Metric Type | Value Unit |
|---|---|---|---|
| `hami_build_info` | HAMi의 Build 정보. 값은 항상 `1` | Gauge | |
{{</ table >}}

### 1.4. Legacy Metrics

Helm의 `legacyMetrics` 설정을 `true`로 지정하면 HAMi Scheduler와 vGPU monitor는 현재 Metric과 함께 이전 이름의 Metric도 노출한다. 기본값은 `false`이며, 이전 버전 기준으로 작성된 Dashboard를 계속 이용할 때 활성화한다.

{{< table caption="[Table 10] Legacy Metric과 현재 Metric의 대응" >}}
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

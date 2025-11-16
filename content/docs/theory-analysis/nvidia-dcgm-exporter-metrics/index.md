---
title: "NVIDIA DCGM Exporter Metrics"
---

NVIDIA DCGM Exporter가 노출하는 Metric을 정리한다.

## 1. Metric 목록

### 1.1. Utilization Metrics

GPU 사용률을 의미

{{< table caption="[Table 1] NVIDIA DCGM Exporter Utilization Metrics" >}}
| Metric | Description | Metric Type | Value Unit |
|---|---|---|---|
| `DCGM_FI_DEV_GPU_UTIL` | 전반적인 GPU 사용률를 의미 | Gauge | Percentage (0 ~ 100) |
| `DCGM_FI_DEV_MEM_COPY_UTIL` | 특정 주기 동안 GPU Memory에 Data가 복사가 수행된 시간 비율 | Gauge | Percentage (0 ~ 100) |
| `DCGM_FI_DEV_ENC_UTIL` | Encoder의 사용률 | Gauge | Percentage (0 ~ 1) |
| `DCGM_FI_DEV_DEC_UTIL` | Decoder의 사용률 | Gauge | Percentage (0 ~ 1) |
{{</ table >}}

### 1.2. Memory Metrics

GPU Memory 사용량을 의미

{{< table caption="[Table 2] NVIDIA DCGM Exporter Memory Metrics" >}}
| Metric | Description | Metric Type | Value Unit |
|---|---|---|---|
| `DCGM_FI_DEV_FB_FREE` | 이용 가능한 GPU Memory 용량 | Gauge | MB |
| `DCGM_FI_DEV_FB_USED` | 이용중인 GPU Memory 용량 | Gauge | MB |
{{</ table >}}

### 1.3. Clock Metrics

GPU, GPU Memory의 Clock 상태를 의미

{{< table caption="[Table 3] NVIDIA DCGM Exporter Clock Metrics" >}}
| Metric | Description | Metric Type | Value Unit |
|---|---|---|---|
| `DCGM_FI_DEV_SM_CLOCK` | SM (Streaming Multiprocessor)의 Clock | Gauge | MHz |
| `DCGM_FI_DEV_MEM_CLOCK` | GPU Memory Clock | Gauge | MHz |
{{</ table >}}

### 1.4. NVLink Metrics

NVLink Metric

{{< table caption="[Table 4] NVIDIA DCGM Exporter NVLink Metrics" >}}
| Metric | Description | Metric Type | Value Unit |
|---|---|---|---|
| `DCGM_FI_DEV_NVLINK_CRC_FLIT_ERROR_COUNT_TOTAL` | NVLink에서 Flow-Control CRC Error가 발생한 횟수 | Counter | |
| `DCGM_FI_DEV_NVLINK_CRC_DATA_ERROR_COUNT_TOTAL` | NVLink에서 Data CRC Error가 발생한 횟수 | Counter | |
| `DCGM_FI_DEV_NVLINK_REPLAY_ERROR_COUNT_TOTAL` | NVLink에서 Retry가 발생한 횟수 | Counter | |
| `DCGM_FI_DEV_NVLINK_RECOVERY_ERROR_COUNT_TOTAL` | NVLink에서 Recovery가 발생한 횟수 | Counter | |
| `DCGM_FI_DEV_NVLINK_BANDWIDTH_TOTAL` | NVLink의 Bandwidth Counter | Counter | |
| `DCGM_FI_DEV_NVLINK_BANDWIDTH_L0` | 활성화된 NVLink를 통해서 주고 받은 Data양 (Header & Payload) | Counter | Byte |
{{</ table >}}

### 1.5. PCIe Metrics

PCIe Metric

{{< table caption="[Table 5] NVIDIA DCGM Exporter PCIe Metrics" >}}
| Metric | Description | Metric Type | Value Unit |
|---|---|---|---|
| `DCGM_FI_DEV_PCIE_REPLAY_COUNTER` | PCIe에서 Packet 전송에 Error가 발생하여 재시도한 횟수 | Counter | |
{{</ table >}}

### 1.6. DCP (Profiling) Metrics

Profiling Metric

{{< table caption="[Table 6] NVIDIA DCGM Exporter DCP (Profiling) Metrics" >}}
| Metric | Description | Metric Type | Value Unit |
|---|---|---|---|
| `DCGM_FI_PROF_GR_ENGINE_ACTIVE` | SM(Streaming Multiprocessor) 내부의 CUDA Core가 특정 주기 동안 동작한 시간 비율 | Gauge | Percentage (0 ~ 1) |
| `DCGM_FI_PROF_PIPE_TENSOR_ACTIVE` | Tensor Core가 특정 주기 동안 동작한 시간 비율 | Gauge | Percentage (0 ~ 1) |
| `DCGM_FI_PROF_DRAM_ACTIVE` | 특정 주기 동안 GPU Memory가 동작한 시간 비율 | Gauge | Percentage (0 ~ 1) |
| `DCGM_FI_PROF_PCIE_RX_BYTES` | GPU가 PCIe로부터 수신하는 Data양 (Header & Payload) | Gauge | Bytes per second |
| `DCGM_FI_PROF_PCIE_TX_BYTES` | GPU가 PCIe로 송신하는 Data양 (Header & Payload) | Gauge | Bytes per second |
{{</ table >}}

### 1.7. Remapping Rows Metrics

GPU Memory에서 수행하는 Remapping Row Metric. Remapping Row는 GPU Memory에 비정상 상태의 Row가 존재할 경우, 다른 정상 상태의 Row로 치환하는 기능을 의미한다. Row는 메모리 칩 내부의 최소 저장 단위를 의미한다.

{{< table caption="[Table 7] NVIDIA DCGM Exporter Remapping Rows Metrics" >}}
| Metric | Description | Metric Type | Value Unit |
|---|---|---|---|
| `DCGM_FI_DEV_CORRECTABLE_REMAPPED_ROWS` | GPU Memory에서 Row Remapping을 통해서 수정이 가능한 Error의 갯수 | Counter | |
| `DCGM_FI_DEV_UNCORRECTABLE_REMAPPED_ROWS` | GPU Memory에서 Row Remapping을 통해서 수정이 불가능한 Error의 갯수 | Counter | |
| `DCGM_FI_DEV_ROW_REMAP_FAILURE` | GPU Memory에서 Row Remapping 수행 시도 실패 횟수 | Counter | |
{{</ table >}}

### 1.8. ECC Metrics

GPU Memroy의 ECC (Error-Correcting Code) Metric

{{< table caption="[Table 8] NVIDIA DCGM Exporter ECC Metrics" >}}
| Metric | Description | Metric Type | Value Unit |
|---|---|---|---|
| `DCGM_FI_DEV_ECC_SBE_VOL_TOTAL` | 휘발성 Single-Bit Error의 갯수 | Counter | |
| `DCGM_FI_DEV_ECC_DBE_VOL_TOTAL` | 휘발성 Double-Bit Error의 갯수 | Counter | |
| `DCGM_FI_DEV_ECC_SBE_AGG_TOTAL` | 영구적인 Single-Bit Error의 갯수 | Counter | |
| `DCGM_FI_DEV_ECC_DBE_AGG_TOTAL` | 영구적인 Double-Bit Error의 갯수 | Counter | |
{{</ table >}}

### 1.9. Retired Pages Metrics

GPU Memroy의 Retired Pages Metric. Retired Page는 비정상 상태의 Page를 삭제하여 GPU Memory의 안정성을 높이는 기능을 의미한다.

{{< table caption="[Table 9] NVIDIA DCGM Exporter Retired Pages Metrics" >}}
| Metric | Description | Metric Type | Value Unit |
|---|---|---|---|
| `DCGM_FI_DEV_RETIRED_SBE` | 휘발성 Single-Bit Error로 인해서 삭제된 Page의 갯수 | Counter | |
| `DCGM_FI_DEV_RETIRED_DBE` | 휘발성 Double-Bit Error로 인해서 삭제된 Page의 갯수 | Counter | |
| `DCGM_FI_DEV_RETIRED_PENDING` | 삭제 대기중인 Page의 갯수 | Counter | |
{{</ table >}}

### 1.10. Error and Violation Metrics

Error 및 Violation Metric

{{< table caption="[Table 10] NVIDIA DCGM Exporter Error and Violation Metrics" >}}
| Metric | Description | Metric Type | Value Unit |
|---|---|---|---|
| `DCGM_FI_DEV_XID_ERRORS` | 마지막에 발생한 XID Error Code | Gauge | |
| `DCGM_FI_DEV_POWER_VIOLATION` | 전력 제한에 의한 Throttling 시간 | Counter | us |
| `DCGM_FI_DEV_THERMAL_VIOLATION` | 온도 제한에 의한 Throttling 시간 | Counter | us |
| `DCGM_FI_DEV_SYNC_BOOST_VIOLATION` | Sync-Boost 제한에 의한 Throttling 시간 | Counter | us |
| `DCGM_FI_DEV_BOARD_LIMIT_VIOLATION` | 보드 제한에 의한 Throttling 시간 | Counter | us |
| `DCGM_FI_DEV_LOW_UTIL_VIOLATION` | 사용률 제한에 의한 Throttling 시간 | Counter | us |
| `DCGM_FI_DEV_RELIABILITY_VIOLATION` | 신뢰성 제한에 의한 Throttling 시간 | Counter | us |
{{</ table >}}

### 1.11. Power Metrics

소비 전력 Metric

{{< table caption="[Table 11] NVIDIA DCGM Exporter Power Metrics" >}}
| Metric | Description | Metric Type | Value Unit |
|---|---|---|---|
| `DCGM_FI_DEV_POWER_USAGE` | GPU 전력 소모량 | Gauge | Watt |
| `DCGM_FI_DEV_TOTAL_ENERGY_CONSUMPTION` | GPU Driver가 동작한 이후에 소모한 총 에너지량 | Counter | mJ |
{{</ table >}}

### 1.12. Temperature Metrics

온도 Metric

{{< table caption="[Table 12] NVIDIA DCGM Exporter Temperature Metrics" >}}
| Metric | Description | Metric Type | Value Unit |
|---|---|---|---|
| `DCGM_FI_DEV_GPU_TEMP` | GPU 온도 | Gauge | Celsius |
| `DCGM_FI_DEV_MEMORY_TEMP` | GPU Memory 온도 | Gauge | Celsius |
{{</ table >}}

### 1.13. License Metrics

License 상태 Metric

{{< table caption="[Table 13] NVIDIA DCGM Exporter License Metrics" >}}
| Metric | Description | Metric Type | Value |
|---|---|---|---|
| `DCGM_FI_DEV_VGPU_LICENSE_STATUS` | vGPU 기능 이용시 필요한 License 상태 | Gauge | 0 : vGPU License가 존재하지 않는 상태, 1 : vGPU License가 존재하는 상태 |
{{</ table >}}

## 2. Metric Label

{{< table caption="[Table 14] NVIDIA DCGM Exporter Metric Label" >}}
| Label | Description | Value | Note |
|---|---|---|---|
| `UUID` | GPU의 UUID | GPU-{UUID} | |
| `gpu` | GPU 번호 | 0, 1, 2, ... | |
| `device` | GPU Device Number | nvidia0, nvidia1, ... | |
| `Hostname` | GPU가 설치된 Host의 이름 | | |
| `modelName` | GPU 모델 이름 | | |
| `pci_bus_id` | GPU의 PCI Bus ID | | |
| `exported_namespace` | GPU를 이용하는 Pod가 위치하는 Namespace 이름 | | K8s Pod Metric |
| `exported_pod` | GPU를 이용하는 Pod 이름 | | K8s Pod Metric |
| `exported_container` | GPU를 이용하는 Container 이름 | | K8s Pod Metric |
| `DCGM_FI_DRIVER_VERSION` | GPU Driver 버전 | | MIG Metric |
| `GPU_I_PROFILE` | MIG Profile 이름 | | MIG Metric |
| `GPU_I_ID` | MIG Instance ID | | MIG Metric |
{{</ table >}}

* Note
  * K8s Pod Metric : K8s Pod에 할당된 GPU에 붙는 Label
  * MIG Metric : MIG (Multi-Instance GPU) 기능을 이용하여 생성된 GPU Instance에만 붙는 Label

## 3. 참조

* NVIDIA DCGM Exporter : [https://raw.githubusercontent.com/NVIDIA/dcgm-exporter/main/etc/dcp-metrics-included.csv](https://raw.githubusercontent.com/NVIDIA/dcgm-exporter/main/etc/dcp-metrics-included.csv)
* NVIDIA DCGM Exporter : [https://github.com/NVIDIA/dcgm-exporter/blob/main/deployment/templates/metrics-configmap.yaml](https://github.com/NVIDIA/dcgm-exporter/blob/main/deployment/templates/metrics-configmap.yaml)
* NVIDIA DCGM Exporter : [https://aws.amazon.com/blogs/machine-learning/enable-pod-based-gpu-metrics-in-amazon-cloudwatch/](https://aws.amazon.com/blogs/machine-learning/enable-pod-based-gpu-metrics-in-amazon-cloudwatch/)
* NVIDIA DCGM Exporter : [https://docs.nvidia.com/datacenter/cloud-native/gpu-telemetry/latest/dcgm-exporter.html](https://docs.nvidia.com/datacenter/cloud-native/gpu-telemetry/latest/dcgm-exporter.html)
* NVIDIA DCGM Exporter : [https://cloud.google.com/kubernetes-engine/docs/how-to/dcgm-metrics?hl=ko](https://cloud.google.com/kubernetes-engine/docs/how-to/dcgm-metrics?hl=ko)
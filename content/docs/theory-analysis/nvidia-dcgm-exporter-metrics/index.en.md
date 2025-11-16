---
title: "NVIDIA DCGM Exporter Metrics"
---

Organizes Metrics exposed by NVIDIA DCGM Exporter.

## 1. Metric List

### 1.1. Utilization Metrics

Represents GPU utilization rate

{{< table caption="[Table 1] NVIDIA DCGM Exporter Utilization Metrics" >}}
|| Metric | Description | Metric Type | Value Unit |
|---|---|---|---|
|| `DCGM_FI_DEV_GPU_UTIL` | Represents overall GPU utilization rate | Gauge | Percentage (0 ~ 100) |
|| `DCGM_FI_DEV_MEM_COPY_UTIL` | Ratio of time during which Data copy was performed to GPU Memory during a specific period | Gauge | Percentage (0 ~ 100) |
|| `DCGM_FI_DEV_ENC_UTIL` | Encoder utilization rate | Gauge | Percentage (0 ~ 1) |
|| `DCGM_FI_DEV_DEC_UTIL` | Decoder utilization rate | Gauge | Percentage (0 ~ 1) |
{{</ table >}}

### 1.2. Memory Metrics

Represents GPU Memory usage

{{< table caption="[Table 2] NVIDIA DCGM Exporter Memory Metrics" >}}
|| Metric | Description | Metric Type | Value Unit |
|---|---|---|---|
|| `DCGM_FI_DEV_FB_FREE` | Available GPU Memory capacity | Gauge | MB |
|| `DCGM_FI_DEV_FB_USED` | GPU Memory capacity in use | Gauge | MB |
{{</ table >}}

### 1.3. Clock Metrics

Represents Clock status of GPU and GPU Memory

{{< table caption="[Table 3] NVIDIA DCGM Exporter Clock Metrics" >}}
|| Metric | Description | Metric Type | Value Unit |
|---|---|---|---|
|| `DCGM_FI_DEV_SM_CLOCK` | SM (Streaming Multiprocessor) Clock | Gauge | MHz |
|| `DCGM_FI_DEV_MEM_CLOCK` | GPU Memory Clock | Gauge | MHz |
{{</ table >}}

### 1.4. NVLink Metrics

NVLink Metric

{{< table caption="[Table 4] NVIDIA DCGM Exporter NVLink Metrics" >}}
|| Metric | Description | Metric Type | Value Unit |
|---|---|---|---|
|| `DCGM_FI_DEV_NVLINK_CRC_FLIT_ERROR_COUNT_TOTAL` | Number of Flow-Control CRC Errors that occurred in NVLink | Counter | |
|| `DCGM_FI_DEV_NVLINK_CRC_DATA_ERROR_COUNT_TOTAL` | Number of Data CRC Errors that occurred in NVLink | Counter | |
|| `DCGM_FI_DEV_NVLINK_REPLAY_ERROR_COUNT_TOTAL` | Number of Retries that occurred in NVLink | Counter | |
|| `DCGM_FI_DEV_NVLINK_RECOVERY_ERROR_COUNT_TOTAL` | Number of Recoveries that occurred in NVLink | Counter | |
|| `DCGM_FI_DEV_NVLINK_BANDWIDTH_TOTAL` | NVLink Bandwidth Counter | Counter | |
|| `DCGM_FI_DEV_NVLINK_BANDWIDTH_L0` | Amount of Data sent and received through activated NVLink (Header & Payload) | Counter | Byte |
{{</ table >}}

### 1.5. PCIe Metrics

PCIe Metric

{{< table caption="[Table 5] NVIDIA DCGM Exporter PCIe Metrics" >}}
|| Metric | Description | Metric Type | Value Unit |
|---|---|---|---|
|| `DCGM_FI_DEV_PCIE_REPLAY_COUNTER` | Number of retries due to Packet transmission errors in PCIe | Counter | |
{{</ table >}}

### 1.6. DCP (Profiling) Metrics

Profiling Metric

{{< table caption="[Table 6] NVIDIA DCGM Exporter DCP (Profiling) Metrics" >}}
|| Metric | Description | Metric Type | Value Unit |
|---|---|---|---|
|| `DCGM_FI_PROF_GR_ENGINE_ACTIVE` | Ratio of time during which CUDA Cores inside SM (Streaming Multiprocessor) operated during a specific period | Gauge | Percentage (0 ~ 1) |
|| `DCGM_FI_PROF_PIPE_TENSOR_ACTIVE` | Ratio of time during which Tensor Core operated during a specific period | Gauge | Percentage (0 ~ 1) |
|| `DCGM_FI_PROF_DRAM_ACTIVE` | Ratio of time during which GPU Memory operated during a specific period | Gauge | Percentage (0 ~ 1) |
|| `DCGM_FI_PROF_PCIE_RX_BYTES` | Amount of Data GPU receives from PCIe (Header & Payload) | Gauge | Bytes per second |
|| `DCGM_FI_PROF_PCIE_TX_BYTES` | Amount of Data GPU sends to PCIe (Header & Payload) | Gauge | Bytes per second |
{{</ table >}}

### 1.7. Remapping Rows Metrics

Remapping Row Metric performed in GPU Memory. Remapping Row refers to the function of replacing abnormal Rows in GPU Memory with other normal Rows. Row refers to the minimum storage unit inside memory chips.

{{< table caption="[Table 7] NVIDIA DCGM Exporter Remapping Rows Metrics" >}}
|| Metric | Description | Metric Type | Value Unit |
|---|---|---|---|
|| `DCGM_FI_DEV_CORRECTABLE_REMAPPED_ROWS` | Number of Errors that can be corrected through Row Remapping in GPU Memory | Counter | |
|| `DCGM_FI_DEV_UNCORRECTABLE_REMAPPED_ROWS` | Number of Errors that cannot be corrected through Row Remapping in GPU Memory | Counter | |
|| `DCGM_FI_DEV_ROW_REMAP_FAILURE` | Number of failed attempts to perform Row Remapping in GPU Memory | Counter | |
{{</ table >}}

### 1.8. ECC Metrics

GPU Memory's ECC (Error-Correcting Code) Metric

{{< table caption="[Table 8] NVIDIA DCGM Exporter ECC Metrics" >}}
|| Metric | Description | Metric Type | Value Unit |
|---|---|---|---|
|| `DCGM_FI_DEV_ECC_SBE_VOL_TOTAL` | Number of volatile Single-Bit Errors | Counter | |
|| `DCGM_FI_DEV_ECC_DBE_VOL_TOTAL` | Number of volatile Double-Bit Errors | Counter | |
|| `DCGM_FI_DEV_ECC_SBE_AGG_TOTAL` | Number of permanent Single-Bit Errors | Counter | |
|| `DCGM_FI_DEV_ECC_DBE_AGG_TOTAL` | Number of permanent Double-Bit Errors | Counter | |
{{</ table >}}

### 1.9. Retired Pages Metrics

GPU Memory's Retired Pages Metric. Retired Page refers to the function of deleting abnormal Pages to improve GPU Memory stability.

{{< table caption="[Table 9] NVIDIA DCGM Exporter Retired Pages Metrics" >}}
|| Metric | Description | Metric Type | Value Unit |
|---|---|---|---|
|| `DCGM_FI_DEV_RETIRED_SBE` | Number of Pages deleted due to volatile Single-Bit Errors | Counter | |
|| `DCGM_FI_DEV_RETIRED_DBE` | Number of Pages deleted due to volatile Double-Bit Errors | Counter | |
|| `DCGM_FI_DEV_RETIRED_PENDING` | Number of Pages pending deletion | Counter | |
{{</ table >}}

### 1.10. Error and Violation Metrics

Error and Violation Metric

{{< table caption="[Table 10] NVIDIA DCGM Exporter Error and Violation Metrics" >}}
|| Metric | Description | Metric Type | Value Unit |
|---|---|---|---|
|| `DCGM_FI_DEV_XID_ERRORS` | Last occurred XID Error Code | Gauge | |
|| `DCGM_FI_DEV_POWER_VIOLATION` | Throttling time due to power limit | Counter | us |
|| `DCGM_FI_DEV_THERMAL_VIOLATION` | Throttling time due to temperature limit | Counter | us |
|| `DCGM_FI_DEV_SYNC_BOOST_VIOLATION` | Throttling time due to Sync-Boost limit | Counter | us |
|| `DCGM_FI_DEV_BOARD_LIMIT_VIOLATION` | Throttling time due to board limit | Counter | us |
|| `DCGM_FI_DEV_LOW_UTIL_VIOLATION` | Throttling time due to utilization limit | Counter | us |
|| `DCGM_FI_DEV_RELIABILITY_VIOLATION` | Throttling time due to reliability limit | Counter | us |
{{</ table >}}

### 1.11. Power Metrics

Power consumption Metric

{{< table caption="[Table 11] NVIDIA DCGM Exporter Power Metrics" >}}
|| Metric | Description | Metric Type | Value Unit |
|---|---|---|---|
|| `DCGM_FI_DEV_POWER_USAGE` | GPU power consumption | Gauge | Watt |
|| `DCGM_FI_DEV_TOTAL_ENERGY_CONSUMPTION` | Total energy consumed since GPU Driver started operating | Counter | mJ |
{{</ table >}}

### 1.12. Temperature Metrics

Temperature Metric

{{< table caption="[Table 12] NVIDIA DCGM Exporter Temperature Metrics" >}}
|| Metric | Description | Metric Type | Value Unit |
|---|---|---|---|
|| `DCGM_FI_DEV_GPU_TEMP` | GPU temperature | Gauge | Celsius |
|| `DCGM_FI_DEV_MEMORY_TEMP` | GPU Memory temperature | Gauge | Celsius |
{{</ table >}}

### 1.13. License Metrics

License status Metric

{{< table caption="[Table 13] NVIDIA DCGM Exporter License Metrics" >}}
|| Metric | Description | Metric Type | Value |
|---|---|---|---|
|| `DCGM_FI_DEV_VGPU_LICENSE_STATUS` | License status required when using vGPU functionality | Gauge | 0 : State where vGPU License does not exist, 1 : State where vGPU License exists |
{{</ table >}}

## 2. Metric Label

{{< table caption="[Table 14] NVIDIA DCGM Exporter Metric Label" >}}
|| Label | Description | Value | Note |
|---|---|---|---|
|| `UUID` | GPU's UUID | GPU-{UUID} | |
|| `gpu` | GPU number | 0, 1, 2, ... | |
|| `device` | GPU Device Number | nvidia0, nvidia1, ... | |
|| `Hostname` | Name of Host where GPU is installed | | |
|| `modelName` | GPU model name | | |
|| `pci_bus_id` | GPU's PCI Bus ID | | |
|| `exported_namespace` | Namespace name where Pod using GPU is located | | K8s Pod Metric |
|| `exported_pod` | Pod name using GPU | | K8s Pod Metric |
|| `exported_container` | Container name using GPU | | K8s Pod Metric |
|| `DCGM_FI_DRIVER_VERSION` | GPU Driver version | | MIG Metric |
|| `GPU_I_PROFILE` | MIG Profile name | | MIG Metric |
|| `GPU_I_ID` | MIG Instance ID | | MIG Metric |
{{</ table >}}

* Note
  * K8s Pod Metric : Label attached to GPU allocated to K8s Pod
  * MIG Metric : Label attached only to GPU Instance created using MIG (Multi-Instance GPU) functionality

## 3. References

* NVIDIA DCGM Exporter : [https://raw.githubusercontent.com/NVIDIA/dcgm-exporter/main/etc/dcp-metrics-included.csv](https://raw.githubusercontent.com/NVIDIA/dcgm-exporter/main/etc/dcp-metrics-included.csv)
* NVIDIA DCGM Exporter : [https://github.com/NVIDIA/dcgm-exporter/blob/main/deployment/templates/metrics-configmap.yaml](https://github.com/NVIDIA/dcgm-exporter/blob/main/deployment/templates/metrics-configmap.yaml)
* NVIDIA DCGM Exporter : [https://aws.amazon.com/blogs/machine-learning/enable-pod-based-gpu-metrics-in-amazon-cloudwatch/](https://aws.amazon.com/blogs/machine-learning/enable-pod-based-gpu-metrics-in-amazon-cloudwatch/)
* NVIDIA DCGM Exporter : [https://docs.nvidia.com/datacenter/cloud-native/gpu-telemetry/latest/dcgm-exporter.html](https://docs.nvidia.com/datacenter/cloud-native/gpu-telemetry/latest/dcgm-exporter.html)
* NVIDIA DCGM Exporter : [https://cloud.google.com/kubernetes-engine/docs/how-to/dcgm-metrics?hl=ko](https://cloud.google.com/kubernetes-engine/docs/how-to/dcgm-metrics?hl=ko)


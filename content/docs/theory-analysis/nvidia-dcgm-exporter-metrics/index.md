---
title: "NVIDIA DCGM Exporter Metrics"
---

NVIDIA DCGM Exporter가 노출하는 Metric을 정리한다.

## 1. NVIDIA DCGM Exporter Metrics

### 1.1. Metric 목록

| Metric | Description | Metric Type | Value Unit |
|---|---|---|---|
| `DCGM_FI_DEV_GPU_UTIL` | 전반적인 GPU 사용률를 의미 | Gauge | Percentage (0 ~ 100) |
| `DCGM_FI_DEV_ENC_UTIL` | NVENC (비디오 인코더)의 사용률 | Gauge | Percentage (0 ~ 1) |
| `DCGM_FI_PROF_GR_ENGINE_ACTIVE` | SM(Streaming Multiprocessor) 내부의 CUDA Core가 특정 주기 동안 동작한 시간 비율 | Gauge | Percentage (0 ~ 1) |
| `DCGM_FI_PROF_PIPE_TENSOR_ACTIVE` | Tensor Core가 특정 주기 동안 동작한 시간 비율 | Gauge | Percentage (0 ~ 1) |
| `DCGM_FI_DEV_FB_FREE` | 이용 가능한 GPU Memory 용량 | Gauge | MB |
| `DCGM_FI_DEV_FB_USED` | 이용중인 GPU Memory 용량 | Gauge | MB |
| `DCGM_FI_DEV_MEM_COPY_UTIL` | 특정 주기 동안 GPU Memory에 Data가 복사가 수행된 시간 비율 | Gauge | Percentage (0 ~ 100) |
| `DCGM_FI_PROF_DRAM_ACTIVE` | 특정 주기 동안 GPU Memory가 동작한 시간 비율 | Gauge | Percentage (??) |
| `DCGM_FI_DEV_SM_CLOCK` | SM (Streaming Multiprocessor)의 Clock | Gauge | MHz |
| `DCGM_FI_DEV_MEM_CLOCK` | GPU Memory Clock | Gauge | MHz |
| `DCGM_FI_DEV_CORRECTABLE_REMAPPED_ROWS` | GPU Memory에서 Row Remapping을 통해서 수정이 가능한 Error의 갯수 | Counter | |
| `DCGM_FI_DEV_UNCORRECTABLE_REMAPPED_ROWS` | GPU Memory에서 Row Remapping을 통해서 수정이 불가능한 Error의 갯수 | Counter | |
| `DCGM_FI_DEV_ROW_REMAP_FAILURE` | GPU Memory에서 Row Remapping 수행 시도 실패 횟수 | Counter | |
| `DCGM_FI_DEV_NVLINK_BANDWIDTH_TOTAL` | NVLink의 총 Bandwidth | Counter | |
| `DCGM_FI_PROF_PCIE_RX_BYTES` | GPU가 PCIe로부터 수신하는 Data (Header & Payload)양 | Gauge | Bytes per second |
| `DCGM_FI_PROF_PCIE_TX_BYTES` | GPU가 PCIe로 송신하는 Data (Header & Payload)양 | Gauge | Bytes per second |
| `DCGM_FI_DEV_PCIE_REPLAY_COUNTER` | PCIe에서 Packet 전송에 Error가 발생하여 재시도한 횟수 | Counter | |
| `DCGM_FI_DEV_XID_ERRORS` | 마지막에 발생한 XID Error Code | Gauge | |
| `DCGM_FI_DEV_GPU_TEMP` | GPU 온도 | Gauge | Celsius |
| `DCGM_FI_DEV_MEMORY_TEMP` | GPU Memory 온도 | Gauge | Celsius 양
| `DCGM_FI_DEV_POWER_USAGE` | GPU 전력 소모량 | Gauge | Watt |
| `DCGM_FI_DEV_TOTAL_ENERGY_CONSUMPTION` | GPU Driver가 동작한 이후에 소모한 총 에너지량 | Counter | mJ |
| `DCGM_FI_DEV_VGPU_LICENSE_STATUS` | vGPU 기능 이용시 필요한 License 상태 | Gauge | 0 : vGPU License가 존재하지 않는 상태, 1 : vGPU License가 존재하는 상태 |

### 1.2. Metric Label

### 1.3. MIG Metrics

## 2. 참조

* NVIDIA DCGM Exporter : [https://raw.githubusercontent.com/NVIDIA/dcgm-exporter/main/etc/dcp-metrics-included.csv](https://raw.githubusercontent.com/NVIDIA/dcgm-exporter/main/etc/dcp-metrics-included.csv)
* NVIDIA DCGM Exporter : [https://aws.amazon.com/blogs/machine-learning/enable-pod-based-gpu-metrics-in-amazon-cloudwatch/](https://aws.amazon.com/blogs/machine-learning/enable-pod-based-gpu-metrics-in-amazon-cloudwatch/)
* NVIDIA DCGM Exporter : [https://docs.nvidia.com/datacenter/cloud-native/gpu-telemetry/latest/dcgm-exporter.html](https://docs.nvidia.com/datacenter/cloud-native/gpu-telemetry/latest/dcgm-exporter.html)
* NVIDIA DCGM Exporter : [https://cloud.google.com/kubernetes-engine/docs/how-to/dcgm-metrics?hl=ko](https://cloud.google.com/kubernetes-engine/docs/how-to/dcgm-metrics?hl=ko)
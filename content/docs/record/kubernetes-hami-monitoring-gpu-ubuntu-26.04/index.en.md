---
title: Kubernetes HAMi Monitoring Setup / GPU Ubuntu 26.04 Environment
---

## 1. Installation and Runtime Environment

The installation and runtime environment is as follows. A Kubernetes Single-node Cluster and HAMi are assumed to be already running.

* `192.168.1.32` single Server (Control-plane + Worker combined)
* Ubuntu 26.04 LTS 64bit, root user
* Nvidia RTX 5060 Ti GPU 16GB
* Kubernetes v1.34.12 (kubeadm) + HAMi Chart 2.10.0
* Software
  * **Helm** : v3
  * **kube-prometheus-stack** : Chart 92.10.1
  * **DCGM Exporter** : Chart 4.8.4

## 2. kube-prometheus-stack Installation

```yaml {caption="[File 1] kps-values.yaml", linenos=table}
grafana:
  adminPassword: admin
  service:
    type: NodePort
    nodePort: 30300

prometheus:
  service:
    type: NodePort
    nodePort: 30900
  prometheusSpec:
    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false
    ruleSelectorNilUsesHelmValues: false
    probeSelectorNilUsesHelmValues: false
    scrapeConfigSelectorNilUsesHelmValues: false
```

This is the Values file for Chart installation. Grafana and Prometheus are exposed on NodePort 30300 and 30900, and `serviceMonitorSelectorNilUsesHelmValues: false` makes externally-created ServiceMonitors become Scrape Targets automatically.

```shell
$ helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
$ helm repo update
$ kubectl create namespace monitoring
$ helm install monitoring prometheus-community/kube-prometheus-stack \
    --version 92.10.1 \
    --namespace monitoring \
    -f kps-values.yaml
```

Add the Helm Repo and install the Chart under the `monitoring` Namespace.

```shell
$ kubectl -n monitoring get svc | grep -E 'grafana|prometheus-prometheus'
monitoring-grafana                     NodePort    10.100.42.91   <none>   80:30300/TCP      62s
monitoring-kube-prometheus-prometheus  NodePort    10.96.2.96     <none>   9090:30900/TCP    62s
```

Confirm that the Grafana and Prometheus Services are exposed on their NodePorts.

## 3. HAMi Exporter Integration

HAMi 2.x embeds its own Metrics Exporters. The `vgpu-monitor` Sidecar in the `hami-device-plugin` Pod exposes Host- and Container-level GPU Metrics on Port 9394, and the `hami-scheduler` Pod exposes cluster-wide vGPU allocation Metrics on Port 9395.

```yaml {caption="[File 2] hami-servicemonitor.yaml", linenos=table}
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: hami-device-plugin
  namespace: monitoring
spec:
  namespaceSelector:
    matchNames: [kube-system]
  selector:
    matchLabels:
      app.kubernetes.io/component: hami-device-plugin
      app.kubernetes.io/instance: hami
  endpoints:
    - port: monitorport
      honorLabels: true
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: hami-scheduler
  namespace: monitoring
spec:
  namespaceSelector:
    matchNames: [kube-system]
  selector:
    matchLabels:
      app.kubernetes.io/component: hami-scheduler
      app.kubernetes.io/instance: hami
  endpoints:
    - port: monitor
      honorLabels: true
```

Register two ServiceMonitors so Prometheus Operator scrapes both HAMi Exporter Services. `honorLabels: true` keeps the `namespace`/`pod`/`container` Labels HAMi embeds in each metric so the Prometheus Operator's default relabeling does not overwrite them with the scrape target Pod (`hami-device-plugin`). Without this option, a vLLM Pod's GPU usage is attributed to the `hami-device-plugin` Pod instead.

```shell
$ kubectl apply -f hami-servicemonitor.yaml
$ curl -s 'http://192.168.1.32:30900/api/v1/query?query=hami_container_device_memory_bytes' \
    | python3 -c '
import json,sys
for r in json.load(sys.stdin)["data"]["result"]:
    m=r["metric"]; print(f"{m[\"namespace\"]}/{m[\"pod\"]}/{m[\"container\"]} = {int(r[\"value\"][1])/2**30:.2f} GiB")'
default/qwen3-14b-awq-84dfd5c495-nw9rg/vllm = 12.08 GiB
```

Apply the ServiceMonitors and query per-Pod vGPU Memory usage through the Prometheus Query API. The vLLM Pod occupying ~12 GiB is surfaced directly.

## 4. DCGM Exporter Installation

While the HAMi Exporter is specialized for vGPU virtualization and per-Pod accounting, the **NVIDIA DCGM Exporter** exposes physical GPU hardware telemetry (Temperature, Power, SM/Memory Clock, ECC/XID Errors, etc.). The two Exporters are complementary and are installed together.

```yaml {caption="[File 3] dcgm-values.yaml", linenos=table}
serviceMonitor:
  enabled: true

extraEnv:
  - name: NVIDIA_VISIBLE_DEVICES
    value: "all"
```

`serviceMonitor.enabled: true` makes the Chart create its own ServiceMonitor. `NVIDIA_VISIBLE_DEVICES=all` lets DCGM Exporter access the physical GPU directly through nvidia-container-toolkit, bypassing HAMi's vGPU Slot allocation. Hardware telemetry can only be collected from the physical Device.

```shell
$ helm repo add gpu-helm-charts https://nvidia.github.io/dcgm-exporter/helm-charts
$ helm repo update
$ helm install dcgm-exporter gpu-helm-charts/dcgm-exporter \
    --version 4.8.4 \
    --namespace monitoring \
    -f dcgm-values.yaml
$ curl -s 'http://192.168.1.32:30900/api/v1/query?query=DCGM_FI_DEV_GPU_TEMP' \
    | python3 -c 'import json,sys;r=json.load(sys.stdin)["data"]["result"][0]; print(r["metric"]["device"], r["value"][1], "°C")'
nvidia0 30 °C
```

Installed as a DaemonSet with one Pod per GPU Node; Prometheus scrapes the DCGM Metrics.

## 5. Grafana Dashboard Addition

Register the official HAMi Dashboard and the NVIDIA DCGM Dashboard as ConfigMaps. The Grafana Sidecar watches ConfigMaps labeled `grafana_dashboard=1` and imports the dashboards automatically.

```shell
$ curl -sLO https://project-hami.io/grafana/gpu-dashboard.json
$ curl -sL https://grafana.com/api/dashboards/12239/revisions/latest/download \
    -o dcgm-dashboard.json
```

Download the **HAMi official Dashboard** (`project-hami.io`) and the **NVIDIA DCGM Dashboard** (Grafana.com ID 12239).

```shell
$ python3 <<'PY'
import json
for src, dst in [('gpu-dashboard.json','hami-fixed.json'),
                 ('dcgm-dashboard.json','dcgm-fixed.json')]:
    text = open(src).read()
    text = text.replace('${DS_PROMETHEUS}', 'Prometheus')
    d = json.loads(text)
    for k in ('__inputs','__requires','__elements'): d.pop(k, None)
    def fix(o):
        if isinstance(o, dict):
            for k,v in list(o.items()):
                if k == 'datasource' and isinstance(v, dict):
                    v['type']='prometheus'; v['uid']='prometheus'
            for v in o.values(): fix(v)
        elif isinstance(o, list):
            for i in o: fix(i)
    fix(d)
    json.dump(d, open(dst,'w'), indent=2)
PY
$ kubectl -n monitoring create cm hami-dashboard \
    --from-file=hami-dashboard.json=hami-fixed.json \
    --dry-run=client -o yaml \
  | kubectl label --local -f - grafana_dashboard=1 --dry-run=client -o yaml \
  | kubectl apply -f -
$ kubectl -n monitoring create cm dcgm-dashboard \
    --from-file=dcgm-dashboard.json=dcgm-fixed.json \
    --dry-run=client -o yaml \
  | kubectl label --local -f - grafana_dashboard=1 --dry-run=client -o yaml \
  | kubectl apply -f -
```

Replace the Datasource Variables (`${DS_PROMETHEUS}` etc.) in each Dashboard JSON with the installed Prometheus Datasource (`prometheus`), then apply them as ConfigMaps. Without the substitution, the Sidecar auto-import path cannot resolve the Datasource and Panels appear empty.

```shell
$ curl -s -u admin:admin 'http://192.168.1.32:30300/api/search' \
    | python3 -c '
import json,sys
for d in json.load(sys.stdin):
    if "hami" in d["title"].lower() or "dcgm" in d["title"].lower():
        print(d["title"], d["url"])'
HAMi vGPU metrics /d/hami-vgpu-metrics/hami-vgpu-metrics
NVIDIA DCGM Exporter Dashboard /d/Oxed_c6Wz/nvidia-dcgm-exporter-dashboard
```

Confirm both Dashboards are registered in Grafana. Open `http://192.168.1.32:30300` in a browser, log in as `admin/admin`, and open the `HAMi vGPU metrics` and `NVIDIA DCGM Exporter Dashboard` Dashboards to see GPU utilization, VRAM, per-Pod vGPU usage, Temperature, Power, and other Panels populated with real data.

## 6. References

* kube-prometheus-stack : [https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
* HAMi Grafana Dashboard : [https://project-hami.io/docs/userguide/monitoring/grafana-dashboard](https://project-hami.io/docs/userguide/monitoring/grafana-dashboard)
* NVIDIA DCGM Exporter : [https://github.com/NVIDIA/dcgm-exporter](https://github.com/NVIDIA/dcgm-exporter)
* NVIDIA DCGM Exporter Dashboard : [https://grafana.com/grafana/dashboards/12239-nvidia-dcgm-exporter-dashboard/](https://grafana.com/grafana/dashboards/12239-nvidia-dcgm-exporter-dashboard/)

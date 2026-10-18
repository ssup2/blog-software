---
title: Kubernetes Prometheus/Grafana + HAMi GPU Monitoring Installation / Ubuntu 26.04 Environment
---

## 1. Installation and Runtime Environment

The installation and runtime environment is as follows. A Kubernetes Single-node Cluster, HAMi, and a vLLM Pod are assumed to be already running.

* Ubuntu 26.04 LTS 64bit, root user
* Nvidia RTX 5060 Ti GPU 16GB
* Kubernetes v1.34.12 (kubeadm) + HAMi Chart 2.10.0
* Software
  * **Helm** : v3
  * **kube-prometheus-stack** : Chart 92.10.1 (Prometheus Operator v0.94.1)
  * **Grafana Dashboard** : hami-vgpu-dashboard (grafana.com ID 21833)

## 2. kube-prometheus-stack Installation

```shell
$ helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
$ helm repo update
```

**kube-prometheus-stack** is a Package that bundles the Prometheus Operator, Prometheus, Alertmanager, Grafana, kube-state-metrics, and node-exporter into a single Helm Chart. The Prometheus Operator watches ServiceMonitor/PodMonitor CRDs and manages Scrape Targets declaratively.

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

This is the Values file for Chart installation. The main items are as follows.

* `grafana.service.nodePort: 30300` : Expose Grafana at NodePort 30300.
* `prometheus.service.nodePort: 30900` : Expose Prometheus at NodePort 30900.
* `prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues: false` : By Default, Prometheus only selects ServiceMonitors tagged with the Chart Release Label (`release: monitoring`). Setting this to `false` makes Prometheus select every ServiceMonitor in a Namespace, so externally-created ServiceMonitors become Scrape Targets automatically. The `podMonitor`, `rule`, `probe`, and `scrapeConfig` entries below have the same meaning.

```shell
$ kubectl create namespace monitoring
$ helm install monitoring prometheus-community/kube-prometheus-stack \
    --version 92.10.1 \
    --namespace monitoring \
    -f kps-values.yaml
```

Install the Chart. The Prometheus Operator, Prometheus, Alertmanager, Grafana, and the exporters are deployed together under the `monitoring` Namespace.

```shell
$ kubectl -n monitoring get pods
NAME                                                     READY   STATUS    RESTARTS   AGE
alertmanager-monitoring-kube-prometheus-alertmanager-0   2/2     Running   0          52s
monitoring-grafana-5bdd67849c-ckl2h                      3/3     Running   0          62s
monitoring-kube-prometheus-operator-7c5bf754c4-g7wc9     1/1     Running   0          62s
monitoring-kube-state-metrics-7b5bd68446-tcjxs           1/1     Running   0          62s
monitoring-prometheus-node-exporter-n7vsj                1/1     Running   0          62s
prometheus-monitoring-kube-prometheus-prometheus-0       2/2     Running   0          52s
$ kubectl -n monitoring get svc | grep -E 'grafana|prometheus'
monitoring-grafana                     NodePort    10.100.42.91   <none>   80:30300/TCP                    62s
monitoring-kube-prometheus-prometheus  NodePort    10.96.2.96     <none>   9090:30900/TCP,8080:30228/TCP   62s
```

Verify that all Component Pods and Services are up and that the Grafana/Prometheus Services are exposed on NodePort 30300 and 30900 respectively.

## 3. HAMi Exporter and ServiceMonitor

HAMi 2.x embeds its own vGPU/GPU Metrics Exporters without requiring additional installation. The `hami-device-plugin` Pod runs a **`vgpu-monitor`** Sidecar Container that exposes Host- and Container-level GPU utilization and Memory on Port 9394, and the `hami-scheduler` Pod runs a **`vgpu-scheduler-extender`** Container that exposes cluster-wide vGPU allocation state on Port 9395. GPU usage of vLLM Pods can be collected without installing a separate DCGM Exporter.

```shell
$ kubectl -n kube-system get svc -l app.kubernetes.io/instance=hami
NAME                         TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)                         AGE
hami-device-plugin-monitor   NodePort   10.106.231.202  <none>        31992:31992/TCP                 14h
hami-scheduler               NodePort   10.97.57.101    <none>        443:31998/TCP,31993:31993/TCP   14h
```

Check the two Services created at HAMi install time. The one whose name ends with `monitor` is the Metrics endpoint.

```shell
$ curl -s http://192.168.1.32:31992/metrics | grep -E '^# HELP hami_(host|container)' | head -6
# HELP hami_container_device_memory_bytes Container device memory usage in bytes
# HELP hami_container_device_utilization_ratio Container device SM utilization ratio
# HELP hami_container_last_kernel_elapsed_seconds Seconds since last kernel execution in container
# HELP hami_host_gpu_memory_controller_utilization_ratio GPU memory controller utilization ratio (0-100)
# HELP hami_host_gpu_memory_used_bytes GPU device memory usage in bytes
# HELP hami_host_gpu_utilization_ratio GPU core utilization ratio (0-100)
```

A sample of the Metrics exposed by `hami-device-plugin-monitor`. `hami_host_*` captures the physical GPU state of the Host, while `hami_container_*` captures the state of each Container that is using a vGPU.

```yaml {caption="[File 2] hami-servicemonitor.yaml", linenos=table}
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: hami-device-plugin
  namespace: monitoring
  labels:
    release: monitoring
spec:
  namespaceSelector:
    matchNames:
      - kube-system
  selector:
    matchLabels:
      app.kubernetes.io/component: hami-device-plugin
      app.kubernetes.io/instance: hami
  endpoints:
    - port: monitorport
      path: /metrics
      interval: 15s
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: hami-scheduler
  namespace: monitoring
  labels:
    release: monitoring
spec:
  namespaceSelector:
    matchNames:
      - kube-system
  selector:
    matchLabels:
      app.kubernetes.io/component: hami-scheduler
      app.kubernetes.io/instance: hami
  endpoints:
    - port: monitor
      path: /metrics
      interval: 15s
```

Create two **ServiceMonitors** so that Prometheus Scrapes both HAMi Services. `namespaceSelector` points to the Namespace where the Target Services live (`kube-system`), and `selector.matchLabels` matches the Service Labels. `endpoints.port` is specified by Service Port name (`monitorport`, `monitor`).

```shell
$ kubectl apply -f hami-servicemonitor.yaml
servicemonitor.monitoring.coreos.com/hami-device-plugin created
servicemonitor.monitoring.coreos.com/hami-scheduler created
```

Apply the ServiceMonitors. The Prometheus Operator picks them up and adds Scrape Jobs to Prometheus Config immediately.

```shell
$ curl -s 'http://192.168.1.32:30900/api/v1/targets?state=active' \
    | python3 -c 'import json,sys;d=json.load(sys.stdin); [print(t["scrapePool"], t["health"], t["scrapeUrl"]) for t in d["data"]["activeTargets"] if "hami" in t["scrapePool"]]'
serviceMonitor/monitoring/hami-device-plugin/0  up  http://10.244.0.5:9394/metrics
serviceMonitor/monitoring/hami-scheduler/0  up  http://10.244.0.6:9395/metrics
```

Confirm via Prometheus's `/api/v1/targets` Endpoint that both HAMi Scrape Targets are in the `up` state.

```shell
$ curl -s 'http://192.168.1.32:30900/api/v1/query?query=hami_host_gpu_memory_used_bytes' \
    | python3 -c 'import json,sys;r=json.load(sys.stdin)["data"]["result"][0]; print(r["metric"]["device_type"], "used=", int(r["value"][1])/2**30, "GiB")'
NVIDIA-NVIDIA GeForce RTX 5060 Ti used= 13.360000610351562 GiB
```

Query current VRAM usage through the Prometheus Query API. The ~13.4 GiB occupied by the vLLM Pod is surfaced directly as a number.

## 4. Grafana Dashboard Addition

Import [Grafana.com Dashboard 21833 `hami-vgpu-dashboard`](https://grafana.com/grafana/dashboards/21833-hami-vgpu-dashboard/). Replace the Dashboard JSON's Datasource Variable `${DS_ALL}` with `Prometheus` so the existing Prometheus Datasource is used, then hand the result to Grafana as a ConfigMap for Sidecar auto-import.

```shell
$ curl -sL 'https://grafana.com/api/dashboards/21833/revisions/2/download' -o hami-dashboard.json
$ python3 <<'PY'
import json
with open('hami-dashboard.json') as f: text = f.read()
text = text.replace('${DS_ALL}', 'Prometheus')
d = json.loads(text)
for k in ('__inputs','__requires','__elements'): d.pop(k, None)
def fix(o):
    if isinstance(o, dict):
        for k,v in list(o.items()):
            if k == 'datasource' and isinstance(v, dict):
                v['type']='prometheus'; v['uid']='prometheus'
            fix(v)
    elif isinstance(o, list):
        for i in o: fix(i)
fix(d)
json.dump(d, open('hami-dashboard-fixed.json','w'), indent=2)
PY
$ kubectl -n monitoring create cm hami-dashboard \
    --from-file=hami-dashboard.json=hami-dashboard-fixed.json \
    --dry-run=client -o yaml \
  | kubectl label --local -f - grafana_dashboard=1 --dry-run=client -o yaml \
  | kubectl apply -f -
configmap/hami-dashboard created
```

Rewrite the Dashboard JSON and apply it as a ConfigMap. Two key changes are made. The `${DS_ALL}` Variable prompts the user to pick a Datasource at Grafana Import time, but the Sidecar auto-import path cannot make that choice, so it is replaced with the Datasource name `Prometheus`. In addition, the `datasource` Field on each Panel is set with an explicit UID (`prometheus`) so Grafana resolves the Datasource immediately. The Grafana Sidecar watches ConfigMaps tagged with the Label `grafana_dashboard=1` and registers the Dashboard into Grafana automatically.

```shell
$ kubectl -n monitoring logs deploy/monitoring-grafana -c grafana-sc-dashboard --tail=5 | grep hami
{"time": "2026-10-18T04:28:55.895011+00:00", "level": "INFO", "msg": "Writing /tmp/dashboards/hami-dashboard.json (ascii)"}
{"time": "2026-10-18T04:28:55.932181+00:00", "level": "INFO", "msg": "None sent to http://localhost:3000/api/admin/provisioning/dashboards/reload. Response: 200 OK {\"message\":\"Dashboards config reloaded\"}"}
$ curl -s -u admin:admin 'http://192.168.1.32:30300/api/search?query=hami' \
    | python3 -c 'import json,sys;[print(d["title"],d["url"]) for d in json.load(sys.stdin)]'
hami-vgpu-dashboard /d/Oxed_c6Wz21/hami-vgpu-dashboard
```

Check the Sidecar Log showing the Dashboard was written and that the Grafana API accepted the reload request. Also confirm via `/api/search` that the Dashboard is registered in Grafana. Open `http://192.168.1.32:30300` in a browser, log in as `admin/admin`, and open `hami-vgpu-dashboard` from the Dashboards menu on the left to see Panels for GPU utilization, vGPU Memory allocation, and per-Pod usage.

The Dashboard contains both **HAMi Metric** (`hami_*`) based Panels and **NVIDIA DCGM Exporter Metric** (`DCGM_*`) based Panels. Since this post does not add a DCGM Exporter, the DCGM Panels display "No data", while the core Panels for GPU utilization, VRAM, and vGPU allocation work from HAMi Metrics alone.

## 5. References

* kube-prometheus-stack : [https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
* Prometheus Operator ServiceMonitor : [https://prometheus-operator.dev/docs/getting-started/design/#servicemonitor](https://prometheus-operator.dev/docs/getting-started/design/#servicemonitor)
* HAMi Monitoring : [https://github.com/Project-HAMi/HAMi/blob/master/docs/dashboard.md](https://github.com/Project-HAMi/HAMi/blob/master/docs/dashboard.md)
* Grafana Dashboard hami-vgpu-dashboard : [https://grafana.com/grafana/dashboards/21833-hami-vgpu-dashboard/](https://grafana.com/grafana/dashboards/21833-hami-vgpu-dashboard/)

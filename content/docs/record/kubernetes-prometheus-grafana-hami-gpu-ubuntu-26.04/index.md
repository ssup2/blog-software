---
title: Kubernetes Prometheus/Grafana + HAMi GPU 모니터링 설치 / Ubuntu 26.04 환경
---

## 1. 설치, 실행 환경

설치, 실행 환경은 다음과 같다. Kubernetes Single-node Cluster와 HAMi, vLLM Pod가 이미 구동 중인 상태를 전제로 한다.

* Ubuntu 26.04 LTS 64bit, root user
* Nvidia RTX 5060 Ti GPU 16GB
* Kubernetes v1.34.12 (kubeadm) + HAMi Chart 2.10.0
* Software
  * **Helm** : v3
  * **kube-prometheus-stack** : Chart 92.10.1 (Prometheus Operator v0.94.1)
  * **DCGM Exporter** : Chart 4.8.4 (App 4.8.4)
  * **Grafana Dashboard** : HAMi 공식 vGPU Metrics Dashboard, NVIDIA DCGM Exporter Dashboard (grafana.com ID 12239)

## 2. kube-prometheus-stack 설치

```shell
$ helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
$ helm repo update
```

**kube-prometheus-stack**은 Prometheus Operator, Prometheus, Alertmanager, Grafana, kube-state-metrics, node-exporter를 하나의 Helm Chart로 묶어 배포하는 Package다. Prometheus Operator가 ServiceMonitor/PodMonitor CRD를 Watch하여 Scrape Target을 선언적으로 관리한다.

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

Chart 설치용 Values 파일이다. 주요 항목은 다음과 같다.

* `grafana.service.nodePort: 30300` : Grafana를 NodePort 30300으로 노출한다.
* `prometheus.service.nodePort: 30900` : Prometheus를 NodePort 30900으로 노출한다.
* `prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues: false` : Default는 Chart Release Label (`release: monitoring`)이 붙은 ServiceMonitor만 선택한다. `false`로 바꾸면 Namespace 안의 모든 ServiceMonitor를 선택하여 외부 ServiceMonitor도 자동으로 Scrape 대상이 된다. 아래 `podMonitor`, `rule`, `probe`, `scrapeConfig`도 동일한 의미다.

```shell
$ kubectl create namespace monitoring
$ helm install monitoring prometheus-community/kube-prometheus-stack \
    --version 92.10.1 \
    --namespace monitoring \
    -f kps-values.yaml
```

Chart를 설치한다. `monitoring` Namespace 아래 Prometheus Operator, Prometheus, Alertmanager, Grafana, exporter들이 함께 Deploy된다.

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

Component Pod와 Service가 모두 뜨고 Grafana/Prometheus Service가 각각 NodePort 30300, 30900으로 노출된 것을 확인한다.

## 3. HAMi Exporter와 ServiceMonitor

HAMi 2.x는 추가 설치 없이 vGPU/GPU Metrics Exporter를 자체 포함하고 있다. `hami-device-plugin` Pod에는 **`vgpu-monitor`** Sidecar Container가 Port 9394로 Host·Container 단위 GPU 사용률과 Memory를 노출하고, `hami-scheduler` Pod에는 **`vgpu-scheduler-extender`** Container가 Port 9395로 Cluster 전체 vGPU 할당 현황을 노출한다. 별도 DCGM Exporter 설치 없이도 vLLM Pod의 GPU 사용 상태를 바로 수집할 수 있다.

```shell
$ kubectl -n kube-system get svc -l app.kubernetes.io/instance=hami
NAME                         TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)                         AGE
hami-device-plugin-monitor   NodePort   10.106.231.202  <none>        31992:31992/TCP                 14h
hami-scheduler               NodePort   10.97.57.101    <none>        443:31998/TCP,31993:31993/TCP   14h
```

HAMi 설치 시 함께 생성된 두 Service를 확인한다. Service 이름 뒤에 `monitor`가 붙은 쪽이 Metrics용이다.

```shell
$ curl -s http://192.168.1.32:31992/metrics | grep -E '^# HELP hami_(host|container)' | head -6
# HELP hami_container_device_memory_bytes Container device memory usage in bytes
# HELP hami_container_device_utilization_ratio Container device SM utilization ratio
# HELP hami_container_last_kernel_elapsed_seconds Seconds since last kernel execution in container
# HELP hami_host_gpu_memory_controller_utilization_ratio GPU memory controller utilization ratio (0-100)
# HELP hami_host_gpu_memory_used_bytes GPU device memory usage in bytes
# HELP hami_host_gpu_utilization_ratio GPU core utilization ratio (0-100)
```

`hami-device-plugin-monitor`가 노출하는 Metric 샘플이다. `hami_host_*`는 Host의 물리 GPU 상태를, `hami_container_*`는 vGPU를 사용 중인 각 Container의 상태를 담는다.

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
      honorLabels: true
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
      honorLabels: true
```

Prometheus가 두 HAMi Service를 Scrape하도록 **ServiceMonitor** 두 개를 생성한다. `namespaceSelector`는 Target Service가 있는 Namespace(`kube-system`)를 가리키고, `selector.matchLabels`는 Service의 Label과 일치시킨다. `endpoints.port`는 Service Port의 이름 (`monitorport`, `monitor`)으로 지정한다.

`honorLabels: true`는 HAMi가 Metric에 심어 보낸 `namespace`/`pod`/`container` Label을 Prometheus Operator의 Default Relabeling이 Scrape 대상인 `hami-device-plugin` Pod의 값으로 덮어쓰지 않도록 유지시킨다. 이 Option이 없으면 vLLM Pod의 vGPU Memory 사용량이 `hami-device-plugin-xxxxx/vgpu-monitor`로 뒤바뀌어 Dashboard에서 실제 사용 Pod를 구분할 수 없다.

```shell
$ kubectl apply -f hami-servicemonitor.yaml
servicemonitor.monitoring.coreos.com/hami-device-plugin created
servicemonitor.monitoring.coreos.com/hami-scheduler created
```

ServiceMonitor를 적용한다. Prometheus Operator가 바로 감지하여 Prometheus Config에 Scrape Job을 추가한다.

```shell
$ curl -s 'http://192.168.1.32:30900/api/v1/targets?state=active' \
    | python3 -c 'import json,sys;d=json.load(sys.stdin); [print(t["scrapePool"], t["health"], t["scrapeUrl"]) for t in d["data"]["activeTargets"] if "hami" in t["scrapePool"]]'
serviceMonitor/monitoring/hami-device-plugin/0  up  http://10.244.0.5:9394/metrics
serviceMonitor/monitoring/hami-scheduler/0  up  http://10.244.0.6:9395/metrics
```

Prometheus의 `/api/v1/targets` Endpoint로 두 HAMi Scrape Target이 `up` 상태인지 확인한다.

```shell
$ curl -s 'http://192.168.1.32:30900/api/v1/query?query=hami_container_device_memory_bytes' \
    | python3 -c '
import json,sys
for r in json.load(sys.stdin)["data"]["result"]:
    m=r["metric"]; print(f"{m[\"namespace\"]}/{m[\"pod\"]}/{m[\"container\"]} = {int(r[\"value\"][1])/2**30:.2f} GiB")'
default/qwen3-14b-awq-84dfd5c495-nw9rg/vllm = 12.08 GiB
```

Prometheus Query API로 현재 Pod 단위 VRAM 사용량을 조회한다. HAMi가 심어 보낸 `namespace`/`pod`/`container` Label이 그대로 유지되어 vLLM Pod가 ~12 GiB vGPU Memory를 점유하는 상태가 바로 노출된다.

## 4. Grafana Dashboard 추가

HAMi는 공식 Grafana Dashboard JSON을 자체 Website (`project-hami.io`)에서 호스팅한다. Grafana.com에 올라와 있는 `hami-vgpu-dashboard` (ID 21833, 2024-09 업로드)와 `hami-vgpu-metrics-dashboard` (ID 22043, 2024-10)는 HAMi 1.x 시절의 옛 Metric 이름 (`HostCoreUtilization`, `Device_memory_desc_of_container`, `nodeGPUOverview` 등)을 쓰기 때문에 HAMi 2.x에 적용하면 대부분 Panel이 "No data"로 뜬다. HAMi 2.10부터 Metric이 `hami_*` Prefix로 재명명되었고 (PR #2301), 공식 Dashboard는 HAMi 저장소에서 분리되어 Website 저장소에 통합되었다 (PR #3002, #3031). 2.x 환경에서는 `https://project-hami.io/grafana/gpu-dashboard.json`을 받아 쓰는 것이 올바른 경로다.

```shell
$ curl -sLO https://project-hami.io/grafana/gpu-dashboard.json
$ python3 -c 'import json; d=json.load(open("gpu-dashboard.json")); print(d["title"], "panels=", len(d["panels"]))'
HAMi vGPU metrics panels= 31
```

공식 Dashboard를 Download하고 Panel 개수를 확인한다. Cluster Overview, Physical GPUs, Scheduler Allocation, Workloads, Hardware Telemetry 5개 Section에 걸쳐 31개 Panel이 포함된다. Dashboard는 Datasource를 `${datasource}` Variable (type: datasource, query: prometheus)로 받으므로 Grafana가 기본 Prometheus Datasource를 자동으로 선택한다.

```shell
$ kubectl -n monitoring create cm hami-dashboard \
    --from-file=hami-dashboard.json=./gpu-dashboard.json \
    --dry-run=client -o yaml \
  | kubectl label --local -f - grafana_dashboard=1 --dry-run=client -o yaml \
  | kubectl apply -f -
configmap/hami-dashboard created
```

Dashboard JSON을 ConfigMap에 담아 적용한다. Grafana Sidecar는 `grafana_dashboard=1` Label이 붙은 ConfigMap을 Watch하여 Dashboard를 Grafana에 자동 등록한다.

```shell
$ kubectl -n monitoring logs deploy/monitoring-grafana -c grafana-sc-dashboard --tail=5 | grep hami
{"time": "...", "level": "INFO", "msg": "Writing /tmp/dashboards/hami-dashboard.json (ascii)"}
{"time": "...", "level": "INFO", "msg": "None sent to http://localhost:3000/api/admin/provisioning/dashboards/reload. Response: 200 OK {\"message\":\"Dashboards config reloaded\"}"}
$ curl -s -u admin:admin 'http://192.168.1.32:30300/api/search?query=HAMi' \
    | python3 -c 'import json,sys;[print(d["title"],d["url"]) for d in json.load(sys.stdin)]'
HAMi vGPU metrics /d/hami-vgpu-metrics/hami-vgpu-metrics
```

Sidecar Log에서 Dashboard가 Write되고 Grafana API에 Reload 요청이 성공한 것을 확인한다. `/api/search`로 Grafana에 Dashboard가 등록되었는지도 다시 확인한다. 브라우저에서 `http://192.168.1.32:30300` → `admin/admin` 로그인 후 좌측 Dashboards 메뉴에서 `HAMi vGPU metrics` Dashboard를 열면 Cluster 자원 현황, 물리 GPU 사용률·VRAM, Scheduler 할당량, Pod·Container 단위 vGPU 사용 Panel이 실데이터로 표시된다.

Dashboard는 선택적으로 **NVIDIA DCGM Exporter** Metric (`DCGM_FI_DEV_GPU_TEMP`, `DCGM_FI_DEV_POWER_USAGE`, `DCGM_FI_DEV_SM_CLOCK`, `DCGM_FI_DEV_XID_ERRORS`)도 참조한다. 아래 5·6절에서 DCGM Exporter까지 설치하면 Temperature·Power·SM Clock·XID Error Panel도 함께 채워져 Dashboard가 완전해진다.

## 5. DCGM Exporter 설치

HAMi Exporter가 vGPU 가상화·Pod 단위 Accounting에 특화되어 있다면, **NVIDIA DCGM Exporter**는 물리 GPU의 하드웨어 Telemetry (Temperature, Power, SM/Memory Clock, PCIe Throughput, ECC/XID Error 등) 를 노출한다. 두 Exporter는 서로 보완 관계로, 함께 설치하면 가상화 사용 현황과 하드웨어 Health를 모두 모니터링할 수 있다.

```shell
$ helm repo add gpu-helm-charts https://nvidia.github.io/dcgm-exporter/helm-charts
$ helm repo update
```

NVIDIA에서 공식 배포하는 Helm Chart Repo를 추가한다.

```yaml {caption="[File 3] dcgm-values.yaml", linenos=table}
serviceMonitor:
  enabled: true
  interval: 30s
  honorLabels: false
  additionalLabels:
    release: monitoring

extraEnv:
  - name: NVIDIA_VISIBLE_DEVICES
    value: "all"

tolerations:
  - key: node-role.kubernetes.io/control-plane
    operator: Exists
    effect: NoSchedule
```

Chart Values의 주요 항목은 다음과 같다.

* `serviceMonitor.enabled: true` : Chart가 자체적으로 ServiceMonitor를 생성한다. 별도 Manifest가 필요없다.
* `extraEnv.NVIDIA_VISIBLE_DEVICES: all` : DCGM Exporter가 HAMi의 vGPU Slot 할당을 거치지 않고 nvidia-container-toolkit을 통해 Host의 모든 물리 GPU에 직접 접근한다. HAMi가 할당하는 가상 Slot이 아닌 물리 Device를 봐야 하드웨어 Telemetry를 수집할 수 있다.
* `tolerations` : Control-plane Node에 걸린 Default Taint를 Tolerate한다. 본 Cluster는 이미 Taint를 제거해 두었으나 Chart Default 유지를 위해 그대로 둔다.

```shell
$ helm install dcgm-exporter gpu-helm-charts/dcgm-exporter \
    --version 4.8.4 \
    --namespace monitoring \
    -f dcgm-values.yaml
NAME: dcgm-exporter
LAST DEPLOYED: ...
NAMESPACE: monitoring
STATUS: deployed
```

DCGM Exporter를 설치한다. DaemonSet 형태로 GPU Node마다 Pod가 뜨며, Port 9400에서 Metric을 노출한다.

```shell
$ kubectl -n monitoring get pods -l app.kubernetes.io/name=dcgm-exporter -o wide
NAME                  READY   STATUS    RESTARTS   AGE   IP            NODE
dcgm-exporter-rgr94   1/1     Running   0          58s   10.244.0.17   gpu
$ curl -s 'http://192.168.1.32:30900/api/v1/targets?state=active' \
    | python3 -c '
import json,sys
for t in json.load(sys.stdin)["data"]["activeTargets"]:
    if "dcgm" in t["scrapePool"].lower(): print(t["scrapePool"], t["health"], t["scrapeUrl"])'
serviceMonitor/monitoring/dcgm-exporter/0 up http://10.244.0.17:9400/metrics
```

DCGM Exporter Pod가 Running 상태이고 Prometheus Target도 `up`인지 확인한다.

```shell
$ curl -s 'http://192.168.1.32:30900/api/v1/query?query=DCGM_FI_DEV_GPU_TEMP' \
    | python3 -c '
import json,sys
r = json.load(sys.stdin)["data"]["result"][0]
print(r["metric"]["device"], "temp=", r["value"][1], "°C")'
nvidia0 temp= 30 °C
$ curl -s 'http://192.168.1.32:30900/api/v1/query?query=DCGM_FI_DEV_POWER_USAGE' \
    | python3 -c '
import json,sys
r = json.load(sys.stdin)["data"]["result"][0]
print(r["metric"]["device"], "power=", r["value"][1], "W")'
nvidia0 power= 7.9 W
```

Prometheus Query API로 Temperature와 Power 사용량을 조회한다. 각각 30°C, 7.9W로 Idle 상태의 RTX 5060 Ti가 수집된다. DCGM Exporter 설치로 **4절의 HAMi Dashboard** 안에 있던 Temperature·Power·SM Clock·XID Error Panel이 "No data"에서 실측 값으로 채워진다.

## 6. NVIDIA DCGM Grafana Dashboard 추가

NVIDIA는 grafana.com에 **DCGM 전용 공식 Dashboard** (ID 12239, `NVIDIA DCGM Exporter Dashboard`) 를 공개하고 있다. HAMi Dashboard는 DCGM Metric 몇 개만 참조하는 반면 이 Dashboard는 Temperature, Power, SM Clock, Memory Clock, Framebuffer Usage, Tensor Core Activity 등 DCGM이 노출하는 Metric 전반을 Panel로 보여준다.

```shell
$ curl -sL 'https://grafana.com/api/dashboards/12239/revisions/latest/download' -o dcgm-dashboard.json
$ python3 <<'PY'
import json
with open('dcgm-dashboard.json') as f: text = f.read()
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
json.dump(d, open('dcgm-dashboard-fixed.json','w'), indent=2)
PY
$ kubectl -n monitoring create cm dcgm-dashboard \
    --from-file=dcgm-dashboard.json=dcgm-dashboard-fixed.json \
    --dry-run=client -o yaml \
  | kubectl label --local -f - grafana_dashboard=1 --dry-run=client -o yaml \
  | kubectl apply -f -
configmap/dcgm-dashboard created
```

Dashboard JSON의 `${DS_PROMETHEUS}` Variable을 `Prometheus`로 치환하고 각 Panel의 `datasource` Field에 Prometheus UID를 명시한 뒤 ConfigMap으로 적용한다. 4절의 HAMi Dashboard와 동일한 Sidecar 자동 Import 흐름을 따른다.

```shell
$ curl -s -u admin:admin 'http://192.168.1.32:30300/api/search?query=DCGM' \
    | python3 -c 'import json,sys;[print(d["title"],d["url"]) for d in json.load(sys.stdin)]'
NVIDIA DCGM Exporter Dashboard /d/Oxed_c6Wz/nvidia-dcgm-exporter-dashboard
```

Grafana에 Dashboard가 등록된 것을 확인한다. 브라우저에서 `http://192.168.1.32:30300` → `admin/admin` 로그인 후 좌측 Dashboards 메뉴에서 `NVIDIA DCGM Exporter Dashboard`를 열면 GPU Temperature, Power Usage, SM/Memory Clock, GPU Utilization, Framebuffer, Tensor Core 활용률 Panel이 모두 실데이터로 표시된다.

## 7. 참조

* kube-prometheus-stack : [https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
* Prometheus Operator ServiceMonitor : [https://prometheus-operator.dev/docs/getting-started/design/#servicemonitor](https://prometheus-operator.dev/docs/getting-started/design/#servicemonitor)
* HAMi Grafana Dashboard Docs : [https://project-hami.io/docs/userguide/monitoring/grafana-dashboard](https://project-hami.io/docs/userguide/monitoring/grafana-dashboard)
* HAMi Dashboard JSON : [https://project-hami.io/grafana/gpu-dashboard.json](https://project-hami.io/grafana/gpu-dashboard.json)
* NVIDIA DCGM Exporter : [https://github.com/NVIDIA/dcgm-exporter](https://github.com/NVIDIA/dcgm-exporter)
* NVIDIA DCGM Exporter Dashboard : [https://grafana.com/grafana/dashboards/12239-nvidia-dcgm-exporter-dashboard/](https://grafana.com/grafana/dashboards/12239-nvidia-dcgm-exporter-dashboard/)
* Prometheus honor_labels : [https://prometheus.io/docs/prometheus/latest/configuration/configuration/#scrape_config](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#scrape_config)

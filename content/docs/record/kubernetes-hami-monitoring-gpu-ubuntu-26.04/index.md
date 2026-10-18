---
title: Kubernetes HAMi Monitoring 구성 / GPU Ubuntu 26.04 환경
---

## 1. 설치, 실행 환경

설치, 실행 환경은 다음과 같다. Kubernetes Single-node Cluster와 HAMi가 이미 구동 중인 상태를 전제로 한다.

* `192.168.1.32` 단일 Server (Control-plane + Worker 겸용)
* Ubuntu 26.04 LTS 64bit, root user
* Nvidia RTX 5060 Ti GPU 16GB
* Kubernetes v1.34.12 (kubeadm) + HAMi Chart 2.10.0
* Software
  * **Helm** : v3
  * **kube-prometheus-stack** : Chart 92.10.1
  * **DCGM Exporter** : Chart 4.8.4

## 2. kube-prometheus-stack 설치

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

Chart 설치용 Values 파일이다. Grafana/Prometheus를 NodePort 30300·30900으로 노출하고, `serviceMonitorSelectorNilUsesHelmValues: false`로 외부에서 생성한 ServiceMonitor도 자동으로 Scrape 대상이 되게 한다.

```shell
$ helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
$ helm repo update
$ kubectl create namespace monitoring
$ helm install monitoring prometheus-community/kube-prometheus-stack \
    --version 92.10.1 \
    --namespace monitoring \
    -f kps-values.yaml
```

Helm Repo를 추가하고 `monitoring` Namespace에 Chart를 설치한다.

```shell
$ kubectl -n monitoring get svc | grep -E 'grafana|prometheus-prometheus'
monitoring-grafana                     NodePort    10.100.42.91   <none>   80:30300/TCP      62s
monitoring-kube-prometheus-prometheus  NodePort    10.96.2.96     <none>   9090:30900/TCP    62s
```

Grafana/Prometheus Service가 각 NodePort로 노출되었는지 확인한다.

## 3. HAMi Exporter 연동

HAMi 2.x는 Metrics Exporter를 자체 포함하고 Helm Chart에 ServiceMonitor Template도 들어 있다. HAMi 설치 시 `prometheus.enabled=true`를 지정하면 Chart가 `hami-device-plugin-metrics-monitor`, `hami-scheduler-metrics-monitor` ServiceMonitor를 자동 생성한다. 다만 Chart Template에는 `honorLabels` 설정이 없어서 그대로 두면 Prometheus Operator의 Default Relabeling이 Metric에 심어진 `namespace`/`pod`/`container` Label을 Scrape 대상 Pod(`hami-device-plugin`)의 값으로 덮어쓰고 vLLM Pod 단위 사용량이 보이지 않는다.

```shell
$ helm upgrade hami hami-charts/hami --version 2.10.0 \
    --reuse-values \
    --set prometheus.enabled=true \
    -n kube-system
Release "hami" has been upgraded. Happy Helming!
$ kubectl -n kube-system get servicemonitor
NAME                                 AGE
hami-device-plugin-metrics-monitor   7s
hami-scheduler-metrics-monitor       7s
```

HAMi Chart를 Upgrade하여 ServiceMonitor를 생성한다. HAMi 설치 시점에 `--set prometheus.enabled=true`를 미리 넣었다면 이 단계는 생략해도 된다.

```shell
$ kubectl -n kube-system patch servicemonitor hami-device-plugin-metrics-monitor \
    --type=json -p='[{"op":"add","path":"/spec/endpoints/0/honorLabels","value":true}]'
$ kubectl -n kube-system patch servicemonitor hami-scheduler-metrics-monitor \
    --type=json -p='[{"op":"add","path":"/spec/endpoints/0/honorLabels","value":true}]'
```

생성된 두 ServiceMonitor에 `honorLabels: true`를 Patch로 주입한다. 이 Option은 Prometheus Scrape Config의 `honor_labels`를 활성화해 Metric 본문의 Label을 Target Discovery Label보다 우선시한다.

```shell
$ curl -s 'http://192.168.1.32:30900/api/v1/query?query=hami_container_device_memory_bytes' \
    | python3 -c '
import json,sys
for r in json.load(sys.stdin)["data"]["result"]:
    m=r["metric"]; print(f"{m[\"namespace\"]}/{m[\"pod\"]}/{m[\"container\"]} = {int(r[\"value\"][1])/2**30:.2f} GiB")'
default/qwen3-14b-awq-84dfd5c495-nw9rg/vllm = 12.08 GiB
```

Prometheus Query API로 Pod 단위 vGPU Memory 사용량이 vLLM Pod로 올바르게 attribute되는지 확인한다.

## 4. DCGM Exporter 설치

HAMi Exporter가 가상화·Pod 단위 Accounting에 특화되어 있다면, **NVIDIA DCGM Exporter**는 물리 GPU의 하드웨어 Telemetry (Temperature, Power, SM/Memory Clock, ECC/XID Error 등) 를 노출한다. 두 Exporter는 보완 관계로 함께 설치한다.

```yaml {caption="[File 2] dcgm-values.yaml", linenos=table}
serviceMonitor:
  enabled: true

extraEnv:
  - name: NVIDIA_VISIBLE_DEVICES
    value: "all"
```

`serviceMonitor.enabled: true`로 Chart가 자체 ServiceMonitor를 생성한다. `NVIDIA_VISIBLE_DEVICES=all`은 HAMi의 vGPU Slot 할당을 거치지 않고 nvidia-container-toolkit을 통해 물리 GPU에 직접 접근하도록 한다. 하드웨어 Telemetry는 물리 Device를 봐야 수집된다.

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

DaemonSet 형태로 설치되어 GPU Node마다 Pod가 뜨고, Prometheus가 DCGM Metric을 Scrape한다.

## 5. Grafana Dashboard 추가

HAMi 공식 Dashboard와 NVIDIA DCGM Dashboard를 ConfigMap으로 등록한다. Grafana Sidecar가 `grafana_dashboard=1` Label이 붙은 ConfigMap을 Watch하여 Dashboard를 자동 Import한다.

```shell
$ curl -sLO https://project-hami.io/grafana/gpu-dashboard.json
$ curl -sL https://grafana.com/api/dashboards/12239/revisions/latest/download \
    -o dcgm-dashboard.json
```

**HAMi 공식 Dashboard** (`project-hami.io`) 와 **NVIDIA DCGM Dashboard** (Grafana.com ID 12239) 를 Download한다.

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

두 Dashboard JSON의 Datasource Variable (`${DS_PROMETHEUS}` 등) 을 설치된 Prometheus Datasource (`prometheus`) 로 치환한 뒤 ConfigMap으로 적용한다. Datasource를 치환하지 않으면 Sidecar 자동 Import 경로에서 Grafana가 Datasource를 Resolve하지 못해 Panel이 비어 보인다.

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

Grafana에 두 Dashboard가 등록된 것을 확인한다. 브라우저에서 `http://192.168.1.32:30300` → `admin/admin` 로그인 후 `HAMi vGPU metrics` 와 `NVIDIA DCGM Exporter Dashboard` 를 열면 GPU 사용률·VRAM·Pod별 vGPU 사용량·Temperature·Power 등 Panel이 실데이터로 표시된다.

## 6. 참조

* kube-prometheus-stack : [https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
* HAMi Grafana Dashboard : [https://project-hami.io/docs/userguide/monitoring/grafana-dashboard](https://project-hami.io/docs/userguide/monitoring/grafana-dashboard)
* NVIDIA DCGM Exporter : [https://github.com/NVIDIA/dcgm-exporter](https://github.com/NVIDIA/dcgm-exporter)
* NVIDIA DCGM Exporter Dashboard : [https://grafana.com/grafana/dashboards/12239-nvidia-dcgm-exporter-dashboard/](https://grafana.com/grafana/dashboards/12239-nvidia-dcgm-exporter-dashboard/)

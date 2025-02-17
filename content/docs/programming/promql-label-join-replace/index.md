---
title: PromQL Label Join, Replace
---

PromQL의 Label Join가 Label Replace 문법을 정리한다.

## 1. PromQL Label Join

```promql {caption="[SQL Syntax 1] PromQL Label Join"}
label-join(<Instant Vector>, <Dest Label>, <Seperator>, <Src Label>, <Src Label>, ...)

# --- example ---
label-join(node-memory-MemAvailable-bytes, "dest-label", "+", "job", "endpoint", "namespace")
```

Label Join은 기존 Label들의 값을 조합하여 **새로운 Label**을 생성하는 문법이다. [SQL Syntax 1]은 Label Join의 문법을 나타내고 있다. `Src Label`은 값을 가져오려는 Label을 나타내며 다수의 `Src Label`이 선택될 수 있다. `Seperator`는 가져온 Label 사이에 삽입되는 분리자를 의미한다. Empty String (`""`)으로도 설정할 수 있다. `Dest Label`은 `Src Label`과 `Seperator`로 구성된 값의 저장될 새로운 Label을 나타낸다.

```promql {caption="[Query 1] node-memory-MemAvailable-bytes"}
# --- query ---
node-memory-MemAvailable-bytes{}

# --- result ---
node-memory-MemAvailable-bytes{container="node-exporter", endpoint="metrics", instance="192.168.0.31:9100", job="node-exporter", namespace="monitoring", pod="prometheus-prometheus-node-exporter-lpqff", service="prometheus-prometheus-node-exporter"} 14897680384
node-memory-MemAvailable-bytes{container="node-exporter", endpoint="metrics", instance="192.168.0.32:9100", job="node-exporter", namespace="monitoring", pod="prometheus-prometheus-node-exporter-59wm5", service="prometheus-prometheus-node-exporter"} 6833418240
node-memory-MemAvailable-bytes{container="node-exporter", endpoint="metrics", instance="192.168.0.33:9100", job="node-exporter", namespace="monitoring", pod="prometheus-prometheus-node-exporter-9lzmv", service="prometheus-prometheus-node-exporter"} 9297317888
```

[Query 1]은 Label Join 예제를 위한 `node-memory-MemAvailable-bytes` Instant Vector Type의 Data를 보여주고 있다.

```promql {caption="[Query 2] node-memory-MemAvailable-bytes with Join", }
# --- query ---
label-join(node-memory-MemAvailable-bytes, "dest", "+", "job", "endpoint", "namespace")

# --- result ---
node-memory-MemAvailable-bytes{container="node-exporter", dest="node-exporter+metrics+monitoring", endpoint="metrics", instance="192.168.0.31:9100", job="node-exporter", namespace="monitoring", pod="prometheus-prometheus-node-exporter-lpqff", service="prometheus-prometheus-node-exporter"} 14864846848
node-memory-MemAvailable-bytes{container="node-exporter", dest="node-exporter+metrics+monitoring", endpoint="metrics", instance="192.168.0.32:9100", job="node-exporter", namespace="monitoring", pod="prometheus-prometheus-node-exporter-59wm5", service="prometheus-prometheus-node-exporter"} 6715412480
node-memory-MemAvailable-bytes{container="node-exporter", dest="node-exporter+metrics+monitoring", endpoint="metrics", instance="192.168.0.33:9100", job="node-exporter", namespace="monitoring", pod="prometheus-prometheus-node-exporter-9lzmv", service="prometheus-prometheus-node-exporter"} 9297317888
```

[Query 2]는 node-memory-MemAvailable-bytes를 이용한 Label Join의 예제를 나타내고 있다. `dest` Label이 추가된 것을 확인할 수 있고, `dest`의 값은 `job`, `endpoint`, `namespace` Label 값과 Seperator인 `+`으로 구성되어 있는것을 확인 할 수 있다.

## 2. PromQL Label Replace

```promql {caption="[SQL Syntax 2] PromQL Label Replace"}
label-replace(<Instant Vector>, <Dest Label>, <Replacement>, <Src Label>, <Regex>)

# --- example ---
label-replace(node-memory-MemAvailable-bytes, "dest", "$1", "job", "(.*)")
```

Label Join은 기존 Label의 값을 변경하여 **새로운 Label**을 생성하는 문법이다. [SQL Syntax 2]은 Label Replace의 문법을 나타내고 있다. `Src Label`은 값을 변경하려는 Label을 나타내며, `Regex`에는 `Src Label`에서 어떻게 값을 가져올지 정규식으로 설정한다. `Dest Label`은 변경한 값이 저장될 새로운 Label을 의미하며, `Replacement`에는 `Dest Label`에 `Src Label`에서 가져온 값을 어떻게 저장할지 설정한다.

```promql {caption="[Query 3] node-memory-MemAvailable-bytes with Replace", }
# --- query ---
label-replace(node-memory-MemAvailable-bytes, "dest", "$1-replace", "job", "(.*)")

# --- result ---
node-memory-MemAvailable-bytes{container="node-exporter", dest="node-exporter-replace", endpoint="metrics", instance="192.168.0.31:9100", job="node-exporter", namespace="monitoring", pod="prometheus-prometheus-node-exporter-lpqff", service="prometheus-prometheus-node-exporter"} 14864846848
node-memory-MemAvailable-bytes{container="node-exporter", dest="node-exporter-replace", endpoint="metrics", instance="192.168.0.32:9100", job="node-exporter", namespace="monitoring", pod="prometheus-prometheus-node-exporter-59wm5", service="prometheus-prometheus-node-exporter"} 6715412480
node-memory-MemAvailable-bytes{container="node-exporter", dest="node-exporter-replace", endpoint="metrics", instance="192.168.0.33:9100", job="node-exporter", namespace="monitoring", pod="prometheus-prometheus-node-exporter-9lzmv", service="prometheus-prometheus-node-exporter"} 9297317888
```

[Query 3]은 `node-memory-MemAvailable-bytes`를 이용한 Label Replace의 예제를 나타내고 있다. `dest` Label이 추가된 것을 확인 할 수 있고, `dest`의 값은 Regex 및 Replacement 문법에 따라서 `node-exporter` label의 값에 `-replace` 문자열이 더해진 값이 설정되는 것을 확인 할 수 있다.

## 3. 참조

* [https://prometheus.io/docs/prometheus/latest/querying/functions/#label-join](https://prometheus.io/docs/prometheus/latest/querying/functions/#label-join)
* [https://t3guild.com/2020/07/29/prometheus-promql/](https://t3guild.com/2020/07/29/prometheus-promql/)
* [https://devthomas.tistory.com/15](https://devthomas.tistory.com/15)

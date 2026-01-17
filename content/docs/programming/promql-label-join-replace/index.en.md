---
title: PromQL Label Join, Replace
---

This document summarizes PromQL Label Join and Label Replace syntax.

## 1. PromQL Label Join

```promql {caption="[SQL Syntax 1] PromQL Label Join"}
label-join(<Instant Vector>, <Dest Label>, <Seperator>, <Src Label>, <Src Label>, ...)

# --- example ---
label-join(node-memory-MemAvailable-bytes, "dest-label", "+", "job", "endpoint", "namespace")
```

Label Join is syntax that creates **new Labels** by combining values of existing Labels. [SQL Syntax 1] shows the syntax of Label Join. `Src Label` represents the Label from which to get values, and multiple `Src Labels` can be selected. `Seperator` means a separator inserted between retrieved Labels. It can also be set to an Empty String (`""`). `Dest Label` represents a new Label where values composed of `Src Label` and `Seperator` will be stored.

```promql {caption="[Query 1] node-memory-MemAvailable-bytes"}
# --- query ---
node-memory-MemAvailable-bytes{}

# --- result ---
node-memory-MemAvailable-bytes{container="node-exporter", endpoint="metrics", instance="192.168.0.31:9100", job="node-exporter", namespace="monitoring", pod="prometheus-prometheus-node-exporter-lpqff", service="prometheus-prometheus-node-exporter"} 14897680384
node-memory-MemAvailable-bytes{container="node-exporter", endpoint="metrics", instance="192.168.0.32:9100", job="node-exporter", namespace="monitoring", pod="prometheus-prometheus-node-exporter-59wm5", service="prometheus-prometheus-node-exporter"} 6833418240
node-memory-MemAvailable-bytes{container="node-exporter", endpoint="metrics", instance="192.168.0.33:9100", job="node-exporter", namespace="monitoring", pod="prometheus-prometheus-node-exporter-9lzmv", service="prometheus-prometheus-node-exporter"} 9297317888
```

[Query 1] shows Data of the `node-memory-MemAvailable-bytes` Instant Vector Type for the Label Join example.

```promql {caption="[Query 2] node-memory-MemAvailable-bytes with Join", }
# --- query ---
label-join(node-memory-MemAvailable-bytes, "dest", "+", "job", "endpoint", "namespace")

# --- result ---
node-memory-MemAvailable-bytes{container="node-exporter", dest="node-exporter+metrics+monitoring", endpoint="metrics", instance="192.168.0.31:9100", job="node-exporter", namespace="monitoring", pod="prometheus-prometheus-node-exporter-lpqff", service="prometheus-prometheus-node-exporter"} 14864846848
node-memory-MemAvailable-bytes{container="node-exporter", dest="node-exporter+metrics+monitoring", endpoint="metrics", instance="192.168.0.32:9100", job="node-exporter", namespace="monitoring", pod="prometheus-prometheus-node-exporter-59wm5", service="prometheus-prometheus-node-exporter"} 6715412480
node-memory-MemAvailable-bytes{container="node-exporter", dest="node-exporter+metrics+monitoring", endpoint="metrics", instance="192.168.0.33:9100", job="node-exporter", namespace="monitoring", pod="prometheus-prometheus-node-exporter-9lzmv", service="prometheus-prometheus-node-exporter"} 9297317888
```

[Query 2] shows an example of Label Join using node-memory-MemAvailable-bytes. You can see that the `dest` Label has been added, and you can see that the value of `dest` is composed of the `job`, `endpoint`, `namespace` Label values and the Seperator `+`.

## 2. PromQL Label Replace

```promql {caption="[SQL Syntax 2] PromQL Label Replace"}
label-replace(<Instant Vector>, <Dest Label>, <Replacement>, <Src Label>, <Regex>)

# --- example ---
label-replace(node-memory-MemAvailable-bytes, "dest", "$1", "job", "(.*)")
```

Label Join is syntax that creates **new Labels** by changing values of existing Labels. [SQL Syntax 2] shows the syntax of Label Replace. `Src Label` represents the Label whose value to change, and `Regex` is set as a regular expression for how to get values from `Src Label`. `Dest Label` means a new Label where the changed value will be stored, and `Replacement` sets how to store values retrieved from `Src Label` in `Dest Label`.

```promql {caption="[Query 3] node-memory-MemAvailable-bytes with Replace", }
# --- query ---
label-replace(node-memory-MemAvailable-bytes, "dest", "$1-replace", "job", "(.*)")

# --- result ---
node-memory-MemAvailable-bytes{container="node-exporter", dest="node-exporter-replace", endpoint="metrics", instance="192.168.0.31:9100", job="node-exporter", namespace="monitoring", pod="prometheus-prometheus-node-exporter-lpqff", service="prometheus-prometheus-node-exporter"} 14864846848
node-memory-MemAvailable-bytes{container="node-exporter", dest="node-exporter-replace", endpoint="metrics", instance="192.168.0.32:9100", job="node-exporter", namespace="monitoring", pod="prometheus-prometheus-node-exporter-59wm5", service="prometheus-prometheus-node-exporter"} 6715412480
node-memory-MemAvailable-bytes{container="node-exporter", dest="node-exporter-replace", endpoint="metrics", instance="192.168.0.33:9100", job="node-exporter", namespace="monitoring", pod="prometheus-prometheus-node-exporter-9lzmv", service="prometheus-prometheus-node-exporter"} 9297317888
```

[Query 3] shows an example of Label Replace using `node-memory-MemAvailable-bytes`. You can see that the `dest` Label has been added, and you can see that the value of `dest` is set to the value of the `node-exporter` label with the string `-replace` added according to Regex and Replacement syntax.

## 3. References

* [https://prometheus.io/docs/prometheus/latest/querying/functions/#label-join](https://prometheus.io/docs/prometheus/latest/querying/functions/#label-join)
* [https://t3guild.com/2020/07/29/prometheus-promql/](https://t3guild.com/2020/07/29/prometheus-promql/)
* [https://devthomas.tistory.com/15](https://devthomas.tistory.com/15)


---
title: Prometheus Metric Type
---

## 1. Prometheus Metric Type

Prometheus classifies Metrics into 4 types: **Counter**, **Gauge**, **Histogram**, and **Summary**, and each Type has functions or calculation methods that are mainly used with it.

### 1.1 Counter

```promql {caption="[Query 1] Counter Type Example"}
http_requests_total 1234

rate(http_requests_total[5m])
increase(http_requests_total[1h])
```

The Counter Type represents a monotonically increasing Metric. It is mainly used for Metrics that represent the total number of requests, the number of errors, the total throughput, and so on. Since the value of the Counter Type increases monotonically, calculating the amount of increase is the key point, and for this purpose the `rate()`, `irate()`, or `increase()` functions are mainly used to calculate the rate or amount of increase.

### 1.2 Gauge

```promql {caption="[Query 2] Gauge Type Example"}
memory_usage_bytes 654321

min(memory_usage_bytes)
max(memory_usage_bytes)
avg(memory_usage_bytes)
delta(memory_usage_bytes)
```

The Gauge Type represents a Metric that increases or decreases. It is mainly used for Metrics that represent measured values such as temperature and memory usage. Since the value of the Gauge Type can increase or decrease, calculating the current value, maximum value, minimum value, average value, and change is the key point, and for this purpose functions such as `min()`, `max()`, `avg()`, and `delta()` are mainly used to calculate the current, maximum, and minimum values.

### 1.3 Histogram

```promql {caption="[Query 3] Histogram Type Example"}
http_request_duration_seconds_bucket{le="0.1"} 1200
http_request_duration_seconds_bucket{le="0.5"} 3400
http_request_duration_seconds_bucket{le="1.0"} 4500
http_request_duration_seconds_bucket{le="+Inf"} 5000
http_request_duration_seconds_count 5000
http_request_duration_seconds_sum 750

# Calculate 95th percentile of request duration
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

The Histogram Type is a Metric that stores the distribution of values by dividing data into multiple Buckets. It is mainly used for Metrics that represent distributions such as response time, request size, and processing time. The Histogram Type has the `le` Label, which means **Lower or Equal**, and it represents the values contained in each Bucket. For example, `http_request_duration_seconds_bucket` in [Query 3] indicates that HTTP Request response times of 0.1 seconds or less occurred 1200 times, HTTP Request response times of 0.5 seconds or less occurred 3400 times, HTTP Request response times of 1 second or less occurred 4500 times, and HTTP Request response times above that occurred 5000 times. Quantiles are mainly calculated and used through the `histogram_quantile()` function.

### 1.4 Summary

```promql {caption="[Query 4] Summary Type Example"}
http_request_duration_seconds{quantile="0.5"} 0.2
http_request_duration_seconds{quantile="0.9"} 0.5
http_request_duration_seconds{quantile="0.99"} 0.7
http_request_duration_seconds_count 5000
http_request_duration_seconds_sum 750
```

The Summary Type is similar to the Histogram Type, but it is a Metric that stores pre-calculated quantiles. The Summary Type has the `quantile` Label, which represents the stored quantiles. For example, `http_request_duration_seconds` in [Query 4] indicates that the 0.5 quantile is 0.2 seconds, the 0.9 quantile is 0.5 seconds, and the 0.99 quantile is 0.7 seconds.

## 2. References

* Prometheus Metric Type : [https://prometheus.io/docs/concepts/metric_types/](https://prometheus.io/docs/concepts/metric_types/)
* Prometheus Metric Type : [https://prometheus.io/docs/tutorials/understanding_metric_types/](https://prometheus.io/docs/tutorials/understanding_metric_types/)
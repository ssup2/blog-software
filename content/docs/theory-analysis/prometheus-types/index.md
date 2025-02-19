---
title: Prometheus Metric Type
---

## 1. Prometheus Metric Type

Prometheus는 Metric을 **Counter**, **Gauge**, **Histogram**, **Summary** 4가지 타입으로 구분하며, 각 Type별로 주로 이용하는 함수나 계산 방법이 존재한다.

### 1.1 Counter

```promql {caption="[Query 1] Counter Type Example"}
http_requests_total 1234

rate(http_requests_total[5m])
increase(http_requests_total[1h])
```

Counter Type은 단조 증가하는 Metric을 나타내는 타입이다. 주로 총 요청 수, 오류 수, 총 처리량 등을 나타내는 Metric에 사용된다. Counter Type은 값이 단조 증가하기 때문에 증가량을 계산하는것이 핵심이며, 이를 위해서 주로 `rate()`, `irate()` 또는 `increase()` 함수를 사용해 증가율이나 증가량을 계산한다.

### 1.2 Gauge

```promql {caption="[Query 2] Gauge Type Example"}
memory_usage_bytes 654321

min(memory_usage_bytes)
max(memory_usage_bytes)
avg(memory_usage_bytes)
delta(memory_usage_bytes)
```

Gauge Type은 증가 또는 감소하는 Metric을 나타내는 타입이다. 주로 온도, 메모리 사용량과 같이 측정되는 값을 나타내는 Metric에 사용된다. Gauge Type은 값이 증가하거나 감소할 수 있기 때문에 현재값, 최대값, 최소값, 평균값, 변화량을 계산하는것이 핵심이며, 이를 위해서 주로 `min()`, `max()`, `avg()`, `delta()` 등의 함수를 사용해 현재, 최대, 최소 값을 계산한다.

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

Histogram Type은 데이터를 여러 Bucket으로 분할하여 값의 분포를 저장하는 Metric이다. 주로 응답 시간, 요청 크기, 처리 시간 등의 분포를 나타내는 Metric에 사용된다. Histogram Type에는 **Lower or Equal**를 의미하는 `le` Label이 존재하며, 이를 통해서 Bucket에 존재하는 값을 나타낸다. 예를 들어 [Query 3]에 존재하는 `http_request_duration_seconds_bucket`는 0.1초 이하의 HTTP Request 응답 시간이 1200번, 0.5초 이하의 HTTP Request 응답 시간이 3400번, 1초 이하의 HTTP Request 응답 시간이 4500번, 그 이상의 HTTP Request 응답 시간이 5000번 발생한 것을 나타낸다. 주로 `histogram_quantile()` 함수를 통해서 분위수를 계산하여 이용한다.

### 1.4 Summary

```promql {caption="[Query 4] Summary Type Example"}
http_request_duration_seconds{quantile="0.5"} 0.2
http_request_duration_seconds{quantile="0.9"} 0.5
http_request_duration_seconds{quantile="0.99"} 0.7
http_request_duration_seconds_count 5000
http_request_duration_seconds_sum 750
```

Summary Type은 Histogram Type과 유사하지만, 미리 계산된 분위수를 저장하는 Metric이다. Summary Type에는 `quantile` Label이 존재하며, 이를 통해서 저장된 분위수를 나타낸다. 예를 들어 [Query 4]에 존재하는 `http_request_duration_seconds`는 0.5 분위수가 0.2초, 0.9 분위수가 0.5초, 0.99 분위수가 0.7초인 것을 나타낸다.

## 2. 참고

* Prometheus Metric Type : [https://prometheus.io/docs/concepts/metric_types/](https://prometheus.io/docs/concepts/metric_types/)
* Prometheus Metric Type : [https://prometheus.io/docs/tutorials/understanding_metric_types/](https://prometheus.io/docs/tutorials/understanding_metric_types/)
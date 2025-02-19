---
title: PromQL Range Vector 증가 계산 함수
---

## 1. PromQL 증가 계산

PromQL에서는 Range Vector를 사용하여 증가량, 증가율 등을 계산할 수 있으며, 이를 위해 `increase()`, `rate()`, `irate()`, `changes()`, `delta()`, `idelta()`, `deriv()` 함수를 제공한다.

{{< table caption="[Table 1] 예제 데이터" >}}
| Timestamp | Value (http_requests_total) |
| --- | --- |
| 10:00 | 100 |
| 10:05 | 120 |
| 10:10 | 140 |
| 10:15 | 160 |
| 10:20 | 200 |
{{< /table >}}

[Table 1]은 각 시간에 대한 `http_requests_total` 값을 나타낸 예시 데이터를 나타내고 있다. [Table 1]의 데이터를 사용하여 각 함수의 결과를 실제로 계산하여, 각 함수가 어떻게 동작하는지 확인한다.

### 1. increase() 함수

```promql {caption="[Query 1] increase() Example"}
# --- Query at 10:20 ---
increase(http_requests_total[10m])

# --- Result ---
# 200 - 140 = 60
```

`increase()` 함수는 주어진 시간 범위에 대한 **증가량**을 계산하는 함수다. 주어진 Range Vector에 대한 최종 값과 초기 값의 차이를 계산하는 함수다. 주로 값이 누적되는 Counter 타입의 메트릭에 사용된다. [Query 1]에서 `10:20`에는 `200` 값을 가지고 있고, `10:15`에는 `160` 값을 가지고 있기 때문에 `200 - 160 = 40` 값을 반환한다.

### 2. rate() 함수

```promql {caption="[Query 2] rate() Example"}
# --- Query at 10:20 ---
rate(http_requests_total[10m])

# --- Result ---
# (200 - 140) / 10m = 60 / 600s = 0.1
```

`rate()` 함수는 주어진 시간 범위에 대한 **초당 증가율**을 계산하는 함수다. 주어진 Range Vector에 대한 최종 값과 초기 값의 차이를 계산하는 함수다. 주로 값이 누적되는 Counter 타입의 메트릭에 사용된다. [Query 2]에서 `10:20`에는 `200` 값을 가지고 있고, `10:15`에는 `160` 값을 가지고 있고, 초당 증가율이기 때문에 `(200 - 160) / 10m = 60 / 600s = 0.1` 값을 반환한다.

### 3. irate() 함수

```promql {caption="[Query 3] irate() Example"}
# --- Query at 10:20 ---
irate(http_requests_total[10m])

# --- Result ---
# (200 - 160) / 10m = 40 / 300s = 0.1333
```

`irate()` 함수는 주어진 시간 범위에 대한 **초당 증가율**을 계산하는 함수다. 주어진 Range Vector에 대한 최종 값과 바로 이전 값의 차이를 계산하는 함수다. `rate()` 함수와 유사하지만 `rate()` 함수는 최종 값과 초기 값의 차이를 계산하기 때문에 Range Vector의 시간 범위에 따라서 결과가 달라지지만, `irate()` 함수는 최종 값과 바로 이전 값의 차이를 계산하기 때문에 Range Vector의 시간 범위가 달라져도 언제나 동일한 결과를 반환한다. 이러한 특징때문에 `rate()` 함수는 전반적인 증가율을 보여주지만, `irate()` 함수는 급격한 증가율을 더 잘 보여준다.

[Query 3]에서 `10:20`에는 `200` 값을 가지고 있고, `10:15`에는 `160` 값을 가지고 있기 때문에 `(200 - 160) / 10m = 40 / 300s = 0.1333` 값을 반환한다. 주어진 Range Vector의 시간 범위가 10m이지만 최종 값의 바로 이전 값을 사용하여 계산하기 때문에 `10:10`의 값이 아니라 `10:15`의 값을 사용하여 계산한다.

### 4. changes() 함수

```promql {caption="[Query 4] changes() Example"}
# --- Query at 10:20 ---
changes(http_requests_total[10m])

# --- Result ---
# 140 -> 160 -> 200 = 3 (changes)
```

`changes()` 함수는 주어진 시간 범위에 대한 **변화 횟수**를 계산하는 함수다. 주어진 Range Vector에 대한 각 값의 변화 횟수를 계산하는 함수다. [Query 4]에서 `10:10`에는 `140` 값을 가지고 있고, `10:15`에는 `160` 값을 가지고 있고, `10:20`에는 `200` 값을 가지고 있기 때문에 3번 변화하였고 따라서 `3` 값을 반환한다.

### 5. delta() 함수

```promql {caption="[Query 5] delta() Example"}
# --- Query at 10:20 ---
delta(http_requests_total[10m])

# --- Result ---
# (200 - 140) / 2 = 60 / 2 = 30
```

`delta()` 함수는 주어진 시간 범위에 대한 **평균 증가량**을 계산하는 함수다. [Query 5]에서 `10:20`에는 `200` 값을 가지고 있고, `10:15`에는 `160` 값을 가지고 있고 2개의 구간이 있기 때문에 `(200 - 140) / 2 = 60 / 2 = 30` 값을 반환한다.

### 6. idelta() 함수

```promql {caption="[Query 6] idelta() Example"}
# --- Query at 10:20 ---
idelta(http_requests_total[10m])

# --- Result ---
# 200 - 160 = 40
```

`idelta()` 함수는 주어진 시간 범위에 대한 **마지막 구간의 증가량**을 계산하는 함수다. [Query 6]에서 `10:20`에는 `200` 값을 가지고 있고, `10:15`에는 `160` 값을 가지고 때문에 `200 - 160 = 40` 값을 반환한다. 주어진 Range Vector의 시간 범위가 10m이지만 최종 값의 바로 이전 값을 사용하여 계산하기 때문에 `10:10`의 값이 아니라 `10:15`의 값을 사용하여 계산한다.

### 7. deriv() 함수

```promql {caption="[Query 7] deriv() Example"}
# --- Query at 10:20 ---
deriv(http_requests_total[10m])

# --- Result ---
# simple linear regression = 2.67
```

`deriv()` 함수는 주어진 시간 범위에 대한 **선형 회귀 계수**를 계산하는 함수다. [Query 7]에서 `10:10`에는 `140` 값을 가지고 있고, `10:15`에는 `160` 값을 가지고 있고, `10:20`에는 `200` 값을 가지고 있고, 3개의 값에 대해서 선형 회귀 계수를 계산하여 `2.67` 값을 반환한다.

## 2. 참고

* PromQL Functions : [https://prometheus.io/docs/prometheus/latest/querying/functions/](https://prometheus.io/docs/prometheus/latest/querying/functions/)
* rate() vs irate() : [https://techannotation.wordpress.com/2021/07/19/irate-vs-rate-whatre-they-telling-you/](https://techannotation.wordpress.com/2021/07/19/irate-vs-rate-whatre-they-telling-you/)

---
title: PromQL Range Vector Increase Calculation Functions
---

## 1. PromQL Increase Calculation

PromQL can calculate increase amounts, increase rates, etc. using Range Vectors, and provides the functions `increase()`, `rate()`, `irate()`, `changes()`, `delta()`, `idelta()`, and `deriv()` for this purpose.

{{< table caption="[Table 1] Example Data" >}}
| Timestamp | Value (http_requests_total) |
| --- | --- |
| 10:00 | 100 |
| 10:05 | 120 |
| 10:10 | 140 |
| 10:15 | 160 |
| 10:20 | 200 |
{{< /table >}}

[Table 1] shows example data representing `http_requests_total` values for each time. We actually calculate the results of each function using the data from [Table 1] to see how each function works.

### 1. increase() function

```promql {caption="[Query 1] increase() Example"}
# --- Query at 10:20 ---
increase(http_requests_total[10m])

# --- Result ---
# 200 - 140 = 60
```

The `increase()` function calculates the **increase amount** for a given time range. It is a function that calculates the difference between the final value and the initial value of a given Range Vector. It is mainly used for Counter-type metrics where values accumulate. In [Query 1], since `10:20` has the value `200` and `10:15` has the value `160`, it returns the value `200 - 160 = 40`.

### 2. rate() function

```promql {caption="[Query 2] rate() Example"}
# --- Query at 10:20 ---
rate(http_requests_total[10m])

# --- Result ---
# (200 - 140) / 10m = 60 / 600s = 0.1
```

The `rate()` function calculates the **increase rate per second** for a given time range. It is a function that calculates the difference between the final value and the initial value of a given Range Vector. It is mainly used for Counter-type metrics where values accumulate. In [Query 2], since `10:20` has the value `200` and `10:15` has the value `160`, and it is an increase rate per second, it returns the value `(200 - 160) / 10m = 60 / 600s = 0.1`.

### 3. irate() function

```promql {caption="[Query 3] irate() Example"}
# --- Query at 10:20 ---
irate(http_requests_total[10m])

# --- Result ---
# (200 - 160) / 10m = 40 / 300s = 0.1333
```

The `irate()` function calculates the **increase rate per second** for a given time range. It is a function that calculates the difference between the final value and the immediately previous value of a given Range Vector. It is similar to the `rate()` function, but the `rate()` function calculates the difference between the final value and the initial value, so results differ depending on the time range of the Range Vector, while the `irate()` function calculates the difference between the final value and the immediately previous value, so it always returns the same result even if the time range of the Range Vector changes. Because of this characteristic, the `rate()` function shows overall increase rates, while the `irate()` function better shows sudden increase rates.

In [Query 3], since `10:20` has the value `200` and `10:15` has the value `160`, it returns the value `(200 - 160) / 10m = 40 / 300s = 0.1333`. Although the time range of the given Range Vector is 10m, it uses the value from `10:15` instead of `10:10` for calculation because it uses the immediately previous value of the final value.

### 4. changes() function

```promql {caption="[Query 4] changes() Example"}
# --- Query at 10:20 ---
changes(http_requests_total[10m])

# --- Result ---
# 140 -> 160 -> 200 = 3 (changes)
```

The `changes()` function calculates the **number of changes** for a given time range. It is a function that calculates the number of changes for each value of a given Range Vector. In [Query 4], since `10:10` has the value `140`, `10:15` has the value `160`, and `10:20` has the value `200`, it changed 3 times, so it returns the value `3`.

### 5. delta() function

```promql {caption="[Query 5] delta() Example"}
# --- Query at 10:20 ---
delta(http_requests_total[10m])

# --- Result ---
# (200 - 140) / 2 = 60 / 2 = 30
```

The `delta()` function calculates the **average increase amount** for a given time range. In [Query 5], since `10:20` has the value `200` and `10:15` has the value `160`, and there are 2 intervals, it returns the value `(200 - 140) / 2 = 60 / 2 = 30`.

### 6. idelta() function

```promql {caption="[Query 6] idelta() Example"}
# --- Query at 10:20 ---
idelta(http_requests_total[10m])

# --- Result ---
# 200 - 160 = 40
```

The `idelta()` function calculates the **increase amount of the last interval** for a given time range. In [Query 6], since `10:20` has the value `200` and `10:15` has the value `160`, it returns the value `200 - 160 = 40`. Although the time range of the given Range Vector is 10m, it uses the value from `10:15` instead of `10:10` for calculation because it uses the immediately previous value of the final value.

### 7. deriv() function

```promql {caption="[Query 7] deriv() Example"}
# --- Query at 10:20 ---
deriv(http_requests_total[10m])

# --- Result ---
# simple linear regression = 2.67
```

The `deriv()` function calculates the **linear regression coefficient** for a given time range. In [Query 7], since `10:10` has the value `140`, `10:15` has the value `160`, and `10:20` has the value `200`, it calculates the linear regression coefficient for 3 values and returns the value `2.67`.

## 2. References

* PromQL Functions : [https://prometheus.io/docs/prometheus/latest/querying/functions/](https://prometheus.io/docs/prometheus/latest/querying/functions/)
* rate() vs irate() : [https://techannotation.wordpress.com/2021/07/19/irate-vs-rate-whatre-they-telling-you/](https://techannotation.wordpress.com/2021/07/19/irate-vs-rate-whatre-they-telling-you/)


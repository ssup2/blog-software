---
title: PromQL Data Type
---

This document summarizes PromQL Data Types.

## 1. PromQL Data Type

PromQL has four Data Types: String, Scalar, Instant Vector, and Range Vector.

### 1.1. String

{{< figure caption="[Figure 1] String Type" src="images/promql-string-type.png" width="900px" >}}

String Type is a Data Type that represents strings, as the name suggests. It is expressed with `""` (double quotes). In [Figure 1], you can see that querying with the string `ssup2` is a String Type.

### 1.2. Scalar

{{< figure caption="[Figure 2] Scalar Type, Integer" src="images/promql-scalar-type1.png" width="900px" >}}

{{< figure caption="[Figure 3] Scalar Type, Float" src="images/promql-scalar-type2.png" width="900px" >}}

Scalar Type is a Data Type that represents values, as the name suggests. It can express both integers and real numbers. In [Figure 2], you can see that querying with the integer 10 is a Scalar Type. In [Figure 3], you can also see that querying with the real number `1.1` is a Scalar Type.

### 1.3. Instant Vector

{{< figure caption="[Figure 4] Instant Vector, node-memory-MemAvailable-bytes Graph" src="images/promql-instant-vector-type2.png" width="900px" >}}

Instant Vector Type is a Data Type that stores values for **a specific time (Timestamp)**. Therefore, Instant Vector Type can be expressed as a Graph. It can have multiple values for each time. [Figure 4] shows the Graph of `node-memory-MemAvailable-bytes` that stores the available Memory size of Nodes exposed by Node Exporter by time. Since it has 3 values for each time, 3 Graphs appear.

{{< figure caption="[Figure 5] Instant Vector, node-memory-MemAvailable-bytes" src="images/promql-instant-vector-type1.png" width="900px" >}}

When querying, Instant Vector Type outputs only **the value stored at the most recent time**, and to output values from previous times, you must specify previous times through the **offset** syntax. [Figure 5] shows the query results of `node-memory-MemAvailable-bytes`. Since 3 values are stored at the last time, you can see that all 3 values are output. The reason each value is distinguished at the same time is because the **Label** connected to each value is different. Labels are used to distinguish values and exist in **Key-value** format under `{}` (curly braces).

{{< figure caption="[Figure 6] Instant Vector, node-memory-MemAvailable-bytes Selector" src="images/promql-instant-vector-type3.png" width="900px" >}}

When you want to select and obtain only specific values among multiple values at a specific time, you can select Labels that exist in the values as **Selectors**. Selectors are also represented with `{}` (curly braces) in Queries. In [Figure 6], it shows an example of selecting only values where the Instance Label is `192.168.0.31:9100` among `node-memory-MemAvailable-bytes`. Selectors provide the following comparison operators.

* = : When values match
* != : When values do not match
* =~ : When regular expressions match
* !~ : When regular expressions do not match

#### 1.3.1. Cardinality

Labels exist in Key-value format, and the number of types of Values that Labels can have here means the Cardinality of the Label. In [Figure 5], all values have one Value `node-exporter` in the `container` Label. Therefore, the Cardinality of the `container` Label is 1. On the other hand, the `instance` Label has 3 Values: `192.168.0.31:9100`, `192.168.0.32:9100`, `192.168.0.33:9100`. Therefore, the Cardinality of the `Instance` Label is 3.

The Cardinality of Instant Vector Type means the number of values that can be had for each time. Since `node-memory-MemAvailable-bytes` in [Figure 5] has 3 values for each time, the Cardinality is also 3. The Cardinality of Instant Vector Type is determined according to the Cardinality of Labels. If only one Label with Cardinality 3 exists, the Cardinality of Instant Vector Type becomes 3, but if 2 Labels with Cardinality 3 exist, the Cardinality of Instant Vector Type becomes 9 (3*3).

A high Cardinality of Instant Vector Type means that the Data to be processed also increases, which increases the burden on Prometheus. Therefore, to reduce the burden on Prometheus, it is good to manage the Cardinality of Metrics and optimize Labels as needed to reduce Cardinality.

### 1.4. Range Vector

{{< figure caption="[Figure 7] Range Vector, node-memory-MemAvailable-bytes[1m]" src="images/promql-range-vector-type.png" width="900px" >}}

Range Vector Type is a Data Type that stores **all values** from **a specific time range** among Instant Vector Type values in **array** format. Range Vector Type can be obtained by attaching a **Range Selector** represented by `[]` (square brackets) to Instant Vector Type. Specify the length of the time range inside []. [Figure 7] shows values from the last 1 minute of `node-memory-MemAvailable-bytes`.

Since 2 values with the same Label exist during 1 minute, you can see that 2 values exist in array format in each row of [Figure 7]. Each value is expressed in the format `[value]@[collection time]`. If the time increases beyond 1 minute, the number of values included in each row also increases. Range Vector Type is mainly used when obtaining average values or increment values for a specific time range. This is because you can calculate the average of values stored in arrays to obtain average values, and use the difference of values stored in arrays to obtain increment values. Since Range Vector stores values in array format, it cannot be expressed in Graph format.

## 2. References

* [https://prometheus.io/docs/prometheus/latest/querying/basics/#expression-language-data-types](https://prometheus.io/docs/prometheus/latest/querying/basics/#expression-language-data-types)
* [https://devthomas.tistory.com/15](https://devthomas.tistory.com/15)
* [https://gurumee92.tistory.com/244](https://gurumee92.tistory.com/244)
* [https://www.robustperception.io/cardinality-is-key](https://www.robustperception.io/cardinality-is-key)


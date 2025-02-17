---
title: PromQL Data Type
---

PromQL의 Data Type을 정리한다.

## 1. PromQL Data Type

PromQL에는 String, Scalar, Instant Vector, Range Vector 4가지 Data Type이 존재한다.

### 1.1. String

{{< figure caption="[Figure 1] String Type" src="images/promql-string-type.png" width="900px" >}}

String Type은 의미 그대로 문자열을 나타내는 Data Type이다. `""(큰따옴표)`로 표현된다. [Figure 1]에서 `ssup2` 문자열로 질의시 String Type인걸 확인할 수 있다.

### 1.2. Scalar

{{< figure caption="[Figure 2] Scalar Type, Integer" src="images/promql-scalar-type1.png" width="900px" >}}

{{< figure caption="[Figure 3] Scalar Type, Float" src="images/promql-scalar-type2.png" width="900px" >}}

Scalar Type은 의미 그대로 값을 나타내는 Data Type이다. 정수, 실수 모두 표현할 수 있다. [Figure 2]에서 정수 10 질의시 Scalar Type인걸 확인할 수 있다. [Figure 3]에서 실수 `1.1` 질의시에도 Scalar Type인걸 확인할 수 있다.

### 1.3. Instant Vector

{{< figure caption="[Figure 4] Instant Vector, node-memory-MemAvailable-bytes Graph" src="images/promql-instant-vector-type2.png" width="900px" >}}

Instant Vector Type은 **특정 시간대(Timestamp)의** 값을 저장하고 있는 Data Type이다. 따라서 Instant Vector Type은 Graph로 표현이 가능하다. 각 시간별로 여러개의 값을 가질 수 있다. [Figure 4]는 Node Exporter가 노출하는 Node의 가용 Memory 크기를 시간별로 저장하고 있는 `node-memory-MemAvailable-bytes`의 Graph를 나타내고 있다. 각 시간별로 3개의 값을 가지고 있기 때문에 Graph도 3개가 나타난다.

{{< figure caption="[Figure 5] Instant Vector, node-memory-MemAvailable-bytes" src="images/promql-instant-vector-type1.png" width="900px" >}}

Instant Vector Type은 질의시에는 **가장 최근 시간에 저장된 값**만 출력되며, 이전 시간의 값을 출력하기 위해서는 **offset** 문법을 통해서 이전 시간을 지정해야 한다. [Figure 5]는 `node-memory-MemAvailable-bytes`의 질의 결과를 나타내고 있다. 마지막 시간에 3개의 값이 저장되어 있기 때문에 3개의 값이 모두 출력되는 것을 확인할 수 있다. 동일한 시간에 각 값이 구분되는 이유는 각 값에 연결된 **Label**이 다르기 때문이다. Label은 값을 구분하는데 이용되며 `{}(중괄호)`아래 **Key-value** 형태로 존재한다.

{{< figure caption="[Figure 6] Instant Vector, node-memory-MemAvailable-bytes Selector" src="images/promql-instant-vector-type3.png" width="900px" >}}

특정 시간의 다수의 값 중에서 특정 값만 선택하여 얻고 싶을때는 값에 존재하는 Label을 **Selector**로 선택하면 된다. Selector도 Query에 {}(중괄호)로 나타난다. [Figure 6]의 경우에는 `node-memory-MemAvailable-bytes`중에서 Instance Label에 `192.168.0.31:9100`인 값만 선택하는 예제를 나타내고 있다. Selector는 다음과 같은 비교문을 제공한다.

* = : 값이 일치하는 경우
* != : 값이 일치하지 않는 경우
* =~ : 정규표현식이 일치하는 경우
* !~ : 정규표현식이 일치하지 않는 경우

#### 1.3.1. Cardinality

Label은 Key-value 형태로 존재하는데 여기서 Label이 갖을수 있는 Value의 종류의 개수는 Label의 Cardinality를 의미한다. [Figure 5]에서 모든 값의 `container` Label에는 `node-exporter`라는 하나의 Value를 가지고 있다. 따라서 `container` Label의 Cardinality는 1이다. 반면 `instance` Label에는 `192.168.0.31:9100`, `192.168.0.32:9100`, `192.168.0.33:9100` 3개의 Value를 가지고 있다. 따라서 `Instance` Label의 Cardinality는 3이다.

Instant Vector Type의 Cardinality는 각 시간별로 갖을수 있는 값의 개수를 의미한다. [Figure 5]의 `node-memory-MemAvailable-bytes`는 각 시간별 3개의 값을 가지고 있기 때문에 Cardinality도 3이다. Instant Vector Type의 Cardinality는 Label의 Cardinality에 따라서 결정된다. 3의 Cardinality를 갖는 Label이 하나만 존재한다면 Instant Vector Type의 Cardinality는 3이 되지만, 3의 Cardinality를 Label이 2개 존재한다면 Instant Vector Type의 Cardinality는 9(3*3)가 된다.

Instant Vector Type의 Cardinality가 높다는 의미는, 처리해야할 Data도 증가한다는걸 의미하며 이는 Prometheus의 부담을 증가시킨다. 따라서 Prometheus의 부담을 덜기 위해서는 Metric의 Cardinality를 관리하고 필요에 따라서는 Label을 최적화하여 Cardinality를 줄이는 것이 좋다.

### 1.4. Range Vector

{{< figure caption="[Figure 7] Range Vector, node-memory-MemAvailable-bytes[1m]" src="images/promql-range-vector-type.png" width="900px" >}}

Range Vector Type은 Instant Vector Type의 값 중에서 **특정 시간대의 모든 값**들을 **배열** 형태로 저장하고 있는 Data Type이다. Range Vector Type은 Instant Vector Type에 `[](대괄호)`로 나타나는 **Range Selector**를 붙이면 얻을 수 있다. []안에는 시간대의 길이를 명시하면 된다. [Figure 7]은 `node-memory-MemAvailable-bytes`의 마지막 1분 동안의 값을 나타내고 있다.

1분 동안에 동일한 Label을 갖는 값이 2개가 존재하기 때문에 [Figure 7]의 각 행에 2개의 값이 배열 형태로 존재하는 것을 확인할 수 있다. 각 값의 형태는 `[값]@[수집 시간]` 형태로 표현된다. 시간이 1분에서 더 늘어난다면 각 행에 포함된는 값의 개수도 늘어나게 된다. Range Vector Type은 특정 시간대의 평균 값이나 증분 값을 얻을때 주로 이용된다. 평균 값을 얻을때는 배열로 저장된 값들의 평균을 구하면되고, 증분 값을 얻을때는 배열로 저장된 값들의 차이를 이용하면 되기 때문이다. Range Vector는 값을 배열 형태로 저장하고 있기 때문에 Graph 형태로 표현이 불가능하다.

## 2. 참조

* [https://prometheus.io/docs/prometheus/latest/querying/basics/#expression-language-data-types](https://prometheus.io/docs/prometheus/latest/querying/basics/#expression-language-data-types)
* [https://devthomas.tistory.com/15](https://devthomas.tistory.com/15)
* [https://gurumee92.tistory.com/244](https://gurumee92.tistory.com/244)
* [https://www.robustperception.io/cardinality-is-key](https://www.robustperception.io/cardinality-is-key)
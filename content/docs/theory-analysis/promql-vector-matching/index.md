---
title: PromQL Vector Matching
---

PromQL의 Vector Matching 문법을 정리한다.

## 1. PromQL Vector Matching

PromQL의 Vector Matching은 의미 그대로 두개의 Instant Vector Type의 Data를 Matching하여 연산시키는 문법이다. PromQL에서 가장 많이 이용되는 문법중 하나이다. Instant Vector Type에 존재하는 하나의 값을 어떻게 연산시키는지에 따라서 One-to-one Matching, One-to-many/Many-to-one Matching, Many-to-many Matching이 존재한다. 여기서 Matching은 값에 존재하는 **Label**을 기준으로 이루어진다.

### 1.1. One-to-one Vector Matching

One-to-one Vector Matching은 의미 그대로 Instant Vector Type에 존재하는 하나의 값을 다른 Instant Vector Type에 존재하는 하나의 값과 1:1로 Matching시켜 연산하는 문법이다. Matching시 모든 Label이 Matching되어야 하는 경우와 일부 Label만 Matching되는 경우로 나눌 수 있다.

```text {caption="[Instant Vector 1] Candy 1 Count"}
--- query ---
candy1-count{}

--- result ---
candy1-count{color="blue", size="big"} 1
candy1-count{color="red", size="medium"} 3
candy1-count{color="green", size="small"} 5
```

```text {caption="[Instant Vector 2] Ice 1 Count"}
--- query --- 
ice1-count{}

--- result ---
ice1-count{color="blue", size="big"} 2
ice1-count{color="red", size="medium"} 4
ice1-count{color="green", size="big"} 6
```

[Instant Vector 1]과 [Instant Vector 2]는 One-to-one Vector Matching 설명을 위해서 이용되는 가상의 Instant Vector Type의 Data인 candy1-count, ice1-count를 나타내고 있다.

#### 1.1.1. 모든 Label Matching

```text {caption="[SQL Syntax 1] One-to-one, 모든 Label Matching"}
[Instant Vector] [Op] [Instant Vector]

ex) candy1-count{} + ice1-count{}
ex) candy1-count{} * ice1-count{}
```

[SQL Syntax 1]은 One-to-one Vector Matching에서 모든 Label을 Matching 시키는 경우의 문법과 예제를 타나내고 있다.

```text {caption="[Query 1] One-to-one, 모든 Label Matching"}
--- query ---
candy1-count{} + ice1-count{}

--- result ---
{color="blue", size="big"} 3 (1+2)
{color="red", size="medium"} 7 (3+4)
```

[Query 1]은 candy1-count와 ice1-count를 대상으로 One-to-one 모든 Label을 Matching하는 경우를 나타내고 있다. candy1-count와 ice1-count의 Cardinality가 3이지만 결과의 Cardinality가 2인 이유는 모든 Label이 Matching하는 경우가 {color="blue", size="big"}, {color="red", size="medium"} 2가지 밖에 없기 때문이다. Operand는 "+"이기 때문에 두 값이 더해진다.

#### 1.1.2 일부 Label Matching

```text {caption="[SQL Syntax 2] One-to-one, 일부 Label Matching, on"}
[Instant Vector] [Op] on([label], ...) [Instant Vector]

ex) candy1-count{} + on(color) ice1-count{}
ex) candy1-count{} - on(color) ice1-count{}
```

One-to-one Matching에서 일부 Label만 Matching 시키는 경우 Matching 시키는 Label을 명시하는 **on** 문법과 Matching에서 제외시키는 Label을 명시하는 **ignoring** 문법 2가지가 존재한다. [SQL Syntax 2]는 on 문법을 이용하여 Matching 시키는 Label을 명시하는 경우의 문법과 예제를 나타내고 있다.

```text {caption="[Query 2] One-to-one, 일부 Label Matching, on"}
--- query --- 
candy1-count{} - on(color) ice1-count{}
--- result ---
{color="blue"} -1 (1+2)
{color="red"} -1 (3+4)
{color="green"} -1 (5+6)
```

[Query 2]는 candy1-count와 ice1-count를 대상으로 on 문법을 이용하여 color Label만 Matching하는 경우를 나타내고 있다. candy1-count와 ic2-count의 color Label의 값인 blue, red, green 별로 연산이 이루어진다. Operand가 "-"이기 때문에 빼기 연산을 수행한다.

```text {caption="[SQL Syntax 3] One-to-one, 일부 Label Matching, ignoring"}
[Instant Vector] [Op] ignoring([label], ...) [Instant Vector]

ex) candy1-count{} + ignoring(size) ice1-count{}
ex) candy1-count{} / ignoring(size) ice1-count{}
```

[SQL Syntax 3]은 ignoring 문법을 이용하여 Matching에서 제외시키는 Label을 명시적으로 제외하는 경우의 문법과 예제를 나타내고 있다.

```text {caption="[Query 3] One-to-one, 일부 Label Matching, ignoring"}
--- query --- 
candy1-count{} - ignoring(size) ice1-count{}

--- result ---
{color="blue"} -1 (1-2)
{color="red"} -1 (3-4)
{color="green"} -1 (5-6)
```

[Query 3]은 candy1-count와 ice1-count를 대상으로 on 문법을 이용하여 size Label을 제외한 나머지 Label만을 이용하여 Matching하는 경우를 나타내고 있다. candy1-count와 ice1-count 모두 color, size Label만 존재하는 상태에서 size Label만 Matching에서 제외하였기 때문에 colr Label만을 이용하여 Matching을 수행한다. 따라서 [Query 2]의 결과와 [Query 3]의 결과는 동일하게 된다.

One-to-one 일부 Label Matching시 선택할 수 있는 Label은 반드시 아래의 조건을 만족시켜야 한다. 아래의 조건을 만족시키지 못하면 Query Error가 발생한다.
* 하나의 Instant Vector Type의 Data 내부에서 선택한 Label의 값은 중복되면 안된다.
* 두 Instant Vector Type의 Data 사이에서 선택한 Label의 값은 반드시 1:1 Matching이 되어야 한다.

```text {caption="[Query 4] One-to-one, 일부 Label Matching, Error"}
--- query --- 
candy1-count{} + on(size) ice1-count{}

--- result ---
Error
```

[Query 4]는 candy1-count와 ice1-count를 대상으로 size Label을 선택하여 Matching에 실패하는 경우를 나타내고 있다. size Label 선택시 Error가 발생하는 이유는 ice1-count의 size Label의 값중 하나인 "big"이 중복되기 때문이다. Label 선택 규칙중 첫번째 규칙에 어긋난다.

candy1-count와 ice1-count를 대상으로 모든 Label 선택 규칙을 만족시키는 Label은 color Label만이 유일하다. 만약 candy1-count와 ice1-count를 대상으로 size Label을 선택하여 Matching을 수행하기 위해서는 One-to-one이 아닌 One-to-many Matching을 이용해야 한다.

### 1.2. One-to-many(Many-to-one) Vector Matching

One-to-many Vector Matching은 의미 그대로 Instant Vector Type에 존재하는 하나의 값을 다른 Instant Vector Type에 존재하는 다수의 값과 1:N으로 Matching시켜 연산하는 문법이다.

```text {caption="[Instant Vector 3] Candy 2 Count"}
--- query ---
candy2-count{}

--- result ---
candy2-count{color="blue", size="big"} 1
candy2-count{color="green", size="small"} 3
candy2-count{color="green", size="big"} 5
```

```text {caption="[Instant Vector 4] Ice 2 Count"}
--- query --- 
ice2-count{}

--- result ---
ice2-count{color="blue", size="big", flavor="soda"} 2
ice2-count{color="red", size="medium", flavor="cherry"} 4
ice2-count{color="green", size="big", flavor="lime"} 6
```

[Instant Vector 3]과 [Instant Vector 4]는 One-to-many Vector Matching 설명을 위해서 이용되는 가상의 Instant Vector Type의 Data인 candy2-count, ice2-count를 나타내고 있다.

```text {caption="[SQL Syntax 4] One-to-many Matching"}
[Instant Vector] [Op] on/ignoring([label], ...) group-left [Instant Vector]
[Instant Vector] [Op] on/ignoring([label], ...) group-right [Instant Vector]

ex) candy2-count{} * on(color) group-left ice2-count{}
```

[SQL Syntax 4]는 One-to-many Matching의 문법을 나타내고 있다. One-to-one 일부 Label Matching 문법에서 **group-left, group-right**만 추가된것을 확인할 수 있다. 1:N Matching시 group-left는 왼쪽 Instant Vector Type의 Data를 "N"으로 설정하고 오른쪽 Instant Vector Type의 Data를 "1"으로 설정할때 이용하며, group-right는 오른쪽 Instant Vector Type의 Data를 "N"으로 설정하고 왼쪽 Instant Vector Type의 Data를 "1"으로 설정할때 이용한다.

여기서 "1"으로 설정된 Instant Vector Type의 Data는 반드시 on, ignoring 문법으로 명시되는 Label에 의해서 **하나의 값만 선택**이 되어야 하며, "N"으로 설정된 Instant Vector Type의 Data는 on, ignoring 문법으로 명시되는 Label에 의해서 0개를 포함하여 다수의 값이 선택되어도 관계없다.

```text {caption="[Query 5] One-to-many, group-left"}
--- query --- 
candy2-count{} * on(color) group-left ice2-count{}

--- result ---
{color="blue", size="big"} 2 (1*2)
{color="green", size="small"} 18 (3*6)
{color="green", size="big"} 30 (5*6)
```

[Query 5]는 group-left를 활용한 One-to-mnay Query를 나타내고 있다. color Label을 기준으로 ice2-count에서는 blue/1개, green/1개, red/1개 즉 모두 1개의 Value만 선택이 되기 때문에 "1"이 될 수 있는 자격이되고, candy2-count에서는 color Label을 기준으로 blue/1개, green/2개, red/0개가 되기 때문에 "1"이 될 수 없고 "N"만 될 수 있다. 따라서 group-left를 통해서 candy2-count가 "N"이 되도록 Matching을 수행해야 한다.

아래와 같이 N:1로 3번 Matching되고 그 결과나 나타난다.

* candy2-count{color="blue", size="big"} * ice2-count{color="blue", size="big", flavor="soda"} = 1 * 2 = 2
* candy2-count{color="green", size="small"} * ice2-count{color="green", size="big", flavor="lime"} = 3 * 6 = 18
* candy2-count{color="green", size="big"} * ice2-count{color="green", size="big", flavor="lime"} = 5 * 6 = 30

```text {caption="[SQL Syntax 5] One-to-many, Many-to-one Matching, with Label"}
[Instant Vector] [Op] on/ignoring([label], ...) group-left([label], ...) [Instant Vector]
[Instant Vector] [Op] on/ignoring([label], ...) group-right([label], ...) [Instant Vector]

ex) candy2-count{} * on(size) group-left(flavor) ice2-count{}
```

[Query 5]의 결과를 보면 "N"이된 candy2-count의 Label만 유지가 되고, "1"이 된 ice2-count의 Label은 사라지는 것을 확인 할 수 있다. "1"의 Label이 유지되기 위해서는 group-left, group-right 문법에 유지되면 좋을 "1"의 Label을 지정하여 넣으면 된다. [SQL Syntax 5]는 group-left, group-right에 "1"의 Label을 지정하는 방법을 나타낸다.

```text {caption="[Query 6] One-to-Many, group-left, with Label"}
--- query --- 
candy2-count{} * on(color) group-left(flavor) ice2-count{}

--- result ---
{color="blue", size="big", flavor="soda"} 2 (1*2)
{color="green", size="small", flavor="lime"} 18 (3*6)
{color="green", size="big", flavor="lime"} 30 (5*6)
```

[Query 6]의 Query는 [Query 5]의 Query에서 ice2-count의 flavor Label를 group-left에 명시한 부분만 변경되었다. 따라서 Query 결과에도 Matching된 ice2-count의 flavor가 존재하는 것을 확인 할 수 있다.

### 1.3. Many-to-many Vector Matching

## 2. 참조

* [https://iximiuz.com/en/posts/prometheus-vector-matching/](https://iximiuz.com/en/posts/prometheus-vector-matching/)
* [https://devthomas.tistory.com/15](https://devthomas.tistory.com/15)
* [https://blog.naver.com/PostView.nhn?blogId=alice-k106&logNo=221535575875](https://blog.naver.com/PostView.nhn?blogId=alice-k106&logNo=221535575875)
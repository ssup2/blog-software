---
title: DB Join
draft: true
---

## 1. Join

{{< figure caption="[Figure 1] DB Join Dataset Example" src="images/db-join-dataset-example.png" width="700px" >}}

Join은 서로 다른 Table에 흩어진 관련 Data를 하나의 Query 결과로 함께 조회할 때 주로 이용하는 RDB 연산이다. [Figure 1]은 Join 연산을 설명하기 위한 예제 Dataset을 나타내고 있다. `Departments` Table과 `Employees` Table이 존재하며, `Departments` Table의 `id` Column과 `Employees` Table의 `dept_id` Column을 Join Key로 사용하여 Join을 수행한다.

### 1.1. Join Type

Join 연산은 연산 방식에 따라서 **Inner Join**, **Outer Join**, **Cross Join**으로 구분할 수 있다.

#### 1.1.1. Inner Join

```sql {caption="[Query 1] Inner Join"}
SELECT   d.id, d.dept_name, e.name
FROM     departments d
INNER JOIN employees e
  ON d.id = e.dept_id;
```

{{< figure caption="[Figure 2] Inner Join Result" src="images/db-join-type-inner.png" width="550px" >}}

#### 1.1.2. Outer Join

```sql {caption="[Query 2] Left Outer Join"}
SELECT   d.id, d.dept_name, e.name
FROM     departments d
LEFT JOIN employees e
  ON d.id = e.dept_id;
```

{{< figure caption="[Figure 3] Left Outer Join Result" src="images/db-join-type-outer-left.png" width="550px" >}}

```sql {caption="[Query 3] Right Outer Join"}
SELECT   d.id, d.dept_name, e.name
FROM     departments d
RIGHT JOIN employees e
  ON d.id = e.dept_id;
```

{{< figure caption="[Figure 4] Right Outer Join Result" src="images/db-join-type-outer-right.png" width="550px" >}}

```sql {caption="[Query 4] Full Outer Join"}
SELECT   d.id, d.dept_name, e.name
FROM     departments d
FULL OUTER JOIN employees e
  ON d.id = e.dept_id;
```

{{< figure caption="[Figure 5] Full Outer Join Result" src="images/db-join-type-outer-full.png" width="550px" >}}

#### 1.1.3. Cross Join

```sql {caption="[Query 5] Cross Join"}
SELECT   d.id, d.dept_name, e.name, e.dept_id
FROM     departments d
CROSS JOIN employees e;
```

{{< figure caption="[Figure 6] Cross Join Result" src="images/db-join-type-cross.png" width="1000px" >}}

### 1.2. Join 알고리즘

{{< figure caption="[Figure 1] DB Join 알고리즘" src="images/db-join-algorithm-tables.png" width="700px" >}}

Join을 수행하는 대표적인 알고리즘에는 **Nested Loop Join**, **Sort Merge Join**, **Hash Join** 3가지가 존재한다. [Figure 1]은 Join 알고리즘을 설명하기 위한 예제 Table을 나타내고 있다. `Employees` Table과 `Departments` Table이 존재하며, `Employees` Table의 `dept_id` Column과 `Departments` Table의 `id` Column을 Join Key로 사용하여 Join을 수행한다.

Join을 수행하기 위해서는 Table 순회가 필요한데, 이때 기준이 되어 한번만 순회를 수행하는 Table을 **Outer Table**이라고 하고, 여러번 순회를 수행하는 Table을 **Inner Table**이라고 한다. `Employees` Table과 `Departments` Table은 Join 알고리즘 설명을 위해, 필요에 따라 Outer Table과 Inner Table의 역할을 모두 수행한다.

#### 1.2.1. Nested Loop Join

Nested Loop Join은 가장 기본적인 Join 알고리즘으로, Outer Table의 각 행을 순회하면서 Inner Table의 모든 행을 순회하는 방식으로 동작한다.

```text {caption="[Text 1] Departments Table : Outer Table, dept_id Index : X / Nested Loop Join 순회 순서"}
Engineering Alice -> O
Engineering Bob -> O
Engineering Carol -> X
Engineering Dave -> X
Engineering Eve -> X
Marketing Alice -> X
Marketing Bob -> X
Marketing Carol -> O
Marketing Dave -> X
Marketing Eve -> O
HR Alice -> X
HR Bob -> X
HR Carol -> X
HR Dave -> O
HR Eve -> X
```

[Text 1]은 `Departments` Table이 Outer Table이고 `Employees` Table이 Inner Table이며, `dept_id` Column에 Index가 없는 경우 Nested Loop Join 수행 시 순회하는 순서를 나타내고 있다. Outer Table인 `Departments` Table의 각 행을 순회하면서 Inner Table인 `Employees` Table의 모든 행을 순회하고 값을 비교하는 방식으로 동작하는 것을 확인할 수 있다.

`dept_id` Column에 Index가 없으면 특정 `dept_id` 값을 가진 Row의 위치를 바로 알 수 없기 때문에, Join 조건(`Employees.dept_id` = `Departments.id`)을 만족하는 Row를 찾으려면 `Employees` Table 전체를 읽어 비교해야 한다. `Departments` Table이 3개의 Record를 가지고 `Employees` Table이 5개의 Record를 가지므로 총 15번의 비교가 발생한다. 시간 복잡도는 O(N * M)이다.

```text {caption="[Text 2] Departments Table : Outer Table, dept_id Index : O / Nested Loop Join 순회 순서"}
Engineering Alice -> O
Engineering Bob -> O
Marketing Carol -> O
Marketing Eve -> O
HR Carol -> O
```

반면 `dept_id` Column에 Index가 있으면, `Departments` Table의 각 행마다 Index Lookup을 통해 해당 `dept_id`를 가진 `Employees` Row만 찾을 수 있다. [Text 2]는 이 경우 Nested Loop Join 수행 시 순회하는 순서를 나타내고 있다. `Employees` Table의 모든 Record를 스캔하지 않고 Join 조건에 맞는 Row만 접근하므로, [Text 1]과 같이 15번이 아니라 5번만 비교하면 된다.

이처럼 Inner Table의 Join Key Column에 Index가 있으면, Outer Table의 각 Row마다 Index Lookup이 한 번씩 수행되고 Inner Table 전체를 반복 스캔하지 않아도 된다. 따라서 탐색 비용은 크게 Outer Table Row 수에 좌우되며, Optimizer는 일반적으로 Row 수가 더 적은 Table을 Outer Table로 선택한다.

#### 1.2.2. Sort Merge Join

{{< figure caption="[Figure 2] DB Join Algorithm" src="images/db-join-algorithm-tables-sort-merge.png" width="700px" >}}

#### 1.2.3. Hash Join

## 2. 참고
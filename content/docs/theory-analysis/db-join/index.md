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

Inner Join은 가장 기본적인 Join 연산으로, 두 Table의 Join Key가 일치하는 Row만 결과에 포함된다. [Query 1]은 Inner Join을 수행하는 SQL Query를 나타내고 있으며, [Figure 2]는 Inner Join 결과를 나타내고 있다. [Figure 2]에서 `NULL` 값을 가진 Row를 제외하고 `Departments` Table의 `id` Column과 `Employees` Table의 `dept_id` Column이 일치하는 Row만 결과에 포함된 것을 확인할 수 있다.

#### 1.1.2. Outer Join

Outer Join은 두 Table의 Join Key가 일치하지 않는 Row도 결과에 포함된다. Outer Join을 이용하는 이유는 왼쪽 또는 오른쪽 또는 양쪽 Table의 모든 Row를 결과에 포함시키기 위해서이다. 모든 Row를 결과에 포함시키는 이유는 누락된 데이터를 파악하거나, 데이터 정합성을 검증하기 위해서 또는 집계 연산을 수행하기 위해서 등 다양한 이유가 있다. 어느 Table의 모든 Row를 결과에 포함시킬지에 따라서 **Left Outer Join**, **Right Outer Join**, **Full Outer Join**으로 구분할 수 있다.

```sql {caption="[Query 2] Left Outer Join"}
SELECT   d.id, d.dept_name, e.name
FROM     departments d
LEFT JOIN employees e
  ON d.id = e.dept_id;
```

{{< figure caption="[Figure 3] Left Outer Join Result" src="images/db-join-type-outer-left.png" width="550px" >}}

Left Outer Join은 이름에서 유추할 수 있는것 처럼 Join Query의 왼쪽 Table이 기준이되어 왼쪽 Table의 모든 Row를 결과에 포함시키고, Join Key가 일치하지 않는 Row는 `NULL` 값을 가진 Row로 채운다. [Query 2]는 Left Outer Join을 수행하는 SQL Query를 나타내고 있으며, [Figure 3]는 Left Outer Join 결과를 나타내고 있다. [Figure 3]에서 `Departments` Table의 모든 Row를 결과에 포함시키고, Join Key가 일치하지 않는 `d.id = 40` Row는 `NULL` 값을 가진 Row로 채워진 것을 확인할 수 있다.

```sql {caption="[Query 3] Right Outer Join"}
SELECT   d.id, d.dept_name, e.name
FROM     departments d
RIGHT JOIN employees e
  ON d.id = e.dept_id;
```

{{< figure caption="[Figure 4] Right Outer Join Result" src="images/db-join-type-outer-right.png" width="550px" >}}

Right Outer Join은 이름에서 유추할 수 있는것 처럼 Join Query의 오른쪽 Table이 기준이되어 오른쪽 Table의 모든 Row를 결과에 포함시키고, Join Key가 일치하지 않는 Row는 `NULL` 값을 가진 Row로 채운다. [Query 3]는 Right Outer Join을 수행하는 SQL Query를 나타내고 있으며, [Figure 4]는 Right Outer Join 결과를 나타내고 있다. [Figure 4]에서 `Employees` Table의 모든 Row를 결과에 포함시키고, Join Key가 일치하지 않는 `name = Ssup` Row는 `NULL` 값을 가진 Row로 채워진 것을 확인할 수 있다.

```sql {caption="[Query 4] Full Outer Join"}
SELECT   d.id, d.dept_name, e.name
FROM     departments d
FULL OUTER JOIN employees e
  ON d.id = e.dept_id;
```

{{< figure caption="[Figure 5] Full Outer Join Result" src="images/db-join-type-outer-full.png" width="550px" >}}

Full Outer Join은 이름에서 유추할 수 있는것 처럼 양쪽 Table의 모든 Row를 결과에 포함시킨다. [Query 4]는 Full Outer Join을 수행하는 SQL Query를 나타내고 있으며, [Figure 5]는 Full Outer Join 결과를 나타내고 있다. [Figure 5]에서 양쪽 Table의 모든 Row를 결과에 포함시키고, Join Key가 일치하지 않는 Row는 `NULL` 값을 가진 Row로 채워진 것을 확인할 수 있다.

#### 1.1.3. Cross Join

```sql {caption="[Query 5] Cross Join"}
SELECT   d.id, d.dept_name, e.name, e.dept_id
FROM     departments d
CROSS JOIN employees e;
```

{{< figure caption="[Figure 6] Cross Join Result" src="images/db-join-type-cross.png" width="1000px" >}}

Cross Join은 두 Table의 모든 Row를 조합하여 결과를 생성한다. 따라서 Cross Join으로 생성된 Row의 개수는 두 Table의 Row 개수를 곱한 값이 된다. 이러한 특징 때문에 **카디시안 곱(Cartesian Product)**이라고 부르기도 한다. [Query 5]는 Cross Join을 수행하는 SQL Query를 나타내고 있으며, [Figure 6]는 Cross Join 결과를 나타내고 있다. [Figure 6]에서 두 Table의 모든 Row를 조합하여 결과를 생성한 것을 확인할 수 있다.

### 1.2. Join 알고리즘

Join 연산을 수행하기 위해서는 Join 대상 테이블을 한 번 이상 순회해야 한다. 이때 기준이 되어 한 번만 순회하는 테이블을 **Outer Table**이라고 하고, 반복적으로 순회하는 테이블을 **Inner Table**이라고 한다. 어떤 테이블을 Outer Table로 선택하느냐에 따라 Join 알고리즘의 성능이 크게 달라질 수 있으며, 일반적으로 **DB Optimizer**가 통계 정보를 기반으로 더 적은 행을 가진 테이블을 Outer Table로 자동 선택한다.

순회 방식에 따라서 **Nested Loop Join**, **Sort Merge Join**, **Hash Join** 3가지가 알고리즘이 존재한다.

#### 1.2.1. Nested Loop Join

Nested Loop Join은 가장 기본적인 Join 알고리즘으로, Outer Table의 각 행을 순회하면서 Inner Table의 모든 행을 순회하는 방식으로 동작한다.

```text {caption="[Text 1] Nested Loop Join 순회 / Outer Table: Departments, Inner Table: Employees, dept_id Index: X"}
[Outer: Engineering (id=10)]
  → Alice (dept_id=10)   O
  → Bob   (dept_id=10)   O
  → Coral (dept_id=20)   X
  → Dave  (dept_id=30)   X
  → Eve   (dept_id=20)   X
  → Ssup  (dept_id=NULL) X

[Outer: Marketing (id=20)]
  → Alice (dept_id=10)   X
  → Bob   (dept_id=10)   X
  → Coral (dept_id=20)   O
  → Dave  (dept_id=30)   X
  → Eve   (dept_id=20)   O
  → Ssup  (dept_id=NULL) X

[Outer: HR (id=30)]
  → Alice (dept_id=10)   X
  → Bob   (dept_id=10)   X
  → Coral (dept_id=20)   X
  → Dave  (dept_id=30)   O
  → Eve   (dept_id=20)   X
  → Ssup  (dept_id=NULL) X

[Outer: NULL (dept_id=40)]
  → Alice (dept_id=10)   X
  → Bob   (dept_id=10)   X
  → Coral (dept_id=20)   X
  → Dave  (dept_id=30)   X
  → Eve   (dept_id=20)   X
  → Ssup  (dept_id=NULL) X
```

[Text 1]은 `Departments` Table이 Outer Table이고 `Employees` Table이 Inner Table이며, `dept_id` Column에 Index가 없는 경우 Nested Loop Join 수행 시 순회하는 순서를 나타내고 있다. Outer Table인 `Departments` Table의 각 행을 순회하면서 Inner Table인 `Employees` Table의 모든 행을 순회하고 값을 비교하는 방식으로 동작하는 것을 확인할 수 있다.

`dept_id` Column에 Index가 없으면 특정 `dept_id` 값을 가진 Row의 위치를 바로 알 수 없기 때문에, Join 조건(`Employees.dept_id` = `Departments.id`)을 만족하는 Row를 찾으려면 `Employees` Table 전체를 읽어 비교해야 한다. `Departments` Table이 4개의 Record를 가지고 `Employees` Table이 6개의 Record를 가지므로 총 24번의 Row Scan이 발생한다. 시간 복잡도는 `O(N * M)`이다.

```text {caption="[Text 2] Nested Loop Join 순회 / Outer Table: Departments, Inner Table: Employees, dept_id Index: O"}
[Outer: Engineering (id=10)]
  → Alice (dept_id=10)   O
  → Bob   (dept_id=10)   O

[Outer: Marketing (id=20)]
  → Coral (dept_id=20)   O
  → Eve   (dept_id=20)   O

[Outer: HR (id=30)]
  → Dave  (dept_id=30)   O

[Outer: NULL (id=40)]
```

반면 `dept_id` Column에 Index가 있으면, `Departments` Table의 각 행마다 Index Lookup을 통해 해당 `dept_id`를 가진 `Employees` Row만 찾을 수 있다. [Text 2]는 이 경우 Nested Loop Join 수행 시 순회하는 순서를 나타내고 있다. `Employees` Table의 모든 Record를 스캔하지 않고 Join 조건에 맞는 Row만 접근하므로, [Text 2]와 같이 24번이 아니라 5번의 Row Scan만 수행하면 되며, 이 경우 Index Lookup은 4번만 (`10`, `20`, `30`, `40`) 수행하면 된다.

```text {caption="[Text 3] Nested Loop Join 순회 / Outer Table: Employees, Inner Table: Departments"}
[Outer: Alice (dept_id=10)]
  → Engineering (id=10)   O

[Outer: Bob (dept_id=10)]
  → Engineering (id=10)   O

[Outer: Coral (dept_id=20)]
  → Marketing   (id=20)   O

[Outer: Dave (dept_id=30)]
  → HR          (id=30)   O

[Outer: Eve (dept_id=20)]
  → Marketing   (id=20)   O

[Outer: Ssup (dept_id=NULL)]
```

[Text 3]은 `Employees` Table이 Outer Table이고 `Departments` Table이 Inner Table이며, `dept_id` Column에 Index가 있는 경우 Nested Loop Join 수행 시 순회하는 순서를 나타내고 있다. Outer Table인 `Employees` Table의 각 행을 순회하면서, Inner Table인 `Departments` Table의 Index를 통해 조건에 맞는 Row만 직접 탐색하는 방식으로 동작하는 것을 확인할 수 있다. 이 경우 Row Scan은 [Text 2]와 같이 5번을 수행하지만 Index Lookup도 5번 (`10`, `10`, `20`, `30`, `20`) 수행이 필요하다. `Ssup`은 `dept_id`가 NULL이므로 Index Lookup을 수행하지 않고 즉시 조인 대상에서 제외된다.

이 처럼 [Text 2]와 [Text 3]는 동일한 Join 연산이지만 어떤 Table을 Outer Table로 선택하느냐에 따라서 Index Lookup 횟수가 달라질 수 있으며, 이는 Join 알고리즘의 성능에 크게 영향을 미칠 수 있다. Index Lookup 횟수를 줄이기 위해서는 Outer Table의 Row 수가 Inner Table보다 적어야 하며, 따라서 DB Optimizer는 일반적으로 Row 수가 더 적은 Table을 Outer Table로 자동 선택한다.

#### 1.2.2. Sort Merge Join

Sort Merge Join은 이름에서 유추할 수 있듯이 Join Key 기준으로 Data를 정렬한 뒤 Join을 수행한다. Sort Merge Join을 수행하려면 Join Key 기준으로 양쪽 Table이 정렬된 상태여야 하며, 정렬이 끝나면 각 Table의 **Pointer**를 앞에서부터 내려가며 Join Key를 비교하고 Join을 수행한다. 이때 Inner Table의 경우에도 Nested Loop Join과 다르게 한번만 순회가 발생한다.

{{< figure caption="[Figure 7] Sort Merge Join" src="images/db-join-dataset-example-sorted.png" width="700px" >}}

[Figure 7]은 [Figure 1]의 Dataset에서 `Employees.dept_id` Column을 기준으로 `Employees` Table만 정렬한 상태를 나타내고 있다. `Departments.id`는 Primary Key Clustered Index에 의해 이미 정렬되어 있으므로 [Figure 1]과 동일한 순서를 유지한다.

```text {caption="[Text 4] Sort Merge Join Merge 단계 / Inner Join (d.id = e.dept_id)"}
Engineering(10)  · Alice(10)      → O    →            `ptr_e++`
Engineering(10)  · Bob(10)        → O    →            `ptr_e++`
Engineering(10)  · Coral(20)      → X    → `ptr_d++`
Marketing(20)    · Coral(20)      → O    →            `ptr_e++`
Marketing(20)    · Eve(20)        → O    →            `ptr_e++`
Marketing(20)    · Dave(30)       → X    → `ptr_d++`
HR(30)           · Dave(30)       → O    →            `ptr_e++`
HR(30)           · Ssup(NULL)     → X    → `ptr_d++`
(Unassigned)40   · Ssup(NULL)     → X
```

[Text 4]는 [Figure 7]의 Sort Merge Join Merge 단계를 나타낸다. Nested Loop Join과 달리 Outer Table의 각 Row마다 Inner Table 전체를 순회하지 않고, `ptr_d`는 `Departments` Table의, `ptr_e`는 `Employees` Table의 현재 Row를 가리키는 두 Pointer로 앞에서부터 읽으며 진행한다. Join Key가 같으면 `ptr_e++`로 다음 Employee를 본다. `ptr_d++`로 다음 Department를 본다.

#### 1.2.3. Hash Join

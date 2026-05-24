---
title: DB Join
draft: true
---

## 1. Join

### 1.1. Join Type

### 1.2. Join 알고리즘

{{< figure caption="[Figure 1] DB Join 알고리즘" src="images/db-join-algorithm-tables.png" width="800px" >}}

Join을 수행하는 대표적인 알고리즘에는 **Nested Loop Join**, **Sort Merge Join**, **Hash Join** 3가지가 존재한다. [Figure 1]은 Join 알고리즘을 설명하기 위한 예제 Table을 나타내고 있다. `Employees` Table과 `Departments` Table이 존재하며, `Employees` Table의 `dept_id` Column과 `Departments` Table의 `id` Column을 Join Key로 사용하여 Join을 수행한다.

Join을 수행하기 위해서는 Table 순회가 필요한데, 이때 기준이 되어 한번만 순회를 수행하는 Table을 **Outer Table**이라고 하고, 여러번 순회를 수행하는 Table을 **Inner Table**이라고 한다. `Employees` Table과 `Departments` Table은 Join 알고리즘 설명을 위해, 필요에 따라 Outer Table과 Inner Table의 역할을 모두 수행한다.

#### 1.2.1. Nested Loop Join

Nested Loop Join은 가장 기본적인 Join 알고리즘으로, Outer Table의 각 행을 순회하면서 Inner Table의 모든 행을 순회하는 방식으로 동작한다.

```text {caption="[Text 1] Departments Table Outer Table, No dept_id Index / Nested Loop Join 순회 순서"}
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

[Text 1]은 `Departments` Table이 Outer Table이고 `Employees` Table이 Inner Table이며, `dept_id` Column에 Index가 없는 경우 Nested Loop Join 수행시 순회하는 순서를 나타내고 있다. Outer Table인 `Departments` Table의 각 행을 순회하면서 Inner Table인 `Employees` Table의 모든 행을 순회하고 값을 비교하는 방식으로 동작하는 것을 확인할 수 있다. 즉 `Departments` Table이 3개의 Record를 가지고 있고, `Employees` Table이 5개의 Record를 가지고 있기 때문에 총 15번의 순회가 발생하다.

`Departments` Table의 각 행마다 `Employees` Table의 모든 행을 순회해야 하는 이유는 `dept_id` Column에 Index가 존재하지 않기 때문에, 직접 읽지 않으면 어떤 값을 갖는지 알 수 없기 때문이다. 하지만 `dept_id` Column에 Index가 존재하면, 해당 Column을 기반으로 빠르게 `Employees` Table을 순회할 수 있다.

#### 1.2.2. Sort Merge Join

{{< figure caption="[Figure 2] DB Join Algorithm" src="images/db-join-algorithm-tables-sort-merge.png" width="800px" >}}

#### 1.2.3. Hash Join

## 2. 참고
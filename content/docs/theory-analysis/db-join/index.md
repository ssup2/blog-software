---
title: DB Join
draft: true
---

## 1. Join

### 1.1. Join Type

### 1.2. Join Algorithm

{{< figure caption="[Figure 1] DB Join Algorithm" src="images/db-join-algorithm-tables.png" width="800px" >}}

Join을 수행하는 대표적인 알고리즘에는 **Nested Loop Join**, **Sort Merge Join**, **Hash Join** 3가지가 존재한다. [Figure 1]은 Join 알고리즘을 설명하기 위한 예제 Table을 나타내고 있다. `Employees` Table과 `Departments` Table이 존재하며, `Employees` Table의 `dept_id` Column과 `Departments` Table의 `id` Column을 Join Key로 사용하여 Join을 수행한다.

Join을 수행하기 위해서는 Table 순회가 필요한데, 이때 기준이 되어 한번만 순회를 수행하는 Table을 **Outer Table**이라고 하고, 여러번 순회를 수행하는 Table을 **Inner Table**이라고 한다. 모든 예제에서 `Employees` Table은 Outer Table로 이용되고, `Departments` Table은 Inner Table로 이용된다라고 가정한다.

#### 1.2.1. Nested Loop Join

#### 1.2.2. Sort Merge Join

{{< figure caption="[Figure 2] DB Join Algorithm" src="images/db-join-algorithm-tables-sort-merge.png" width="800px" >}}

#### 1.2.3. Hash Join

## 2. 참고
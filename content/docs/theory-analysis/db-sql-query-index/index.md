---
title: DB SQL Query with Index
---

Index를 활용하는 SQL Query를 정리한다.

## 1. Where

```sql {caption="[Query 1] Where 단일 조건문"}
WHERE state = 'NC'
WHERE state IN ('NC')
WHERE state >= 'NC'
WHERE state < 'NC'
```

Index를 이용하면 WHERE 조건문을 이용하는 SQL Query의 성능을 향상 시킬 수 있다. [Query 1]은 WHERE 조건문의 예제를 나타내고 있다. 동일한 값을 찾을때 뿐만 아니라, 크거나 작은 값을 찾을때도 Index를 이용한다. IN 문법의 경우에는 값의 개수가 적을경우에는 Index를 이용하지만, 값의 개수가 많아지는 경우 Index를 이용하지 않게된다. MySQL의 경우에는 "range-optimizer-max-mem-size"의 값과 Data에 사이즈에 따라서 최대 몇개의 값까지 Index를 이용할지 설정할 수 있다.

```sql {caption="[Query 2] Where 복수 조건문"}
WHERE state = 'NC' AND fruit >= 'Apple' AND fruit < 'Lemon'
WHERE state > 'NC' AND fruit >= 'Apple' AND fruit < 'Lemon'
```

WHERE 조건문에 AND 문법으로 여러가지 조건이 추가되는 경우 조건의 범위가 가장 작은 Index 하나를 선택하고, 참조해서 Query를 수행한다. Fruit Field의 Index와 State Field의 Index가 각각 존재할때 [Query 2]의 첫번째 Query는 State Field의 Index를 참조한다. State Field의 범위가 'NC'로 정해져 있기 때문이다. 두번째 Query는 Fruit Field의 Index를 참조한다. State Field의 범위는 최소값만 정해져 있지만 Fruit Field의 범위는 최소값, 최대값 둘다 정해져 있기 때문이다.

## 2. Concatenated Index (결합인덱스)

{{< figure caption="[Figure 1] DB Table" src="images/db-table.png" width="400px" >}}

[Figure 1]은 설명을 위한 가상의 Table을 나타내고 있다. 현재 대부분의 DB에서는 하나의 Field가 아니라 여러개의 Field를 결합하여 Index를 생성하는 기능을 지원하고 있다. 이러한 Index를 **Concatenated Index(결합인덱스)**라고 한다. Concatenated Index 생성시 Field 결합 순서는 매우 중요하다. Field의 결합 순서대로 Record의 값을 붙여 Index를 생성하기 때문이다. [Figure 1]에서 Fruit, State Field 순으로 Index를 생성하면 Index에는 OrangeFL값이 들어가고, State, Fruit 순으로 Index를 생성하면 Index에는 FLOrange값이 들어가게 된다.

```sql {caption="[Query 3] Select, Where 복수 조건문"}
SELECT * FROM fruit-info WHERE fruit = 'Lemon' AND state = 'NC'
```

[Query 3]을 Fruit, State Field 순으로 생성한 Index를 이용하는 경우 Index를 완전히 활용하여 Record를 빠르게 찾을 수 있다. 하지만 State, Fruit Field 순으로 생성한 Index를 이용하는 경우 Index의 앞부분인 State Field부분은 이용할 수 있지만 Index의 뒷부분인 Fruit 부분은 이용하지 못한다. 이와 같이 Concatenated Index의 Field 순서와 WHERE 조건문에 따라서 순서에 따라 SQL 성능이 달라진다. 또한 Concatenated Index의 첫번째 Field는 다양한 WHERE 조건문에서 이용 가능하다.

## 3. Join

```sql {caption="[Query 4] Join"}
SELECT * FROM dept, emp WHERE dept.id = emp.dept-id
```

Index를 이용하면 Join Query의 성능을 향상 시킬 수 있다. DB는 [Query 4]의 Query를 실행 할 때 dept Table의 record를 하나 선택한 다음 dept.dept-id를 확인한다. 그 후 emp Table를 뒤져 dept.id와 값이 같은 emp.dept-id를 갖는 record를 찾아 Join을 수행한다. 그리고 DB는 dept Table의 다음 record를 선택한뒤 동일 과정을 반복한다.

DB는 [Query 4]의 수행 과정에서 dept.id 값을 emp Table의 dept-ip Field안에서 찾기 위해 emp Table을 모두 뒤져보는 동작을 반복 수행하게 된다. emp.dept-id에 대한 Index를 생성해 놓으면 DB는 Index를 이용해 emp Table 전체를 뒤지지 않아도 되기 때문에 성능 향상으로 이어진다.

## 4. 참조

* [https://www.progress.com/tutorials/odbc/using-indexes](https://www.progress.com/tutorials/odbc/using-indexes)
* [https://hoing.io/archives/24493](https://hoing.io/archives/24493)
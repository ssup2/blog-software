---
title: Spark Join Strategy
draft: true
---

## 1. Strategy Decision Flow

{{< table caption="[Table 1] Spark Join Strategy" >}}
| Join Strategy | 개요 | Shuffle | 지원 Join Type | Hint |
|----|----|----|----|----|
| Broadcast Hash Join | 소형 Table을 Executor에 Broadcast 후 Hash Join | 불필요 (Broadcast) | Inner, Left Semi, Left Anti | `BROADCAST`, `BROADCASTJOIN`,  `MAPJOIN`|
| Shuffle Hash Join | 양쪽을 Join Key로 Shuffle 후 Hash Join | 필요 | Inner | `SHUFFLE_HASH` |
| Shuffle Sort Merge Join | 양쪽을 Join Key로 Shuffle·정렬 후 Merge Join | 필요 | Inner, Left/Right/Full Outer |  `SHUFFLE_MERGE`, `MERGE`,`MERGEJOIN` |
| Cartesian Product (Cross Join) | 두 Table의 모든 Row 조합 | 불필요 또는 필요 | Cross | `SHUFFLE_REPLICATE_NL` |
| Broadcast Nested Loop Join | 소형 Table Broadcast 후 Nested Loop | 불필요 (Broadcast) | Inner, Outer | - |
{{< /table >}}

{{< figure caption="[Figure 1] Spark Join Strategy Decision Flow" src="images/spark-join-strategy-decision-flow.png" width="1000px" >}}

## 2. Join Strategy

### 2.1. Broadcast Hash Join

{{< figure caption="[Figure 2] Broadcast Hash Join" src="images/spark-join-broadcast-hash.png" width="1000px" >}}

### 2.2. Shuffle Hash Join

{{< figure caption="[Figure 3] Shuffle Hash Join" src="images/spark-join-shuffle-hash.png" width="1000px" >}}

### 2.3. Shuffle Sort Merge Join

{{< figure caption="[Figure 4] Shuffle Sort Merge Join" src="images/spark-join-shuffle-sort-merge.png" width="1000px" >}}

### 2.4. Cartesian Product (Cross Join)

{{< figure caption="[Figure 5] Cartesian Product (Cross Join)" src="images/spark-join-cartesian-product.png" width="1000px" >}}

### 2.5. Broadcast Nested Loop Join

{{< figure caption="[Figure 6] Broadcast Nested Loop Join" src="images/spark-join-broadcast-nested-loop.png" width="1000px" >}}

## 3. 참고

* Spark Join : [https://velog.io/@kimhaggie/spark-join%EC%9D%98-%EC%A2%85%EB%A5%98](https://velog.io/@kimhaggie/spark-join%EC%9D%98-%EC%A2%85%EB%A5%98)
* Spark Join : [https://sunrise-min.tistory.com/entry/Apache-Spark-Join-strategy](https://sunrise-min.tistory.com/entry/Apache-Spark-Join-strategy)
* Spark Join : [https://faun.pub/primer-on-spark-join-strategy-134e7340f7a6](https://faun.pub/primer-on-spark-join-strategy-134e7340f7a6)
* Spark Join : [https://dataninjago.com/2022/01/11/spark-sql-query-engine-deep-dive-11-join-strategies/](https://dataninjago.com/2022/01/11/spark-sql-query-engine-deep-dive-11-join-strategies/)
* Spark Join : [https://medium.com/@amarkrgupta96/join-strategies-in-apache-spark-a-hands-on-approach-d0696fc0a6c9](https://medium.com/@amarkrgupta96/join-strategies-in-apache-spark-a-hands-on-approach-d0696fc0a6c9)

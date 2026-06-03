---
title: Spark Join
draft: true
---

## 1. Spark Join

{{< table caption="[Table 1] Spark Join Strategy" >}}
| Join Strategy | 개요 | Shuffle | 지원 Join Type | Hint |
|----|----|----|----|----|
| Broadcast Hash Join | 소형 Table을 Executor에 Broadcast 후 Hash Join | 불필요 (Broadcast) | Inner, Left Semi, Left Anti | `BROADCAST` |
| Shuffle Hash Join | 양쪽을 Join Key로 Shuffle 후 Hash Join | 필요 | Inner | `SHUFFLE_HASH` |
| Shuffle Sort Merge Join | 양쪽을 Join Key로 Shuffle·정렬 후 Merge Join | 필요 | Inner, Left/Right/Full Outer | `MERGE` |
| Cross Join | 두 Table의 모든 Row 조합 | 불필요 또는 필요 | Cross | `SHUFFLE_REPLICATE_NL` |
| Broadcast Nested Loop Join | 소형 Table Broadcast 후 Nested Loop | 불필요 (Broadcast) | Inner, Outer | - |
{{< /table >}}

### 1.1. Broadcast Hash Join

### 1.2. Shuffle Hash Join

### 1.3. Shuffle Sort Merge Join

### 1.4. Broadcast Nested Loop Join

### 1.5. Cross Join

## 2. 참고

* Spark Join : [https://velog.io/@kimhaggie/spark-join%EC%9D%98-%EC%A2%85%EB%A5%98](https://velog.io/@kimhaggie/spark-join%EC%9D%98-%EC%A2%85%EB%A5%98)
* Spark Join : [https://sunrise-min.tistory.com/entry/Apache-Spark-Join-strategy](https://sunrise-min.tistory.com/entry/Apache-Spark-Join-strategy)
* Spark Join : [https://faun.pub/primer-on-spark-join-strategy-134e7340f7a6](https://faun.pub/primer-on-spark-join-strategy-134e7340f7a6)
* Spark Join : [https://medium.com/@amarkrgupta96/join-strategies-in-apache-spark-a-hands-on-approach-d0696fc0a6c9](https://medium.com/@amarkrgupta96/join-strategies-in-apache-spark-a-hands-on-approach-d0696fc0a6c9)

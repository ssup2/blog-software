---
title: Trino Architecture
---

## 1. Trino Architecture

{{< figure caption="[Figure 1] Trino Architecture" src="images/trino-architecture.png" width="1000px" >}}

[Figure 1]은 Trino Architecture를 나타낸다. Trino는 Coordinator와 Worker로 분류할 수 있다. Coordinator는 Client로부터 Query를 받아 Query를 Task로 쪼개어 Worker에게 할당하는 역할을 수행하며, Worker는 Coordinator로부터 받은 Task를 실제로 수행하여 Query를 처리하는 역할을 수행한다.

## 2. 참조

* [https://www.oreilly.com/library/view/trino-the-definitive/9781098107703/ch04.html](https://www.oreilly.com/library/view/trino-the-definitive/9781098107703/ch04.html)
* [https://trino.io/docs/current/overview/concepts.html](https://trino.io/docs/current/overview/concepts.html)
* [https://www.slideshare.net/streamnative/trino-a-ludicrously-fast-query-engine-pulsar-summit-na-2021](https://www.slideshare.net/streamnative/trino-a-ludicrously-fast-query-engine-pulsar-summit-na-2021)
---
title: Trino Architecture
---

## 1. Trino Architecture

{{< figure caption="[Figure 1] Trino Architecture" src="images/trino-architecture.png" width="900px" >}}

[Figure 1]은 Trino Architecture를 나타낸다. Trino는 Coordinator와 Worker로 분류할 수 있다. Coordinator는 Client로부터 Query를 받아 Query를 Task로 쪼개어 Worker에게 할당하는 역할을 수행하며, Worker는 Coordinator로부터 받은 Task를 실제로 수행하여 Query를 처리하는 역할을 수행한다. Coordinator는 "Parser/Analyzer", "Planner/Optimizer", "Scheduler"로 구성되어 있으며 역할은 다음과 같다.

* Parser/Analyzer : Query를 검사하고 Parsing하는 역할을 수행한다. 
* Planner/Optimizer : Query를 Tree 형태의 Task로 쪼개는 역할을 수행한다. 
* Scheduler : Task를 어느 Worker에 할당할지 결정한다.

Trino는 다양한 Data Source를 대상으로 Query 수행이 가능하며, 다양한 Data Source 지원을 위해서 "SPI (Service Provider Interface)"를 이용한다. SPI는 Parser/Analyzer가 이용하는 **Metadata SPI**, Planner/Optimzer가 이용하는 **Data Statistics SPI**, Scheduler가 이용하는 **Data Location SPI**, Worker가 이용하는 **Data Stream SPI**로 구성되어 있으며 역할은 다음과 같다.

* Metadata SPI : Query 점검을 위해서 Table, Column, Type 정보를 제공한다.
* Data Statistics SPI : Query 최적화를 위해서 Table의 크기 및 Table의 Row 개수 정보를 제공한다.
* Data Location SPI : Data 위치 정보를 제공하여 Task를 효율적으로 Worker에 할당하도록 돕는다.
* Data Stream SPI : Data Source로부터 실제 Data를 조회하고 가져온다.

## 2. 참조

* [https://www.oreilly.com/library/view/trino-the-definitive/9781098107703/ch04.html](https://www.oreilly.com/library/view/trino-the-definitive/9781098107703/ch04.html)
* [https://trino.io/docs/current/overview/concepts.html](https://trino.io/docs/current/overview/concepts.html)
* [https://www.slideshare.net/streamnative/trino-a-ludicrously-fast-query-engine-pulsar-summit-na-2021](https://www.slideshare.net/streamnative/trino-a-ludicrously-fast-query-engine-pulsar-summit-na-2021)
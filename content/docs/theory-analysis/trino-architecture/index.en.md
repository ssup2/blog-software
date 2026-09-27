---
title: Trino Architecture
---

## 1. Trino Architecture

{{< figure caption="[Figure 1] Trino Architecture" src="images/trino-architecture.png" width="900px" >}}

[Figure 1] shows the Trino Architecture. Trino can be classified into Coordinator and Worker. The Coordinator receives Queries from Clients, splits the Queries into Tasks, and assigns them to Workers, while the Worker actually executes the Tasks received from the Coordinator to process the Queries. The Coordinator consists of "Parser/Analyzer", "Planner/Optimizer", and "Scheduler", and their roles are as follows.

* **Parser/Analyzer** : Inspects and parses Queries. 
* **Planner/Optimizer** : Splits Queries into Tasks in a Tree form. 
* **Scheduler** : Decides which Worker to assign Tasks to.

Trino can execute Queries against various Data Sources, and uses the "SPI (Service Provider Interface)" to support various Data Sources. The SPI consists of the **Metadata SPI** used by the Parser/Analyzer, the **Data Statistics SPI** used by the Planner/Optimzer, the **Data Location SPI** used by the Scheduler, and the **Data Stream SPI** used by the Worker, and their roles are as follows.

* **Metadata SPI** : Provides Table, Column, and Type information for Query inspection.
* **Data Statistics SPI** : Provides Table size and Table Row count information for Query optimization.
* **Data Location SPI** : Provides Data location information to help assign Tasks to Workers efficiently.
* **Data Stream SPI** : Retrieves and fetches actual Data from Data Sources.

## 2. References

* Trino: The Definitive Guide - Chapter 4 : [https://www.oreilly.com/library/view/trino-the-definitive/9781098107703/ch04.html](https://www.oreilly.com/library/view/trino-the-definitive/9781098107703/ch04.html)
* Trino Concepts : [https://trino.io/docs/current/overview/concepts.html](https://trino.io/docs/current/overview/concepts.html)
* Trino: A Ludicrously Fast Query Engine (Pulsar Summit NA 2021) : [https://www.slideshare.net/streamnative/trino-a-ludicrously-fast-query-engine-pulsar-summit-na-2021](https://www.slideshare.net/streamnative/trino-a-ludicrously-fast-query-engine-pulsar-summit-na-2021)
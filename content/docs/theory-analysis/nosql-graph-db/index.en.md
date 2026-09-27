---
title: NoSQL Graph DB
---

This post analyzes Graph DB, one of the NoSQL DBs.

## 1. Graph DB

{{< figure caption="[Figure 1] NoSQL Graph DB" src="images/nosql-graph.png" width="500px" >}}

**Graph DB**, as the name implies, refers to a DB that stores and manages Data in Graph form. Here, the Graph consists of **Data and the Data Relationships that connect Data**. [Figure 1] shows Data in Graph form. A Node of the Graph represents Data, and an Edge of the Graph represents a Data Relationship. Users can freely store Data and Data Relations in a Graph DB without defining a Schema. Transactions are not supported.

### 1.1. vs RDBMS

An RDBMS represents Data Relationships **indirectly** using the PK (Primary Key) and FK (Foreign Key) of Tables. Therefore, to query and manipulate related Data stored in multiple Tables at once, the Tables must be connected using the **Join** operation. In contrast, since a Graph DB stores Data and Data Relationships together, no Data-connecting operation such as Join is needed even when querying and manipulating related Data at once. The Join operation of an RDBMS incurs heavy load as the Data grows. Therefore, when storing a large amount of Data and Data Relations, the use of a Graph DB is worth considering.

## 2. References

* What is a Graph Database? : [https://database.guide/what-is-a-graph-database/](https://database.guide/what-is-a-graph-database/)
* What is a graph database? A better way to store connected data : [https://www.infoworld.com/article/3263764/what-is-a-graph-database-a-better-way-to-store-connected-data.html](https://www.infoworld.com/article/3263764/what-is-a-graph-database-a-better-way-to-store-connected-data.html)
* Graph Database vs Relational Database : [https://medium.com/@mtbuzzerseo/graph-database-vs-relational-database-e5798281f6ef](https://medium.com/@mtbuzzerseo/graph-database-vs-relational-database-e5798281f6ef)
* Comparison of relational databases and graph databases : [https://stackoverflow.com/questions/13046442/comparison-of-relational-databases-and-graph-databases](https://stackoverflow.com/questions/13046442/comparison-of-relational-databases-and-graph-databases)

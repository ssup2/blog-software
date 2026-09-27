---
title: NoSQL Key-value DB
---

This article analyzes the Key-value DB, one of the NoSQL DBs.

## 1. Key-value DB

{{< figure caption="[Figure 1] NoSQL Key-value DB" src="images/nosql-key-value.png" width="300px" >}}

As the name **Key-value** implies, it is a DB that stores and manages Data with a Key/Value relationship. Since the Key uses a Binary Sequence, various kinds of Data ranging from Primitive Types such as integers and strings to Image Files can be used as a Key, but the Key must be **Unique**. Because a Key-value DB must guarantee that Keys are Unique, it performs a Key comparison operation every time Key/Value Data is added. The longer the Key, the greater the Key comparison operation Overhead, so it is better to use a Binary Sequence as short as possible to improve Key-value DB performance.

The Value basically supports Primitive Types such as integers and strings, but depending on the DB, data structure Types such as List and Hash may also be provided. Memcached provides only String Type Values, while Redis provides not only the String Type but also data structure Types such as List, Set, and Hash.

A Key-value DB only provides CRUD functionality for Key/Value Data based on the Unique Key, and does not store Relation information between Keys. Because of this simple functionality, Key-value DBs show the fastest CRUD performance. In addition, a Key-value DB has high Flexibility because Key/Value Data can simply be inserted without defining a Schema, and it has high Scalability because there is no Dependency between Keys except for the Unique constraint on the Key.

## 2. References

* What is a Key-Value Database? : [https://database.guide/what-is-a-key-value-database/](https://database.guide/what-is-a-key-value-database/)

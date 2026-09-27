---
title: NoSQL Document-oriented DB
---

This post analyzes the Document-oriented DB, one of the NoSQL DBs.

## 1. Document-oriented DB

{{< figure caption="[Figure 1] NoSQL Document-oriented" src="images/document-oriented.png" width="500px" >}}

A **Document-oriented DB** is, as the name suggests, a DB that stores and manages Data in the form of Documents. Here, a Document means **hierarchical Key-value Data** like XML or JSON. Therefore, a Document-oriented DB can be seen as a DB that evolved from the Key-value DB. [Figure 1] shows an example of a MongoDB Document. The Key/Value rules of a Document are almost identical to JSON. A Key must be unique within an Object (within `{}` in JSON). A Value can hold various kinds of Data, from Integer to String.

A Document-oriented DB, like a Key-value DB, does not require a Schema. Users can freely put Data into Documents as needed, and this characteristic leads to high Flexibility. Also, since there is no Dependency between Keys except for the uniqueness condition of Keys and the hierarchy between Keys, it has relatively high Scalability.

A Document-oriented DB manages Documents by attaching a unique ID to each Document. In [Figure 1], `_id` means the unique ID value for Document management in MongoDB. The ID is **Indexed**, helping the Document-oriented DB find Documents more quickly. Not only the ID but also any Key the user wants can be Indexed. Most Document-oriented DBs also support various Data operation features, from simple operations such as Data addition and multiplication to Map/Reduce, so Apps can easily process and use Data.

## 2. References

* Document-oriented Database : [https://en.wikipedia.org/wiki/Document_oriented_database](https://en.wikipedia.org/wiki/Document_oriented_database)
* What is a Document Store Database? : [https://database.guide/what-is-a-document-store-database/](https://database.guide/what-is-a-document-store-database/)
* Document Oriented Databases : [https://www.slideshare.net/fabiofumarola1/9-document-oriented-databases](https://www.slideshare.net/fabiofumarola1/9-document-oriented-databases)
* CouchDB Student Project Report (ULB) : [http://cs.ulb.ac.be/public/-media/teaching/infoh415/student-projects/couchdb.pdf](http://cs.ulb.ac.be/public/-media/teaching/infoh415/student-projects/couchdb.pdf)

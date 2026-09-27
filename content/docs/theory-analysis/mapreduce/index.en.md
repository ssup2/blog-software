---
title: MapReduce
---

## 1. MapReduce

{{< figure caption="[Figure 1] MapReduce" src="images/mapreduce.png" width="800px" >}}

**MapReduce** is a technique for processing large amounts of Data in a distributed manner. [Figure 1] shows the MapReduce process. Hadoop was the first to support it, and it is now also supported by Document Type NoSQL DBs such as CouchDB and MongoDB. MapReduce proceeds in 4 main stages: Splitting, Mapping, Shuffling, and Reducing.

* **Splitting** : Splitting is the process of splitting the Input File and then delivering the split Input File to each Node. Through the Splitting process, the Input File is split into K1, V1 Key-Value relationships. In [Figure 1], the Key is the Line of the File and the Value is the String of the Line. In the MapReduce Framework, the Class responsible for splitting the Input File is the `InputFormat` Class. Developers can decide how to split the Input File by using the default `InputFormat` Classes, the `TextInputFormat` and `KeyValueInputFormat` Classes, or by developing their own `InputFormat` Class.
* **Mapping** : Mapping is the process of Mapping the split Input File into List(K2, V2) Key-Values as needed. The MapReduce Framework creates as many YARN Containers as the number of split Input Files, and performs the Mapping work in parallel inside each Container. Therefore, the more Nodes that make up the YARN Cluster, the faster large amounts of Data can be processed. The MapReduce Framework provides developers with the `Mapper` Class responsible for Mapping, helping developers perform Mapping easily.
* **Shuffling** : Shuffling is the process of delivering the Mapping results to the Nodes that perform Reducing. Through the Shuffling process, the Values are gathered to specific Nodes based on the Key (K2) used in the Mapping process.
* **Reducing** : Reducing is the process of merging the Mapping results. The MapReduce Framework provides developers with the `Reducer` Class responsible for Reducing, allowing developers to perform Reducing easily.

## 2. References

* Hadoop InputFormat, Types of InputFormat in MapReduce : [https://data-flair.training/blogs/hadoop-inputformat/](https://data-flair.training/blogs/hadoop-inputformat/)
* Hadoop Concepts - Definitions Along the MapReduce Flow : [http://icecello.tistory.com/35](http://icecello.tistory.com/35)

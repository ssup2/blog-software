---
title: Elasticsearch Data Structure
---

Analyzes the Data Structure of Elasticsearch.

## 1. Elasticsearch Data Structure

{{< figure caption="[Figure 1] Data Structure" src="images/elasticsearch-data-structure.png" width="700px" >}}

[Figure 1] shows the Data Structure of Elasticsearch. Elasticsearch Data is composed of three levels: **Index, Type, Document**. Document stores Data in JSON format as a Tree structure. A collection of Documents is called Type. A collection of Types is called Index. Compared to MySQL, Index maps to Database, Type maps to Table, and Document maps to Row/Column.

```json {caption="[Data 1] Document Info", linenos=table}
{
  "-index" : "index",
  "-type" : "type",
  "-id" : "id",
  "-version" : 1,
  "-seq-no" : 0,
  "-primary-term" : 1,
  "found" : true,
  "-source" : {
    "key1" : "value1",
    "key2" : {
      "key3" : "value2"
    }
  }
}
```

[Data 1] shows information about a Document obtained from Elasticsearch. `-index` and `-type` represent the Index and Type to which the Document belongs. `-id` represents the ID of the Document. `-version` represents the Version of the Document, and the value of `-version` increases each time the Document is Updated. `-source` represents the actual Data of the Document.

## 2. References

* [https://www.elastic.co/kr/blog/what-is-an-elasticsearch-index](https://www.elastic.co/kr/blog/what-is-an-elasticsearch-index)


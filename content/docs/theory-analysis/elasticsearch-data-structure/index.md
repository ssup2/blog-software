---
title: Elasticsearch Data Structure
---

Elasticsearch의 Data Structure를 분석한다.

## 1. Elasticsearch Data Structure

{{< figure caption="[Figure 1] Data Structure" src="images/elasticsearch-data-structure.png" width="700px" >}}

[Figure 1]은 Elasticsearch의 Data Sturcture를 나타내고 있다. Elasticsearch의 Data는 **Index, Type, Document** 3단계로 구성되어 있다. Document는 Json 형태의 Tree 구조로 Data를 저장한다. Document의 집합을 Type이라고 명칭한다. Type의 집합을 Index라고 명칭한다. MySQL과 비교하면 Index는 Database, Type은 Table, Document는 Row/Column으로 Mapping된다.

```json {caption="", linenos=table}
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
<figure>
<figcaption class="caption">[Data 1] Document Info</figcaption>
</figure>

[Data 1]은 Elasticsearch로 부터 얻은 Document의 정보를 나타내고 있다. -index, -type은 Document가 소속되어 있는 Index, Type을 나타낸다. -id는 Document의 ID를 나타낸다. -version은 Document의 Version을 나타내며 Document가 Update 될때마다 -version의 값은 증가한다. -source는 Document의 실제 Data를 나타낸다.

## 2. 참조

* [https://www.elastic.co/kr/blog/what-is-an-elasticsearch-index](https://www.elastic.co/kr/blog/what-is-an-elasticsearch-index)
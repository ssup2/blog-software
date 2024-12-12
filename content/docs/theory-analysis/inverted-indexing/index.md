---
title: Inverted Indexing
---

## 1. Inverted Indexing

{{< figure caption="[Figure 1] Inverted Indexing" src="images/db-inverted-indexing.png" width="800px" >}}

Inverted Indexing 기법은 문서에서 특정 단어를 빠르게 찾기 위한 Index를 생성하는 기법이다. [Figure 1]은 Inverted Index를 생성하는 과정과 생성된 Inverted Index를 나타내고 있다. 문서(Document)에서 불용어(stopword)를 제거한 이후에 각 단어(Term)를 알파벳 순서로 정렬한다. 이후에 각 단어가 어느 문서에 존재하는지를 적어두면 Inverted Index 구성이 완료된다.

Inverted Index가 존재하지 않는다면 특정 단어를 찾기 위해서는 모든 문서의 단어를 일일히 하나씩 비교를 해야하지만, Inverted Index를 참조하면 특정 단어가 어느 문서에 있는지 빠르게 검색할 수 있다.

## 2. 참조

*  [https://esbook.kimjmin.net/06-text-analysis/6.1-indexing-data](https://esbook.kimjmin.net/06-text-analysis/6.1-indexing-data)
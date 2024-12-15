---
title: Bloom Filter
---

## 1. Bloom Filter

Bloom Filter는 데이터 집합에 주어진 데이터가 포함되어 있는지를 적은량의 메모리 사용하여 검사하는 알고리즘이다. 일반적으로 데이터 집합에 주어진 데이터가 포함되어 있는지를 검사할때는 Set 자료구조를 활용하여 데이터 집합을 구성한 다음 주어진 데이터가 포함되어 있는지를 확인한다. 하지만 Set 자료구조는 데이터의 개수에 비례하여 메모리 사용량이 증가하기 때문에, 데이터의 개수가 몇백억개에서 몇천억개 정도가 된다면 그만큼 많은양의 메모리를 이용해야 한다. Bloom Filter는 이처럼 데이터의 개수가 많거나 사용할 수 있는 메모리의 용량이 제한되었을때, 적은 용량의 메모리를 사용하면서도 데이터 집합에 주어진 데이터가 존재하는지를 확인할 수 있다.

{{< figure caption="[Figure 1] Creating Bloom Filter" src="images/creating-bloom-filter.png" width="800px" >}}

[Figure 1]은 Bloom Filter를 `ssup`, `hyo`, `eun` 3개의 데이터의 집합을 나타내는 Bloom Filter를 생성하는 과정을 나타내고 있다. Bloom Filter는 Hash 함수와 Bitmap을 활용하여 구성한다. 각각의 데이터를 대상으로 여러개의 Hash Function을 활용하여 Hashing 과정을 수행하며, Hashing 결과로 나온 값을 Bitmap의 자릿수로 활용하여 해당 자리의 값을 1로 설정한다. 모든 데이터에 대해서 Hashing을 수행하고 그 결과를 합하면 Bloom Filter 구성이 완료된다.

{{< figure caption="[Figure 2] Checking Words with Bloom Filter" src="images/checking-words-bloom-filter.png" width="800px" >}}

[Figure 2]는 구성한 Bloom Filter를 활용하여 집합에 주어진 데이터가 존재하는지를 검사하는 과정을 나타내고 있다. Bloom Filter를 구성할때 활용한 다수의 Hash Function을 그대로 활용하여 Hashing을 수행한 결과를 Bitmap의 자릿수로 활용하여 해당 자리에 1이 있는지를 검사한다. 모든 자릿수에 1이 존재하면 데이터가 존재한다는걸 의미하며, 만약 일부 자릿수에 1이 존재하지 않는다면 해당 데이터는 존재하지 않는다는 것을 의미한다. [Figure 2]에서 `none` 데이터의 Hashing 결과의 값으로 `8`, `6`. `1`이 나왔지만 Bloom Filter의 6번째 자릿수는 0이기 때문에 `none` 데이터는 존재하지 않는다.

{{< figure caption="[Figure 3] Bloom Filter False Positive" src="images/bloom-filter-false-positive.png" width="800px" >}}

Bloom Filter는 Bitmap을 활용하는 방식이기 때문에 적은양의 메모리를 이용하며, Hashing을 이용하기 때문에 매우 빠른 연산이 가능하다는 장점을 가지고 있다. 반면에 큰 제약점을 가지고 있는데 바로 **False Positive**, 즉 Bloom Filter에 의해서 데이터가 존재한다라는 결과를 받더라도 실제로 데이터가 존재하지 않을수 있다.

[Figure 3]은 True Netative 현상을 보여주고 있다. `ssup` 데이터 결과와 `fake` 데이터의 결과가 동일할 경우 Bloom Filter에는 `fake` 데이터가 존재하지 않더라도 존재하고 있다라는 결과를 보여주고 있다. 이러한 이유는 Hashing 충돌시에 별다른 처리를 수행하지 않기 때문이다. 만약 Hashing 충돌시 추가적인 메모리를 활용하여 별도의 처리 과정을 수행한다면, 메모리를 절약할 수 있는 Bloom Filter의 특징이 사라지게 된다. 반면에 Bloom Filter를 통해서 존재하지 않는 데이터라고 판정될 경우에는 **100% 확률로 데이터가 존재하지 않는걸** 의미한다. 따라서 Bloom Filter는 `Data가 존재한다는 결과가 나올경우에도 실제로 존재하지 않을 확률이 존재`, `Data가 존재하지 않는다는 결과가 나온다면 100% 확률로 존재하지 않음` 2가지 특징을 가지며, 이러한 특징을 만족시킬수 있는 곳에서만 이용해야한다.

[Figure 1]에서는 3개의 Hash Function과, 12 자리수의 BitMap을 이용하고 있지만 데이터의 개수, False Positive 확률, 메모리 사이즈를 고려하여 Bitmap의 크기를 조정하거나 Hash Function의 개수를 조정할 수 있다. 일반적으로 Bitmap의 크기를 증가시키면 

Cassandra, HBase, Oracle과 같이 Disk에 큰 데이터를 저장하고 관리하는 Database에서 Disk에 데이터 유무를 빠르게 판변하기 위해서 Bloom Filter를 이용하고 있다. Bloom Filter 결과 Data가 없다라고 한다면 Disk에 접근을 수행하지 않으며, Bloom Filter 결과 Data가 있다라고 판단되면 Data가 존재하지 않을수 있는걸 가정하고 Disk에서 탐색 동작을 수행한다. 즉 Bloom Filter를 통해서 Disk 접근을 최소화 하는 용도로 이용하고 있다.

Bloom Filter는 한번 데이터 집합이 구성되면 제거할수 없다는 제약점도 같는다. [Figure 1]에서 구성된 Bloom Filter에서 `hyo` 데이터를 나타내는 Bit를 1에서 0으로 변경한다면 `eun` 데이터도 영향을 받는다는 것을 확인할 수 있다. Bloom Filter의 Data 제거를 못한다는 제약점을 개선한 알고리즘으로 **Cockoo Filter**가 존재한다.

## 2. 참조

* Bloom Filter : [https://meetup.nhncloud.com/posts/192](https://meetup.nhncloud.com/posts/192)
* Bloom Filter : [https://steemit.com/kr-dev/@heejin/bloom-filter](https://steemit.com/kr-dev/@heejin/bloom-filter)
* Bloom Filter : [https://www.youtube.com/watch?v=iA-QtVCPjtE](https://www.youtube.com/watch?v=iA-QtVCPjtE)
* Bloom Filter Calcuator : [https://hur.st/bloomfilter/](https://hur.st/bloomfilter/)
* Cuckoo Filter : [https://brilliant.org/wiki/cuckoo-filter/](https://brilliant.org/wiki/cuckoo-filter/)
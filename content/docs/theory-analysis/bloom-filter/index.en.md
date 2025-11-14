---
title: Bloom Filter
---

## 1. Bloom Filter

Bloom Filter is an algorithm that checks whether given data is included in a data set using a small amount of memory. Generally, when checking whether given data is included in a data set, a Set data structure is used to construct the data set and then check if the given data is included. However, since the Set data structure increases memory usage in proportion to the number of data, if the number of data reaches hundreds of billions to trillions, that much memory must be used. Bloom Filter can check whether given data exists in a data set using a small amount of memory when the number of data is large or the available memory capacity is limited.

{{< figure caption="[Figure 1] Creating Bloom Filter" src="images/creating-bloom-filter.png" width="800px" >}}

[Figure 1] shows the process of creating a Bloom Filter representing a set of 3 data: `ssup`, `hyo`, `eun`. Bloom Filter is constructed using Hash functions and Bitmap. For each data, multiple Hash Functions are used to perform Hashing, and the values resulting from Hashing are used as Bitmap positions to set the value at that position to 1. After performing Hashing on all data and combining the results, Bloom Filter construction is complete.

{{< figure caption="[Figure 2] Checking Words with Bloom Filter" src="images/checking-words-bloom-filter.png" width="800px" >}}

[Figure 2] shows the process of checking whether given data exists in the set using the constructed Bloom Filter. The multiple Hash Functions used when constructing the Bloom Filter are used as-is to perform Hashing, and the results are used as Bitmap positions to check if 1 exists at those positions. If 1 exists at all positions, it means the data exists, and if 1 does not exist at some positions, it means the data does not exist. In [Figure 2], the Hashing result values for `none` data are `8`, `6`, `1`, but since the 6th position of the Bloom Filter is 0, the `none` data does not exist.

{{< figure caption="[Figure 3] Bloom Filter False Positive" src="images/bloom-filter-false-positive.png" width="800px" >}}

Since Bloom Filter uses Bitmap, it has the advantage of using a small amount of memory, and since it uses Hashing, very fast operations are possible. However, it has a major limitation: **False Positive**, meaning that even if Bloom Filter returns a result that data exists, the data may not actually exist.

[Figure 3] shows the False Positive phenomenon. If the results of `ssup` data and `fake` data are the same, Bloom Filter shows that `fake` data exists even though it does not exist. This is because no special processing is performed when Hashing collisions occur. If additional memory is used to perform separate processing when Hashing collisions occur, the characteristic of Bloom Filter that saves memory disappears. On the other hand, if Bloom Filter determines that data does not exist, it **means with 100% probability that the data does not exist**. Therefore, Bloom Filter has two characteristics: `Even if the result shows that data exists, there is a probability that it does not actually exist`, and `If the result shows that data does not exist, it does not exist with 100% probability`, and should only be used in places where these characteristics can be satisfied.

In [Figure 1], 3 Hash Functions and a 12-digit Bitmap are used, but the Bitmap size or the number of Hash Functions can be adjusted considering three variables: the number of data, False Positive probability, and Bitmap size. Increasing the Bitmap size reduces False Positive probability but increases memory usage. For the number of Hash Functions, when the number of Hash Functions is small, False Positive probability decreases as the number of Hash Functions increases, but when the number of Hash Functions is too large, False Positive probability increases conversely. Therefore, setting an appropriate number of Hash Functions and Bitmap size is important, and it is recommended to use [Bloom Filter Calculator](https://hur.st/bloomfilter/) for configuration.

Databases like Cassandra, HBase, and Oracle that store and manage large data on Disk use Bloom Filter to quickly determine data existence on Disk. If Bloom Filter result says data does not exist, Disk access is not performed, and if Bloom Filter result determines that data exists, it assumes that data may not exist and performs search operations on Disk. That is, Bloom Filter is used to minimize Disk access.

Bloom Filter also has the limitation that once a data set is constructed, it cannot be removed. In the Bloom Filter constructed in [Figure 1], if the bit representing `hyo` data is changed from 1 to 0, you can see that `eun` data is also affected. **Cuckoo Filter** is an algorithm that improves the limitation that Bloom Filter cannot remove data.

## 2. References

* Bloom Filter : [https://meetup.nhncloud.com/posts/192](https://meetup.nhncloud.com/posts/192)
* Bloom Filter : [https://steemit.com/kr-dev/@heejin/bloom-filter](https://steemit.com/kr-dev/@heejin/bloom-filter)
* Bloom Filter : [https://www.youtube.com/watch?v=iA-QtVCPjtE](https://www.youtube.com/watch?v=iA-QtVCPjtE)
* Bloom Filter Calcuator : [https://hur.st/bloomfilter/](https://hur.st/bloomfilter/)
* Cuckoo Filter : [https://brilliant.org/wiki/cuckoo-filter/](https://brilliant.org/wiki/cuckoo-filter/)


---
title: Consistent Hashing
---

## 1. Consistent Hashing

{{< figure caption="[Figure 1] Consistent Hashing" src="images/consistent-hashing.png" width="900px" >}}

Consistent Hashing is one of the Hashing Algorithms. When using Hashing as a **distribution algorithm**, Consistent Hashing is generally used a lot. [Figure 1] compares Modular Hashing, which is generally the most used, with Consistent Hashing. In the case of Modular Hashing, when the number of Buckets changes, most Keys belonging to Buckets also move through the Rebalancing process. This movement of many Keys causes performance degradation.

For example, if Data is Sharded and stored across multiple Disks based on Modular Hashing, a lot of Data movement occurs whenever Disks are added/removed. Consistent Hashing is a Hashing Algorithm created to minimize Key movement when Buckets are added/removed to solve this problem. Consistent Hashing moves an average of **(total number of Keys)/(total number of Buckets)** Keys when Buckets are added/removed.

### 1.1. Ring Consistent Hashing

{{< figure caption="[Figure 2] Ring Consistent Hashing" src="images/ring-consistent-hashing.png" width="900px" >}}

Ring Consistent Hashing is the Hashing Algorithm that first introduced the term Consistent Hashing. [Figure 2] shows Ring Consistent Hashing. Ring Consistent Hashing uses a Ring composed of Hashing result values called **Hash Ring**. Here, Hashing can be understood as Modular Hashing. In [Figure 2], Hash Ring has values from 0 to 15. And **vBucket (vNode)**, which means a virtual Bucket, is located between Hash Rings.

Ring Consistent Hashing assigns Keys to the vBucket first encountered when moving clockwise on the Hash Ring. In [Figure 2], when Bucket size is 3, assuming the Hashing result of character 'a' is '1', '1' first encounters the vBucket of Bucket 2 when moving clockwise from '1', so character 'a' is assigned to Bucket 2.

When Buckets are added/removed, vBuckets existing in Hash Ring are also added/removed. In this case, you can see that most characters remain in their Buckets without moving. In [Figure 2], when Bucket size increases from 3 to 4, character 'a' moves to Bucket 3 because vBucket of Bucket 3 was added between '1' ~ '2'. On the other hand, character 'e' remains in Bucket 2.

Multiple vBuckets are mapped to one Bucket, and the reason vBuckets are needed is to evenly distribute Keys to each Bucket. If you think that only 3~4 Buckets exist in the Hash Ring of [Figure 2], you can see that characters may concentrate on specific Buckets. Generally, more than 1000 vBuckets are created per Bucket. By adjusting the ratio of Bucket and vBucket for each Bucket, each Bucket can have Keys at **different ratios (Weight)**.

If many vBuckets are created so that vBuckets are located between most values of Hash Ring, the Hashing time complexity becomes **O(1)**.

### 1.2. Jump Consistent Hashing

{{< figure caption="[Figure 3] Jump Consistent Hashing" src="images/jump-consistent-hashing.png" width="900px" >}}

Jump Consistent Hashing is a Hashing Algorithm created **to reduce the Memory space** used by Ring Consistent Hashing for vBucket allocation. [Figure 3] shows Jump Consistent Hashing. In Jump Consistent Hashing, Keys start from '-1' and continuously Jump by random distances. When Jump exceeds Bucket size, **the position before exceeding Bucket size** becomes the Key's Bucket.

In [Figure 3], when Bucket size is 7, character 'c' Jumps from position 3 and moves to position 7 at once. Since Bucket size is 7, position 7 is a position that exceeds Bucket size. Therefore, character 'c' is located in Bucket 3. When Bucket size increases to 8, position 7 is included in Bucket size. After that, since the next jump exceeds Bucket size, character 'c' is included in Bucket 7.

The Jump distance for each Key is Random, and Key is used as the Seed of Random. This means that each Key performs Jump at different distances, but Jump distance does not change according to Bucket size. In [Figure 3], you can see that even when Bucket size changes, Jump distance is the same for each character (Key). When Buckets are added/removed, only Jumps that exceed Bucket size are affected, so you can see that only Keys of related Buckets move.

Jump Consistent Hashing does not need to store all Jump processes of each Key, but only needs to remember the position before exceeding Bucket size, so it does not need the concept of vBucket like Ring Consistent Hashing, and uses less Memory space compared to Ring Consistent Hashing. However, unlike Ring Consistent Hashing, each Bucket cannot have Keys at different ratios. The Hashing time complexity is **O(ln(n))**.
## 2. References

* Ring Consistent Hashing : [https://dl.acm.org/doi/abs/10.1145/258533.258660](https://dl.acm.org/doi/abs/10.1145/258533.258660)
* Ring Consistent Hashing : [https://www.secmem.org/blog/2021/01/24/consistent-hashing/](https://www.secmem.org/blog/2021/01/24/consistent-hashing/)
* Jump Consistent Hashing : [https://arxiv.org/ftp/arxiv/papers/1406/1406.2294.pdf](https://arxiv.org/ftp/arxiv/papers/1406/1406.2294.pdf)
* [https://www.joinc.co.kr/w/man/12/hash/consistent](https://www.joinc.co.kr/w/man/12/hash/consistent)
* [https://itnext.io/introducing-consistent-hashing-9a289769052e](https://itnext.io/introducing-consistent-hashing-9a289769052e)
* [https://www.popit.kr/consistent-hashing/](https://www.popit.kr/consistent-hashing/)
* [https://www.secmem.org/blog/2021/01/24/consistent-hashing/](https://www.secmem.org/blog/2021/01/24/consistent-hashing/)
* [https://www.popit.kr/jump-consistent-hash/](https://www.popit.kr/jump-consistent-hash/)


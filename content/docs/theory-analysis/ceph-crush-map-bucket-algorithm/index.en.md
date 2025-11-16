---
title: Ceph CRUSH Map, Bucket Algorithm
---

Analyzes CRUSH Map, which represents Storage Topology in Ceph, and analyzes Bucket algorithms used by Bucket, which is an element that constitutes CRUSH Map, when selecting subordinate Buckets.

## 1. Ceph CRUSH Map

{{< figure caption="[Figure 1] Ceph PG, CRUSH" src="images/ceph-pg-crush.png" width="700px" >}}

Ceph uses **CRUSH** as an algorithm to place Objects on OSD (Object Storage Daemon) of RADOS Cluster. [Figure 1] shows the process of Objects being placed on OSDs through CRUSH. Objects are allocated to specific PG (Placement Group) through Hashing of Object ID. And PG is again allocated to specific OSD through PG ID and CRUSH. [Figure 1] assumes that Replica is set to 3. Therefore, CRUSH allocates 3 OSDs per Object.

{{< figure caption="[Figure 2] Ceph CRUSH Map" src="images/ceph-crush-map.png" width="800px" >}}

CRUSH uses Storage Topology called **CRUSH Map**. [Figure 2] shows CRUSH Map. CRUSH Map is composed of a hierarchy of logical units called **Bucket**. Bucket consists of 11 types: root, region, datacenter, room, pod, pdu, row, rack, chassis, host, and osd. The Leaf of CRUSH Map must be an osd bucket.

Each Bucket has a **Weight** value, and Weight represents the proportion of Objects that each Bucket has. If Bucket A's Weight is 100 and Bucket B's Weight is 200, it means Bucket B has twice as many Objects as Bucket A. Therefore, generally, the Weight value of osd Bucket Type is set in proportion to the capacity of the Disk managed by OSD. The weight of the remaining Bucket Types is the sum of the Weights of all subordinate Buckets. The numbers inside Buckets in [Figure 2] represent Weight.

CRUSH starts from CRUSH Map's root Bucket, selects subordinate Buckets as many as the Replica count, and repeats the same operation in selected Buckets to find osd Bucket at Leaf. The Replica count of Objects is determined according to Replica set in Bucket Type. If 3 Replicas are set in Rack Bucket Type and 2 Replicas are set in Row Bucket Type, CRUSH selects 3 Rack Buckets and selects 2 Row Buckets per Rack Bucket, which are subordinate Buckets of selected Rack Buckets, so Object's Replica becomes 6. The criterion for selecting subordinate Buckets is determined according to Bucket algorithm set in each Bucket Type.

## 2. Bucket Algorithm

{{< table caption="[Table 1] Bucket Algorithm Performance Comparison" >}}
| | Uniform | List | Tree | Straw | Straw2 |
|----|----|----|----|----|----|
| Object Allocation | O(1) | O(n) | O(log n) | O (n) | O (n) |
| Subordinate Bucket Addition | Poor | Optimal | Good | Good | Optimal |
| Subordinate Bucket Deletion | Poor | Poor | Good | Good | Optimal |
| Subordinate Bucket Weight Change | X | Poor | Good | Good | Optimal |
{{< /table >}}

Bucket can select a Bucket algorithm to select its subordinate Buckets. Algorithms include Uniform, List, Tree, Straw, and Straw2, and each algorithm has advantages and disadvantages. The default algorithm uses Straw2. [Table 1] compares the performance of each algorithm.

### 2.1. Uniform

```cpp {caption="[Code 1] uniform() function", linenos=table}
cbucket uniform(bucket, pg_id, replica) {
    return bucket->cbuckets[hash(pg_id, bucket->id, replica) % length(bucket->cbuckets)];
}
```

* cbucket : Represents the subordinate Bucket selected through Uniform algorithm.
* bucket : Represents the parent Bucket.
* pg_id : Represents the ID of PG that has the Object to place.
* replica : Represents Replica. 0 represents Primary Replica.

Uniform algorithm selects subordinate Buckets using **Consistency Hashing**. [Code 1] briefly shows the uniform() function that selects subordinate Buckets using Uniform algorithm. Since Hashing needs to be performed only once, subordinate Buckets can be found in O(1) time. However, even when using Consistency Hashing, when subordinate Buckets are added or removed, many PGs are relocated to other subordinate Buckets. Therefore, many Objects are Rebalanced. All subordinate Buckets of Uniform algorithm have the same Weight. That is, Uniform algorithm cannot apply different Weights to each subordinate Bucket. Even if Weight values are set, they are ignored. To apply different Weights to each subordinate Bucket, other Bucket algorithms must be used.

### 2.2. List

{{< figure caption="[Figure 3] Weight Linked List used in List Algorithm" src="images/crush-list-bucket.png" width="700px" >}}

```cpp {caption="[Code 2] init_sum_weights() function", linenos=table}
init_sum_weights(cbucket_weights, sum_weights) {
    sum_weights[0] = cbucket_weights[0];

    for (i = 1; i < length(cbucket_weights); i++) {
        sum_weights[i] = sum_weights[i - i] + cbucket_weights[i];
    }
}
```

* cbucket_weights : Represents the Weight values of subordinate Buckets set in CRUSH Map.
* sum_weights : Represents the sums of cbucket_weights according to List algorithm.

List algorithm manages subordinate Buckets using **Linked List**. To perform Link algorithm, a Linked List like [Figure 3] must be prepared based on Weight information of subordinate Buckets in CRUSH Map. [Code 2] briefly shows the init_sum_weights() function that initializes the sum_weights Linked List of [Figure 3].

```cpp {caption="[Code 3] list() function", linenos=table}
cbucket list(bucket, pg_id, replica) {
    for (i = length(bucket->cbuckets) - 1; i > 0; i--) {
        tmp = hash(pg_id, bucket->cbuckets[i]->id, replica)
        if ( tmp < (cbucket_weights[i] / sum_weights[i]) ) {
            return bucket->cbuckets[i];
        }
    }

    return bucket->cbuckets[0];
}
```

* cbucket : Represents the subordinate Bucket selected through List algorithm.
* bucket : Represents the parent Bucket.
* pg_id : Represents the ID of PG that has the Object to place.
* replica : Represents Replica. For Primary Replica, 0 is used.

[Code 3] shows the list() function that performs Link algorithm using initialized cbucket_weights Linked List and sum_weights Linked List. list() function moves from the end of Linked List to the beginning and allocates PG in proportion to subordinate Bucket's Weight. Since Hashing must be performed as many times as the length of Linked List, which is the number of subordinate Buckets, it takes O(N) time to find subordinate Buckets.

{{< figure caption="[Figure 4] Case when Subordinate Bucket is Added to List" src="images/crush-list-bucket-add.png" width="750px" >}}

[Figure 4] shows the case when a subordinate Bucket is added to Linked List. The added Bucket is attached to the end of Linked List and becomes the Bucket that is first checked for placement when Link algorithm is performed. When a subordinate Bucket is added, **PG is placed in the added Bucket or remains in the existing Bucket.** This is because existing sum_weights values do not change even when subordinate Buckets are added. Therefore, only a small number of Objects are Rebalanced.

{{< figure caption="[Figure 5] Case when Subordinate Bucket is Removed from List" src="images/crush-list-bucket-remove.png" width="650px" >}}

[Figure 5] shows the case when a subordinate Bucket is removed from Linked List. [Figure 5] shows when subordinate Bucket 1 is removed. When a subordinate Bucket is removed, existing sum_weights values also change, causing many PGs to be placed in other subordinate Buckets. Therefore, many Objects are Rebalanced. When subordinate Bucket's Weight is changed, sum_weights values also change, causing many Objects to be Rebalanced.

### 2.3. Tree

{{< figure caption="[Figure 6] Binary Tree used in Tree Algorithm" src="images/crush-tree.png" width="800px" >}}

Tree algorithm manages subordinate Buckets in Binary Tree form. [Figure 6] shows the Binary Tree used in Tree algorithm. Tree is constructed using arrays but is not constructed like a typical Binary Search Tree. Each Tree's Level's Index has **(Odd) * (2 ^ Level)**. Each Leaf of Tree has a subordinate Bucket. Each Node of Tree stores the sum of Weights existing in all its subordinate Nodes.

```cpp {caption="[Code 4] tree() function", linenos=table}
cbucket tree(bucket, pg_id, replica) {
    level = log2(length(array));
    index = length(array) / 2;

    for(i = 0; i < level - 1; i++) {
        if (hash(pg_id, bucket->id, index, replica) < 
            (array[get_left(index)]->weight/array[index]->weight)) {
            index = get_left(index);
        } else {
            index = get_rigth(index);
        }
    }

    return array[index]->bucket;
}
```

* cbucket : Represents the subordinate Bucket selected through Tree algorithm.
* bucket : Represents the parent Bucket.
* array : Represents the array that stores subordinate Buckets as Binary Tree.
* pg_id : Represents the ID of PG that has the Object to place.
* replica : Represents Replica. For Primary Replica, 0 is used.

[Code 4] shows the tree() function that performs Tree algorithm using initialized Binary Tree. It searches Binary Tree starting from Root Node and places PG in proportion to Weight. Since Hashing must be performed as many times as the height of Binary Tree, it takes O(log N) time to find subordinate Buckets.

{{< figure caption="[Figure 7] Case when Subordinate Bucket is Added to Tree" src="images/crush-tree-add.png" width="900px" >}}

[Figure 7] shows when a subordinate Bucket is added to Binary Tree. **Even when Bucket is added to Binary Tree, only some Nodes' Weights change, so only some PGs are relocated and the remaining PGs are allocated to existing Buckets.** Therefore, only a small number of Objects are Rebalanced. When subordinate Buckets are deleted or subordinate Bucket's Weight is changed, only some Nodes' Weights change, so only a small number of Objects are Rebalanced.

### 2.4. Straw2

```cpp {caption="[Code 5] straw2() function", linenos=table}
cbucket straw2(bucket, pg_id, replica) {
    max_index = 0;
    max_draw = 0;

    for (i = 0; i < length(bucket->cbuckets); i++) {
        draw = dist(pg_id, bucket->cbuckets[i]->id, replica, bucket->cbuckets[i]->weight);
        if (draw > max_draw) {
            max_index = i;
            max_draw = draw;
        }
    }

    return bucket->cbuckets[max_index];
}
```

* cbucket : Represents the subordinate Bucket selected through Tree algorithm.
* bucket : Represents the parent Bucket.
* pg_id : Represents the ID of PG that has the Object to place.
* replica : Represents Replica. For Primary Replica, 0 is used.

straw2 algorithm calculates the value obtained by using **dist()** function on subordinate Bucket ID and multiplying it by subordinate Bucket's Weight for all subordinate Buckets. It allocates PG to the Bucket with the largest value among the calculated values. dist() function generates Random values like hash() function, but it is a function where the probability of generating larger Random values increases as Weight value increases. [Code 5] shows the straw2() function that performs Straw2 algorithm. Since Hashing must be performed as many times as the number of subordinate Buckets, it takes O(N) time to find subordinate Buckets.

{{< figure caption="[Figure 8] Case when Subordinate Bucket is Added to Straw2" src="images/crush-straw2-add.png" width="700px" >}}

[Figure 8] shows the case when a subordinate Bucket is added to Straw2. Even when subordinate Buckets are added, **PG is placed in the new Bucket or remains in the existing Bucket.** Therefore, only a small number of Objects are Rebalanced. Even when existing Buckets are deleted, only PGs that were placed in deleted Buckets are relocated and existing PGs remain, so only a small number of Objects are Rebalanced. When Bucket's Weight is changed, PGs placed in the Bucket with changed Weight may be relocated to other Buckets, or PGs placed in other Buckets may be relocated to the Bucket with changed Weight. However, since PGs are not relocated between Buckets that did not change Weight, only a small number of Objects are Rebalanced even when Bucket's Weight is changed.

### 2.5. Straw

```cpp {caption="[Code 6] straw() function", linenos=table}
cbucket straw(bucket, pg_id, replica) {
    max_index = 0;
    max_draw = 0;

    for (i = 0; i < length(bucket->cbuckets); i++) {
        draw = hash(pg_id, bucket->cbuckets[i]->id, replica) * 
            bucket->cbuckets[i]->straw;
        if (draw > max_draw) {
            max_index = i;
            max_draw = draw;
        }
    }

    return bucket->cbuckets[max_index];
}
```

* cbucket : Represents the subordinate Bucket selected through Tree algorithm.
* bucket : Represents the parent Bucket.
* pg_id : Represents the ID of PG that has the Object to place.
* replica : Represents Replica. For Primary Replica, 0 is used.

Straw algorithm calculates the value obtained by Hashing subordinate Bucket ID and multiplying it by subordinate Bucket's **Straw** for all subordinate Buckets. It allocates PG to the Bucket with the largest value among the calculated values. [Code 6] shows the straw() function that performs Straw algorithm. Straw value is calculated by sorting subordinate Buckets in ascending order by Weight, then using the Weight value of the subordinate Bucket for which Straw value is to be calculated and the Weight value of the immediately preceding subordinate Bucket. For example, when there are 3 subordinate Buckets A/1.0, B/3.0, C/2.5, they are sorted in A, C, B order according to Weight. Then, to calculate C Bucket's Straw value, C Bucket's Weight value and A Bucket's Weight value are used.

The fact that calculating subordinate Bucket's Straw value uses not only that Bucket's Weight but also other subordinate Buckets' Weights means that when subordinate Buckets are added, deleted, or existing Bucket's Weight is changed, up to 3 Straw values can change. Straw algorithm was designed to minimize Object Rebalancing even when subordinate Buckets change, but it did not properly achieve its goal due to Side Effects in the process of calculating Straw values. The algorithm that came out to solve this problem is straw2.

## 3. References

* [http://www.nminoru.jp/~nminoru/unix/ceph/rados-overview.html#mapping](http://www.nminoru.jp/~nminoru/unix/ceph/rados-overview.html#mapping)
* [https://github.com/ceph/ceph/blob/master/src/crush/mapper.c](https://github.com/ceph/ceph/blob/master/src/crush/mapper.c)
* [https://github.com/ceph/ceph/blob/master/src/crush/builder.c](https://github.com/ceph/ceph/blob/master/src/crush/builder.c)
* [https://my.oschina.net/linuxhunter/blog/639016](https://my.oschina.net/linuxhunter/blog/639016)


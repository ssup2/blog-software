---
title: CRUSH Controlled, Scalable, Decentralized Placement of Replicated Data
---

## 1. Summary

This explains CRUSH, which is used as an algorithm for distributing objects (data) to storage devices in CEPH.

## 2. CRUSH

CRUSH is an algorithm that distributes objects to each storage device in proportion to the weight of each storage device. Here, the meaning of object distribution also includes object replicas. If CEPH needs to maintain 3 replicas, CRUSH determines 3 storage devices where objects will be stored. CRUSH distributes objects based on a map called **Cluster Map** that represents the hierarchy of logical storage devices.

### 2.1. Cluster Map

Cluster Map is a map that represents the **hierarchy** of logical storage devices. If there is a storage server room, the storage server room has multiple server cabinets, each server cabinet has disk racks, and each disk rack has multiple disks. The Cluster Map is a logical representation of this physical storage device structure.

{{< table caption="[Table 1] CRUSH Map Example" >}}
|| Action | Resulting |
|---|---|
|| take(root) | root |
|| select(1, row) | row2 |
|| select(3, cabinet) | cab21 cab23 cab24 |
|| select(1, disk) | disk2107 disk2313 disk2437 |
|| emit |  |
{{< /table >}}

Based on the hierarchy information of the Cluster Map, CEPH administrators can freely set the placement of replicas. Replicas can be placed on the same disk rack, on different disk racks, or on different server cabinets. These replica placement settings allow replicas to be stored more safely physically. It would be safer to place replicas on server cabinets that use different power sources rather than placing them on disk racks that use the same power source. [Table 1] shows the process of CRUSH selecting 3 replicas at the server cabinet level.

Cluster Map consists of **Buckets** and **Devices**. Buckets are logical groups, and in [Table 1], they can be server cabinets or disk racks. Buckets can have sub-buckets or sub-devices. Devices represent actual disks, and disks can only be located at the leaves of the Cluster Map. Buckets and Devices can each have a **Weight**. The weight of a bucket is the sum of the weights of sub-buckets or sub-disks. Generally, weights are set in proportion to the capacity of sub-devices. Therefore, the weight value of a bucket is proportional to the disk capacity belonging to the bucket.

The criteria for selecting sub-buckets or sub-devices in each bucket differ depending on the **Weight** and **Bucket Type** of the sub-buckets or sub-devices.

### 2.2. Bucket Type

Bucket Type refers to the way of managing items (sub-buckets, sub-devices). There are 4 types of Bucket Types: Uniform, List, Tree, and Straw.

#### 2.2.1. Uniform

Uniform Bucket manages sub-items using **Consistency Hashing**. Since it is hash-based, sub-items can be found in O(1) time. However, when items are added or removed, the hashing results change, so rebalancing takes a lot of time. Uniform Bucket proceeds under the assumption that all buckets have the same weight. If you want to give different weights to each bucket, you need to use a different bucket type.

#### 2.2.2. List

List Bucket manages sub-items using a **Linked List**. When finding sub-items, it takes O(n) time because the linked list must be traversed. Therefore, it has the disadvantage of slow search time when the number of sub-items increases. Traversal starts from the front of the linked list. Whether to use the selected item is determined based on the weight of the selected item and the sum of all weights behind the selected item. If the selected item is not used, the next item in the linked list is selected and the same algorithm is repeated.

When items are added to the linked list, they are added to the very front of the linked list. When items are added, only some of the existing items' sub-items need to be moved to the added item's sub-items, so relatively fast rebalancing is possible. However, when items in the middle or end of the linked list are removed or item weights are changed, rebalancing takes a lot of time because sub-items need to be moved overall.

#### 2.2.3. Tree

Tree Bucket uses a **Weighted Binary Search Tree** for sub-items. Sub-items are attached to the end of the tree. Since it is tree-based, sub-item search takes O(log n) time. The Left/Right Weight of the tree is equal to the sum of the weights of all items belonging to the Left/Right Subtree.

When items are added, removed, or item weights are changed in the tree, only some items' sub-items need to participate in rebalancing because it only affects some weights of the Weighted Binary Search Tree. Therefore, relatively fast rebalancing is possible.

#### 2.2.4. Straw

Straw Bucket is a method of drawing straws for each sub-item and **selecting the item with the longest straw length**. The length of the straw uses **hashing that is affected by each item's weight**. The higher the item's weight, the higher the probability of being assigned a long straw. Since hashing must be performed for all sub-items, it takes O(n) time to select sub-items.

Even if items are added, removed, or item weights are changed in Straw, only sub-items belonging to affected items need to perform rebalancing because it uses the hashing method performed for each item. Therefore, fast rebalancing is possible.

## 3. References

* [https://ceph.com/wp-content/uploads/2016/08/weil-crush-sc06.pdf](https://ceph.com/wp-content/uploads/2016/08/weil-crush-sc06.pdf)
* [http://docs.ceph.com/docs/jewel/rados/operations/crush-map/](http://docs.ceph.com/docs/jewel/rados/operations/crush-map/)
* [http://www.lamsade.dauphine.fr/~litwin/cours98/Doc-cours-clouds/ceph-2009-02%5B1%5D.pdf](http://www.lamsade.dauphine.fr/~litwin/cours98/Doc-cours-clouds/ceph-2009-02%5B1%5D.pdf)

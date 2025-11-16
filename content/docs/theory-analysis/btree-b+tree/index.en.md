---
title: B-tree, B+ tree
---

Analyzes B-Tree and B+ Tree, which are widely used in Filesystems or DBs that mainly use Disk.

## 1. B-tree

{{< figure caption="[Figure 1] B-tree" src="images/btree.png" width="1000px" >}}

B-tree is a Tree that extends Binary Search Tree, where each Node can have multiple Keys and multiple Children. Also, all Leaf Nodes have the same Depth. [Figure 1] shows a 3 Order B-Tree. For N Order B-Tree, each Node can have N-1 Keys and up to N Children. Therefore, in 3 Order B-Tree, each Node can have up to 2 Keys and up to 3 Children.

Each Node has multiple Keys and also has Data corresponding to each Key. Keys are sorted in a form similar to Binary Search and placed in each Node. In Binary Search, the Key of the right Child Node is smaller than itself and the Key of the left Child Node is larger than itself, and similar rules apply to each Key in B-Tree as well.

In [Figure 1], you can see that the left Node of the Node with Keys 11 and 25 only stores Keys smaller than 11. Also, the middle Child only has Keys between Keys 11 and 25. Finally, you can see that the right Node only stores Keys larger than Key 25. Due to the characteristic of having multiple Keys in one Node, using B-Tree is advantageous over Binary Search Tree in Disk environments where Data is Read/Write in large Block units.

## 2. B+ tree

{{< figure caption="[Figure 2] B+tree" src="images/b+tree.png" width="1000px" >}}

B+ Tree is a data structure that improves B-Tree. Like B-tree, all Leaf Nodes have the same Depth. The biggest difference from B-Tree is that Inner Nodes only store Keys, and Leaf Nodes store both Keys and Data. Since Data is only stored in Leaf Nodes, connecting Leaf Nodes with Links (Pointers) to enable easier traversal compared to B-Tree is also a characteristic of B+ Tree.

[Figure 2] shows a 4 Order B+ Tree. It shows that Inner Nodes only have Keys, and Leaf Nodes have both Keys and Data. You can also see that Links are connected between Leaf Nodes. For N Order B+ Tree, each Node can have N-2 Keys and N-1 Children. Therefore, for 4 Order B+ Tree, each Node can have up to 2 Keys and up to 3 Children.

Keys are sorted in a form similar to B-Tree and placed in each Node. However, since B+ Tree Nodes only store Data in Leaf Nodes, parent Nodes of Leaf Nodes have the characteristic of storing some Keys of Leaf Nodes. In [Figure 2], you can see that the parent Node of the Node with Key 11 and the Node with Key 25 has Keys 11 and 25.

B+ Tree's Inner Nodes are smaller in capacity compared to B-Tree's Inner Nodes because they have no Data. This allows more Inner Nodes to be placed in one Disk Block, so relatively fewer Disk Blocks need to be read during Key search compared to B-Tree. Due to this advantage, B+ Tree generally shows better performance than B-Tree during Key search.

## 3. References

* [https://www.slideshare.net/MahediMahfujAnik/database-management-system-chapter12](https://www.slideshare.net/MahediMahfujAnik/database-management-system-chapter12)
* [https://stackoverflow.com/questions/870218/differences-between-b-trees-and-b-trees](https://stackoverflow.com/questions/870218/differences-between-b-trees-and-b-trees)
* [http://potatoggg.tistory.com/174](http://potatoggg.tistory.com/174)


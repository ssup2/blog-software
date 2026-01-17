---
title: Java Collections Framework (JCF)
---

This document analyzes Interfaces and Classes provided by the Java Collections Framework.

## 1. Collection Interface

{{< figure caption="[Figure 1] Java Collection Interface Relationship Diagram" src="images/collection-interface.png" width="1000px" >}}

The Collection Interface performs the role of a framework that provides Interfaces for managing Object Groups. [Figure 1] shows the relationship diagram of the Collection Interface.

### 1.1. Interface

#### 1.1.1. Collection

The Collection Interface provides **basic** Interfaces necessary for **Object Group** management. It provides Methods such as Group size (size()), Object addition (add()), Object deletion (remove()), Iterator (Iterator()), etc.

#### 1.1.2. Set

The Set Interface provides Interfaces necessary for managing Object Groups that **do not have identical Objects**. Since it currently only provides Methods inherited from the Collection Interface, it has the same Methods as the Collection Interface.

#### 1.1.3. SortedSet, NavigableSet

The SortedSet and NavigableSet Interfaces provide Interfaces necessary for managing Object Groups that are **sorted without having identical Objects**. In addition to Methods inherited from the Set Interface, they include additional Methods that take advantage of sorting. They have additional Methods such as the largest Object (head()), the smallest Object (tail()), and ranges (subSet(), headSet(), tailSet()).

#### 1.1.4. List

The List Interface provides Interfaces necessary for managing **Indexed** Object Groups. It allows duplicate Objects. In addition to Methods inherited from the Collection Interface, it includes additional Methods that take advantage of indexing. It has additional Methods such as position-based access (get(index)) and search (indexOf(), lastIndexOf()).

#### 1.1.5. Queue

The Queue Interface provides Interfaces necessary for managing Object Groups that **perform Queue data structure operations**. It allows duplicate Objects. In addition to Methods inherited from the Collection Interface, it has additional Methods for performing Queueing operations. It has additional Methods such as Push (offer()) and Pop (poll()).

#### 1.1.6. Dequeue

The Dequeue Interface provides Interfaces necessary for managing Object Groups that **perform Dequeue data structure operations**. It allows duplicate Objects. It has additional Methods such as inserting Objects at the front of the Queue (addFirst()), deleting (removeFirst()), inserting Objects at the back of the Queue (addLast()), and deleting (removeLast()).

### 1.2. Class

#### 1.2.1. HashSet

A Class that implements the Set Interface using **Hashtable + Chaining**. It shows fast Object insertion/deletion speeds. HashSet does not guarantee traversal in insertion order when iterating.

#### 1.2.2. LinkedHashSet

Unlike HashSet, LinkedHashSet performs traversal in Object insertion order. It **additionally uses a Double Linked List** to manage Object insertion order. However, due to Overhead from the Double Linked List, it shows relatively slow Object insertion/deletion speeds compared to HashSet.

#### 1.2.3. TreeSet

A Class that implements the SortedSet Interface using a **Red-Black Tree**. Although much Overhead occurs when inserting/removing Objects due to the Red-Black Tree, it shows fast Object search speeds.

#### 1.2.4. ArrayList

A Class that implements the List Interface using an **Array**. Since it is Array-based, Index-based Object access is very fast, but it has the disadvantage of being slow when inserting/deleting Objects due to Object Shift operations. It is also slow when changing Array size due to Object Copy operations.

#### 1.2.5. Vector

Vector is similar to ArrayList but is inefficient in Single Thread environments because all Methods have the **synchronized** keyword attached for synchronization. It is a Class that appeared before ArrayList and is not commonly used now, existing for backward compatibility.

#### 1.2.6. LinkedList

A Class that implements the List Interface, Queue Interface, and Dequeue Interface using a **LinkedList**. Since it is LinkedList-based, Object insertion/deletion is faster compared to ArrayList. However, it is slow for Index-based Object access or Object search due to traversal operations.

#### 1.2.7. PriorityQueue

A Class that implements the Queue Interface using a **Heap**. Using the Heap's sorting functionality, Objects with the highest Priority can be obtained quickly.

#### 1.2.8. ArrayDequeue

A Class that implements the Dequeue Interface using an **Array**. It has the same characteristics as ArrayList, which is Array-based.

## 2. Map Interface

{{< figure caption="[Figure 2] Java Collection Interface Relationship Diagram" src="images/map-interface.png" width="700px" >}}

The Map Interface performs the role of a framework that provides Interfaces for managing Key-Value Groups. [Figure 2] shows the relationship diagram of the Map Interface.

### 2.1. Interface

#### 2.1.1. Map

The Map Interface provides **basic** Interfaces necessary for **key-Value Group** management. Keys cannot be duplicated. It provides Methods such as Group size (size()), Key-Value addition (put()), Value retrieval (get()), Key-Value deletion (remove()), Set Interface retrieval (entrySet(), keySet()), etc. The Map Interface does not provide an Iterator. Use the Iterator of the Set Interface obtained through the entrySet() and ketSet() Methods.

#### 2.1.1. SortedMap, NavigableMap

The SortedMap and NavigableMap Interfaces provide Interfaces necessary for managing Key-Value Groups that are **sorted by Key without having identical Keys**. In addition to Methods inherited from the Map Interface, they include additional Methods that take advantage of sorting. They have additional Methods such as the largest Key (firstKey()), the smallest Key (lastKey()), and ranges (subMap(), headMap(), tailMap()).

### 2.2. Class

#### 2.2.1. HashMap

A Class that implements the Map Interface using **Hashtable + Chaining** based on Key. One Null can be entered for Key, and Null can also be entered for Value. Also, HashMap does not guarantee traversal in insertion order when iterating. HashMap Methods are not synchronized. Therefore, problems occur when used in Multi-Thread environments. In Multi-Thread environments, use the ConcurrentHashMap Class.

#### 2.2.2. LinkedHashMap

Unlike HashMap, LinkedHashMap performs traversal in Key-Value insertion order. It **additionally uses a Double Linked List** to manage Key-Value insertion order. However, due to Overhead from the Double Linked List, it shows relatively slow Key-Value insertion/deletion speeds compared to HashMap.

#### 2.2.3. HashTable

HashTable is similar to HashMap but is inefficient in Single Thread environments because all Methods have the synchronized keyword attached for synchronization. Null cannot be entered for Key and Value. Since Lock Granularity is larger than ConcurrentHashMap, performance is slow. It is a Class that appeared before HashMap and ConcurrentHashMap and is not commonly used now, existing for backward compatibility.

#### 2.2.4. EnumMap

A Class that implements the Map Interface using **Enum** as Key. Since Key is Enum, the values that can be entered as Key are very limited. Therefore, EnumMap allocates and uses an **Array** with the same length as the number of Enums. Since it uses a fixed-length Array, Resize does not occur, and O(1) complexity is always guaranteed.

#### 2.2.5. TreeMap

A Class that implements the SortedMap Interface using a **Red-Black Tree** based on Key. Although much Overhead occurs when inserting/removing Key-Values due to the Red-Black Tree, it shows fast Key search speeds.

## 3. References

* Java Collection Cheat Sheet : [http://pierrchen.blogspot.kr/2014/03/java-collections-framework-cheat-sheet.html](http://pierrchen.blogspot.kr/2014/03/java-collections-framework-cheat-sheet.html)
* [http://java-latte.blogspot.kr/2013/09/java-collection-arraylistvectorlinkedli.html](http://java-latte.blogspot.kr/2013/09/java-collection-arraylistvectorlinkedli.html)
* [https://docs.oracle.com/javase/tutorial/collections/interfaces/index.html](https://docs.oracle.com/javase/tutorial/collections/interfaces/index.html)
* [https://stackoverflow.com/questions/12646404/concurrenthashmap-and-hashtable-in-java](https://stackoverflow.com/questions/12646404/concurrenthashmap-and-hashtable-in-java)
* [http://www.programering.com/a/MDMyMzMwATQ.html](http://www.programering.com/a/MDMyMzMwATQ.html)


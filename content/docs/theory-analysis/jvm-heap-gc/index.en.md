---
title: JVM Heap, GC (Garbage Collection)
---

## 1. JVM Heap

{{< figure caption="[Figure 1] JVM Heap" src="images/jvm-heap.png" width="500px" >}}

**JVM Heap** is the Memory area where Objects (Instances) allocated mainly through the `new` syntax are located. The JVM Heap is divided into three areas: Young Generation, Old Generation, and Permanent. The Young Generation is the area where recently created Objects are located, and the Old Generation is the area where Objects that have survived multiple GC operations after creation are located. The Permanent area is the space where Static Objects, String Objects, Class Meta, Method Meta, and JIT Meta information are stored. The Permanent area is not subject to GC. In addition, since the Permanent area does not exist in Java 8, this article does not cover it in detail.

{{< figure caption="[Figure 2] JVM Heap Option" src="images/jvm-heap-option.png" width="600px" >}}

[Figure 2] shows the Options related to the JVM Heap. The size of each area can be configured in various ways through these options. `-Xms` means the Heap Size at JVM startup, and `-Xmx` means the maximum Heap Size.

## 2. Garbage Collector

### 2.1. Serial, Parallel, CMS

### 2.2. G1

## 3. Object Reachability

## 4. References

* Java Garbage Collection (NAVER D2) : [http://d2.naver.com/helloworld/1329](http://d2.naver.com/helloworld/1329)
* Java Reference와 GC (NAVER D2) : [http://d2.naver.com/helloworld/329631](http://d2.naver.com/helloworld/329631)
* Java 8 Perm : [https://yckwon2nd.blogspot.kr/2015/03/java8-permanent.html](https://yckwon2nd.blogspot.kr/2015/03/java8-permanent.html)
* G1 : [http://www.oracle.com/technetwork/tutorials/tutorials-1876574.html](http://www.oracle.com/technetwork/tutorials/tutorials-1876574.html)

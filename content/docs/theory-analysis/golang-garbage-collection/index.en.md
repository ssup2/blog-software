---
title: Golang Garbage Collection
---

This document analyzes Golang Garbage Collection.

## 1. Golang Garbage Collection

The Golang Runtime includes a Garbage Collector that manages Heap Memory. Golang's Garbage Collector performs Garbage Collection relatively simply using only the **CMS (Concurrent Mark and Sweep)** technique based on the **TCMalloc Memory Allocator**. It does not use Compaction techniques to prevent fragmentation of the Heap Memory area, or Generation techniques to minimize scanning of the Heap Memory area that occurs during Garbage Collection.

Fragmentation of the Heap Memory area can be minimized depending on how Heap Memory is allocated. In Golang, it is considered that the TCMalloc Memory Allocator minimizes fragmentation of the Heap Memory area and allocates Memory quickly. Therefore, Golang does not view Memory fragmentation as a major problem.

The Generation technique for minimizing scanning of the Heap Memory area was initially considered for introduction in Golang, but the Generation technique has not been applied to Golang so far. Golang's Compiler allocates Memory spaces with short lifespans to Stack rather than Heap based on good Escape analysis performance. Through this, it minimizes Heap Memory spaces with short lifespans and reduces the burden on the Garbage Collector.

Therefore, it is judged that even if the Generation technique is introduced to Golang, significant benefits cannot be obtained. Also, since it is not judged that the Generation technique is sufficiently fast compared to the complexity of Write Barrier and the difficulty of optimization of the Generation technique, the Generation technique has not been applied to Golang yet.

#### 1.1. Tuning

{{< figure caption="[Figure 1] GOGC" src="images/gogc.png" width="900px" >}}

Golang can control the timing of Garbage Collection to some extent through the `GOGC` environment variable. The value set in the `GOGC` environment variable represents the ratio between the capacity of Heap Memory space that remains and is used after the previous Garbage Collection, and the capacity of newly allocated space in Heap Memory.

[Figure 1] shows Garbage Collection execution according to the GOGC environment variable. When the `GOGC` environment variable value is 100, if the Heap Memory space that remains and is used after Garbage Collection is 50MB, then when 50MB is allocated to the Heap Memory space again, Garbage Collection is performed again. If the `GOGC` value is 200, then when 100MB is allocated to the Heap Memory space, Garbage Collection is performed again.

In this way, the higher the `GOGC` environment variable value, the lower the frequency of Garbage Collection. If Garbage Collection is unnecessary like Batch Jobs that run once and terminate, the GOGC environment variable can be set to `off` to prevent Garbage Collection from being performed.

## 2. References

* [https://engineering.linecorp.com/ko/blog/detail/342/](https://engineering.linecorp.com/ko/blog/detail/342/)
* [https://aidanbae.github.io/video/gogc/](https://aidanbae.github.io/video/gogc/)
* [https://groups.google.com/g/golang-nuts/c/KJiyv2mV2pU](https://groups.google.com/g/golang-nuts/c/KJiyv2mV2pU)
* [http://goog-perftools.sourceforge.net/doc/tcmalloc.html](http://goog-perftools.sourceforge.net/doc/tcmalloc.html)
* [https://golang.org/pkg/runtime/debug/#SetGCPercent](https://golang.org/pkg/runtime/debug/#SetGCPercent)

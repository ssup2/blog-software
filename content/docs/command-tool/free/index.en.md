---
title: free
---

This document summarizes the usage of `free`, which displays memory usage.

## 1. free

### 1.1. free -m

```shell {caption="[Shell 1] free -m"}
$ free -m
              total        used        free      shared  buff/cache   available
Mem:           7977        1430        2455           1        4090        6249
Swap:          4095           0        4095
```

Displays memory usage in MB. [Shell 1] shows the output of `free -m` displaying memory usage. In [Shell 1], `Mem:` represents physical memory usage, and `Swap:` represents swap usage. Each row has the following meaning:

* total : Total capacity
* used : Result of "total - free - buff/cache - cache"
* free : Unused capacity
* shared : Capacity used by tmpfs
* buff/cache : Sum of Buffer and Cache capacity used by the kernel. Cache includes Page Cache, Slab, and tmpfs capacity in use
* available : Memory capacity available for new processes or existing processes. Result of "free + Page Cache + reclaimable Slab"

## 2. References

* [https://linux.die.net/man/1/free](https://linux.die.net/man/1/free)
* [https://serverfault.com/questions/23433/in-linux-what-is-the-difference-between-buffers-and-cache-reported-by-the-f](https://serverfault.com/questions/23433/in-linux-what-is-the-difference-between-buffers-and-cache-reported-by-the-f)



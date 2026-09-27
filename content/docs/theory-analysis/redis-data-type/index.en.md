---
title: Redis Data Type
---

This article analyzes Redis Data Types.

## 1. Redis Data Type

**Redis** is fundamentally a storage that serves as a Key-Value Store, but it has the characteristic of supporting various Data Types for the **Value**.

### 1.1. Strings

The Strings Type is, as the name implies, a Type that stores strings. Strings can be used to store not only actual text but also various Data such as JPEG Images. When storing numbers, the `INCR`, `DECR`, and `INCRBY` commands can be used to change the number atomically, and when storing strings, the `APPEND`, `GETRANGE`, and `SETRANGE` commands can be used to manipulate the string. Bit Operations are also possible through the `SETBIT` and `GETBIT` commands. Up to 512MB can be stored.

### 1.2. Lists

The Lists Type is, as the name implies, a Type that stores a List of strings. The strings in the List are ordered by insertion order, and they can be added on both sides using the `LPUSH` and `RPUSH` commands, and removed from both sides using the `LPOP` and `RPOP` commands. Removing strings in the middle of the List and Sorting are not supported.

### 1.3. Sets

The Sets Type is similar to the Lists Type, but it does not allow duplicate values. Since it internally manages strings based on a Hash Table, it has the characteristic that string insertion and string lookup take O(1) time. Strings can be added using the `SADD` command and removed using the `SPOP` command.

### 1.4. Sorted sets

The Sorted sets Type is similar to the Sets Type, but differs in that it sorts by a value called **Score** that is stored together with the string. Therefore, when adding a string, the Score must also be set and added together. Strings and Scores can be added using the `ZADD` command, and the string with the largest or smallest Score can be removed using the `ZPOPMIN` and `ZPOPMAX` commands. There is no function to remove a specific string by specifying it. The `ZRANGE` command can also be used to get strings in a specific range based on the Score.

### 1.5. Hashes

The Hashes Type is a Type that stores Key-Values composed of strings. The `HSET` command is used to store a string Key-Value, and the `HGET` command is used to get the string Value through the string Key.

## 2. References

* Redis Data Types : [https://redis.io/topics/data-types](https://redis.io/topics/data-types)
* Introduction to Redis Data Types : [https://redis.io/topics/data-types-intro](https://redis.io/topics/data-types-intro)
* redis data type 종류 : [https://kimpaper.github.io/2016/07/27/redis-datatype/](https://kimpaper.github.io/2016/07/27/redis-datatype/)
* How does Redis claim O(1) time for key lookup : [https://stackoverflow.com/questions/15216897/how-does-redis-claim-o1-time-for-key-lookup](https://stackoverflow.com/questions/15216897/how-does-redis-claim-o1-time-for-key-lookup)

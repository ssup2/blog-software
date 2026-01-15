---
title: Serialization, Marshaling
---

This document compares Serialization and Marshaling, which have similar meanings.

## 1. Serialization

Serialization refers to the process of converting **Member Data of Objects** into primitive forms such as Byte Streams so they can be transmitted externally. Conversely, the process of converting primitives into Member Data of Objects is called Unserialization (Deserialization).

## 2. Marshaling

Marshaling refers to the process of converting **Objects themselves** so they can be transmitted externally. It transmits not only Object's Member Data but also **Object's Meta Data** as needed. A Serialization process occurs for Object's Member Data during the Marshaling process. Therefore, Serialization can be said to be part of Marshaling. The process of restoring Objects transformed through Marshaling back to their original Objects is called Unmarshalling.

## 3. References

* [http://stackoverflow.com/questions/770474/what-is-the-difference-between-serialization-and-marshaling](http://stackoverflow.com/questions/770474/what-is-the-difference-between-serialization-and-marshaling)


---
title: Cloud Storage
---

Classify and analyze Storage used in Cloud environments into Block Storage, Object Storage, and File Storage.

## 1. Block Storage

{{< figure caption="[Figure 1] Block Storage" src="images/block-storage.png" width="450px" >}}

Block Storage is Storage that provides **Block Device** like Hard Disk. Blocks in Block Storage all have the **same size**, and each Block is assigned a **Block Address**. Block Storage supports Block Read/Write operations based on Block Address. Block Storage only has Block-related Meta information such as the total number of Blocks. Block Storage shows the fastest I/O performance because it only performs simple Block-related functions.

Kernel recognizes Block Storage as a general Block Device like Hard Disk. In Linux, you can see Block Storage allocated under the /dev folder. Apps that directly manage Blocks like DB can directly use Block Storage. Also, Block Storage can be formatted and mounted as a Filesystem like EXT4 so that general Apps can also use it.

## 2. Object Storage

{{< figure caption="[Figure 2] Block Storage" src="images/object-storage.png" width="700px" >}}

Object Storage manages information in units called Objects. Object consists of three components: a unique **ID** that represents the Object, **Meta** that represents the Object's information, and **Data** where the actual information is stored.

One of the characteristics of Objects is **flexible Meta** format. Users can store various Meta information in Object Meta. Object Storage can perform various operations (Object search, sorting) based on stored Object Meta. Also, Object Storage does not have hierarchies between Objects and only provides a **Key-Value based flat** storage format using Object ID as Key. This format makes expansion and Replication of Object Storage easy.

Generally, Object Storage is operated in REST API format. When Object ID, which is the Key, is passed through REST API, the Object's information is retrieved and manipulated. Due to the flexibility of Object Storage and accessibility through REST API, it is generally used for Web Apps or Data Backup.

## 3. File Storage

{{< figure caption="[Figure 3] File Storage" src="images/file-storage.png" width="600px" >}}

File Storage is **hierarchy-based Storage** using File System. It manages Files by freely creating hierarchies through Directories and placing Files in specific Directories. File Storage only stores Meta information defined by File System such as creation time and ownership for each File. File Storage can be connected through mount command. Once connected, it can be copied and modified using various Apps like Local Files. Due to these characteristics, it is used for File sharing between VMs and Containers.

## 4. References

* [https://www.storagecraft.com/blog/storage-wars-file-block-object-storage](https://www.storagecraft.com/blog/storage-wars-file-block-object-storage/)


---
title: Hadoop AWS S3 Filesystem
---

This post summarizes the AWS S3 Filesystems available in Hadoop.

## 1. Hadoop AWS S3 Filesystem

Hadoop can use not only HDFS but also AWS S3 as its Data store. Depending on how Data is stored and transferred, it is divided into three Types: S3, S3A, and S3N.

### 1.1. S3 (S3 Block Filesystem)

A Filesystem that stores the Files accessed by Hadoop in S3 **in Block form**. When a Hadoop App uses a URL starting with `s3://`, the S3 Type is used. It maps S3 Objects to the Blocks of a Block Disk. Therefore, an Object stored in S3 means a Block composed of multiple Files, and Files and Objects have an N:1 relationship. Since an Object is a Block composed of multiple Files, Files cannot be accessed through the AWS Management Console or the aws CLI.

### 1.2. S3N (S3 Native Filesystem)

As can be guessed from the name, it is a Filesystem that stores each **File accessed by Hadoop as a single S3 Object**. When a Hadoop App uses a URL starting with `s3n://`, the S3N Type is used. Files and Objects have a 1:1 relationship. Therefore, Files can also be accessed directly through the AWS Management Console or the aws CLI. It has the drawback that a single File cannot exceed 5GB in size.

### 1.3. S3A (S3 Advanced Filesystem)

A Filesystem that improves on S3N. When a Hadoop App uses a URL starting with `s3a://`, the S3A Type is used. Files and Objects have a 1:1 relationship just like S3N, but because it leverages S3's **Multi-part Upload/Download** feature, a single File is supported up to 5TB in size and it shows faster performance. To use Multi-part Upload/Download, the AWS Library that performs the related functions must be included on the Node.

S3A supports backward compatibility with S3N. Therefore, a Hadoop Application using S3N can easily migrate to S3A by switching to S3A. From Hadoop 2.7 Version onward, using S3A instead of S3N is recommended, and from Hadoop 3.0 Version onward, only S3A can be used. Internally it uses the S3A Committer.

## 2. EMRFS on EMR Cluster

On AWS EMR Clusters, S3 can be used as a store through EMRFS. When an App inside an EMR Cluster accesses Files with URLs starting with `s3://` or `s3a://`, EMRFS is used. Therefore, even when the same `s3://` or `s3a://` URL is used, the internal behavior differs depending on whether it is a plain Hadoop Cluster or an EMR Cluster. For security and stability reasons, EMRFS recommends using `s3://` rather than `s3a://`, and does not support `s3a://`. Internally it uses the **EMR S3-optimized Committer**.

## 3. References

* Comparison of S3, S3N, and S3A : [https://www.quora.com/In-AWS-what-is-the-difference-between-S3N-S3A-and-S3](https://www.quora.com/In-AWS-what-is-the-difference-between-S3N-S3A-and-S3)
* Comparison of S3, S3N, and S3A : [https://stackoverflow.com/questions/33356041/technically-what-is-the-difference-between-s3n-s3a-and-s3](https://stackoverflow.com/questions/33356041/technically-what-is-the-difference-between-s3n-s3a-and-s3)
* Comparison of S3, S3N, and S3A : [https://vivani.net/2017/04/18/s3-vs-s3n-vs-s3a-vs-emrfs/](https://vivani.net/2017/04/18/s3-vs-s3n-vs-s3a-vs-emrfs/)
* Comparison of S3, S3N, and S3A : [https://spidyweb.tistory.com/475](https://spidyweb.tistory.com/475)
* S3A Contribution : [https://aws.amazon.com/ko/blogs/opensource/community-collaboration-the-s3a-story/](https://aws.amazon.com/ko/blogs/opensource/community-collaboration-the-s3a-story/)
* S3N Bucket File Write Example : [https://blog.voidmainvoid.net/229](https://blog.voidmainvoid.net/229)
* S3A Committer : [https://hadoop.apache.org/docs/r3.1.1/hadoop-aws/tools/hadoop-aws/committers.html](https://hadoop.apache.org/docs/r3.1.1/hadoop-aws/tools/hadoop-aws/committers.html)
* EMRFS S3-optimized Committer : [https://docs.aws.amazon.com/emr/latest/ReleaseGuide/emr-spark-s3-optimized-committer.html](https://docs.aws.amazon.com/emr/latest/ReleaseGuide/emr-spark-s3-optimized-committer.html)

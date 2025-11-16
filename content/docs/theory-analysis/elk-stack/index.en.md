---
title: ELK Stack
---

Analyzes ELK (Elasticsearch, Logstash, Kibana).

## 1. ELK Stack

{{< figure caption="[Figure 1] ELK Stack" src="images/elk-stack.png" width="700px" >}}

ELK Stack refers to the combination of Elasticsearch, Logstash, and Kibana. Using ELK Stack, you can easily build a Platform for collecting and analyzing Data. [Figure 1] shows the ELK Stack.

## 2. Elasticsearch

Elasticsearch performs the role of a distributed Data search and analysis engine. Elasticsearch stores Data in **Document** format such as JSON. Elasticsearch uses **Inverted Index** for Full-text Search and **BKD Tree** for numeric and location Data processing to enable fast Data search. Elasticsearch consists of four Node Types: Master-eligible, Data, Ingest, and Coordinating. Although there are 4 Node Types, all 4 Node Types can be applied to a single Node.

#### 2.1. Master-eligible Node

```cpp linenos {caption="[Text 1] Master Node Configuration", linenos=table}
node.master: true 
node.data: false
node.ingest: false
```

Master-eligible Node is a Node that manages the Elasticsearch Cluster overall. It manages the state of Nodes composing the Cluster, manages Indexes, and decides which Shard to store Data in. When there are multiple Master-eligible Nodes in the Cluster, only one Node actually performs the Master role, and the remaining Master-eligible Nodes perform the role of standby Nodes that can become Master during Failover. [Text 1] is the Configuration for setting up a Master-eligible Node.

#### 2.2. Data Node

```cpp linenos {caption="[Text 2] Data Node Configuration", linenos=table}
node.master: false 
node.data: true 
node.ingest: false 
```

Data Node is a Node that stores and manages Shards. [Text 2] is the Configuration for setting up a Data Node.

#### 2.3. Ingest Node

```cpp linenos {caption="[Text 3] Ingest Node Configuration", linenos=table}
node.master: false 
node.data: false
node.ingest: true 
```

Ingest Node is a Node that performs Data Pre-processing Pipeline. Therefore, Data preprocessing performed by Logstash can also be performed in Ingest Node. [Text 3] is the Configuration for setting up an Ingest Node.

#### 2.4. Coordinating (Client) Node

```cpp linenos {caption="[Text 4] Coordinating Node Configuration", linenos=table}
node.master: false
node.data: false
node.ingest: false
```

Coordinating Node performs the role of a Load Balancer or Proxy that sends appropriate requests to Master Node, Data Node, and Coordinating Node according to external (Logstash, Kibana) requests, and receives request results and delivers them back to the outside. [Text 4] is the Configuration for setting up a Coordinating Node.

## 3. Logstash

Logstash performs the role of collecting Data from various Data Sources, processing it, and sending it to Elasticsearch. Data Sources include Log files, Data delivered through App's REST API calls, and Data delivered through Beats. Since Logstash basically puts Data received from Data Sources into an In-memory Queue, Data loss occurs when Logstash fails. To prevent such Data loss, Logstash provides Persistent Queue. Persistent Queue stores Data on Disk to prevent Data loss. Persistent Queue can also be used as a Data Buffer role instead of Message Queues such as Kafka and RabbitMQ.

#### 3.1. Beats

Beats are Data collectors. Beats provide various Plugins for collecting various Data.

## 4. Kibana

Kibana is a Tool for visualizing Data analyzed through Elasticsearch.

## 5. References

* [https://www.elastic.co/guide/en/elasticsearch/reference/current/modules-node.html](https://www.elastic.co/guide/en/elasticsearch/reference/current/modules-node.html)
* [https://www.elastic.co/guide/en/elasticsearch/guide/2.x/important-configuration-changes.html#-minimum-master-nodes](https://www.elastic.co/guide/en/elasticsearch/guide/2.x/important-configuration-changes.html#-minimum-master-nodes)
* [https://www.elastic.co/kr/blog/writing-your-own-ingest-processor-for-elasticsearch](https://www.elastic.co/kr/blog/writing-your-own-ingest-processor-for-elasticsearch)
* [https://blog.yeom.me/2018/03/24/get-started-elasticsearch/](https://blog.yeom.me/2018/03/24/get-started-elasticsearch/)
* [https://www.slideshare.net/AntonUdovychenko/search-and-analyze-your-data-with-elasticsearch-62204515](https://www.slideshare.net/AntonUdovychenko/search-and-analyze-your-data-with-elasticsearch-62204515)
* [https://m.blog.naver.com/PostView.nhn?blogId=indy9052&logNo=220942459559&proxyReferer=https%3A%2F%2Fwww.google.com%2F](https://m.blog.naver.com/PostView.nhn?blogId=indy9052&logNo=220942459559&proxyReferer=https%3A%2F%2Fwww.google.com%2F)
* [https://www.popit.kr/look-at-new-features-elasticsearch-5/](https://www.popit.kr/look-at-new-features-elasticsearch-5/)
* [https://subscription.packtpub.com/book/big-data-and-business-intelligence/9781784391010/9/ch09lvl1sec50/node-types-in-elasticsearch](https://subscription.packtpub.com/book/big-data-and-business-intelligence/9781784391010/9/ch09lvl1sec50/node-types-in-elasticsearch)
* [http://tech.javacafe.io/2017/12/12/logstash-persistent-queue/](http://tech.javacafe.io/2017/12/12/logstash-persistent-queue/)


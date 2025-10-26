---
title: Jaeger Architecture
---

This document analyzes Jaeger Architecture.

## 1. Jaeger Architecture

Jaeger is a Distributed Tracing System that provides Profiling and Monitoring for MSA (Micro Service Architecture) Services (Apps). It follows the **OpenTracing** standard. Jaeger can be built in two ways: without using Kafka and using Kafka.

### 1.1 Without Kafka

{{< figure caption="[Figure 1] Jaeger Architecture without Kafka" src="images/jeager-architecture-without-kafka.png" width="900px" >}}

[Figure 1] shows the Architecture when Jaeger is built without using Kafka. **App** (Service) executes jaeger-client Library Instrumentation before or after performing Business Logic due to external requests. Instrumentation executed before performing Business Logic creates Spans, and Instrumentation executed after performing Business Logic stores Trace-related information according to Business Logic execution in the created Span and transmits it to jaeger-agent. Here, Span refers to the Execution unit defined in OpenTracing and represents part of Trace information.

**jaeger-agent** operates on the same Host or same Container where the App is running and pushes Trace information received from jaeger-client to jaeger-collector for delivery. **jaeger-collector** stores Trace information in Storage and also performs the role of controlling jaeger-client through jaeger-agent. The reason why jaeger-client control is needed is to set **Sampling policies** that determine how much Trace information to collect.

If Spans and Trace information are generated for all Business Logic processed by the App, a lot of load is also placed on the Host or Container. To minimize these problems, jaeger-client samples only some, not all Business Logic processed by the App, and transmits it to jaeger-agent. Multiple jaeger-collectors can operate. When multiple jaeger-collectors operate, jaeger-client distributes and transmits Trace information in Round Robin manner based on IP/Port information of multiple jaeger-collectors obtained through Parameters. Alternatively, Infra Services like DNS can be used to make jaeger-collector distribute Trace information to multiple jaeger-collectors.

**Storage** stores Metric information collected by jaeger-collector. Currently, Jaeger supports Cassandra, Elasticsearch, BadgerDB, and Memory as Storage Backends, and Jaeger recommends using Cassandra. Trace information stored in Storage is analyzed through **Spark Job** and the analyzed Trace information is stored back in Storage. **jaeger-ui** obtains original Trace information or analyzed Trace information stored in Storage through **jaeger-query** and shows it to Jaeger users.

Jaeger provides an **all-in-one** Binary, and when operating Jaeger through the all-in-one Binary, jaeger-collector, Storage (BadgerDB, Memory), jaeger-query, and jaeger-ui included in the Jaeger Backend operate within one Process. For Storage, only BadgerDB and Memory are supported, and Spark Job is not included.

### 1.2. With Kafka

{{< figure caption="[Figure 2] Jaeger Architecture with Kafka" src="images/jeager-architecture-with-kafka.png" width="900px" >}}

When too much Trace information is transmitted to Storage and Storage receives too much load, Kafka can be introduced to reduce the load on Storage. [Figure 2] shows the Architecture when Jaeger is built using Kafka. The Host or Container part is the same as [Figure 1], but it can be seen that the Jaeger Backend part is different. jaeger-collector does not transmit Trace information directly to Storage but transmits it to Kafka. Kafka performs the role of a Trace information Queue.

**jaeger-ingester** performs the role of obtaining Trace information from Kafka and storing it in Storage. **Flink Streaming** obtains Trace information from Kafka, analyzes it, and stores it in Storage.

## 2. References

* [https://www.jaegertracing.io/docs/1.22/architecture/](https://www.jaegertracing.io/docs/1.22/architecture/)
* [https://www.jaegertracing.io/docs/1.22/deployment/](https://www.jaegertracing.io/docs/1.22/deployment/)
* [https://www.scalyr.com/blog/jaeger-tracing-tutorial/](https://www.scalyr.com/blog/jaeger-tracing-tutorial/)
* [https://github.com/jaegertracing/spark-dependencies](https://github.com/jaegertracing/spark-dependencies)
* [https://github.com/jaegertracing/jaeger-analytics-flink](https://github.com/jaegertracing/jaeger-analytics-flink)
* [https://github.com/opentracing/specification/blob/master/specification.md](https://github.com/opentracing/specification/blob/master/specification.md)


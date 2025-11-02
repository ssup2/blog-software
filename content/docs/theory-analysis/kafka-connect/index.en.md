---
title: Kafka Connect
---

Analyze Kafka Connect.

## 1. Kafka Connect

{{< figure caption="[Figure 1] Kafka Connect Architecture" src="images/kafka-connect-architecture.png" width="900px" >}}

Kafka Connect is a tool that helps build data streams by integrating with external data stores based on Kafka. [Figure 1] shows the architecture of Kafka Connect and consists of the following components.

* **Data Source** : Data store that serves as the starting point of the data stream.
* **Data Destination** : Data store that serves as the destination point of the data stream.
* **Kafka Connect Cluster** : Manages **Plugins** (Kafka Connector, Transform, Converter) that exchange data streams between data stores and Kafka. It can be managed remotely through **REST API**. It consists of one or multiple **Workers**. [Figure 1] shows a Kafka Connect Cluster in Distributed Mode consisting of multiple Workers.
  * **Connector** : Performs the role of actually exchanging data streams between data stores and Converters. A connector that connects to a Data Source is called a **Source Connector**, and a connector that connects to a Data Destination is called a **Sink Connector**.
  * **Converter** : Performs data serialization/deserialization between Connector and Kafka.
  * **Transform** : Performs simple data transformation between Connector and Converter. It is not a required component and can be used optionally.
* **Kafka Cluster, Data Stream Topic** : Kafka topic that stores data streams processed by Connectors.
* **Kafka Cluster, Connect Topic** : Kafka topic that stores Kafka Connect's configuration/status information. Kafka Connect Cluster does not use a database to store configuration/status information, but implements this using Kafka topics. Each Kafka Connect Cluster uses separate Config, Offset, and Status Kafka topics.
  * **Config Topic** : Topic that stores the configuration information of the Kafka Connect Cluster.
  * **Offset Topic** : Topic that stores offset information indicating how far the Kafka Connect Cluster has processed the data stream.
  * **Status Topic** : Topic that stores the status information of the Kafka Connect Cluster.
* **Kafka Schema Registry** : Stores and manages schema information required for data serialization/deserialization by Converters.

### 1.1. Worker

Kafka Connect Cluster consists of one or multiple **Workers**. When consisting of one Worker, it operates in **Standalone Mode**, and when consisting of multiple Workers, it operates in **Distributed Mode**.

#### 1.1.1. Standalone Mode

{{< figure caption="[Figure 2] Kafka Connect Worker Standalone Mode" src="images/kafka-connect-worker-standalone.png" width="650px" >}}

[Figure 2] shows **Standalone Mode** consisting of one Worker. It also shows the Connector, Converter, and Transform running on the Worker. Connector is composed of **Connector Instance** and **Connector Task**, and each operates with a separate **Thread** allocated. Therefore, multiple Connector Instances and Connector Tasks can operate on a single Worker. Connector Instance and Connector Task perform the following roles.

* **Connector Instance** : Performs the role of distributing and creating multiple data streams into multiple tasks according to configuration. It also monitors the status of data stores and appropriately reconfigures tasks accordingly.
* **Connector Task** : Created by Connector Instance and performs the role of actually accessing data stores to exchange data streams. Generally, each Task is allocated a unique **Partition** to form and operate a separate data stream, and [Figure 2] also shows the Partition allocated to each Task.

Converter and Transform exist as **Class Instances** and are called and operated through methods from Connector Tasks. In Standalone Mode, Workers store and use all configuration/status information on the **Host**. Config information uses the Host's Properties file, Offset information uses the Host's file, and Status information uses the Host's memory. Since everything is located on a single Host, ensuring availability is difficult. Therefore, Standalone Mode is generally used in development environments.

#### 1.1.2. Distributed Mode

{{< figure caption="[Figure 3] Kafka Connect Worker Distributed Mode" src="images/kafka-connect-worker-distributed.png" width="900px" >}}

Generally, in Alpha or Production environments, **Distributed Mode** is used, which consists of multiple Workers, ensures high availability, and allows scale-out. [Figure 3] shows Distributed Mode. You can see that Connector Instances and Connector Tasks are distributed and operate across multiple Workers, and for Converters and Transforms that exist as Class Instances, each Worker has its own separate instance.

```properties {caption="[File 1] Kafka Connect Cluster Topic Properties Example" linenos=table}
config.storage.topic=connect-configs
offset.storage.topic=connect-offsets
status.storage.topic=connect-status

config.storage.replication.factor=-1
offset.storage.replication.factor=-1
status.storage.replication.factor=-1
```

When operating in Distributed Mode, multiple Workers store and use configuration/status information that needs to be shared among Workers in shared Kafka topics (Config, Offset, Status), while other configuration information that does not need to be shared or is needed for Worker initialization uses the Properties file on the same Host. Therefore, the Host's Properties file is configured with which Kafka topic to use as a shared topic, and [File 1] shows an example. You can see that topics are specified for Config, Offset, and Status, and the Replication Factor is set to `-1`, meaning the Replication Factor for that topic is set to be the same as the Kafka Cluster's Replication Factor.

One of the multiple Workers operates as a **Leader Worker**. The Leader Worker obtains all Connector Instance, Connector Task, and Worker information of the Kafka Connect Cluster through shared Kafka topics and performs the role of a Scheduler that decides which Worker to assign Connector Instances and Connector Tasks to. It also performs Task Rebalancing when a Worker dies. If the Leader Worker dies, another Worker is elected as the new Leader Worker and operates.

When running a Kafka Connect Cluster on Kubernetes, one Host operates as one Pod, and Properties files are stored in Kubernetes ConfigMap and shared and used by all Pods.

### 1.2. REST API

{{< table caption="[Table 1] Kafka Connect REST API" >}}
| URI | Method | Description |
| --- | --- | --- |
| /connectors | GET | Query all currently registered Connectors. |
| /connectors | POST | Register a new Connector. |
| /connectors/{connector-name} | GET | Query information about a specific Connector. |
| /connectors/{connector-name} | PUT | Modify information about a specific Connector. |
| /connectors/{connector-name} | DELETE | Delete a specific Connector. |
| /connectors/{connector-name}/config | GET | Query configuration information for a specific Connector. |
| /connectors/{connector-name}/config | PUT | Modify configuration information for a specific Connector. |
| /connectors/{connector-name}/status | GET | Query status information for a specific Connector. |
| /connectors/{connector-name}/pause | GET | Pause a specific Connector. |
| /connectors/{connector-name}/resume | GET | Resume a specific Connector. |
| /connectors/{connector-name}/tasks | GET | Query all Task information for a specific Connector. |
| /connectors/{connector-name}/tasks/{taskId} | GET | Query specific Task information for a specific Connector. |
| /connectors/{connector-name}/tasks/{taskId}/status | PUT | Modify the status of a specific Task for a specific Connector. |
| /connectors/{connector-name}/tasks/{taskId}/restart | GET | Restart a specific Task for a specific Connector. |
{{< /table >}}

Kafka Connect Cluster can be controlled externally through REST API. [Table 1] shows the REST API provided by Kafka Connect Cluster. You can register, query, delete, pause, or resume Connectors, or query detailed configuration or Task status information.

In Standalone Mode, since Workers use Local Properties files for configuration information, configuration information cannot be changed through `PUT`, `POST`, `DELETE` REST API, and to change configuration information, you must directly modify the Local Properties file and restart the Worker. The `GET` REST API for querying information can be used normally. On the other hand, in Distributed Mode, you can change or query configuration/status information through all `GET`, `PUT`, `POST`, `DELETE` REST API.

Even when operating in Distributed Mode, not only the Leader Worker but all Workers can receive requests through REST API. A Worker that receives a `GET` REST API request that does not change configuration/status information directly obtains configuration/status information from shared Kafka topics and responds. On the other hand, a Worker that receives `POST`, `PUT`, `DELETE` REST API requests that change configuration/status information only stores the received request in shared Kafka topics. Later, the Leader Worker obtains the changed configuration/status information through shared Kafka topics and processes the request.

```properties {caption="[File 2] Kafka Connect REST API Properties Example" linenos=table}
rest.advertised.listener=https
rest.advertised.host.name=ssup2.local
rest.advertised.port=8083
```

REST API can be configured through Properties files, and [File 2] shows an example of REST API configuration for Kafka Connect Cluster. According to the example content, you can use REST API through URIs in the form of `https://ssup2.local:8083`.

### 1.3. Converter

Converter performs data serialization/deserialization between Connector and Kafka. As can be seen in [Figure 1], the Converter on the Data Source side performs Serialization, that is, converting structured data to Byte Array, and the Converter on the Data Destination side performs Deserialization, that is, converting Byte Array to structured data.

{{< table caption="[Table 2] Kafka Connect Converter" >}}
| Converter | Class | Kafka Schema Registry | Description |
| --- | --- | --- | --- |
| ByteArrayConverter | org.apache.kafka.connect.converters.ByteArrayConverter | X | Pass-through without conversion. |
| DoubleConverter | org.apache.kafka.connect.converters.DoubleConverter | X | Supports Double format conversion. |
| FloatConverter | org.apache.kafka.connect.converters.FloatConverter | X | Supports Float format conversion. |
| IntegerConverter | org.apache.kafka.connect.converters.IntegerConverter | X | Supports Integer format conversion. |
| LongConverter | org.apache.kafka.connect.converters.LongConverter | X | Supports Long format conversion. |
| ShortConverter | org.apache.kafka.connect.converters.ShortConverter | X | Supports Short format conversion. |
| StringConverter | org.apache.kafka.connect.storage.StringConverter | X | Supports String format conversion. |
| JsonConverter | org.apache.kafka.connect.json.JsonConverter | X | Supports JSON format conversion. |
| AvroConverter | io.confluent.connect.avro.AvroConverter | O | Supports Avro format conversion. |
| ProtobufConverter | io.confluent.connect.protobuf.ProtobufConverter | O | Supports Protobuf format conversion. |
| JsonSchemaConverter | io.confluent.connect.json.JsonSchemaConverter | O | Supports JSON format conversion. |
{{< /table >}}

Converter exists as a Class Instance, and [Table 2] shows the list of Converters supported by default. They can be classified into Converters that use Kafka Schema Registry and Converters that do not use it.

```properties {caption="[File 3] Kafka Connect Converter Properties Example" linenos=table}
key.converter=org.apache.kafka.connect.json.JsonConverter
value.converter=org.apache.kafka.connect.json.JsonConverter
key.converter.schemas.enable=false
value.converter.schemas.enable=false
```

[File 3] shows an example of Converter configuration for Kafka Connect Cluster. According to the example content, it uses `JsonConverter` to serialize/deserialize data, and you can see that it does not use Schema Registry.

### 1.4. Transform

Transform performs simple data transformation between Connector and Converter. It can only perform transformation on **single Record units**, and for complex transformations targeting multiple Records, it is common to use separate frameworks such as Kafka Streams or Flink. It also supports transformation by sequentially applying multiple Transforms through **Chaining**.

{{< table caption="[Table 3] Kafka Connect Transform" >}}
| Transform | Class | Description |
| --- | --- | --- |
| InsertField | org.apache.kafka.connect.transforms.InsertField | Add a specific field. |
| ExtractField | org.apache.kafka.connect.transforms.ExtractField | Extract only a specific field. |
| ReplaceField | org.apache.kafka.connect.transforms.ReplaceField | Change a specific field. |
| MaskField | org.apache.kafka.connect.transforms.MaskField | Hide a specific field. |
{{< /table >}}

[Table 3] shows the list of Transforms supported by default, and they can be applied independently to Record's Key and Value.

```properties {caption="[File 4] Kafka Connect InsertField Transform Key Properties Example" linenos=table}
transforms=insertKey
transforms.insertKey.type=org.apache.kafka.connect.transforms.InsertField$Key
transforms.insertKey.value.static.field=my-field
transforms.insertKey.value.static.value=my-value
```

```properties {caption="[File 5] Kafka Connect InsertField Transform Value Properties Example" linenos=table}
transforms=insertValue
transforms.insertValue.type=org.apache.kafka.connect.transforms.InsertField$Value
transforms.insertValue.value.static.field=my-field
transforms.insertValue.value.static.value=my-value
```

[File 4] and [File 5] show examples of InsertField Transform configuration for Kafka Connect. [File 4] defines the `insertKey` Transform that adds a field named `my-field` with value `my-value` to the Record's Key, and similarly, [File 5] defines the `insertValue` Transform that adds a field named `my-field` with value `my-value` to the Record's Value.

```properties {caption="[File 6] Kafka Connect Chaining Transform Properties Example" linenos=table}
transforms=insertKey,insertValue
transforms.insertKey.type=org.apache.kafka.connect.transforms.InsertField$Key
transforms.insertKey.value.static.field=my-field
transforms.insertKey.value.static.value=my-value
transforms.insertValue.type=org.apache.kafka.connect.transforms.InsertField$Value
transforms.insertValue.value.static.field=my-field
transforms.insertValue.value.static.value=my-value
```

[File 6] shows an example of Chaining Transform configuration for Kafka Connect. You can see that `insertKey` and `insertValue` Transforms are applied sequentially to add a field named `my-field` with value `my-value` to both the Record's Key and Value.

## 2. References

* Kafka Connect : [https://docs.confluent.io/platform/current/connect/index.html#](https://docs.confluent.io/platform/current/connect/index.html#)
* Kafka Connect : [https://docs.lenses.io/latest/connectors/understanding-kafka-connect](https://docs.lenses.io/latest/connectors/understanding-kafka-connect)
* Kafka Connect : [https://developer.confluent.io/courses/kafka-connect/how-connectors-work/](https://developer.confluent.io/courses/kafka-connect/how-connectors-work/)
* Kakka Connect : [https://www.instaclustr.com/blog/apache-kafka-connect-architecture-overview/](https://www.instaclustr.com/blog/apache-kafka-connect-architecture-overview/)
* Kakfa Connect : [https://kafka.apache.org/documentation.html#connect](https://kafka.apache.org/documentation.html#connect)
* Kafka Connect : [https://cjw-awdsd.tistory.com/53](https://cjw-awdsd.tistory.com/53)
* Kafka Connect REST API : [https://docs.confluent.io/platform/current/connect/references/restapi.html](https://docs.confluent.io/platform/current/connect/references/restapi.html)
* Kafka Connect Rebalancing : [https://cwiki.apache.org/confluence/display/KAFKA/KIP-415:+Incremental+Cooperative+Rebalancing+in+Kafka+Connect](https://cwiki.apache.org/confluence/display/KAFKA/KIP-415:+Incremental+Cooperative+Rebalancing+in+Kafka+Connect)
* Kafka S3 Connector Exactly-once : [https://jaegukim.github.io/posts/s3-connector%EC%9D%98-exactly-once/](https://jaegukim.github.io/posts/s3-connector%EC%9D%98-exactly-once/)


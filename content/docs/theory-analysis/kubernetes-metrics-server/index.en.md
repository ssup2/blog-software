---
title: Kubernetes Metrics Server
---

This post analyzes the Metrics Server of Kubernetes.

## 1. Kubernetes Metrics Server

{{< figure caption="[Figure 1] Kubernetes Metrics Server" src="images/kubernetes-metrics-server.png" width="700px" >}}

The **Kubernetes Metrics Server** collects the Metric information of the Nodes and Pods that make up the Kubernetes Cluster, and then delivers the collected Metric information to the Kubernetes Components that need it. [Figure 1] shows the Kubernetes Metrics Server and the Metric collection process. kubelet has a built-in Node and Pod Metric Collector called cAdvisor, which is based on Linux's Cgroup. The Metrics collected by cAdvisor are exposed to the outside through the `/stat` Path on kubelet's 10250 Port.

The Metrics Server obtains the connection information of the kubelet running on each Node from the Kubernetes API Server, and then collects the Node and Pod Metrics from the kubelet. The collected Metrics are stored in Memory. Therefore, when the Metrics Server is restarted, all collected Metric information disappears. The Metrics Server uses Kubernetes' **API Aggregation** feature to register the Metrics Service connected to the Metrics Server as the `metrics.k8s.io` API. Therefore, the Kubernetes Components that need the Metric information of the Metrics Server do not fetch Metrics directly from the Metrics Server or the Metrics Service, but fetch them through the Kubernetes API Server.

The Kubernetes Components that currently use the Metric information of the Metrics Server include the Horizontal Pod Autoscaler Controller residing in the Kubernetes Controller Manager and the `kubectl top` command. Although not shown in [Figure 1], the Vertical Pod Autoscaler Controller, which operates as a separate Controller, also uses the Metrics of the Metrics Server. The Metrics Server was developed to provide Metrics to Kubernetes Components, and was not developed to expose Metric information outside the Kubernetes Cluster. To expose the Metrics of the Kubernetes Cluster to the outside, a separate tool such as Prometheus must be used.

The Metrics Server fetches Metrics from the kubelet in a Pull manner, the same as Prometheus. The Horizontal Pod Autoscaler Controller and the `kubectl top` command also fetch the Metrics of the Metrics Server in a Pull manner as needed. Therefore, it can also be seen that the direction of the Network Connection and the direction of the Metrics are opposite to each other.

### 1.1. High Availability

{{< figure caption="[Figure 2] Kubernetes Metrics Server with HA" src="images/kubernetes-metrics-server-ha.png" width="700px" >}}

Since the Metrics of the Metrics Server are used by the Horizontal Pod Autoscaler Controller as the baseline Metrics for Pod Auto Scailing, a failure of the Metrics Server can lead to a failure of the service. To prepare for a failure of the Metrics Server, an HA configuration is possible, and the HA configuration takes the form of running spare Metrics Servers. [Figure 2] shows the Metrics Server configured with HA. Even when multiple Metrics Servers are running, each Metrics Server is independent and collects Metrics separately.

The amount of Metric transmission increases in proportion to the number of Metrics Servers, which can lead to an increase in Network cost. Therefore, the recommended configuration is to run about 2 Metrics Servers on different Nodes. When the `--enable-aggregator-routing=true` setting is enabled, the Kubernetes API Server connects to one of the 2 Metrics Servers through the Metrics Server Service through the Service and collects Metrics.

## 2. References

* kubernetes-sigs/metrics-server : [https://github.com/kubernetes-sigs/metrics-server](https://github.com/kubernetes-sigs/metrics-server)
* Metrics Server Design Proposal : [https://github.com/kubernetes/community/blob/master/contributors/design-proposals/instrumentation/metrics-server.md](https://github.com/kubernetes/community/blob/master/contributors/design-proposals/instrumentation/metrics-server.md)
* Tools for Monitoring Resources : [https://kubernetes.io/docs/tasks/debug-application-cluster/resource-usage-monitoring/](https://kubernetes.io/docs/tasks/debug-application-cluster/resource-usage-monitoring/)
* Test and document high availability configuration (metrics-server #552) : [https://github.com/kubernetes-sigs/metrics-server/issues/552](https://github.com/kubernetes-sigs/metrics-server/issues/552)
* Kubernetes Monitoring - Concept, Architecture : [https://gruuuuu.github.io/cloud/monitoring-k8s1/#](https://gruuuuu.github.io/cloud/monitoring-k8s1/#)

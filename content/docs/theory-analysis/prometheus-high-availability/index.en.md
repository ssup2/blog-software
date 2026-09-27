---
title: Prometheus High Availability
---

This post analyzes how to configure High Availability for Prometheus.

## 1. Prometheus High Availability

{{< figure caption="[Figure 1] Prometheus HA Configuration" src="images/prometheus-ha.png" width="700px" >}}

[Figure 1] shows the HA (High Availability) configuration method for the Prometheus Server and Alertmanager. To configure HA for the Prometheus Server, multiple Prometheus Servers that fetch Metrics from the **same** Prometheus Exporter and Prometheus Pushgateway are run simultaneously. The multiple Prometheus Servers are grouped behind an LB and provided to Clients. This HA approach for the Prometheus Server provides high availability, but several problems arise because the Prometheus Server fetches Metrics in a Pull manner.

In the approach where an Agent that collects Metrics, such as the Prometheus Exporter, delivers Metrics to the Server in a Push manner, even if there are multiple Servers, all Servers end up with the same Metrics as long as the Agent delivers the same Metrics to all Servers. However, when the Server fetches Metrics in a Pull manner, even if it fetches Metrics from the same Agent, it may fetch different Metrics depending on the time of fetching. Therefore, in the Pull approach, each Server may end up with different Metrics.

Since each Prometheus Server may hold different Metrics, when requests sent by a single Prometheus Client are distributed to multiple Servers through the LB, the problem arises that the Client fetches different Metrics with each request. To solve this problem, the LB's Sticky Session feature can be used so that even if a single Prometheus Client sends multiple requests, they are delivered to only one Prometheus Server, allowing the Prometheus Client to fetch the same Metrics. However, if a Prometheus Server dies, the Clients that were using the dead Prometheus Server cannot fetch the same Metrics, and since each Client may fetch different Metrics, **it cannot be considered a complete HA approach.**

HA for the Prometheus Alertmanager can be solved with **Prometheus Alertmanager Clustering**, which uses a Protocol called gossip. When an Alert occurs, each Prometheus Server sends the Alert to all Prometheus Alertmanagers that make up the Cluster. Therefore, even if some Prometheus Alertmanagers fail to receive the Alert or die, the Alert is not lost. However, the Prometheus Alertmanager Cluster receives the same Alert redundantly, up to as many times as the number of Prometheus Alertmanagers included in the Cluster.

The Prometheus Alertmanager Cluster does not send a redundantly received Alert to the Alert destination multiple times according to the number of duplicates. It removes the duplicates and sends only one Alert to the Alert destination. If the Prometheus Alertmanager Cluster temporarily fails to perform Alert deduplication due to external failure factors, the same Alert may be sent to the Alert destination multiple times. Currently, the Prometheus Pushgateway does not support HA.

## 2. References

* Prometheus Operator - High Availability : [https://coreos.com/operators/prometheus/docs/latest/high-availability.html](https://coreos.com/operators/prometheus/docs/latest/high-availability.html)
* Prometheus FAQ - Can Prometheus be made highly available? : [https://prometheus.io/docs/introduction/faq/#can-prometheus-be-made-highly-available](https://prometheus.io/docs/introduction/faq/#can-prometheus-be-made-highly-available)
* Alertmanager and High Availability : [https://promcon.io/2017-munich/slides/alertmanager-and-high-availability.pdf](https://promcon.io/2017-munich/slides/alertmanager-and-high-availability.pdf)
* feature request: cluster (pushgateway #241) : [https://github.com/prometheus/pushgateway/issues/241](https://github.com/prometheus/pushgateway/issues/241)
* Pushgateway HA (pushgateway #319) : [https://github.com/prometheus/pushgateway/issues/319](https://github.com/prometheus/pushgateway/issues/319)

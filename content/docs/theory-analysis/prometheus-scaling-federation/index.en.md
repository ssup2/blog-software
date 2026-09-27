---
title: Prometheus Scaling, Federation
---

This post analyzes Prometheus Federation.

## 1. Prometheus Scaling, Federation

{{< figure caption="[Figure 1] Prometheus Horizontal Sharding" src="images/prometheus-scaling.png" width="900px" >}}

When the Metrics to collect increase and it becomes difficult for a single Prometheus Server to collect all Metric information, a **Horizontal Sharding** based Scaling technique can be used, which runs multiple Prometheus Servers and collects Metrics in a distributed manner. [Figure 1] shows the Scaling technique using Horizontal Sharding. When multiple Prometheus Servers run through Horizontal Sharding, some Prometheus Servers may need Metrics stored by other Prometheus Servers. To meet this need, the Prometheus Server provides the **Federation** feature.

```yaml {caption="[File 1] Federation Scrape Target Configuration", linenos=table}
scrape-configs:
  - job-name: 'federate'
    scrape-interval: 15s
    honor-labels: true
    metrics-path: '/federate'
    params:
      'match[]':
        - '{job="prometheus"}'
    static-configs:
      - targets:
        - 'prom-1:9090'
        - 'prom-2:9090'
```

Every Prometheus Server provides the `/federate` URL so that the Metrics it has collected can be fetched from the outside. A Match Query is appended after the `/federate` URL, like `/federate?[MatchQuery]`, to filter the Metrics to fetch. [File 1] shows the configuration of a Prometheus Server configured to fetch Metrics from the external `prom-1` and `prom-2` Prometheus Servers using the Federation feature. It is configured to fetch all metric information whose `job` Label stores the `prometheus` string at 15-second intervals using the `[prom-1, prom-2]:9090/federate?match[]={job="prometheus"}` URL.

{{< figure caption="[Figure 2] Federation Configuration of Prometheus Servers" src="images/prometheus-federation.png" width="900px" >}}

[Figure 2] shows the Federation configuration of Prometheus Servers. The method of configuring Federation in a Tree form with hierarchy between Prometheus Servers is called Hierarchical Federation. The parent Prometheus Server is used to provide the aggregated Metrics of the child Prometheus Servers and Alerts based on the aggregated Metrics. The method of configuring Federation between Prometheus Servers at the same Level is called Cross-service Federation.

## 2. References

* Federation : [https://prometheus.io/docs/prometheus/latest/federation/](https://prometheus.io/docs/prometheus/latest/federation/)
* Federation, what is it good for? : [https://www.robustperception.io/federation-what-is-it-good-for](https://www.robustperception.io/federation-what-is-it-good-for)
* Prometheus federation match params do not work : [https://stackoverflow.com/questions/48751632/prometheus-federation-match-params-do-not-work](https://stackoverflow.com/questions/48751632/prometheus-federation-match-params-do-not-work)

---
title: Prometheus Architecture
---

This post analyzes the Architecture of Prometheus.

## 1. Prometheus Architecture

{{< figure caption="[Figure 1] Prometheus Architecture" src="images/prometheus-architecture.png" width="700px" >}}

[Figure 1] shows the Prometheus Architecture. **Prometheus** largely consists of the Server, Exporter, Alertmanager, and Pushgateway. The Exporter **collects** and **Aggregates** Metrics. Multiple Exporters can be linked to and used with a single Server. In general, Exporters are divided by purpose. For example, the Node Exporter collects the Metrics of a specific Node. The MySQL Exporter collects the Metrics of a specific MySQL DB.

The Metric information collected and Aggregated by the Exporter is obtained not by the Exporter first Pushing it to the Server, but by the Server first **Pulling** it from the Exporter. In other words, all Metrics are collected with the Server, not the Exporter, at the center. This Server-centric Metric collection method has the great advantage that the Server itself can control the load caused by Metric collection. When the number of Exporters grows and the amount of Metrics to collect increases, the Server can actively lengthen the interval at which it Pulls Metrics from each Exporter. However, the Pull method is not suitable for recording Events. Even if an Event occurs and is stored in the Exporter, the point at which it is delivered to the Server is determined by the Server's Metric collection interval, which is unrelated to the Event.

The Pushgateway, as the name implies, collects Metrics in the Push manner that the Server cannot perform and delivers them to the Server. For the Metrics of Short-lived Jobs such as Batch Jobs, collecting them through the Pushgateway is more efficient than briefly running a separate Exporter to collect those Metrics. Pulling Metrics from the Exporter or Pushgateway is performed by the Server's Scrape Manager. The Scrape Manager stores the collected Metrics in the Storage. The Scrape Manager also detects changes in the Targets (Services) whose Metrics should be collected, and delivers the changed Target information to the Notifier as needed. Target information is obtained from specific Platforms or Servers such as K8s, Marathon, OpenStack, and DNS.

The Storage basically uses a Local Storage that serves as a TSDB (Time Series Data Base), and can additionally use an external Remote Storage. The Local Storage is not designed to store Metrics for a long time. To store Metrics for a long period, the Remote Storage must be used. Currently Metrics can also be read from the Remote Storage, but it is planned to be changed later so that only Metric write operations are allowed on the Remote Storage. The PromQL Engine processes PromQL Queries based on the Metrics stored in the Storage. Clients such as Grafana obtain the desired Metrics through PromQL Queries.

The Rule Manager executes and manages the **Recording Rules** or **Alert Rules** defined by the Prometheus user. A Recording Rule defines rules for preprocessing the Metrics stored in the Storage. The Rule Manager periodically fetches Metrics through the PromQL Engine according to the Recording Rules, preprocesses them, and stores them back in the Storage. Recording Rules are generally used for Aggregating Metrics. An Alert Rule defines rules for raising Alerts according to Metrics. The Rule Manager periodically compares the Metrics fetched through the PromQL Engine against the Alert Rules and stores the state of the Alerts in the Storage. If the condition of an Alert Rule is met and the Alert should be raised, the Rule Manager delivers that Alert to the Alertmanager through the Notifier. The interval at which the Rule Manager executes the Recording Rules and Alert Rules can be configured by the Prometheus user.

The Notifier not only handles the Alerts from the Rule Manager but also detects Target changes and delivers those changes to the Alertmanager as Alerts. The Alertmanager delivers the Alerts received from the Notifier according to the Alert destinations configured in the Alertmanager. The Alertmanager provides Grouping, which bundles similar Alerts, Inhibition, which prevents other configured Alerts from being raised when an Alert occurs, and Silence, which turns off Alerts. Supported Alert destinations include Email, HTTP/HTTPS, Webhook, and Slack.

## 2. References

* The Prometheus monitoring system and time series database : [https://github.com/prometheus/prometheus](https://github.com/prometheus/prometheus)
* Prometheus Internal Architecture : [https://github.com/prometheus/prometheus/blob/master/documentation/internal_architecture.md](https://github.com/prometheus/prometheus/blob/master/documentation/internal_architecture.md)
* Prometheus Monitoring: The Definitive Guide in 2019 : [https://devconnected.com/the-definitive-guide-to-prometheus-in-2019/](https://devconnected.com/the-definitive-guide-to-prometheus-in-2019/)
* Prometheus #1 - 아키텍쳐와 개념 : [https://badcandy.github.io/2018/12/25/prometheus-architecture/](https://badcandy.github.io/2018/12/25/prometheus-architecture/)

---
title: Prometheus with Thanos
---

This post analyzes Prometheus operating together with Thanos.

## 1. Prometheus with Thanos

One of the techniques that solves this incomplete HA of the Prometheus Server to some extent is the method of using Thanos. **Thanos** plays the role of relaying the multiple Prometheus Servers configured for HA. Thanos receives the Prometheus Client's requests on behalf of the Prometheus Servers and then delivers them again to each Prometheus Server. After that, Thanos collects and Aggregates the Metric information received from each Prometheus Server and delivers it to the Prometheus Client.

Instead of having the multiple Prometheus Servers receive the Prometheus Client's requests, the method gathers the Metric information held by each of the multiple Prometheus Servers into one shared Storage, and then Thanos receives the Prometheus Client's requests on behalf of the Prometheus Servers and provides the Metric information stored in the shared Storage to the Prometheus Client. Since all Metric information of Thanos is stored in one shared Storage, HA can be easily configured by running multiple Thanos Servers.

## 2. References

* thanos-io/thanos: Highly available Prometheus setup with long term storage capabilities : [https://github.com/thanos-io/thanos](https://github.com/thanos-io/thanos)
* Thanos - a Scalable Prometheus with Unlimited Storage : [https://www.infoq.com/news/2018/06/thanos-scalable-prometheus/](https://www.infoq.com/news/2018/06/thanos-scalable-prometheus/)

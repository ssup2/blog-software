---
title: Prometheus High Availability
---

Prometheus의 High Availability 구성 방법을 분석한다.

## 1. Prometheus High Availability

{{< figure caption="[Figure 1] Prometheus HA 구성" src="images/prometheus-ha.png" width="700px" >}}

[Figure 1]은 Prometheus Server, Alertmanager의 HA (High Availability) 구성 방법을 나타내고 있다. Prometheus Server의 HA를 구성하기 위해서는 **동일한** Prometheus Exporter, Prometheus Pushgateway의 Metric을 가져오는 Prometheus Server를 동시에 여러개 구동하는 방식을 이용한다. 다수의 Prometheus Server는 LB에 묶여서 Client에게 제공한다. 이러한 Prometheus Server의 HA 방식은 높은 가용성을 제공하지만 Prometheus Server가 Pull 방식으로 Metric을 가져온다는 특징 때문에 몇가지 문제점이 발생한다.

Prometheus Exporter와 같이 Metric을 수집하는 Agent에서 Server에게 Push 방식으로 Metric을 전달하는 방식은 다수의 Server가 있더라도 Agent가 동일한 Metric을 모든 Server에게 전달한다면 모든 Server는 동일한 Metric을 갖게 된다. 하지만 Server의 Pull 방식으로 Metric을 가져오게 되면 동일한 Agent에서 Metric을 가져오더라도 가져오는 시간에 따라서 다른 Metric을 가져올 수 있다. 따라서 Pull 방식에서 Server는 각각 다른 Metric을 갖을 수 있게 된다.

각 Prometheus Server는 다른 Metric을 갖고 있을수 있기 때문에 하나의 Prometheus Client에서 전송한 요청이 LB를 통해서 다수의 Server로 분배될 경우 Client은 요청을 보낼때 마다 다른 Metric를 갖고 온다는 문제가 발생한다. 이러한 문제를 해결하기 위해서 LB의 Sticky Session 기능을 이용하여 하나의 Prometheus Client가 다수의 요청을 전송하더라도 하나의 Prometheus Server에게만 전달 하도록하여 Prometheus Client가 동일한 Metric을 가져올수 있도록 만들 수 있다. 하지만 Prometheus Server가 죽을경우 죽은 Prometheus Server를 이용하던 Client는 동일한 Metric을 가져올 수 없고, 각 Client 마다 다른 Metric을 가져올 수 있기 때문에 **완전한 HA 방식이라고 볼수는 없다.** 

Prometheus Alertmanager의 HA는 gossip이라고 불리는 Protocol을 이용한 **Prometheus Alertmanager Clustering**으로 해결할 수 있다. 각 Prometheus Server는 Alert이 발생하면 Cluster를 구성하는 모든 Prometheus Alertmanager에게 Alert을 전송한다. 따라서 일부의 Prometheus Alertmanager가 Alert을 받지 못하거나 죽더라도 Alert은 소실되지 않는다. 하지만 Prometheus Alertmanager Cluster는 동일한 Alert을 최대 Cluster에 포함된 Prometheus Alertmanager의 개수만큼 중복해서 받게된다. 

Prometheus Alertmanager Cluster는 중복 수신한 Alert을 중복 횟수만큼 여러번 Alert 목적지로 전송하지 않는다. 중복을 제거하여 하나의 Alert만 Alert 목적지로 전송한다. 외부의 장애 요소로 인해서 Prometheus Alertmanager Cluster가 일시적으로 Alert 중복 제거를 수행하지 못하는 경우, Alert 목적지로 동일한 Alert이 여려번 전송될 수 있다. 현재 Prometheus Pushgateway는 HA를 지원하지 않는다.

## 2. 참조

* [https://www.perimeterx.com/blog/scaling-out-with-prometheus/](https://www.perimeterx.com/blog/scaling-out-with-prometheus/)
* [https://coreos.com/operators/prometheus/docs/latest/high-availability.html](https://coreos.com/operators/prometheus/docs/latest/high-availability.html)
* [https://prometheus.io/docs/introduction/faq/#can-prometheus-be-made-highly-available](https://prometheus.io/docs/introduction/faq/#can-prometheus-be-made-highly-available)
* [https://promcon.io/2017-munich/slides/alertmanager-and-high-availability.pdf](https://promcon.io/2017-munich/slides/alertmanager-and-high-availability.pdf)
* [https://github.com/prometheus/pushgateway/issues/241](https://github.com/prometheus/pushgateway/issues/241)
* [https://github.com/prometheus/pushgateway/issues/319](https://github.com/prometheus/pushgateway/issues/319)

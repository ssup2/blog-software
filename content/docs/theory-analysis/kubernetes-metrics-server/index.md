---
title: Kubernetes Metrics Server
---

Kubernetes의 Metrics Server를 분석한다.

## 1. Kubernetes Metrics Server

{{< figure caption="[Figure 1] Kubernetes Metrics Server" src="images/kubernetes-metrics-server.png" width="700px" >}}

Kubernetes Metrics Server는 Kubernetes Cluster를 구성하는 Node와 Pod의 Metric 정보를 수집한 다음, Metric 정보가 필요한 Kubernetes Component들에게 수집한 Metric 정보를 전달하는 역할을 수행한다. [Figure 1]은 Kubernetes Metrics Server와 Metric 수집 과정을 나타내고 있다. kubelet은 cAdvisor라고 불리는 Linux의 Cgroup을 기반으로하는 Node, Pod Metric Collector를 내장하고 있다. cAdvisor가 수집하는 Metric은 kubelet의 10250 Port의 `/stat` Path를 통해서 외부로 노출된다.

Metrics Server는 Kubernetes API Server로부터 Node에서 구동중인 kubelet의 접속 정보를 얻은 다음, kubelet으로 부터 Node, Pod의 Metric을 수집한다. 수집된 Metric은 Memory에 저장된다. 따라서 Metrics Server가 재시작 되면 수집된 모든 Metric 정보는 사라진다. Metrics Server는 Kubernetes의 **API Aggregation** 기능을 이용하여 Metrics Server와 연결되어 있는 Metrics Service를 metric.k8s.io API로 등록한다. 따라서 Metrics Server의 Metric 정보가 필요한 Kubernetes Component들은 Metrics Server 또는 Metric Service로부터 직접 Metric을 가져오지 않고, Kubernetes API Server를 통해서 가져온다.

현재 Metrics Server의 Metric 정보를 이용하는 Kubernetes Component에는 Kubernetes Controller Manager에 존재하는 Horizontal Pod Autoscaler Controller와 kubectl top 명령어가 있다. [Figure 1]에는 존재하지 않지만 별도의 Controller로 동작하는 Vertical Pod Autoscaler Controller도 Metrics Server의 Metric을 이용한다. Metrics Server는 Kubernetes Component들에게 Metric을 제공하는 용도로 개발되었으며, Kubernetes Cluster 외부로 Metric 정보를 노출시키는 용도로 개발되지는 않았다. Kubernetes Cluster의 Metric을 외부로 노출하기 위해서는 Prometheus같은 별도의 도구를 이용해야 한다.

Metrics Server는 Prometheus와 동일하게 Pull 방식으로 kubelet으로부터 Metric을 가져온다. 또한 Horizontal Pod Autoscaler Controller와 kubectl top 명령어 또한 필요에 따라서 Metrics Server의 Metric을 Pull 방식으로 가져온다. 따라서 Network Connection의 방향과 Metric의 방향이 서로 반대인것도 확인할 수 있다.

### 1.1. High Availability

{{< figure caption="[Figure 2] Kubernetes Metrics Server with HA" src="images/kubernetes-metrics-server.png" width="700px" >}}

Metrics Server의 Metric은 Horizontal Pod Autoscaler Controller에서 Pod Auto Scailing을 위한 기준 Metric으로 이용되기 때문에, Metrics Server의 장애는 서비스의 장애로 이어질 수 있다. Metrics Server의 장애를 대비하기 위해서 HA 구성이 가능하며, HA 구성은 여분의 Metrics Server를 동작시키는 형태로 구성된다. [Figure 2]는 HA를 구성한 Metrics Server를 나타내고 있다. Metrics Server가 여러대 동작하더라도 각각의 Metrics Server는 독립되어 별도로 Metric을 수집한다.

Metrics Server개수에 비례하여 Metric 전송량도 비례하여 증가하고 이는 Network 비용의 증가로 이어질 수 있다. 따라서 Metrics Server는 2대정도 서로 다른 Node에 동작시켜 구성하는 방식이 권장된다. Kubernetes API Server는 `--enable-aggregator-routing=true` 설정이 활성화 되어 있으면 Metrics Server Service를 통해서 Service를 통해서 2대의 Metrics Server중에 한대의 Metrics Server에 접속하여 Metric을 수집한다.

## 2. 참조

* [https://github.com/kubernetes-sigs/metrics-server](https://github.com/kubernetes-sigs/metrics-server)
* [https://github.com/kubernetes/community/blob/master/contributors/design-proposals/instrumentation/resource-metrics-api.md](https://github.com/kubernetes/community/blob/master/contributors/design-proposals/instrumentation/resource-metrics-api.md)
* [https://github.com/kubernetes/community/blob/master/contributors/design-proposals/instrumentation/metrics-server.md](https://github.com/kubernetes/community/blob/master/contributors/design-proposals/instrumentation/metrics-server.md)
* [https://kubernetes.io/docs/tasks/debug-application-cluster/resource-usage-monitoring/](https://kubernetes.io/docs/tasks/debug-application-cluster/resource-usage-monitoring/)
* [https://github.com/kubernetes/community/blob/master/contributors/design-proposals/instrumentation/monitoring-architecture.md#architecture](https://github.com/kubernetes/community/blob/master/contributors/design-proposals/instrumentation/monitoring-architecture.md#architecture)
* [https://github.com/kubernetes-sigs/metrics-server/issues/552](https://github.com/kubernetes-sigs/metrics-server/issues/552)
* [https://gruuuuu.github.io/cloud/monitoring-k8s1/#](https://gruuuuu.github.io/cloud/monitoring-k8s1/#)

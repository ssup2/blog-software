---
title: "Istio Locality Load Balancing"
---

## 1. Istio Locality Load Balancing

Istio's **Locality Load Balancing** literally means a function that sends requests only to Pods that exist in the same Locality (region). By utilizing the Locality Load Balancing feature well, you can minimize network hops to improve request processing speed, and in cloud environments, you can reduce network costs by sending requests only to Pods that exist in the same Region or Zone. It is a function similar to the **Topology Aware Load Balancing** function provided by Kubernetes Service.

### 1.1. Test Environment Setup

{{< figure caption="[Figure 1] Locality Load Balancing Test Environment" src="images/test-environment.png" width="900px" >}}

[Figure 1] shows a Kubernetes Cluster for testing Istio's Locality Load Balancing. It consists of 4 nodes, with each node configured in two Regions (`kr`, `us`) and two Zones (`a`, `b`), forming a total of 4 localities. Each locality is configured with 2 Pods through separate Deployments, for a total of 8 Pods. However, Service, Virtual Service, and Destination Rule are defined only once to be applied to all Deployment Pods. For access testing, a `myshell-kr-a` Pod that serves as a Shell Pod is also configured in the `a` Zone of the `kr` Region.

```shell {caption="[Shell 1] Kubernetes Cluster Setup"}
# Create kubernetes cluster with kind
$ kind create cluster --config=- <<EOF                           
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
- role: worker
- role: worker
EOF

# Install istio
$ istioctl install --set profile=demo -y

# Enable locality load balancing
$ kubectl -n istio-system patch deployment istiod --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/env/-", "value": {"name": "PILOT_ENABLE_LOCALITY_LOAD_BALANCING", "value": "true"}}]'

# Label nodes
$ kubectl label node kind-worker topology.kubernetes.io/region=kr
$ kubectl label node kind-worker2 topology.kubernetes.io/region=kr
$ kubectl label node kind-worker3 topology.kubernetes.io/region=us
$ kubectl label node kind-worker4 topology.kubernetes.io/region=us

$ kubectl label node kind-worker topology.kubernetes.io/zone=a
$ kubectl label node kind-worker2 topology.kubernetes.io/zone=b
$ kubectl label node kind-worker3 topology.kubernetes.io/zone=a
$ kubectl label node kind-worker4 topology.kubernetes.io/zone=b

# Enable sidecar injection to default namespace
$ kubectl label namespace default istio-injection=enabled
```

[Shell 1] shows a script for setting up a Kubernetes Cluster to test Istio's Locality Load Balancing. It uses `kind` to set up a Kubernetes Cluster and installs Istio. Then it sets topology information in Node Labels. Istio uses **Topology Labels** on Nodes to understand Node topology, so Node Label configuration is essential. Istio uses the following topology labels set on Nodes:

* `topology.kubernetes.io/region` : Region information
* `topology.kubernetes.io/zone` : Zone information
* `topology.kubernetes.io/subzone` : Subzone information

As shown in [Figure 1], the region has two values `kr` and `us`, and the zone has two values `a` and `b`, forming a total of 4 localities. subzone is not set.

```yaml {caption="[File 1] Basic Workload Manifest", linenos=table}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: helloworld-kr-a
spec:
  replicas: 2
  selector:
    matchLabels:
      app: helloworld
  template:
    metadata:
      labels:
        app: helloworld
    spec:
      nodeSelector:
        topology.kubernetes.io/region: kr
        topology.kubernetes.io/zone: a
      containers:
      - name: helloworld
        image: docker.io/istio/examples-helloworld-v1:1.0
        ports:
        - containerPort: 5000
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: helloworld-kr-b
spec:
  replicas: 2
  selector:
    matchLabels:
      app: helloworld
  template:
    metadata:
      labels:
        app: helloworld
    spec:
      nodeSelector:
        topology.kubernetes.io/region: kr
        topology.kubernetes.io/zone: b
      containers:
      - name: helloworld
        image: docker.io/istio/examples-helloworld-v1:1.0
        ports:
        - containerPort: 5000
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: helloworld-us-a
spec:
  replicas: 2
  selector:
    matchLabels:
      app: helloworld
  template:
    metadata:
      labels:
        app: helloworld
    spec:
      nodeSelector:
        topology.kubernetes.io/region: us
        topology.kubernetes.io/zone: a
      containers:
      - name: helloworld
        image: docker.io/istio/examples-helloworld-v1:1.0
        ports:
        - containerPort: 5000
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: helloworld-us-b
spec:
  replicas: 2
  selector:
    matchLabels:
      app: helloworld
  template:
    metadata:
      labels:
        app: helloworld
    spec:
      nodeSelector:
        topology.kubernetes.io/region: us
        topology.kubernetes.io/zone: b
      containers:
      - name: helloworld
        image: docker.io/istio/examples-helloworld-v1:1.0
        ports:
        - containerPort: 5000
---
apiVersion: v1
kind: Service
metadata:
  name: helloworld
spec:
  selector:
    app: helloworld
  ports:
  - port: 5000
    targetPort: 5000
    protocol: TCP
  type: ClusterIP
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: helloworld
spec:
  hosts:
  - helloworld.default.svc.cluster.local
  gateways:
  - mesh
  http:
  - route:
    - destination:
        host: helloworld.default.svc.cluster.local
        port:
          number: 5000
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: helloworld
spec:
  host: helloworld.default.svc.cluster.local
---
apiVersion: v1
kind: Pod
metadata:
  name: my-shell-kr-a
spec:
  nodeSelector:
    topology.kubernetes.io/region: kr
    topology.kubernetes.io/zone: a
  containers:
  - name: netshoot
    image: nicolaka/netshoot:latest
    command:
    - sleep
    - infinity
    tty: true
    stdin: true
```

[File 1] shows the basic Workload Manifest for testing Locality Load Balancing. As shown in [Figure 1], each Deployment is configured with 2 Pods and 4 localities, forming a total of 8 Pods. Also, only one Destination Rule, Service, and Virtual Service are defined to be applied to all Deployments.

```shell {caption="[Shell 2] Request Sending Command"}
$ kubectl exec -it my-shell-kr-a -- bash -c '
for i in {1..4}; do
  curl helloworld:5000/hello 
done
'
```

```text {caption="[Text 1] Request Sending Result"}
Hello version: v1, instance: helloworld-kr-a-57cdf4d447-gwnzb
Hello version: v1, instance: helloworld-us-a-7cfcf79cd4-grxlr
Hello version: v1, instance: helloworld-kr-b-7b95f679bd-8z7rv
Hello version: v1, instance: helloworld-us-b-59fd8576c5-grhkk
```

[Shell 2] shows a command to send 4 requests to the `helloworld` Service from the `my-shell-kr-a` Pod. [Text 1] shows the result of executing the command in [Shell 2]. Since Locality Load Balancing is not applied, you can see that each request is distributed and sent to Pods in all localities once.

### 1.2. Applying Locality Load Balancing

{{< figure caption="[Figure 2] Locality Load Balancing Example" src="images/locality-load-balancing.png" width="900px" >}}

[Figure 2] shows the state when Locality Load Balancing is activated in the [Figure 1] environment. Since the `my-shell-kr-a` Pod exists in the `kr/a` Locality, you can see that all requests are sent only to Pods of the `helloworld` Service in the `kr/a` Locality.

Locality Load Balancing is activated by setting the `localityLbSetting.enabled` Field to `true` in the Destination Rule. At this time, you must set the `outlierDetection` Field to activate Failover or set the `distribute` Field to activate Distribution. If you set only the `localityLbSetting.enabled` Field to `true`, Locality Load Balancing will not be activated. Conversely, even if you set both the `outlierDetection` Field and the `distribute` Field, Locality Load Balancing will be activated, but it is rarely used because the policy of the `outlierDetection` Field does not work properly due to the `distribute` Field.

#### 1.2.1. with Failover

One of the considerations when utilizing the Locality Load Balancing feature is availability. When not using Locality Load Balancing, client requests are sent to Pods in all localities, so high availability is guaranteed. On the other hand, when using Locality Load Balancing, if there are no Pods in the corresponding locality, requests cannot be sent, so availability may be reduced.

Istio provides a Failover function to solve this availability problem. The Failover function can be activated by setting the `outlierDetection` Field in the Destination Rule. When the `outlierDetection` Field is set, if there are no Pods in the same locality as the client, requests can be sent to Pods in other localities. The `outlierDetection` Field defines criteria for determining the abnormal state of Server Pods.

```yaml {caption="[File 2] Locality Load Balancing Outlier Detection Example"}
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: helloworld
spec:
  host: helloworld.default.svc.cluster.local
  trafficPolicy:
    loadBalancer:
      localityLbSetting:
        enabled: true
    outlierDetection:
      consecutive5xxErrors: 1
      interval: 1s
      baseEjectionTime: 1m
```

```text {caption="[Text 2] Locality Load Balancing Outlier Detection Result"}
Hello version: v1, instance: helloworld-kr-a-57cdf4d447-gwnzb
Hello version: v1, instance: helloworld-kr-a-57cdf4d447-gvgxg
Hello version: v1, instance: helloworld-kr-a-57cdf4d447-gwnzb
Hello version: v1, instance: helloworld-kr-a-57cdf4d447-gwnzb
```

[File 2] shows an example of a Destination Rule that activates Locality Load Balancing along with the `outlierDetection` Field, and when you execute the command in [Shell 2], you can see the same result as [Text 2]. You can see that Locality Load Balancing is activated and requests are sent only to Pods in the `kr/a` Locality where the `my-shell-kr-a` Pod is located.

##### 1.2.1.1. Zone Failover

{{< figure caption="[Figure 3] Locality Load Balancing Zone Failover Example" src="images/locality-load-balancing-failover-zone.png" width="900px" >}}

[Figure 3] shows the Zone Failover behavior when all `helloworld` Pods in the `kr/a` Zone where the `my-shell-kr-a` Pod is located are removed from the state in [Figure 2]. Since there are no `helloworld` Pods in the Zone where the `my-shell-kr-a` Pod is located, you can see that all requests are sent to Pods in the `kr/b` Zone. The reason why requests are not sent to Pods in the `us/a` and `us/b` localities is that `kr/b` has a higher locality priority than `us/a` and `us/b` because it exists in the same Region as `kr/a`. This locality priority can be set through the `failoverPriority` Field in the Destination Rule.

```shell {caption="[Shell 3] Scale helloworld-kr-a Deployment to 0 replicas"}
$ kubectl scale deployment helloworld-kr-a --replicas 0
$ kubectl scale deployment helloworld-kr-b --replicas 2
```

```text {caption="[Text 3] Result of scaling helloworld-kr-a Deployment to 0 replicas"}
Hello version: v1, instance: helloworld-kr-b-7b95f679bd-fg8q5
Hello version: v1, instance: helloworld-kr-b-7b95f679bd-8z7rv
Hello version: v1, instance: helloworld-kr-b-7b95f679bd-fg8q5
Hello version: v1, instance: helloworld-kr-b-7b95f679bd-8z7rv
```

[Shell 3] shows a command to scale the `helloworld-kr-a` Deployment to 0 replicas, and [Text 3] shows the result of executing the command in [Shell 2]. Since no Pods exist in the `kr/a` Locality anymore, you can see that all requests are sent only to Pods in the `kr/b` Locality. That is, you can see that the Failover function is activated and requests are sent to Pods in other localities.

##### 1.2.1.2. Region Failover

{{< figure caption="[Figure 4] Locality Load Balancing Region Failover Example" src="images/locality-load-balancing-failover-region.png" width="900px" >}}

[Figure 4] shows the Region Failover behavior when all `helloworld` Pods in the `kr` Region where the `my-shell-kr-a` Pod is located are removed from the state in [Figure 2]. Since there are no `helloworld` Pods in the Region where the `my-shell-kr-a` Pod is located, you can see that all requests are distributed to Pods in the `us/a` and `us/b` localities. Since the `us/a` and `us/b` localities have the same priority, traffic is also distributed evenly.

```shell {caption="[Shell 4] Scale helloworld-kr-a, helloworld-kr-b Deployments to 0 replicas"}
$ kubectl scale deployment helloworld-kr-a --replicas 0
$ kubectl scale deployment helloworld-kr-b --replicas 0
```

```text {caption="[Text 4] Result of scaling helloworld-kr-a, helloworld-kr-b Deployments to 0 replicas"}
Hello version: v1, instance: helloworld-us-a-7cfcf79cd4-grxlr
Hello version: v1, instance: helloworld-us-b-59fd8576c5-grhkk
Hello version: v1, instance: helloworld-us-a-7cfcf79cd4-grxlr
Hello version: v1, instance: helloworld-us-b-59fd8576c5-qd85k
```

[Shell 4] shows a command to scale the `helloworld-kr-a` and `helloworld-kr-b` Deployments to 0 replicas, and [Text 4] shows the result of executing the command in [Shell 2]. Since no Pods exist in the `kr/a` and `kr/b` localities anymore, the `us/a` and `us/b` localities have the same priority. Therefore, you can see that all requests are evenly distributed to Pods in the `us/a` and `us/b` localities.

##### 1.2.1.3. When Only Some Pods Exist in Zone

{{< figure caption="[Figure 5] Locality Load Balancing Only One Pod" src="images/locality-load-balancing-failover-zone-one-pod.png" width="900px" >}}

[Figure 5] shows the behavior when only one `helloworld` Pod exists in the `kr/a` Locality where the `my-shell-kr-a` Pod is located from the state in [Figure 2]. You can see that all requests are sent to the single Pod in the `kr/a` Locality. Istio's Locality Load Balancing sends requests to the corresponding Server Pod even if there is a large difference in the number of Server Pods for each Locality, as long as **at least one Server Pod** exists in the same Locality as the client. This is in contrast to Kubernetes Service's Topology Aware Load Balancing, which stops functioning due to **Guardrail** when there is too much difference in the number of Pods between localities.

As the difference in the number of Server Pods existing in each Locality increases, the imbalance in the number of requests each Server Pod receives also increases. To solve this imbalance, you need to set `topologySpreadConstraint` on Pods to maintain the same number of Server Pods in each Locality.

```shell {caption="[Shell 5] Scale helloworld-kr-a Deployment to 1 replica"}
$ kubectl scale deployment helloworld-kr-a --replicas 1
$ kubectl scale deployment helloworld-kr-b --replicas 2
```

```text {caption="[Text 5] Result of scaling helloworld-kr-a Deployment to 1 replica"}
Hello version: v1, instance: helloworld-kr-a-57cdf4d447-gwnzb
Hello version: v1, instance: helloworld-kr-a-57cdf4d447-gwnzb
Hello version: v1, instance: helloworld-kr-a-57cdf4d447-gwnzb
Hello version: v1, instance: helloworld-kr-a-57cdf4d447-gwnzb
```

[Shell 5] shows a command to scale the `helloworld-kr-a` Deployment to 1 replica and the `helloworld-kr-b` Deployment to 2 replicas, and [Text 5] shows the result of executing the command in [Shell 4]. Since one Pod still exists in the `kr/a` Locality, you can see that all requests are sent to the Pod in the `kr/a` Locality.

#### 1.2.2. with Distribution

Locality Load Balancing not only sends traffic only to Server Pods in the same Locality as the Client Pod, but also provides a Distribution function that allows explicit requests to be sent to Server Pods in other localities. The Distribution function can be activated through the `distribute` Field in the Destination Rule.

```yaml {caption="[File 3] Locality Load Balancing Distribute Example"}
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: helloworld
spec:
  host: helloworld.default.svc.cluster.local
  trafficPolicy:
    loadBalancer:
      localityLbSetting:
        enabled: true
        distribute:
        - from: "kr/a/*"
          to:
            "kr/a/*": 100
        - from: "kr/b/*"
          to:
            "kr/b/*": 100
        - from: "us/a/*"
          to:
            "us/a/*": 100
        - from: "us/b/*"
          to:
            "us/b/*": 100
```

```shell {caption="[Text 6] Locality Load Balancing Distribute Result"}
Hello version: v1, instance: helloworld-kr-a-57cdf4d447-skvgp
Hello version: v1, instance: helloworld-kr-a-57cdf4d447-rw56z
Hello version: v1, instance: helloworld-kr-a-57cdf4d447-skvgp
Hello version: v1, instance: helloworld-kr-a-57cdf4d447-skvgp
```

[File 3] shows an example of a Destination Rule that activates Locality Load Balancing along with the `distribute` Field, and when you execute the command in [Shell 2], you can see the same result as [Text 6]. In `from` and `to`, you define which Locality to send traffic to in the form of `region/zone/subzone` along with **Weight**. At this time, the sum of weights must be 100. [File 3] is configured so that all client requests are sent only to Server Pods in the same Locality, so you can see the same result as [Figure 1].

```yaml {caption="[File 4] Locality Load Balancing Distribute Cross Region Example"}
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: helloworld
spec:
  host: helloworld.default.svc.cluster.local
  trafficPolicy:
    loadBalancer:
      localityLbSetting:
        enabled: true
        distribute:
        - from: "kr/a/*"
          to:
            "us/a/*": 20
            "us/b/*": 80
        - from: "kr/b/*"
          to:
            "us/a/*": 80
            "us/b/*": 20
        - from: "us/a/*"
          to:
            "kr/a/*": 20
            "kr/b/*": 80
        - from: "us/b/*"
          to:
            "kr/a/*": 80
            "kr/b/*": 20
```

[File 4] shows an example of configuring Cross Region through the Distribution function. You can see that requests sent from the `kr` Region are sent to Pods in the `us` Region, and conversely, requests sent from the `us` Region are sent to Pods in the `kr` Region. You can also see that traffic between Zones is distributed in an 80:20 ratio.

{{< figure caption="[Figure 6] Locality Load Balancing Distribute Cross Region Example" src="images/locality-load-balancing-distribution-cross-region.png" width="900px" >}}

```text {caption="[Text 7] Locality Load Balancing Distribute Cross Region Result"}
Hello version: v1, instance: helloworld-us-b-59fd8576c5-grhkk
Hello version: v1, instance: helloworld-us-b-59fd8576c5-grhkk
Hello version: v1, instance: helloworld-us-b-59fd8576c5-grhkk
Hello version: v1, instance: helloworld-us-a-7cfcf79cd4-grxlr
```

[Figure 6] and [Text 7] show the result of executing the command in [File 4]. You can see that all traffic is sent to Pods in the `us` Region.

## 2. References

* Istio Locality Load Balancing : [https://istio.io/latest/docs/tasks/traffic-management/locality-load-balancing/](https://istio.io/latest/docs/tasks/traffic-management/locality-load-balancing/)
* Istio Locality Load Balancing : [https://dobby-isfree.tistory.com/224](https://dobby-isfree.tistory.com/224)
* Destination Rule Global : [https://istio.io/latest/docs/reference/config/networking/destination-rule/#LocalityLoadBalancerSetting](https://istio.io/latest/docs/reference/config/networking/destination-rule/#LocalityLoadBalancerSetting)

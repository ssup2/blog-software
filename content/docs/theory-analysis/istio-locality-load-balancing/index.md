---
title: "Istio Locality Load Balancing"
draft: true
---

## 1. Istio Locality Load Balancing

### 1.1. Test 환경 구성

[그림 1]은 Istio의 Locality Load Balancing을 테스트하기 위한 Kubernetes Cluster를 나타내고 있다.

```shell {caption="[Shell 1] Kubernetes Cluster 구성"}
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

[Shell 1]은 Istio의 Locality Load Balancing을 테스트하기 위한 Kubernetes Cluster를 구성하는 Script를 나타내고 있다. kind를 활용하여 Kubernetes Cluster를 구성하고, Istio를 설치한다. 그리고 Node Label에 Topology 정보를 설정한다. Istio는 Node Label에 설정되어 있는 Topology 정보를 활용하여 Node의 Topology를 파악하기 때문에, Node Label 설정이 필수이다. Istio는 Node에 설정되어 있는 다음의 Label을 활용하여 Node의 Topology를 파악한다.

* `topology.kubernetes.io/region` : Region 정보
* `topology.kubernetes.io/zone` : Zone 정보

region은 `kr`, `us` 두 가지 값을 가지고, zone은 `a`, `b` 두 가지 값을 설정하여 총 4개의 Locality를 구성한다.

```yaml {caption="[File 1] 기본 Workload Manifest", linenos=table}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: helloworld-zone-kr-a
spec:
  replicas: 3
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
  name: helloworld-zone-kr-b
spec:
  replicas: 3
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
  name: helloworld-zone-us-a
spec:
  replicas: 3
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
  name: helloworld-zone-us-b
spec:
  replicas: 3
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
  name: helloworld-svc
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
  name: helloworld-vs
spec:
  hosts:
  - helloworld-svc.default.svc.cluster.local
  gateways:
  - mesh
  http:
  - route:
    - destination:
        host: helloworld-svc.default.svc.cluster.local
        port:
          number: 5000
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: helloworld-dr
spec:
  host: helloworld-svc.default.svc.cluster.local
---
apiVersion: v1
kind: Pod
metadata:
  name: netshoot-a
spec:
  nodeSelector:
    topology.kubernetes.io/zone: b
  containers:
  - name: netshoot
    image: nicolaka/netshoot:latest
    command:
    - sleep
    - infinity
    tty: true
    stdin: true
```

[File 1]은 Locality Load Balancing을 테스트하기 위한 기본 Workload Manifest를 나타내고 있다. 각 

```shell {caption="[Shell 2] Locality Load Balancing Off"}
$ kubectl exec -it netshoot-b -- bash
(netshoot-b)# curl helloworld-svc:5000/hello
Hello version: v1, instance: helloworld-zone-c-6667db9dbd-gpclb
(netshoot-b)# curl helloworld-svc:5000/hello
Hello version: v1, instance: helloworld-zone-b-d48b9c6cc-nzqt8
(netshoot-b)# curl helloworld-svc:5000/hello
Hello version: v1, instance: helloworld-zone-a-87c7fd898-wxfrw
```

```shell
$ istioctl proxy-config all netshoot-b -o json \
| jq -r '["locality","weight","endpoints(ip|status)"],(
    .configs[]|select(."@type"=="type.googleapis.com/envoy.admin.v3.EndpointsConfigDump")
    | ..|objects
    | select(.cluster_name? and (.cluster_name|contains("helloworld")))
    | .endpoints[]?
    | [
        ([.locality.region,.locality.zone,.locality.subzone,.locality.sub_zone] | map(. // "") | map(select(.!="")) | join("/")),
        ((.load_balancing_weight | (.value? // .)) // (.loadBalancingWeight | (.value? // .)) // "N/A"),
        ([ .lb_endpoints[]?
           | (.endpoint.address.socket_address.address) as $ip
           | ($ip + "|" + ((.health_status // .healthStatus // "UNKNOWN") | tostring))
         ] | join(","))
      ]) | @tsv' \
| column -s $'\t' -t
locality  weight  endpoints(ip|status)
kr/a      3       10.244.3.12|HEALTHY,10.244.3.13|HEALTHY,10.244.3.14|HEALTHY
kr/b      3       10.244.2.13|HEALTHY,10.244.2.15|HEALTHY,10.244.2.14|HEALTHY
kr/c      3       10.244.1.13|HEALTHY,10.244.1.12|HEALTHY,10.244.1.14|HEALTHY
```

### 1.2. Locality Load Balancing On

```yaml {caption="[File 2] Locality Load Balancing Distribute Example"}
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: helloworld-dr
spec:
  host: helloworld-svc.default.svc.cluster.local
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
        - from: "kr/c/*"
          to:
            "kr/c/*": 100
```

```shell {caption="[Shell 3] Locality Load Balancing On"}
$ kubectl exec -it netshoot-b -- bash
(netshoot-b)# curl helloworld-svc:5000/hello
Hello version: v1, instance: helloworld-zone-b-d48b9c6cc-nzqt8
(netshoot-b)# curl helloworld-svc:5000/hello
Hello version: v1, instance: helloworld-zone-b-d48b9c6cc-c9xsx
(netshoot-b)# curl helloworld-svc:5000/hello
Hello version: v1, instance: helloworld-zone-b-d48b9c6cc-c9xsx
```

```shell
$ istioctl proxy-config all netshoot-b -o json \
| jq -r '["locality","weight","endpoints(ip|status)"],(
    .configs[]|select(."@type"=="type.googleapis.com/envoy.admin.v3.EndpointsConfigDump")
    | ..|objects
    | select(.cluster_name? and (.cluster_name|contains("helloworld")))
    | .endpoints[]?
    | [
        ([.locality.region,.locality.zone,.locality.subzone,.locality.sub_zone] | map(. // "") | map(select(.!="")) | join("/")),
        ((.load_balancing_weight | (.value? // .)) // (.loadBalancingWeight | (.value? // .)) // "N/A"),
        ([ .lb_endpoints[]?
           | (.endpoint.address.socket_address.address) as $ip
           | ($ip + "|" + ((.health_status // .healthStatus // "UNKNOWN") | tostring))
         ] | join(","))
      ]) | @tsv' \
| column -s $'\t' -t
locality  weight  endpoints(ip|status)
kr/b      100     10.244.2.13|HEALTHY,10.244.2.15|HEALTHY,10.244.2.14|HEALTHY
```

```shell {caption="[Shell 3] Locality Load Balancing On"}
$ kubectl scale deployment helloworld-zone-b --replicas 3
$ kubectl exec -it netshoot-b -- bash
(netshoot-b)# curl helloworld-svc:5000/hello
no healthy upstream
```

```yaml {caption="[File 3] Locality Load Balancing Distribute Example"}
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: helloworld-dr
spec:
  host: helloworld-svc.default.svc.cluster.local
  trafficPolicy:
    loadBalancer:
      localityLbSetting:
        enabled: true
        distribute:
        - from: "kr/a/*"
          to:
            "kr/b/*": 90
            "kr/c/*": 10
        - from: "kr/b/*"
          to:
            "kr/a/*": 90
            "kr/c/*": 10
        - from: "kr/c/*"
          to:
            "kr/a/*": 90
            "kr/b/*": 10
```

```shell
$ istioctl proxy-config all netshoot-b -o json |
jq -r '
  .configs[] | select(."@type"=="type.googleapis.com/envoy.admin.v3.EndpointsConfigDump")
  | .. | objects
  | select(.cluster_name? and (.cluster_name | contains("helloworld")))
  | .endpoints[]?
  | [
      ([.locality.region, .locality.zone, .locality.subzone, .locality.sub_zone] | map(. // "") | map(select(.!="")) | join("/")),
      ((.load_balancing_weight | (.value? // .)) // (.loadBalancingWeight | (.value? // .)) // "N/A"),
      ([.lb_endpoints[]? | .endpoint.address.socket_address.address] | join(","))
    ]
  | @tsv
'
kr/a    90      10.244.3.12,10.244.3.13,10.244.3.14
kr/c    10      10.244.1.13,10.244.1.12,10.244.1.14
...
```

### 1.3. Locality Load Balancing Failover

```yaml {caption="[File 2] Locality Load Balancing Distribute Example"}
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: helloworld-dr
spec:
  host: helloworld-svc.default.svc.cluster.local
  trafficPolicy:
    loadBalancer:
      localityLbSetting:
        enabled: true
    outlierDetection:
      consecutive5xxErrors: 1
      interval: 1s
      baseEjectionTime: 1m
```

```shell
$ kubectl exec -it netshoot-b -- bash
(netshoot-b)# curl helloworld-svc:5000/hello
Hello version: v1, instance: helloworld-zone-b-d48b9c6cc-nzqt8
(netshoot-b)# curl helloworld-svc:5000/hello
Hello version: v1, instance: helloworld-zone-b-d48b9c6cc-nzqt8
(netshoot-b)# curl helloworld-svc:5000/hello
Hello version: v1, instance: helloworld-zone-b-d48b9c6cc-c9xsx
```

```shell
$ kubectl scale deployment helloworld-zone-b --replicas 1
Hello version: v1, instance: helloworld-zone-b-d48b9c6cc-d4jtx
Hello version: v1, instance: helloworld-zone-b-d48b9c6cc-d4jtx
Hello version: v1, instance: helloworld-zone-b-d48b9c6cc-d4jtx

locality  weight  endpoints(ip|status)
kr/b      1       10.244.2.19|HEALTHY
kr/a      3       10.244.3.12|HEALTHY,10.244.3.13|HEALTHY,10.244.3.14|HEALTHY
kr/c      3       10.244.1.13|HEALTHY,10.244.1.12|HEALTHY,10.244.1.14|HEALTHY
```

```shell
$ kubectl exec -it netshoot-b -- bash
Hello version: v1, instance: helloworld-zone-c-6667db9dbd-gpclb
Hello version: v1, instance: helloworld-zone-a-87c7fd898-cs8c9
Hello version: v1, instance: helloworld-zone-a-87c7fd898-cs8c9

locality  weight  endpoints(ip|status)
kr/a      3       10.244.3.12|HEALTHY,10.244.3.13|HEALTHY,10.244.3.14|HEALTHY
kr/c      3       10.244.1.13|HEALTHY,10.244.1.12|HEALTHY,10.244.1.14|HEALTHY
```

## 2. 참조

* Istio Locality Load Balancing : [https://istio.io/latest/docs/tasks/traffic-management/locality-load-balancing/](https://istio.io/latest/docs/tasks/traffic-management/locality-load-balancing/)
* Istio Locality Load Balancing : [https://dobby-isfree.tistory.com/224](https://dobby-isfree.tistory.com/224)
* Destination Rule Global : [https://istio.io/latest/docs/reference/config/networking/destination-rule/#LocalityLoadBalancerSetting](https://istio.io/latest/docs/reference/config/networking/destination-rule/#LocalityLoadBalancerSetting)
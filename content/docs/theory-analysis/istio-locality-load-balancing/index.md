---
title: "Istio Locality Load Balancing"
draft: true
---

## 1. Istio Locality Load Balancing

### 1.1. Test 환경 구성

{{< figure caption="[Figure 1] Locality Load Balancing Test Environment" src="images/test-environment.png" width="900px" >}}

[Figure 1]은 Istio의 Locality Load Balancing을 테스트하기 위한 Kubernetes Cluster를 나타내고 있다. 4개의 Node로 구성되어 있고 각 Node는 `kr`, `us` 두 가지 Region과 `a`, `b` 두 가지 Zone에 한대씩 구성되어 총 4개의 Locality를 구성한다. 각 Locality에는 마다 별도의 Deployment를 통해서 2개의 Pod, 총 8개의 Pod를 구성한다. 하지만 Service, Virtual Service, Destination Rule은 하나만 정의하여 모든 Deployment의 Pod에 적용되도록 구성한다. 접근 Test를 위해서 `kr` Region의 `a` Zone에 Shell Pod의 역할을 수행하는 `myshell-kr-a` Pod도 하나 구성한다.

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

[Shell 1]은 Istio의 Locality Load Balancing을 테스트하기 위한 Kubernetes Cluster를 구성하는 Script를 나타내고 있다. kind를 활용하여 Kubernetes Cluster를 구성하고, Istio를 설치한다. 그리고 Node Label에 Topology 정보를 설정한다. Istio는 Node Label에 설정되어 있는 Topology 정보를 활용하여 Node의 Topology를 파악하기 때문에, Node Label 설정이 필수이다. 

Istio는 Node에 설정되어 있는 다음의 Label을 활용하여 Node의 Topology를 파악한다. [Figure 1]과 동일하게 region은 `kr`, `us` 두 가지 값을 가지고, zone은 `a`, `b` 두 가지 값을 설정하여 총 4개의 Locality를 구성한다.

* `topology.kubernetes.io/region` : Region 정보
* `topology.kubernetes.io/zone` : Zone 정보

```yaml {caption="[File 1] 기본 Workload Manifest", linenos=table}
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

[File 1]은 Locality Load Balancing을 테스트하기 위한 기본 Workload Manifest를 나타내고 있다. [Figure 1]과 동일하게 각 Deployment는 2개의 Pod와 4개의 Locality를 구성하여 총 8개의 Pod를 구성한다. 또한 하나의 Destination Rule과 Service, Virtual Service는 하나만 정의하여 모든 Deployment에 적용되도록 구성한다.

```shell {caption="[Shell 2] 요청 전송 명령어"}
$ kubectl exec -it my-shell-kr-a -- bash -c '
for i in {1..4}; do
  curl helloworld:5000/hello 
done
'
```

```text {caption="[Text 1] 요청 전송 결과"}
Hello version: v1, instance: helloworld-kr-a-57cdf4d447-gwnzb
Hello version: v1, instance: helloworld-us-a-7cfcf79cd4-grxlr
Hello version: v1, instance: helloworld-kr-b-7b95f679bd-8z7rv
Hello version: v1, instance: helloworld-us-b-59fd8576c5-grhkk
```

[Shell 2]는 `my-shell-kr-a` Pod에서 `helloworld` Service에 요청을 4번 전송하는 명령어를 나타내고 있다. [Text 1]은 [Shell 2]의 명령어를 실행한 결과를 나타내고 있다. 각 요청이 각 Locality의 Pod에 한번씩 분배되어 전송되는 것을 확인할 수 있다.

### 1.2. Outlier Detection 설정과 함께 Locality Load Balancing 적용

```yaml {caption="[File 2] Locality Load Balancing Distribute Example"}
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
Istio의 Locality Load Balancing을 가장 간단하게 활성화 할 수 있는 방법은 Destination Rule에서 `localityLbSetting.enabled` Field를 `true`로 설정과 함께 `outlierDetection` Field를 설정하는 것이다. `outlierDetection` Field를 설정하지 않으면 Locality Load Balancing이 활성화되지 않는다. [File 2]는 `outlierDetection` Field과 함께 Locality Load Balancing을 활성화하는 Destination Rule의 예제를 나타내고 있다.

```text {caption="[Text 2] Outlier Detection 설정과 함께 요청 전송 결과"}
Hello version: v1, instance: helloworld-kr-a-57cdf4d447-gwnzb
Hello version: v1, instance: helloworld-kr-a-57cdf4d447-gvgxg
Hello version: v1, instance: helloworld-kr-a-57cdf4d447-gwnzb
Hello version: v1, instance: helloworld-kr-a-57cdf4d447-gwnzb
```

[Shell 2]의 명령어를 실행하면 [Text 2]과 같은 결과를 확인할 수 있다. Locality Load Balancing이 활성화되어 `my-shell-kr-a` Pod가 위치하는 `kr/a` Locality의 Pod에만 요청이 전송되는 것을 확인할 수 있다.

```shell {caption="[Shell 3] helloworld-kr-a Deployment의 Replica를 1로 조정"}
$ kubectl scale deployment helloworld-kr-a --replicas 1
```

```text {caption="[Text 3] helloworld-kr-a Deployment의 Replica를 1로 조정 결과"}
Hello version: v1, instance: helloworld-kr-a-57cdf4d447-gwnzb
Hello version: v1, instance: helloworld-kr-a-57cdf4d447-gwnzb
Hello version: v1, instance: helloworld-kr-a-57cdf4d447-gwnzb
Hello version: v1, instance: helloworld-kr-a-57cdf4d447-gwnzb
```

[Shell 3]은 `helloworld-kr-a` Deployment의 Replica를 1로 조정후 요청을 전송하는 명령어를 나타내고 있다. [Text 3]은 [Shell 3]의 명령어를 실행한 결과를 나타내고 있다. `kr/a` Locality에 여전히 하나의 Pod가 존재하기 때문에, 모든 요청이 `kr/a` Locality의 Pod에 전송되는 것을 확인할 수 있다.

```shell {caption="[Shell 4] helloworld-kr-a Deployment의 Replica를 0으로 조정"}
$ kubectl scale deployment helloworld-kr-a --replicas 0
```

```text {caption="[Text 4] helloworld-kr-a Deployment의 Replica를 0으로 조정 결과"}
Hello version: v1, instance: helloworld-kr-b-7b95f679bd-fg8q5
Hello version: v1, instance: helloworld-kr-b-7b95f679bd-8z7rv
Hello version: v1, instance: helloworld-kr-b-7b95f679bd-fg8q5
Hello version: v1, instance: helloworld-kr-b-7b95f679bd-8z7rv
```

[Shell 4]는 `helloworld-kr-a` Deployment의 Replica를 0으로 조정후 요청을 전송하는 명령어를 나타내고 있다. [Text 4]은 [Shell 4]의 명령어를 실행한 결과를 나타내고 있다. `kr/a` Locality에 더이상 Pod가 존재하지 않기 때문에, 모든 요청이 `kr/b` Locality의 Pod에 전송되는 것을 확인할 수 있다.

### 1.2. Locality Load Balancing with Outlier Detection

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



## 2. 참조

* Istio Locality Load Balancing : [https://istio.io/latest/docs/tasks/traffic-management/locality-load-balancing/](https://istio.io/latest/docs/tasks/traffic-management/locality-load-balancing/)
* Istio Locality Load Balancing : [https://dobby-isfree.tistory.com/224](https://dobby-isfree.tistory.com/224)
* Destination Rule Global : [https://istio.io/latest/docs/reference/config/networking/destination-rule/#LocalityLoadBalancerSetting](https://istio.io/latest/docs/reference/config/networking/destination-rule/#LocalityLoadBalancerSetting)
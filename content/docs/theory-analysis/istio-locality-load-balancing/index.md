---
title: "Istio Locality Load Balancing"
draft: true
---

## 1. Istio Locality Load Balancing

Istio의 **Locality Load Balancing**은 의미 그대로 같은 Locality(지역성)에 존재하는 Pod에만 요청을 전송하는 기능을 의미한다. Locality Load Balancing 기능을 잘 활용하면 Network Hop을 최소화하여 요청 처리 속도를 높일 수 있으며, Cloud 환경에서는 같은 Region 또는 Zone에 존재하는 Pod에만 요청을 전송하여 네트워크 비용을 줄일 수 있다. Kubernetes Service에서 제공하는 **Topology Aware Load Balancing** 기능과 유사한 기능이다.

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

[Shell 1]은 Istio의 Locality Load Balancing을 테스트하기 위한 Kubernetes Cluster를 구성하는 Script를 나타내고 있다. `kind`를 활용하여 Kubernetes Cluster를 구성하고 Istio를 설치한다. 그리고 Node Label에 Topology 정보를 설정한다. Istio는 Node의 **Topology Label**을 통해서  Node의 Topology를 파악하기 때문에 Node Label 설정이 필수이다. Istio는 Node에 설정되어 있는 다음의 Topology Label을 활용한다.

* `topology.kubernetes.io/region` : Region 정보
* `topology.kubernetes.io/zone` : Zone 정보
* `topology.kubernetes.io/subzone` : Subzone 정보

[Figure 1]과 동일하게 region은 `kr`, `us` 두 가지 값을 가지고, zone은 `a`, `b` 두 가지 값을 설정하여 총 4개의 Locality를 구성한다. subzone은 설정하지 않는다.

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

[Shell 2]는 `my-shell-kr-a` Pod에서 `helloworld` Service에 요청을 4번 전송하는 명령어를 나타내고 있다. [Text 1]은 [Shell 2]의 명령어를 실행한 결과를 나타내고 있다. Locality Load Balancing이 적용되어 있지 않기 때문에, 각 요청이 모든 Locality의 Pod에 한번씩 분배되어 전송되는 것을 확인할 수 있다.

### 1.2. Locality Load Balancing 적용

{{< figure caption="[Figure 2] Locality Load Balancing 예제" src="images/locality-load-balancing.png" width="900px" >}}

[Figure 2]는 [Figure 1] 환경에서 Locality Load Balancing을 활성화한 모습을 나타내고 있다. `my-shell-kr-a` Pod가 `kr/a` Locality에 존재하기 때문에, 모든 요청도 `kr/a` Locality의 `helloworld` Service의 Pod에만 전송되는 것을 확인할 수 있다.

Locality Load Balancing은 Destination Rule에서 `localityLbSetting.enabled` Field를 `true`로 설정하여 활성화 한다. 이때 반드시 `outlierDetection` Field를 설정하여 Failover를 활성화 하거나, `distribute` Field를 설정하여 Distribution을 활성화 해야 한다. 단독으로 `localityLbSetting.enabled` Field를 `true`로 설정하는 경우에는 Locality Load Balancing이 활성화되지 않는다. 반대로 `outlierDetection` Field와 `distribute` Field를 같이 설정해도 Locality Load Balancing이 활성화 되지만, 일반적으로 `distribute` Field로 인해서 `outlierDetection` Field의 정책이 제대로 동작하지 않기 때문에 잘 이용되지 않는다.

#### 1.2.1. with Failover

Locality Load Balancing을 기능을 활용할 경우 고려해야 할 부분중에 하나는 가용성이다. Locality Load Balancing을 이용하지 않을 경우 Client의 요청은 모든 Locality의 Pod에 전송되기 때문에 높은 가용성이 보장된다. 반면에 Locality Load Balancing을 이용하는 경우에는 해당 Locality에 존재하는 Pod가 없는 경우에는 요청을 전송할 수 없기 때문에 가용성이 떨어질 수 있다.

Istio에서는 이러한 가용성 문제를 해결하기 위해서 Failover 기능을 제공한다. Failover 기능은 Destination Rule에서 `outlierDetection` Field를 설정하여 활성화할 수 있다. `outlierDetection` Field를 설정되면 Client와 동일한 Locality에 존재하는 Pod가 없는 경우에는 다른 Locality의 Pod에 요청을 전송할 수 있다. `outlierDetection` Field는 Server Pod의 비정상 상태를 판단하는 기준을 정의한다.

```yaml {caption="[File 2] Locality Load Balancing Outlier Detection 예제"}
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

```text {caption="[Text 2] Locality Load Balancing Outlier Detection 결과"}
Hello version: v1, instance: helloworld-kr-a-57cdf4d447-gwnzb
Hello version: v1, instance: helloworld-kr-a-57cdf4d447-gvgxg
Hello version: v1, instance: helloworld-kr-a-57cdf4d447-gwnzb
Hello version: v1, instance: helloworld-kr-a-57cdf4d447-gwnzb
```

[File 2]는 `outlierDetection` Field과 함께 Locality Load Balancing을 활성화하는 Destination Rule의 예제를 나타내고 있으며, [Shell 2]의 명령어를 실행하면 [Text 2]과 같은 결과를 확인할 수 있다. Locality Load Balancing이 활성화되어 `my-shell-kr-a` Pod가 위치하는 `kr/a` Locality의 Pod에만 요청이 전송되는 것을 확인할 수 있다.

##### 1.2.1.1. Zone Failover

{{< figure caption="[Figure 3] Locality Load Balancing Zone Failover 예제" src="images/locality-load-balancing-failover-zone.png" width="900px" >}}

[Figure 3]은 [Figure 2]의 상태에서 `my-shell-kr-a` Pod가 위치하는 `kr/a` Zone의 모든 `helloworld` Pod를 제거할 경우 동작하는 Zone Failover의 모습을 나타내고 있다. `my-shell-kr-a` Pod가 위치하는 Zone에 `helloworld` Pod가 없기 때문에, 모든 요청이 `kr/b` Zone의 Pod에 전송되는 것을 확인할 수 있다. `us/a`와 `us/b` Locality에 존재하는 Pod에는 요청이 전송되지 않는 이유는, `kr/b`이 `kr/a`와 동일한 Region에 존재하기 때문에 `us/a`, `us/b` 보다 Locality 우선순위가 더 높기 때문이다. 이러한 Locality 우선순위는 Destination Rule에서 `failoverPriority` Field를 통해서 설정할 수 있다.

```shell {caption="[Shell 3] helloworld-kr-a Deployment의 Replica를 0으로 조정"}
$ kubectl scale deployment helloworld-kr-a --replicas 0
$ kubectl scale deployment helloworld-kr-b --replicas 2
```

```text {caption="[Text 3] helloworld-kr-a Deployment의 Replica를 0으로 조정 결과"}
Hello version: v1, instance: helloworld-kr-b-7b95f679bd-fg8q5
Hello version: v1, instance: helloworld-kr-b-7b95f679bd-8z7rv
Hello version: v1, instance: helloworld-kr-b-7b95f679bd-fg8q5
Hello version: v1, instance: helloworld-kr-b-7b95f679bd-8z7rv
```

[Shell 3]는 `helloworld-kr-a` Deployment의 Replica를 0으로 조정하는 명령어를 나타내고 있으며, [Text 3]은 [Shell 2]의 명령어를 실행한 결과를 나타내고 있다. `kr/a` Locality에 더이상 Pod가 존재하지 않기 때문에, 모든 요청이 `kr/b` Locality의 Pod에만 전송되는 것을 확인할 수 있다. 즉 Failover 기능이 활성화되어 요청이 다른 Locality의 Pod에 전송되는 것을 확인할 수 있다.

##### 1.2.1.2. Region Failover

{{< figure caption="[Figure 4] Locality Load Balancing Region Failover 예제" src="images/locality-load-balancing-failover-region.png" width="900px" >}}

[Figure 4]는 [Figure 2]의 상태에서 `my-shell-kr-a` Pod가 위치하는 `kr` Region의 모든 `helloworld` Pod를 제거할 경우 동작하는 Region Failover의 모습을 나타내고 있다. `my-shell-kr-a` Pod가 위치하는 Region에 `helloworld` Pod가 없기 때문에, 모든 요청이 `us/a`와 `us/b` Locality의 Pod에 분배되는 것을 확인할 수 있다. `us/a`, `us/b` Locality가 동일한 우선순위를 갖기 때문에 Traffic도 균등하게 분배된다.

```shell {caption="[Shell 4] helloworld-kr-a, helloworld-kr-b Deployment의 Replica를 0으로 조정"}
$ kubectl scale deployment helloworld-kr-a --replicas 0
$ kubectl scale deployment helloworld-kr-b --replicas 0
```

```text {caption="[Text 4] helloworld-kr-a, helloworld-kr-b Deployment의 Replica를 0으로 조정 결과"}
Hello version: v1, instance: helloworld-us-a-7cfcf79cd4-grxlr
Hello version: v1, instance: helloworld-us-b-59fd8576c5-grhkk
Hello version: v1, instance: helloworld-us-a-7cfcf79cd4-grxlr
Hello version: v1, instance: helloworld-us-b-59fd8576c5-qd85k
```

[Shell 4]는 `helloworld-kr-a`와 `helloworld-kr-b` Deployment의 Replica를 0으로 조정하는 명령어를 나타내고 있으며, [Text 4]은 [Shell 2]의 명령어를 실행한 결과를 나타내고 있다. `kr/a`, `kr/b` Locality에 더이상 Pod가 존재하지 않기 때문에, `us/a`, `us/b` Locality가 동일한 우선순위를 갖는다. 따라서 모든 요청이 `us/a`, `us/b` Locality의 Pod에 균등하게 분배되는 것을 확인할 수 있다.

##### 1.2.1.3. Zone에 일부 Pod만 존재

{{< figure caption="[Figure 5] Locality Load Balancing Only One Pod" src="images/locality-load-balancing-failover-zone-one-pod.png" width="900px" >}}

[Figure 5]는 [Figure 2]의 상태에서 `my-shell-kr-a` Pod가 위치하는 `kr/a` Locality에 하나의 `helloworld` Pod만 존재하는 경우 동작하는 모습을 나타내고 있다. 모든 요청이 `kr/a` Locality의 단일 Pod에 전송되는 것을 확인할 수 있다. Istio의 Locality Load Balancing은 각 Locality 마다 Server Pod의 개수의 차이가 너무 커도 **하나의 Server Pod**라도 Client와 동일한 Locality에 존재하면 해당 Server Pod에 요청을 전송한다. Kubernetes Service의 Topology Aware Load Balancing은 Locality 사이의 Pod 개수가 너무 큰 차이가 발생하는 경우에는 **Guardrail**로 인해서 기능이 중지되는것과 대비되는 부분이다.

각 Locality에 존재하는 Server Pod의 개수의 차이가 커지수록, 각 Server Pod가 받는 요청의 불균형도 커진다. 이러한 불균형을 해결하기 위해서는 Pod에 `topologySpreadConstraint`를 설정하여 각 Locality에 존재하는 Server Pod의 개수를 동일하게 유지하도록 만들어야 한다. 

```shell {caption="[Shell 5] helloworld-kr-a Deployment의 Replica를 1로 조정"}
$ kubectl scale deployment helloworld-kr-a --replicas 1
$ kubectl scale deployment helloworld-kr-b --replicas 2
```

```text {caption="[Text 5] helloworld-kr-a Deployment의 Replica를 1로 조정 결과"}
Hello version: v1, instance: helloworld-kr-a-57cdf4d447-gwnzb
Hello version: v1, instance: helloworld-kr-a-57cdf4d447-gwnzb
Hello version: v1, instance: helloworld-kr-a-57cdf4d447-gwnzb
Hello version: v1, instance: helloworld-kr-a-57cdf4d447-gwnzb
```

[Shell 5]은 `helloworld-kr-a` Deployment의 Replica를 1로, `helloworld-kr-b` Deployment의 Replica를 2로 조정하는 명령어를 나타내고 있으며, [Text 5]은 [Shell 4]의 명령어를 실행한 결과를 나타내고 있다. `kr/a` Locality에 여전히 하나의 Pod가 존재하기 때문에, 모든 요청이 `kr/a` Locality의 Pod에 전송되는 것을 확인할 수 있다.

#### 1.2.2. with Distribution

Locality Load Balancing은 Traffic을 Client Pod와 동일한 Locality의 Server Pod에만 전송하는 기능뿐만이 아니라, 다른 Locality의 Server Pod에도 명시적으로 요청을 전송하도록 만들 수 있는 Distribution 기능도 제공한다. Distribution 기능은 Destination Rule에서 `distribute` Field를 통해서 활성화할 수 있다.

```yaml {caption="[File 3] Locality Load Balancing Distribute 예제"}
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

```shell {caption="[Text 6] Locality Load Balancing Distribute 결과"}
Hello version: v1, instance: helloworld-kr-a-57cdf4d447-skvgp
Hello version: v1, instance: helloworld-kr-a-57cdf4d447-rw56z
Hello version: v1, instance: helloworld-kr-a-57cdf4d447-skvgp
Hello version: v1, instance: helloworld-kr-a-57cdf4d447-skvgp
```

[File 3]은 `distribute` Field과 함께 Locality Load Balancing을 활성화하는 Destination Rule의 예제를 나타내고 있으며, [Shell 2]의 명령어를 실행하면 [Text 6]과 같은 결과를 확인할 수 있다. `from`과 `to`에는 `region/zone/subzone` 형태로 Traffic을 어느 Locality로 전송할지를 **Weight**과 함께 정의한다. 이때 Weight의 합은 100이어야 한다. [File 3]은 Client의 모든 요청이 동일한 Locality의 Server Pod에만 전송되도록 설정되어 있어 [Figure 1]과 같은 결과를 확인할 수 있다.

```yaml {caption="[File 4] Locality Load Balancing Distribute Cross Region 예제"}
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

[File 4]는 Distribution 기능을 통해서 Cross Region을 구성하는 예제를 나타내고 있다. `kr` Region에서 전송한 요청은 `us` Region의 Pod으로 전송되며 반대로 `us` Region에서 전송한 요청은 `kr` Region의 Pod으로 전송되는 것을 확인할 수 있다. 또한 Zone 사이의 Traffic은 80:20의 비율로 분배되는 것을 확인할 수 있다.

{{< figure caption="[Figure 6] Locality Load Balancing Distribute Cross Region Example" src="images/locality-load-balancing-distribution-cross-region.png" width="900px" >}}

```text {caption="[Text 7] Locality Load Balancing Distribute Cross Region 결과"}
Hello version: v1, instance: helloworld-us-b-59fd8576c5-grhkk
Hello version: v1, instance: helloworld-us-b-59fd8576c5-grhkk
Hello version: v1, instance: helloworld-us-b-59fd8576c5-grhkk
Hello version: v1, instance: helloworld-us-a-7cfcf79cd4-grxlr
```

[Figure 6]과 [Text 7]은 [File 4]의 명령어를 실행한 결과를 나타내고 있다. 모든 Traffic이 `us` Region의 Pod에 전송되는 것을 확인할 수 있다.

## 2. 참조

* Istio Locality Load Balancing : [https://istio.io/latest/docs/tasks/traffic-management/locality-load-balancing/](https://istio.io/latest/docs/tasks/traffic-management/locality-load-balancing/)
* Istio Locality Load Balancing : [https://dobby-isfree.tistory.com/224](https://dobby-isfree.tistory.com/224)
* Destination Rule Global : [https://istio.io/latest/docs/reference/config/networking/destination-rule/#LocalityLoadBalancerSetting](https://istio.io/latest/docs/reference/config/networking/destination-rule/#LocalityLoadBalancerSetting)
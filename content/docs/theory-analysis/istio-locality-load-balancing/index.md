---
title: "Istio Locality Load Balancing"
draft: true
---

## 1. Istio Locality Load Balancing

### 1.1. Deploy

```shell
$ kind create cluster --config=- <<EOF                           
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
- role: worker
EOF

kubectl -n istio-system patch deployment istiod --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/env/-", "value": {"name": "PILOT_ENABLE_LOCALITY_LOAD_BALANCING", "value": "true"}}]'

$ kubectl label node kind-worker topology.kubernetes.io/region=kr
$ kubectl label node kind-worker2 topology.kubernetes.io/region=kr
$ kubectl label node kind-worker3 topology.kubernetes.io/region=kr

$ kubectl label node kind-worker topology.kubernetes.io/zone=a
$ kubectl label node kind-worker2 topology.kubernetes.io/zone=b
$ kubectl label node kind-worker3 topology.kubernetes.io/zone=c
```

```yaml {caption="[File 1] Locality Load Balancing Example", linenos=table}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: helloworld-zone-a
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
  name: helloworld-zone-b
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
  name: helloworld-zone-c
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
        topology.kubernetes.io/zone: c
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
  name: netshoot-b
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

```shell
$ kubectl get pod -o wide        
NAME                                 READY   STATUS    RESTARTS   AGE   IP            NODE           NOMINATED NODE   READINESS GATES
helloworld-zone-a-87c7fd898-7jdfm    2/2     Running   0          56s   10.244.3.14   kind-worker    <none>           <none>
helloworld-zone-a-87c7fd898-cs8c9    2/2     Running   0          56s   10.244.3.12   kind-worker    <none>           <none>
helloworld-zone-a-87c7fd898-wxfrw    2/2     Running   0          56s   10.244.3.13   kind-worker    <none>           <none>
helloworld-zone-b-d48b9c6cc-c9xsx    2/2     Running   0          56s   10.244.2.15   kind-worker2   <none>           <none>
helloworld-zone-b-d48b9c6cc-nzqt8    2/2     Running   0          56s   10.244.2.14   kind-worker2   <none>           <none>
helloworld-zone-b-d48b9c6cc-sbr8z    2/2     Running   0          56s   10.244.2.13   kind-worker2   <none>           <none>
helloworld-zone-c-6667db9dbd-gpclb   2/2     Running   0          56s   10.244.1.13   kind-worker3   <none>           <none>
helloworld-zone-c-6667db9dbd-p964l   2/2     Running   0          56s   10.244.1.14   kind-worker3   <none>           <none>
helloworld-zone-c-6667db9dbd-qbfl7   2/2     Running   0          56s   10.244.1.12   kind-worker3   <none>           <none>
netshoot-b                           2/2     Running   0          33m   10.244.2.6    kind-worker2   <none>           <none>
```

```shell
$ istioctl proxy-config all netshoot-b | grep kr
endpoint/10.244.3.12:5000                                 HEALTHY     kr/a         outbound|5000||helloworld-svc.default.svc.cluster.local
endpoint/10.244.3.13:5000                                 HEALTHY     kr/a         outbound|5000||helloworld-svc.default.svc.cluster.local
endpoint/10.244.3.14:5000                                 HEALTHY     kr/a         outbound|5000||helloworld-svc.default.svc.cluster.local
endpoint/10.244.2.13:5000                                 HEALTHY     kr/b         outbound|5000||helloworld-svc.default.svc.cluster.local
endpoint/10.244.2.15:5000                                 HEALTHY     kr/b         outbound|5000||helloworld-svc.default.svc.cluster.local
endpoint/10.244.2.14:5000                                 HEALTHY     kr/b         outbound|5000||helloworld-svc.default.svc.cluster.local
endpoint/10.244.1.13:5000                                 HEALTHY     kr/c         outbound|5000||helloworld-svc.default.svc.cluster.local
endpoint/10.244.1.12:5000                                 HEALTHY     kr/c         outbound|5000||helloworld-svc.default.svc.cluster.local
endpoint/10.244.1.14:5000                                 HEALTHY     kr/c         outbound|5000||helloworld-svc.default.svc.cluster.local
...
```

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
```

```shell
$ kubectl exec -it netshoot-b -- bash
(netshoot-b)# curl helloworld-svc:5000/hello
Hello version: v1, instance: helloworld-zone-c-6667db9dbd-gpclb
(netshoot-b)# curl helloworld-svc:5000/hello
Hello version: v1, instance: helloworld-zone-a-87c7fd898-cs8c9
(netshoot-b)# curl helloworld-svc:5000/hello
Hello version: v1, instance: helloworld-zone-a-87c7fd898-cs8c9
```

## 2. 참조

* Istio Locality Load Balancing : [https://istio.io/latest/docs/tasks/traffic-management/locality-load-balancing/](https://istio.io/latest/docs/tasks/traffic-management/locality-load-balancing/)
* Istio Locality Load Balancing : [https://dobby-isfree.tistory.com/224](https://dobby-isfree.tistory.com/224)
* Destination Rule Global : [https://istio.io/latest/docs/reference/config/networking/destination-rule/#LocalityLoadBalancerSetting](https://istio.io/latest/docs/reference/config/networking/destination-rule/#LocalityLoadBalancerSetting)
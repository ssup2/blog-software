---
title: Istio Sidecar Object
---

## 1. Istio Sidecar Object

Istio에서 제공하는 Sidecar Object는 Istio의 Sidecar Proxy의 Inbound, Outbound Traffic 관련 설정을 세세하게 제어할 때 이용한다. 일반적으로는 Sidecar Proxy가 관리하는 Endpoint를 제한하여 Egress 통신을 제한하거나, Endpoint 개수를 줄여서 istiod의 부하를 줄이는 용도로 활용된다.

### 1.1. Sidecar Object Test 환경

```shell {caption="[Shell 1] Sidecar Object Test Environment"}
$ kubectl -n bookinfo get pod -o wide
NAME                             READY   STATUS    RESTARTS   AGE   IP            NODE           NOMINATED NODE   READINESS GATES
details-v1-79dfbd6fff-l876n      2/2     Running   0          18m   10.244.1.29   kind-worker2   <none>           <none>
productpage-v1-dffc47f64-qw4bk   2/2     Running   0          18m   10.244.1.32   kind-worker2   <none>           <none>
ratings-v1-65f797b499-rftkh      2/2     Running   0          18m   10.244.1.30   kind-worker2   <none>           <none>
reviews-v1-5c4d6d447c-qwmbv      2/2     Running   0          18m   10.244.2.31   kind-worker    <none>           <none>
reviews-v2-65cb66b45c-dtwjd      2/2     Running   0          18m   10.244.1.31   kind-worker2   <none>           <none>
reviews-v3-f68f94645-bmzrn       2/2     Running   0          18m   10.244.2.32   kind-worker    <none>           <none>

$ kubectl -n bookinfo get service -o wide
NAME          TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE   SELECTOR
details       ClusterIP   10.96.117.59    <none>        9080/TCP   20m   app=details
productpage   ClusterIP   10.96.159.57    <none>        9080/TCP   20m   app=productpage
ratings       ClusterIP   10.96.116.237   <none>        9080/TCP   20m   app=ratings
reviews       ClusterIP   10.96.209.151   <none>        9080/TCP   20m   app=reviews

$ kubectl -n default get pod
NAME      READY   STATUS    RESTARTS      AGE
my-shell  2/2     Running   0             81m
```

[Shell 1]은 Sidecar Object Test를 위한 환경을 보여주고 있다. `bookinfo` Namespace에는 Istio에서 제공하는 Bookinfo Example을 활용하여 관련 Service와 Pod를 동작시키고 있다. `default` Namespace에는 `bookinfo` Namespace의 `reviews` Service에 요청을 생성하기 위한 `my-shell` Pod가 동작하고 있다.

```shell {caption="[Shell 2] my-shell Pod에서 reviews 서비스 호출"}
$ curl 10.96.209.151:9080/reviews/1
{"id": "1","podname": "reviews-v3-f68f94645-bmzrn","clustername": "null","reviews": [{  "reviewer": "Reviewer1",  "text": "An extremely entertaining play by Shakespeare. The slapstick humour is refreshing!", "rating": {"stars": 5, "color": "red"}},{  "reviewer": "Reviewer2",  "text": "Absolutely fun and entertaining. The play lacks thematic depth when compared to other plays by Shakespeare.", "rating": {"stars": 4, "color": "red"}}]}
```

[Shell 2]는 `my-shell` Pod에서 `bookinfo` Namespace의 `reviews` Service에 요청을 보내고 받은 응답을 보여주고 있다. `10.96.209.151` IP 주소는 `reviews` Service의 ClusterIP이다. `reviews` Service로 요청을 보낼시 tcpdump를 통해서 Sidecar Object 적용 유무에 따라서 Packet이 어떻게 전송되는지 확인할 예정이다.

### 1.2. Sidecar Object 적용 전

```shell {caption="[Shell 3] Sidecar Object 적용 전 my-shell Pod Sidecar Proxy의 Endpoint 목록"}
$ istioctl proxy-config endpoint my-shell
ENDPOINT                                                STATUS      OUTLIER CHECK     CLUSTER
10.244.0.3:53                                           HEALTHY     OK                outbound|53||kube-dns.kube-system.svc.cluster.local
10.244.0.3:9153                                         HEALTHY     OK                outbound|9153||kube-dns.kube-system.svc.cluster.local
10.244.0.4:53                                           HEALTHY     OK                outbound|53||kube-dns.kube-system.svc.cluster.local
10.244.0.4:9153                                         HEALTHY     OK                outbound|9153||kube-dns.kube-system.svc.cluster.local
10.244.1.2:15010                                        HEALTHY     OK                outbound|15010||istiod.istio-system.svc.cluster.local
10.244.1.2:15012                                        HEALTHY     OK                outbound|15012||istiod.istio-system.svc.cluster.local
10.244.1.2:15014                                        HEALTHY     OK                outbound|15014||istiod.istio-system.svc.cluster.local
10.244.1.2:15017                                        HEALTHY     OK                outbound|443||istiod.istio-system.svc.cluster.local
10.244.1.29:9080                                        HEALTHY     OK                outbound|9080||details.bookinfo.svc.cluster.local
10.244.1.30:9080                                        HEALTHY     OK                outbound|9080||ratings.bookinfo.svc.cluster.local
10.244.1.31:9080                                        HEALTHY     OK                outbound|9080||reviews.bookinfo.svc.cluster.local
10.244.1.32:9080                                        HEALTHY     OK                outbound|9080||productpage.bookinfo.svc.cluster.local
10.244.2.28:8080                                        HEALTHY     OK                outbound|80||istio-ingressgateway.istio-system.svc.cluster.local
10.244.2.28:8443                                        HEALTHY     OK                outbound|443||istio-ingressgateway.istio-system.svc.cluster.local
10.244.2.28:15021                                       HEALTHY     OK                outbound|15021||istio-ingressgateway.istio-system.svc.cluster.local
10.244.2.28:15443                                       HEALTHY     OK                outbound|15443||istio-ingressgateway.istio-system.svc.cluster.local
10.244.2.28:31400                                       HEALTHY     OK                outbound|31400||istio-ingressgateway.istio-system.svc.cluster.local
10.244.2.29:8080                                        HEALTHY     OK                outbound|80||istio-egressgateway.istio-system.svc.cluster.local
10.244.2.29:8443                                        HEALTHY     OK                outbound|443||istio-egressgateway.istio-system.svc.cluster.local
10.244.2.31:9080                                        HEALTHY     OK                outbound|9080||reviews.bookinfo.svc.cluster.local
10.244.2.32:9080                                        HEALTHY     OK                outbound|9080||reviews.bookinfo.svc.cluster.local
...
```

[Shell 3]은 Sidecar Object 적용 전 `my-shell` Pod의 Sidecar Proxy에 설정된 Endpoint 목록을 나타내고 있다. Kubernetes Cluster에 존재하는 대부분의 Endpoint들이 존재하며, `bookinfo` Namespace에 존재하는 서비스들도 확인할 수 있다.

```shell {caption="[Shell 4] Sidecar Object 적용 전 my-shell Pod가 동작하는 Node에서 tcpdump 수행"}
$ tcpdump -i veth5f577e0f dst port 9080
14:57:02.572059 IP 10.244.2.34.44644 > 10.244.2.32.9080: Flags [P.], seq 3112:3890, ack 5085, win 684, options [nop,nop,TS val 1627817850 ecr 1863232535], length 778
14:57:02.586416 IP 10.244.2.34.44644 > 10.244.2.32.9080: Flags [.], ack 6356, win 684, options [nop,nop,TS val 1627817864 ecr 1863242761], length 0
14:57:03.368051 IP 10.244.2.34.35610 > 10.244.2.31.9080: Flags [P.], seq 778:1556, ack 1197, win 674, options [nop,nop,TS val 1871835149 ecr 3884956713], length 778
14:57:03.373794 IP 10.244.2.34.35610 > 10.244.2.31.9080: Flags [.], ack 2393, win 685, options [nop,nop,TS val 1871835155 ecr 3884976887], length 0
14:57:04.808147 IP 10.244.2.34.32956 > 10.244.1.31.9080: Flags [P.], seq 5684:6462, ack 8451, win 636, options [nop,nop,TS val 3824446528 ecr 1562128845], length 778
14:57:04.825053 IP 10.244.2.34.32956 > 10.244.1.31.9080: Flags [.], ack 9732, win 658, options [nop,nop,TS val 3824446545 ecr 1562142003], length 0
14:57:06.579253 IP 10.244.2.34.39690 > 10.244.2.31.9080: Flags [P.], seq 778:1556, ack 1197, win 601, options [nop,nop,TS val 1871838360 ecr 3884970399], length 778
14:57:06.585129 IP 10.244.2.34.39690 > 10.244.2.31.9080: Flags [.], ack 2393, win 623, options [nop,nop,TS val 1871838366 ecr 3884980099], length 0
...
```

{{< figure caption="[Figure 1] Sidecar Object 적용 전 Traffic Flow" src="images/traffic-flow-without-sidecar-object.png" width="700px" >}}

[Shell 4]는 Sidecar Object 적용 전 `my-shell` Pod에서 `reviews` Service에 요청을 보낼시 `my-shell` Pod의 Node에서 `my-shell` Pod의 veth Interface에 tcpdump를 수행한 모습을 나타내고 있다. `my-shell` Pod에서는 `reviews` Service의 ClusterIP로 요청을 전송하지만, Sidecar Proxy에서 DNAT를 수행하기 때문에 tcpdump에서는 3개의 `reviews` Pod의 IP가 보이는것을 확인할 수 있다. [Figure 1]은 이러한 Traffic의 흐름을 간단하게 나타내고 있다.

### 1.3. Sidecar Object 적용 후

```yaml {caption="[File 1] default Namespace의 Default Sidecar Object"}
apiVersion: networking.istio.io/v1
kind: Sidecar
metadata:
  namespace: default
  name: default
spec:
  egress:
  - hosts:
    - "./*"
    - "istio-system/*"
```

[File 1]은 `default` Namespace의 모든 Pod에 적용되는 Sidecar Object를 나타내고 있다. Sidecar Object는 각 Namespace마다 정의가 필요하다. `my-shell` Pod도 `default` Namespace에 존재하기 때문에 [File 1]의 Sidecar Object 설정에 영향을 받는다. `./*`는 Sidecar Object가 존재하는 Namespace 즉 `default` Namespace의 모든 Endpoint를 나타내며, `istio-system/*`는 `istio-system` Namespace의 모든 Endpoint를 나타낸다. 하지만 `bookinfo` Namespace는 제외되어 있는것을 확인할 수 있다.

```shell {caption="[Shell 5] Sidecar Object 적용 후 my-shell Pod Sidecar Proxy의 Endpoint 목록"}
$ istioctl proxy-config endpoint my-shell
ENDPOINT                                                STATUS      OUTLIER CHECK     CLUSTER
10.244.1.2:15010                                        HEALTHY     OK                outbound|15010||istiod.istio-system.svc.cluster.local
10.244.1.2:15012                                        HEALTHY     OK                outbound|15012||istiod.istio-system.svc.cluster.local
10.244.1.2:15014                                        HEALTHY     OK                outbound|15014||istiod.istio-system.svc.cluster.local
10.244.1.2:15017                                        HEALTHY     OK                outbound|443||istiod.istio-system.svc.cluster.local
10.244.2.28:8080                                        HEALTHY     OK                outbound|80||istio-ingressgateway.istio-system.svc.cluster.local
10.244.2.28:8443                                        HEALTHY     OK                outbound|443||istio-ingressgateway.istio-system.svc.cluster.local
10.244.2.28:15021                                       HEALTHY     OK                outbound|15021||istio-ingressgateway.istio-system.svc.cluster.local
10.244.2.28:15443                                       HEALTHY     OK                outbound|15443||istio-ingressgateway.istio-system.svc.cluster.local
10.244.2.28:31400                                       HEALTHY     OK                outbound|31400||istio-ingressgateway.istio-system.svc.cluster.local
10.244.2.29:8080                                        HEALTHY     OK                outbound|80||istio-egressgateway.istio-system.svc.cluster.local
10.244.2.29:8443                                        HEALTHY     OK                outbound|443||istio-egressgateway.istio-system.svc.cluster.local
127.0.0.1:15000                                         HEALTHY     OK                prometheus_stats
```

[Shell 5]는 [File 1]의 Sidecar Object 적용 후 `my-shell` Pod의 Sidecar Proxy에 설정된 Endpoint 목록을 나타내고 있다. [Shell 3]의 내용과 다르게 `bookinfo` Namespace의 Endpoint들이 존재하지 않는것을 확인할 수 있다. 이처럼 Sidecar Object를 활용하여 Sidecar Proxy에 등록되는 Endpoint 설정할 수 있다. 이는 각 Pod의 Egress 목적지를 모두 Sidecar Object에 등록하면 Endpoint의 개수를 줄일수 있는것을 의미한다. 물론 Kubernetes Cluster를 관리하는 조직에서 각 Pod의 모든 Egress 목적지를 파악하고 갱신하는 것은 쉬운일은 아니다.

Sidecar Object는 기본적으로 Pod의 Traffic을 차단하는 기법이 아니다. 따라서 Pod에서 Sidecar Object로 인해서 Endpoint에 존재하지 않는 Egress 목적지로 Traffic을 전송하면 Traffic은 그대로 전송된다. Sidecar Proxy는 존재하지 않는 Endpoint로 Traffic을 전송하는 경우에는 Traffic을 **Unmatched Traffic**으로 간주하며 해당 Traffic을 그대로 **통과**시키기 때문이다. 즉 Mesh Network를 이용하지 못핣뿐 Traffic 통과되며, 통과된 Traffic은 목적지에 따라서 kube-proxy나 외부 Load Balancer에 의해서 라우팅 되거나, 관련 라우팅 룰이 없다면 Drop 될 수 있다.

Sidecar Object로 인해서 Endpoint가 존재하지 않더라도 Traffic은 통과되기 일부 Endpoint각 Sidecar Object에 누락되더라도 서비스 장애까지는 이어지지 않을수 있다. 다만 Mesh Network를 활용할 수 없기 때문에 가능하면 Pod의 Egress 목적지를 모두 Sidecar Object에 등록해야한다.

```shell {caption="[Shell 6] Sidecar Object 적용 후 my-shell Pod가 동작하는 Node에서 tcpdump 수행"}
15:10:06.153435 IP 10.244.2.34.42122 > 10.96.209.151.9080: Flags [S], seq 1197298391, win 64240, options [mss 1460,sackOK,TS val 954649444 ecr 0,nop,wscale 7], length 0
15:10:06.153588 IP 10.244.2.34.42122 > 10.96.209.151.9080: Flags [.], ack 211632145, win 502, options [nop,nop,TS val 954649444 ecr 1864026328], length 0
15:10:06.153903 IP 10.244.2.34.42122 > 10.96.209.151.9080: Flags [P.], seq 0:90, ack 1, win 502, options [nop,nop,TS val 954649445 ecr 1864026328], length 90
15:10:06.277466 IP 10.244.2.34.42122 > 10.96.209.151.9080: Flags [.], ack 728, win 497, options [nop,nop,TS val 954649568 ecr 1864026452], length 0
15:10:06.277722 IP 10.244.2.34.42122 > 10.96.209.151.9080: Flags [F.], seq 90, ack 728, win 497, options [nop,nop,TS val 954649568 ecr 1864026452], length 0
15:10:06.277808 IP 10.244.2.34.42122 > 10.96.209.151.9080: Flags [.], ack 729, win 497, options [nop,nop,TS val 954649569 ecr 1864026453], length 0
15:10:13.708597 IP 10.244.2.34.46354 > 10.96.209.151.9080: Flags [S], seq 3363835136, win 64240, options [mss 1460,sackOK,TS val 954656999 ecr 0,nop,wscale 7], length 0
15:10:13.708694 IP 10.244.2.34.46354 > 10.96.209.151.9080: Flags [.], ack 931089404, win 502, options [nop,nop,TS val 954656999 ecr 1864033883], length 0
15:10:13.708881 IP 10.244.2.34.46354 > 10.96.209.151.9080: Flags [P.], seq 0:90, ack 1, win 502, options [nop,nop,TS val 954657000 ecr 1864033883], length 90
15:10:13.731894 IP 10.244.2.34.46354 > 10.96.209.151.9080: Flags [.], ack 727, win 497, options [nop,nop,TS val 954657023 ecr 1864033907], length 0
15:10:13.732244 IP 10.244.2.34.46354 > 10.96.209.151.9080: Flags [F.], seq 90, ack 727, win 497, options [nop,nop,TS val 954657023 ecr 1864033907], length 0
15:10:13.732331 IP 10.244.2.34.46354 > 10.96.209.151.9080: Flags [.], ack 728, win 497, options [nop,nop,TS val 954657023 ecr 1864033907], length 0
...
```

{{< figure caption="[Figure 2] Sidecar Object 적용 후 Traffic Flow" src="images/traffic-flow-with-sidecar-object.png" width="700px" >}}

[Shell 6]은 Sidecar Object 적용 후 `my-shell` Pod에서 `reviews` Service에 요청을 보낼시 `my-shell` Pod의 Node에서 `my-shell` Pod의 veth Interface에 tcpdump를 수행한 모습을 나타내고 있다. `reviews` Service의 ClusterIP가 Destination IP로 설정되어 있는것을 확인할 수 있다. 즉 `my-shell` Pod의 Egress Traffic은 Sidecar Proxy를 그대로 **통과**하여 DNAT가 되지 않고, Node의 kube-proxy (iptables)로 인해서 DNAT가 된다는 사실을 알 수 있다. [Figure 2]는 이러한 Traffic의 흐름을 간단하게 나타내고 있다.

### 1.4. workloadSelector 활용

```yaml {caption="[File 2] Sidecar Object의 workloadSelector 예시"}
apiVersion: networking.istio.io/v1
kind: Sidecar
metadata:
  namespace: default
  name: default
spec:
  workloadSelector:
    labels:
      app: reviews
  egress:
  - hosts:
    - "./*"
    - "istio-system/*"
```

[File 2]는 Sidecar Object를 Namespace 전체가 아니라, Namespace의 특정 Pod에만 적용하는 예제를 나타내고 있다. `workloadSelector`를 활용하여 Sidecar Ojbect가 적용될 Pod의 Label을 선택하면 된다.

## 2. 참조

* Istio Sidecar Object : [https://istio.io/latest/docs/reference/config/networking/sidecar/](https://istio.io/latest/docs/reference/config/networking/sidecar/)
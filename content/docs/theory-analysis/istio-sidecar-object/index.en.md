---
title: Istio Sidecar Object
---

## 1. Istio Sidecar Object

The Sidecar Object provided by Istio is used to finely control Inbound and Outbound Traffic settings of Istio's Sidecar Proxy. Generally, it is used to limit Outbound communication by restricting endpoints managed by the Sidecar Proxy, or to reduce the load on istiod by reducing the number of endpoints.

### 1.1. Sidecar Object Test Environment

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

[Shell 1] shows the environment for Sidecar Object testing. In the `bookinfo` namespace, related services and pods are running using Istio's Bookinfo Example. In the `default` namespace, a `my-shell` pod is running to generate requests to the `reviews` service in the `bookinfo` namespace.

```shell {caption="[Shell 2] Calling reviews service from my-shell Pod"}
$ curl 10.96.209.151:9080/reviews/1
{"id": "1","podname": "reviews-v3-f68f94645-bmzrn","clustername": "null","reviews": [{  "reviewer": "Reviewer1",  "text": "An extremely entertaining play by Shakespeare. The slapstick humour is refreshing!", "rating": {"stars": 5, "color": "red"}},{  "reviewer": "Reviewer2",  "text": "Absolutely fun and entertaining. The play lacks thematic depth when compared to other plays by Shakespeare.", "rating": {"stars": 4, "color": "red"}}]}
```

[Shell 2] shows the request sent from the `my-shell` pod to the `reviews` service in the `bookinfo` namespace and the received response. The IP address `10.96.209.151` is the ClusterIP of the `reviews` service. When sending requests to the `reviews` service, we will check how packets are transmitted through tcpdump depending on whether the Sidecar Object is applied.

### 1.2. Before Applying Sidecar Object

```shell {caption="[Shell 3] Endpoint list of my-shell Pod Sidecar Proxy before applying Sidecar Object"}
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

[Shell 3] shows the endpoint list configured in the Sidecar Proxy of the `my-shell` pod before applying the Sidecar Object. Most endpoints existing in the Kubernetes cluster are present, and services in the `bookinfo` namespace can also be seen.

```shell {caption="[Shell 4] Performing tcpdump on the Node where my-shell Pod runs before applying Sidecar Object"}
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

{{< figure caption="[Figure 1] Traffic Flow before applying Sidecar Object" src="images/traffic-flow-without-sidecar-object.png" width="700px" >}}

[Shell 4] shows tcpdump being performed on the veth interface of the `my-shell` pod on the node where the `my-shell` pod runs when sending requests to the `reviews` service before applying the Sidecar Object. The `my-shell` pod sends requests to the ClusterIP of the `reviews` service, but since the Sidecar Proxy performs DNAT, we can see the IPs of 3 `reviews` pods in tcpdump. [Figure 1] simply shows the flow of this traffic.

### 1.3. After Applying Sidecar Object

```yaml {caption="[File 1] Default Sidecar Object for default Namespace"}
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

[File 1] shows the Sidecar Object applied to all pods in the `default` namespace. Sidecar Object needs to be defined for each namespace. Since the `my-shell` pod also exists in the `default` namespace, it is affected by the Sidecar Object settings in [File 1]. `./*` represents all endpoints in the namespace where the Sidecar Object exists, i.e., the `default` namespace, and `istio-system/*` represents all endpoints in the `istio-system` namespace. However, we can see that the `bookinfo` namespace is excluded.

```shell {caption="[Shell 5] Endpoint list of my-shell Pod Sidecar Proxy after applying Sidecar Object"}
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

[Shell 5] shows the endpoint list configured in the Sidecar Proxy of the `my-shell` pod after applying the Sidecar Object in [File 1]. Unlike the content in [Shell 3], we can see that endpoints in the `bookinfo` namespace do not exist. In this way, you can configure endpoints registered in the Sidecar Proxy using the Sidecar Object. This means that if all egress destinations of each pod are registered in the Sidecar Object, the number of endpoints can be reduced. Of course, it is not easy for organizations managing Kubernetes clusters to identify and update all egress destinations of each pod.

The Sidecar Object is basically not a technique to block pod traffic. Therefore, when a pod sends traffic to egress destinations that do not exist due to the Sidecar Object, the traffic is transmitted as is. This is because the Sidecar Proxy considers traffic sent to non-existent endpoints as **Unmatched Traffic** and **passes** that traffic as is. That is, traffic passes through even though the Mesh Network cannot be used, and the passed traffic is routed by kube-proxy or external load balancers depending on the destination, or may be dropped if there are no related routing rules.

Since traffic passes through even if endpoints do not exist due to the Sidecar Object, service failures may not occur even if some endpoints are missing from the Sidecar Object. However, since the Mesh Network cannot be utilized, all egress destinations of pods should be registered in the Sidecar Object if possible.

```shell {caption="[Shell 6] Performing tcpdump on the Node where my-shell Pod runs after applying Sidecar Object"}
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

{{< figure caption="[Figure 2] Traffic Flow after applying Sidecar Object" src="images/traffic-flow-with-sidecar-object.png" width="700px" >}}

[Shell 6] shows tcpdump being performed on the veth interface of the `my-shell` pod on the node where the `my-shell` pod runs when sending requests to the `reviews` service after applying the Sidecar Object. We can see that the ClusterIP of the `reviews` service is set as the Destination IP. That is, the egress traffic of the `my-shell` pod **passes through** the Sidecar Proxy as is without DNAT, and DNAT is performed by the node's kube-proxy (iptables). [Figure 2] simply shows the flow of this traffic.

### 1.4. Outbound Communication Restriction

```yaml {caption="[File 3] egress settings of Sidecar Object"}
mesh: |-
  outboundTrafficPolicy:
    mode: REGISTRY_ONLY
```

By default, the Sidecar Proxy passes traffic sent to endpoints not registered due to the Sidecar Object, but you can block traffic sent to endpoints not registered in the Sidecar Proxy by setting `outboundTrafficPolicy` to `REGISTRY_ONLY` in the Mesh Config. [File 3] shows an example of setting `outboundTrafficPolicy` to `REGISTRY_ONLY` in Istio's Mesh Configuration.

`REGISTRY_ONLY` is, as the name suggests, a setting that only passes endpoints registered in the Sidecar Proxy. That is, it only passes endpoints registered in the Sidecar Proxy and blocks traffic sent to unregistered endpoints. The default value of `outboundTrafficPolicy` is `ALLOW_ANY`, in which case the Sidecar Proxy passes traffic sent to endpoints not registered due to the Sidecar Object.

### 1.5. Using workloadSelector

```yaml {caption="[File 2] workloadSelector example of Sidecar Object"}
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

Using the `workloadSelector` of the Sidecar Object, you can select the labels of pods to which the Sidecar Object will be applied. [File 2] shows an example of applying the Sidecar Object not to the entire namespace but only to specific pods in the namespace. It is configured so that the Sidecar Object is applied only to pods with the `app: reviews` label.

## 2. References

* Istio Sidecar Object : [https://istio.io/latest/docs/reference/config/networking/sidecar/](https://istio.io/latest/docs/reference/config/networking/sidecar/)
* Istio Sidecar Object : [https://www.kimsehwan96.com/istio-sidecar-egress-control/](https://www.kimsehwan96.com/istio-sidecar-egress-control/)

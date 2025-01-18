---
title: Istio Sidecar Object
draft: true
---

Istio의 Sidecar Object를 분석한다.

## 1. Istio Sidecar Object

Istio에서 제공하는 Sidecar Object는 Istio의 Sidecar Proxy의 Endpoint 설정을 세세하게 제어하도록 만든다.

```shell
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
```

```shell
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

```shell
$ curl 10.96.209.151:9080/reviews/1
{"id": "1","podname": "reviews-v3-f68f94645-bmzrn","clustername": "null","reviews": [{  "reviewer": "Reviewer1",  "text": "An extremely entertaining play by Shakespeare. The slapstick humour is refreshing!", "rating": {"stars": 5, "color": "red"}},{  "reviewer": "Reviewer2",  "text": "Absolutely fun and entertaining. The play lacks thematic depth when compared to other plays by Shakespeare.", "rating": {"stars": 4, "color": "red"}}]}
```

```shell
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

```yaml
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

```shell
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

```shell
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

## 2. 참조

